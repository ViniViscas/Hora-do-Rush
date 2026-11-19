extends StaticBody2D
## Chão da fase: um polígono com rampas, colisão e decoração "suja": calçada rachada,
## asfalto com óleo, remendos e poças, postes com fiação embolada e lâmpadas falhando.

const Config := preload("res://src/game_config.gd")

const DISTANCIA_POSTES := 420.0
const ALTURA_FIOS := 212.0   # altura da cruzeta, onde os fios se prendem

var pontos := PackedVector2Array()
var _poligono := PackedVector2Array()
var _fundo := 1400.0
var _postes: Array = []      # x de cada poste
var _luzes: Node2D           # as lâmpadas ficam num nó próprio, redesenhado todo frame
var _t := 0.0


func configurar(p: PackedVector2Array) -> void:
	pontos = p
	_poligono = PackedVector2Array(p)
	_poligono.append(Vector2(p[p.size() - 1].x, _fundo))
	_poligono.append(Vector2(p[0].x, _fundo))
	var col := CollisionPolygon2D.new()
	col.polygon = _poligono
	add_child(col)
	_postes.clear()
	var x := 180.0
	while x < p[p.size() - 1].x:
		_postes.append(x)
		x += DISTANCIA_POSTES
	_luzes = Node2D.new()
	_luzes.draw.connect(_desenhar_luzes)
	add_child(_luzes)
	queue_redraw()


