extends StaticBody2D
## Obstáculo sólido simples no chão (caçamba, caixote, cone). A posição é o centro da base.

const Config := preload("res://src/game_config.gd")

var tipo := "cacamba"
var tamanho := Vector2(110, 55)


func _ready() -> void:
	var forma := CollisionShape2D.new()
	var ret := RectangleShape2D.new()
	ret.size = tamanho
	forma.shape = ret
	forma.position = Vector2(0, -tamanho.y / 2.0)
	add_child(forma)


func _draw() -> void:
	var w := tamanho.x
	var h := tamanho.y
	match tipo:
		"cacamba":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w / 2 - 6, -h), Vector2(w / 2 + 6, -h),
				Vector2(w / 2, -6), Vector2(-w / 2, -6)]), Color(0.55, 0.27, 0.1))
			for i in 4:
				var x := -w / 2 + 14 + i * (w - 28) / 3.0
				draw_line(Vector2(x, -h + 6), Vector2(x, -10), Color(0.35, 0.17, 0.07), 3.0)
			draw_rect(Rect2(-w / 2 - 8, -h - 4, w + 16, 6), Config.COR_PRETO)
			draw_circle(Vector2(-w / 2 + 12, -4), 5.0, Config.COR_PRETO)
			draw_circle(Vector2(w / 2 - 12, -4), 5.0, Config.COR_PRETO)
		"caixote":
			draw_rect(Rect2(-w / 2, -h, w, h), Color(0.42, 0.3, 0.18))
			draw_rect(Rect2(-w / 2, -h, w, h), Color(0.25, 0.17, 0.1), false, 3.0)
			draw_line(Vector2(-w / 2, -h), Vector2(w / 2, 0), Color(0.25, 0.17, 0.1), 3.0)
			draw_line(Vector2(w / 2, -h), Vector2(-w / 2, 0), Color(0.25, 0.17, 0.1), 3.0)
		"cone":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w / 2, 0), Vector2(w / 2, 0), Vector2(3, -h), Vector2(-3, -h)]), Config.COR_LARANJA)
			draw_line(Vector2(-w * 0.32, -h * 0.35), Vector2(w * 0.32, -h * 0.35), Config.COR_PAPEL, 4.0)
			draw_line(Vector2(-w * 0.2, -h * 0.65), Vector2(w * 0.2, -h * 0.65), Config.COR_PAPEL, 3.0)
			draw_rect(Rect2(-w / 2 - 4, -4, w + 8, 4), Config.COR_PRETO)
