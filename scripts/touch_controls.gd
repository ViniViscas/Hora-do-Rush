extends CanvasLayer
## Botões de toque para celular (tela deitada). Aparecem só no celular,
## ou no PC se o jogo for aberto com o argumento "-- --toque".
## (Não dá para usar is_touchscreen_available(): com emulate_touch_from_mouse ligado,
## ele diz que todo PC tem tela de toque.)

const Config := preload("res://scripts/game_config.gd")
const UI := preload("res://scripts/ui_util.gd")

const RAIO := 66
const MARGEM := 28.0

var _botoes := {}


func _ready() -> void:
	layer = 5
	visible = OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--toque")
	_criar("esquerda", "<")
	_criar("direita", ">")
	_criar("freio", "FREIO")
	_criar("pulo", "PULO")
	get_viewport().size_changed.connect(_posicionar)
	_posicionar()


func _criar(acao: String, texto: String) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _textura(Color(0, 0, 0, 0.35), Color(Config.COR_LARANJA, 0.7))
	b.texture_pressed = _textura(Color(Config.COR_LARANJA, 0.55), Config.COR_LARANJA_CLARO)
	b.action = acao
	b.passby_press = true
	var l := UI.label(texto, 30 if texto.length() == 1 else 22, Config.COR_PAPEL)
	l.size = Vector2(RAIO * 2, RAIO * 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	add_child(b)
	_botoes[acao] = b


func _posicionar() -> void:
	var tela := get_viewport().get_visible_rect().size
	var d := RAIO * 2.0
	var y := tela.y - MARGEM - d
	_botoes["esquerda"].position = Vector2(MARGEM, y)
	_botoes["direita"].position = Vector2(MARGEM * 2 + d, y)
	_botoes["pulo"].position = Vector2(tela.x - MARGEM - d, y - 30)
	_botoes["freio"].position = Vector2(tela.x - MARGEM * 2 - d * 2, y + 10)


func _textura(preenchimento: Color, borda: Color) -> ImageTexture:
	var lado := RAIO * 2
	var img := Image.create_empty(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		for x in lado:
			var dist := Vector2(x - RAIO + 0.5, y - RAIO + 0.5).length()
			if dist <= RAIO - 5:
				img.set_pixel(x, y, preenchimento)
			elif dist <= RAIO:
				img.set_pixel(x, y, borda)
	return ImageTexture.create_from_image(img)
