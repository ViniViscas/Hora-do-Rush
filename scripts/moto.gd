extends CharacterBody2D
## A moto do entregador: aceleração, freio, pulo e o desenho (sem sprites por enquanto).

const Config := preload("res://scripts/game_config.gd")

const GRAVIDADE := 1800.0

var vel_max := 520.0
var aceleracao := 650.0
var forca_freio := 1500.0
var desaceleracao_livre := 220.0
var impulso_pulo := -720.0

var controles_ativos := false
var direcao := 1            # 1 = direita, -1 = esquerda (para onde a moto aponta)
var acelerando := 0.0       # 0..1, usado no consumo de gasolina
var cor_bag := Config.COR_LARANJA

var _giro_roda := 0.0
var _inclinacao := 0.0
var _buffer_pulo := 0.0
var _coyote := 0.0


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


func _physics_process(delta: float) -> void:
	var eixo := 0.0
	var freando := false
	if controles_ativos:
		eixo = Input.get_axis("esquerda", "direita")
		freando = Input.is_action_pressed("freio")
		if Input.is_action_just_pressed("pulo"):
			_buffer_pulo = 0.12
	_buffer_pulo = maxf(_buffer_pulo - delta, 0.0)

	var no_chao := is_on_floor()
	if no_chao:
		_coyote = 0.1
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y += GRAVIDADE * delta

	var fator_ar := 1.0 if no_chao else 0.45
	var vx := velocity.x
	acelerando = 0.0
	if freando:
		if no_chao:
			vx = move_toward(vx, 0.0, forca_freio * delta)
	elif eixo != 0.0:
		if absf(vx) > 20.0 and signf(eixo) != signf(vx):
			# Apertar para o lado contrário também freia.
			vx = move_toward(vx, 0.0, forca_freio * 0.8 * delta * fator_ar)
		else:
			vx = move_toward(vx, eixo * vel_max, aceleracao * delta * fator_ar)
			acelerando = absf(eixo)
			direcao = 1 if eixo > 0.0 else -1
	elif no_chao:
		vx = move_toward(vx, 0.0, desaceleracao_livre * delta)
	velocity.x = vx

	if _buffer_pulo > 0.0 and _coyote > 0.0:
		velocity.y = impulso_pulo
		_buffer_pulo = 0.0
		_coyote = 0.0

	move_and_slide()
	_atualizar_visual(delta)


func parar() -> void:
	velocity = Vector2(0.0, velocity.y)
	acelerando = 0.0


func _atualizar_visual(delta: float) -> void:
	var alvo := 0.0
	if is_on_floor():
		alvo = get_floor_normal().angle() + PI / 2.0
	else:
		alvo = clampf(velocity.y / 1500.0, -0.35, 0.35) * direcao
	_inclinacao = lerp_angle(_inclinacao, alvo, minf(12.0 * delta, 1.0))
	_giro_roda += velocity.x * delta / 17.0
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _inclinacao, Vector2(direcao, 1))
	var preto := Config.COR_PRETO
	var cinza := Config.COR_CINZA
	var cinza_claro := Config.COR_CINZA_CLARO

	# Bag (atrás do piloto)
	draw_rect(Rect2(-44, -98, 32, 38), cor_bag.darkened(0.45))
	draw_rect(Rect2(-42, -96, 28, 34), cor_bag)
	draw_rect(Rect2(-42, -84, 28, 4), cor_bag.darkened(0.3))

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
