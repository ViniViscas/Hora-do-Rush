extends Control
## Desenha o código do pedido com números "quebradiços": tremem, piscam e têm rachaduras.
## distorcao vai de 0 (legível) a 1 (bem difícil).

const Config := preload("res://scripts/game_config.gd")

const TAMANHO_FONTE := 64
const ESPACO := 76.0
const INTERVALO_GLITCH := 0.09

var codigo := ""
var distorcao := 0.5

var _rotacoes: Array[float] = []
var _semente := 0
var _t := 0.0


func configurar(c: String, d: float) -> void:
	codigo = c
	distorcao = clampf(d, 0.0, 1.0)
	reembaralhar()


func reembaralhar() -> void:
	_rotacoes.clear()
	for i in codigo.length():
		_rotacoes.append(randf_range(-0.45, 0.45) * distorcao)
	_semente = randi()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _t >= INTERVALO_GLITCH:
		_t = 0.0
		_semente = randi()
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _semente
	var fonte := get_theme_default_font()
	var n := codigo.length()
	var x0 := size.x / 2.0 - ESPACO * (n - 1) / 2.0
	var cy := size.y / 2.0
	var d := distorcao
	for i in n:
		var ch := codigo[i]
		var tremida := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 5.0 * d
		var escala := Vector2(1.0 + rng.randf_range(-0.15, 0.15) * d, 1.0 + rng.randf_range(-0.25, 0.25) * d)
		draw_set_transform(Vector2(x0 + i * ESPACO, cy) + tremida, _rotacoes[i], escala)
		var largura := fonte.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE).x
		var base := Vector2(-largura / 2.0, TAMANHO_FONTE * 0.35)
		# "Fantasma" vermelho deslocado
		if d > 0.3:
			draw_string(fonte, base + Vector2(rng.randf_range(-5, 5) * d, rng.randf_range(-2, 2)), ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE, Color(0.75, 0.16, 0.12, 0.45))
		# Piscada ocasional
		var alfa := 1.0
		if rng.randf() < 0.12 * d:
			alfa = 0.2
		draw_string(fonte, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE,
			Color(0.08, 0.07, 0.07, alfa))
		# Rachaduras: faixas da cor do papel cortando o número
		var faixas := int(round(4.0 * d))
		for k in faixas:
			var y := rng.randf_range(-TAMANHO_FONTE * 0.42, TAMANHO_FONTE * 0.25)
			var altura := rng.randf_range(1.5, 2.0 + 4.0 * d)
			draw_rect(Rect2(-largura * 0.8, y, largura * 1.6, altura), Config.COR_PAPEL)
		if d > 0.5 and rng.randf() < 0.5:
			var a := Vector2(rng.randf_range(-largura, 0), rng.randf_range(-30, 0))
			var b := Vector2(rng.randf_range(0, largura), rng.randf_range(0, 20))
			draw_line(a, b, Config.COR_PAPEL, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
