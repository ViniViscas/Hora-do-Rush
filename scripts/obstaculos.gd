extends Node2D
## Lógica dos obstáculos do M2: lombada, boca de lobo, estrada de terra, ciclovia,
## blitz, cruzamento, chuva e a perseguição da CET (habilitação vencida).
## Fala com a cena principal só por sinais.

signal aviso(texto: String, cor: Color)
signal placar(pontos: int, tempo: float, texto: String, cor: Color)

const Config := preload("res://scripts/game_config.gd")
const Gerador := preload("res://scripts/gerador_fase.gd")
const Marcador := preload("res://scripts/marcador.gd")
const CarroCet := preload("res://scripts/carro_cet.gd")

var moto
var chao
var rng: RandomNumberGenerator
var dif: Dictionary = {}

var lombadas: Array = []
var bocas: Array = []
var terras: Array = []
var ciclovias: Array = []
var blitzes: Array = []
var cruzamentos: Array = []

var chovendo := false
var cet = null  # carro_cet.gd
var cet_restante := 0.0
var _cet_gatilho := -1.0
var _tempo := 0.0
var _x_anterior := 0.0
var _causa_voo := ""
var _na_ciclovia := false
var _ajuda_equilibrio := 0


## Cria os desenhos na pista a partir da fase gerada. Chamado depois do chão existir.
func construir(chao_ref, rng_ref: RandomNumberGenerator, fase: Dictionary) -> void:
	chao = chao_ref
	rng = rng_ref
	for x in fase.lombadas:
		lombadas.append(_marcador("lombada", x - 46.0, x + 46.0))
	for x in fase.bocas:
		bocas.append(_marcador("boca", x - 34.0, x + 34.0))
	for t in fase.terra:
		terras.append(_marcador("terra", t[0], t[1]))
	for c in fase.ciclovias:
		ciclovias.append(_marcador("ciclovia", c[0], c[1]))
	for b in fase.blitz:
		blitzes.append(_marcador("blitz", b[0], b[1]))
	for x in fase.cruzamentos:
		var m = _marcador("cruzamento", x - 100.0, x + 100.0)
		m.iniciar_cruzamento(rng.randf_range(0.5, 4.0))
		cruzamentos.append(m)


func _marcador(tipo: String, x0: float, x1: float):
	var m := Marcador.new()
	m.tipo = tipo
	m.x0 = x0
	m.x1 = x1
	m.chao = chao
	add_child(m)
	return m


## Sorteios da partida: ciclovias, chuva e se a CET vai aparecer.
func iniciar(moto_ref, dificuldade: Dictionary) -> void:
	moto = moto_ref
	dif = dificuldade
	moto.pousou.connect(_on_pousou)
	_x_anterior = moto.position.x

	var alguma := false
	for c in ciclovias:
		c.ativo = rng.randf() < 0.5
		alguma = alguma or c.ativo
	if not alguma and not ciclovias.is_empty():
		ciclovias[rng.randi_range(0, ciclovias.size() - 1)].ativo = true
	for c in ciclovias:
		c.visible = c.ativo

	chovendo = rng.randf() < dif.chance_chuva
	moto.mult_freio = 0.4 if chovendo else 1.0

	_cet_gatilho = -1.0
	if rng.randf() < dif.chance_cet:
		_cet_gatilho = rng.randf_range(0.15, 0.4) * dif.tempo_fase


## Chamado todo frame durante a partida. "pausado" = cliente digitando código.
func processar(delta: float, pausado: bool) -> void:
	for c in cruzamentos:
		c.atualizar_cruzamento(delta)
	if pausado:
		return
	_tempo += delta
	var x: float = moto.position.x
	var vx: float = absf(moto.velocity.x)
	var no_chao: bool = moto.is_on_floor()

	# Superfície: terra deixa lento, ciclovia corta caminho mais rápido
	var mult_vel := 1.0
	var mult_acel := 1.0
	var em_ciclovia := false
	for t in terras:
		if t.contem(x):
			mult_vel *= 0.55
			mult_acel *= 0.6
	for c in ciclovias:
		if c.contem(x) and no_chao:
			mult_vel *= 1.35
			mult_acel *= 1.3
			em_ciclovia = true
	moto.mult_vel = mult_vel
	moto.mult_acel = mult_acel
	if em_ciclovia and not _na_ciclovia:
		aviso.emit("Ciclovia! Cortando caminho...", Config.COR_LARANJA_CLARO)
	_na_ciclovia = em_ciclovia

	if no_chao and not moto.caido:
		_checar_lombadas(x, vx)
		_checar_bocas(x, vx)
	_checar_blitz(x, vx)
	_checar_cruzamentos(x)
	_atualizar_cet(delta, x)
	_x_anterior = x


func _cruzou(px: float, x: float) -> bool:
	return (_x_anterior < px) != (x < px)


func _checar_lombadas(x: float, vx: float) -> void:
	for l in lombadas:
		if not _cruzou(l.cx(), x):
			continue
		if vx > 200.0:
			var forca: float = vx / moto.vel_max
			var sentido := signf(moto.velocity.x)
			# Empina a moto (bico para cima no sentido do movimento)
			moto.lancar(-(250.0 + 0.95 * vx), -sentido * rng.randf_range(1.2, 2.4) * forca)
			_causa_voo = "lombada"
			_dica_equilibrio()
		else:
			moto.velocity.y = -150.0


func _checar_bocas(x: float, vx: float) -> void:
	for b in bocas:
		if not _cruzou(b.cx(), x):
			continue
		if vx > 150.0:
			var lado := 1.0 if rng.randf() < 0.5 else -1.0
			moto.lancar(-380.0, lado * rng.randf_range(2.4, 3.6))
			_causa_voo = "boca"
			_dica_equilibrio()
		else:
			moto.velocity.x *= 0.5


