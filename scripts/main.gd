extends Node2D
## Cena principal: monta a fase, controla o fluxo de pedidos, tempo, gasolina e pontuação.
## Os obstáculos do M2 ficam em obstaculos.gd; o mapa é gerado por gerador_fase.gd.

const Config := preload("res://scripts/game_config.gd")
const Gerador := preload("res://scripts/gerador_fase.gd")
const Moto := preload("res://scripts/moto.gd")
const Chao := preload("res://scripts/ground.gd")
const Bloco := preload("res://scripts/block.gd")
const Local := preload("res://scripts/location.gd")
const Fachada := preload("res://scripts/fachada.gd")
const Skyline := preload("res://scripts/skyline.gd")
const Obstaculos := preload("res://scripts/obstaculos.gd")
const Chuva := preload("res://scripts/chuva.gd")
const Hud := preload("res://scripts/hud.gd")
const Telas := preload("res://scripts/screens.gd")
const PopupCodigo := preload("res://scripts/code_popup.gd")
const Toque := preload("res://scripts/touch_controls.gd")

const LARGURA_FASE := Gerador.LARGURA
const PX_POR_METRO := 16.0
const VEL_PARADO := 35.0

enum Estado { MENU, JOGANDO, CODIGO, FIM }
enum Etapa { IR_RESTAURANTE, COLETANDO, IR_CLIENTE, ESPERANDO_CLIENTE }

## Dificuldade a iniciar direto após recarregar a cena ("Jogar de novo").
static var dificuldade_pendente := ""
## Semente do mapa a reaproveitar após recarregar ("Jogar de novo" repete o mesmo mapa).
static var semente_pendente := 0

var estado := Estado.MENU
var dif_id := ""
var dif: Dictionary = {}
var rng := RandomNumberGenerator.new()
var fase: Dictionary = {}   # layout gerado (ver gerador_fase.gd)

var moto  # Moto
var camera: Camera2D
var chao  # Chao
var obst  # Obstaculos
var chuva  # Chuva
var restaurantes: Array = []
var casas: Array = []
var postos: Array = []
var fachadas_posto: Array = []   # tapam a vaga quando o posto não aparece
var camadas_fundo: Array = []   # [[Node2D, fator]]

var hud  # Hud
var telas  # Telas
var popup  # PopupCodigo

var tempo_restante := 0.0
var pontos := 0
var entregas := 0
var gasolina := 0.0
var etapa := Etapa.IR_RESTAURANTE
var restaurante_atual  # Local
var casa_atual  # Local
var codigo_atual := ""
var prazo_total := 0.0
var prazo_restante := 0.0
var progresso := 0.0
var espera_total := 0.0
var _avisou_tanque_cheio := false


func _ready() -> void:
	rng.randomize()
	_configurar_input()
	fase = Gerador.new().gerar(_escolher_semente())
	_criar_fundo()
	_criar_mundo()
	_criar_moto()
	_criar_ui()
	if dificuldade_pendente != "":
		var d := dificuldade_pendente
		dificuldade_pendente = ""
		_iniciar(d)
	else:
		telas.mostrar_menu()


# ---------------------------------------------------------------- montagem

func _configurar_input() -> void:
	var mapa := {
		"esquerda": [KEY_A, KEY_LEFT],
		"direita": [KEY_D, KEY_RIGHT],
		"freio": [KEY_S, KEY_DOWN, KEY_SHIFT],
		"pulo": [KEY_SPACE, KEY_W, KEY_UP],
	}
	for acao in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(acao, ev)


## Mapa novo a cada partida, a não ser que venha de "Jogar de novo" ou de -- --semente=N.
func _escolher_semente() -> int:
	var s := semente_pendente
	semente_pendente = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--semente="):
			s = a.substr(10).to_int()
	return s if s > 0 else rng.randi_range(1, 999999)


