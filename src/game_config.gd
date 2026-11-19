extends RefCounted
## Constantes de balanceamento e paleta do jogo.
## Ajuste os números aqui para mudar a dificuldade sem mexer na lógica.

# --- Paleta "gritty": laranja, cinza, preto, vermelho ---
const COR_LARANJA := Color(0.91, 0.44, 0.11)
const COR_LARANJA_CLARO := Color(1.0, 0.6, 0.24)
const COR_VERMELHO := Color(0.75, 0.16, 0.12)
const COR_PRETO := Color(0.07, 0.06, 0.06)
const COR_CINZA_ESCURO := Color(0.16, 0.16, 0.15)
const COR_CINZA := Color(0.29, 0.27, 0.27)
const COR_CINZA_CLARO := Color(0.54, 0.52, 0.5)
const COR_PAPEL := Color(0.91, 0.89, 0.85)
const COR_AMARELO := Color(0.95, 0.76, 0.19)

# --- Dificuldade escolhida pela bag ---
# Nomes de paródia dos apps (iFood, 99 e Keeta), com as cores das bags de verdade.
# cor / cor_texto / cor_detalhe: bag, texto do botão e detalhe (borda do botão e faixa na bag)
# painel_bag: retângulo do detalhe desenhado na bag da moto
# tempo_fase: segundos totais da fase
# prazo_base / prazo_px_por_s: prazo do pedido = base + distância / px_por_s
# bonus_mult: segundos ganhos por segundo de prazo que sobrou
# distorcao: 0..1, quão "quebrados" ficam os números do código
# chance_chuva / chance_cet: chance por partida de chover / de a CNH vencida soltar a CET
# vel_cet: velocidade do carro da CET em relação à moto
# chance_blitz: chance de ser parado passando devagar na blitz
const DIFICULDADES := {
	"facil": {
		"nome": "iFudê",
		"rotulo": "Fácil",
		"cor": Color(0.85, 0.1, 0.14),
		"cor_texto": Color(0.97, 0.95, 0.92),
		"cor_detalhe": Color(0.97, 0.95, 0.92),
		"painel_bag": Rect2(-39, -92, 22, 5),
		"tempo_fase": 200.0,
		"prazo_base": 15.0,
		"prazo_px_por_s": 300.0,
		"bonus_mult": 2.5,
		"chance_cliente_demora": 0.15,
		"chance_pedido_atrasado": 0.10,
		"distorcao": 0.25,
		"chance_chuva": 0.25,
		"chance_cet": 0.5,
		"vel_cet": 0.82,
		"chance_blitz": 0.05,
	},
	"medio": {
		"nome": "99 Problemas",
		"rotulo": "Médio",
		"cor": Color(0.98, 0.8, 0.12),
		"cor_texto": Color(0.07, 0.06, 0.06),
		"cor_detalhe": Color(0.07, 0.06, 0.06),
		"painel_bag": Rect2(-38, -93, 20, 7),
		"tempo_fase": 170.0,
		"prazo_base": 10.0,
		"prazo_px_por_s": 360.0,
		"bonus_mult": 2.0,
		"chance_cliente_demora": 0.25,
		"chance_pedido_atrasado": 0.20,
		"distorcao": 0.55,
		"chance_chuva": 0.35,
		"chance_cet": 0.75,
		"vel_cet": 0.88,
		"chance_blitz": 0.08,
	},
	"dificil": {
		"nome": "Kitreta",
		"rotulo": "Difícil",
		"cor": Color(0.22, 0.76, 0.68),
		"cor_texto": Color(0.07, 0.06, 0.06),
		"cor_detalhe": Color(0.97, 0.9, 0.25),
		"painel_bag": Rect2(-42, -80, 28, 18),
		"tempo_fase": 130.0,
		"prazo_base": 6.0,
		"prazo_px_por_s": 420.0,
		"bonus_mult": 1.5,
		"chance_cliente_demora": 0.35,
		"chance_pedido_atrasado": 0.30,
		"distorcao": 0.9,
		"chance_chuva": 0.5,
		"chance_cet": 1.0,
		"vel_cet": 0.94,
		"chance_blitz": 0.12,
	},
}

