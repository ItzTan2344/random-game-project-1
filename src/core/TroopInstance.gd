class_name TroopInstance
extends RefCounted
## Mutable per-match troop state. Reads stats from its TroopData template, never writes to it.

var uid: int = 0
var data: TroopData
var side: int = 0
var hp: int = 0
var cr: float = 0.0
var cooldowns: Array[int] = []
var passive_icd: int = 0
var effects: Array[ActiveEffect] = []
## Set once the troop has been on the field (the opponent can see it).
var revealed: bool = false


func _init(p_uid: int, p_data: TroopData, p_side: int) -> void:
	uid = p_uid
	data = p_data
	side = p_side
	hp = p_data.max_hp
	for i in p_data.skills.size():
		cooldowns.append(0)


func max_hp() -> int:
	return data.max_hp


func is_alive() -> bool:
	return hp > 0


func hp_ratio() -> float:
	return float(hp) / float(max_hp())


func base_stat(stat: CombatTypes.Stat) -> float:
	match stat:
		CombatTypes.Stat.ATTACK:
			return float(data.attack)
		CombatTypes.Stat.DEFENSE:
			return float(data.defense)
		CombatTypes.Stat.SPEED:
			return float(data.speed)
		CombatTypes.Stat.CRIT_CHANCE:
			return data.crit_chance
		CombatTypes.Stat.EFFECTIVENESS:
			return data.effectiveness
		CombatTypes.Stat.EFFECT_RESISTANCE:
			return data.effect_resistance
	return 0.0


func stat_modifier(stat: CombatTypes.Stat) -> float:
	var total: float = 0.0
	for e in effects:
		if e.kind == CombatTypes.EffectKind.STAT_MOD and e.stat == stat:
			total += e.magnitude
	var cap: float = CombatTypes.MAX_SPEED_BUFF if stat == CombatTypes.Stat.SPEED else CombatTypes.STAT_MOD_MAX
	return clampf(total, CombatTypes.STAT_MOD_MIN, cap)


## ATK/DEF/SPD modifiers are multiplicative; chance stats are flat additive.
func get_stat(stat: CombatTypes.Stat) -> float:
	var mod: float = stat_modifier(stat)
	if stat == CombatTypes.Stat.ATTACK or stat == CombatTypes.Stat.DEFENSE or stat == CombatTypes.Stat.SPEED:
		return base_stat(stat) * (1.0 + mod)
	return base_stat(stat) + mod


func shield() -> int:
	var total: int = 0
	for e in effects:
		if e.kind == CombatTypes.EffectKind.SHIELD:
			total += e.value
	return total


## Drains shields first; returns the amount absorbed.
func absorb_shield(amount: int) -> int:
	var remaining_dmg: int = amount
	for i in range(effects.size() - 1, -1, -1):
		var e: ActiveEffect = effects[i]
		if e.kind != CombatTypes.EffectKind.SHIELD or remaining_dmg <= 0:
			continue
		var take: int = mini(e.value, remaining_dmg)
		e.value -= take
		remaining_dmg -= take
		if e.value <= 0:
			effects.remove_at(i)
	return amount - remaining_dmg


func find_effect(kind: CombatTypes.EffectKind, stat: CombatTypes.Stat, debuff: bool) -> ActiveEffect:
	for e in effects:
		if e.kind == kind and e.is_debuff() == debuff and (kind != CombatTypes.EffectKind.STAT_MOD or e.stat == stat):
			return e
	return null


func is_stunned() -> bool:
	for e in effects:
		if e.kind == CombatTypes.EffectKind.STUN:
			return true
	return false


func has_debuff() -> bool:
	for e in effects:
		if e.is_debuff():
			return true
	return false


## Removes debuffs. `stat_only` limits it to stat-stage debuffs (switch-in rule).
func cleanse(stat_only: bool) -> int:
	var removed: int = 0
	for i in range(effects.size() - 1, -1, -1):
		var e: ActiveEffect = effects[i]
		if e.is_debuff() and (not stat_only or e.kind == CombatTypes.EffectKind.STAT_MOD):
			effects.remove_at(i)
			removed += 1
	return removed


func tick_cooldowns() -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxi(0, cooldowns[i] - 1)
	passive_icd = maxi(0, passive_icd - 1)


## Decrements durations at the owner's turn end; returns expired effects.
func tick_effects(current_turn: int) -> Array[ActiveEffect]:
	var expired: Array[ActiveEffect] = []
	for i in range(effects.size() - 1, -1, -1):
		var e: ActiveEffect = effects[i]
		if e.applied_turn == current_turn:
			continue
		e.remaining -= 1
		if e.remaining <= 0:
			expired.append(e)
			effects.remove_at(i)
	return expired


func to_snapshot() -> Dictionary:
	var fx: Array[Dictionary] = []
	for e in effects:
		fx.append(e.to_dict())
	return {
		"uid": uid,
		"troop_id": String(data.troop_id),
		"name": data.display_name,
		"side": side,
		"archetype": data.archetype,
		"hp": hp,
		"max_hp": max_hp(),
		"shield": shield(),
		"cr": cr,
		"speed": get_stat(CombatTypes.Stat.SPEED),
		"cooldowns": cooldowns.duplicate(),
		"passive_icd": passive_icd,
		"alive": is_alive(),
		"effects": fx,
	}
