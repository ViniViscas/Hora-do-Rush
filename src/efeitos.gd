extends Node2D
## Efeitos de feedback no mundo: poeira, faíscas, confete e textos flutuantes ("+100").
## Uma instância fica na cena principal, por cima da moto. Cada efeito se apaga sozinho.

const Config := preload("res://src/game_config.gd")
const UI := preload("res://src/ui_util.gd")


func _ready() -> void:
	z_index = 20


## Nuvem de poeira (pouso, freada na terra). forca 0..1 muda o tamanho.
func poeira(pos: Vector2, forca: float = 0.5) -> void:
	_rajada(pos, int(8 + 18 * forca), Color(0.55, 0.5, 0.42, 0.75), Vector2.UP, 80.0,
		Vector2(40, 90 + 120 * forca), 0.45 + 0.3 * forca, Vector2(4, 10), 120.0)


## Faíscas de metal raspando no asfalto (queda).
func faiscas(pos: Vector2) -> void:
	_rajada(pos, 22, Config.COR_LARANJA_CLARO, Vector2.UP, 70.0, Vector2(160, 360), 0.45, Vector2(2, 4), 900.0)
	_rajada(pos, 10, Color(1.0, 0.92, 0.6), Vector2.UP, 50.0, Vector2(200, 300), 0.3, Vector2(1.5, 3), 900.0)


## Confete/brilho de comemoração (entrega, pouso perfeito).
func confete(pos: Vector2, cores: Array = [Config.COR_LARANJA, Config.COR_AMARELO, Config.COR_PAPEL]) -> void:
	for cor in cores:
		_rajada(pos, 10, cor, Vector2.UP, 75.0, Vector2(140, 300), 0.9, Vector2(3, 6), 520.0)


## Texto que sobe e some (pontos, segundos ganhos).
func texto(pos: Vector2, conteudo: String, cor: Color, tamanho: int = 24) -> void:
	var l := UI.label(conteudo, tamanho, cor, 6)
	l.position = pos - Vector2(100, 0)
	l.size = Vector2(200, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 70.0, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.65)
	tw.chain().tween_callback(l.queue_free)


## Uma explosão única de partículas que se apaga depois de "vida" segundos.
func _rajada(pos: Vector2, qtd: int, cor: Color, direcao: Vector2, abertura: float, vel: Vector2,
		vida: float, tamanho: Vector2, gravidade: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = maxi(qtd, 1)
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = vida
	p.direction = direcao
	p.spread = abertura
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.gravity = Vector2(0, gravidade)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = tamanho.x
	p.scale_amount_max = tamanho.y
	var rampa := Gradient.new()
	rampa.set_color(0, cor)
	rampa.set_color(1, Color(cor, 0.0))
	p.color_ramp = rampa
	p.emitting = true
	add_child(p)
	get_tree().create_timer(vida + 0.3, false).timeout.connect(p.queue_free)
