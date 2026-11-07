class_name ArchetypeRegistry
extends RefCounted
## Loads every archetype .tres in DIR. Never list archetype ids in code.

const DIR: String = "res://src/data/archetypes/"


static func load_all() -> Dictionary[StringName, ArchetypeData]:
	var out: Dictionary[StringName, ArchetypeData] = {}
	for file in DirAccess.get_files_at(DIR):
		var name: String = file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var a: ArchetypeData = load(DIR + name) as ArchetypeData
		if a != null:
			out[a.archetype_id] = a
	return out


static var _cache: Dictionary[StringName, ArchetypeData] = {}


## Cached lookup for UI; null for an empty or unknown id.
static func find(id: StringName) -> ArchetypeData:
	if _cache.is_empty():
		_cache = load_all()
	return _cache.get(id) as ArchetypeData
