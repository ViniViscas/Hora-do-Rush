extends Node2D
## Construções decorativas que preenchem a rua entre os pontos de entrega.
## A posição é o centro da base. As texturas "sujas" vêm de sujeira.gd.

const Config := preload("res://src/game_config.gd")
const Sujeira := preload("res://src/sujeira.gd")

const TIPOS := ["sobrado", "sobrado", "loja", "bar", "borracharia", "muro", "terreno", "predio", "predio"]

var tipo := "sobrado"
var largura := 160.0
var semente := 0

var _rs := RandomNumberGenerator.new()   # sorteios da sujeira (separados do desenho)
var _r_suja := Rect2()                   # parede que recebe pichação/cartaz/lixo por cima


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	_rs.seed = semente * 7919 + 13
	_r_suja = Rect2()
	match tipo:
		"sobrado":
			_sobrado(rng)
		"loja":
			_loja(rng)
		"bar":
			_bar(rng)
		"borracharia":
			_borracharia(rng)
		"muro":
			_muro(rng)
		"terreno":
			_terreno(rng)
		"predio":
			_predio(rng)
	if _r_suja.has_area():
		Sujeira.por_cima(self, _r_suja, _rs)


## Suja a parede logo depois de pintada (umidade, reboco caído...), embaixo das janelas.
func _sujar(r: Rect2, intensidade: float = 1.0) -> void:
	_r_suja = r
	Sujeira.parede(self, r, _rs, intensidade)


func _parede(rng: RandomNumberGenerator) -> Color:
	var cores := [Color(0.36, 0.33, 0.31), Color(0.42, 0.36, 0.3), Color(0.33, 0.33, 0.34),
		Color(0.45, 0.4, 0.34), Color(0.4, 0.3, 0.27)]
	return cores[rng.randi() % cores.size()]


func _janela(r: Rect2, acesa: bool) -> void:
	draw_rect(r, Color(0.85, 0.55, 0.22, 0.85) if acesa else Color(0.12, 0.12, 0.13))
	draw_rect(r, Config.COR_PRETO, false, 2.0)
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Config.COR_PRETO, 1.5)


func _texto(pos: Vector2, largura_txt: float, texto: String, tam: int, cor: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, texto, HORIZONTAL_ALIGNMENT_CENTER, largura_txt, tam, cor)


## Maior tamanho de fonte (até "maximo") em que o texto cabe na largura.
func _tam_cabe(texto: String, largura_max: float, maximo: int) -> int:
	var tam := maximo
	while tam > 8 and ThemeDB.fallback_font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura_max:
		tam -= 1
	return tam


func _sobrado(rng: RandomNumberGenerator) -> void:
	var w := largura
	var h := rng.randf_range(190, 250)
	var tijolo := rng.randf() < 0.55
	var cor := Color(0.52, 0.27, 0.16) if tijolo else _parede(rng)
	draw_rect(Rect2(-w / 2, -h, w, h + 60), cor)
	if tijolo:
		var y := -h
		while y < 0:
			draw_line(Vector2(-w / 2, y), Vector2(w / 2, y), cor.darkened(0.25), 1.0)
			y += 8
	_sujar(Rect2(-w / 2, -h, w, h))
	draw_rect(Rect2(-w / 2 - 4, -h, w + 8, 8), Color(0.5, 0.5, 0.48))
	draw_rect(Rect2(-w / 2 - 4, -h / 2 - 4, w + 8, 6), Color(0.5, 0.5, 0.48))
	# Caixa d'água
	draw_rect(Rect2(w / 2 - 50, -h - 26, 36, 26), Color(0.3, 0.33, 0.36))
	for andar in 2:
		var y := -h + 24 + andar * h / 2
		_janela(Rect2(-w / 2 + 16, y, 34, 30), rng.randf() < 0.35)
		if w > 150:
			_janela(Rect2(w / 2 - 50, y, 34, 30), rng.randf() < 0.35)
	# Varal no andar de cima
	if rng.randf() < 0.5:
		var vy := -h + 70
		draw_line(Vector2(-w / 2 + 8, vy), Vector2(w / 2 - 8, vy), Config.COR_PRETO, 1.0)
		var x := -w / 2 + 16
		while x < w / 2 - 20:
			var cores := [Config.COR_VERMELHO, Config.COR_CINZA_CLARO, Config.COR_LARANJA, Color(0.2, 0.25, 0.35)]
			draw_rect(Rect2(x, vy, 12, rng.randf_range(14, 22)), cores[rng.randi() % cores.size()])
			x += rng.randf_range(16, 26)
	# Portão
	draw_rect(Rect2(-24, -64, 48, 64), Color(0.2, 0.2, 0.21))
	for i in 5:
		draw_line(Vector2(-20 + i * 10, -62), Vector2(-20 + i * 10, 0), Config.COR_CINZA, 2.0)


