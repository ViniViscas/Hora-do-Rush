extends Node2D
## Personagens da oficina, desenhados por código em baixa resolução (1 unidade = 1 "pixel"
## da pixel art). A tela da oficina mostra este nó dentro de um SubViewport ampliado 4x
## sem suavização, para combinar com o fundo em pixel art.
## A posição é o meio dos pés; o personagem tem ~86 unidades de altura.

const Config := preload("res://src/game_config.gd")

enum Expressao { NEUTRA, FELIZ, BRAVA }

var tipo := "mecanica"        # "mecanica" | "entregador"
var olhando_direita := true
var expressao := Expressao.NEUTRA
var falando := false
var gesto := 0.0              # 0..1: braço da frente levantado (comemoração, explicação)
var cor_bag := Color(0.8, 0.15, 0.12)
var cor_bag_detalhe := Color(0.95, 0.95, 0.9)

var _t := 0.0
var _piscar := 0.0
var _prox_piscada := 2.5

const CONTORNO := Color(0.05, 0.05, 0.06)
const PELE_MECANICA := Color(0.76, 0.56, 0.42)
const PELE_ENTREGADOR := Color(0.5, 0.33, 0.23)
const CABELO := Color(0.07, 0.06, 0.07)
const MACACAO := Color(0.25, 0.31, 0.39)
const MACACAO_SOMBRA := Color(0.18, 0.22, 0.29)
const GRAXA := Color(0.1, 0.09, 0.08, 0.55)
const LUVA := Color(0.32, 0.32, 0.32)
const METAL := Color(0.72, 0.73, 0.75)
const JAQUETA := Color(0.16, 0.16, 0.18)
const JAQUETA_LUZ := Color(0.25, 0.25, 0.28)
const JEANS := Color(0.18, 0.22, 0.32)
const CAPACETE := Color(0.27, 0.33, 0.22)


func _process(delta: float) -> void:
	_t += delta
	_prox_piscada -= delta
	if _prox_piscada <= 0.0:
		_piscar = 0.13
		_prox_piscada = randf_range(2.0, 4.5)
	_piscar = maxf(_piscar - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# Respiração: o corpo sobe 1 pixel de vez em quando
	var resp := 1.0 if sin(_t * 2.2) > 0.6 else 0.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1 if olhando_direita else -1, 1))
	if tipo == "mecanica":
		_mecanica(resp)
	else:
		_entregador(resp)


# ---------------------------------------------------------------- utilidades

## Forma com contorno escuro de 1 pixel (o "outline" típico de pixel art).
func _forma(pts: PackedVector2Array, cor: Color) -> void:
	draw_colored_polygon(pts, cor)
	var fechado := PackedVector2Array(pts)
	fechado.append(pts[0])
	draw_polyline(fechado, CONTORNO, 1.0)


func _membro(a: Vector2, b: Vector2, largura: float, cor: Color) -> void:
	draw_line(a, b, CONTORNO, largura + 2.0)
	draw_line(a, b, cor, largura)


func _olhos(centro: Vector2, cor_olho: Color) -> void:
	if _piscar > 0.0:
		draw_line(centro + Vector2(-2, 0), centro + Vector2(-1, 0), CONTORNO, 1.0)
		draw_line(centro + Vector2(2, 0), centro + Vector2(3, 0), CONTORNO, 1.0)
		return
	draw_rect(Rect2(centro + Vector2(-2, -1), Vector2(2, 2)), Color(0.95, 0.93, 0.9))
	draw_rect(Rect2(centro + Vector2(2, -1), Vector2(2, 2)), Color(0.95, 0.93, 0.9))
	draw_rect(Rect2(centro + Vector2(-1, -1), Vector2(1, 2)), cor_olho)
	draw_rect(Rect2(centro + Vector2(3, -1), Vector2(1, 2)), cor_olho)


func _sobrancelhas(centro: Vector2, cor: Color) -> void:
	var y := centro.y - 3
	match expressao:
		Expressao.BRAVA:   # inclinadas para dentro
			draw_line(Vector2(centro.x - 3, y - 1), Vector2(centro.x, y + 1), cor, 1.0)
			draw_line(Vector2(centro.x + 2, y + 1), Vector2(centro.x + 5, y - 1), cor, 1.0)
		Expressao.FELIZ:   # levantadas
			draw_line(Vector2(centro.x - 3, y - 1), Vector2(centro.x - 1, y - 1), cor, 1.0)
			draw_line(Vector2(centro.x + 2, y - 1), Vector2(centro.x + 4, y - 1), cor, 1.0)
		_:
			draw_line(Vector2(centro.x - 3, y), Vector2(centro.x - 1, y), cor, 1.0)
			draw_line(Vector2(centro.x + 2, y), Vector2(centro.x + 4, y), cor, 1.0)


