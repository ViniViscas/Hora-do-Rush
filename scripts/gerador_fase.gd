extends RefCounted
## Gerador procedural da fase. A mesma semente sempre gera o mesmo mapa.
## Tudo em pixels; o chão "normal" fica em y = 600.
##
## Ordem de montagem: chão (platôs/viadutos) → obstáculos de pista → restaurantes,
## postos e casas → obstáculos sólidos → trechos de ciclovia.
## O "respiro" entre as coisas fica na tabela FOLGAS: é ali que se ajusta.

const LARGURA := 14000.0
const Y_CHAO := 600.0
const INICIO_LIVRE := 600.0   # nada perigoso perto de onde a moto nasce
const FIM_LIVRE := 300.0

## Distância mínima (px, borda a borda) entre dois tipos de coisa na pista.
## -1 = podem se sobrepor. Par fora da lista = só não podem se encostar.
const FOLGAS := [
	# Lombada e boca de lobo: embalo antes e pista livre para pousar.
	["lombada", "lombada", 650], ["lombada", "boca", 650], ["boca", "boca", 550],
	["lombada", "blitz", 750], ["boca", "blitz", 750],
	["lombada", "cruzamento", 550], ["boca", "cruzamento", 550],
	["lombada", "terra", 450], ["boca", "terra", 450],
	["lombada", "bloco", 330], ["boca", "bloco", 330],
	["lombada", "rampa", 200], ["boca", "rampa", 200],
	["lombada", "ciclovia", 100], ["boca", "ciclovia", 100],
	["lombada", "local", 40], ["boca", "local", 40],
	["lombada", "borda", 500], ["boca", "borda", 500],
	# Blitz: chega-se nela embalado, para a escolha "freio ou arrisco" pesar.
	["blitz", "blitz", 2000], ["blitz", "cruzamento", 750], ["blitz", "terra", 650],
	["blitz", "bloco", 300], ["blitz", "ciclovia", 300], ["blitz", "rampa", 100],
	["blitz", "local", 40], ["blitz", "borda", 800],
	# Cruzamento
	["cruzamento", "cruzamento", 1200], ["cruzamento", "terra", 450], ["cruzamento", "bloco", 200],
	["cruzamento", "rampa", 150], ["cruzamento", "ciclovia", 150], ["cruzamento", "local", 50],
	["cruzamento", "borda", 500],
	# Estrada de terra
	["terra", "terra", 1200], ["terra", "bloco", 50], ["terra", "ciclovia", 200],
	["terra", "rampa", 50], ["terra", "local", -1], ["terra", "borda", 200],
	# Ciclovia (atalho): pode passar na frente de casas e em rampas
	["ciclovia", "ciclovia", 600], ["ciclovia", "bloco", 80], ["ciclovia", "local", -1],
	["ciclovia", "rampa", -1], ["ciclovia", "borda", 200],
	# Sólidos e endereços
	["bloco", "bloco", 150], ["bloco", "local", 30], ["bloco", "rampa", 80], ["bloco", "borda", 200],
	["local", "local", 20], ["local", "rampa", 10], ["local", "borda", -1],
	["rampa", "borda", -1],
	# Topo de platô/viaduto: tudo pode ficar lá em cima, menos cruzamento
	["plato", "lombada", -1], ["plato", "boca", -1], ["plato", "blitz", -1], ["plato", "terra", -1],
	["plato", "ciclovia", -1], ["plato", "bloco", -1], ["plato", "local", -1], ["plato", "rampa", -1],
	["plato", "borda", -1], ["plato", "plato", -1],
]

## Quantos obstáculos de pista por fase: [mínimo, máximo] (padrão; cada fase da
## campanha passa a sua em Config.FASES). O mínimo é garantido; os extras só
## entram se couberem com as folgas.
const QUANTIDADE := {
	"lombada": [3, 5], "boca": [3, 5], "terra": [1, 3], "cruzamento": [2, 3], "blitz": [1, 2],
}
const CANDIDATAS_CICLOVIA := 4   # cada uma tem 50% de chance por partida (obstaculos.gd)
const N_RESTAURANTES := 5
const N_CASAS := 15
const N_POSTOS := 6              # vagas; só Config.POSTOS_ATIVOS aparecem
const N_BLOCOS := [6, 9]

const LARG_LOCAL := {"restaurante": 220.0, "casa": 160.0, "posto": 240.0}
const TIPOS_BLOCO := [["cone", Vector2(26, 36)], ["caixote", Vector2(54, 48)], ["cacamba", Vector2(110, 55)]]
const NOMES_RESTAURANTE := [
	"Pizzaria Bella Nonna", "Esfiha Express", "Burguer da Quebrada", "Pastel da Feira",
	"Marmitaria Dona Cida", "Yakisoba do Japa", "Açaí Sem Freio", "Churrasquinho do Tião",
	"Padaria Pão Nosso", "Hot Dog do Careca", "Sushi Vila Sônia", "Tapioca da Bahia",
]

var _rng := RandomNumberGenerator.new()
var _folga := {}
var _ocupados: Array = []   # [tipo, x0, x1]
var _quant: Dictionary = QUANTIDADE


