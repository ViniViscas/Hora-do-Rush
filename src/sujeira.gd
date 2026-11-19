extends RefCounted
## Texturas "sujas" desenhadas por código, para dar o clima gritty da cidade:
## umidade subindo do chão, escorridos, manchas, rachaduras, reboco caído com tijolo
## aparente, pichação, lambe-lambe rasgado e lixo na calçada.
##
## Uso no _draw() de qualquer construção (r = retângulo da parede, base em r.end.y):
##   Sujeira.parede(self, r, rng)    logo depois de pintar a parede (fica embaixo das janelas)
##   Sujeira.por_cima(self, r, rng)  no fim do desenho (pichação e cartaz ficam por cima de tudo)
## O rng deve ter semente fixa: a mesma construção suja sempre do mesmo jeito.

const Config := preload("res://src/game_config.gd")

const COR_SUJO := Color(0.06, 0.05, 0.03)
const CORES_TINTA := [
	Color(0.07, 0.06, 0.06), Color(0.07, 0.06, 0.06), Color(0.07, 0.06, 0.06),   # preto é o mais comum
	Color(0.5, 0.1, 0.1), Color(0.14, 0.2, 0.45), Color(0.82, 0.82, 0.78), Color(0.2, 0.42, 0.24),
]
const CORES_CARTAZ := [Color(0.86, 0.83, 0.72), Color(0.92, 0.78, 0.25), Color(0.85, 0.55, 0.6), Color(0.6, 0.75, 0.85)]


## Camada de baixo: umidade, escorridos, manchas, reboco caído e rachaduras.
static func parede(c: CanvasItem, r: Rect2, rng: RandomNumberGenerator, intensidade: float = 1.0) -> void:
	_umidade(c, r, rng)
	for i in rng.randi_range(2, 4):
		_escorrido(c, Vector2(rng.randf_range(r.position.x + 4, r.end.x - 4), r.position.y + rng.randf_range(0, 12)),
			rng.randf_range(20, minf(90, r.size.y * 0.5)), rng)
	for i in rng.randi_range(1, 3):
		_mancha(c, Vector2(rng.randf_range(r.position.x + 10, r.end.x - 10), rng.randf_range(r.position.y + 20, r.end.y - 30)),
			rng.randf_range(8, 22), rng)
	if rng.randf() < 0.65 * intensidade:
		_reboco_caido(c, Vector2(rng.randf_range(r.position.x + 24, r.end.x - 24),
			rng.randf_range(r.position.y + 30, r.end.y - 40)), rng)
	if rng.randf() < 0.3 * intensidade:
		_reboco_caido(c, Vector2(rng.randf_range(r.position.x + 24, r.end.x - 24), r.end.y - rng.randf_range(14, 30)), rng)
	if rng.randf() < 0.55 * intensidade:
		_rachadura(c, Vector2(rng.randf_range(r.position.x + 10, r.end.x - 10), r.position.y + rng.randf_range(4, 40)),
			rng.randf_range(30, 70), rng)


## Camada de cima: pichação, pixo no alto, lambe-lambe e lixo encostado na parede.
static func por_cima(c: CanvasItem, r: Rect2, rng: RandomNumberGenerator, intensidade: float = 1.0) -> void:
	if rng.randf() < 0.6 * intensidade:
		tag(c, Vector2(rng.randf_range(r.position.x + 6, r.end.x - 60), r.end.y - rng.randf_range(24, 60)), rng)
	if r.size.y > 150 and rng.randf() < 0.45 * intensidade:
		pixo(c, Vector2(rng.randf_range(r.position.x + 6, r.end.x - 70), r.position.y + rng.randf_range(52, 66)), rng)   # abaixo das placas
	if rng.randf() < 0.4 * intensidade:
		_cartazes(c, Vector2(rng.randf_range(r.position.x + 8, r.end.x - 40), r.end.y - rng.randf_range(50, 80)), rng)
	if rng.randf() < 0.5 * intensidade:
		lixo(c, Vector2(rng.randf_range(r.position.x + 10, r.end.x - 10), r.end.y), rng)


## Faixa escura de umidade subindo do chão, com a borda de cima irregular.
static func _umidade(c: CanvasItem, r: Rect2, rng: RandomNumberGenerator) -> void:
	var alt := rng.randf_range(18, 46)
	for camada in 3:
		var pts := PackedVector2Array()
		var a := alt * (1.0 - camada * 0.3)
		pts.append(Vector2(r.position.x, r.end.y))
		var x := r.position.x
		while x < r.end.x:
			pts.append(Vector2(x, r.end.y - a + rng.randf_range(-6, 6)))
			x += rng.randf_range(8, 16)
		pts.append(Vector2(r.end.x, r.end.y - a))
		pts.append(Vector2(r.end.x, r.end.y))
		c.draw_colored_polygon(pts, Color(COR_SUJO, 0.12))


