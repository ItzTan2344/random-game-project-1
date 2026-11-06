class_name TroopRegistry
extends RefCounted
## Loads the starter roster (.tres) and builds the default 6-troop squads.

const TROOP_DIR: String = "res://src/data/troops/"
const SQUAD_A: Array[StringName] = [&"ember_duelist", &"hex_weaver", &"iron_bastion", &"swift_courier", &"storm_lancer", &"grove_keeper"]
const SQUAD_B: Array[StringName] = [&"frost_warden", &"blood_reaver", &"grove_keeper", &"storm_lancer", &"iron_bastion", &"swift_courier"]


static func load_all() -> Dictionary[StringName, TroopData]:
	var out: Dictionary[StringName, TroopData] = {}
	for file in DirAccess.get_files_at(TROOP_DIR):
		var name: String = file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var troop: TroopData = load(TROOP_DIR + name) as TroopData
		if troop != null:
			out[troop.troop_id] = troop
	return out


static func build_squad(ids: Array[StringName]) -> Array[TroopData]:
	var all: Dictionary[StringName, TroopData] = load_all()
	var squad: Array[TroopData] = []
	for id in ids:
		if all.has(id):
			squad.append(all[id])
		else:
			push_error("TroopRegistry: unknown troop id '%s'" % id)
	return squad


static func default_squad(side: int) -> Array[TroopData]:
	return build_squad(SQUAD_A if side == CombatTypes.Side.A else SQUAD_B)
