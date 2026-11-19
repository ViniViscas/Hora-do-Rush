extends CanvasLayer
## HUD: tempo, pedido atual, pontos, entregas, gasolina, avisos e setas para o destino.

const Config := preload("res://src/game_config.gd")
const UI := preload("res://src/ui_util.gd")

var lbl_tempo: Label
var lbl_pedido: Label
var lbl_pontos: Label
var lbl_entregas: Label
var barra_gas: ProgressBar
var estilo_gas: StyleBoxFlat
var lbl_toast: Label
var lbl_alerta: Label
var seta: Control

var _alvos: Array = []   # [{pos: Vector2, cor: Color, texto: String}]
var _tween_toast: Tween
var _t := 0.0


func _ready() -> void:
	layer = 10
	var raiz: Control = UI.tela_cheia(Control.new())
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	seta = UI.tela_cheia(Control.new())
	seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seta.draw.connect(_desenhar_setas)
	raiz.add_child(seta)

	var barra := ColorRect.new()
	barra.color = Color(0, 0, 0, 0.65)
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.offset_bottom = 56
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(barra)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margem.offset_bottom = 56
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 20)
	raiz.add_child(margem)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 28)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(linha)

	lbl_tempo = UI.label("TEMPO 0:00", 24, Config.COR_PAPEL)
	lbl_pedido = UI.label("", 18, Config.COR_LARANJA_CLARO)
	lbl_pedido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_pedido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pedido.clip_text = true
	lbl_entregas = UI.label("ENTREGAS 0/0", 18, Config.COR_PAPEL)
	lbl_pontos = UI.label("PONTOS 0", 24, Config.COR_LARANJA)
	for l in [lbl_tempo, lbl_pedido, lbl_entregas, lbl_pontos]:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		linha.add_child(l)

	# Gasolina
	var caixa_gas := HBoxContainer.new()
	caixa_gas.position = Vector2(20, 66)
	caixa_gas.add_theme_constant_override("separation", 10)
	caixa_gas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(caixa_gas)
	caixa_gas.add_child(UI.label("GASOLINA", 18, Config.COR_PAPEL, 5))
	barra_gas = ProgressBar.new()
	barra_gas.custom_minimum_size = Vector2(220, 20)
	barra_gas.show_percentage = false
	barra_gas.max_value = 1.0
	barra_gas.step = 0.0
	barra_gas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_gas.add_theme_stylebox_override("background", UI.estilo(Config.COR_PRETO, Config.COR_CINZA, 2, 2))
	estilo_gas = UI.estilo(Config.COR_LARANJA, Config.COR_PRETO, 2, 0)
	barra_gas.add_theme_stylebox_override("fill", estilo_gas)
	barra_gas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caixa_gas.add_child(barra_gas)

	# Avisos
	lbl_toast = UI.label("", 26, Config.COR_PAPEL, 8)
	lbl_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_toast.offset_top = 120
	lbl_toast.offset_bottom = 170
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_toast.modulate.a = 0.0
	raiz.add_child(lbl_toast)

	# Alerta fixo (equilibrar, CET, blitz...)
	lbl_alerta = UI.label("", 34, Config.COR_VERMELHO, 9)
	lbl_alerta.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_alerta.offset_top = 210
	lbl_alerta.offset_bottom = 260
	lbl_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(lbl_alerta)


func _process(delta: float) -> void:
	_t += delta


func atualizar(dados: Dictionary) -> void:
	var tempo: float = maxf(dados.tempo, 0.0)
	lbl_tempo.text = "TEMPO %d:%02d" % [int(tempo) / 60, int(tempo) % 60]
	lbl_tempo.label_settings.font_color = Config.COR_VERMELHO if tempo < 20.0 else Config.COR_PAPEL
	lbl_pontos.text = "PONTOS %d" % dados.pontos
	lbl_entregas.text = "ENTREGAS %d/%d" % [dados.entregas, dados.total]
	lbl_pedido.text = dados.texto_pedido
	lbl_pedido.label_settings.font_color = dados.cor_pedido

	var gas: float = dados.gasolina
	barra_gas.value = gas
	if gas < 0.25:
		estilo_gas.bg_color = Config.COR_VERMELHO
		barra_gas.modulate.a = 0.55 + 0.45 * absf(sin(_t * 6.0))
	else:
		estilo_gas.bg_color = Config.COR_LARANJA
		barra_gas.modulate.a = 1.0

	var alerta: String = dados.get("alerta", "")
	lbl_alerta.text = alerta
	lbl_alerta.modulate.a = 0.6 + 0.4 * absf(sin(_t * 8.0)) if alerta != "" else 1.0

	_alvos = dados.alvos
	seta.queue_redraw()


func aviso(texto: String, cor: Color = Config.COR_PAPEL) -> void:
	lbl_toast.text = texto
	lbl_toast.label_settings.font_color = cor
	if _tween_toast:
		_tween_toast.kill()
	lbl_toast.modulate.a = 1.0
	_tween_toast = create_tween()
	_tween_toast.tween_interval(1.8)
	_tween_toast.tween_property(lbl_toast, "modulate:a", 0.0, 0.6)


func _desenhar_setas() -> void:
	var tela := seta.get_viewport_rect().size
	var ct := seta.get_viewport().get_canvas_transform()
	var fonte := ThemeDB.fallback_font
	var area := Rect2(Vector2(50, 110), tela - Vector2(100, 170))
	var centro := area.get_center()
	for alvo in _alvos:
		var p: Vector2 = ct * (alvo.pos as Vector2)
		if area.has_point(p):
			continue
		var d := p - centro
		var esc := INF
		if d.x != 0.0:
			esc = minf(esc, absf(area.size.x / 2.0 / d.x))
		if d.y != 0.0:
			esc = minf(esc, absf(area.size.y / 2.0 / d.y))
		var pos := centro + d * esc
		var ang := d.angle()
		var cor: Color = alvo.cor
		var pts := PackedVector2Array([
			pos + Vector2(26, 0).rotated(ang),
			pos + Vector2(-14, 16).rotated(ang),
			pos + Vector2(-14, -16).rotated(ang)])
		seta.draw_colored_polygon(pts, Config.COR_PRETO)
		var pts_int := PackedVector2Array()
		for q in pts:
			pts_int.append(pos + (q - pos) * 0.72)
		seta.draw_colored_polygon(pts_int, cor)
		var txt_pos := pos - Vector2(cos(ang), sin(ang)) * 46.0 + Vector2(-60, 8)
		seta.draw_string_outline(fonte, txt_pos, alvo.texto, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 6, Config.COR_PRETO)
		seta.draw_string(fonte, txt_pos, alvo.texto, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, cor)