# --- Campanha: fases em sequência ---
# Cada bag tem sua própria campanha. Vencer uma fase libera a próxima e paga em R$.
# entregas: quantas entregas fecham a fase
# tempo: multiplica o tempo_fase da bag (que vale para 5 entregas) proporcional às entregas
# quantidade: obstáculos de pista [mínimo, máximo] passados ao gerador (gerador_fase.gd)
# chuva / cet / blitz: multiplicam as chances da bag (0 = não aparece nessa fase)
const FASES := [
	{
		"nome": "Primeiro dia",
		"descricao": "Lombadas, buracos e cruzamentos. Sem blitz, sem chuva, sem CET.",
		"entregas": 3,
		"tempo": 1.2,
		"quantidade": {"lombada": [2, 3], "boca": [1, 2], "terra": [1, 1], "cruzamento": [1, 2], "blitz": [0, 0]},
		"chuva": 0.0, "cet": 0.0, "blitz": 0.0,
	},
	{
		"nome": "Pegando o jeito",
		"descricao": "Começam as blitzes.",
		"entregas": 4,
		"tempo": 1.1,
		"quantidade": {"lombada": [3, 4], "boca": [2, 3], "terra": [1, 2], "cruzamento": [2, 2], "blitz": [1, 1]},
		"chuva": 0.0, "cet": 0.0, "blitz": 1.0,
	},
	{
		"nome": "Sexta à noite",
		"descricao": "Pode chover, e a CET está de olho na sua CNH.",
		"entregas": 5,
		"tempo": 1.0,
		"quantidade": {"lombada": [3, 5], "boca": [3, 5], "terra": [1, 3], "cruzamento": [2, 3], "blitz": [1, 2]},
		"chuva": 1.0, "cet": 1.0, "blitz": 1.0,
	},
	{
		"nome": "Véspera de feriado",
		"descricao": "Mais lombadas e buracos, e a blitz para mais gente.",
		"entregas": 6,
		"tempo": 0.97,
		"quantidade": {"lombada": [4, 5], "boca": [3, 5], "terra": [1, 2], "cruzamento": [2, 3], "blitz": [1, 2]},
		"chuva": 1.0, "cet": 1.0, "blitz": 1.3,
	},
	{
		"nome": "Hora do Rush",
		"descricao": "Rua lotada, chuva mais frequente e relógio apertado.",
		"entregas": 7,
		"tempo": 0.95,
		"quantidade": {"lombada": [4, 6], "boca": [4, 6], "terra": [1, 2], "cruzamento": [2, 3], "blitz": [1, 2]},
		"chuva": 1.4, "cet": 1.0, "blitz": 1.5,
	},
]

# --- Pagamento (R$) ---
const PONTOS_POR_REAL := 10     # vencendo: R$ 1 a cada 10 pontos
const REAIS_POR_ENTREGA := 8    # perdendo: só as entregas feitas pagam a taxa

# --- Oficina: melhorias da moto, compradas entre as fases ---
# por_nivel: quanto cada nível soma ao atributo (0.07 = +7%)
const PRECOS_MELHORIA := [50, 100, 180]
const MELHORIAS := {
	"motor": {"nome": "Motor", "descricao": "+7% de velocidade e +10% de arrancada por nível", "por_nivel": 0.07},
	"freio": {"nome": "Freio", "descricao": "+18% de força de freio por nível (ajuda na chuva)", "por_nivel": 0.18},
	"tanque": {"nome": "Tanque", "descricao": "+25% de gasolina no tanque por nível", "por_nivel": 0.25},
	"amortecedor": {"nome": "Amortecedor", "descricao": "Aguenta pousar 6° mais torto por nível sem cair", "por_nivel": 0.1},
	"bag": {"nome": "Bag térmica", "descricao": "+12% de prazo em cada pedido por nível", "por_nivel": 0.12},
}

# --- Gasolina ---
const GASOLINA_MAX := 100.0
const GASOLINA_INICIAL := 55.0
const CONSUMO_PARADO := 0.08          # por segundo, moto ligada
const CONSUMO_VELOCIDADE_MAX := 1.6   # por segundo, em velocidade máxima
const TEMPO_ENCHER_TANQUE := 10.0     # segundos parado no posto p/ encher do zero
const POSTOS_ATIVOS := 3              # quantos postos aparecem por partida

# --- Pontuação ---
const PONTOS_ENTREGA := 100
const PONTOS_POR_SEG_SOBRA := 5
const PONTOS_ATRASADO := 40
const PENALIDADE_CODIGO := 25
const PONTOS_POR_SEG_RESTANTE := 2    # bônus ao fechar a fase

# --- Obstáculos (M2) ---
const PENALIDADE_QUEDA_LOMBADA := 40
const PENALIDADE_QUEDA_BOCA := 30
const PENALIDADE_CRUZAMENTO := 50
const PENALIDADE_CET := 60
const TEMPO_PERDIDO_CET := 8.0
const BONUS_FUGA_CET := 50
const DURACAO_CET := 22.0

# --- Mensagens ---
const MENSAGENS_SEM_GASOLINA := [
	"A moto bebeu menos que você no fim de semana, mas acabou primeiro.",
	"Pedido cancelado. Motivo: entregador virou pedestre.",
	"O cliente avaliou com 1 estrela: \"veio empurrando a moto\".",
	"Você tinha R$ 3,50 de gasolina e um sonho.",
	"A luz da reserva tava acesa desde terça. Você sabia.",
	"Empurrar moto também é cardio. Parabéns pelo treino.",
]

const MENSAGENS_TEMPO := [
	"O rush acabou e você ainda tá na rua.",
	"O app te deslogou. Motivo: lentidão crônica.",
	"Os clientes desistiram e pediram miojo.",
]
