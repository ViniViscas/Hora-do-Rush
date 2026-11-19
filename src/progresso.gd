extends RefCounted
## Progresso da campanha, salvo em disco. Cada bag (capítulo) tem o seu: fases liberadas,
## recorde e mapa (semente) de cada fase. O dinheiro e as melhorias são da moto do Felipe,
## a mesma nos três capítulos (seção "moto" do arquivo).
##
## Há SLOTS espaços de save (user://save_1.cfg, save_2.cfg...): cada um é uma campanha
## independente. A tela inicial escolhe o slot (nova campanha ou carregar) e, a partir
## daí, "caminho" aponta para o arquivo dele.

const Config := preload("res://src/game_config.gd")
const Historia := preload("res://src/historia.gd")

const SLOTS := 3
## Arquivo único das versões antigas (antes dos slots): vira o save 1 na primeira abertura.
static var caminho_antigo := "user://progresso.cfg"
## Começo do nome dos arquivos de save (os testes trocam para não mexer nos saves de quem joga).
static var prefixo := "user://save_"

## Slot em uso (0 = nenhum escolhido ainda: mostra a tela inicial). Sobrevive ao recarregar a cena.
static var slot := 0
## Arquivo do save em uso. Os testes trocam o arquivo para não mexer no progresso de quem joga.
static var caminho := "user://save_1.cfg"


# ---------------------------------------------------------------- slots

static func caminho_slot(n: int) -> String:
	return "%s%d.cfg" % [prefixo, n]


static func existe(n: int) -> bool:
	return FileAccess.file_exists(caminho_slot(n))


static func algum_save() -> bool:
	for n in range(1, SLOTS + 1):
		if existe(n):
			return true
	return false


## Passa a usar o save do slot n.
static func usar(n: int) -> void:
	slot = n
	caminho = caminho_slot(n)


## Começa uma campanha do zero no slot n (apaga o que havia nele).
static func novo(n: int) -> void:
	apagar(n)
	usar(n)
	var cfg := ConfigFile.new()
	cfg.set_value("save", "criado", int(Time.get_unix_time_from_system()))
	cfg.set_value("save", "atualizado", int(Time.get_unix_time_from_system()))
	cfg.save(caminho)


static func apagar(n: int) -> void:
	if existe(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_slot(n)))
	if slot == n:
		slot = 0


## Versões antigas tinham um só arquivo: na primeira abertura com slots, ele vira o save 1.
static func migrar_antigo() -> void:
	if FileAccess.file_exists(caminho_antigo) and not algum_save():
		DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho_antigo),
			ProjectSettings.globalize_path(caminho_slot(1)))


## Resumo para a tela de carregar: capítulo atual, fases vencidas, dinheiro e data.
static func resumo(n: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(caminho_slot(n)) != OK:
		return {}
	var total := Config.FASES.size()
	var vencidas := 0
	var capitulo := ""
	var fase := 1
	for id in Historia.ORDEM:
		var recordes: Array = cfg.get_value(id, "recordes", [])
		var feitas := 0
		for r in recordes:
			if r != null and r > 0:
				feitas += 1
		vencidas += feitas
		# Capítulo atual: o primeiro que ainda não foi fechado
		if capitulo == "" and feitas < total:
			capitulo = id
			fase = int(cfg.get_value(id, "liberada", 0)) + 1
	var atualizado: int = cfg.get_value("save", "atualizado", 0)
	if atualizado == 0:   # save antigo, de antes dos slots: usa a data do arquivo
		atualizado = FileAccess.get_modified_time(caminho_slot(n))
	return {
		"capitulo": capitulo,   # "" = os três capítulos fechados
		"fase": fase,
		"vencidas": vencidas,
		"total": total * Historia.ORDEM.size(),
		"dinheiro": cfg.get_value("moto", "dinheiro", 0),
		"data": _data(atualizado) if atualizado > 0 else "",
	}


## "19/11/2026 14:32", no fuso do computador.
static func _data(unix: int) -> String:
	var fuso := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + fuso)
	return "%02d/%02d/%d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


# ---------------------------------------------------------------- campanha


## Chaves que pertencem à moto do Felipe (as mesmas nos três capítulos), e não à bag.
const DA_MOTO := ["dinheiro", "niveis"]


static func carregar(dif_id: String) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	var n := Config.FASES.size()
	var p := {
		"liberada": cfg.get_value(dif_id, "liberada", 0),   # índice da maior fase liberada
		# Saves antigos guardavam isso por bag: se ainda não existe a seção "moto", aproveita o da bag
		"dinheiro": cfg.get_value("moto", "dinheiro", cfg.get_value(dif_id, "dinheiro", 0)),
		"niveis": cfg.get_value("moto", "niveis", cfg.get_value(dif_id, "niveis", {})),
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
		if chave in DA_MOTO:
			cfg.set_value("moto", chave, p[chave])
			if cfg.has_section_key(dif_id, chave):
				cfg.erase_section_key(dif_id, chave)   # limpa o formato antigo
		else:
			cfg.set_value(dif_id, chave, p[chave])
	cfg.set_value("save", "atualizado", int(Time.get_unix_time_from_system()))
	cfg.save(caminho)


## A campanha da bag foi fechada (venceu a última fase)?
static func campanha_fechada(dif_id: String) -> bool:
	var p := carregar(dif_id)
	return p.recordes[Config.FASES.size() - 1] > 0


## Cutscenes já vistas: "abertura_facil", "fase_medio_2"... (ficam na seção "geral")
static func visto(chave: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	return cfg.get_value("geral", "visto_" + chave, false)


static func marcar_visto(chave: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	cfg.set_value("geral", "visto_" + chave, true)
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
