extends CharacterBody2D
## A moto do entregador: aceleração, freio, pulo, equilíbrio no ar e queda.
##
## Quando a moto é lançada por um obstáculo (lombada, boca de lobo), ela fica "instável":
## no ar, A/D (ou < >) giram a moto em vez de acelerar. Pousar muito torta = queda.

signal pousou(diferenca: float, tempo_ar: float, caiu: bool)

const Config := preload("res://scripts/game_config.gd")

const GRAVIDADE := 1800.0
const GRAVIDADE_VOO := 1350.0   # lançada por obstáculo, a moto "flutua" mais
const TORQUE_AR := 15.0         # rad/s² aplicados com A/D quando instável
const TURBULENCIA := 3.0        # rad/s² de balanço no ar (muda a cada voo)
const GIRO_MAX := 9.0           # rad/s

var vel_max := 520.0
var aceleracao := 650.0
var forca_freio := 1500.0
var desaceleracao_livre := 220.0
var impulso_pulo := -720.0
var limite_queda := 0.8     # ~45°: pousar mais torto que isso derruba (o amortecedor aumenta)

## Multiplicadores ajustados pelos obstáculos (terra, ciclovia, chuva)
var mult_vel := 1.0
var mult_acel := 1.0
var mult_freio := 1.0

var controles_ativos := false
var direcao := 1            # 1 = direita, -1 = esquerda (para onde a moto aponta)
var acelerando := 0.0       # 0..1, usado no consumo de gasolina
var cor_bag := Config.COR_LARANJA
var cor_bag_detalhe := Config.COR_PAPEL
var painel_bag := Rect2()   # faixa/painel com a cor do app (vazio = sem detalhe)

var instavel := false       # lançada por obstáculo, precisa equilibrar
var caido := false
var angulo := 0.0           # inclinação atual da moto (rad)
var vel_ang := 0.0

var _tempo_ar := 0.0
var _estava_no_ar := false
var _caido_t := 0.0
var _bloqueio_t := 0.0
var _lado_queda := 1.0
var _giro_roda := 0.0
var _buffer_pulo := 0.0
var _coyote := 0.0
var _fase_turb := 0.0
var _freq_turb := 6.0


func _ready() -> void:
	floor_snap_length = 14.0
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	var forma := CollisionShape2D.new()
	var capsula := CapsuleShape2D.new()
	capsula.radius = 20.0
	capsula.height = 84.0
	forma.shape = capsula
	forma.rotation = PI / 2.0
	forma.position = Vector2(0, -20)
	add_child(forma)


## Joga a moto para cima e a deixa instável (precisa equilibrar no ar).
func lancar(vel_y: float, giro: float) -> void:
	if caido:
		return
	velocity.y = vel_y
	instavel = true
	vel_ang = giro
	_tempo_ar = 0.0
	_fase_turb = randf() * TAU
	_freq_turb = randf_range(4.5, 8.0)


## Derruba a moto por um tempo. empurrao_x != 0 joga a moto para trás.
func derrubar(tempo: float, empurrao_x: float = 0.0) -> void:
	caido = true
	instavel = false
	vel_ang = 0.0
	_caido_t = tempo
	_lado_queda = -1.0 if angulo < 0.0 else 1.0
	if empurrao_x != 0.0:
		velocity.x = empurrao_x
		velocity.y = -260.0


## Obriga a moto a ficar parada (blitz, multa) por um tempo.
func segurar(tempo: float) -> void:
	_bloqueio_t = maxf(_bloqueio_t, tempo)


func bloqueada() -> bool:
	return _bloqueio_t > 0.0


func parar() -> void:
	velocity = Vector2(0.0, velocity.y)
	acelerando = 0.0


func _physics_process(delta: float) -> void:
	var no_chao := is_on_floor()
	if not no_chao:
		velocity.y += (GRAVIDADE_VOO if instavel else GRAVIDADE) * delta
	_caido_t = maxf(_caido_t - delta, 0.0)
	_bloqueio_t = maxf(_bloqueio_t - delta, 0.0)
	if caido and _caido_t <= 0.0:
		caido = false

	var pode_pilotar := controles_ativos and not caido and _bloqueio_t <= 0.0
	var eixo := 0.0
	var freando := _bloqueio_t > 0.0
	if pode_pilotar:
		eixo = Input.get_axis("esquerda", "direita")
		freando = Input.is_action_pressed("freio")
		if Input.is_action_just_pressed("pulo"):
			_buffer_pulo = 0.12
	_buffer_pulo = maxf(_buffer_pulo - delta, 0.0)
	_coyote = 0.1 if no_chao else maxf(_coyote - delta, 0.0)

	var limite := vel_max * mult_vel
	var vx := velocity.x
	acelerando = 0.0
	if caido:
		if no_chao:
			vx = move_toward(vx, 0.0, 900.0 * delta)
	elif instavel and not no_chao:
		# No ar e instável: A/D giram a moto para equilibrar. Segurar direto passa do ponto.
		vel_ang += eixo * TORQUE_AR * delta
		vel_ang += sin(_tempo_ar * _freq_turb + _fase_turb) * TURBULENCIA * delta
		vel_ang = clampf(vel_ang, -GIRO_MAX, GIRO_MAX)
	elif freando:
		if no_chao:
			vx = move_toward(vx, 0.0, forca_freio * mult_freio * delta)
	elif eixo != 0.0:
		var fator_ar := 1.0 if no_chao else 0.45
		if absf(vx) > 20.0 and signf(eixo) != signf(vx):
			# Apertar para o lado contrário também freia.
			vx = move_toward(vx, 0.0, forca_freio * mult_freio * 0.8 * delta * fator_ar)
		else:
			vx = move_toward(vx, eixo * limite, aceleracao * mult_acel * delta * fator_ar)
			acelerando = absf(eixo)
			direcao = 1 if eixo > 0.0 else -1
	elif no_chao:
		vx = move_toward(vx, 0.0, desaceleracao_livre * (0.4 + 0.6 * mult_freio) * delta)
	# Entrou num trecho mais lento (terra) acima do limite: perde velocidade.
	if no_chao and absf(vx) > limite:
		vx = move_toward(vx, signf(vx) * limite, 900.0 * delta)
	velocity.x = vx

	if pode_pilotar and _buffer_pulo > 0.0 and _coyote > 0.0:
		velocity.y = impulso_pulo
		_buffer_pulo = 0.0
		_coyote = 0.0

	move_and_slide()
	_depois_de_mover(delta)


