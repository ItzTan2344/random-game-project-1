class_name TeamState
extends RefCounted
## One side: the brought squad, draft picks, field slots, bench, and shared Team Energy.

var side: int = 0
var squad: Array[TroopData] = []
var picks: Array[int] = []
var locked: bool = false
## Size ACTIVE_SLOTS. A KO'd troop stays in its slot until Standby replaces it.
var active: Array[TroopInstance] = []
var bench: Array[TroopInstance] = []
var energy: int = 0
var slot_switch_cd: Array[int] = [0, 0]
## Field slots waiting for a Standby replacement.
var pending_slots: Array[int] = []
## This round's chosen actions (troop uid -> CombatAction); `actions_locked` once submitted.
var actions: Dictionary = {}
var actions_locked: bool = false


func _init(p_side: int) -> void:
	side = p_side


func living_actives() -> Array[TroopInstance]:
	var out: Array[TroopInstance] = []
	for t in active:
		if t != null and t.is_alive():
			out.append(t)
	return out


func slot_of(troop: TroopInstance) -> int:
	return active.find(troop)


func is_bench_ready(index: int) -> bool:
	return index >= 0 and index < bench.size() and bench[index] != null and bench[index].is_alive()


func ready_bench_indices() -> Array[int]:
	var out: Array[int] = []
	for i in bench.size():
		if is_bench_ready(i):
			out.append(i)
	return out


func first_ready_bench() -> int:
	var ready: Array[int] = ready_bench_indices()
	return ready[0] if not ready.is_empty() else -1


func is_wiped() -> bool:
	if active.is_empty():
		return false
	for t in active:
		if t != null and t.is_alive():
			return false
	return ready_bench_indices().is_empty()
