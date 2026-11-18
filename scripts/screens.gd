extends CanvasLayer
## Telas sobrepostas: menu inicial (escolha da bag) e fim de fase (vitória / game over).

signal iniciar(dificuldade: String)
signal jogar_de_novo
signal voltar_menu

const Config := preload("res://scripts/game_config.gd")
const UI := preload("res://scripts/ui_util.gd")

var _atual: Control


func _ready() -> void:
	layer = 20


func limpar() -> void:
	if _atual:
		_atual.queue_free()
		_atual = null


func _base(opacidade: float) -> VBoxContainer:
	limpar()
	_atual = UI.tela_cheia(Control.new())
	add_child(_atual)
	var fundo: ColorRect = UI.tela_cheia(ColorRect.new())
	fundo.color = Color(0.05, 0.04, 0.04, opacidade)
	_atual.add_child(fundo)
	var centro: CenterContainer = UI.tela_cheia(CenterContainer.new())
	_atual.add_child(centro)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 18)
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(caixa)
	return caixa


func mostrar_menu() -> void:
	var caixa := _base(0.72)
	var titulo := UI.label("HORA DO RUSH", 88, Config.COR_LARANJA, 14)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(titulo)
	var sub := UI.label("Colete, entregue e não deixe a gasolina acabar.", 24, Config.COR_CINZA_CLARO)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(sub)

	var escolha := UI.label("ESCOLHA SUA BAG", 26, Config.COR_PAPEL)
	escolha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(escolha)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 20)
	caixa.add_child(linha)
	for id in ["facil", "medio", "dificil"]:
		var d: Dictionary = Config.DIFICULDADES[id]
		var b: Button = UI.botao("%s\n%s" % [d.nome, d.rotulo], d.cor, d.cor_texto, 24)
		b.custom_minimum_size = Vector2(230, 110)
		b.add_theme_stylebox_override("normal", UI.estilo(d.cor, d.cor_detalhe))
		b.pressed.connect(func() -> void: iniciar.emit(id))
		linha.add_child(b)

	var ajuda := UI.label("PC: A/D ou setas = pilotar   S/Shift = freio   Espaço/W = pulo   Números = código\n"
		+ "Celular: botões na tela", 18, Config.COR_CINZA_CLARO, 4)
	ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(ajuda)


func mostrar_fim(vitoria: bool, titulo: String, mensagem: String, estatisticas: String) -> void:
	var caixa := _base(0.8)
	var t := UI.label(titulo, 64, Config.COR_LARANJA if vitoria else Config.COR_VERMELHO, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(t)
	var m := UI.label(mensagem, 26, Config.COR_PAPEL)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(760, 0)
	caixa.add_child(m)
	var e := UI.label(estatisticas, 22, Config.COR_CINZA_CLARO, 4)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(e)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 20)
	caixa.add_child(linha)
	var b1: Button = UI.botao("JOGAR DE NOVO", Config.COR_LARANJA)
	b1.custom_minimum_size = Vector2(240, 64)
	b1.pressed.connect(func() -> void: jogar_de_novo.emit())
	linha.add_child(b1)
	var b2: Button = UI.botao("MENU", Config.COR_CINZA, Config.COR_PAPEL)
	b2.custom_minimum_size = Vector2(160, 64)
	b2.pressed.connect(func() -> void: voltar_menu.emit())
	linha.add_child(b2)