func _boca(centro: Vector2) -> void:
	var cor := Color(0.35, 0.12, 0.1)
	if falando and int(_t * 9.0) % 2 == 0:
		draw_rect(Rect2(centro + Vector2(-1, -1), Vector2(3, 2)), cor)   # aberta
		return
	match expressao:
		Expressao.FELIZ:
			draw_line(centro + Vector2(-2, -1), centro + Vector2(-1, 0), cor, 1.0)
			draw_line(centro + Vector2(-1, 0), centro + Vector2(2, 0), cor, 1.0)
			draw_line(centro + Vector2(2, 0), centro + Vector2(3, -1), cor, 1.0)
		Expressao.BRAVA:
			draw_line(centro + Vector2(-1, 0), centro + Vector2(2, 0), cor, 1.0)
			draw_line(centro + Vector2(-2, 1), centro + Vector2(-1, 0), cor, 1.0)
		_:
			draw_line(centro + Vector2(-1, 0), centro + Vector2(2, 0), cor, 1.0)


# ---------------------------------------------------------------- mecânica

func _mecanica(resp: float) -> void:
	var y := -resp
	# Rabo de cavalo atrás de tudo, balançando de leve
	var balanco := sin(_t * 1.7) * 1.0
	_forma(PackedVector2Array([Vector2(-5, -84 + y), Vector2(-2, -82 + y), Vector2(-6 + balanco, -66 + y),
		Vector2(-9 + balanco, -60 + y), Vector2(-10 + balanco, -68 + y)]), CABELO)

	# Botas
	_forma(PackedVector2Array([Vector2(-9, -5), Vector2(-3, -5), Vector2(-2, 0), Vector2(-10, 0)]), Color(0.13, 0.11, 0.1))
	_forma(PackedVector2Array([Vector2(1, -5), Vector2(7, -5), Vector2(10, 0), Vector2(1, 0)]), Color(0.13, 0.11, 0.1))
	# Pernas do macacão
	_forma(PackedVector2Array([Vector2(-9, -40 + y), Vector2(-1, -40 + y), Vector2(-3, -5), Vector2(-9, -5)]), MACACAO_SOMBRA)
	_forma(PackedVector2Array([Vector2(0, -40 + y), Vector2(8, -40 + y), Vector2(7, -5), Vector2(1, -5)]), MACACAO)
	draw_rect(Rect2(-8, -22, 2, 2), GRAXA)   # manchas de graxa
	draw_rect(Rect2(3, -16, 3, 2), GRAXA)
	draw_line(Vector2(-9, -8), Vector2(-3, -8), MACACAO_SOMBRA.darkened(0.3), 1.0)   # barra dobrada

	# Braço de trás (segura a chave inglesa)
	var ombro_t := Vector2(-9, -63 + y)
	var cotovelo_t := Vector2(-11, -50 + y)
	var mao_t := Vector2(-10, -39 + y)
	_membro(ombro_t, cotovelo_t, 4.0, MACACAO_SOMBRA)
	_membro(cotovelo_t, mao_t, 3.0, PELE_MECANICA)   # manga dobrada: antebraço de fora
	draw_rect(Rect2(cotovelo_t + Vector2(-2, -1), Vector2(5, 2)), MACACAO)
	# Chave inglesa
	_membro(mao_t, mao_t + Vector2(1, 15), 2.0, METAL)
	_forma(PackedVector2Array([mao_t + Vector2(-2, 15), mao_t + Vector2(4, 15), mao_t + Vector2(4, 19),
		mao_t + Vector2(2, 19), mao_t + Vector2(2, 17), mao_t + Vector2(0, 17), mao_t + Vector2(0, 19), mao_t + Vector2(-2, 19)]), METAL)
	draw_rect(Rect2(mao_t + Vector2(-2, -2), Vector2(4, 4)), LUVA)

	# Tronco
	_forma(PackedVector2Array([Vector2(-10, -66 + y), Vector2(10, -66 + y), Vector2(9, -40 + y), Vector2(-9, -40 + y)]), MACACAO)
	draw_rect(Rect2(-10, -66 + y, 4, 26), MACACAO_SOMBRA)   # sombra lateral
	# Gola em V com a camiseta por baixo
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -66 + y), Vector2(3, -66 + y), Vector2(0, -60 + y)]), Color(0.85, 0.84, 0.8))
	draw_line(Vector2(0, -60 + y), Vector2(0, -41 + y), MACACAO_SOMBRA.darkened(0.3), 1.0)   # zíper
	draw_rect(Rect2(3, -60 + y, 5, 4), MACACAO_SOMBRA)   # bolso
	draw_rect(Rect2(4, -59 + y, 3, 1), Config.COR_LARANJA)   # crachá / caneta
	draw_rect(Rect2(-6, -52 + y, 3, 2), GRAXA)
	draw_line(Vector2(-9, -42 + y), Vector2(9, -42 + y), MACACAO_SOMBRA.darkened(0.2), 1.0)   # cintura

	# Braço da frente: mão aberta explicando; "gesto" levanta o braço (comemorando com o polegar)
	var ombro_f := Vector2(9, -63 + y)
	var fala := sin(_t * 6.0) * 1.5 if falando else 0.0
	var cotovelo_f := ombro_f + Vector2(4, 12).lerp(Vector2(5, -2), gesto)
	var mao_f := cotovelo_f + Vector2(7, -2 + fala).lerp(Vector2(3, -11), gesto)
	_membro(ombro_f, cotovelo_f, 4.0, MACACAO)
	_membro(cotovelo_f, mao_f, 3.0, PELE_MECANICA)
	draw_rect(Rect2(cotovelo_f + Vector2(-2, -1), Vector2(5, 2)), MACACAO_SOMBRA)
	draw_rect(Rect2(mao_f + Vector2(-2, -2), Vector2(4, 4)), LUVA)
	if gesto > 0.5:
		draw_rect(Rect2(mao_f + Vector2(-1, -5), Vector2(2, 3)), LUVA)   # polegar para cima

	# Pescoço e cabeça
	draw_rect(Rect2(-2, -70 + y, 4, 5), PELE_MECANICA.darkened(0.15))
	var rosto := PackedVector2Array([Vector2(-5, -84 + y), Vector2(5, -84 + y), Vector2(6, -77 + y),
		Vector2(4, -71 + y), Vector2(0, -69 + y), Vector2(-4, -71 + y), Vector2(-6, -77 + y)])
	_forma(rosto, PELE_MECANICA)
	# Cabelo: topo, franja de lado e mecha atrás da orelha
	_forma(PackedVector2Array([Vector2(-6, -79 + y), Vector2(-6, -86 + y), Vector2(-2, -89 + y),
		Vector2(4, -88 + y), Vector2(7, -84 + y), Vector2(6, -80 + y), Vector2(2, -84 + y), Vector2(-3, -82 + y)]), CABELO)
	draw_rect(Rect2(-6, -80 + y, 2, 6), CABELO)
	draw_rect(Rect2(-4, -77 + y, 1, 2), PELE_MECANICA.darkened(0.25))   # orelha
	var olhos := Vector2(1, -78 + y)
	_olhos(olhos, Color(0.2, 0.13, 0.08))
	_sobrancelhas(olhos, CABELO)
	draw_rect(Rect2(2, -75 + y, 1, 1), PELE_MECANICA.darkened(0.25))   # nariz
	_boca(Vector2(1, -72 + y))
	draw_rect(Rect2(-3, -74 + y, 2, 1), GRAXA)   # graxa na bochecha


