extends Node2D
## Desenho (e estado do cruzamento) dos obstáculos do M2 que ficam na pista:
## lombada, boca de lobo, estrada de terra, ciclovia, blitz e cruzamento.
## Fica na posição (0, 0) e desenha em coordenadas do mundo, seguindo o chão.

const Config := preload("res://scripts/game_config.gd")

enum Sinal { VERDE, AMARELO, CARRO }

const T_VERDE := 2.6
const T_AMARELO := 1.0
const T_CARRO := 1.4

var tipo := ""
var x0 := 0.0
var x1 := 0.0
var chao  # ground.gd
var ativo := true

# Cruzamento
var sinal := Sinal.VERDE
var t_sinal := 0.0
var atingiu_neste_ciclo := false
var _cor_carro := Color.GRAY
var _no_carro: Node2D   # desenhado na frente da moto

# Blitz
var sorteado := false
var vel_vista := 0.0


func cx() -> float:
	return (x0 + x1) * 0.5


func contem(x: float) -> bool:
	return ativo and x >= x0 and x <= x1


func _y(x: float) -> float:
	return chao.altura_em(x)


# ---------------------------------------------------------------- cruzamento

func iniciar_cruzamento(defasagem: float) -> void:
	sinal = Sinal.VERDE
	t_sinal = defasagem
	_no_carro = Node2D.new()
	_no_carro.z_index = 3
	_no_carro.draw.connect(_desenhar_carro_frente)
	add_child(_no_carro)


func atualizar_cruzamento(delta: float) -> void:
	t_sinal -= delta
	if t_sinal <= 0.0:
		match sinal:
			Sinal.VERDE:
				sinal = Sinal.AMARELO
				t_sinal = T_AMARELO
			Sinal.AMARELO:
				sinal = Sinal.CARRO
				t_sinal = T_CARRO
				atingiu_neste_ciclo = false
				var cores := [Color(0.55, 0.55, 0.55), Color(0.15, 0.15, 0.16), Color(0.6, 0.15, 0.12), Color(0.85, 0.83, 0.78)]
				_cor_carro = cores[randi() % cores.size()]
			Sinal.CARRO:
				sinal = Sinal.VERDE
				t_sinal = T_VERDE
	queue_redraw()
	_no_carro.queue_redraw()


## Progresso do carro atravessando (0 = surgindo no fundo, 1 = passou).
func progresso_carro() -> float:
	return 1.0 - t_sinal / T_CARRO if sinal == Sinal.CARRO else 0.0


## O carro já está na pista (atinge quem estiver no cruzamento).
func perigoso() -> bool:
	var p := progresso_carro()
	return sinal == Sinal.CARRO and p > 0.3 and p < 0.92


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if not ativo or chao == null:
		return
	match tipo:
		"lombada":
			_desenhar_lombada()
		"boca":
			_desenhar_boca()
		"terra":
			_desenhar_terra()
		"ciclovia":
			_desenhar_ciclovia()
		"blitz":
			_desenhar_blitz()
		"cruzamento":
			_desenhar_cruzamento()


func _desenhar_lombada() -> void:
	var c := cx()
	var g := _y(c)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(Vector2(c - 46 + 92 * t, g - 14.0 * sin(PI * t)))
	pts.append(Vector2(c + 46, g + 2))
	pts.append(Vector2(c - 46, g + 2))
	draw_colored_polygon(pts, Config.COR_AMARELO)
	for i in 5:
		var x := c - 40 + i * 18
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, g + 1), Vector2(x + 8, g + 1), Vector2(x + 14, g - 12), Vector2(x + 6, g - 12)]),
			Config.COR_PRETO)
	draw_polyline(pts.slice(0, 13), Config.COR_PRETO, 2.0)
	# Placa de aviso antes da lombada
	for lado in [-1.0, 1.0]:
		var px: float = c + lado * 230.0
		var py := _y(px)
		draw_rect(Rect2(px - 2, py - 110, 4, 110), Config.COR_CINZA)
		draw_colored_polygon(PackedVector2Array([
			Vector2(px, py - 142), Vector2(px + 20, py - 122), Vector2(px, py - 102), Vector2(px - 20, py - 122)]),
			Config.COR_AMARELO)
		draw_arc(Vector2(px, py - 114), 9.0, PI, TAU, 8, Config.COR_PRETO, 3.0)