func _criar_fundo() -> void:
	var ceu := CanvasLayer.new()
	ceu.layer = -100
	add_child(ceu)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.1, 0.09, 0.09))
	grad.set_color(1, Color(0.55, 0.25, 0.1))
	grad.add_point(0.6, Color(0.3, 0.16, 0.11))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ceu.add_child(rect)

	var defs := [
		[0.15, 7, Color(0.2, 0.13, 0.11), Color(0.9, 0.5, 0.2, 0.25), 200.0, 420.0, 0.12],
		[0.4, 13, Color(0.13, 0.11, 0.1), Color(0.95, 0.6, 0.25, 0.5), 120.0, 330.0, 0.22],
	]
	for def in defs:
		var s := Skyline.new()
		var fator: float = def[0]
		s.semente = def[1]
		s.cor = def[2]
		s.cor_janela = def[3]
		s.altura_min = def[4]
		s.altura_max = def[5]
		s.chance_janela = def[6]
		s.base_y = 600.0
		s.x_inicio = -1500.0
		s.x_fim = LARGURA_FASE * fator + 1500.0
		add_child(s)
		camadas_fundo.append([s, fator])


func _criar_mundo() -> void:
	chao = Chao.new()
	chao.configurar(PackedVector2Array(fase.chao))

	for r in fase.restaurantes:
		restaurantes.append(_criar_local("restaurante", r[0], r[1], Gerador.LARG_LOCAL.restaurante))
	for c in fase.casas:
		casas.append(_criar_local("casa", c[0], c[1], Gerador.LARG_LOCAL.casa))
	for x in fase.postos:
		var f = _criar_fachada(x - 120.0, x + 120.0, int(x))
		fachadas_posto.append(f)
		postos.append(_criar_local("posto", x, "Posto", Gerador.LARG_LOCAL.posto))
	_preencher_rua()

	# Chão depois dos prédios (postes na frente), obstáculos por cima do chão
	add_child(chao)
	obst = Obstaculos.new()
	add_child(obst)
	obst.construir(chao, rng, fase)
	obst.aviso.connect(func(t: String, c: Color) -> void: hud.aviso(t, c))
	obst.placar.connect(_on_placar)

	for o in fase.blocos:
		var b := Bloco.new()
		b.tipo = o[1]
		b.tamanho = o[2]
		b.position = Vector2(o[0], chao.altura_em(o[0]))
		add_child(b)

	for x in [0.0, LARGURA_FASE]:
		var parede := StaticBody2D.new()
		var forma := CollisionShape2D.new()
		var limite := WorldBoundaryShape2D.new()
		limite.normal = Vector2.RIGHT if x == 0.0 else Vector2.LEFT
		forma.shape = limite
		parede.add_child(forma)
		parede.position = Vector2(x, 0)
		add_child(parede)


func _criar_local(tipo: String, x: float, nome: String, largura: float):
	var l := Local.new()
	l.tipo = tipo
	l.nome = nome
	l.largura = largura
	l.position = Vector2(x, chao.altura_em(x))
	add_child(l)
	return l


## Enche os espaços vazios entre os pontos de entrega com construções decorativas.
func _preencher_rua() -> void:
	var ocupados := []
	for l in restaurantes + casas + postos:
		ocupados.append([l.position.x - l.largura / 2.0 - 6.0, l.position.x + l.largura / 2.0 + 6.0])
	for x in fase.cruzamentos:
		ocupados.append([x - 135.0, x + 150.0])
	ocupados.append([LARGURA_FASE - 10.0, LARGURA_FASE + 10.0])
	ocupados.sort_custom(func(a, b) -> bool: return a[0] < b[0])

	var r := RandomNumberGenerator.new()
	r.seed = fase.semente   # mesma semente, mesmas fachadas
	var cursor := 10.0
	for seg in ocupados:
		var x := cursor
		var fim: float = seg[0]
		while fim - x >= 80.0:
			var w := r.randf_range(120.0, 220.0)
			if fim - x - w < 80.0:
				w = fim - x
			if w > 260.0:
				w = 200.0
			_criar_fachada(x, x + w - 4.0, r.randi()).tipo = Fachada.TIPOS[r.randi() % Fachada.TIPOS.size()]
			x += w
		cursor = maxf(cursor, seg[1])