# ---------------------------------------------------------------- entregador

func _entregador(resp: float) -> void:
	var y := -resp
	# Bag nas costas (atrás de tudo), na cor do app
	var bag := PackedVector2Array([Vector2(-19, -70 + y), Vector2(-6, -71 + y), Vector2(-5, -40 + y), Vector2(-19, -42 + y)])
	_forma(bag, cor_bag)
	draw_rect(Rect2(-19, -70 + y, 3, 28), cor_bag.darkened(0.3))
	draw_rect(Rect2(-16, -62 + y, 8, 4), cor_bag_detalhe)   # painel com a cor do app
	draw_line(Vector2(-18, -50 + y), Vector2(-6, -50 + y), cor_bag.darkened(0.35), 1.0)   # zíper

	# Tênis
	_forma(PackedVector2Array([Vector2(-8, -4), Vector2(-2, -4), Vector2(0, 0), Vector2(-9, 0)]), Color(0.12, 0.12, 0.13))
	_forma(PackedVector2Array([Vector2(2, -4), Vector2(8, -4), Vector2(11, 0), Vector2(2, 0)]), Color(0.12, 0.12, 0.13))
	draw_line(Vector2(-9, -1), Vector2(0, -1), Color(0.85, 0.85, 0.82), 1.0)   # solado branco
	draw_line(Vector2(2, -1), Vector2(11, -1), Color(0.85, 0.85, 0.82), 1.0)
	# Calça jeans
	_forma(PackedVector2Array([Vector2(-8, -40 + y), Vector2(0, -40 + y), Vector2(-2, -4), Vector2(-8, -4)]), JEANS.darkened(0.2))
	_forma(PackedVector2Array([Vector2(0, -40 + y), Vector2(8, -40 + y), Vector2(8, -4), Vector2(2, -4)]), JEANS)
	draw_line(Vector2(4, -36 + y), Vector2(5, -6), JEANS.lightened(0.15), 1.0)   # costura

	# Jaqueta com capuz
	_forma(PackedVector2Array([Vector2(-11, -68 + y), Vector2(11, -68 + y), Vector2(10, -38 + y), Vector2(-10, -38 + y)]), JAQUETA)
	draw_rect(Rect2(-3, -67 + y, 6, 26), Color(0.82, 0.82, 0.8))   # camiseta (jaqueta aberta)
	draw_line(Vector2(-3, -67 + y), Vector2(-3, -40 + y), JAQUETA_LUZ, 1.0)
	draw_line(Vector2(3, -67 + y), Vector2(3, -40 + y), JAQUETA_LUZ, 1.0)
	draw_rect(Rect2(-9, -68 + y, 6, 3), Color(0.3, 0.3, 0.33))   # capuz
	draw_line(Vector2(-10, -56 + y), Vector2(-4, -57 + y), cor_bag.darkened(0.2), 2.0)   # alça da bag

	# Braço de trás segurando o capacete na cintura
	var ombro_t := Vector2(-9, -65 + y)
	var mao_t := Vector2(-6, -44 + y)
	_membro(ombro_t, Vector2(-11, -52 + y), 4.0, JAQUETA)
	_membro(Vector2(-11, -52 + y), mao_t, 4.0, JAQUETA)
	draw_circle(Vector2(-4, -44 + y), 6.0, CONTORNO)
	draw_circle(Vector2(-4, -44 + y), 5.0, CAPACETE)
	draw_rect(Rect2(-2, -46 + y, 4, 3), Color(0.55, 0.6, 0.62))   # viseira
	draw_rect(Rect2(mao_t + Vector2(-2, -1), Vector2(3, 3)), PELE_ENTREGADOR)

	# Braço da frente: mão aberta, explicando
	var ombro_f := Vector2(9, -65 + y)
	var fala := sin(_t * 6.0) * 1.5 if falando else 0.0
	var cotovelo_f := ombro_f + Vector2(4, 11)
	var mao_f := cotovelo_f + Vector2(8, -3 + fala)
	_membro(ombro_f, cotovelo_f, 4.0, JAQUETA)
	_membro(cotovelo_f, mao_f, 4.0, JAQUETA)
	draw_rect(Rect2(mao_f + Vector2(-1, -2), Vector2(4, 3)), PELE_ENTREGADOR)

	# Cabeça careca com barba curta
	draw_rect(Rect2(-2, -72 + y, 4, 5), PELE_ENTREGADOR.darkened(0.15))
	var rosto := PackedVector2Array([Vector2(-5, -86 + y), Vector2(5, -86 + y), Vector2(6, -79 + y),
		Vector2(5, -73 + y), Vector2(0, -70 + y), Vector2(-5, -73 + y), Vector2(-6, -79 + y)])
	_forma(rosto, PELE_ENTREGADOR)
	draw_rect(Rect2(-4, -86 + y, 8, 1), PELE_ENTREGADOR.lightened(0.15))   # brilho da careca
	var barba := Color(0.12, 0.09, 0.08)
	draw_polyline(PackedVector2Array([Vector2(-5, -76 + y), Vector2(-4, -72 + y), Vector2(0, -70 + y),
		Vector2(4, -72 + y), Vector2(5, -76 + y)]), barba, 1.0)
	draw_rect(Rect2(-1, -74 + y, 4, 1), barba)   # bigode
	draw_rect(Rect2(-4, -79 + y, 1, 2), PELE_ENTREGADOR.darkened(0.25))   # orelha
	var olhos := Vector2(1, -80 + y)
	_olhos(olhos, Color(0.12, 0.08, 0.05))
	_sobrancelhas(olhos, barba)
	_boca(Vector2(1, -72 + y))
