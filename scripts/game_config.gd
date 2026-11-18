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
# tempo_fase: segundos totais da fase
# prazo_base / prazo_px_por_s: prazo do pedido = base + distância / px_por_s
# bonus_mult: segundos ganhos por segundo de prazo que sobrou
# distorcao: 0..1, quão "quebrados" ficam os números do código
# chance_chuva / chance_cet: chance por partida de chover / de a CNH vencida soltar a CET
# vel_cet: velocidade do carro da CET em relação à moto
# chance_blitz: chance de ser parado passando devagar na blitz
const DIFICULDADES := {
	"facil": {
		"nome": "BAG LARANJA",
		"rotulo": "Fácil",
		"cor": Color(0.91, 0.44, 0.11),
		"cor_texto": Color(0.07, 0.06, 0.06),
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
		"nome": "BAG AMARELA",
		"rotulo": "Médio",
		"cor": Color(0.95, 0.76, 0.19),
		"cor_texto": Color(0.07, 0.06, 0.06),
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
		"nome": "BAG PRETA",
		"rotulo": "Difícil",
		"cor": Color(0.1, 0.1, 0.1),
		"cor_texto": Color(0.95, 0.76, 0.19),
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

# --- Fase ---
const ENTREGAS_FASE := 5

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