func _desenhar_boca() -> void:
	var c := cx()
	var g := _y(c)
	draw_rect(Rect2(c - 34, g - 2, 68, 18), Config.COR_PRETO)
	for i in 7:
		var x := c - 30 + i * 10
		draw_line(Vector2(x, g), Vector2(x, g + 14), Config.COR_CINZA, 2.0)
	draw_line(Vector2(c - 34, g), Vector2(c + 34, g), Config.COR_CINZA_CLARO, 2.0)
	# Meio-fio quebrado em volta
	draw_colored_polygon(PackedVector2Array([
		Vector2(c - 48, g), Vector2(c - 34, g), Vector2(c - 34, g + 8), Vector2(c - 44, g + 14)]), Config.COR_PRETO)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c + 34, g), Vector2(c + 52, g), Vector2(c + 40, g + 12), Vector2(c + 34, g + 10)]), Config.COR_PRETO)


func _desenhar_terra() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0)
	var topo := PackedVector2Array()
	var x := x0
	while x <= x1:
		topo.append(Vector2(x, _y(x) - 3.0))
		x += 40.0
	topo.append(Vector2(x1, _y(x1) - 3.0))
	var poli := PackedVector2Array(topo)
	poli.append(Vector2(x1, _y(x1) + 34))
	poli.append(Vector2(x0, _y(x0) + 34))
	draw_colored_polygon(poli, Color(0.36, 0.25, 0.16))
	draw_polyline(topo, Color(0.45, 0.32, 0.2), 3.0)
	# Pedras, poças e marcas de pneu
	for i in int((x1 - x0) / 25.0):
		var px := rng.randf_range(x0 + 6, x1 - 6)
		var py := _y(px) + rng.randf_range(2, 28)
		draw_circle(Vector2(px, py), rng.randf_range(1.5, 4.0), Color(0.5, 0.45, 0.4))
	for i in int((x1 - x0) / 220.0):
		var px := rng.randf_range(x0 + 30, x1 - 60)
		var py := _y(px) + 6
		draw_rect(Rect2(px, py, rng.randf_range(30, 60), 5), Color(0.2, 0.15, 0.1))
		draw_line(Vector2(px + 4, py + 1), Vector2(px + 20, py + 1), Color(0.6, 0.5, 0.4, 0.5), 1.0)
	draw_line(Vector2(x0, _y(x0) + 14), Vector2(x1, _y(x1) + 14), Color(0.28, 0.19, 0.12), 2.0)
	# Placa
	var sx := x0 - 40
	var sy := _y(sx)
	draw_rect(Rect2(sx - 2, sy - 90, 4, 90), Color(0.3, 0.22, 0.14))
	draw_rect(Rect2(sx - 44, sy - 116, 88, 28), Color(0.42, 0.3, 0.18))
	draw_string(ThemeDB.fallback_font, Vector2(sx - 44, sy - 96), "SEM ASFALTO", HORIZONTAL_ALIGNMENT_CENTER,
		88, 12, Config.COR_PAPEL)