func _criar_fachada(x0: float, x1: float, semente: int):
	var f := Fachada.new()
	f.largura = x1 - x0
	f.semente = semente
	f.position = Vector2((x0 + x1) / 2.0, maxf(chao.altura_em(x0), chao.altura_em(x1)))
	add_child(f)
	return f


func _criar_moto() -> void:
	moto = Moto.new()
	moto.position = Vector2(200, 560)
	add_child(moto)
	camera = Camera2D.new()
	camera.position = Vector2(0, -90)
	camera.limit_left = 0
	camera.limit_right = int(LARGURA_FASE)
	camera.limit_bottom = 720
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	moto.add_child(camera)


func _criar_ui() -> void:
	chuva = Chuva.new()
	chuva.visible = false
	add_child(chuva)
	hud = Hud.new()
	hud.visible = false
	add_child(hud)
	popup = PopupCodigo.new()
	add_child(popup)
	popup.acertou.connect(_on_codigo_certo)
	popup.errou.connect(_on_codigo_errado)
	add_child(Toque.new())
	telas = Telas.new()
	add_child(telas)
	telas.iniciar.connect(_iniciar)
	telas.jogar_de_novo.connect(func() -> void:
		dificuldade_pendente = dif_id
		semente_pendente = fase.semente
		get_tree().reload_current_scene())
	telas.voltar_menu.connect(func() -> void: get_tree().reload_current_scene())


# ---------------------------------------------------------------- fluxo

func _iniciar(id: String) -> void:
	dif_id = id
	dif = Config.DIFICULDADES[id]
	telas.limpar()
	hud.visible = true
	moto.cor_bag = dif.cor
	moto.cor_bag_detalhe = dif.cor_detalhe
	moto.painel_bag = dif.painel_bag
	moto.controles_ativos = true
	tempo_restante = dif.tempo_fase
	pontos = 0
	entregas = 0
	gasolina = Config.GASOLINA_INICIAL

	# Postos em posições aleatórias a cada partida; a vaga vazia vira outra construção.
	var ordem := range(postos.size())
	ordem.shuffle()
	for j in postos.size():
		var ativo: bool = ordem.find(j) < Config.POSTOS_ATIVOS
		postos[j].ativo = ativo
		postos[j].visible = ativo
		fachadas_posto[j].visible = not ativo

	obst.iniciar(moto, dif)
	chuva.visible = obst.chovendo

	estado = Estado.JOGANDO
	_novo_pedido()
	var msg := "Bora! %d entregas até o fim do rush." % Config.ENTREGAS_FASE
	if obst.chovendo:
		msg += "\nTá chovendo: o freio tá fraco!"
	hud.aviso(msg, Config.COR_LARANJA_CLARO)


func _novo_pedido() -> void:
	# Sorteia entre os 2 restaurantes mais perto (sem repetir o último)
	var anterior = restaurante_atual
	var opcoes := restaurantes.filter(func(r) -> bool: return r != anterior)
	var x: float = moto.position.x
	opcoes.sort_custom(func(a, b) -> bool: return absf(a.position.x - x) < absf(b.position.x - x))
	restaurante_atual = opcoes[rng.randi_range(0, mini(1, opcoes.size() - 1))]
	casa_atual = null
	etapa = Etapa.IR_RESTAURANTE
	_atualizar_destaques()


