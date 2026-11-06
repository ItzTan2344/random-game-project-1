class_name CombatMath
extends RefCounted
## Pure, stateless combat formulas. RNG rolls happen in CombatEngine, not here.


## Time units until `cr` reaches 100 at `speed` CR/time-unit.
static func time_to_full(cr: float, speed: float) -> float:
	if speed <= 0.0:
		return INF
	return maxf(0.0, CombatTypes.CR_MAX - cr) / speed


## Deterministic Effectiveness vs Effect Resistance curve (no innate absolute resist).
static func hit_chance(effectiveness: float, effect_resistance: float) -> float:
	return clampf(1.0 + effectiveness - effect_resistance, 0.0, 1.0)


static func mitigation(defense: float) -> float:
	return 1.0 / (1.0 + maxf(defense, 0.0) / CombatTypes.DEFENSE_CONSTANT)


static func raw_damage(attack: float, caster_max_hp: int, skill: SkillData, caster_missing_ratio: float) -> float:
	var base: float = attack * skill.attack_scaling + float(caster_max_hp) * skill.hp_scaling
	return base * (1.0 + skill.missing_hp_bonus * clampf(caster_missing_ratio, 0.0, 1.0))


static func final_damage(raw: float, defense: float, crit: bool, crit_damage: float, multiplier: float) -> int:
	var dmg: float = raw * mitigation(defense) * multiplier
	if crit:
		dmg *= crit_damage
	return maxi(1, roundi(dmg))


static func clamp_cr_push(amount: float) -> float:
	return clampf(amount, -CombatTypes.MAX_CR_PUSH, CombatTypes.MAX_CR_PUSH)


static func cycle_at(timeline_time: float) -> int:
	return maxi(1, ceili(timeline_time * CombatTypes.CYCLE_BASE_SPEED / CombatTypes.CR_MAX - CombatTypes.EPSILON))


static func frenzy_stacks(cycle: int) -> int:
	return maxi(0, cycle - CombatTypes.FRENZY_START_CYCLE)


static func frenzy_damage_mult(cycle: int) -> float:
	return 1.0 + CombatTypes.FRENZY_STEP * float(frenzy_stacks(cycle))


static func frenzy_heal_mult(cycle: int) -> float:
	return maxf(0.0, 1.0 - CombatTypes.FRENZY_STEP * float(frenzy_stacks(cycle)))
