class_name EffectData
extends Resource
## One status/utility effect attached to a skill. Static template: never mutated at runtime.

@export var kind: CombatTypes.EffectKind = CombatTypes.EffectKind.STAT_MOD
@export var target: CombatTypes.EffectTarget = CombatTypes.EffectTarget.SKILL_TARGETS
@export var stat: CombatTypes.Stat = CombatTypes.Stat.ATTACK
## STAT_MOD: fraction (+0.2 = +20%). DOT: fraction of caster ATK per tick.
## SHIELD/HEAL: fraction of caster max HP. CR_CHANGE: CR points. ENERGY: Team Energy points.
@export var magnitude: float = 0.0
## Turns the effect lasts (STAT_MOD, STUN, DOT, SHIELD).
@export var duration: int = 0
## Base proc chance, rolled before the Effectiveness vs Effect Resistance check.
@export_range(0.0, 1.0) var chance: float = 1.0


func is_debuff() -> bool:
	if kind == CombatTypes.EffectKind.STUN or kind == CombatTypes.EffectKind.DOT:
		return true
	if kind == CombatTypes.EffectKind.STAT_MOD or kind == CombatTypes.EffectKind.CR_CHANGE:
		return magnitude < 0.0
	return false
