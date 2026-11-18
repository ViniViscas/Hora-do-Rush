extends RefCounted
## Layout da fase 1. Tudo em pixels; o chão "normal" fica em y = 600.
## Para mexer no mapa, edite só este arquivo.

const LARGURA := 14000.0

## Perfil do chão (pontos da superfície, da esquerda para a direita).
const CHAO := [
	Vector2(-700, 600), Vector2(1300, 600), Vector2(1500, 500), Vector2(2200, 500),
	Vector2(2400, 600), Vector2(4200, 600), Vector2(4350, 540), Vector2(4700, 540),
	Vector2(4850, 600), Vector2(10400, 600), Vector2(10600, 480), Vector2(11400, 480),
	Vector2(11600, 600), Vector2(14700, 600),
]

const RESTAURANTES := [
	[450.0, "Pizzaria Bella Nonna"], [3050.0, "Esfiha Express"], [6000.0, "Burguer da Quebrada"],
	[8900.0, "Pastel da Feira"], [12750.0, "Marmitaria Dona Cida"],
]

const CASAS := [
	[850.0, "12"], [1700.0, "77"], [2650.0, "145"], [3700.0, "230"], [4520.0, "301"],
	[5150.0, "418"], [6500.0, "512"], [6950.0, "640"], [7750.0, "15-A"], [8250.0, "22"],
	[9250.0, "88"], [11850.0, "1010"], [12400.0, "1107"], [13300.0, "1234"], [13750.0, "1350"],
]

## Vagas possíveis de posto; a cada partida só Config.POSTOS_ATIVOS aparecem.
const POSTOS := [1120.0, 2030.0, 4000.0, 5550.0, 10150.0, 13020.0]

## Obstáculos sólidos: [x, tipo, tamanho]
const BLOCOS := [
	[2480.0, "cone", Vector2(26, 36)], [3350.0, "cacamba", Vector2(110, 55)],
	[5780.0, "caixote", Vector2(54, 48)], [6250.0, "caixote", Vector2(54, 48)],
	[6730.0, "cone", Vector2(26, 36)], [9400.0, "caixote", Vector2(54, 48)],
	[11200.0, "cone", Vector2(26, 36)], [13550.0, "cacamba", Vector2(110, 55)],
]

## Obstáculos do M2
const LOMBADAS := [3500.0, 5330.0, 8600.0, 11000.0]
const BOCAS_DE_LOBO := [4950.0, 7980.0, 9090.0, 12560.0]
const TERRA := [[2740.0, 2930.0], [7550.0, 8450.0]]
const CRUZAMENTOS := [7350.0, 12100.0]
const BLITZ := [[9480.0, 9880.0]]
## Trechos onde PODE aparecer ciclovia (cada um tem 50% de chance por partida).
const CICLOVIAS := [[3560.0, 4150.0], [9950.0, 10380.0], [11650.0, 12000.0], [13400.0, 13950.0]]
