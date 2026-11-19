extends Control
## Cutscene: imagens em tela cheia (com um zoom lento) e uma caixa de texto embaixo,
## com o nome de quem fala e o texto aparecendo letra por letra.
## Clique, Espaço ou Enter avançam (se o texto ainda está aparecendo, completa ele);
## ESC ou o botão PULAR encerram. Emite "terminou" no fim.

signal terminou

const Config := preload("res://src/game_config.gd")
const UI := preload("res://src/ui_util.gd")
const Historia := preload("res://src/historia.gd")
const Som := preload("res://src/som.gd")

var _cenas: Array = []
var _cena := -1
var _fala := 0
var _imagem: TextureRect
var _cortina: ColorRect        # preto para os fades entre cenas
var _titulo: Label
var _caixa: PanelContainer
var _nome: Label
var _etiqueta: PanelContainer
var _texto: Label
var _dica: Label
var _tween_texto: Tween
var _trocando := false
var _acabou := false


func iniciar(cenas: Array) -> void:
	_cenas = cenas
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo: ColorRect = UI.tela_cheia(ColorRect.new())
	fundo.color = Color(0.03, 0.03, 0.04)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	_imagem = UI.tela_cheia(TextureRect.new())
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagem.pivot_offset = Vector2(640, 360)
	add_child(_imagem)

	_titulo = UI.label("", 34, Config.COR_LARANJA, 10)
	_titulo.position = Vector2(0, 28)
	_titulo.size = Vector2(1280, 50)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_titulo)

	_caixa = PanelContainer.new()
	_caixa.position = Vector2(60, 556)
	_caixa.size = Vector2(1160, 134)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := UI.estilo(Color(0.05, 0.05, 0.06, 0.88), Config.COR_LARANJA, 6, 3)
	estilo.set_content_margin_all(18)
	_caixa.add_theme_stylebox_override("panel", estilo)
	add_child(_caixa)
	_texto = UI.label("", 18, Config.COR_PAPEL, 4)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(1120, 90)
	_caixa.add_child(_texto)

	_etiqueta = PanelContainer.new()
	_etiqueta.position = Vector2(84, 536)
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta.add_theme_stylebox_override("panel", UI.estilo(Config.COR_LARANJA, Config.COR_PRETO, 3, 3))
	_nome = UI.label("", 16, Config.COR_PRETO, 0)
	_etiqueta.add_child(_nome)
	add_child(_etiqueta)

	_dica = UI.label("ESPAÇO / CLIQUE >>", 12, Config.COR_CINZA_CLARO, 3)
	_dica.position = Vector2(1000, 664)
	_dica.size = Vector2(200, 20)
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_dica)

	var pular: Button = UI.botao("PULAR (ESC)", Config.COR_CINZA_ESCURO, Config.COR_PAPEL, 14)
	pular.position = Vector2(1100, 20)
	pular.size = Vector2(160, 40)
	pular.pressed.connect(_encerrar)
	add_child(pular)

	_cortina = UI.tela_cheia(ColorRect.new())
	_cortina.color = Color.BLACK
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)

	_proxima_cena()


func _process(delta: float) -> void:
	# Seta piscando quando o texto já terminou de aparecer
	_dica.modulate.a = (0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)) if _texto.visible_ratio >= 1.0 else 0.0


func _input(event: InputEvent) -> void:
	if _acabou:
		return
	if event.is_action_pressed("pausa"):
		get_viewport().set_input_as_handled()
		_encerrar()
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		_avancar()


func _gui_input(event: InputEvent) -> void:
	var clique := event as InputEventMouseButton
	if clique and clique.pressed and clique.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_avancar()


func _avancar() -> void:
	if _trocando or _acabou:
		return
	if _texto.visible_ratio < 1.0:
		if _tween_texto:
			_tween_texto.kill()
		_texto.visible_ratio = 1.0   # completa o texto de uma vez
		return
	Som.tocar("clique")
	_fala += 1
	var falas: Array = _cenas[_cena].falas
	if _fala < falas.size():
		_mostrar_fala()
	else:
		_proxima_cena()


func _proxima_cena() -> void:
	_cena += 1
	if _cena >= _cenas.size():
		_encerrar()
		return
	_trocando = true
	var tw := create_tween()
	if _cena > 0:
		tw.tween_property(_cortina, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_montar_cena)
	tw.tween_property(_cortina, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void:
		_trocando = false
		_mostrar_fala())


func _montar_cena() -> void:
	var cena: Dictionary = _cenas[_cena]
	var arquivo := Historia.caminho(cena.imagem)
	_imagem.texture = load(arquivo) if ResourceLoader.exists(arquivo) else null   # sem imagem: fundo escuro
	_titulo.text = cena.get("titulo", "")
	_texto.text = ""
	_nome.text = ""
	_etiqueta.visible = false
	_fala = 0
	# Zoom lento ("efeito Ken Burns") para a imagem parada ganhar vida
	_imagem.scale = Vector2.ONE
	var zoom := create_tween()
	zoom.tween_property(_imagem, "scale", Vector2(1.06, 1.06), 9.0).set_trans(Tween.TRANS_SINE)


func _mostrar_fala() -> void:
	var fala: Array = _cenas[_cena].falas[_fala]
	var quem: String = fala[0]
	_etiqueta.visible = quem != ""
	_nome.text = quem
	_texto.text = ("\"%s\"" % fala[1]) if quem != "" else fala[1]
	_texto.label_settings.font_color = Config.COR_PAPEL if quem == "" else Config.COR_LARANJA_CLARO
	_texto.visible_ratio = 0.0
	if _tween_texto:
		_tween_texto.kill()
	_tween_texto = create_tween()
	_tween_texto.tween_property(_texto, "visible_ratio", 1.0, _texto.text.length() * 0.028)


func _encerrar() -> void:
	if _acabou:
		return
	_acabou = true
	var tw := create_tween()
	tw.tween_property(_cortina, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func() -> void: terminou.emit())
