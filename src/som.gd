extends Node
## Sons e músicas do jogo, todos sintetizados por código (nenhum arquivo de áudio).
##
## Uso, de qualquer script:  const Som := preload("res://src/som.gd")
##   Som.tocar("pouso")                     efeito curto
##   Som.loop("motor", true, -10.0, 1.4)    som contínuo (liga/desliga, volume em dB, tom)
##   Som.musica("partida_facil")            troca a trilha ("" = silêncio)
## Tecla M liga/desliga todo o som.
##
## O nó fica pendurado na raiz da árvore (fora da cena principal), então a música
## continua tocando quando a cena recarrega para começar outra fase.

const Config := preload("res://src/game_config.gd")

const TAXA := 22050   # amostras por segundo (qualidade suficiente e gera rápido)

enum Onda { SENO, QUADRADA, SERRA, TRIANGULO, RUIDO }

## Volume base de cada efeito (dB), para equilibrar a mixagem. Calibrado pelo volume
## médio (RMS) de cada som: recompensas e quedas mais altas, bipes e cliques discretos.
const GANHO := {
	"pulo": -10.0, "tranco": -5.0, "pouso": -5.0, "perfeito": -1.0, "queda": 0.0,
	"buzina": -10.0, "apito": -11.5, "multa": -5.0, "coleta": -3.0, "entrega": 0.0,
	"erro": -15.0, "bipe": -12.0, "alerta": -11.5, "clique": -10.0, "compra": -8.0,
	"tanque": -3.5, "vitoria": 0.0, "derrota": -3.0,
}
## Trilhas: "menu" e uma da partida por bag (iFudê, 99 Problemas, Kitreta).
const VOLUME_MUSICA := {"menu": -5.0, "partida_facil": -8.0, "partida_medio": -5.5, "partida_dificil": -8.0}

static var _inst = null
static var mudo := false

var _efeitos := {}     # nome -> AudioStreamWAV
var _vozes: Array = []  # AudioStreamPlayer reaproveitados pelos efeitos
var _loops := {}       # nome -> {player, alvo (dB), ligado}
var _musicas := {}     # nome -> AudioStreamWAV (geradas em segundo plano)
var _player_musica: AudioStreamPlayer
var _musica_atual := ""
var _musica_pedida := ""
var _espera_musica := 0.0
var _abafada := false
var _tarefa := -1
var _trava := Mutex.new()
var _prontas := {}     # músicas que a thread terminou, esperando o _process pegar
var _rotulo: Label


# ---------------------------------------------------------------- interface

static func _no():
	if _inst == null:
		_inst = load("res://src/som.gd").new()
		var arvore := Engine.get_main_loop() as SceneTree
		arvore.root.add_child.call_deferred(_inst)
	return _inst


## Garante que o som já foi preparado (chamado no começo do jogo).
static func iniciar() -> void:
	_no()


static func tocar(nome: String, volume_db: float = 0.0, tom: float = 1.0) -> void:
	_no()._tocar(nome, volume_db, tom)


static func loop(nome: String, ligado: bool, volume_db: float = 0.0, tom: float = 1.0) -> void:
	_no()._loop(nome, ligado, volume_db, tom)


static func parar_loops() -> void:
	for nome in _no()._loops:
		_inst._loop(nome, false)


## Troca a trilha. "atraso" = segundos de silêncio antes (ex.: depois da vinheta de fim).
static func musica(nome: String, atraso: float = 0.0) -> void:
	var s = _no()
	s._musica_pedida = nome
	s._espera_musica = atraso


## Abaixa a música (cliente digitando o código, CET na cola...).
static func abafar(sim: bool) -> void:
	_no()._abafada = sim


static func alternar_mudo() -> void:
	mudo = not mudo
	AudioServer.set_bus_mute(0, mudo)
	if _inst and _inst._rotulo:
		_inst._rotulo.visible = mudo


# ---------------------------------------------------------------- nó

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_vozes.append(p)
	_player_musica = AudioStreamPlayer.new()
	_player_musica.volume_db = -60.0
	add_child(_player_musica)
	_gerar_efeitos()
	_gerar_loops()
	# As músicas demoram um pouco para gerar: vão numa thread para não travar a abertura.
	_tarefa = WorkerThreadPool.add_task(_gerar_musicas)

	var camada := CanvasLayer.new()
	camada.layer = 40
	add_child(camada)
	_rotulo = Label.new()
	_rotulo.text = "SOM DESLIGADO (M)"
	_rotulo.add_theme_font_size_override("font_size", 15)
	_rotulo.add_theme_color_override("font_color", Config.COR_PAPEL)
	_rotulo.add_theme_color_override("font_outline_color", Config.COR_PRETO)
	_rotulo.add_theme_constant_override("outline_size", 5)
	_rotulo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_rotulo.offset_left = -360.0
	_rotulo.offset_top = -40.0
	_rotulo.offset_right = -16.0
	_rotulo.offset_bottom = -12.0
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rotulo.visible = mudo
	camada.add_child(_rotulo)
	AudioServer.set_bus_mute(0, mudo)


