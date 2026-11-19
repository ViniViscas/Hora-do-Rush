extends CharacterBody2D
## A moto do entregador: aceleração, freio, pulo, equilíbrio no ar e queda.
##
## Quando a moto é lançada por um obstáculo (lombada, boca de lobo), ela fica "instável":
## no ar, A/D (ou < >) giram a moto em vez de acelerar. Pousar muito torta = queda.

signal pousou(diferenca: float, tempo_ar: float, caiu: bool)
signal aterrissou(forca: float)   # qualquer pouso depois de um tempo no ar (0..1)
signal derrubada                  # a moto foi ao chão (queda, carro do cruzamento)

const Config := preload("res://src/game_config.gd")
const Som := preload("res://src/som.gd")

const GRAVIDADE := 1800.0
const GRAVIDADE_VOO := 1350.0   # lançada por obstáculo, a moto "flutua" mais
const TORQUE_AR := 15.0         # rad/s² aplicados com A/D quando instável
const TURBULENCIA := 3.0        # rad/s² de balanço no ar (muda a cada voo)
const GIRO_MAX := 9.0           # rad/s

## Cores do desenho (moto "CG" verde, como a da oficina)
const COR_MOTO := Color(0.27, 0.37, 0.22)
const CROMADO := Color(0.74, 0.75, 0.77)
const JAQUETA := Color(0.16, 0.16, 0.18)
const JEANS := Color(0.18, 0.22, 0.32)

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

## Animação (só visual, não mexe na física)
var levantar_poeira := false   # ligado por obstaculos.gd na estrada de terra
var _inclinar := 0.0           # tronco do piloto: + para a frente (acelerando), - para trás (freando)
var _mergulho := 0.0           # moto afundando a frente na freada (+) ou levantando na arrancada (-)
var _freando_vis := false
var _t_vis := 0.0
var _fumaca: CPUParticles2D
var _poeira: CPUParticles2D


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
	_fumaca = _particulas(Color(0.8, 0.78, 0.74, 0.5), 26, 1.0, Vector2(-40, 70), Vector2(0, -40), 4.5)
	_poeira = _particulas(Color(0.5, 0.42, 0.3, 0.6), 30, 0.6, Vector2(60, 140), Vector2(0, 160), 5.0)


