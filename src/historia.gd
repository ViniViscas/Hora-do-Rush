extends RefCounted
## Roteiro das cutscenes: a história do Felipe, motoboy de São Paulo, e da mecânica Tati.
## Cada bag é um capítulo: iFudê (a casa), 99 Problemas (a reforma), Kitreta (a oficina).
## Cada cena: imagem + falas [quem fala ("" = narração), texto]. "titulo" aparece em cima.
## As imagens ficam em assets/img/cutscenes/; os cartões das fases reaproveitam as mesmas
## cinco imagens nos três capítulos, com textos diferentes.

const PASTA := "res://assets/img/cutscenes/"
const IMAGENS_FASES := ["04_primeiro_dia.jpg", "05_pegando_o_jeito.jpg", "06_sexta_a_noite.jpg",
	"07_vespera_de_feriado.jpg", "08_hora_do_rush_%s.jpg"]   # %s = bag: a fase 5 tem uma imagem por capítulo
const NOMES_FASES := ["PRIMEIRO DIA", "PEGANDO O JEITO", "SEXTA À NOITE", "VÉSPERA DE FERIADO", "HORA DO RUSH"]

## Ordem dos capítulos (cada um é liberado ao fechar o anterior, ver Config.CAPITULOS_EM_ORDEM).
const ORDEM := ["facil", "medio", "dificil"]

const CAPITULOS := {
	"facil": {
		"titulo": "CAPÍTULO 1: A CASA",
		"abertura": [
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
		],
		"fases": [
			[["", "Primeiro dia. Três entregas."], ["", "Calma, Felipe. É só não cair na lombada."]],
			[["", "Felipe já conhece as ruas. Agora aprendeu outra regra: na blitz, devagar."]],
			[["", "Sexta, chuva e pedido de pizza pra todo lado."], ["", "E a CNH... continua vencida."]],
			[["", "Véspera de feriado. Todo mundo pede, ninguém quer esperar."]],
			[["", "O último turno. Se fechar hoje, a entrada da casa tá paga."]],
		],
		"final": [
			{
				"imagem": "09_vitoria.jpg",
				"falas": [
					["TATI", "Falei que essa moto ia longe."],
					["", "Felipe virou o entregador mais rápido de São Paulo."],
					["", "E, pela primeira vez, chegou em casa. Na casa dele."],
				],
			},
		],
		"fundo_final": "09_vitoria.jpg",
	},
	"medio": {
		"titulo": "CAPÍTULO 2: A REFORMA",
		"abertura": [
			{
				"imagem": "12_cap2_abertura.jpg",
				"falas": [
					["", "A casa é dele. A goteira, o reboco caindo e a fiação também."],
					["TATI", "Parabéns, proprietário. Agora descobre quanto custa um saco de cimento."],
					["FELIPE", "O 99 Problemas paga melhor. Os prazos são mais curtos, mas eu dou conta."],
					["TATI", "Prazo curto é onde moto vira estatística. Vai com cabeça."],
				],
			},
		],
		"fases": [
			[["", "Primeiro turno no app novo. O relógio corre mais rápido aqui."]],
			[["", "Blitz de novo. Com prazo apertado, cada parada dói no bolso."]],
			[["", "Chuva, CET, cliente reclamando no chat."], ["", "Felipe não dorme direito há dias."]],
			[["", "Feriado: o app dobra a taxa. E dobra a pressão."]],
			[["", "Último turno do mês. Falta pouco para terminar a laje."]],
		],
		"final": [
			{
				"imagem": "13_cap2_final.jpg",
				"falas": [
					["", "Casa pintada, laje pronta e os amigos lá em cima."],
					["TATI", "Quem diria. O motoqueiro do arame agora tem até churrasqueira."],
					["FELIPE", "E ainda tô devendo a revisão da moto, né?"],
					["", "Mas o celular não para de vibrar."],
				],
			},
		],
		"fundo_final": "13_cap2_final.jpg",
	},
	"dificil": {
		"titulo": "CAPÍTULO 3: A OFICINA",
		"abertura": [
			{
				"imagem": "14_cap3_abertura.jpg",
				"falas": [
					["", "O aluguel da oficina subiu. A Tati tem até o fim do mês."],
					["TATI", "Doze anos aqui. Nunca deixei uma moto na mão. E agora sou eu que vou ficar."],
					["FELIPE", "O Kitreta paga o dobro. Me deixa ajudar."],
					["TATI", "Esse app trata motoqueiro como cronômetro. Promete que não vai fazer besteira."],
				],
			},
		],
		"fases": [
			[["", "Prazo de 6 minutos para atravessar o bairro. No Kitreta, atraso é bloqueio."]],
			[["", "Blitz, de novo. O app não quer saber."]],
			[["", "Chuva forte. O freio já não é o mesmo. Felipe também não."]],
			[["", "Três da manhã. O corpo pede para parar, o app pede mais uma."]],
			[["", "Último turno. É hoje que a oficina se salva."]],
		],
		# Cenas extras antes de um cartão de fase (índice da fase -> cenas)
		"antes_da_fase": {
			3: [
				{
					"imagem": "15_cap3_estresse.jpg",
					"falas": [
						["", "Um carro. Uma freada. O chão."],
						["", "Felipe levanta. A moto também. Dessa vez."],
						["TATI", "Larga esse celular e vem pra cá. Agora."],
					],
				},
			],
		},
		"final": [
			{
				"imagem": "16_cap3_final.jpg",
				"falas": [
					["", "A oficina não fechou. Agora tem dois nomes na porta."],
					["TATI", "Sócio. Primeira regra: ninguém aqui trabalha pra cronômetro."],
					["", "Felipe ainda faz entregas. Mas agora chega em casa a tempo do jantar."],
				],
			},
		],
		"fundo_final": "16_cap3_final.jpg",
	},
}

## Fundos da tela de fim quando o turno dá errado (iguais nos três capítulos).
const FUNDO_SEM_GASOLINA := "10_sem_gasolina.jpg"
const FUNDO_TEMPO := "11_tempo_esgotado.jpg"
const FRASE_SEM_GASOLINA := "O tanque secou antes do turno acabar. Amanhã tem mais."
const FRASE_TEMPO := "O rush acabou antes dele. Amanhã tem outro turno."


static func caminho(imagem: String) -> String:
	return PASTA + imagem


static func abertura(dif_id: String) -> Array:
	return CAPITULOS[dif_id].abertura


static func final(dif_id: String) -> Array:
	return CAPITULOS[dif_id].final


static func fundo_final(dif_id: String) -> String:
	return CAPITULOS[dif_id].fundo_final


## Cenas antes da fase: as extras do capítulo (se houver) e o cartão com o título da fase.
static func antes_da_fase(dif_id: String, n: int) -> Array:
	var cap: Dictionary = CAPITULOS[dif_id]
	var cenas: Array = []
	cenas.append_array(cap.get("antes_da_fase", {}).get(n, []))
	cenas.append({
		"imagem": IMAGENS_FASES[n].replace("%s", dif_id),
		"titulo": "FASE %d: %s" % [n + 1, NOMES_FASES[n]],
		"falas": cap.fases[n],
	})
	return cenas


## Capítulo que precisa ser fechado antes deste ("" = nenhum).
static func capitulo_anterior(dif_id: String) -> String:
	var i := ORDEM.find(dif_id)
	return ORDEM[i - 1] if i > 0 else ""