func _dica_equilibrio() -> void:
	if _ajuda_equilibrio < 3:
		_ajuda_equilibrio += 1
		aviso.emit("EQUILIBRA!  Use < A  e  D >", Config.COR_LARANJA_CLARO)


func _on_pousou(diferenca: float, tempo_ar: float, caiu: bool) -> void:
	var causa := _causa_voo
	_causa_voo = ""
	if caiu:
		var pen := Config.PENALIDADE_QUEDA_LOMBADA if causa == "lombada" else Config.PENALIDADE_QUEDA_BOCA
		var frase := "Voou e capotou!" if causa == "lombada" else "Caiu no buraco!"
		placar.emit(-pen, 0.0, "%s -%d pts" % [frase, pen], Config.COR_VERMELHO)
	elif causa == "lombada":
		var bonus := 10 + int(tempo_ar * 25.0)
		if absf(diferenca) < 0.2:
			bonus = int(bonus * 1.5)
			placar.emit(bonus, 0.0, "Pouso perfeito! +%d pts" % bonus, Config.COR_LARANJA_CLARO)
		else:
			placar.emit(bonus, 0.0, "Pousou! +%d pts" % bonus, Config.COR_LARANJA_CLARO)
	elif causa == "boca":
		placar.emit(10, 0.0, "Segurou firme! +10 pts", Config.COR_LARANJA_CLARO)


func _checar_blitz(x: float, vx: float) -> void:
	for z in blitzes:
		if not z.contem(x):
			z.sorteado = false
			z.vel_vista = 0.0
			continue
		z.vel_vista = maxf(z.vel_vista, vx)
		if z.sorteado or not _cruzou(z.cx(), x):
			continue
		z.sorteado = true
		# Devagar: chance baixa. Rápido: a chance sobe bastante.
		var excesso := clampf((z.vel_vista - 180.0) / (moto.vel_max - 180.0), 0.0, 1.0)
		var chance: float = dif.chance_blitz + excesso * 0.65
		if rng.randf() < chance:
			moto.segurar(rng.randf_range(3.0, 5.0))
			var frase := "Passou voando, né?" if excesso > 0.3 else "Abordagem de rotina."
			aviso.emit("BLITZ! %s \"Documento, por favor.\"" % frase, Config.COR_VERMELHO)
		elif excesso <= 0.0:
			aviso.emit("Passou na blitz de boa.", Config.COR_CINZA_CLARO)


func _checar_cruzamentos(x: float) -> void:
	for c in cruzamentos:
		if c.atingiu_neste_ciclo or not c.perigoso() or moto.caido:
			continue
		if absf(x - c.cx()) < 100.0 and absf(moto.position.y - chao.altura_em(c.cx())) < 70.0:
			c.atingiu_neste_ciclo = true
			var sentido := signf(moto.velocity.x) if absf(moto.velocity.x) > 10.0 else float(moto.direcao)
			moto.derrubar(1.2, -sentido * 380.0)
			placar.emit(-Config.PENALIDADE_CRUZAMENTO, 0.0,
				"Furou o sinal! -%d pts" % Config.PENALIDADE_CRUZAMENTO, Config.COR_VERMELHO)


# ---------------------------------------------------------------- CET

func _atualizar_cet(delta: float, x: float) -> void:
	if _cet_gatilho >= 0.0 and _tempo >= _cet_gatilho and cet == null:
		_soltar_cet(x)
	if cet == null:
		return
	cet_restante -= delta
	var dx: float = x - cet.position.x
	var vmax: float = moto.vel_max * dif.vel_cet
	for t in terras:
		if t.contem(cet.position.x):
			vmax *= 0.6
	cet.vel = move_toward(cet.vel, signf(dx) * vmax, 420.0 * delta)
	cet.position.x = clampf(cet.position.x + cet.vel * delta, 40.0, Gerador.LARGURA - 40.0)
	cet.position.y = chao.altura_em(cet.position.x)
	var y_frente: float = chao.altura_em(cet.position.x + 40.0)
	cet.angulo = atan2(y_frente - cet.position.y, 40.0)

	if absf(dx) < 70.0 and absf(moto.position.y - cet.position.y) < 80.0:
		moto.segurar(3.0)
		placar.emit(-Config.PENALIDADE_CET, -Config.TEMPO_PERDIDO_CET,
			"MULTADO pela CET! -%d pts  -%ds" % [Config.PENALIDADE_CET, int(Config.TEMPO_PERDIDO_CET)],
			Config.COR_VERMELHO)
		_remover_cet()
	elif cet_restante <= 0.0:
		placar.emit(Config.BONUS_FUGA_CET, 0.0, "Despistou a CET! +%d pts" % Config.BONUS_FUGA_CET,
			Config.COR_LARANJA_CLARO)
		_remover_cet()


func _soltar_cet(x: float) -> void:
	_cet_gatilho = -1.0
	var lado := -float(moto.direcao)
	var inicio := x + lado * 1000.0
	if inicio < 60.0 or inicio > Gerador.LARGURA - 60.0:
		inicio = x - lado * 1000.0
	cet = CarroCet.new()
	cet.position = Vector2(clampf(inicio, 60.0, Gerador.LARGURA - 60.0), chao.altura_em(inicio))
	add_child(cet)
	cet_restante = Config.DURACAO_CET
	aviso.emit("CNH VENCIDA! A CET tá na sua cola!", Config.COR_VERMELHO)


func _remover_cet() -> void:
	if cet:
		cet.queue_free()
	cet = null
