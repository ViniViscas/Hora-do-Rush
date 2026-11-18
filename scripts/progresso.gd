extends RefCounted
## Progresso da campanha, salvo em disco. Cada bag (dificuldade) tem o seu:
## fases liberadas, dinheiro, níveis das melhorias, recorde e mapa (semente) de cada fase.

const Config := preload("res://scripts/game_config.gd")

## Os testes trocam o arquivo para não mexer no progresso de quem joga.
static var caminho := "user://progresso.cfg"


static func carregar(dif_id: String) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	var n := Config.FASES.size()
	var p := {
		"liberada": cfg.get_value(dif_id, "liberada", 0),   # índice da maior fase liberada
		"dinheiro": cfg.get_value(dif_id, "dinheiro", 0),
		"niveis": cfg.get_value(dif_id, "niveis", {}),
		"recordes": cfg.get_value(dif_id, "recordes", []),
		"sementes": cfg.get_value(dif_id, "sementes", []),
	}
	for id in Config.MELHORIAS:
		if not p.niveis.has(id):
			p.niveis[id] = 0
	p.recordes.resize(n)
	for i in n:
		if p.recordes[i] == null:
			p.recordes[i] = 0
	# Cada fase tem um mapa fixo na campanha: tentar de novo repete o mesmo mapa.
	var sorteio := RandomNumberGenerator.new()
	sorteio.randomize()
	while p.sementes.size() < n:
		p.sementes.append(sorteio.randi_range(1, 999999))
	return p


static func salvar(dif_id: String, p: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	for chave in p:
		cfg.set_value(dif_id, chave, p[chave])
	cfg.save(caminho)


static func preco(p: Dictionary, melhoria: String) -> int:
	var nivel: int = p.niveis[melhoria]
	if nivel >= Config.PRECOS_MELHORIA.size():
		return -1
	return Config.PRECOS_MELHORIA[nivel]


## Compra o próximo nível. Retorna false se já está no máximo ou falta dinheiro.
static func comprar(dif_id: String, p: Dictionary, melhoria: String) -> bool:
	var custo := preco(p, melhoria)
	if custo < 0 or p.dinheiro < custo:
		return false
	p.dinheiro -= custo
	p.niveis[melhoria] += 1
	salvar(dif_id, p)
	return true


## Quanto a melhoria soma ao atributo (0.14 = +14%).
static func bonus(p: Dictionary, melhoria: String) -> float:
	return p.niveis[melhoria] * Config.MELHORIAS[melhoria].por_nivel
