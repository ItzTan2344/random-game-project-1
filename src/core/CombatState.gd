class_name CombatState
extends RefCounted
## Entire authoritative match state. Owned and mutated only by CombatEngine.

var phase: CombatTypes.Phase = CombatTypes.Phase.PREVIEW
var teams: Array[TeamState] = []
var troops: Dictionary[int, TroopInstance] = {}
## Round counter (the frenzy 'cycle').
var cycle: int = 1
## Actions executed so far.
var turn_count: int = 0
## Whoever acted last (decides a simultaneous wipe).
var last_actor: TroopInstance = null
var winner: int = -1


func _init() -> void:
	teams = [TeamState.new(CombatTypes.Side.A), TeamState.new(CombatTypes.Side.B)]


func team(side: int) -> TeamState:
	return teams[side]


func get_troop(uid: int) -> TroopInstance:
	return troops.get(uid) as TroopInstance


func actives(side: int) -> Array[TroopInstance]:
	return teams[side].living_actives()


func all_actives() -> Array[TroopInstance]:
	var out: Array[TroopInstance] = actives(CombatTypes.Side.A)
	out.append_array(actives(CombatTypes.Side.B))
	return out


func is_active(troop: TroopInstance) -> bool:
	return troop != null and troop.is_alive() and teams[troop.side].active.has(troop)


func partner(troop: TroopInstance) -> TroopInstance:
	for t in actives(troop.side):
		if t != troop:
			return t
	return null


func frenzy_stacks() -> int:
	return CombatMath.frenzy_stacks(cycle)
