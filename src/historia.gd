extends RefCounted
## Roteiro das cutscenes: a história do Felipe, motoboy de São Paulo que quer comprar
## a própria casa, com a ajuda da mecânica Tati. As imagens ficam em assets/img/cutscenes/.
## Cada cena: imagem + falas [quem fala ("" = narração), texto]. "titulo" aparece em cima.

const PASTA := "res://assets/img/cutscenes/"

const INTRO := [
	{
		"imagem": "01_quartinho.jpg",
		"falas": [
			["", "São Paulo. Felipe tem 28 anos, uma moto velha e três contas atrasadas."],
			["", "No celular, um anúncio: \"Casa com quintal. Aceita entrada.\""],
			["FELIPE", "Um dia essa casa vai ser minha."],
		],
	},
	{
		"imagem": "02_moto_nao_liga.jpg",
		"falas": [
			["", "A moto morreu no primeiro dia do novo app."],
			["", "Só tinha um lugar aberto àquela hora."],
		],
	},
	{
		"imagem": "03_oficina_da_tati.jpg",
		"falas": [
			["TATI", "Essa moto tá segurando no arame, hein."],
			["FELIPE", "Não tenho como pagar agora. Mas eu vou entregar muito."],
			["TATI", "Então faz assim: eu arrumo, você paga com as entregas. Cada real que sobrar, a gente investe na máquina."],
			["TATI", "E vê se renova essa CNH, que a CET tá de olho."],
		],
	},
]

## Um cartão antes de cada fase (mesma ordem de Config.FASES).
const FASES := [
	{
		"imagem": "04_primeiro_dia.jpg",
		"titulo": "FASE 1: PRIMEIRO DIA",
		"falas": [["", "Primeiro dia. Três entregas."], ["", "Calma, Felipe. É só não cair na lombada."]],
	},
	{
		"imagem": "05_pegando_o_jeito.jpg",
		"titulo": "FASE 2: PEGANDO O JEITO",
		"falas": [["", "Felipe já conhece as ruas. Agora aprendeu outra regra: na blitz, devagar."]],
	},
	{
		"imagem": "06_sexta_a_noite.jpg",
		"titulo": "FASE 3: SEXTA À NOITE",
		"falas": [["", "Sexta, chuva e pedido de pizza pra todo lado."], ["", "E a CNH... continua vencida."]],
	},
	{
		"imagem": "07_vespera_de_feriado.jpg",
		"titulo": "FASE 4: VÉSPERA DE FERIADO",
		"falas": [["", "Véspera de feriado. Todo mundo pede, ninguém quer esperar."]],
	},
	{
		"imagem": "08_hora_do_rush.jpg",
		"titulo": "FASE 5: HORA DO RUSH",
		"falas": [["", "O último turno. Se fechar hoje, a entrada da casa tá paga."]],
	},
]

const VITORIA := [
	{
		"imagem": "09_vitoria.jpg",
		"falas": [
			["TATI", "Falei que essa moto ia longe."],
			["", "Felipe virou o entregador mais rápido de São Paulo."],
			["", "E, pela primeira vez, chegou em casa. Na casa dele."],
		],
	},
]

## Fundos da tela de fim quando o turno dá errado.
const FUNDO_SEM_GASOLINA := "10_sem_gasolina.jpg"
const FUNDO_TEMPO := "11_tempo_esgotado.jpg"
const FUNDO_VITORIA := "09_vitoria.jpg"

## Fechamento das derrotas, logo abaixo da mensagem engraçada.
const FRASE_SEM_GASOLINA := "O tanque secou antes do turno acabar. Amanhã tem mais."
const FRASE_TEMPO := "O rush acabou antes dele. Mas a casa ainda tá lá. Esperando."


static func caminho(imagem: String) -> String:
	return PASTA + imagem