func _exit_tree() -> void:
	# Para tudo ao fechar o jogo (som tocando na saída fica preso na memória)
	for p in _vozes:
		p.stop()
	for nome in _loops:
		_loops[nome].player.stop()
	_player_musica.stop()
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_M:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return   # digitando um nome (ranking): o M é letra, não o mudo
		alternar_mudo()


func _process(delta: float) -> void:
	_trava.lock()
	_musicas.merge(_prontas)
	_prontas.clear()
	_trava.unlock()

	# Sons contínuos: sobem/descem suave até o volume pedido; desligados somem e param.
	for nome in _loops:
		var l: Dictionary = _loops[nome]
		var p: AudioStreamPlayer = l.player
		var alvo: float = l.alvo if l.ligado else -50.0
		p.volume_db = move_toward(p.volume_db, alvo, 90.0 * delta)
		if not l.ligado and p.playing and p.volume_db <= -49.0:
			p.stop()

	# Música: espera o atraso, desce o volume da atual, troca e sobe a nova.
	_espera_musica = maxf(_espera_musica - delta, 0.0)
	var quero := _musica_pedida if _espera_musica <= 0.0 else ""
	if quero != _musica_atual:
		_player_musica.volume_db = move_toward(_player_musica.volume_db, -60.0, 50.0 * delta)
		if _player_musica.volume_db <= -59.0 or not _player_musica.playing:
			_player_musica.stop()
			_musica_atual = ""
			if quero != "" and _musicas.has(quero):
				_player_musica.stream = _musicas[quero]
				_player_musica.play()
				_musica_atual = quero
	elif _musica_atual != "":
		var alvo: float = VOLUME_MUSICA[_musica_atual] - (9.0 if _abafada else 0.0)
		_player_musica.volume_db = move_toward(_player_musica.volume_db, alvo, 25.0 * delta)


func _tocar(nome: String, volume_db: float, tom: float) -> void:
	if not is_inside_tree() or not _efeitos.has(nome):
		return
	# Usa uma voz livre; se todas estiverem ocupadas, a que tocou há mais tempo.
	var voz: AudioStreamPlayer = _vozes[0]
	for v in _vozes:
		if not v.playing:
			voz = v
			break
	_vozes.erase(voz)
	_vozes.append(voz)
	voz.stream = _efeitos[nome]
	voz.volume_db = GANHO.get(nome, 0.0) + volume_db
	voz.pitch_scale = tom
	voz.play()


func _loop(nome: String, ligado: bool, volume_db: float = 0.0, tom: float = 1.0) -> void:
	if not is_inside_tree() or not _loops.has(nome):
		return
	var l: Dictionary = _loops[nome]
	var p: AudioStreamPlayer = l.player
	l.ligado = ligado
	if ligado:
		l.alvo = volume_db
		p.pitch_scale = maxf(tom, 0.05)
		if not p.playing:
			p.volume_db = -40.0
			p.play()


# ---------------------------------------------------------------- síntese

func _vazio(segundos: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(segundos * TAXA))
	b.fill(0.0)
	return b


## Soma uma nota no buffer "b".
## t0/dur em segundos; f0 -> f1 = frequência no começo e no fim (desliza);
## queda = quão rápido o volume cai (envelope exponencial); filtro < 1 abafa os agudos;
## vibrato = [velocidade Hz, profundidade 0..1]; envolver = o que passar do fim volta
## para o começo (para a música emendar sem corte no loop).
func _nota(b: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, onda: int, vol: float,
		queda: float = 6.0, ataque: float = 0.004, filtro: float = 1.0,
		vibrato: Vector2 = Vector2.ZERO, envolver: bool = false) -> void:
	var tam := b.size()
	var i0 := int(t0 * TAXA)
	var n := int(dur * TAXA)
	var fase := 0.0
	var y := 0.0
	var razao := f1 / f0
	var rng := RandomNumberGenerator.new()
	rng.seed = i0 + int(f0)
	for k in n:
		var i := i0 + k
		if i >= tam:
			if not envolver:
				break
			i = i % tam
		var t := float(k) / TAXA
		var f := f0 * pow(razao, float(k) / n) if f0 != f1 else f0
		if vibrato.x > 0.0:
			f *= 1.0 + vibrato.y * sin(TAU * vibrato.x * t)
		fase += f / TAXA
		var ciclo := fase - floorf(fase)
		var x := 0.0
		if onda == Onda.SENO:
			x = sin(TAU * ciclo)
		elif onda == Onda.QUADRADA:
			x = 1.0 if ciclo < 0.5 else -1.0
		elif onda == Onda.SERRA:
			x = 2.0 * ciclo - 1.0
		elif onda == Onda.TRIANGULO:
			x = 1.0 - 4.0 * absf(ciclo - 0.5)
		else:
			x = rng.randf_range(-1.0, 1.0)
		y += filtro * (x - y)
		var env := minf(t / ataque, 1.0) * exp(-queda * t)
		var resto := float(n - k) / TAXA
		if resto < 0.006:
			env *= resto / 0.006
		b[i] += y * env * vol