func _depois_de_mover(delta: float) -> void:
	var no_chao := is_on_floor()
	if not no_chao:
		_tempo_ar += delta
		if instavel:
			angulo += vel_ang * delta
		elif not caido:
			var alvo := clampf(velocity.y / 1500.0, -0.35, 0.35) * direcao
			angulo = lerp_angle(angulo, alvo, minf(12.0 * delta, 1.0))
	else:
		var ang_chao := get_floor_normal().angle() + PI / 2.0
		if _estava_no_ar and instavel:
			var diferenca := angle_difference(ang_chao, angulo)
			var caiu := absf(diferenca) > limite_queda
			instavel = false
			vel_ang = 0.0
			if caiu:
				derrubar(1.6)
			pousou.emit(diferenca, _tempo_ar, caiu)
		var alvo_chao := ang_chao + (_lado_queda * 1.35 if caido else 0.0)
		angulo = lerp_angle(angulo, alvo_chao, minf(12.0 * delta, 1.0))
		_tempo_ar = 0.0
	_estava_no_ar = not no_chao
	_giro_roda += velocity.x * delta / 17.0
	queue_redraw()


func _draw() -> void:
	# Caída, a moto gira em volta da base: sobe o desenho para não afundar no chão.
	var deslocamento := Vector2.ZERO
	if caido:
		var mais_baixo := 0.0
		for canto in [Vector2(-44, -100), Vector2(40, -100), Vector2(40, 0), Vector2(-44, 0)]:
			var p: Vector2 = (canto * Vector2(direcao, 1)).rotated(angulo)
			mais_baixo = maxf(mais_baixo, p.y)
		deslocamento.y = -mais_baixo
	draw_set_transform(deslocamento, angulo, Vector2(direcao, 1))
	var preto := Config.COR_PRETO
	var cinza := Config.COR_CINZA
	var cinza_claro := Config.COR_CINZA_CLARO

	# Bag (atrás do piloto)
	draw_rect(Rect2(-44, -98, 32, 38), cor_bag.darkened(0.45))
	draw_rect(Rect2(-42, -96, 28, 34), cor_bag)
	draw_rect(Rect2(-42, -84, 28, 4), cor_bag.darkened(0.3))
	if painel_bag.has_area():
		draw_rect(painel_bag, cor_bag_detalhe)

	# Quadro e carenagem
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, -30), Vector2(-14, -44), Vector2(24, -46),
		Vector2(40, -32), Vector2(30, -24), Vector2(-30, -24)]), Color(0.23, 0.22, 0.22))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -46), Vector2(20, -48), Vector2(26, -38), Vector2(0, -36)]), Config.COR_VERMELHO)
	# Banco
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32, -44), Vector2(-4, -48), Vector2(-2, -42), Vector2(-30, -39)]), preto)
	# Garfo e guidão
	draw_line(Vector2(34, -17), Vector2(22, -54), cinza_claro, 4.0)
	draw_line(Vector2(16, -58), Vector2(28, -55), preto, 4.0)
	# Farol
	draw_circle(Vector2(37, -40), 4.0, Color(1.0, 0.85, 0.5))
	# Escapamento
	draw_line(Vector2(-36, -22), Vector2(-6, -24), cinza_claro, 3.0)

	# Rodas
	for centro in [Vector2(-32, -17), Vector2(34, -17)]:
		draw_circle(centro, 17.0, preto)
		draw_circle(centro, 9.0, cinza)
		for i in 3:
			var ang := _giro_roda + i * TAU / 3.0
			draw_line(centro, centro + Vector2(cos(ang), sin(ang)) * 9.0, preto, 2.0)

	# Piloto
	draw_line(Vector2(-14, -46), Vector2(4, -30), Color(0.15, 0.15, 0.17), 7.0)   # perna
	draw_line(Vector2(4, -30), Vector2(10, -22), preto, 6.0)                       # bota
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -48), Vector2(-6, -50), Vector2(6, -80), Vector2(-10, -84)]), Color(0.2, 0.19, 0.19))
	draw_line(Vector2(-14, -66), Vector2(2, -76), Config.COR_LARANJA, 3.0)        # faixa refletiva
	draw_line(Vector2(0, -74), Vector2(20, -57), Color(0.2, 0.19, 0.19), 6.0)      # braço
	draw_circle(Vector2(4, -92), 12.0, preto)                                      # capacete
	draw_rect(Rect2(6, -96, 10, 6), Config.COR_LARANJA_CLARO)                      # viseira

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
