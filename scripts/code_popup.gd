extends CanvasLayer
## Balão do cliente no portão pedindo o código do pedido, com teclado numérico na tela.
## Também aceita os números do teclado físico (incluindo o numpad).

signal acertou
signal errou

const Config := preload("res://scripts/game_config.gd")
const UI := preload("res://scripts/ui_util.gd")
const CodeDisplay := preload("res://scripts/code_display.gd")

var codigo := ""
var digitado := ""

var _display  # CodeDisplay
var _lbl_digitado: Label


func _ready() -> void:
	layer = 15
	visible = false

	var fundo: ColorRect = UI.tela_cheia(ColorRect.new())
	fundo.color = Color(0, 0, 0, 0.45)
	add_child(fundo)

	var centro: CenterContainer = UI.tela_cheia(CenterContainer.new())
	add_child(centro)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", UI.estilo(Color(0.1, 0.09, 0.09, 0.96), Config.COR_LARANJA, 6, 3))
	centro.add_child(painel)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	painel.add_child(caixa)

	var balao := PanelContainer.new()
	balao.add_theme_stylebox_override("panel", UI.estilo(Config.COR_PAPEL, Config.COR_PRETO, 18, 3))
	caixa.add_child(balao)
	var caixa_balao := VBoxContainer.new()
	balao.add_child(caixa_balao)
	var fala := UI.label("\"Oi! Qual o código do pedido?\"", 20, Config.COR_PRETO, 0)
	fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa_balao.add_child(fala)
	_display = CodeDisplay.new()
	_display.custom_minimum_size = Vector2(380, 96)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_balao.add_child(_display)

	_lbl_digitado = UI.label("_ _ _ _", 40, Config.COR_LARANJA_CLARO)
	_lbl_digitado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(_lbl_digitado)

	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	caixa.add_child(grade)
	for tecla in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", ""]:
		if tecla == "":
			var vazio := Control.new()
			grade.add_child(vazio)
			continue
		var cor := Config.COR_CINZA if tecla == "<" else Config.COR_LARANJA
		var b: Button = UI.botao("APAGAR" if tecla == "<" else tecla, cor, Config.COR_PRETO,
			20 if tecla == "<" else 30)
		b.custom_minimum_size = Vector2(124, 58)
		b.pressed.connect(_tecla.bind(tecla))
		grade.add_child(b)


func abrir(c: String, distorcao: float) -> void:
	codigo = c
	digitado = ""
	_display.configurar(c, distorcao)
	_atualizar()
	visible = true


func fechar() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var tecla := ""
	if k.keycode >= KEY_0 and k.keycode <= KEY_9:
		tecla = str(k.keycode - KEY_0)
	elif k.keycode >= KEY_KP_0 and k.keycode <= KEY_KP_9:
		tecla = str(k.keycode - KEY_KP_0)
	elif k.keycode == KEY_BACKSPACE:
		tecla = "<"
	if tecla != "":
		_tecla(tecla)
		get_viewport().set_input_as_handled()


func _tecla(tecla: String) -> void:
	if tecla == "<":
		digitado = digitado.left(-1)
	elif digitado.length() < codigo.length():
		digitado += tecla
	_atualizar()
	if digitado.length() == codigo.length():
		_verificar()


func _verificar() -> void:
	if digitado == codigo:
		acertou.emit()
		return
	digitado = ""
	_atualizar()
	_display.reembaralhar()
	_lbl_digitado.modulate = Config.COR_VERMELHO
	var tw := create_tween()
	tw.tween_property(_lbl_digitado, "modulate", Color.WHITE, 0.5)
	errou.emit()


func _atualizar() -> void:
	var partes := PackedStringArray()
	for i in codigo.length():
		partes.append(digitado[i] if i < digitado.length() else "_")
	_lbl_digitado.text = " ".join(partes)