## Risco de sujeira escorrendo (chuva, ferrugem), mais grosso em cima e afinando.
static func _escorrido(c: CanvasItem, topo: Vector2, comp: float, rng: RandomNumberGenerator) -> void:
	var cor := Color(COR_SUJO, rng.randf_range(0.14, 0.26))
	if rng.randf() < 0.25:
		cor = Color(0.35, 0.18, 0.08, 0.25)   # ferrugem
	var w := rng.randf_range(3.0, 6.0)
	var p := topo
	var passos := 4
	for i in passos:
		var prox := p + Vector2(rng.randf_range(-1.5, 1.5), comp / passos)
		c.draw_line(p, prox, cor, w * (1.0 - float(i) / passos) + 0.8)
		p = prox


## Mancha irregular (mofo, graxa).
static func _mancha(c: CanvasItem, centro: Vector2, raio: float, rng: RandomNumberGenerator) -> void:
	c.draw_colored_polygon(_bolha(centro, raio, raio * rng.randf_range(0.5, 0.9), rng),
		Color(0.1, 0.11, 0.05, rng.randf_range(0.1, 0.2)))


## Pedaço de reboco que caiu, mostrando o tijolo por baixo.
static func _reboco_caido(c: CanvasItem, centro: Vector2, rng: RandomNumberGenerator) -> void:
	var rx := rng.randf_range(14, 30)
	var ry := rng.randf_range(9, 18)
	var buraco := _bolha(centro, rx, ry, rng)
	c.draw_colored_polygon(buraco, Color(0.42, 0.38, 0.34))   # argamassa
	var tijolo := Color(0.55, 0.29, 0.18)
	var y := centro.y - ry
	var linha := 0
	while y < centro.y + ry:
		var x := centro.x - rx + (6.0 if linha % 2 else 0.0)
		while x < centro.x + rx:
			var meio := Vector2(x + 5, y + 2.5)
			var d := Vector2((meio.x - centro.x) / rx, (meio.y - centro.y) / ry)
			if d.length() < 0.8:
				c.draw_rect(Rect2(x, y, 10, 4), tijolo.darkened(rng.randf_range(0.0, 0.25)))
			x += 12
		y += 6
		linha += 1
	buraco.append(buraco[0])
	c.draw_polyline(buraco, Color(0.62, 0.6, 0.56, 0.7), 2.0)   # borda do reboco quebrado


