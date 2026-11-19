extends CanvasLayer
## Telas sobrepostas: tela inicial (nova campanha / carregar), escolha do save,
## menu de capítulos (bag), fases da campanha, oficina, pausa e fim de fase.
## Funciona com o jogo pausado (process_mode ALWAYS); P/ESC pedem a pausa.

signal escolher_bag(dificuldade: String)
signal jogar_fase(indice: int)
signal abrir_oficina
signal comprar(melhoria: String)
signal voltar_campanha
signal voltar_menu
signal pedir_pausa
signal continuar
signal ver_historia
signal abrir_save(slot: int, novo: bool)   # nova campanha (apaga o slot) ou carregar
signal apagar_save(slot: int)
signal voltar_inicio

const Config := preload("res://src/game_config.gd")
const UI := preload("res://src/ui_util.gd")
const TelaOficina := preload("res://src/tela_oficina.gd")
const Cutscene := preload("res://src/cutscene.gd")
const Historia := preload("res://src/historia.gd")
const Progresso := preload("res://src/progresso.gd")

var _atual: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa"):
		get_viewport().set_input_as_handled()
		pedir_pausa.emit()


func limpar() -> void:
	if _atual:
		_atual.queue_free()
		_atual = null


## Tela com fundo escurecido; "imagem" (opcional) aparece por trás do escurecimento.
func _base(opacidade: float, imagem: String = "") -> VBoxContainer:
	limpar()
	_atual = UI.tela_cheia(Control.new())
	add_child(_atual)
	if imagem != "" and ResourceLoader.exists(imagem):
		var foto: TextureRect = UI.tela_cheia(TextureRect.new())
		foto.texture = load(imagem)
		foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_atual.add_child(foto)
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


## Tela inicial: nova campanha ou carregar uma salva.
func mostrar_inicio() -> void:
	var caixa := _base(0.62, Historia.caminho("01_quartinho.jpg"))
	_titulo(caixa, "HORA DO RUSH", 104, Config.COR_LARANJA)
	_titulo(caixa, "A história do Felipe, motoboy de São Paulo.", 24, Config.COR_PAPEL)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	coluna.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caixa.add_child(coluna)
	var novo: Button = UI.botao("NOVA CAMPANHA", Config.COR_LARANJA, Config.COR_PRETO, 28)
	novo.custom_minimum_size = Vector2(420, 72)
	novo.pressed.connect(func() -> void: mostrar_saves(true))
	coluna.add_child(novo)
	var carregar: Button = UI.botao("CARREGAR CAMPANHA", Config.COR_AMARELO, Config.COR_PRETO, 28)
	carregar.custom_minimum_size = Vector2(420, 72)
	carregar.disabled = not Progresso.algum_save()
	carregar.add_theme_stylebox_override("disabled", UI.estilo(Config.COR_CINZA_ESCURO))
	carregar.add_theme_color_override("font_disabled_color", Config.COR_CINZA_CLARO)
	carregar.pressed.connect(func() -> void: mostrar_saves(false))
	coluna.add_child(carregar)
	if carregar.disabled:
		_titulo(caixa, "Nenhuma campanha salva ainda.", 15, Config.COR_CINZA_CLARO)


## Os espaços de save. novo = true: escolher onde começar a campanha (ocupado pede confirmação);
## novo = false: escolher qual carregar (ou apagar).
func mostrar_saves(novo: bool) -> void:
	var caixa := _base(0.8, Historia.caminho("03_oficina_da_tati.jpg"))
	_titulo(caixa, "NOVA CAMPANHA" if novo else "CARREGAR CAMPANHA", 56, Config.COR_LARANJA)
	_titulo(caixa, "Escolha um espaço para a campanha:" if novo else "Escolha a campanha:", 22, Config.COR_PAPEL)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 10)
	caixa.add_child(lista)
	for n in range(1, Progresso.SLOTS + 1):
		var r := Progresso.resumo(n)
		var vazio := r.is_empty()
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 10)
		lista.add_child(linha)
		var cor: Color = Config.COR_CINZA if vazio else Config.COR_LARANJA
		var b: Button = UI.botao("SAVE %d   ·   %s" % [n, _texto_resumo(r)], cor,
			Config.COR_PAPEL if vazio else Config.COR_PRETO, 17)
		b.custom_minimum_size = Vector2(700, 78)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = vazio and not novo
		b.add_theme_stylebox_override("disabled", UI.estilo(Config.COR_CINZA_ESCURO))
		b.add_theme_color_override("font_disabled_color", Config.COR_CINZA_CLARO)
		if novo and not vazio:
			b.pressed.connect(func() -> void: _confirmar(
				"Começar do zero no SAVE %d?" % n,
				"A campanha salva nele (%s) será apagada." % _texto_resumo(r).split("\n")[0],
				"APAGAR E COMEÇAR", func() -> void: abrir_save.emit(n, true),
				func() -> void: mostrar_saves(true)))
		else:
			b.pressed.connect(func() -> void: abrir_save.emit(n, novo))
		linha.add_child(b)
		if not novo and not vazio:
			var x: Button = UI.botao("APAGAR", Config.COR_VERMELHO, Config.COR_PAPEL, 16)
			x.custom_minimum_size = Vector2(130, 78)
			x.pressed.connect(func() -> void: _confirmar(
				"Apagar o SAVE %d?" % n, "Isso não tem volta: fases, dinheiro e melhorias da moto somem.",
				"APAGAR", func() -> void: apagar_save.emit(n),
				func() -> void: mostrar_saves(false)))
			linha.add_child(x)
	var rodape := _linha_botoes(caixa)
	_botao(rodape, "VOLTAR", Config.COR_CINZA_ESCURO, Config.COR_PAPEL, 220, func() -> void: mostrar_inicio())


