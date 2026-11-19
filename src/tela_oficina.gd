extends Control
## Tela da oficina: fundo em pixel art, a mecânica Tati e o entregador conversando,
## e o painel de melhorias à direita. A Tati comenta o estado da moto (quantas melhorias),
## o saldo, a bag escolhida e reage a cada compra.

signal comprar(melhoria: String)
signal voltar

const Config := preload("res://src/game_config.gd")
const UI := preload("res://src/ui_util.gd")
const Progresso := preload("res://src/progresso.gd")
const Personagem := preload("res://src/personagem.gd")

const FUNDO := "res://assets/img/oficina_fundo.jpg"
const PIXEL := 4                       # cada pixel dos personagens vira 4x4 na tela
const NOME_MECANICA := "TATI"

## Fala ao passar o mouse numa melhoria, pelo nível atual dela (0 a 3).
const FALAS_NIVEL := {
	"motor": [
		"Esse motor tá cansado, parece liquidificador velho. Uma envenenada resolve.",
		"Já dei um tapa no motor. Dá pra apertar mais um pouco o giro.",
		"Mais um nível e essa moto vira foguete na avenida.",
		"Motor no talo. Mais que isso, só moto de corrida.",
	],
	"freio": [
		"Pastilha no metal, hein? Desse jeito você para no portão do vizinho.",
		"Freio tá bom, mas na chuva ainda escorrega. Dá pra melhorar.",
		"Disco maior e pinça nova. Aí para até na descida molhada.",
		"Freio no máximo. Para na moeda.",
	],
	"tanque": [
		"Tanque original. Vive no posto, né? Aumento ele pra você.",
		"Já cabe mais gasolina, mas ainda dá pra crescer.",
		"Mais um nível e você esquece onde fica o posto.",
		"Tanque no máximo. Isso aí é quase um caminhão-pipa.",
	],
	"amortecedor": [
		"Amortecedor batendo seco. Cada lombada é um susto.",
		"Mola nova ajuda. Mas pousar torto ainda derruba.",
		"Mais um nível e a moto aguenta pouso de acrobata.",
		"Amortecedor no máximo. Pode voar da lombada sem medo.",
	],
	"bag": [
		"Essa bag não segura calor nenhum. O cliente recebe pizza gelada.",
		"Bag térmica melhorou. Dá mais prazo em cada pedido.",
		"Mais uma camada e a comida chega pelando.",
		"Bag no máximo. A marmita chega mais quente do que saiu.",
	],
}

## Reação depois de comprar, pelo novo nível (1 a 3).
const FALAS_COMPRA := {
	"motor": ["Escuta esse ronco! Agora vai.", "Envenenei mais um pouco. Cuidado na lombada!", "Motor no talo! Segura essa máquina."],
	"freio": ["Pastilha nova. Agora para na hora.", "Disco novo! Pode chegar embalado no portão.", "Freio de moto de corrida. Para na moeda!"],
	"tanque": ["Tanque maior, menos parada no posto.", "Mais uns litros de folga. Economiza viagem.", "Tanque no máximo! Roda a cidade inteira."],
	"amortecedor": ["Mola nova! A lombada já não assusta.", "Agora aguenta pouso mais torto.", "Amortecedor no máximo. Pode voar!"],
	"bag": ["Bag nova, comida quentinha.", "Mais isolamento, mais prazo nos pedidos.", "Bag no máximo. O cliente vai até dar gorjeta."],
}

var _dif: Dictionary = {}
var _prog: Dictionary = {}
var _tati
var _motoboy
var _texto_balao: Label
var _saldo: Label
var _linhas := {}        # id -> {pips: Array[ColorRect], botao: Button}
var _tween_fala: Tween
var _tween_gesto: Tween


func configurar(dif: Dictionary, prog: Dictionary) -> void:
	_dif = dif
	_prog = prog
	_montar_fundo()
	_tati = _personagem("mecanica", Vector2(500, 662), true)
	_motoboy = _personagem("entregador", Vector2(722, 662), false)
	_motoboy.cor_bag = dif.cor
	_motoboy.cor_bag_detalhe = dif.cor_detalhe
	_montar_balao()
	_montar_painel()
	_atualizar_painel()
	_falar(_saudacao(), Personagem.Expressao.FELIZ if _total_niveis() > 0 else Personagem.Expressao.NEUTRA)


