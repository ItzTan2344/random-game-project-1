class_name TroopData
extends Resource
## Static troop template. Runtime state lives in TroopInstance; this is never mutated in battle.

@export var troop_id: StringName = &""
@export var display_name: String = ""
@export var archetype: CombatTypes.Archetype = CombatTypes.Archetype.AGGRO
@export var max_hp: int = 1000
## Physical attack / defense (ATK, DEF) and special attack / defense (SPA, SPD). Speed is SPE.
@export var attack: int = 150
@export var special_attack: int = 150
@export var defense: int = 100
@export var special_defense: int = 100
@export var speed: int = 100
@export_range(0.0, 1.0) var crit_chance: float = 0.15
@export var crit_damage: float = 1.5
## EFF: scales the proc chance of every skill effect (chance x (1 + EFF)).
@export var effectiveness: float = 0.0
## Exactly three: S1, S2, S3.
@export var skills: Array[SkillData] = []


func to_summary() -> Dictionary:
	var skill_list: Array[Dictionary] = []
	for s in skills:
		skill_list.append(s.to_summary())
	return {
		"troop_id": String(troop_id),
		"name": display_name,
		"archetype": archetype,
		"max_hp": max_hp,
		"attack": attack,
		"special_attack": special_attack,
		"defense": defense,
		"special_defense": special_defense,
		"effectiveness": effectiveness,
		"speed": speed,
		"skills": skill_list,
	}
