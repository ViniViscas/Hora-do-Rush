extends RefCounted
## Ranking local: os TAMANHO melhores resultados de cada fase de cada capítulo, com nome.
## Fica num arquivo só (user://ranking.cfg), compartilhado por todos os saves deste
## computador: é o "placar da máquina", como nos fliperamas.

const TAMANHO := 5
const MAX_NOME := 12

## Os testes trocam o arquivo para não mexer no ranking de quem joga.
static var caminho := "user://ranking.cfg"


static func _secao(dif_id: String, fase: int) -> String:
	return "%s_%d" % [dif_id, fase]


## Lista ordenada (maior primeiro) de {"nome", "pontos", "data"}.
static func lista(dif_id: String, fase: int) -> Array:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	return cfg.get_value(_secao(dif_id, fase), "lista", [])


## Esses pontos entram no ranking da fase?
static func entra(dif_id: String, fase: int, pontos: int) -> bool:
	if pontos <= 0:
		return false
	var l := lista(dif_id, fase)
	return l.size() < TAMANHO or pontos > int(l[l.size() - 1].pontos)


## Grava o resultado; retorna a posição (1 = primeiro) ou 0 se não entrou.
static func registrar(dif_id: String, fase: int, nome: String, pontos: int) -> int:
	if not entra(dif_id, fase, pontos):
		return 0
	nome = nome.strip_edges().substr(0, MAX_NOME)
	if nome == "":
		nome = "FELIPE"
	var l := lista(dif_id, fase)
	var pos := 0
	while pos < l.size() and int(l[pos].pontos) >= pontos:
		pos += 1
	var d := Time.get_datetime_dict_from_system()
	l.insert(pos, {"nome": nome, "pontos": pontos, "data": "%02d/%02d/%d" % [d.day, d.month, d.year]})
	l.resize(mini(l.size(), TAMANHO))
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	cfg.set_value(_secao(dif_id, fase), "lista", l)
	cfg.set_value("geral", "ultimo_nome", nome)
	cfg.save(caminho)
	return pos + 1


## Último nome digitado (já vem preenchido na próxima vez).
static func ultimo_nome() -> String:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	return cfg.get_value("geral", "ultimo_nome", "")
