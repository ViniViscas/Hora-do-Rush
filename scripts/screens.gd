extends CanvasLayer
## Telas sobrepostas: menu inicial (escolha da bag), fases da campanha, oficina
## e fim de fase (vitória / game over).

signal escolher_bag(dificuldade: String)
signal jogar_fase(indice: int)
signal abrir_oficina
signal comprar(melhoria: String)
signal voltar_campanha
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
		b.pressed.connect(func() -> void: escolher_bag.emit(id))
		linha.add_child(b)

	var ajuda := UI.label("PC: A/D ou setas = pilotar   S/Shift = freio   Espaço/W = pulo   Números = código\n"
		+ "Celular: botões na tela", 18, Config.COR_CINZA_CLARO, 4)
	ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(ajuda)




func _titulo(caixa: VBoxContainer, texto: String, tamanho: int, cor: Color) -> void:
	var t := UI.label(texto, tamanho, cor, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(t)


func _linha_botoes(caixa: VBoxContainer) -> HBoxContainer:
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 20)
	caixa.add_child(linha)
	return linha


func _botao(linha: HBoxContainer, texto: String, cor: Color, cor_texto: Color, largura: float, acao: Callable) -> Button:
	var b: Button = UI.botao(texto, cor, cor_texto)
	b.custom_minimum_size = Vector2(largura, 60)
	b.pressed.connect(acao)
	linha.add_child(b)
	return b


## Lista das fases da campanha da bag: as liberadas dá para jogar (e rejogar para juntar R$).
func mostrar_campanha(d: Dictionary, p: Dictionary) -> void:
	var caixa := _base(0.8)
	_titulo(caixa, "%s (%s)" % [d.nome, d.rotulo], 48, d.cor)
	_titulo(caixa, "Saldo: R$ %d" % p.dinheiro, 26, Config.COR_PAPEL)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 8)
	caixa.add_child(lista)
	for i in Config.FASES.size():
		var f: Dictionary = Config.FASES[i]
		var liberada: bool = i <= p.liberada
		var texto := "FASE %d  ·  %s  ·  %d entregas" % [i + 1, f.nome, f.entregas]
		if not liberada:
			texto += "\nVença a fase anterior para liberar"
		elif p.recordes[i] > 0:
			texto += "\n%s   Recorde: %d pts" % [f.descricao, p.recordes[i]]
		else:
			texto += "\n" + f.descricao
		var cor: Color = Config.COR_LARANJA if liberada else Config.COR_CINZA_ESCURO
		var b: Button = UI.botao(texto, cor, Config.COR_PRETO if liberada else Config.COR_CINZA_CLARO, 19)
		b.custom_minimum_size = Vector2(760, 66)
		b.disabled = not liberada
		b.add_theme_stylebox_override("disabled", UI.estilo(cor))
		b.add_theme_color_override("font_disabled_color", Config.COR_CINZA_CLARO)
		b.pressed.connect(func() -> void: jogar_fase.emit(i))
		lista.add_child(b)

	var linha := _linha_botoes(caixa)
	_botao(linha, "OFICINA", Config.COR_AMARELO, Config.COR_PRETO, 220, func() -> void: abrir_oficina.emit())
	_botao(linha, "TROCAR BAG", Config.COR_CINZA, Config.COR_PAPEL, 220, func() -> void: voltar_menu.emit())


## Oficina: compra das melhorias da moto com o dinheiro das fases.
func mostrar_oficina(d: Dictionary, p: Dictionary) -> void:
	var caixa := _base(0.85)
	_titulo(caixa, "OFICINA", 56, Config.COR_LARANJA)
	_titulo(caixa, "Saldo: R$ %d     (bag %s)" % [p.dinheiro, d.nome], 26, Config.COR_PAPEL)

	var grade := GridContainer.new()
	grade.columns = 4
	grade.add_theme_constant_override("h_separation", 18)
	grade.add_theme_constant_override("v_separation", 10)
	caixa.add_child(grade)
	var maximo := Config.PRECOS_MELHORIA.size()
	for id in Config.MELHORIAS:
		var m: Dictionary = Config.MELHORIAS[id]
		var nivel: int = p.niveis[id]
		var nome := UI.label(m.nome, 26, Config.COR_LARANJA_CLARO)
		nome.custom_minimum_size = Vector2(190, 0)
		grade.add_child(nome)
		var desc := UI.label(m.descricao, 18, Config.COR_CINZA_CLARO, 4)
		desc.custom_minimum_size = Vector2(500, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grade.add_child(desc)
		grade.add_child(UI.label("Nível %d/%d" % [nivel, maximo], 22, Config.COR_PAPEL))
		var custo: int = Config.PRECOS_MELHORIA[nivel] if nivel < maximo else -1
		var b: Button
		if custo < 0:
			b = UI.botao("MÁXIMO", Config.COR_CINZA, Config.COR_PAPEL, 20)
			b.disabled = true
		else:
			var da: bool = p.dinheiro >= custo
			b = UI.botao("R$ %d" % custo, Config.COR_AMARELO if da else Config.COR_CINZA_ESCURO,
				Config.COR_PRETO if da else Config.COR_CINZA_CLARO, 22)
			b.disabled = not da
			b.pressed.connect(func() -> void: comprar.emit(id))
		b.add_theme_stylebox_override("disabled", UI.estilo(Config.COR_CINZA_ESCURO))
		b.add_theme_color_override("font_disabled_color", Config.COR_CINZA_CLARO)
		b.custom_minimum_size = Vector2(150, 54)
		grade.add_child(b)

	var linha := _linha_botoes(caixa)
	_botao(linha, "VOLTAR ÀS FASES", Config.COR_LARANJA, Config.COR_PRETO, 280, func() -> void: voltar_campanha.emit())


func mostrar_fim(vitoria: bool, titulo: String, mensagem: String, estatisticas: String, indice_fase: int) -> void:
	var caixa := _base(0.8)
	_titulo(caixa, titulo, 64, Config.COR_LARANJA if vitoria else Config.COR_VERMELHO)
	var m := UI.label(mensagem, 26, Config.COR_PAPEL)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(760, 0)
	caixa.add_child(m)
	var e := UI.label(estatisticas, 22, Config.COR_CINZA_CLARO, 4)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(e)

	var linha := _linha_botoes(caixa)
	var tem_proxima := indice_fase + 1 < Config.FASES.size()
	if vitoria and tem_proxima:
		_botao(linha, "PRÓXIMA FASE", Config.COR_LARANJA, Config.COR_PRETO, 250,
			func() -> void: jogar_fase.emit(indice_fase + 1))
	else:
		_botao(linha, "JOGAR DE NOVO" if vitoria else "TENTAR DE NOVO", Config.COR_LARANJA, Config.COR_PRETO, 250,
			func() -> void: jogar_fase.emit(indice_fase))
	_botao(linha, "OFICINA", Config.COR_AMARELO, Config.COR_PRETO, 180, func() -> void: abrir_oficina.emit())
	_botao(linha, "FASES", Config.COR_CINZA, Config.COR_PAPEL, 160, func() -> void: voltar_campanha.emit())