func _coletar() -> void:
	restaurante_atual.progresso = -1.0
	# Casa nem perto demais nem do outro lado do mapa
	var opcoes := casas.filter(func(c) -> bool:
		var d := absf(c.position.x - restaurante_atual.position.x)
		return d > 1500.0 and d < 5000.0)
	if opcoes.is_empty():
		opcoes = casas
	casa_atual = opcoes[rng.randi_range(0, opcoes.size() - 1)]
	var dist := absf(casa_atual.position.x - restaurante_atual.position.x)
	prazo_total = dif.prazo_base + dist / dif.prazo_px_por_s
	prazo_restante = prazo_total
	codigo_atual = "%04d" % rng.randi_range(0, 9999)
	etapa = Etapa.IR_CLIENTE
	_atualizar_destaques()
	hud.aviso("Pedido na bag! Entregar no Nº %s" % casa_atual.nome, Config.COR_LARANJA_CLARO)


func _atualizar_destaques() -> void:
	for l in restaurantes + casas:
		l.destacado = false
	if etapa == Etapa.IR_RESTAURANTE or etapa == Etapa.COLETANDO:
		restaurante_atual.destacado = true
		restaurante_atual.rotulo_destaque = "COLETA"
	elif casa_atual:
		casa_atual.destacado = true
		casa_atual.rotulo_destaque = "ENTREGA"


func _on_codigo_certo() -> void:
	popup.fechar()
	casa_atual.cliente_visivel = false
	casa_atual.progresso = -1.0
	var ganho := 0
	if prazo_restante > 0.0:
		var bonus_tempo: float = prazo_restante * dif.bonus_mult
		tempo_restante += bonus_tempo
		ganho = Config.PONTOS_ENTREGA + int(prazo_restante * Config.PONTOS_POR_SEG_SOBRA)
		hud.aviso("Entregue adiantado! +%d pts  +%ds" % [ganho, int(bonus_tempo)], Config.COR_LARANJA_CLARO)
	else:
		ganho = Config.PONTOS_ATRASADO
		hud.aviso("Entregue atrasado... +%d pts" % ganho, Config.COR_CINZA_CLARO)
	pontos += ganho
	entregas += 1
	moto.controles_ativos = true
	estado = Estado.JOGANDO
	if entregas >= Config.ENTREGAS_FASE:
		_fim(true, "Bag vazia, tanque na reserva e o rush vencido.")
	else:
		_novo_pedido()


func _on_codigo_errado() -> void:
	pontos = maxi(0, pontos - Config.PENALIDADE_CODIGO)
	hud.aviso("Código errado! -%d pts" % Config.PENALIDADE_CODIGO, Config.COR_VERMELHO)


## Pontos/tempo vindos dos obstáculos (quedas, multas, bônus de pouso...).
func _on_placar(delta_pontos: int, delta_tempo: float, texto: String, cor: Color) -> void:
	if estado != Estado.JOGANDO and estado != Estado.CODIGO:
		return
	pontos = maxi(0, pontos + delta_pontos)
	tempo_restante += delta_tempo
	hud.aviso(texto, cor)


