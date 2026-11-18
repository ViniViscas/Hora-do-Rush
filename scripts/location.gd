extends Node2D
## Um ponto da cidade: restaurante (coleta), casa (entrega) ou posto (gasolina).
## A posição é o centro da base, na altura do chão.

const Config := preload("res://scripts/game_config.gd")

var tipo := "casa"          # "restaurante" | "casa" | "posto"
var nome := ""
var largura := 160.0
var ativo := true
var cor_parede := Color(0.34, 0.31, 0.3)

var destacado := false:
	set(v):
		destacado = v
		queue_redraw()
var rotulo_destaque := ""
var progresso := -1.0:
	set(v):
		progresso = v
		queue_redraw()
var texto_progresso := ""
var cliente_visivel := false:
	set(v):
		cliente_visivel = v
		queue_redraw()

var _t := 0.0


func altura_topo() -> float:
	match tipo:
		"restaurante":
			return 240.0
		"posto":
			return 235.0
	return 210.0


func _process(delta: float) -> void:
	if destacado or progresso >= 0.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	match tipo:
		"restaurante":
			_desenhar_restaurante()
		"casa":
			_desenhar_casa()
		"posto":
			_desenhar_posto()
	_desenhar_indicadores()


func _desenhar_restaurante() -> void:
	var w := largura
	var h := 240.0
	var fonte := ThemeDB.fallback_font
	draw_rect(Rect2(-w / 2, -h, w, h), Color(0.23, 0.2, 0.19))
	# Vitrine com luz quente e porta
	draw_rect(Rect2(-w / 2 + 14, -104, w - 84, 66), Color(0.91, 0.63, 0.24, 0.85))
	draw_rect(Rect2(-w / 2 + 14, -104, w - 84, 66), Config.COR_PRETO, false, 3.0)
	draw_rect(Rect2(w / 2 - 58, -96, 42, 96), Config.COR_PRETO)
	draw_circle(Vector2(w / 2 - 24, -48), 3.0, Config.COR_LARANJA)
	# Toldo listrado
	var faixas := 8
	var fw := (w + 20) / faixas
	for i in faixas:
		var cor := Config.COR_VERMELHO if i % 2 == 0 else Config.COR_LARANJA
		var x := -w / 2 - 10 + i * fw
		draw_rect(Rect2(x, -136, fw, 22), cor)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -114), Vector2(x + fw, -114), Vector2(x + fw / 2, -104)]), cor)
	# Letreiro
	draw_rect(Rect2(-w / 2 + 8, -h + 14, w - 16, 46), Config.COR_PRETO)
	draw_rect(Rect2(-w / 2 + 8, -h + 14, w - 16, 46), Config.COR_LARANJA, false, 2.0)
	draw_string(fonte, Vector2(-w / 2 + 8, -h + 44), nome, HORIZONTAL_ALIGNMENT_CENTER,
		w - 16, 17, Config.COR_LARANJA_CLARO)


func _desenhar_casa() -> void:
	var w := largura
	var h := 150.0
	var fonte := ThemeDB.fallback_font
	draw_rect(Rect2(-w / 2, -h, w, h), cor_parede)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w / 2 - 12, -h), Vector2(w / 2 + 12, -h), Vector2(0, -h - 60)]), Color(0.16, 0.13, 0.13))
	# Janela
	draw_rect(Rect2(-w / 2 + 14, -124, 40, 34), Color(0.75, 0.52, 0.25, 0.7))
	draw_rect(Rect2(-w / 2 + 14, -124, 40, 34), Config.COR_PRETO, false, 3.0)
	# Muro e portão
	draw_rect(Rect2(-w / 2 - 6, -56, w + 12, 56), Color(0.27, 0.25, 0.24))
	draw_rect(Rect2(-28, -72, 56, 72), Color(0.1, 0.1, 0.1))
	for i in 6:
		var x := -24 + i * 9.6
		draw_line(Vector2(x, -70), Vector2(x, 0), Config.COR_CINZA_CLARO, 2.0)
	# Número
	draw_rect(Rect2(w / 2 - 56, -112, 46, 24), Config.COR_LARANJA)
	draw_string(fonte, Vector2(w / 2 - 56, -94), nome, HORIZONTAL_ALIGNMENT_CENTER, 46, 16, Config.COR_PRETO)
	if cliente_visivel:
		_desenhar_cliente(Vector2(40, 0))


