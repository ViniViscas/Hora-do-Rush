extends RefCounted
## Conquistas: ficam no save em uso (seção "conquistas" do arquivo do Progresso),
## guardando a data em que cada uma foi desbloqueada.
## main.gd chama desbloquear() quando algo acontece; se for novidade, mostra o aviso.

const Config := preload("res://src/game_config.gd")
const Progresso := preload("res://src/progresso.gd")

const LISTA := [
	{"id": "primeira_entrega", "nome": "Primeira entrega", "descricao": "Entregue o primeiro pedido."},
	{"id": "turno", "nome": "Turno fechado", "descricao": "Vença uma fase."},
	{"id": "liso", "nome": "Liso", "descricao": "Vença uma fase sem cair nenhuma vez."},
	{"id": "pouso", "nome": "Asa delta", "descricao": "Faça um pouso perfeito depois de uma lombada."},
	{"id": "cet", "nome": "Fugiu da CET", "descricao": "Despiste a perseguição da CET."},
	{"id": "blitz", "nome": "Passou batido", "descricao": "Passe embalado pela blitz sem ser parado."},
	{"id": "reserva", "nome": "No vapor", "descricao": "Vença uma fase com menos de 10% de gasolina."},
	{"id": "melhoria", "nome": "Investimento", "descricao": "Compre a primeira melhoria na oficina."},
	{"id": "talo", "nome": "Moto no talo", "descricao": "Deixe todas as melhorias no nível máximo."},
	{"id": "cap_facil", "nome": "A casa", "descricao": "Feche o capítulo 1 (iFudê)."},
	{"id": "cap_medio", "nome": "A reforma", "descricao": "Feche o capítulo 2 (99 Problemas)."},
	{"id": "cap_dificil", "nome": "A oficina", "descricao": "Feche o capítulo 3 (Kitreta)."},
]


static func info(id: String) -> Dictionary:
	for c in LISTA:
		if c.id == id:
			return c
	return {}


static func tem(id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(Progresso.caminho)
	return cfg.has_section_key("conquistas", id)


## Ids desbloqueados neste save.
static func desbloqueadas() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(Progresso.caminho)
	if not cfg.has_section("conquistas"):
		return []
	return Array(cfg.get_section_keys("conquistas"))


## Desbloqueia; retorna true se é nova (para mostrar o aviso).
static func desbloquear(id: String) -> bool:
	if info(id).is_empty():
		return false
	var cfg := ConfigFile.new()
	cfg.load(Progresso.caminho)
	if cfg.has_section_key("conquistas", id):
		return false
	cfg.set_value("conquistas", id, int(Time.get_unix_time_from_system()))
	cfg.save(Progresso.caminho)
	return true


## Saves de antes das conquistas: libera, sem aviso, o que o progresso já comprova.
static func conferir_progresso() -> void:
	var ids := []
	for cap in ["facil", "medio", "dificil"]:
		if Progresso.campanha_fechada(cap):
			ids.append_array(["turno", "cap_" + cap])
	var p: Dictionary = Progresso.carregar("facil")
	var no_maximo := true
	var alguma := false
	for m in p.niveis:
		if p.niveis[m] < Config.PRECOS_MELHORIA.size():
			no_maximo = false
		if p.niveis[m] > 0:
			alguma = true
	if alguma:
		ids.append("melhoria")
	if no_maximo:
		ids.append("talo")
	for id in ids:
		desbloquear(id)
