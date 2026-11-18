extends StaticBody2D
## Chão da fase: um polígono com rampas, colisão e decoração (calçada, postes).

const Config := preload("res://scripts/game_config.gd")

var pontos := PackedVector2Array()
var _poligono := PackedVector2Array()
var _fundo := 1400.0


func configurar(p: PackedVector2Array) -> void:
	pontos = p
	_poligono = PackedVector2Array(p)
	_poligono.append(Vector2(p[p.size() - 1].x, _fundo))
	_poligono.append(Vector2(p[0].x, _fundo))
	var col := CollisionPolygon2D.new()
	col.polygon = _poligono
	add_child(col)
	queue_redraw()


## Altura (y) da superfície no x dado, interpolando os pontos.
func altura_em(x: float) -> float:
	for i in range(pontos.size() - 1):
		var a := pontos[i]
		var b := pontos[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return pontos[pontos.size() - 1].y


func _draw() -> void:
	if _poligono.is_empty():
		return
	draw_colored_polygon(_poligono, Config.COR_CINZA_ESCURO)

	# Faixa da calçada / meio-fio acompanhando a superfície
	for i in range(pontos.size() - 1):
		var a := pontos[i]
		var b := pontos[i + 1]
		draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 14), a + Vector2(0, 14)]),
			Color(0.36, 0.34, 0.32))
		draw_line(a + Vector2(0, 14), b + Vector2(0, 14), Config.COR_PRETO, 3.0)
		draw_line(a, b, Color(0.45, 0.43, 0.4), 2.0)

	# Textura de asfalto (pontinhos determinísticos)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1943
	var x0 := pontos[0].x
	var x1 := pontos[pontos.size() - 1].x
	for i in 900:
		var x := rng.randf_range(x0, x1)
		var y := altura_em(x) + rng.randf_range(24, 140)
		draw_rect(Rect2(x, y, rng.randf_range(2, 6), 2), Color(0.22, 0.21, 0.2))

	# Postes de luz
	var x := 180.0
	while x < x1:
		var base := altura_em(x)
		draw_rect(Rect2(x - 3, base - 230, 6, 230), Color(0.12, 0.12, 0.12))
		draw_line(Vector2(x, base - 228), Vector2(x + 34, base - 236), Color(0.12, 0.12, 0.12), 5.0)
		draw_circle(Vector2(x + 36, base - 232), 26.0, Color(1.0, 0.6, 0.24, 0.10))
		draw_circle(Vector2(x + 36, base - 232), 6.0, Config.COR_LARANJA_CLARO)
		x += 420.0
