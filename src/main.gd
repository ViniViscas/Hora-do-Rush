extends Node2D
## Cena principal: monta a fase, controla o fluxo de pedidos, tempo, gasolina e pontuação.
## Os obstáculos do M2 ficam em obstaculos.gd; o mapa é gerado por gerador_fase.gd.
## A campanha (fases em sequência, dinheiro e melhorias) fica salva por progresso.gd.

const Config := preload("res://src/game_config.gd")
const Gerador := preload("res://src/gerador_fase.gd")
const Moto := preload("res://src/moto.gd")
const Chao := preload("res://src/ground.gd")
const Bloco := preload("res://src/block.gd")
const Local := preload("res://src/location.gd")
const Fachada := preload("res://src/fachada.gd")
const Skyline := preload("res://src/skyline.gd")
const Obstaculos := preload("res://src/obstaculos.gd")
const Chuva := preload("res://src/chuva.gd")
const Hud := preload("res://src/hud.gd")
const Telas := preload("res://src/screens.gd")
const PopupCodigo := preload("res://src/code_popup.gd")
const Toque := preload("res://src/touch_controls.gd")
const Progresso := preload("res://src/progresso.gd")
const Som := preload("res://src/som.gd")
const Efeitos := preload("res://src/efeitos.gd")
const Historia := preload("res://src/historia.gd")

const LARGURA_FASE := Gerador.LARGURA
const PX_POR_METRO := 16.0
const VEL_PARADO := 35.0

enum Estado { MENU, JOGANDO, CODIGO, FIM }
enum Etapa { IR_RESTAURANTE, COLETANDO, IR_CLIENTE, ESPERANDO_CLIENTE }

## Fase a iniciar direto após recarregar a cena (cada fase monta um mapa novo).
static var dificuldade_pendente := ""
static var fase_pendente := 0

var estado := Estado.MENU
var dif_id := ""
var dif: Dictionary = {}
var rng := RandomNumberGenerator.new()
var fase: Dictionary = {}   # layout gerado (ver gerador_fase.gd)
var n_fase := 0             # índice em Config.FASES
var def_fase: Dictionary = {}
var prog: Dictionary = {}   # progresso da campanha da bag (ver progresso.gd)
var meta_entregas := 0
var gas_max := Config.GASOLINA_MAX
var mult_prazo := 1.0

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
var _avisou_reserva := false
var _abastecendo := false
var efeitos  # Efeitos
var _olhar := 0.0           # câmera olhando à frente do movimento
var _tremor := 0.0          # segundos de tremor restantes
var _tremor_forca := 0.0


func _ready() -> void:
	rng.randomize()
	_configurar_input()
	Som.iniciar()
	var jogar := dificuldade_pendente
	dificuldade_pendente = ""
	if jogar != "":
		dif_id = jogar
		n_fase = fase_pendente
		prog = Progresso.carregar(dif_id)
		fase = Gerador.new().gerar(_escolher_semente(prog.sementes[n_fase]),
			Config.FASES[n_fase].quantidade)
	else:
		fase = Gerador.new().gerar(_escolher_semente(rng.randi_range(1, 999999)))
	_criar_fundo()
	_criar_mundo()
	_criar_moto()
	_criar_ui()
	if jogar != "":
		# Cartão da história antes da fase, só na primeira vez que ela é jogada
		var chave := "fase_%s_%d" % [jogar, n_fase]
		if Progresso.visto(chave):
			_iniciar(jogar, n_fase)
		else:
			Som.musica("menu")
			telas.mostrar_cutscene(Historia.antes_da_fase(jogar, n_fase), func() -> void:
				Progresso.marcar_visto(chave)
				_iniciar(jogar, n_fase))
	else:
		telas.mostrar_menu(_bags_bloqueadas())
		Som.musica("menu")


# ---------------------------------------------------------------- montagem

func _configurar_input() -> void:
	var mapa := {
		"esquerda": [KEY_A, KEY_LEFT],
		"direita": [KEY_D, KEY_RIGHT],
		"freio": [KEY_S, KEY_DOWN, KEY_SHIFT],
		"pulo": [KEY_SPACE, KEY_W, KEY_UP],
		"pausa": [KEY_P, KEY_ESCAPE],
	}
	for acao in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(acao, ev)


