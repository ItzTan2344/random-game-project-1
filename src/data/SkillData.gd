class_name SkillData
extends Resource
## Static skill template (S1/S2/S3). Active skills are cast; passives fire on `trigger`.

@export var skill_name: String = ""
@export_multiline var description: String = ""
@export var slot: CombatTypes.SkillSlot = CombatTypes.SkillSlot.S1
@export var is_passive: bool = false
@export var trigger: CombatTypes.Trigger = CombatTypes.Trigger.NONE
## Turns before reuse. For passives this is the internal cooldown.
@export var cooldown: int = 0
@export var target_type: CombatTypes.TargetType = CombatTypes.TargetType.SINGLE_ENEMY

@export_group("Damage")
## Special skills use SPA vs the target's SPD; otherwise ATK vs DEF. `attack_scaling` scales whichever applies.
@export var special: bool = false
@export var attack_scaling: float = 0.0
@export var hp_scaling: float = 0.0
## Extra damage multiplier at 100% missing caster HP (scales linearly).
@export var missing_hp_bonus: float = 0.0
## Extra damage multiplier against a target that has any debuff.
@export var bonus_vs_debuffed: float = 0.0

@export_group("Utility")
@export var effects: Array[EffectData] = []
@export var energy_gain: int = 0
## S1 only. Engine clamps to CombatTypes.DUAL_ATTACK_CAP.
@export_range(0.0, 0.05) var dual_attack_chance: float = 0.0
## Pivot: after resolving, the caster swaps with a benched troop (no switch cooldown).
@export var self_switch_after: bool = false

@export_group("Overdrive")
@export var overdrive_kind: CombatTypes.OverdriveKind = CombatTypes.OverdriveKind.NONE
@export var overdrive_cost: int = 0
## BONUS_DAMAGE: added multiplier. REDUCE_COOLDOWN: turns removed.
@export var overdrive_value: float = 0.0


func deals_damage() -> bool:
	return attack_scaling > 0.0 or hp_scaling > 0.0


func needs_target() -> bool:
	return target_type == CombatTypes.TargetType.SINGLE_ENEMY or target_type == CombatTypes.TargetType.SINGLE_ALLY


func to_summary() -> Dictionary:
	return {
		"name": skill_name,
		"description": description,
		"slot": slot,
		"passive": is_passive,
		"cooldown": cooldown,
		"special": special,
		"target_type": target_type,
		"overdrive_kind": overdrive_kind,
		"overdrive_cost": overdrive_cost,
	}