func _texto_resumo(r: Dictionary) -> String:
	if r.is_empty():
		return "Vazio"
	var onde := "História completa!"
	if r.capitulo != "":
		onde = "%s  ·  Fase %d" % [Historia.CAPITULOS[r.capitulo].titulo, r.fase]
	var texto := "%s\n%d/%d fases  ·  R$ %d" % [onde, r.vencidas, r.total, r.dinheiro]
	if r.data != "":
		texto += "  ·  Salvo em %s" % r.data
	return texto


## Pergunta de confirmação (apagar save). "sim" executa; "nao" volta.
func _confirmar(pergunta: String, detalhe: String, texto_sim: String, sim: Callable, nao: Callable) -> void:
	var caixa := _base(0.85)
	_titulo(caixa, pergunta, 44, Config.COR_LARANJA)
	var d := UI.label(detalhe, 22, Config.COR_PAPEL)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(760, 0)
	caixa.add_child(d)
	var linha := _linha_botoes(caixa)
	_botao(linha, texto_sim, Config.COR_VERMELHO, Config.COR_PAPEL, 300, sim)
	_botao(linha, "CANCELAR", Config.COR_CINZA, Config.COR_PAPEL, 220, nao)


## bloqueadas: bags cujo capítulo ainda não foi liberado (o anterior não foi fechado).
func mostrar_menu(bloqueadas: Array = []) -> void:
	var caixa := _base(0.72)
	var titulo := UI.label("HORA DO RUSH", 88, Config.COR_LARANJA, 14)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(titulo)
	var sub := UI.label("Colete, entregue e não deixe a gasolina acabar.", 24, Config.COR_CINZA_CLARO)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(sub)

	var escolha := UI.label("ESCOLHA O CAPÍTULO", 26, Config.COR_PAPEL)
	escolha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(escolha)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 20)
	caixa.add_child(linha)
	for id in ["facil", "medio", "dificil"]:
		var d: Dictionary = Config.DIFICULDADES[id]
		var bloqueada := bloqueadas.has(id)
		var coluna := VBoxContainer.new()
		coluna.add_theme_constant_override("separation", 8)
		linha.add_child(coluna)
		var b: Button = UI.botao("%s\n%s" % [d.nome, d.rotulo], d.cor, d.cor_texto, 24)
		b.custom_minimum_size = Vector2(250, 110)
		b.add_theme_stylebox_override("normal", UI.estilo(d.cor, d.cor_detalhe))
		b.disabled = bloqueada
		b.add_theme_stylebox_override("disabled", UI.estilo(Config.COR_CINZA_ESCURO))
		b.add_theme_color_override("font_disabled_color", Config.COR_CINZA_CLARO)
		b.pressed.connect(func() -> void: escolher_bag.emit(id))
		coluna.add_child(b)
		var texto: String = Historia.CAPITULOS[id].titulo
		if bloqueada:
			var anterior := Historia.capitulo_anterior(id)
			texto = "FECHE O %s" % Historia.CAPITULOS[anterior].titulo.split(":")[0]
		var cap := UI.label(texto, 13, Config.COR_CINZA_CLARO if bloqueada else Config.COR_PAPEL, 4)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coluna.add_child(cap)

	var ajuda := UI.label("PC: A/D ou setas = pilotar   S/Shift = freio   Espaço/W = pulo   Números = código   M = som\n"
		+ "Celular: botões na tela", 15, Config.COR_CINZA_CLARO, 4)
	ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(ajuda)
	var rodape := _linha_botoes(caixa)
	_botao(rodape, "TELA INICIAL", Config.COR_CINZA_ESCURO, Config.COR_PAPEL, 260, func() -> void: voltar_inicio.emit())
	var qual := UI.label("Jogando no SAVE %d" % Progresso.slot, 16, Config.COR_CINZA_CLARO, 4)
	qual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rodape.add_child(qual)




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
		var b: Button = UI.botao(texto, cor, Config.COR_PRETO if liberada else Config.COR_CINZA_CLARO, 16)
		b.custom_minimum_size = Vector2(760, 66)
		b.disabled = not liberada
		b.add_theme_stylebox_override("disabled", UI.estilo(cor))
		b.add_theme_color_override("font_disabled_color", Config.COR_CINZA_CLARO)
		b.pressed.connect(func() -> void: jogar_fase.emit(i))
		lista.add_child(b)

	var linha := _linha_botoes(caixa)
	_botao(linha, "OFICINA", Config.COR_AMARELO, Config.COR_PRETO, 200, func() -> void: abrir_oficina.emit())
	_botao(linha, "HISTÓRIA", Config.COR_LARANJA_CLARO, Config.COR_PRETO, 200, func() -> void: ver_historia.emit())
	_botao(linha, "TROCAR BAG", Config.COR_CINZA, Config.COR_PAPEL, 200, func() -> void: voltar_menu.emit())


