class_name TroopRegistry
extends RefCounted
## Loads the roster from every .tres in TROOP_DIR. Never list troop ids in code: new troops are picked up by dropping a .tres in.

const TROOP_DIR: String = "res://src/data/troops/"


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


## Sorted by id so a seed always gives the same squad.
static func sorted_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(load_all().keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Random squad of DRAFT_BRING distinct troops (AI opponents, autoplay, tests). Deterministic per seed.
static func random_squad(seed_value: int) -> Array[TroopData]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[StringName] = sorted_ids()
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: StringName = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	return build_squad(ids.slice(0, CombatTypes.DRAFT_BRING))
