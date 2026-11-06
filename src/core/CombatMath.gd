class_name CombatMath
extends RefCounted
## Pure, stateless combat formulas. RNG rolls happen in CombatEngine, not here.


## Effect proc chance: base chance scaled by Effectiveness (+EFF = +EFF x 100% relative), capped at 100%.
static func effect_chance(base: float, effectiveness: float) -> float:
	return clampf(base * (1.0 + maxf(effectiveness, 0.0)), 0.0, 1.0)


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


static func frenzy_stacks(cycle: int) -> int:
	return maxi(0, cycle - CombatTypes.FRENZY_START_CYCLE)


static func frenzy_damage_mult(cycle: int) -> float:
	return 1.0 + CombatTypes.FRENZY_STEP * float(frenzy_stacks(cycle))


static func frenzy_heal_mult(cycle: int) -> float:
	return maxf(0.0, 1.0 - CombatTypes.FRENZY_STEP * float(frenzy_stacks(cycle)))
