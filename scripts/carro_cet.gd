extends Node2D
## Carro da CET que persegue o entregador com a CNH vencida. Movido por obstaculos.gd.

const Config := preload("res://scripts/game_config.gd")

var vel := 0.0
var angulo := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var dir := -1.0 if vel < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, angulo, Vector2(dir, 1))
	var branco := Color(0.88, 0.87, 0.83)
	# Carroceria (vista lateral, frente para +x)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-84, -14), Vector2(-84, -44), Vector2(-50, -48), Vector2(-28, -76), Vector2(34, -76),
		Vector2(56, -48), Vector2(86, -42), Vector2(88, -14)]), branco)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -50), Vector2(-6, -70), Vector2(20, -70), Vector2(20, -50)]), Color(0.12, 0.14, 0.17))
	draw_colored_polygon(PackedVector2Array([
		Vector2(26, -50), Vector2(26, -70), Vector2(32, -70), Vector2(48, -50)]), Color(0.12, 0.14, 0.17))
	draw_rect(Rect2(-84, -36, 172, 10), Config.COR_LARANJA)
	draw_string(ThemeDB.fallback_font, Vector2(-40, -30), "CET", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Config.COR_PRETO)
	draw_rect(Rect2(80, -40, 8, 8), Color(1, 0.92, 0.65))
	# Giroflex alternando
	var lado := int(_t * 6.0) % 2 == 0
	draw_rect(Rect2(-12, -84, 14, 8), Config.COR_VERMELHO if lado else Color(0.3, 0.1, 0.1))
	draw_rect(Rect2(4, -84, 14, 8), Config.COR_LARANJA_CLARO if not lado else Color(0.35, 0.2, 0.1))
	var brilho := Color(Config.COR_VERMELHO if lado else Config.COR_LARANJA_CLARO, 0.18)
	draw_circle(Vector2(3, -80), 30.0, brilho)
	# Rodas
	for rx in [-54.0, 56.0]:
		draw_circle(Vector2(rx, -14), 15.0, Config.COR_PRETO)
		draw_circle(Vector2(rx, -14), 7.0, Config.COR_CINZA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