func _fim(vitoria: bool, mensagem: String) -> void:
	estado = Estado.FIM
	moto.controles_ativos = false
	popup.fechar()
	var bonus := 0
	if vitoria:
		bonus = int(tempo_restante) * Config.PONTOS_POR_SEG_RESTANTE
		pontos += bonus
	var linhas := "Entregas: %d/%d     Pontos: %d" % [entregas, Config.ENTREGAS_FASE, pontos]
	if vitoria:
		linhas += "\n(inclui +%d pelo tempo que sobrou)" % bonus
	linhas += "\nBag: %s (%s)     Mapa nº %d" % [dif.nome, dif.rotulo, fase.semente]
	var titulo := "TURNO FECHADO!" if vitoria else "GAME OVER"
	telas.mostrar_fim(vitoria, titulo, mensagem, linhas)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if estado == Estado.JOGANDO or estado == Estado.CODIGO:
		tempo_restante -= delta
		if etapa == Etapa.IR_CLIENTE or etapa == Etapa.ESPERANDO_CLIENTE:
			prazo_restante -= delta
		obst.processar(delta, estado == Estado.CODIGO)
		_consumir_gasolina(delta)
		if gasolina <= 0.0:
			gasolina = 0.0
			_fim(false, "SEM GASOLINA!\n" + _sortear(Config.MENSAGENS_SEM_GASOLINA))
		elif tempo_restante <= 0.0:
			tempo_restante = 0.0
			_fim(false, "TEMPO ESGOTADO!\n" + _sortear(Config.MENSAGENS_TEMPO))
		elif estado == Estado.JOGANDO:
			_interacoes(delta)

	# Câmera olha um pouco à frente do movimento
	camera.offset.x = lerpf(camera.offset.x, clampf(moto.velocity.x * 0.4, -220.0, 220.0), 2.0 * delta)
	_atualizar_parallax()
	if estado != Estado.MENU:
		_atualizar_hud()


func _consumir_gasolina(delta: float) -> void:
	var frac: float = absf(moto.velocity.x) / moto.vel_max
	gasolina -= (Config.CONSUMO_PARADO + Config.CONSUMO_VELOCIDADE_MAX * frac) * delta


func _interacoes(delta: float) -> void:
	var parado: bool = absf(moto.velocity.x) < VEL_PARADO and moto.is_on_floor() and not moto.caido

	# Posto: parado dentro da área enche o tanque (~10 s do zero ao cheio)
	for p in postos:
		var abastecendo: bool = p.ativo and parado and _moto_em(p) and gasolina < Config.GASOLINA_MAX
		if abastecendo:
			gasolina = minf(Config.GASOLINA_MAX,
				gasolina + Config.GASOLINA_MAX / Config.TEMPO_ENCHER_TANQUE * delta)
			p.texto_progresso = "Abastecendo..."
			p.progresso = gasolina / Config.GASOLINA_MAX
			_avisou_tanque_cheio = false
		elif p.progresso >= 0.0:
			p.progresso = -1.0
			if gasolina >= Config.GASOLINA_MAX and not _avisou_tanque_cheio:
				_avisou_tanque_cheio = true
				hud.aviso("Tanque cheio!", Config.COR_LARANJA_CLARO)

	match etapa:
		Etapa.IR_RESTAURANTE:
			if parado and _moto_em(restaurante_atual):
				etapa = Etapa.COLETANDO
				progresso = 0.0
				espera_total = 1.5
				restaurante_atual.texto_progresso = "Pegando o pedido..."
				if rng.randf() < dif.chance_pedido_atrasado:
					espera_total += rng.randf_range(3.0, 6.0)
					restaurante_atual.texto_progresso = "Pedido atrasado..."
					hud.aviso("Pedido atrasado! A cozinha tá enrolando...", Config.COR_VERMELHO)
		Etapa.COLETANDO:
			if not _moto_em(restaurante_atual):
				etapa = Etapa.IR_RESTAURANTE
				restaurante_atual.progresso = -1.0
				hud.aviso("Volta! O pedido ainda não saiu.", Config.COR_VERMELHO)
			else:
				progresso += delta
				restaurante_atual.progresso = progresso / espera_total
				if progresso >= espera_total:
					_coletar()
		Etapa.IR_CLIENTE:
			if parado and _moto_em(casa_atual):
				etapa = Etapa.ESPERANDO_CLIENTE
				progresso = 0.0
				espera_total = rng.randf_range(0.6, 1.2)
				casa_atual.texto_progresso = "Chamando o cliente..."
				if rng.randf() < dif.chance_cliente_demora:
					espera_total += rng.randf_range(4.0, 8.0)
					casa_atual.texto_progresso = "\"Tô descendo!\""
					hud.aviso("O cliente tá \"descendo\"...", Config.COR_VERMELHO)
		Etapa.ESPERANDO_CLIENTE:
			if not _moto_em(casa_atual):
				etapa = Etapa.IR_CLIENTE
				casa_atual.progresso = -1.0
			else:
				progresso += delta
				casa_atual.progresso = progresso / espera_total
				if progresso >= espera_total:
					casa_atual.progresso = -1.0
					casa_atual.cliente_visivel = true
					estado = Estado.CODIGO
					moto.controles_ativos = false
					moto.parar()
					popup.abrir(codigo_atual, dif.distorcao)