func _loja(rng: RandomNumberGenerator) -> void:
	var w := largura
	var h := rng.randf_range(140, 180)
	draw_rect(Rect2(-w / 2, -h, w, h + 60), _parede(rng))
	_sujar(Rect2(-w / 2, -h, w, h))
	var porta := Rect2(-w / 2 + 12, -104, w - 24, 104)
	draw_rect(porta, Color(0.42, 0.42, 0.42))
	var y := porta.position.y
	while y < 0:
		draw_line(Vector2(porta.position.x, y), Vector2(porta.end.x, y), Color(0.3, 0.3, 0.3), 2.0)
		y += 7
	var placas := ["ALUGA-SE", "VENDE-SE", "PASSA-SE O PONTO", "CELULARES", "MODAS", "AÇOUGUE"]
	var placa: String = placas[rng.randi() % placas.size()]
	draw_rect(Rect2(-w / 2 + 8, -h + 14, w - 16, 30), Config.COR_PAPEL.darkened(0.2))
	_texto(Vector2(-w / 2 + 8, -h + 35), w - 16, placa, _tam_cabe(placa, w - 20, 15), Config.COR_VERMELHO)


func _bar(rng: RandomNumberGenerator) -> void:
	var w := largura
	var h := rng.randf_range(150, 190)
	draw_rect(Rect2(-w / 2, -h, w, h + 60), _parede(rng))
	_sujar(Rect2(-w / 2, -h, w, h))
	draw_rect(Rect2(-w / 2 + 12, -100, w - 24, 100), Color(0.16, 0.12, 0.1))
	draw_rect(Rect2(-w / 2 + 12, -100, w - 24, 100), Color(0.85, 0.55, 0.2, 0.25))
	# Balcão e garrafas
	draw_rect(Rect2(-w / 2 + 20, -46, w - 40, 12), Color(0.35, 0.22, 0.12))
	for i in int((w - 50) / 12):
		draw_rect(Rect2(-w / 2 + 24 + i * 12, -84, 6, 16), Color(0.3, 0.45, 0.25, 0.9) if i % 3 else Config.COR_LARANJA)
	var nomes := ["BAR DO TONHO", "BOTECO", "BAR E LANCHES", "BAR DA ESQUINA"]
	draw_rect(Rect2(-w / 2 + 8, -h + 14, w - 16, 32), Config.COR_PRETO)
	var nome: String = nomes[rng.randi() % nomes.size()]
	_texto(Vector2(-w / 2 + 8, -h + 36), w - 16, nome, _tam_cabe(nome, w - 20, 15), Config.COR_LARANJA_CLARO)
	# Mesa e cadeiras de plástico na calçada
	var mx := rng.randf_range(-w / 4, w / 4)
	draw_rect(Rect2(mx - 16, -30, 32, 4), Config.COR_VERMELHO)
	draw_line(Vector2(mx, -26), Vector2(mx, 0), Config.COR_VERMELHO, 3.0)
	for lado in [-1.0, 1.0]:
		var cx: float = mx + lado * 28
		draw_rect(Rect2(cx - 8, -18, 16, 4), Config.COR_VERMELHO)
		draw_line(Vector2(cx - lado * 8, -18), Vector2(cx - lado * 8, -40), Config.COR_VERMELHO, 3.0)
		draw_line(Vector2(cx - 6, -14), Vector2(cx - 6, 0), Config.COR_VERMELHO, 2.0)
		draw_line(Vector2(cx + 6, -14), Vector2(cx + 6, 0), Config.COR_VERMELHO, 2.0)