func _init() -> void:
	for f in FOLGAS:
		_folga[f[0] + "|" + f[1]] = f[2]
		_folga[f[1] + "|" + f[0]] = f[2]


## Gera a fase inteira. Retorna um dicionário com o layout (ver o fim da função).
func gerar(semente: int, quantidade: Dictionary = QUANTIDADE) -> Dictionary:
	_rng.seed = semente
	_quant = quantidade
	_ocupados.clear()
	_ocupar("borda", -800.0, INICIO_LIVRE)
	_ocupar("borda", LARGURA - FIM_LIVRE, LARGURA + 800.0)

	var chao := _gerar_chao()
	# Se faltou o mínimo de algum tipo, refaz só os obstáculos (continua determinístico)
	var antes := _ocupados.duplicate()
	var pista := _gerar_obstaculos_pista()
	for tentativa in 10:
		if _tem_minimos(pista):
			break
		_ocupados = antes.duplicate()
		pista = _gerar_obstaculos_pista()
	var restaurantes := _gerar_locais("restaurante", N_RESTAURANTES)
	var postos := _gerar_locais("posto", N_POSTOS)
	var casas := _gerar_locais("casa", N_CASAS)

	var nomes := NOMES_RESTAURANTE.duplicate()
	_embaralhar(nomes)
	var lista_rest := []
	for i in restaurantes.size():
		lista_rest.append([restaurantes[i], nomes[i]])

	# Numeração da rua cresce da esquerda para a direita
	var lista_casas := []
	var numero := _rng.randi_range(8, 60)
	for x in casas:
		var nome := str(numero)
		if _rng.randf() < 0.12:
			nome += "-A"
		lista_casas.append([x, nome])
		numero += _rng.randi_range(15, 110)

	var blocos := []
	for i in _rng.randi_range(N_BLOCOS[0], N_BLOCOS[1]):
		var t: Array = TIPOS_BLOCO[_rng.randi() % TIPOS_BLOCO.size()]
		var tam: Vector2 = t[1]
		var x := _colocar("bloco", tam.x, 0.0, LARGURA)
		if x >= 0.0:
			blocos.append([x, t[0], tam])
	blocos.sort_custom(func(a, b) -> bool: return a[0] < b[0])

	var ciclovias := []
	for i in CANDIDATAS_CICLOVIA:
		var w := _rng.randf_range(350.0, 600.0)
		var x := _colocar("ciclovia", w, 0.0, LARGURA)
		if x >= 0.0:
			ciclovias.append([x - w / 2.0, x + w / 2.0])
	ciclovias.sort_custom(func(a, b) -> bool: return a[0] < b[0])

	return {
		"semente": semente,
		"largura": LARGURA,
		"chao": chao,
		"restaurantes": lista_rest,
		"casas": lista_casas,
		"postos": postos,
		"blocos": blocos,
		"lombadas": pista.lombada,
		"bocas": pista.boca,
		"terra": pista.terra,
		"cruzamentos": pista.cruzamento,
		"blitz": pista.blitz,
		"ciclovias": ciclovias,
	}


# ---------------------------------------------------------------- chão

## Rua plana com alguns platôs e viadutos. As rampas ficam marcadas como ocupadas
## para nenhum obstáculo ou endereço cair na inclinação; o topo, só para o cruzamento.
func _gerar_chao() -> Array:
	var pts := [Vector2(-700, Y_CHAO)]
	var x := _rng.randf_range(1300.0, 2400.0)
	while x < LARGURA - 1800.0:
		var altura: float = [60.0, 80.0, 100.0, 120.0][_rng.randi() % 4]
		var rampa := 120.0 + altura * 0.7 + _rng.randf_range(0.0, 40.0)
		var topo := _rng.randf_range(400.0, 900.0)
		var y := Y_CHAO - altura
		pts.append(Vector2(x, Y_CHAO))
		pts.append(Vector2(x + rampa, y))
		pts.append(Vector2(x + rampa + topo, y))
		pts.append(Vector2(x + 2.0 * rampa + topo, Y_CHAO))
		_ocupar("rampa", x, x + rampa)
		_ocupar("plato", x + rampa, x + rampa + topo)
		_ocupar("rampa", x + rampa + topo, x + 2.0 * rampa + topo)
		x += 2.0 * rampa + topo + _rng.randf_range(1800.0, 3800.0)
	pts.append(Vector2(LARGURA + 700.0, Y_CHAO))
	return pts


# ---------------------------------------------------------------- obstáculos de pista