## Emissor contínuo (fumaça do escapamento, poeira da roda). As partículas ficam no mundo.
func _particulas(cor: Color, qtd: int, vida: float, vel: Vector2, gravidade: Vector2, tamanho: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = qtd
	p.lifetime = vida
	p.local_coords = false
	p.emitting = false
	p.spread = 18.0
	p.initial_velocity_min = absf(vel.x)
	p.initial_velocity_max = absf(vel.y)
	p.gravity = gravidade
	p.scale_amount_min = tamanho
	p.scale_amount_max = tamanho * 1.6
	var crescer := Curve.new()
	crescer.add_point(Vector2(0, 0.5))
	crescer.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = crescer
	var rampa := Gradient.new()
	rampa.set_color(0, cor)
	rampa.set_color(1, Color(cor, 0.0))
	p.color_ramp = rampa
	add_child(p)
	return p


## Joga a moto para cima e a deixa instável (precisa equilibrar no ar).
func lancar(vel_y: float, giro: float) -> void:
	if caido:
		return
	velocity.y = vel_y
	Som.tocar("tranco")
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
	derrubada.emit()
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
	_freando_vis = freando and no_chao and absf(vx) > 90.0

	if pode_pilotar and _buffer_pulo > 0.0 and _coyote > 0.0:
		velocity.y = impulso_pulo
		Som.tocar("pulo")
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
				Som.tocar("queda")
			else:
				Som.tocar("pouso")
			pousou.emit(diferenca, _tempo_ar, caiu)
		elif _estava_no_ar and _tempo_ar > 0.25 and not caido:
			Som.tocar("pouso", -7.0, 1.15)
		if _estava_no_ar and _tempo_ar > 0.25:
			aterrissou.emit(clampf(_tempo_ar / 1.2, 0.0, 1.0))
		var alvo_chao := ang_chao + (_lado_queda * 1.35 if caido else 0.0)
		angulo = lerp_angle(angulo, alvo_chao, minf(12.0 * delta, 1.0))
		_tempo_ar = 0.0
	_estava_no_ar = not no_chao
	_giro_roda += velocity.x * delta / 17.0
	_animar(delta, no_chao)
	queue_redraw()


## Inclinação do piloto, mergulho da freada, fumaça, poeira e o pisca-pisca de quando cai.
func _animar(delta: float, no_chao: bool) -> void:
	_t_vis += delta
	var alvo_incl := 0.0
	var alvo_merg := 0.0
	if caido:
		pass
	elif instavel and not no_chao:
		alvo_incl = clampf(-vel_ang * 0.05, -0.3, 0.3)   # braços tentando segurar o equilíbrio
	elif _freando_vis:
		alvo_incl = -0.14
		alvo_merg = 0.07
	elif acelerando > 0.0 and no_chao:
		alvo_incl = 0.16
		if absf(velocity.x) < 220.0:
			alvo_merg = -0.05   # empinadinha na arrancada
	_inclinar = lerpf(_inclinar, alvo_incl, minf(10.0 * delta, 1.0))
	_mergulho = lerpf(_mergulho, alvo_merg, minf(8.0 * delta, 1.0))

	var vx := absf(velocity.x)
	_fumaca.position = Vector2(-40.0 * direcao, -22.0).rotated(angulo)
	_fumaca.direction = Vector2(-direcao, -0.5)
	_fumaca.emitting = controles_ativos and not caido and (acelerando > 0.0 or vx < 30.0)
	_poeira.position = Vector2(-32.0 * direcao, 0.0)
	_poeira.direction = Vector2(-signf(velocity.x) if vx > 1.0 else -direcao, -1.2)
	_poeira.emitting = levantar_poeira and no_chao and vx > 120.0
	modulate.a = (0.35 if int(_t_vis * 14.0) % 2 == 0 else 1.0) if caido else 1.0


func _draw() -> void:
	# Caída, a moto gira em volta da base: sobe o desenho para não afundar no chão.
	var deslocamento := Vector2.ZERO
	if caido:
		var mais_baixo := 0.0
		for canto in [Vector2(-44, -100), Vector2(40, -100), Vector2(40, 0), Vector2(-44, 0)]:
			var p: Vector2 = (canto * Vector2(direcao, 1)).rotated(angulo)
			mais_baixo = maxf(mais_baixo, p.y)
		deslocamento.y = -mais_baixo
	var base := Transform2D(angulo + _mergulho * direcao, Vector2(direcao, 1), 0.0, deslocamento)
	draw_set_transform_matrix(base)
	var preto := Config.COR_PRETO
	var cinza := Config.COR_CINZA
	var cinza_claro := Config.COR_CINZA_CLARO

	# Bag no bagageiro, atrás do piloto
	draw_rect(Rect2(-46, -98, 36, 40), Config.COR_PRETO)
	draw_rect(Rect2(-44, -96, 32, 36), cor_bag)
	draw_rect(Rect2(-44, -96, 32, 4), cor_bag.lightened(0.18))      # tampa
	draw_rect(Rect2(-44, -84, 32, 2), cor_bag.darkened(0.3))        # zíper
	draw_rect(Rect2(-44, -64, 32, 4), cor_bag.darkened(0.35))       # base
	if painel_bag.has_area():
		draw_rect(painel_bag, cor_bag_detalhe)
	draw_line(Vector2(-12, -90), Vector2(-6, -76), Color(0.12, 0.12, 0.12), 2.0)   # alça

	# Rodas raiadas (aro cromado, raios girando), disco de freio na dianteira
	for centro in [Vector2(-32, -17), Vector2(34, -17)]:
		draw_circle(centro, 17.0, preto)
		draw_arc(centro, 15.5, 0.0, TAU, 24, Color(0.2, 0.2, 0.2), 1.5)
		draw_arc(centro, 12.5, 0.0, TAU, 24, CROMADO, 2.0)
		for i in 10:
			var ang := _giro_roda + i * TAU / 10.0
			draw_line(centro, centro + Vector2(cos(ang), sin(ang)) * 12.0, Color(0.55, 0.56, 0.58), 1.0)
		draw_circle(centro, 3.5, CROMADO)
	draw_circle(Vector2(34, -17), 6.5, Color(0.48, 0.48, 0.5))           # disco
	draw_rect(Rect2(36, -27, 5, 7), Color(0.15, 0.15, 0.16))             # pinça
	draw_circle(Vector2(-32, -17), 6.0, Color(0.38, 0.38, 0.4))          # tambor traseiro
	# Paralama dianteiro
	draw_arc(Vector2(34, -17), 20.0, deg_to_rad(-160), deg_to_rad(-40), 10, COR_MOTO, 3.0)

	# Balança, corrente e amortecedor com mola
	draw_line(Vector2(-6, -24), Vector2(-32, -17), Color(0.13, 0.13, 0.14), 4.0)
	draw_line(Vector2(-8, -20), Vector2(-32, -14), Color(0.35, 0.35, 0.36), 1.0)
	var mola := PackedVector2Array()
	for k in 7:
		var t := k / 6.0
		mola.append(Vector2(lerpf(-30, -24, t) + (2.0 if k % 2 else -2.0), lerpf(-20, -42, t)))
	draw_line(Vector2(-30, -20), Vector2(-24, -42), Color(0.2, 0.2, 0.2), 2.0)
	draw_polyline(mola, Color(0.72, 0.25, 0.15), 1.5)

	# Motor: bloco prateado com aletas no cilindro e tampa redonda
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -34), Vector2(6, -38), Vector2(14, -32),
		Vector2(12, -20), Vector2(-8, -19)]), Color(0.52, 0.53, 0.55))
	for k in 5:
		draw_line(Vector2(3, -35 + k * 3), Vector2(13, -33 + k * 3), Color(0.32, 0.33, 0.35), 1.0)
	draw_circle(Vector2(-3, -24), 5.5, Color(0.7, 0.71, 0.73))
	draw_circle(Vector2(-3, -24), 2.5, Color(0.45, 0.46, 0.48))
	# Escapamento cromado: sai do cabeçote, passa por baixo e sobe até o silencioso
	draw_polyline(PackedVector2Array([Vector2(12, -28), Vector2(14, -18), Vector2(4, -14), Vector2(-18, -16)]), CROMADO, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -20), Vector2(-42, -28), Vector2(-44, -24), Vector2(-20, -14)]), CROMADO)
	draw_line(Vector2(-22, -18), Vector2(-38, -24), Color(0.35, 0.36, 0.38), 2.0)   # protetor de calor
	draw_rect(Rect2(-46, -28, 4, 4), Color(0.15, 0.15, 0.15))                       # ponteira

	# Quadro e garfo cromado
	draw_line(Vector2(19, -50), Vector2(8, -32), Color(0.12, 0.12, 0.13), 4.0)
	draw_line(Vector2(21, -50), Vector2(34, -17), CROMADO, 3.0)
	draw_line(Vector2(18, -50), Vector2(31, -18), Color(0.4, 0.41, 0.43), 2.0)

	# Tampa lateral, tanque verde com faixa e banco
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -42), Vector2(-4, -42), Vector2(-6, -32), Vector2(-16, -34)]),
		COR_MOTO.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -47), Vector2(4, -54), Vector2(17, -53), Vector2(22, -47),
		Vector2(14, -39), Vector2(-4, -40)]), COR_MOTO)
	draw_line(Vector2(2, -52), Vector2(16, -51), COR_MOTO.lightened(0.3), 2.0)        # brilho
	draw_polyline(PackedVector2Array([Vector2(4, -46), Vector2(10, -48), Vector2(14, -45)]), Color(0.9, 0.9, 0.85), 1.5)   # faixa
	draw_colored_polygon(PackedVector2Array([Vector2(-38, -45), Vector2(-6, -49), Vector2(-3, -44), Vector2(-36, -40)]),
		Color(0.08, 0.08, 0.09))
	draw_line(Vector2(-34, -45), Vector2(-8, -48), Color(0.22, 0.22, 0.24), 1.0)
	# Rabeta com lanterna e placa
	draw_colored_polygon(PackedVector2Array([Vector2(-38, -45), Vector2(-48, -43), Vector2(-46, -38), Vector2(-36, -40)]), COR_MOTO)
	draw_rect(Rect2(-49, -44, 3, 3), Color(0.9, 0.15, 0.1))
	draw_rect(Rect2(-47, -37, 6, 5), Color(0.82, 0.82, 0.78))

	# Farol redondo, pisca, painel, guidão e retrovisor
	draw_circle(Vector2(26, -46), 5.5, CROMADO)
	draw_circle(Vector2(27, -46), 3.8, Color(1.0, 0.88, 0.55))
	draw_rect(Rect2(24, -40, 3, 2), Config.COR_LARANJA)
	draw_circle(Vector2(20, -55), 2.5, Color(0.12, 0.12, 0.13))
	draw_line(Vector2(15, -58), Vector2(25, -56), preto, 3.0)
	draw_line(Vector2(19, -58), Vector2(16, -66), Color(0.2, 0.2, 0.22), 1.5)
	draw_rect(Rect2(13, -69, 6, 3), CROMADO)

	# Piloto: perna e tênis presos na moto; tronco gira em volta do quadril (inclinação)
	draw_line(Vector2(-14, -46), Vector2(5, -41), JEANS, 7.0)       # coxa
	draw_line(Vector2(5, -41), Vector2(6, -26), JEANS, 6.0)         # canela
	draw_rect(Rect2(2, -27, 11, 5), Color(0.1, 0.1, 0.11))           # tênis
	draw_line(Vector2(2, -22), Vector2(13, -22), Color(0.85, 0.85, 0.82), 1.5)   # solado
	var quadril := Vector2(-14, -46)
	draw_set_transform_matrix(base * Transform2D(0.0, quadril) * Transform2D(_inclinar, Vector2.ZERO)
		* Transform2D(0.0, -quadril))
	# Jaqueta com capuz e faixa refletiva
	draw_colored_polygon(PackedVector2Array([Vector2(-21, -48), Vector2(-5, -51), Vector2(8, -78),
		Vector2(-2, -86), Vector2(-12, -84)]), JAQUETA)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -84), Vector2(-4, -86), Vector2(-8, -80), Vector2(-14, -80)]),
		Color(0.28, 0.28, 0.3))                                       # capuz
	draw_line(Vector2(-17, -60), Vector2(2, -73), Config.COR_LARANJA, 3.0)
	draw_line(Vector2(-12, -82), Vector2(-17, -60), cor_bag.darkened(0.3), 2.0)   # alça da bag
	# Braço até o guidão, com luva
	draw_line(Vector2(1, -76), Vector2(10, -63), JAQUETA, 6.0)
	draw_line(Vector2(10, -63), Vector2(18, -58), JAQUETA, 5.0)
	draw_circle(Vector2(19, -58), 3.0, Color(0.1, 0.1, 0.11))
	# Capacete fechado com viseira escura e reflexo
	draw_circle(Vector2(3, -92), 12.0, Color(0.12, 0.12, 0.13))
	draw_arc(Vector2(3, -92), 9.5, deg_to_rad(200), deg_to_rad(280), 8, Color(0.35, 0.35, 0.38), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -98), Vector2(15, -95), Vector2(15, -87), Vector2(7, -88)]),
		Color(0.25, 0.32, 0.4))
	draw_line(Vector2(8, -96), Vector2(13, -94), Color(0.7, 0.8, 0.9, 0.8), 1.5)   # reflexo
	draw_rect(Rect2(6, -85, 8, 4), Color(0.12, 0.12, 0.13))                        # queixeira

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