func _borracharia(rng: RandomNumberGenerator) -> void:
	var w := largura
	var h := rng.randf_range(140, 170)
	draw_rect(Rect2(-w / 2, -h, w, h + 60), _parede(rng))
	_sujar(Rect2(-w / 2, -h, w, h))
	draw_rect(Rect2(-w / 2 + 14, -96, w * 0.55, 96), Color(0.1, 0.1, 0.1))
	# Pilha de pneus
	var px := w / 2 - 34
	for i in rng.randi_range(3, 5):
		var py := -12 - i * 18
		draw_rect(Rect2(px - 22, py - 9, 44, 18), Config.COR_PRETO)
		draw_rect(Rect2(px - 10, py - 4, 20, 8), Color(0.25, 0.25, 0.25))
	# Placa pintada à mão, torta
	draw_set_transform(Vector2(0, -h + 34), rng.randf_range(-0.06, 0.06), Vector2.ONE)
	draw_rect(Rect2(-w / 2 + 8, -16, w - 16, 32), Config.COR_PAPEL.darkened(0.1))
	_texto(Vector2(-w / 2 + 8, 6), w - 16, "BORRACHARIA 24H", _tam_cabe("BORRACHARIA 24H", w - 20, 14),
		Config.COR_VERMELHO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _muro(rng: RandomNumberGenerator) -> void:
	var w := largura
	var h := rng.randf_range(100, 140)
	draw_rect(Rect2(-w / 2, -h, w, h + 60), Color(0.4, 0.39, 0.37))
	_sujar(Rect2(-w / 2, -h, w, h), 1.3)
	var x := -w / 2
	while x < w / 2:
		draw_line(Vector2(x, -h), Vector2(x, 0), Color(0.33, 0.32, 0.3), 1.0)
		x += 40
	# Arame farpado em cima
	draw_line(Vector2(-w / 2, -h - 6), Vector2(w / 2, -h - 6), Config.COR_CINZA_CLARO, 1.0)
	x = -w / 2 + 6
	while x < w / 2:
		draw_arc(Vector2(x, -h - 8), 6.0, 0, TAU, 8, Config.COR_CINZA_CLARO, 1.0)
		x += 12
	# Pichação
	for i in rng.randi_range(1, 3):
		var px := rng.randf_range(-w / 2 + 10, w / 2 - 60)
		var py := rng.randf_range(-h + 20, -30)
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(Vector2(px + k * 9, py + (0.0 if k % 2 else 18.0)))
		draw_polyline(pts, Config.COR_PRETO, 3.0)


func _terreno(rng: RandomNumberGenerator) -> void:
	var w := largura
	# Tapume de madeira com tábuas faltando
	var x := -w / 2
	while x < w / 2:
		if rng.randf() > 0.12:
			var tw := minf(18.0, w / 2 - x)
			draw_rect(Rect2(x, -120, tw - 2, 120), Color(0.4, 0.29, 0.18).darkened(rng.randf_range(0, 0.3)))
		x += 18
	draw_line(Vector2(-w / 2, -96), Vector2(w / 2, -96), Color(0.25, 0.17, 0.1), 3.0)
	draw_line(Vector2(-w / 2, -30), Vector2(w / 2, -30), Color(0.25, 0.17, 0.1), 3.0)
	# Mato
	for i in int(w / 6):
		var mx := rng.randf_range(-w / 2, w / 2)
		draw_line(Vector2(mx, 0), Vector2(mx + rng.randf_range(-6, 6), -rng.randf_range(8, 26)),
			Color(0.3, 0.35, 0.18), 2.0)
	# Entulho
	var ex := rng.randf_range(-w / 4, w / 4)
	draw_colored_polygon(PackedVector2Array([
		Vector2(ex - 34, 0), Vector2(ex - 10, -24), Vector2(ex + 14, -18), Vector2(ex + 36, 0)]), Color(0.45, 0.43, 0.4))
	_r_suja = Rect2(-w / 2, -120, w, 120)   # tapume: só pichação, cartaz e lixo


func _predio(rng: RandomNumberGenerator) -> void:
	var w := largura
	var andares := rng.randi_range(4, 6)
	var h := 60.0 * andares + 30.0
	draw_rect(Rect2(-w / 2, -h, w, h + 60), _parede(rng).darkened(0.1))
	_sujar(Rect2(-w / 2, -h, w, h))
	for a in andares:
		var y := -h + 20 + a * 60
		var x := -w / 2 + 14
		while x < w / 2 - 34:
			_janela(Rect2(x, y, 30, 34), rng.randf() < 0.3)
			# grade
			for g in 3:
				draw_line(Vector2(x + 8 + g * 8, y), Vector2(x + 8 + g * 8, y + 34), Config.COR_PRETO, 1.0)
			if rng.randf() < 0.2:
				draw_rect(Rect2(x + 4, y + 36, 22, 12), Color(0.6, 0.6, 0.58))   # ar-condicionado
			x += 46
	draw_rect(Rect2(-30, -70, 60, 70), Color(0.15, 0.15, 0.16))
	_texto(Vector2(-30, -74), 60, "Ed. %d" % rng.randi_range(10, 999), 11, Config.COR_PAPEL)
	draw_line(Vector2(w / 4, -h), Vector2(w / 4, -h - 40), Config.COR_PRETO, 2.0)