## Bumbo estilo 808: seno que despenca de tom no começo e segura um grave longo.
## "saturacao" maior = grave mais distorcido.
func _bumbo(b: PackedFloat32Array, t0: float, grave: float, dur: float, vol: float,
		envolver: bool = false, saturacao: float = 1.8) -> void:
	var tam := b.size()
	var i0 := int(t0 * TAXA)
	var n := int(dur * TAXA)
	var fase := 0.0
	for k in n:
		var i := i0 + k
		if i >= tam:
			if not envolver:
				break
			i = i % tam
		var t := float(k) / TAXA
		var f := grave + (160.0 - grave) * exp(-t * 35.0)
		fase += f / TAXA
		var env := exp(-t * 3.0 / dur) * minf(float(n - k) / (0.01 * TAXA), 1.0)
		# Saturação leve: o "pancadão" do grave
		b[i] += tanh(sin(TAU * fase) * saturacao) * env * vol


## Palma: três estalos de ruído quase juntos e um rabo curto.
func _palma(b: PackedFloat32Array, t0: float, vol: float, envolver: bool = false) -> void:
	for d in [0.0, 0.011, 0.022]:
		_nota(b, t0 + d, 0.012, 1000.0, 1000.0, Onda.RUIDO, vol, 60.0, 0.001, 0.5, Vector2.ZERO, envolver)
	_nota(b, t0 + 0.03, 0.16, 1000.0, 1000.0, Onda.RUIDO, vol * 0.7, 22.0, 0.001, 0.45, Vector2.ZERO, envolver)


## Chimbal: ruído bem agudo e curtinho.
func _chimbal(b: PackedFloat32Array, t0: float, vol: float, dur: float = 0.04, envolver: bool = false) -> void:
	var tam := b.size()
	var i0 := int(t0 * TAXA)
	var n := int(dur * TAXA)
	var rng := RandomNumberGenerator.new()
	rng.seed = i0
	var ant := 0.0
	for k in n:
		var i := (i0 + k) % tam if envolver else i0 + k
		if i >= tam:
			break
		var x := rng.randf_range(-1.0, 1.0)
		b[i] += (x - ant) * 0.5 * exp(-float(k) / n * 5.0) * vol
		ant = x


## Compressão simples (tanh): deixa o som mais "cheio" sem estourar o pico.
func _comprimir(b: PackedFloat32Array, forca: float) -> PackedFloat32Array:
	var m := 0.0001
	for x in b:
		m = maxf(m, absf(x))
	for i in b.size():
		b[i] = tanh(b[i] / m * forca)
	return b


func _normalizar(b: PackedFloat32Array, pico: float = 0.85) -> PackedFloat32Array:
	var m := 0.0001
	for x in b:
		m = maxf(m, absf(x))
	var g := pico / m
	for i in b.size():
		b[i] *= g
	return b


## Emenda o fim no começo (para loops de ruído não darem "clique" ao repetir).
func _emendar(b: PackedFloat32Array, segundos: float) -> PackedFloat32Array:
	var m := int(segundos * TAXA)
	var n := b.size() - m
	for k in m:
		var a := float(k) / m
		b[k] = b[k] * a + b[n + k] * (1.0 - a)
	b.resize(n)
	return b