## Cada fase da campanha tem seu mapa; -- --semente=N força um mapa específico (testes).
func _escolher_semente(padrao: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--semente="):
			return a.substr(10).to_int()
	return padrao


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
	efeitos = Efeitos.new()
	add_child(efeitos)
	moto.aterrissou.connect(func(forca: float) -> void:
		efeitos.poeira(moto.position, forca)
		if forca > 0.6:
			tremer(3.0 + 5.0 * forca, 0.2))
	moto.derrubada.connect(func() -> void:
		efeitos.faiscas(moto.position + Vector2(0, -12))
		tremer(10.0, 0.4))


## Treme a câmera (queda, multa...). Um tremor mais forte substitui um mais fraco.
func tremer(forca: float, duracao: float) -> void:
	if forca >= _tremor_forca * (_tremor / maxf(duracao, 0.01)):
		_tremor_forca = forca
		_tremor = duracao


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
	telas.escolher_bag.connect(func(id: String) -> void:
		dif_id = id
		prog = Progresso.carregar(id)
		Progresso.salvar(id, prog)   # guarda as sementes sorteadas das fases
		if Progresso.visto("abertura_" + id):
			telas.mostrar_campanha(Config.DIFICULDADES[id], prog)
		else:
			_mostrar_intro())
	telas.ver_historia.connect(_mostrar_intro)
	telas.jogar_fase.connect(func(i: int) -> void:
		get_tree().paused = false
		dificuldade_pendente = dif_id
		fase_pendente = i
		get_tree().reload_current_scene())
	telas.abrir_oficina.connect(func() -> void: telas.mostrar_oficina(Config.DIFICULDADES[dif_id], prog))
	telas.comprar.connect(func(melhoria: String) -> void:
		var ok := Progresso.comprar(dif_id, prog, melhoria)
		Som.tocar("compra" if ok else "erro")
		telas.reagir_compra(melhoria, ok, prog))
	telas.voltar_campanha.connect(func() -> void: telas.mostrar_campanha(Config.DIFICULDADES[dif_id], prog))
	telas.voltar_menu.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	telas.pedir_pausa.connect(_alternar_pausa)
	telas.continuar.connect(_alternar_pausa)


# ---------------------------------------------------------------- fluxo

func _iniciar(id: String, indice_fase: int) -> void:
	dif_id = id
	n_fase = indice_fase
	def_fase = Config.FASES[n_fase]
	# A fase ajusta as chances da bag (ex.: fase 1 sem blitz, sem chuva, sem CET)
	dif = Config.DIFICULDADES[id].duplicate()
	dif.chance_chuva = minf(1.0, dif.chance_chuva * def_fase.chuva)
	dif.chance_cet = minf(1.0, dif.chance_cet * def_fase.cet)
	dif.chance_blitz = dif.chance_blitz * def_fase.blitz
	meta_entregas = def_fase.entregas
	if prog.is_empty():
		prog = Progresso.carregar(id)
	telas.limpar()
	hud.visible = true
	moto.cor_bag = dif.cor
	moto.cor_bag_detalhe = dif.cor_detalhe
	moto.painel_bag = dif.painel_bag
	moto.controles_ativos = true
	_aplicar_melhorias()
	tempo_restante = dif.tempo_fase * def_fase.tempo * meta_entregas / 5.0
	pontos = 0
	entregas = 0
	gasolina = Config.GASOLINA_INICIAL / Config.GASOLINA_MAX * gas_max

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
	Som.musica("partida")
	_novo_pedido()
	var msg := "FASE %d: %s\n%d entregas até o fim do rush." % [n_fase + 1, def_fase.nome, meta_entregas]
	if obst.chovendo:
		msg += "\nTá chovendo: o freio tá fraco!"
	hud.aviso(msg, Config.COR_LARANJA_CLARO)


## Melhorias compradas na oficina (progresso.gd) mexem nos atributos da moto.
func _aplicar_melhorias() -> void:
	var motor := Progresso.bonus(prog, "motor")
	moto.vel_max *= 1.0 + motor
	moto.aceleracao *= 1.0 + motor * 10.0 / 7.0
	moto.forca_freio *= 1.0 + Progresso.bonus(prog, "freio")
	moto.limite_queda += Progresso.bonus(prog, "amortecedor")
	gas_max = Config.GASOLINA_MAX * (1.0 + Progresso.bonus(prog, "tanque"))
	mult_prazo = 1.0 + Progresso.bonus(prog, "bag")


func _novo_pedido() -> void:
	# Sorteia entre os 2 restaurantes mais perto (sem repetir o último)
	var anterior = restaurante_atual
	var opcoes := restaurantes.filter(func(r) -> bool: return r != anterior)
	var x: float = moto.position.x
	opcoes.sort_custom(func(a, b) -> bool: return absf(a.position.x - x) < absf(b.position.x - x))
	restaurante_atual = opcoes[rng.randi_range(0, mini(1, opcoes.size() - 1))]
	casa_atual = null
	etapa = Etapa.IR_RESTAURANTE
	obst.novo_pedido()
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
	prazo_total = (dif.prazo_base + dist / dif.prazo_px_por_s) * mult_prazo
	prazo_restante = prazo_total
	codigo_atual = "%04d" % rng.randi_range(0, 9999)
	etapa = Etapa.IR_CLIENTE
	_atualizar_destaques()
	Som.tocar("coleta")
	efeitos.confete(restaurante_atual.position + Vector2(0, -150), [Config.COR_LARANJA, Config.COR_PAPEL])
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
	Som.abafar(false)
	casa_atual.cliente_visivel = false
	casa_atual.progresso = -1.0
	var ganho := 0
	if prazo_restante > 0.0:
		var bonus_tempo: float = prazo_restante * dif.bonus_mult
		tempo_restante += bonus_tempo
		ganho = Config.PONTOS_ENTREGA + int(prazo_restante * Config.PONTOS_POR_SEG_SOBRA)
		Som.tocar("entrega")
		hud.aviso("Entregue adiantado! +%d pts  +%ds" % [ganho, int(bonus_tempo)], Config.COR_LARANJA_CLARO)
	else:
		ganho = Config.PONTOS_ATRASADO
		Som.tocar("entrega", -4.0, 0.8)
		hud.aviso("Entregue atrasado... +%d pts" % ganho, Config.COR_CINZA_CLARO)
	pontos += ganho
	entregas += 1
	var acima: Vector2 = casa_atual.position + Vector2(0, -110)
	efeitos.confete(acima)
	efeitos.texto(acima + Vector2(0, -40), "+%d" % ganho, Config.COR_LARANJA_CLARO, 30)
	if prazo_restante > 0.0:
		efeitos.texto(acima + Vector2(0, -6), "+%ds" % int(prazo_restante * dif.bonus_mult), Config.COR_PAPEL, 22)
	moto.controles_ativos = true
	estado = Estado.JOGANDO
	if entregas >= meta_entregas:
		_fim(true, "Bag vazia, tanque na reserva e o rush vencido.")
	else:
		_novo_pedido()


func _on_codigo_errado() -> void:
	Som.tocar("erro")
	pontos = maxi(0, pontos - Config.PENALIDADE_CODIGO)
	hud.aviso("Código errado! -%d pts" % Config.PENALIDADE_CODIGO, Config.COR_VERMELHO)


## Abertura do capítulo da bag escolhida (história). Depois vai para as fases.
func _mostrar_intro() -> void:
	telas.mostrar_cutscene(Historia.abertura(dif_id), func() -> void:
		Progresso.marcar_visto("abertura_" + dif_id)
		telas.mostrar_campanha(Config.DIFICULDADES[dif_id], prog))


## Capítulos ainda trancados: só abrem depois de fechar a campanha do anterior.
func _bags_bloqueadas() -> Array:
	var lista := []
	if not Config.CAPITULOS_EM_ORDEM:
		return lista
	for id in Historia.ORDEM:
		var anterior := Historia.capitulo_anterior(id)
		if anterior != "" and not Progresso.campanha_fechada(anterior):
			lista.append(id)
	return lista


## P/ESC (ou o botão "II" no celular): congela a partida e mostra a tela de pausa.
## Com a pausa aberta, P/ESC continua. Fora da partida (menu, fim de fase) não faz nada.
func _alternar_pausa() -> void:
	if estado != Estado.JOGANDO and estado != Estado.CODIGO:
		return
	var pausar := not get_tree().paused
	get_tree().paused = pausar
	hud.lbl_toast.visible = not pausar   # aviso flutuante ficaria por trás do "PAUSADO"
	if pausar:
		Som.parar_loops()
		Som.abafar(true)
		Som.tocar("clique")
		telas.mostrar_pausa(n_fase, def_fase.nome)
	else:
		Som.abafar(estado == Estado.CODIGO)
		telas.limpar()


## Pontos/tempo vindos dos obstáculos (quedas, multas, bônus de pouso...).
func _on_placar(delta_pontos: int, delta_tempo: float, texto: String, cor: Color) -> void:
	if estado != Estado.JOGANDO and estado != Estado.CODIGO:
		return
	pontos = maxi(0, pontos + delta_pontos)
	tempo_restante += delta_tempo
	hud.aviso(texto, cor)
	if delta_pontos != 0:
		efeitos.texto(moto.position + Vector2(0, -140), "%+d" % delta_pontos, cor)
	if delta_tempo < 0.0:
		tremer(8.0, 0.4)   # multa da CET


## Fim da fase. "imagem" = cena da história que aparece no fundo (derrotas).
func _fim(vitoria: bool, mensagem: String, imagem: String = "") -> void:
	estado = Estado.FIM
	moto.controles_ativos = false
	popup.fechar()
	Som.parar_loops()
	Som.abafar(false)
	Som.tocar("vitoria" if vitoria else "derrota")
	Som.musica("menu", 3.0)
	var bonus := 0
	if vitoria:
		bonus = int(tempo_restante) * Config.PONTOS_POR_SEG_RESTANTE
		pontos += bonus

	# Acerto do turno: vencendo, recebe pelos pontos; perdendo, só a taxa das entregas feitas.
	var pagamento := pontos / Config.PONTOS_POR_REAL if vitoria else entregas * Config.REAIS_POR_ENTREGA
	prog.dinheiro += pagamento
	var recorde: bool = vitoria and pontos > prog.recordes[n_fase]
	if vitoria:
		prog.recordes[n_fase] = maxi(prog.recordes[n_fase], pontos)
		prog.liberada = maxi(prog.liberada, mini(n_fase + 1, Config.FASES.size() - 1))
	Progresso.salvar(dif_id, prog)

	var linhas := "Entregas: %d/%d     Pontos: %d" % [entregas, meta_entregas, pontos]
	if vitoria:
		linhas += "\n(inclui +%d pelo tempo que sobrou)%s" % [bonus, "   NOVO RECORDE!" if recorde else ""]
	linhas += "\nAcerto do turno: R$ %d     Saldo: R$ %d" % [pagamento, prog.dinheiro]
	linhas += "\nFase %d: %s     Bag: %s     Mapa nº %d" % [n_fase + 1, def_fase.nome, dif.nome, fase.semente]
	var titulo := "GAME OVER"
	if vitoria:
		titulo = "CAMPANHA FECHADA!" if n_fase == Config.FASES.size() - 1 else "TURNO FECHADO!"
	if vitoria and n_fase == Config.FASES.size() - 1:
		# Fechou a campanha: final da história e, depois, a tela de fim com a casa no fundo
		titulo = "%s FECHADO!" % Historia.CAPITULOS[dif_id].titulo.split(":")[0]
		telas.mostrar_cutscene(Historia.final(dif_id), func() -> void:
			telas.mostrar_fim(vitoria, titulo, mensagem, linhas, n_fase, Historia.caminho(Historia.fundo_final(dif_id))))
		return
	telas.mostrar_fim(vitoria, titulo, mensagem, linhas, n_fase, Historia.caminho(imagem) if imagem != "" else "")


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if estado == Estado.JOGANDO or estado == Estado.CODIGO:
		tempo_restante -= delta
		if etapa == Etapa.IR_CLIENTE or etapa == Etapa.ESPERANDO_CLIENTE:
			prazo_restante -= delta
		obst.processar(delta, estado == Estado.CODIGO)
		_consumir_gasolina(delta)
		_sons_continuos()
		if gasolina <= 0.0:
			gasolina = 0.0
			_fim(false, "SEM GASOLINA!\n" + _sortear(Config.MENSAGENS_SEM_GASOLINA) + "\n" + Historia.FRASE_SEM_GASOLINA,
				Historia.FUNDO_SEM_GASOLINA)
		elif tempo_restante <= 0.0:
			tempo_restante = 0.0
			_fim(false, "TEMPO ESGOTADO!\n" + _sortear(Config.MENSAGENS_TEMPO) + "\n" + Historia.FRASE_TEMPO,
				Historia.FUNDO_TEMPO)
		elif estado == Estado.JOGANDO:
			_interacoes(delta)

	# Câmera olha um pouco à frente do movimento
	_olhar = lerpf(_olhar, clampf(moto.velocity.x * 0.4, -220.0, 220.0), 2.0 * delta)
	var tremida := Vector2.ZERO
	if _tremor > 0.0:
		_tremor -= delta
		var f := _tremor_forca * clampf(_tremor / 0.4, 0.0, 1.0)
		tremida = Vector2(randf_range(-f, f), randf_range(-f, f))
	else:
		_tremor_forca = 0.0
	camera.offset = Vector2(_olhar, 0.0) + tremida
	_atualizar_parallax()
	if estado != Estado.MENU:
		_atualizar_hud()


## Motor, freio, vento, chuva, sirene da CET e bomba do posto: ligados enquanto a situação dura.
func _sons_continuos() -> void:
	var frac: float = clampf(absf(moto.velocity.x) / moto.vel_max, 0.0, 1.3)
	var no_chao: bool = moto.is_on_floor()
	Som.loop("motor", true, -15.0 + 5.0 * frac + 3.0 * moto.acelerando, 0.6 + 1.2 * frac + 0.15 * moto.acelerando)
	var freando: bool = moto.controles_ativos and no_chao and absf(moto.velocity.x) > 140.0 \
		and Input.is_action_pressed("freio")
	Som.loop("freio", freando, -12.0 + 4.0 * frac, 0.9 + 0.3 * frac)
	Som.loop("vento", not no_chao and moto.instavel, -10.0, 1.0)
	Som.loop("chuva", obst.chovendo, -12.0, 1.0)
	Som.loop("sirene", obst.cet != null, -12.0, 1.0)
	Som.loop("bomba", _abastecendo, -12.0, 1.0)
	Som.abafar(estado == Estado.CODIGO or obst.cet != null)
	if gasolina / gas_max < 0.3:
		if not _avisou_reserva:
			_avisou_reserva = true
			Som.tocar("alerta")
	else:
		_avisou_reserva = false


func _consumir_gasolina(delta: float) -> void:
	var frac: float = absf(moto.velocity.x) / moto.vel_max
	gasolina -= (Config.CONSUMO_PARADO + Config.CONSUMO_VELOCIDADE_MAX * frac) * delta


func _interacoes(delta: float) -> void:
	var parado: bool = absf(moto.velocity.x) < VEL_PARADO and moto.is_on_floor() and not moto.caido

	# Posto: parado dentro da área enche o tanque (~10 s do zero ao cheio)
	_abastecendo = false
	for p in postos:
		var abastecendo: bool = p.ativo and parado and _moto_em(p) and gasolina < gas_max
		if abastecendo:
			gasolina = minf(gas_max, gasolina + Config.GASOLINA_MAX / Config.TEMPO_ENCHER_TANQUE * delta)
			p.texto_progresso = "Abastecendo..."
			_abastecendo = true
			p.progresso = gasolina / gas_max
			_avisou_tanque_cheio = false
		elif p.progresso >= 0.0:
			p.progresso = -1.0
			if gasolina >= gas_max and not _avisou_tanque_cheio:
				_avisou_tanque_cheio = true
				Som.tocar("tanque")
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
	if gasolina / gas_max < 0.3:
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
		"total": meta_entregas,
		"gasolina": gasolina / gas_max,
		"texto_pedido": texto,
		"cor_pedido": cor,
		"alvos": alvos,
		"alerta": alerta,
	})


func _sortear(lista: Array) -> String:
	return lista[rng.randi_range(0, lista.size() - 1)]
