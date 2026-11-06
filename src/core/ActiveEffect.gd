class_name ActiveEffect
extends RefCounted
## A live buff/debuff on a TroopInstance, materialised from an EffectData template.

var kind: CombatTypes.EffectKind = CombatTypes.EffectKind.STAT_MOD
var stat: CombatTypes.Stat = CombatTypes.Stat.ATTACK
var magnitude: float = 0.0
var remaining: int = 0
## DOT damage per tick, or remaining SHIELD points.
var value: int = 0
var source_uid: int = -1
## Turn number it was applied on; effects don't tick at the end of that same turn.
var applied_turn: int = 0


func _init(p_kind: CombatTypes.EffectKind, p_stat: CombatTypes.Stat, p_magnitude: float, p_remaining: int, p_value: int, p_source_uid: int, p_applied_turn: int) -> void:
	kind = p_kind
	stat = p_stat
	magnitude = p_magnitude
	remaining = p_remaining
	value = p_value
	source_uid = p_source_uid
	applied_turn = p_applied_turn


func is_debuff() -> bool:
	if kind == CombatTypes.EffectKind.STUN or kind == CombatTypes.EffectKind.DOT:
		return true
	return kind == CombatTypes.EffectKind.STAT_MOD and magnitude < 0.0


func to_dict() -> Dictionary:
	return {"kind": kind, "stat": stat, "magnitude": magnitude, "remaining": remaining, "value": value, "debuff": is_debuff()}