func _wav(b: PackedFloat32Array, repetir: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = bytes
	if repetir:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w


# ---------------------------------------------------------------- efeitos

func _gerar_efeitos() -> void:
	var b: PackedFloat32Array

	b = _vazio(0.16)
	_nota(b, 0.0, 0.16, 190.0, 520.0, Onda.QUADRADA, 0.5, 14.0, 0.004, 0.35)
	_efeitos.pulo = _wav(_normalizar(b))

	# Tranco: a roda batendo na lombada / caindo no buraco
	b = _vazio(0.25)
	_bumbo(b, 0.0, 55.0, 0.22, 0.9)
	_nota(b, 0.0, 0.08, 1.0, 1.0, Onda.RUIDO, 0.5, 30.0, 0.001, 0.25)
	_efeitos.tranco = _wav(_normalizar(b))

	b = _vazio(0.3)
	_bumbo(b, 0.0, 45.0, 0.26, 0.9)
	_nota(b, 0.0, 0.18, 1.0, 1.0, Onda.RUIDO, 0.45, 18.0, 0.001, 0.12)
	_efeitos.pouso = _wav(_normalizar(b))

	b = _vazio(0.5)
	_nota(b, 0.0, 0.4, 1318.5, 1318.5, Onda.SENO, 0.5, 7.0)
	_nota(b, 0.07, 0.43, 1760.0, 1760.0, Onda.SENO, 0.5, 6.0)
	_nota(b, 0.07, 0.43, 3520.0, 3520.0, Onda.SENO, 0.12, 9.0)
	_efeitos.perfeito = _wav(_normalizar(b))

	# Queda: lata amassando (ruído + parciais metálicas desafinadas)
	b = _vazio(0.7)
	_nota(b, 0.0, 0.7, 1.0, 1.0, Onda.RUIDO, 0.8, 6.0, 0.001, 0.3)
	for f in [523.0, 811.0, 1172.0, 1663.0, 2290.0]:
		_nota(b, 0.0, 0.5, f, f * 0.97, Onda.SENO, 0.25, 9.0, 0.001)
	_bumbo(b, 0.0, 50.0, 0.3, 0.3)
	_efeitos.queda = _wav(_normalizar(_comprimir(b, 4.0)))

	# Buzina de carro: "fom-fóóm"
	b = _vazio(0.62)
	for p in [[0.0, 0.16], [0.22, 0.4]]:
		_nota(b, p[0], p[1], 415.0, 415.0, Onda.QUADRADA, 0.4, 0.5, 0.01, 0.3)
		_nota(b, p[0], p[1], 523.0, 523.0, Onda.QUADRADA, 0.4, 0.5, 0.01, 0.3)
	_efeitos.buzina = _wav(_normalizar(b))

	# Apito do guarda: dois trinados
	b = _vazio(1.0)
	_nota(b, 0.0, 0.3, 2600.0, 2600.0, Onda.SENO, 0.6, 1.0, 0.01, 1.0, Vector2(28.0, 0.03))
	_nota(b, 0.4, 0.55, 2600.0, 2550.0, Onda.SENO, 0.6, 1.5, 0.01, 1.0, Vector2(28.0, 0.03))
	_efeitos.apito = _wav(_normalizar(b))

	b = _vazio(0.6)
	_nota(b, 0.0, 0.55, 720.0, 230.0, Onda.SERRA, 0.5, 2.0, 0.005, 0.3)
	_efeitos.multa = _wav(_normalizar(b))

	b = _vazio(0.45)
	_nota(b, 0.0, 0.35, 1046.5, 1046.5, Onda.SENO, 0.5, 8.0)
	_nota(b, 0.08, 0.37, 1568.0, 1568.0, Onda.SENO, 0.5, 7.0)
	_efeitos.coleta = _wav(_normalizar(b))

	# Entrega: "tchi-tching" de caixa registradora
	b = _vazio(0.8)
	_nota(b, 0.0, 0.03, 1.0, 1.0, Onda.RUIDO, 0.3, 50.0, 0.001, 0.6)
	_nota(b, 0.0, 0.08, 1318.5, 1318.5, Onda.QUADRADA, 0.15, 20.0, 0.002, 0.4)
	for f in [2093.0, 2637.0, 3136.0]:
		_nota(b, 0.08, 0.7, f, f, Onda.SENO, 0.3, 4.5)
	_efeitos.entrega = _wav(_normalizar(b))

	b = _vazio(0.32)
	_nota(b, 0.0, 0.12, 150.0, 150.0, Onda.QUADRADA, 0.5, 2.0, 0.003, 0.4)
	_nota(b, 0.17, 0.14, 140.0, 140.0, Onda.QUADRADA, 0.5, 2.0, 0.003, 0.4)
	_efeitos.erro = _wav(_normalizar(b))

	b = _vazio(0.07)
	_nota(b, 0.0, 0.07, 1200.0, 1200.0, Onda.SENO, 0.6, 25.0)
	_efeitos.bipe = _wav(_normalizar(b))

	b = _vazio(0.3)
	_nota(b, 0.0, 0.09, 880.0, 880.0, Onda.QUADRADA, 0.4, 3.0, 0.003, 0.4)
	_nota(b, 0.15, 0.09, 880.0, 880.0, Onda.QUADRADA, 0.4, 3.0, 0.003, 0.4)
	_efeitos.alerta = _wav(_normalizar(b))

	b = _vazio(0.04)
	_nota(b, 0.0, 0.04, 1800.0, 1400.0, Onda.SENO, 0.6, 60.0)
	_nota(b, 0.0, 0.01, 1.0, 1.0, Onda.RUIDO, 0.3, 80.0, 0.001, 0.7)
	_efeitos.clique = _wav(_normalizar(b))

	b = _vazio(0.45)
	_nota(b, 0.0, 0.08, 988.0, 988.0, Onda.QUADRADA, 0.4, 4.0, 0.002, 0.4)
	_nota(b, 0.08, 0.35, 1318.5, 1318.5, Onda.QUADRADA, 0.4, 6.0, 0.002, 0.4)
	_efeitos.compra = _wav(_normalizar(b))

	b = _vazio(0.5)
	_nota(b, 0.0, 0.2, 784.0, 784.0, Onda.TRIANGULO, 0.5, 6.0)
	_nota(b, 0.12, 0.38, 1046.5, 1046.5, Onda.TRIANGULO, 0.5, 5.0)
	_efeitos.tanque = _wav(_normalizar(b))

	# Vitória: arpejo subindo + acorde final + um pancadão de 808
	b = _vazio(1.8)
	var notas := [523.25, 659.25, 783.99, 1046.5]
	for i in notas.size():
		_nota(b, i * 0.11, 0.2, notas[i], notas[i], Onda.QUADRADA, 0.25, 6.0, 0.003, 0.35)
	for f in [523.25, 659.25, 783.99, 1046.5]:
		_nota(b, 0.46, 1.3, f, f, Onda.TRIANGULO, 0.25, 2.0, 0.01)
		_nota(b, 0.46, 1.3, f * 1.004, f * 1.004, Onda.QUADRADA, 0.06, 2.5, 0.01, 0.3)
	_bumbo(b, 0.46, 55.0, 0.8, 0.3)
	_efeitos.vitoria = _wav(_normalizar(_comprimir(b, 2.5)))

	# Derrota: "uóóó-uóóó-uóóó-uóóóóm" descendo
	b = _vazio(2.2)
	var desce := [392.0, 370.0, 349.2, 329.6]
	for i in desce.size():
		var dur := 0.32 if i < 3 else 1.1
		_nota(b, i * 0.36, dur, desce[i], desce[i] * (0.97 if i == 3 else 1.0), Onda.SERRA, 0.4,
			1.5, 0.01, 0.2, Vector2(5.5, 0.012 if i == 3 else 0.0))
	_efeitos.derrota = _wav(_normalizar(b))


func _gerar_loops() -> void:
	var b: PackedFloat32Array

	# Motor: 32 "explosões" por segundo (monocilíndrico). O tom sobe com a velocidade.
	b = _vazio(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var periodo := TAXA / 32
	var y := 0.0
	for i in b.size():
		var k := i % periodo
		var t := float(k) / TAXA
		var pulso := exp(-t * 120.0)
		var x := rng.randf_range(-1.0, 1.0) * pulso * 0.8
		x += sin(TAU * 32.0 * i / TAXA) * 0.5 + sin(TAU * 64.0 * i / TAXA) * 0.35 * pulso
		x += sin(TAU * 96.0 * i / TAXA) * 0.2
		y += 0.25 * (x - y)
		b[i] = y
	_loop_novo("motor", _normalizar(b, 0.7))

	# Vento no voo
	b = _vazio(1.7)
	_nota(b, 0.0, 1.7, 1.0, 1.0, Onda.RUIDO, 0.8, 0.0, 0.001, 0.05)
	for i in b.size():
		b[i] *= 0.7 + 0.3 * sin(TAU * 1.0 * i / TAXA)
	_loop_novo("vento", _normalizar(_emendar(b, 0.2), 0.6))

	# Chuva: chiado agudo + pingos
	b = _vazio(2.2)
	rng.seed = 3
	var ant := 0.0
	for i in b.size():
		var x := rng.randf_range(-1.0, 1.0)
		b[i] = (x - ant) * 0.25
		ant = x
	for g in 70:
		var t := rng.randf_range(0.0, 2.1)
		_nota(b, t, 0.03, rng.randf_range(2500.0, 5000.0), 1500.0, Onda.SENO, rng.randf_range(0.05, 0.2), 90.0, 0.001)
	_loop_novo("chuva", _normalizar(_emendar(b, 0.2), 0.5))

	# Sirene da CET: dois tons, alto-baixo (frequências com ciclos inteiros = emenda perfeita)
	b = _vazio(1.2)
	_nota(b, 0.0, 0.6, 950.0, 950.0, Onda.SERRA, 0.5, 0.0, 0.02, 0.35)
	_nota(b, 0.6, 0.6, 700.0, 700.0, Onda.SERRA, 0.5, 0.0, 0.02, 0.35)
	_loop_novo("sirene", _normalizar(b, 0.6))

	# Freio: chiado do pneu
	b = _vazio(0.6)
	_nota(b, 0.0, 0.6, 1350.0, 1350.0, Onda.TRIANGULO, 0.3, 0.0, 0.001, 1.0, Vector2(13.0, 0.02))
	var ruido := _vazio(0.6)
	_nota(ruido, 0.0, 0.6, 1.0, 1.0, Onda.RUIDO, 0.5, 0.0, 0.001, 0.6)
	for i in b.size():
		b[i] += ruido[i]
	_loop_novo("freio", _normalizar(_emendar(b, 0.1), 0.5))

	# Bomba do posto: zumbido + gorgolejo
	b = _vazio(1.0)
	_nota(b, 0.0, 1.0, 110.0, 110.0, Onda.TRIANGULO, 0.4, 0.0, 0.001)
	_nota(b, 0.0, 1.0, 220.0, 220.0, Onda.SENO, 0.15, 0.0, 0.001)
	var gorgolejo := _vazio(1.0)
	_nota(gorgolejo, 0.0, 1.0, 1.0, 1.0, Onda.RUIDO, 0.6, 0.0, 0.001, 0.08)
	for i in b.size():
		b[i] += gorgolejo[i] * (0.5 + 0.5 * sin(TAU * 7.0 * i / TAXA))
	_loop_novo("bomba", _normalizar(b, 0.6))


func _loop_novo(nome: String, b: PackedFloat32Array) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _wav(b, true)
	add_child(p)
	_loops[nome] = {"player": p, "alvo": -50.0, "ligado": false}


# ---------------------------------------------------------------- músicas

## Roda numa thread. O menu sai primeiro, porque é a primeira tela.
func _gerar_musicas() -> void:
	var menu := _wav(_normalizar(_musica_menu(), 0.9), true)
	_entregar("menu", menu)
	_entregar("partida_facil", _wav(_normalizar(_musica_funk_paulista(), 0.9), true))
	_entregar("partida_medio", _wav(_normalizar(_musica_funk_antigo(), 0.9), true))
	_entregar("partida_dificil", _wav(_normalizar(_musica_funk_bruxaria(), 0.9), true))


func _entregar(nome: String, w: AudioStreamWAV) -> void:
	_trava.lock()
	_prontas[nome] = w
	_trava.unlock()


## Trilha do iFudê: funk paulista ("pancadão"), 130 BPM, 8 compassos em loop.
## 808 grave e longo na batida do tamborzão, palmas, chimbal, o "tuim" que desce
## e, na segunda metade, um synth agudo "automotivo" com vibrato.
func _musica_funk_paulista() -> PackedFloat32Array:
	var passo := 60.0 / 130.0 / 4.0   # semicolcheia
	var compasso := passo * 16.0
	var b := _vazio(compasso * 8.0)
	# Tom de cada compasso (grave do 808): Lá, Lá, Fá, Sol, Lá, Lá, Fá, Mi
	var graves := [55.0, 55.0, 43.65, 49.0, 55.0, 55.0, 43.65, 41.2]
	var agudos := [880.0, 880.0, 698.46, 783.99, 880.0, 880.0, 698.46, 659.25]
	for c in 8:
		var t0: float = c * compasso
		var g: float = graves[c]
		var bumbos := [0, 3, 6, 10] if c % 2 == 0 else [0, 3, 6, 10, 13]
		for s in bumbos:
			var dur := 0.34 if s != 13 else 0.2
			_bumbo(b, t0 + s * passo, g, dur, 0.85, true)
		for s in [4, 12]:
			_palma(b, t0 + s * passo, 0.32, true)
		if c == 7:
			_palma(b, t0 + 14 * passo, 0.22, true)
			_palma(b, t0 + 15 * passo, 0.26, true)
		for s in range(1, 16, 2):
			_chimbal(b, t0 + s * passo, 0.16 if s % 4 == 3 else 0.09, 0.04, true)
		# Tamborim do tamborzão
		for s in [7, 9, 14]:
			_nota(b, t0 + s * passo, 0.07, 440.0, 380.0, Onda.SENO, 0.16, 35.0, 0.001, 1.0, Vector2.ZERO, true)
		# "Tuim": o assobio que despenca, marca do funk
		if c % 2 == 1:
			_nota(b, t0 + 8 * passo, 0.2, 1900.0, 520.0, Onda.SENO, 0.2, 8.0, 0.002, 1.0, Vector2.ZERO, true)
		# Synth "automotivo" na segunda metade
		if c >= 4:
			var a: float = agudos[c]
			for s in [0, 3, 6, 10, 12, 14]:
				var f := a * (1.5 if s == 14 and c % 2 == 1 else 1.0)
				_nota(b, t0 + s * passo, passo * 0.9, f, f, Onda.SERRA, 0.11, 10.0, 0.003, 0.45,
					Vector2(6.0, 0.012), true)
				_nota(b, t0 + s * passo, passo * 0.9, f * 1.006, f * 1.006, Onda.QUADRADA, 0.05, 10.0, 0.003,
					0.3, Vector2.ZERO, true)
		# Sirene subindo antes de voltar ao começo
		if c == 7:
			_nota(b, t0 + 8 * passo, passo * 8.0, 500.0, 1500.0, Onda.SERRA, 0.08, 0.0, 0.05, 0.25,
				Vector2(9.0, 0.02), true)
	return b


## Trilha do 99 Problemas: funk das antigas (baile dos anos 2000), 128 BPM, 8 compassos.
## Batida Miami bass (bumbo 808 "tum... tum-tum", palmas no 2 e no 4), o cowbell do baile,
## "orquestra" no começo dos compassos e, na segunda metade, uma melodia de synth
## (composição original). Fecha o loop com o apito de baile.
func _musica_funk_antigo() -> PackedFloat32Array:
	var passo := 60.0 / 128.0 / 4.0
	var compasso := passo * 16.0
	var b := _vazio(compasso * 8.0)
	# Ré menor, Si bemol, Dó, Lá (dois compassos cada)
	var graves := [73.42, 73.42, 58.27, 58.27, 65.41, 65.41, 55.0, 55.0]
	var acordes := [
		[293.66, 349.23, 440.0], [293.66, 349.23, 440.0],
		[233.08, 293.66, 349.23], [233.08, 293.66, 349.23],
		[261.63, 329.63, 392.0], [261.63, 329.63, 392.0],
		[220.0, 277.18, 329.63], [220.0, 277.18, 329.63],
	]
	# Melodia em colcheias para os compassos 5 a 8 (Hz; 0 = pausa)
	var melodia := [
		[659.25, 0.0, 659.25, 783.99, 698.46, 0.0, 659.25, 587.33],
		[659.25, 0.0, 659.25, 783.99, 1046.5, 0.0, 783.99, 659.25],
		[659.25, 0.0, 554.37, 659.25, 880.0, 0.0, 659.25, 554.37],
		[554.37, 0.0, 554.37, 659.25, 554.37, 0.0, 440.0, 0.0],
	]
	for c in 8:
		var t0: float = c * compasso
		var g: float = graves[c]
		for s in [0, 7, 10]:
			_bumbo(b, t0 + s * passo, g, 0.42 if s == 0 else 0.3, 0.8, true, 1.4)
		for s in [4, 12]:
			_palma(b, t0 + s * passo, 0.34, true)
		for s in 16:
			var aberto := s % 4 == 2
			_chimbal(b, t0 + s * passo, 0.12 if aberto else 0.05, 0.09 if aberto else 0.03, true)
		# Cowbell do baile: dois tons quadrados bem curtos
		for s in [2, 5, 7, 10, 13]:
			_nota(b, t0 + s * passo, 0.09, 540.0, 540.0, Onda.QUADRADA, 0.06, 30.0, 0.001, 0.5, Vector2.ZERO, true)
			_nota(b, t0 + s * passo, 0.09, 800.0, 800.0, Onda.QUADRADA, 0.05, 30.0, 0.001, 0.5, Vector2.ZERO, true)
		# "Orquestra" (o acorde de impacto dos bailes antigos) a cada dois compassos
		if c % 2 == 0:
			for f in acordes[c]:
				_nota(b, t0, 0.35, f, f, Onda.SERRA, 0.09, 9.0, 0.002, 0.45, Vector2.ZERO, true)
				_nota(b, t0, 0.35, f * 2.0, f * 2.0, Onda.SERRA, 0.05, 11.0, 0.002, 0.4, Vector2.ZERO, true)
		# Acorde curtinho no contratempo
		for s in [6, 14]:
			for f in acordes[c]:
				_nota(b, t0 + s * passo, passo * 0.8, f * 2.0, f * 2.0, Onda.QUADRADA, 0.025, 14.0, 0.002, 0.4,
					Vector2.ZERO, true)
		if c >= 4:
			var frase: Array = melodia[c - 4]
			for k in 8:
				var f: float = frase[k]
				if f > 0.0:
					_nota(b, t0 + k * 2.0 * passo, passo * 1.7, f, f, Onda.QUADRADA, 0.09, 6.0, 0.003, 0.35,
						Vector2(5.5, 0.006), true)
		if c == 7:
			for k in 3:   # apito de baile
				_nota(b, t0 + (12 + k) * passo, passo * 0.8, 2700.0, 2700.0, Onda.SENO, 0.12, 3.0, 0.005, 1.0,
					Vector2(30.0, 0.03), true)
	return b


## Trilha do Kitreta: funk "bruxaria" (mandelão sombrio), 150 BPM, mais pesado e tenso:
## 808 distorcido sobre graves cromáticos, sinos dissonantes, um zumbido arrastado,
## chimbal em rajadas e um chiado que sobe antes das viradas. É o som do prazo apertado.
func _musica_funk_bruxaria() -> PackedFloat32Array:
	var passo := 60.0 / 150.0 / 4.0
	var compasso := passo * 16.0
	var b := _vazio(compasso * 8.0)
	# Mi, Mi, Fá, Mi, Mi, Mi, Fá#, Fá: o grave quase não sai do lugar, só raspa meio tom
	var graves := [41.2, 41.2, 43.65, 41.2, 41.2, 41.2, 46.25, 43.65]
	for c in 8:
		var t0: float = c * compasso
		var g: float = graves[c]
		for s in [0, 3, 6, 10, 12]:
			_bumbo(b, t0 + s * passo, g, 0.26, 0.85, true, 3.2)
		for s in [4, 12]:
			_palma(b, t0 + s * passo, 0.3, true)
		for s in [7, 15]:   # aro seco
			_nota(b, t0 + s * passo, 0.03, 1.0, 1.0, Onda.RUIDO, 0.18, 60.0, 0.001, 0.7, Vector2.ZERO, true)
		for s in range(0, 16, 2):
			_chimbal(b, t0 + s * passo, 0.07, 0.03, true)
		if c % 4 == 3:   # rajada de chimbal em tercinas no fim da frase
			for k in 6:
				_chimbal(b, t0 + 12.0 * passo + k * (4.0 * passo / 6.0), 0.1, 0.03, true)
		# Zumbido grave arrastado por baixo de tudo
		_nota(b, t0, compasso, g * 2.0, g * 2.0, Onda.SERRA, 0.05, 0.3, 0.2, 0.08, Vector2(0.5, 0.01), true)
		# Sinos dissonantes: mi e fá tocando juntos, desafinando de leve
		if c >= 2:
			for s in [2, 9]:
				_nota(b, t0 + s * passo, 0.5, 659.25, 655.0, Onda.SENO, 0.08, 5.0, 0.002, 1.0, Vector2.ZERO, true)
				_nota(b, t0 + s * passo, 0.5, 698.46, 694.0, Onda.SENO, 0.06, 5.0, 0.002, 1.0, Vector2.ZERO, true)
				_nota(b, t0 + s * passo, 0.3, 1318.5, 1310.0, Onda.SENO, 0.03, 8.0, 0.002, 1.0, Vector2.ZERO, true)
		if c % 2 == 1:   # "tuim" mais rápido e mais grave
			_nota(b, t0 + 14.0 * passo, 0.12, 1400.0, 300.0, Onda.SENO, 0.2, 10.0, 0.002, 1.0, Vector2.ZERO, true)
		if c == 3 or c == 7:   # chiado subindo antes da virada
			_nota(b, t0 + 8.0 * passo, passo * 8.0, 1.0, 1.0, Onda.RUIDO, 0.12, 0.0, passo * 8.0, 0.35,
				Vector2.ZERO, true)
		if c >= 4:   # sirene grave e lenta na segunda metade
			_nota(b, t0, compasso, 330.0, 330.0, Onda.SERRA, 0.03, 0.0, 0.3, 0.2, Vector2(2.0, 0.08), true)
	return b


## Trilha do menu: fim de tarde, mais calma (92 BPM): acordes suaves, arpejo e batida leve.
func _musica_menu() -> PackedFloat32Array:
	var passo := 60.0 / 92.0 / 4.0
	var compasso := passo * 16.0
	var b := _vazio(compasso * 8.0)
	# Lá menor 7, Fá maior 7, Dó maior, Sol maior (2 compassos cada)
	var acordes := [
		[220.0, 261.63, 329.63, 392.0],
		[174.61, 220.0, 261.63, 329.63],
		[261.63, 329.63, 392.0, 523.25],
		[196.0, 246.94, 293.66, 392.0],
	]
	for a in 4:
		var t0: float = a * 2.0 * compasso
		var notas: Array = acordes[a]
		for f in notas:
			_nota(b, t0, compasso * 2.0, f, f, Onda.TRIANGULO, 0.07, 0.4, 0.35, 0.6, Vector2(4.0, 0.003), true)
		# Baixo
		var raiz: float = notas[0] / 2.0
		for s in [0, 6, 10, 16, 22, 26]:
			_nota(b, t0 + s * passo, passo * 2.5, raiz, raiz, Onda.TRIANGULO, 0.28, 3.0, 0.005, 0.7, Vector2.ZERO, true)
		# Arpejo dedilhado em colcheias
		for s in range(0, 32, 2):
			var f: float = notas[(s / 2) % notas.size()] * 2.0
			_nota(b, t0 + s * passo, passo * 1.8, f, f, Onda.SENO, 0.07, 9.0, 0.003, 1.0, Vector2.ZERO, true)
	for c in 8:
		var t0: float = c * compasso
		for s in [0, 10]:
			_bumbo(b, t0 + s * passo, 52.0, 0.25, 0.4, true)
		for s in [4, 12]:
			_nota(b, t0 + s * passo, 0.06, 1.0, 1.0, Onda.RUIDO, 0.13, 40.0, 0.001, 0.4, Vector2.ZERO, true)
		for s in range(0, 16, 2):
			_chimbal(b, t0 + s * passo, 0.05, 0.03, true)
	return b