## Cutscene em tela cheia (cutscene.gd); "ao_terminar" é chamado no fim ou ao pular.
func mostrar_cutscene(cenas: Array, ao_terminar: Callable) -> void:
	limpar()
	var c = UI.tela_cheia(Cutscene.new())
	_atual = c
	add_child(c)
	c.iniciar(cenas)
	c.terminou.connect(ao_terminar)


## Oficina: tela própria (tela_oficina.gd), com a mecânica comentando as melhorias.
func mostrar_oficina(d: Dictionary, p: Dictionary) -> void:
	limpar()
	var tela = UI.tela_cheia(TelaOficina.new())
	_atual = tela
	add_child(tela)
	tela.configurar(d, p)
	tela.comprar.connect(func(id: String) -> void: comprar.emit(id))
	tela.voltar.connect(func() -> void: voltar_campanha.emit())


## Resultado da compra: a mecânica reage (comemora ou reclama do fiado).
func reagir_compra(melhoria: String, ok: bool, p: Dictionary) -> void:
	if _atual and _atual.has_method("reagir"):
		_atual.reagir(melhoria, ok, p)


func mostrar_fim(vitoria: bool, titulo: String, mensagem: String, estatisticas: String, indice_fase: int,
		imagem: String = "") -> void:
	var caixa := _base(0.8 if imagem == "" else 0.6, imagem)
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
	_botao(linha, "MENU", Config.COR_CINZA_ESCURO, Config.COR_PAPEL, 160, func() -> void: voltar_menu.emit())


## Pausa: o jogo fica congelado por trás (relógio, prazo, gasolina e CET param).
func mostrar_pausa(indice_fase: int, nome_fase: String) -> void:
	var caixa := _base(0.75)
	_titulo(caixa, "PAUSADO", 72, Config.COR_LARANJA)
	_titulo(caixa, "Fase %d: %s" % [indice_fase + 1, nome_fase], 26, Config.COR_PAPEL)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	caixa.add_child(coluna)
	var opcoes := [
		["CONTINUAR", Config.COR_LARANJA, Config.COR_PRETO, func() -> void: continuar.emit()],
		["REINICIAR FASE", Config.COR_AMARELO, Config.COR_PRETO, func() -> void: jogar_fase.emit(indice_fase)],
		["FASES", Config.COR_CINZA, Config.COR_PAPEL, func() -> void: voltar_campanha.emit()],
		["MENU", Config.COR_CINZA_ESCURO, Config.COR_PAPEL, func() -> void: voltar_menu.emit()],
	]
	for o in opcoes:
		var b: Button = UI.botao(o[0], o[1], o[2])
		b.custom_minimum_size = Vector2(320, 58)
		b.pressed.connect(o[3])
		coluna.add_child(b)
	_titulo(caixa, "P ou ESC: continuar     M: som", 18, Config.COR_CINZA_CLARO)