func _desenhar_ciclovia() -> void:
	var cor := Color(0.62, 0.15, 0.12)
	var x := x0
	while x < x1:
		var xb := minf(x + 40.0, x1)
		var a := Vector2(x, _y(x))
		var b := Vector2(xb, _y(xb))
		draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 9), a + Vector2(0, 9)]), cor)
		x = xb
	# Bicicletas pintadas
	var bx := x0 + 80.0
	while bx < x1 - 40.0:
		var by := _y(bx) + 4
		draw_arc(Vector2(bx - 8, by), 4.0, 0, TAU, 10, Config.COR_PAPEL, 1.5)
		draw_arc(Vector2(bx + 8, by), 4.0, 0, TAU, 10, Config.COR_PAPEL, 1.5)
		draw_line(Vector2(bx - 8, by), Vector2(bx, by - 3), Config.COR_PAPEL, 1.5)
		draw_line(Vector2(bx, by - 3), Vector2(bx + 8, by), Config.COR_PAPEL, 1.5)
		bx += 160.0
	# Placa
	var px := x0 + 20
	var py := _y(px)
	draw_rect(Rect2(px - 2, py - 100, 4, 100), Config.COR_CINZA)
	draw_rect(Rect2(px - 26, py - 132, 52, 34), cor)
	draw_string(ThemeDB.fallback_font, Vector2(px - 26, py - 110), "CICLO", HORIZONTAL_ALIGNMENT_CENTER,
		52, 13, Config.COR_PAPEL)


func _desenhar_blitz() -> void:
	var fonte := ThemeDB.fallback_font
	# Cones ao longo da faixa
	var x := x0
	while x <= x1:
		var g := _y(x)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8, g), Vector2(x + 8, g), Vector2(x + 2, g - 22), Vector2(x - 2, g - 22)]), Config.COR_LARANJA)
		draw_line(Vector2(x - 5, g - 9), Vector2(x + 5, g - 9), Config.COR_PAPEL, 3.0)
		x += 80.0
	# Viatura parada no meio
	var c := cx()
	var g := _y(c)
	var base := Vector2(c + 40, g - 60)
	draw_rect(Rect2(base + Vector2(-80, 14), Vector2(160, 34)), Color(0.85, 0.85, 0.82))
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-48, 14), base + Vector2(-30, -10), base + Vector2(34, -10), base + Vector2(54, 14)]),
		Color(0.85, 0.85, 0.82))
	draw_rect(Rect2(base + Vector2(-26, -6), Vector2(26, 18)), Color(0.15, 0.17, 0.2))
	draw_rect(Rect2(base + Vector2(4, -6), Vector2(26, 18)), Color(0.15, 0.17, 0.2))
	draw_rect(Rect2(base + Vector2(-80, 30), Vector2(160, 8)), Config.COR_VERMELHO)
	draw_string(fonte, base + Vector2(-80, 30), "POLÍCIA", HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Config.COR_PRETO)
	draw_rect(Rect2(base + Vector2(-16, -18), Vector2(32, 8)), Config.COR_VERMELHO)
	for rx in [-50.0, 50.0]:
		draw_circle(base + Vector2(rx, 48), 13.0, Config.COR_PRETO)
		draw_circle(base + Vector2(rx, 48), 6.0, Config.COR_CINZA)
	# Policial com colete
	var p := Vector2(c - 70, g)
	draw_line(p + Vector2(-4, 0), p + Vector2(-3, -26), Color(0.15, 0.17, 0.2), 5.0)
	draw_line(p + Vector2(4, 0), p + Vector2(3, -26), Color(0.15, 0.17, 0.2), 5.0)
	draw_rect(Rect2(p + Vector2(-10, -56), Vector2(20, 32)), Config.COR_LARANJA)
	draw_line(p + Vector2(10, -50), p + Vector2(24, -64), Config.COR_LARANJA, 5.0)
	draw_circle(p + Vector2(0, -66), 9.0, Color(0.7, 0.52, 0.4))
	draw_rect(Rect2(p + Vector2(-10, -78), Vector2(20, 6)), Color(0.15, 0.17, 0.2))
	# Placa antes da blitz (dos dois lados)
	for sx in [x0 - 120.0, x1 + 120.0]:
		var sy := _y(sx)
		draw_rect(Rect2(sx - 2, sy - 96, 4, 96), Config.COR_CINZA)
		draw_rect(Rect2(sx - 52, sy - 140, 104, 46), Config.COR_VERMELHO)
		draw_string(fonte, Vector2(sx - 52, sy - 121), "BLITZ", HORIZONTAL_ALIGNMENT_CENTER, 104, 16, Config.COR_PAPEL)
		draw_string(fonte, Vector2(sx - 52, sy - 102), "REDUZA", HORIZONTAL_ALIGNMENT_CENTER, 104, 13, Config.COR_PAPEL)