## Resposta da compra (chamada pela cena principal depois de tentar comprar).
func reagir(melhoria: String, ok: bool, prog: Dictionary) -> void:
	_prog = prog
	_atualizar_painel()
	var nivel: int = _prog.niveis[melhoria]
	if ok:
		_falar(FALAS_COMPRA[melhoria][nivel - 1], Personagem.Expressao.FELIZ)
		_motoboy.expressao = Personagem.Expressao.FELIZ
		_comemorar()
		return
	var preco := Progresso.preco(_prog, melhoria)
	if preco < 0:
		_falar(FALAS_NIVEL[melhoria][3] + " Não tem mais o que mexer aí.", Personagem.Expressao.NEUTRA)
	else:
		_falar("Isso custa R$ %d e você tem R$ %d. Fiado eu não faço, chefia. Roda mais um turno e volta."
			% [preco, _prog.dinheiro], Personagem.Expressao.BRAVA)
		_motoboy.expressao = Personagem.Expressao.NEUTRA


# ---------------------------------------------------------------- falas

func _total_niveis() -> int:
	var t := 0
	for id in _prog.niveis:
		t += _prog.niveis[id]
	return t


func _saudacao() -> String:
	var total := _total_niveis()
	var maximo := Config.MELHORIAS.size() * Config.PRECOS_MELHORIA.size()
	var texto := ""
	if total == 0:
		texto = "Chegou o motoqueiro da %s! Essa moto tá segurando no arame, hein. Vamos dar um jeito nela?" % _dif.nome
	elif total >= maximo:
		return "Não tem mais o que mexer. Essa aí tá melhor que moto de vitrine! Vai lá fazer dinheiro."
	elif total < 6:
		texto = "E aí! A máquina tá melhorando. O que vai ser hoje?"
	else:
		texto = "Olha só, essa moto já tá respeitável. Falta pouco pra ficar redondinha."
	if _prog.dinheiro < Config.PRECOS_MELHORIA[0]:
		texto += " Mas com R$ %d não dá nem pra pastilha. Roda mais um pouco e volta." % _prog.dinheiro
	else:
		texto += " Você tem R$ %d." % _prog.dinheiro
	return texto


func _explicar(id: String) -> void:
	var nivel: int = _prog.niveis[id]
	var texto: String = FALAS_NIVEL[id][nivel]
	var preco := Progresso.preco(_prog, id)
	if preco >= 0:
		texto += " Fica R$ %d." % preco
	_falar(texto, Personagem.Expressao.NEUTRA)


## Texto aparece letra por letra, com a boca mexendo enquanto escreve.
func _falar(texto: String, expressao: int) -> void:
	_tati.expressao = expressao
	_texto_balao.text = texto
	_texto_balao.visible_ratio = 0.0
	_tati.falando = true
	if _tween_fala:
		_tween_fala.kill()
	_tween_fala = create_tween()
	_tween_fala.tween_property(_texto_balao, "visible_ratio", 1.0, texto.length() * 0.022)
	_tween_fala.tween_callback(func() -> void: _tati.falando = false)


## Polegar para cima depois de uma compra.
func _comemorar() -> void:
	if _tween_gesto:
		_tween_gesto.kill()
	_tween_gesto = create_tween()
	_tween_gesto.tween_property(_tati, "gesto", 1.0, 0.15)
	_tween_gesto.tween_interval(1.0)
	_tween_gesto.tween_property(_tati, "gesto", 0.0, 0.25)


# ---------------------------------------------------------------- montagem

func _montar_fundo() -> void:
	var escuro := UI.tela_cheia(ColorRect.new())
	escuro.color = Config.COR_PRETO
	add_child(escuro)
	if ResourceLoader.exists(FUNDO):
		var fundo := UI.tela_cheia(TextureRect.new())
		fundo.texture = load(FUNDO)
		fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fundo)


## Personagem desenhado em baixa resolução e ampliado sem suavizar (visual de pixel art).
func _personagem(tipo: String, pes: Vector2, direita: bool):
	var area := Vector2i(80, 100)
	var caixa := SubViewportContainer.new()
	caixa.stretch = true
	caixa.stretch_shrink = PIXEL
	caixa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.size = Vector2(area * PIXEL)
	caixa.position = pes - Vector2(area.x / 2, area.y - 4) * PIXEL
	var tela := SubViewport.new()
	tela.transparent_bg = true
	tela.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	caixa.add_child(tela)
	var p := Personagem.new()
	p.tipo = tipo
	p.olhando_direita = direita
	p.position = Vector2(area.x / 2, area.y - 4)
	tela.add_child(p)
	add_child(caixa)
	return p