func _moto_em(local) -> bool:
	var dx: float = absf(moto.position.x - local.position.x)
	var dy: float = absf(moto.position.y - local.position.y)
	return dx < local.largura * 0.5 and dy < 40.0


func _atualizar_parallax() -> void:
	var centro := camera.get_screen_center_position()
	for c in camadas_fundo:
		var fator: float = c[1]
		c[0].position = Vector2(centro.x * (1.0 - fator), (centro.y - 360.0) * (1.0 - fator) * 0.5)


func _atualizar_hud() -> void:
	var texto := ""
	var cor := Config.COR_LARANJA_CLARO
	match etapa:
		Etapa.IR_RESTAURANTE:
			texto = "COLETAR em %s" % restaurante_atual.nome
		Etapa.COLETANDO:
			texto = "Esperando o pedido em %s..." % restaurante_atual.nome
		Etapa.IR_CLIENTE, Etapa.ESPERANDO_CLIENTE:
			if prazo_restante >= 0.0:
				texto = "ENTREGAR no Nº %s   PRAZO %ds" % [casa_atual.nome, ceili(prazo_restante)]
				if prazo_restante < 5.0:
					cor = Config.COR_VERMELHO
			else:
				texto = "ENTREGAR no Nº %s   ATRASADO %ds" % [casa_atual.nome, ceili(-prazo_restante)]
				cor = Config.COR_VERMELHO

	var alvos := []
	var destino = casa_atual if casa_atual else restaurante_atual
	if destino:
		alvos.append({
			"pos": destino.position + Vector2(0, -80),
			"cor": Config.COR_LARANJA_CLARO,
			"texto": "%dm" % int(absf(destino.position.x - moto.position.x) / PX_POR_METRO),
		})
	if gasolina / Config.GASOLINA_MAX < 0.3:
		var mais_perto = null
		for p in postos:
			if p.ativo and (mais_perto == null
					or absf(p.position.x - moto.position.x) < absf(mais_perto.position.x - moto.position.x)):
				mais_perto = p
		if mais_perto:
			alvos.append({
				"pos": mais_perto.position + Vector2(0, -40),
				"cor": Config.COR_VERMELHO,
				"texto": "POSTO %dm" % int(absf(mais_perto.position.x - moto.position.x) / PX_POR_METRO),
			})
	if obst.cet:
		alvos.append({"pos": obst.cet.position + Vector2(0, -40), "cor": Config.COR_VERMELHO, "texto": "CET"})

	# Alerta fixo (some sozinho quando a situação acaba)
	var alerta := ""
	if moto.instavel:
		alerta = "EQUILIBRA!   < A        D >"
	elif moto.caido:
		alerta = "Levantando a moto..."
	elif moto.bloqueada():
		alerta = "Parado..."
	elif obst.cet:
		alerta = "CET NA COLA! Aguenta %ds" % ceili(obst.cet_restante)

	hud.atualizar({
		"tempo": tempo_restante,
		"pontos": pontos,
		"entregas": entregas,
		"total": Config.ENTREGAS_FASE,
		"gasolina": gasolina / Config.GASOLINA_MAX,
		"texto_pedido": texto,
		"cor_pedido": cor,
		"alvos": alvos,
		"alerta": alerta,
	})


func _sortear(lista: Array) -> String:
	return lista[rng.randi_range(0, lista.size() - 1)]