func _desenhar_cruzamento() -> void:
	var c := cx()
	var g := _y(c)
	# Rua transversal indo para o fundo
	draw_colored_polygon(PackedVector2Array([
		Vector2(c - 100, g), Vector2(c + 100, g), Vector2(c + 34, g - 150), Vector2(c - 34, g - 150)]),
		Color(0.2, 0.19, 0.19))
	draw_line(Vector2(c, g - 4), Vector2(c, g - 146), Color(0.8, 0.7, 0.3, 0.6), 2.0)
	# Faixa de pedestre
	for i in 9:
		var x := c - 96 + i * 22
		draw_rect(Rect2(x, g, 12, 8), Config.COR_PAPEL.darkened(0.15))

	# Semáforo
	var sx := c + 116
	draw_rect(Rect2(sx - 3, g - 170, 6, 170), Config.COR_PRETO)
	draw_rect(Rect2(sx - 14, g - 228, 28, 64), Config.COR_PRETO)
	var acesa := [Color(0.2, 0.75, 0.3), Config.COR_AMARELO, Config.COR_VERMELHO]
	var apagada := Color(0.18, 0.18, 0.18)
	var piscando := sinal == Sinal.AMARELO and int(t_sinal * 8.0) % 2 == 0
	draw_circle(Vector2(sx, g - 216), 7.0, acesa[2] if sinal == Sinal.CARRO else apagada)
	draw_circle(Vector2(sx, g - 196), 7.0, acesa[1] if sinal == Sinal.AMARELO and not piscando else apagada)
	draw_circle(Vector2(sx, g - 176), 7.0, acesa[0] if sinal == Sinal.VERDE else apagada)

	# Faróis do carro chegando (aviso)
	if sinal == Sinal.AMARELO:
		draw_circle(Vector2(c - 10, g - 140), 3.0, Color(1, 0.9, 0.6))
		draw_circle(Vector2(c + 10, g - 140), 3.0, Color(1, 0.9, 0.6))


func _desenhar_carro_frente() -> void:
	if sinal != Sinal.CARRO:
		return
	var c := cx()
	var g := _y(c)
	var ci := _no_carro
	# Vem do fundo da rua (pequeno) até a frente da tela (grande).
	var e := ease(progresso_carro(), 1.6)
	var esc := lerpf(0.25, 1.35, e)
	var base_y := lerpf(g - 140.0, g + 40.0, e)
	ci.draw_set_transform(Vector2(c, base_y), 0.0, Vector2(esc, esc))
	ci.draw_rect(Rect2(-80, -60, 160, 50), _cor_carro)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-62, -60), Vector2(62, -60), Vector2(46, -100), Vector2(-46, -100)]), _cor_carro.darkened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-54, -62), Vector2(54, -62), Vector2(42, -94), Vector2(-42, -94)]), Color(0.12, 0.14, 0.17))
	ci.draw_rect(Rect2(-74, -44, 26, 12), Color(1, 0.92, 0.65))
	ci.draw_rect(Rect2(48, -44, 26, 12), Color(1, 0.92, 0.65))
	ci.draw_rect(Rect2(-36, -42, 72, 14), Config.COR_PRETO)
	ci.draw_rect(Rect2(-20, -24, 40, 10), Config.COR_PAPEL)
	ci.draw_rect(Rect2(-84, -12, 30, 14), Config.COR_PRETO)
	ci.draw_rect(Rect2(54, -12, 30, 14), Config.COR_PRETO)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
