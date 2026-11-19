extends Node2D
## Silhueta de prédios para o fundo (parallax). Desenhada uma vez, com semente fixa.

var semente := 1
var x_inicio := -1500.0
var x_fim := 6000.0
var base_y := 600.0
var altura_min := 120.0
var altura_max := 380.0
var cor := Color(0.2, 0.18, 0.17)
var cor_janela := Color(0.91, 0.55, 0.2, 0.55)
var chance_janela := 0.25


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var x := x_inicio
	while x < x_fim:
		var w := rng.randf_range(70, 180)
		var h := rng.randf_range(altura_min, altura_max)
		draw_rect(Rect2(x, base_y - h, w, h + 400), cor)
		if rng.randf() < 0.3:
			# caixa d'água / antena
			draw_rect(Rect2(x + w * 0.3, base_y - h - 18, 22, 18), cor)
			draw_line(Vector2(x + w * 0.7, base_y - h), Vector2(x + w * 0.7, base_y - h - 40), cor, 2.0)
		var jy := base_y - h + 16
		while jy < base_y - 20:
			var jx := x + 10
			while jx < x + w - 18:
				if rng.randf() < chance_janela:
					draw_rect(Rect2(jx, jy, 10, 12), cor_janela)
				jx += 22
			jy += 26
		x += w + rng.randf_range(0, 20)
