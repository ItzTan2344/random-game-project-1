class_name CombatAction
extends RefCounted
## Client intent: cast a skill or switch. Validated by CombatEngine before anything happens.

var kind: CombatTypes.ActionKind = CombatTypes.ActionKind.SKILL
var skill_index: int = 0
var target_uid: int = -1
## SWITCH: bench to swap in. Self-switch skills: optional bench choice (-1 = first ready).
var bench_index: int = -1
var overdrive: bool = false


static func cast(index: int, target: int = -1, use_overdrive: bool = false, bench: int = -1) -> CombatAction:
	var a: CombatAction = CombatAction.new()
	a.kind = CombatTypes.ActionKind.SKILL
	a.skill_index = index
	a.target_uid = target
	a.overdrive = use_overdrive
	a.bench_index = bench
	return a


static func switch_to(bench: int) -> CombatAction:
	var a: CombatAction = CombatAction.new()
	a.kind = CombatTypes.ActionKind.SWITCH
	a.bench_index = bench
	return a


func to_dict() -> Dictionary:
	return {"kind": kind, "skill_index": skill_index, "target_uid": target_uid, "bench_index": bench_index, "overdrive": overdrive}


static func from_dict(d: Dictionary) -> CombatAction:
	var a: CombatAction = CombatAction.new()
	a.kind = int(d.get("kind", 0)) as CombatTypes.ActionKind
	a.skill_index = int(d.get("skill_index", 0))
	a.target_uid = int(d.get("target_uid", -1))
	a.bench_index = int(d.get("bench_index", -1))
	a.overdrive = bool(d.get("overdrive", false))
	return a