func _desenhar_cliente(pos: Vector2) -> void:
	draw_line(pos + Vector2(-5, 0), pos + Vector2(-4, -26), Color(0.2, 0.22, 0.3), 5.0)
	draw_line(pos + Vector2(5, 0), pos + Vector2(4, -26), Color(0.2, 0.22, 0.3), 5.0)
	draw_rect(Rect2(pos + Vector2(-10, -56), Vector2(20, 32)), Color(0.55, 0.55, 0.52))
	draw_circle(pos + Vector2(0, -66), 10.0, Color(0.78, 0.6, 0.45))
	draw_line(pos + Vector2(-10, -50), pos + Vector2(-20, -34), Color(0.55, 0.55, 0.52), 5.0)
	draw_rect(Rect2(pos + Vector2(-26, -40), Vector2(10, 16)), Color(0.1, 0.1, 0.1))  # celular


func _desenhar_posto() -> void:
	var w := largura
	var fonte := ThemeDB.fallback_font
	# Pilares e cobertura
	for x in [-w / 2 + 18, w / 2 - 30]:
		draw_rect(Rect2(x, -160, 12, 160), Config.COR_CINZA)
	draw_rect(Rect2(-w / 2, -186, w, 28), Config.COR_VERMELHO)
	draw_rect(Rect2(-w / 2, -164, w, 6), Config.COR_LARANJA)
	draw_rect(Rect2(-w / 2, -186, w, 28), Config.COR_PRETO, false, 2.0)
	# Bomba
	draw_rect(Rect2(-24, -86, 48, 86), Color(0.2, 0.19, 0.19))
	draw_rect(Rect2(-16, -76, 32, 18), Config.COR_LARANJA_CLARO)
	draw_line(Vector2(24, -60), Vector2(36, -30), Config.COR_PRETO, 3.0)
	draw_line(Vector2(36, -30), Vector2(36, -6), Config.COR_PRETO, 3.0)
	# Placa
	var px := w / 2 + 16
	draw_rect(Rect2(px - 3, -235, 6, 235), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(px - 40, -235, 80, 62), Config.COR_PRETO)
	draw_rect(Rect2(px - 40, -235, 80, 62), Config.COR_VERMELHO, false, 2.0)
	draw_string(fonte, Vector2(px - 40, -214), "POSTO", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Config.COR_LARANJA)
	draw_string(fonte, Vector2(px - 40, -186), "R$ 6,99", HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Config.COR_PAPEL)


func _desenhar_indicadores() -> void:
	var fonte := ThemeDB.fallback_font
	var topo := -altura_topo()
	if progresso >= 0.0:
		var bw := 130.0
		var y := topo - 30.0
		draw_rect(Rect2(-bw / 2 - 2, y - 2, bw + 4, 16), Config.COR_PRETO)
		draw_rect(Rect2(-bw / 2, y, bw * clampf(progresso, 0.0, 1.0), 12), Config.COR_LARANJA)
		draw_string_outline(fonte, Vector2(-150, y - 8), texto_progresso, HORIZONTAL_ALIGNMENT_CENTER,
			300, 18, 6, Config.COR_PRETO)
		draw_string(fonte, Vector2(-150, y - 8), texto_progresso, HORIZONTAL_ALIGNMENT_CENTER,
			300, 18, Config.COR_PAPEL)
	elif destacado:
		var y := topo - 30.0 + sin(_t * 5.0) * 8.0
		var cor := Config.COR_LARANJA_CLARO
		draw_colored_polygon(PackedVector2Array([
			Vector2(-18, y - 22), Vector2(18, y - 22), Vector2(0, y)]), cor)
		draw_string_outline(fonte, Vector2(-100, y - 32), rotulo_destaque, HORIZONTAL_ALIGNMENT_CENTER,
			200, 22, 6, Config.COR_PRETO)
		draw_string(fonte, Vector2(-100, y - 32), rotulo_destaque, HORIZONTAL_ALIGNMENT_CENTER,
			200, 22, cor)