## Rachadura em zigue-zague, às vezes com um galho.
static func _rachadura(c: CanvasItem, inicio: Vector2, comp: float, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array([inicio])
	var p := inicio
	var passos := rng.randi_range(4, 7)
	for i in passos:
		p += Vector2(rng.randf_range(-9, 9), comp / passos)
		pts.append(p)
	c.draw_polyline(pts, Color(0.05, 0.05, 0.05, 0.55), 1.0)
	if rng.randf() < 0.6:
		var meio := pts[pts.size() / 2]
		c.draw_line(meio, meio + Vector2(rng.randf_range(-16, 16), rng.randf_range(6, 14)), Color(0.05, 0.05, 0.05, 0.45), 1.0)


## Tag: assinatura rabiscada com sublinhado, em altura de mão.
static func tag(c: CanvasItem, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var cor: Color = CORES_TINTA[rng.randi() % CORES_TINTA.size()]
	var largura := rng.randf_range(2.0, 3.0)
	var x := pos.x
	var letras := rng.randi_range(3, 5)
	for i in letras:
		var pts := PackedVector2Array()
		var alt := rng.randf_range(12, 18)
		for k in rng.randi_range(3, 5):
			pts.append(Vector2(x + rng.randf_range(0, 9), pos.y - rng.randf_range(0, alt)))
		c.draw_polyline(pts, cor, largura)
		x += rng.randf_range(9, 13)
	# Sublinhado com rabicho
	c.draw_polyline(PackedVector2Array([Vector2(pos.x - 2, pos.y + 4), Vector2(x, pos.y + 2),
		Vector2(x + 8, pos.y - 6)]), cor, largura * 0.8)


## Pixo paulistano: letras altas, retas e angulosas, enfileiradas no alto da parede.
static func pixo(c: CanvasItem, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var cor := Color(0.07, 0.06, 0.06) if rng.randf() < 0.8 else Color(0.5, 0.1, 0.1)
	var x := pos.x
	var alt := rng.randf_range(20, 30)
	for i in rng.randi_range(4, 7):
		var w := rng.randf_range(5, 9)
		var forma := rng.randi() % 4
		var pts := PackedVector2Array()
		match forma:
			0:   # tipo "N" esticado
				pts = PackedVector2Array([Vector2(x, pos.y + alt), Vector2(x, pos.y), Vector2(x + w, pos.y + alt), Vector2(x + w, pos.y)])
			1:   # tipo "A" pontudo
				pts = PackedVector2Array([Vector2(x, pos.y + alt), Vector2(x + w / 2, pos.y - 4), Vector2(x + w, pos.y + alt)])
			2:   # tipo "E" de traços
				pts = PackedVector2Array([Vector2(x + w, pos.y), Vector2(x, pos.y), Vector2(x, pos.y + alt), Vector2(x + w, pos.y + alt)])
				c.draw_line(Vector2(x, pos.y + alt / 2), Vector2(x + w * 0.8, pos.y + alt / 2), cor, 2.0)
			_:   # tipo "I" com serifa
				pts = PackedVector2Array([Vector2(x + w / 2, pos.y), Vector2(x + w / 2, pos.y + alt)])
				c.draw_line(Vector2(x, pos.y), Vector2(x + w, pos.y), cor, 2.0)
		c.draw_polyline(pts, cor, 2.0)
		x += w + rng.randf_range(4, 6)


## Lambe-lambe: cartazes colados uns sobre os outros, com canto rasgado.
static func _cartazes(c: CanvasItem, pos: Vector2, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(1, 3):
		var p := pos + Vector2(i * rng.randf_range(10, 18), rng.randf_range(-6, 6))
		var tam := Vector2(rng.randf_range(20, 28), rng.randf_range(26, 34))
		var cor: Color = CORES_CARTAZ[rng.randi() % CORES_CARTAZ.size()]
		c.draw_rect(Rect2(p, tam), Color(cor, 0.85))
		for k in 3:
			c.draw_line(p + Vector2(3, 6 + k * 6), p + Vector2(tam.x - rng.randf_range(3, 9), 6 + k * 6),
				Color(0.1, 0.1, 0.1, 0.5), 2.0)
		# Canto rasgado: um triângulo de "parede" por cima, com borda branca de papel
		var canto := p + Vector2(tam.x, tam.y)
		var corte := rng.randf_range(6, 12)
		c.draw_colored_polygon(PackedVector2Array([canto, canto - Vector2(corte, 0), canto - Vector2(0, corte * 1.3)]),
			Color(0.2, 0.18, 0.16, 0.9))
		c.draw_line(canto - Vector2(corte, 0), canto - Vector2(0, corte * 1.3), Color(0.9, 0.88, 0.8, 0.8), 1.0)


## Lixo encostado na parede: saco preto, caixa de papelão, latinha, papel amassado.
static func lixo(c: CanvasItem, base: Vector2, rng: RandomNumberGenerator) -> void:
	var x := base.x
	for i in rng.randi_range(1, 3):
		match rng.randi() % 4:
			0:   # saco de lixo preto com o nó em cima
				var s := _bolha(Vector2(x, base.y - 8), rng.randf_range(9, 13), 8.0, rng)
				c.draw_colored_polygon(s, Color(0.08, 0.08, 0.09))
				c.draw_line(Vector2(x, base.y - 15), Vector2(x + 2, base.y - 21), Color(0.08, 0.08, 0.09), 3.0)
				c.draw_line(Vector2(x - 4, base.y - 10), Vector2(x + 2, base.y - 4), Color(0.3, 0.3, 0.32, 0.6), 1.0)
			1:   # caixa de papelão amassada
				var w := rng.randf_range(14, 22)
				c.draw_rect(Rect2(x - w / 2, base.y - 12, w, 12), Color(0.5, 0.37, 0.22))
				c.draw_line(Vector2(x - w / 2, base.y - 12), Vector2(x - w / 2 - 6, base.y - 17), Color(0.45, 0.33, 0.2), 2.0)
			2:   # latinha deitada
				c.draw_rect(Rect2(x - 4, base.y - 4, 8, 4), Config.COR_VERMELHO if rng.randf() < 0.5 else Config.COR_CINZA_CLARO)
			_:   # papel amassado
				c.draw_colored_polygon(_bolha(Vector2(x, base.y - 3), 4.0, 3.0, rng), Color(0.8, 0.78, 0.7, 0.9))
		x += rng.randf_range(12, 22)


## Polígono de contorno irregular em volta de um centro (base de manchas, buracos, sacos).
static func _bolha(centro: Vector2, rx: float, ry: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 9
	for i in n:
		var a := TAU * i / n
		var k := rng.randf_range(0.7, 1.15)
		pts.append(centro + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return pts