## Percorre a rua da esquerda para a direita colocando os obstáculos numa ordem
## sorteada. O espaço que sobra é espalhado entre eles, então o mapa fica cheio
## por igual, mas cada um respeita a folga em relação a tudo que já existe.
func _gerar_obstaculos_pista() -> Dictionary:
	# Espaço útil: tira o começo, o fim e as rampas (com a folga típica em volta delas)
	var espaco := LARGURA - INICIO_LIVRE - FIM_LIVRE
	for o in _ocupados:
		if o[0] == "rampa":
			espaco -= o[2] - o[1] + 250.0

	var saco := []
	var extras := []
	for tipo in _quant:
		for i in _quant[tipo][0]:
			saco.append(tipo)
		for i in _rng.randi_range(0, _quant[tipo][1] - _quant[tipo][0]):
			extras.append(tipo)
	_embaralhar(extras)
	var usado := 0.0
	for tipo in saco:
		usado += _espaco_tipico(tipo)
	for tipo in extras:
		if usado + _espaco_tipico(tipo) <= espaco:
			saco.append(tipo)
			usado += _espaco_tipico(tipo)
	_embaralhar(saco)

	var res := {"lombada": [], "boca": [], "terra": [], "cruzamento": [], "blitz": []}
	var cursor := INICIO_LIVRE
	while not saco.is_empty():
		var tipo: String = saco.pop_front()
		var w := _largura_pista(tipo)
		usado -= _espaco_tipico(tipo)
		# Sobra = espaço livre além do mínimo; sorteia quanto dela gastar antes deste
		var livre := LARGURA - FIM_LIVRE - cursor
		for o in _ocupados:
			if o[0] == "rampa" and o[1] > cursor:
				livre -= o[2] - o[1] + 250.0
		var sobra := (livre - usado - _espaco_tipico(tipo)) / (saco.size() + 1)
		var x0 := cursor + _rng.randf_range(0.0, maxf(sobra, 0.0) * 1.6)
		# Empurra para frente até respeitar todas as folgas
		while x0 + w < LARGURA and not _cabe(tipo, x0, x0 + w):
			x0 += 25.0
		if x0 + w < LARGURA:
			_ocupar(tipo, x0, x0 + w)
			cursor = x0 + w
		else:
			# Não coube à frente: procura qualquer brecha no mapa (senão, fica sem esse)
			var c := _colocar(tipo, w, INICIO_LIVRE, LARGURA - FIM_LIVRE)
			if c < 0.0:
				continue
			x0 = c - w / 2.0
		if tipo == "terra" or tipo == "blitz":
			res[tipo].append([x0, x0 + w])
		else:
			res[tipo].append(x0 + w / 2.0)
	return res


func _tem_minimos(pista: Dictionary) -> bool:
	for tipo in _quant:
		if pista[tipo].size() < _quant[tipo][0]:
			return false
	return true


## Largura média + folga média para os vizinhos de pista: quanto de rua um obstáculo "gasta".
func _espaco_tipico(tipo: String) -> float:
	var media := {"lombada": 92.0, "boca": 68.0, "cruzamento": 200.0, "blitz": 420.0, "terra": 495.0}
	var soma := 0.0
	for outro in QUANTIDADE:
		soma += float(_folga.get(tipo + "|" + outro, 0))
	return media[tipo] + soma / QUANTIDADE.size()


func _largura_pista(tipo: String) -> float:
	match tipo:
		"lombada": return 92.0
		"boca": return 68.0
		"cruzamento": return 200.0
		"blitz": return _rng.randf_range(380.0, 460.0)
		"terra": return _rng.randf_range(190.0, 800.0)
	return 100.0


# ---------------------------------------------------------------- endereços

## Divide a rua em faixas iguais e tenta um endereço em cada, para ficarem espalhados.
func _gerar_locais(tipo: String, n: int) -> Array:
	var w: float = LARG_LOCAL[tipo]
	var faixa := (LARGURA - 200.0) / n
	var xs := []
	for i in n:
		var x := _colocar(tipo, w, 100.0 + i * faixa, 100.0 + (i + 1) * faixa)
		if x < 0.0:
			x = _colocar(tipo, w, 100.0, LARGURA - 100.0)
		if x >= 0.0:
			xs.append(x)
	xs.sort()
	return xs


# ---------------------------------------------------------------- ocupação

func _tipo_ocupacao(tipo: String) -> String:
	return "local" if LARG_LOCAL.has(tipo) else tipo


func _ocupar(tipo: String, x0: float, x1: float) -> void:
	_ocupados.append([_tipo_ocupacao(tipo), x0, x1])


func _cabe(tipo: String, x0: float, x1: float) -> bool:
	var t := _tipo_ocupacao(tipo)
	for o in _ocupados:
		var folga: float = _folga.get(t + "|" + o[0], 0)
		if folga < 0.0:
			continue
		if maxf(x0, o[1]) - minf(x1, o[2]) < folga:
			return false
	return true


## Sorteia uma posição livre dentro de [de, ate]. Retorna o centro, ou -1 se não achou.
func _colocar(tipo: String, w: float, de: float, ate: float) -> float:
	for i in 80:
		var c := _rng.randf_range(de + w / 2.0, ate - w / 2.0)
		if _cabe(tipo, c - w / 2.0, c + w / 2.0):
			_ocupar(tipo, c - w / 2.0, c + w / 2.0)
			return c
	return -1.0


func _embaralhar(lista: Array) -> void:
	for i in range(lista.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = lista[i]
		lista[i] = lista[j]
		lista[j] = tmp
