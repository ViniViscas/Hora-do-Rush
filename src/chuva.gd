extends CanvasLayer
## Chuva em cima da tela (gotas inclinadas + escurecida leve).

const QTD_GOTAS := 260

var _gotas: Array = []   # [Vector2 posição, float velocidade, float comprimento]
var _tela: Control


func _ready() -> void:
	layer = 3
	var escuro := ColorRect.new()
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0.1, 0.12, 0.16, 0.22)
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escuro)
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	for i in QTD_GOTAS:
		_gotas.append([Vector2(randf() * 2400.0, randf() * 800.0), randf_range(900, 1400), randf_range(10, 22)])


func _process(delta: float) -> void:
	if not visible:
		return
	var tam := _tela.get_viewport_rect().size
	for g in _gotas:
		g[0] += Vector2(-0.25, 1.0) * g[1] * delta
		if g[0].y > tam.y:
			g[0] = Vector2(randf() * (tam.x + 200.0), -20.0)
		if g[0].x < -20.0:
			g[0].x += tam.x + 40.0
	_tela.queue_redraw()


func _desenhar() -> void:
	var cor := Color(0.75, 0.78, 0.82, 0.45)
	for g in _gotas:
		var p: Vector2 = g[0]
		_tela.draw_line(p, p + Vector2(-0.25, 1.0) * g[2], cor, 1.5)
