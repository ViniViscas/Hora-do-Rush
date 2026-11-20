extends CanvasLayer
## Tutorial: balão da Tati na parte de baixo da tela, com o rosto dela em pixel art.
## main.gd chama dizer() nos momentos certos da primeira fase; as falas entram numa fila
## e cada uma fica na tela o tempo de ler. Fica embaixo, no meio, entre os botões de toque.

const Config := preload("res://src/game_config.gd")
const UI := preload("res://src/ui_util.gd")
const Personagem := preload("res://src/personagem.gd")
const Som := preload("res://src/som.gd")

const PIXEL := 2
const LARGURA := 760.0

var _painel: PanelContainer
var _texto: Label
var _tati
var _fila: Array = []
var _restante := 0.0


func _ready() -> void:
	layer = 12
	_painel = PanelContainer.new()
	var estilo := UI.estilo(Color(0.07, 0.06, 0.06, 0.92), Config.COR_LARANJA, 6, 3)
	estilo.set_content_margin_all(6)
	_painel.add_theme_stylebox_override("panel", estilo)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.custom_minimum_size = Vector2(LARGURA, 0)
	_painel.visible = false
	add_child(_painel)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	_painel.add_child(linha)
	linha.add_child(_retrato())

	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_child(coluna)
	coluna.add_child(UI.label("TATI", 15, Config.COR_LARANJA, 4))
	_texto = UI.label("", 15, Config.COR_PAPEL, 4)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(LARGURA - 130.0, 0)
	coluna.add_child(_texto)


## Rosto e ombros da Tati (o mesmo desenho da oficina), ampliado sem suavizar.
func _retrato() -> Control:
	var area := Vector2i(40, 42)
	var caixa := SubViewportContainer.new()
	caixa.stretch = true
	caixa.stretch_shrink = PIXEL
	caixa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.custom_minimum_size = Vector2(area * PIXEL)
	var tela := SubViewport.new()
	tela.transparent_bg = true
	tela.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	caixa.add_child(tela)
	_tati = Personagem.new()
	_tati.tipo = "mecanica"
	_tati.olhando_direita = true
	_tati.position = Vector2(area.x / 2.0, 90.0)   # pés bem abaixo: só aparece da cintura para cima
	tela.add_child(_tati)
	return caixa


## Põe a fala na fila; aparece assim que a anterior sair.
func dizer(texto: String) -> void:
	_fila.append(texto)
	if not _painel.visible:
		_proxima()


func calar() -> void:
	_fila.clear()
	_restante = 0.0
	_painel.visible = false


func _proxima() -> void:
	if _fila.is_empty():
		_painel.visible = false
		_tati.falando = false
		return
	var texto: String = _fila.pop_front()
	_texto.text = texto
	_restante = 3.5 + texto.length() * 0.045
	_painel.visible = true
	_tati.falando = true
	_tati.expressao = Personagem.Expressao.FELIZ
	Som.tocar("bipe", -6.0, 1.3)
	# Posição: embaixo, no meio (o tamanho só fica certo depois do texto entrar)
	_painel.reset_size()
	var tela := get_viewport().get_visible_rect().size
	_painel.position = Vector2((tela.x - _painel.size.x) / 2.0, tela.y - _painel.size.y - 6.0)
	_painel.modulate.a = 0.0
	create_tween().tween_property(_painel, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	if not _painel.visible:
		return
	# Reposiciona (o autowrap pode mudar a altura no primeiro quadro)
	var tela := get_viewport().get_visible_rect().size
	_painel.position = Vector2((tela.x - _painel.size.x) / 2.0, tela.y - _painel.size.y - 6.0)
	_restante -= delta
	if _restante <= 0.4:
		_tati.falando = false
	if _restante <= 0.0:
		_proxima()