## Altura (y) da superfície no x dado, interpolando os pontos.
func altura_em(x: float) -> float:
	for i in range(pontos.size() - 1):
		var a := pontos[i]
		var b := pontos[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return pontos[pontos.size() - 1].y


func _process(delta: float) -> void:
	_t += delta
	if _luzes:
		_luzes.queue_redraw()


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

	var rng := RandomNumberGenerator.new()
	rng.seed = 1943
	var x0 := pontos[0].x
	var x1 := pontos[pontos.size() - 1].x

	# Textura de asfalto (pontinhos)
	for i in 900:
		var x := rng.randf_range(x0, x1)
		var y := altura_em(x) + rng.randf_range(24, 140)
		draw_rect(Rect2(x, y, rng.randf_range(2, 6), 2), Color(0.22, 0.21, 0.2))

	# Remendos de asfalto (tapa-buraco mal feito)
	for i in 60:
		var x := rng.randf_range(x0, x1)
		var y := altura_em(x) + rng.randf_range(26, 110)
		var r := Rect2(x, y, rng.randf_range(40, 130), rng.randf_range(12, 28))
		draw_rect(r, Color(0.13, 0.13, 0.13) if rng.randf() < 0.6 else Color(0.21, 0.2, 0.19))
		draw_rect(r, Color(0.1, 0.1, 0.1), false, 1.0)

	# Manchas de óleo
	for i in 110:
		var x := rng.randf_range(x0, x1)
		var y := altura_em(x) + rng.randf_range(22, 120)
		draw_colored_polygon(_elipse(Vector2(x, y), rng.randf_range(16, 55), rng.randf_range(3, 9), rng),
			Color(0.05, 0.05, 0.06, rng.randf_range(0.2, 0.4)))

	# Poças perto do meio-fio, com reflexo das luzes
	for i in 40:
		var x := rng.randf_range(x0, x1)
		var y := altura_em(x) + rng.randf_range(20, 34)
		var w := rng.randf_range(30, 90)
		draw_colored_polygon(_elipse(Vector2(x, y), w / 2, rng.randf_range(3, 5), rng), Color(0.12, 0.14, 0.17, 0.85))
		draw_line(Vector2(x - w * 0.25, y - 1), Vector2(x + w * 0.1, y - 1), Color(0.9, 0.6, 0.3, 0.35), 1.0)

	# Calçada: rachaduras, chiclete grudado e mato saindo das frestas
	for i in 220:
		var x := rng.randf_range(x0, x1)
		var y := altura_em(x)
		var pts := PackedVector2Array([Vector2(x, y + 2)])
		for k in 3:
			pts.append(pts[pts.size() - 1] + Vector2(rng.randf_range(3, 9), rng.randf_range(1, 4)))
		draw_polyline(pts, Color(0.2, 0.19, 0.18), 1.0)
	for i in 500:
		var x := rng.randf_range(x0, x1)
		draw_rect(Rect2(x, altura_em(x) + rng.randf_range(3, 11), 2, 2), Color(0.22, 0.21, 0.21))
	for i in 70:
		var x := rng.randf_range(x0, x1)
		var y := altura_em(x)
		for k in 3:
			draw_line(Vector2(x + k * 2, y + 1), Vector2(x + k * 3 - 2, y - rng.randf_range(4, 9)), Color(0.3, 0.36, 0.18), 1.5)

	_desenhar_fiacao(rng)

	# Postes (a lâmpada é desenhada em _desenhar_luzes, para poder piscar)
	for x in _postes:
		var base := altura_em(x)
		draw_rect(Rect2(x - 3, base - 230, 6, 230), Color(0.12, 0.12, 0.12))
		draw_line(Vector2(x, base - 228), Vector2(x + 34, base - 236), Color(0.12, 0.12, 0.12), 5.0)
		# Cruzeta com isoladores, onde os fios se prendem
		draw_rect(Rect2(x - 18, base - ALTURA_FIOS - 3, 36, 4), Color(0.14, 0.13, 0.12))
		for ix in [-14.0, 0.0, 14.0]:
			draw_rect(Rect2(x + ix - 2, base - ALTURA_FIOS - 8, 4, 5), Color(0.55, 0.55, 0.5))
		# Lambe-lambe e adesivos colados no poste
		if rng.randf() < 0.4:
			draw_rect(Rect2(x - 4, base - rng.randf_range(90, 130), 8, 14), Color(0.86, 0.83, 0.72, 0.8))
		# Ferrugem na base
		draw_rect(Rect2(x - 3, base - 18, 6, 18), Color(0.35, 0.18, 0.08, 0.5))


## Fios pendurados entre os postes (com barriga), "gatos" embolados e tênis no fio.
func _desenhar_fiacao(rng: RandomNumberGenerator) -> void:
	var cor_fio := Color(0.05, 0.05, 0.05, 0.9)
	for i in range(_postes.size() - 1):
		var xa: float = _postes[i]
		var xb: float = _postes[i + 1]
		var ya := altura_em(xa) - ALTURA_FIOS
		var yb := altura_em(xb) - ALTURA_FIOS
		for f in 3:
			var off := -14.0 + f * 14.0
			var barriga := rng.randf_range(16, 34)
			var pts := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				var p := Vector2(lerpf(xa + off, xb + off, t), lerpf(ya, yb, t) - 6.0 + 4.0 * barriga * t * (1.0 - t))
				pts.append(p)
			draw_polyline(pts, cor_fio, 1.5)
			# Tênis amarrados pendurados no fio
			if f == 1 and rng.randf() < 0.12:
				var meio := pts[6]
				for lado in [-1.0, 1.0]:
					var pe: Vector2 = meio + Vector2(lado * 4, 16 + lado * 2)
					draw_line(meio, pe, cor_fio, 1.0)
					draw_rect(Rect2(pe.x - 4, pe.y, 9, 5), Color(0.85, 0.85, 0.82))
					draw_rect(Rect2(pe.x - 4, pe.y + 4, 9, 2), Config.COR_VERMELHO)
		# "Gato": rolo de fio embolado perto do poste
		if rng.randf() < 0.35:
			var c := Vector2(xa + rng.randf_range(10, 30), ya + rng.randf_range(4, 14))
			for k in 5:
				draw_arc(c + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3)), rng.randf_range(5, 10),
					0.0, TAU, 10, cor_fio, 1.0)
			draw_line(c, c + Vector2(rng.randf_range(-20, 20), rng.randf_range(20, 50)), cor_fio, 1.0)
		# Caixa de transformador em alguns postes
		if rng.randf() < 0.15:
			draw_rect(Rect2(xa + 5, ya + 12, 16, 22), Color(0.32, 0.34, 0.33))
			draw_rect(Rect2(xa + 5, ya + 12, 16, 22), cor_fio, false, 1.0)


## Lâmpadas dos postes. Algumas estão "com defeito" e piscam de vez em quando.
func _desenhar_luzes() -> void:
	for i in _postes.size():
		var x: float = _postes[i]
		var p := Vector2(x + 36, altura_em(x) - 232)
		var luz := 1.0
		if (i * 7919) % 5 == 0:
			# Falha: apaga em rajadas curtas, num ritmo diferente por poste
			var falha := sin(_t * (3.0 + i % 4) + i) + sin(_t * 17.0 + i * 1.7) * 0.6
			luz = 0.15 if falha > 1.05 else 1.0
		else:
			luz = 0.93 + 0.07 * sin(_t * 50.0 + i)   # zumbido leve
		_luzes.draw_circle(p, 26.0, Color(1.0, 0.6, 0.24, 0.10 * luz))
		_luzes.draw_circle(p, 10.0, Color(1.0, 0.65, 0.3, 0.12 * luz))
		_luzes.draw_circle(p, 6.0, Config.COR_LARANJA_CLARO.lerp(Color(0.25, 0.22, 0.2), 1.0 - luz))


func _elipse(c: Vector2, rx: float, ry: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		var k := rng.randf_range(0.8, 1.1)
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return pts
