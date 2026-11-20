extends Control
## Créditos rolando de baixo para cima sobre uma imagem da história.
## Aparecem depois do final do capítulo 3 e pelo botão CRÉDITOS da tela inicial.
## Esc, Espaço, Enter ou o botão PULAR encerram; o sinal "terminou" avisa quem chamou.

signal terminou

const Config := preload("res://src/game_config.gd")
const UI := preload("res://src/ui_util.gd")
const Historia := preload("res://src/historia.gd")

const VELOCIDADE := 55.0   # px/s

## [texto, tamanho, cor]: "" = espaço em branco
const LINHAS := [
	["HORA DO RUSH", 72, "laranja"],
	["A história do Felipe e da Tati", 22, "papel"],
	["", 60, ""],
	["GRUPO", 30, "amarelo"],
	["Anna Carolina Martins", 24, "papel"],
	["Pedro Henrique Nascimento", 24, "papel"],
	["Isaías de Lima Gomes", 24, "papel"],
	["Vinícius Viscardi Silveira", 24, "papel"],
	["Júlia Silva de Araújo", 24, "papel"],
	["", 50, ""],
	["TRABALHO A3", 30, "amarelo"],
	["Usabilidade, desenvolvimento web, mobile e jogos", 20, "papel"],
	["Professor Elzo Brito dos Santos Filho", 20, "papel"],
	["", 50, ""],
	["FEITO COM", 30, "amarelo"],
	["Godot Engine 4.7", 22, "papel"],
	["Código escrito pelo grupo com o Claude Code (IA da Anthropic)", 18, "cinza"],
	["", 40, ""],
	["ARTE", 30, "amarelo"],
	["Cenário, moto, obstáculos e personagens desenhados por código", 18, "papel"],
	["Cutscenes e fundo da oficina gerados com IA (Google Gemini)", 18, "papel"],
	["", 40, ""],
	["SOM", 30, "amarelo"],
	["Efeitos e trilhas sintetizados por código", 18, "papel"],
	["Funk paulista, funk das antigas e funk bruxaria: composição original", 18, "papel"],
	["", 40, ""],
	["FONTE", 30, "amarelo"],
	["Silkscreen, de Jason Kottke (SIL Open Font License)", 18, "papel"],
	["", 80, ""],
	["Valeu por jogar!", 34, "laranja"],
	["Bora pro próximo turno.", 20, "papel"],
]

var _rolo: VBoxContainer
var _acabou := false
var _iniciado := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var foto: TextureRect = UI.tela_cheia(TextureRect.new())
	foto.texture = load(Historia.caminho("16_cap3_final.jpg"))
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foto)
	var escuro: ColorRect = UI.tela_cheia(ColorRect.new())
	escuro.color = Color(0.04, 0.03, 0.03, 0.86)
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escuro)

	var cores := {"laranja": Config.COR_LARANJA, "amarelo": Config.COR_AMARELO,
		"papel": Config.COR_PAPEL, "cinza": Config.COR_CINZA_CLARO}
	_rolo = VBoxContainer.new()
	_rolo.add_theme_constant_override("separation", 10)
	_rolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rolo)
	for l in LINHAS:
		if l[0] == "":
			var vazio := Control.new()
			vazio.custom_minimum_size = Vector2(0, l[1])
			_rolo.add_child(vazio)
			continue
		var r := UI.label(l[0], l[1], cores[l[2]], 6)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rolo.add_child(r)

	var pular: Button = UI.botao("PULAR (ESC)", Config.COR_CINZA_ESCURO, Config.COR_PAPEL, 14)
	pular.position = Vector2(1100, 20)
	pular.size = Vector2(160, 40)
	pular.pressed.connect(_encerrar)
	add_child(pular)
	resized.connect(_posicionar_inicio)
	_posicionar_inicio.call_deferred()


func _posicionar_inicio() -> void:
	if _iniciado or size.y <= 0.0:
		return
	_iniciado = true
	_rolo.size.x = size.x
	_rolo.position = Vector2(0, size.y * 0.7)


func _process(delta: float) -> void:
	if _acabou or not _iniciado:
		return
	_rolo.size.x = size.x
	_rolo.position.y -= VELOCIDADE * delta
	# Terminou quando a última linha passa do meio da tela
	if _rolo.position.y + _rolo.size.y < size.y * 0.45:
		_encerrar()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_encerrar()


func _encerrar() -> void:
	if _acabou:
		return
	_acabou = true
	terminou.emit()
