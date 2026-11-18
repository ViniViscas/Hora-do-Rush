extends RefCounted
## Funções utilitárias para montar a interface por código com o visual do jogo.

const Config := preload("res://scripts/game_config.gd")


static func label(texto: String, tamanho: int, cor: Color = Config.COR_PAPEL, contorno: int = 6) -> Label:
	var l := Label.new()
	l.text = texto
	var ls := LabelSettings.new()
	ls.font_size = tamanho
	ls.font_color = cor
	ls.outline_size = contorno
	ls.outline_color = Config.COR_PRETO
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func estilo(cor: Color, borda: Color = Config.COR_PRETO, raio: int = 4, largura_borda: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(largura_borda)
	s.set_corner_radius_all(raio)
	s.set_content_margin_all(10)
	return s


static func botao(texto: String, cor: Color, cor_texto: Color = Config.COR_PRETO, tamanho_fonte: int = 24) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", estilo(cor))
	b.add_theme_stylebox_override("hover", estilo(cor.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", estilo(cor.darkened(0.2), Config.COR_LARANJA_CLARO))
	b.add_theme_color_override("font_color", cor_texto)
	b.add_theme_color_override("font_hover_color", cor_texto)
	b.add_theme_color_override("font_pressed_color", cor_texto)
	b.add_theme_font_size_override("font_size", tamanho_fonte)
	return b


static func tela_cheia(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c