func _montar_balao() -> void:
	var balao := Panel.new()
	balao.position = Vector2(20, 226)
	balao.size = Vector2(430, 140)
	balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balao.add_theme_stylebox_override("panel", UI.estilo(Config.COR_PAPEL, Config.COR_PRETO, 6, 4))
	add_child(balao)
	# Rabicho apontando para a cabeça da Tati
	var rabicho := Polygon2D.new()
	rabicho.polygon = PackedVector2Array([Vector2(426, 70), Vector2(426, 104), Vector2(470, 104)])
	rabicho.color = Config.COR_PAPEL
	balao.add_child(rabicho)
	var contorno := Line2D.new()
	contorno.points = PackedVector2Array([Vector2(428, 70), Vector2(470, 104), Vector2(428, 104)])
	contorno.width = 4.0
	contorno.default_color = Config.COR_PRETO
	balao.add_child(contorno)
	var nome := UI.label(NOME_MECANICA, 16, Config.COR_PAPEL, 0)
	var etiqueta := PanelContainer.new()
	etiqueta.add_theme_stylebox_override("panel", UI.estilo(Config.COR_LARANJA, Config.COR_PRETO, 3, 3))
	etiqueta.position = Vector2(14, -18)
	etiqueta.add_child(nome)
	balao.add_child(etiqueta)
	_texto_balao = UI.label("", 15, Config.COR_PRETO, 0)
	_texto_balao.position = Vector2(18, 24)
	_texto_balao.size = Vector2(394, 108)
	_texto_balao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balao.add_child(_texto_balao)


func _montar_painel() -> void:
	var painel := PanelContainer.new()
	painel.position = Vector2(868, 36)
	painel.size = Vector2(392, 648)
	var estilo := UI.estilo(Color(0.06, 0.06, 0.07, 0.86), Config.COR_LARANJA, 6, 3)
	estilo.set_content_margin_all(16)
	painel.add_theme_stylebox_override("panel", estilo)
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	painel.add_child(coluna)
	var titulo := UI.label("OFICINA DA TATI", 24, Config.COR_LARANJA, 6)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)
	_saldo = UI.label("", 18, Config.COR_PAPEL, 4)
	_saldo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_saldo)

	for id in Config.MELHORIAS:
		var m: Dictionary = Config.MELHORIAS[id]
		var linha := PanelContainer.new()
		var fundo_linha := UI.estilo(Color(0.14, 0.14, 0.16, 0.9), Color(0.25, 0.25, 0.28), 4, 2)
		fundo_linha.set_content_margin_all(8)
		linha.add_theme_stylebox_override("panel", fundo_linha)
		linha.mouse_entered.connect(func() -> void: _explicar(id))
		coluna.add_child(linha)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		linha.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 6)
		h.add_child(info)
		info.add_child(UI.label(m.nome, 16, Config.COR_LARANJA_CLARO, 4))
		var pips_box := HBoxContainer.new()
		pips_box.add_theme_constant_override("separation", 4)
		info.add_child(pips_box)
		var pips := []
		for i in Config.PRECOS_MELHORIA.size():
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(26, 9)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips_box.add_child(pip)
			pips.append(pip)
		var botao: Button = UI.botao("", Config.COR_AMARELO, Config.COR_PRETO, 16)
		botao.custom_minimum_size = Vector2(124, 48)
		botao.mouse_entered.connect(func() -> void: _explicar(id))
		botao.pressed.connect(func() -> void: comprar.emit(id))
		h.add_child(botao)
		_linhas[id] = {"pips": pips, "botao": botao}

	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(espaco)
	var sair: Button = UI.botao("VOLTAR ÀS FASES", Config.COR_LARANJA, Config.COR_PRETO, 18)
	sair.custom_minimum_size = Vector2(0, 54)
	sair.pressed.connect(func() -> void: voltar.emit())
	coluna.add_child(sair)


func _atualizar_painel() -> void:
	_saldo.text = "SALDO: R$ %d" % _prog.dinheiro
	for id in _linhas:
		var nivel: int = _prog.niveis[id]
		var pips: Array = _linhas[id].pips
		for i in pips.size():
			pips[i].color = Config.COR_LARANJA if i < nivel else Color(0.3, 0.3, 0.32)
		var botao: Button = _linhas[id].botao
		var preco := Progresso.preco(_prog, id)
		if preco < 0:
			botao.text = "MÁXIMO"
			botao.disabled = true
			botao.add_theme_stylebox_override("disabled", UI.estilo(Config.COR_CINZA_ESCURO))
			botao.add_theme_color_override("font_disabled_color", Config.COR_CINZA_CLARO)
		else:
			botao.text = "R$ %d" % preco
			var da: bool = _prog.dinheiro >= preco
			# Sem dinheiro o botão continua clicável: a Tati reclama do fiado
			var cor: Color = Config.COR_AMARELO if da else Config.COR_CINZA
			botao.add_theme_stylebox_override("normal", UI.estilo(cor))
			botao.add_theme_stylebox_override("hover", UI.estilo(cor.lightened(0.15)))
			botao.add_theme_color_override("font_color", Config.COR_PRETO if da else Config.COR_PAPEL)
			botao.add_theme_color_override("font_hover_color", Config.COR_PRETO if da else Config.COR_PAPEL)
