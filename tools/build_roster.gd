extends SceneTree
## Authoring tool: (re)writes the 8 starter troops to res://src/data/troops/*.tres.
## The .tres files are the source of truth afterwards; re-running this overwrites Inspector edits.
## Run: godot --headless -s res://tools/build_roster.gd

const OUT_DIR: String = "res://src/data/troops/"
const K = CombatTypes.EffectKind
const T = CombatTypes.TargetType
const ET = CombatTypes.EffectTarget
const ST = CombatTypes.Stat
const OD = CombatTypes.OverdriveKind
const TR = CombatTypes.Trigger
const A = CombatTypes.Archetype


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var written: int = 0
	for troop in _roster():
		var err: Error = ResourceSaver.save(troop, OUT_DIR + String(troop.troop_id) + ".tres")
		if err != OK:
			push_error("Failed to save %s: %s" % [troop.troop_id, error_string(err)])
			quit(1)
			return
		written += 1
	print("build_roster: wrote %d troops to %s" % [written, OUT_DIR])
	quit(0)


func _fx(kind: int, target: int, magnitude: float, duration: int = 0, chance: float = 1.0, stat: int = ST.ATTACK) -> EffectData:
	var e: EffectData = EffectData.new()
	e.kind = kind
	e.target = target
	e.magnitude = magnitude
	e.duration = duration
	e.chance = chance
	e.stat = stat
	return e


func _skill(name: String, desc: String, slot: int, target_type: int, cooldown: int, props: Dictionary, effects: Array[EffectData] = []) -> SkillData:
	var s: SkillData = SkillData.new()
	s.skill_name = name
	s.description = desc.replace("% ATK", "% SPA") if props.get("special", false) else desc
	s.slot = slot
	s.target_type = target_type
	s.cooldown = cooldown
	s.effects = effects
	for key: String in props:
		s.set(key, props[key])
	return s


func _s1(name: String, desc: String, props: Dictionary, effects: Array[EffectData] = []) -> SkillData:
	var merged: Dictionary = {"energy_gain": 1, "dual_attack_chance": 0.05}
	merged.merge(props, true)
	return _skill(name, desc, CombatTypes.SkillSlot.S1, T.SINGLE_ENEMY, 0, merged, effects)


func _passive(name: String, desc: String, trigger: int, icd: int, target_type: int, effects: Array[EffectData]) -> SkillData:
	return _skill(name, desc, CombatTypes.SkillSlot.S2, target_type, icd, {"is_passive": true, "trigger": trigger}, effects)


func _troop(id: String, name: String, archetype: int, stats: Array, skills: Array[SkillData]) -> TroopData:
	var t: TroopData = TroopData.new()
	t.troop_id = StringName(id)
	t.display_name = name
	t.archetype = archetype
	t.max_hp = int(stats[0])
	t.attack = int(stats[1])
	t.special_attack = int(stats[2])
	t.defense = int(stats[3])
	t.special_defense = int(stats[4])
	t.speed = int(stats[5])
	t.crit_chance = stats[6]
	t.crit_damage = stats[7]
	t.effectiveness = stats[8]
	t.skills = skills
	return t


## stats: [hp, atk, spa, def, spd, spe, crit, crit_dmg, eff]
func _roster() -> Array[TroopData]:
	var roster: Array[TroopData] = []

	# ---------------- Aggro / Cleave ----------------
	roster.append(_troop("ember_duelist", "Ember Duelist", A.AGGRO, [820, 172, 110, 80, 78, 114, 0.2, 1.5, 0.0], [
		_s1("Flicker Slash", "Strike one enemy (100% ATK).", {"attack_scaling": 1.0}),
		_skill("Blade Rush", "Strike one enemy (130% ATK) and gain +20% SPE for 2 turns.", 1, T.SINGLE_ENEMY, 2,
			{"attack_scaling": 1.3}, [_fx(K.STAT_MOD, ET.SELF, 0.2, 2, 1.0, ST.SPEED)]),
		_skill("Inferno Edge", "Strike one enemy (210% ATK, +30% vs debuffed) and Burn it for 2 turns.\nOverdrive (15): act first this round.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 2.1, "bonus_vs_debuffed": 0.3, "overdrive_kind": OD.ACT_FIRST, "overdrive_cost": 15},
			[_fx(K.DOT, ET.SKILL_TARGETS, 0.25, 2)]),
	]))
	roster.append(_troop("storm_lancer", "Storm Lancer", A.AGGRO, [900, 120, 185, 95, 90, 112, 0.2, 1.5, 0.2], [
		_s1("Arc Thrust", "Strike one enemy (100% ATK); 25% chance to lower DEF for 2 turns.", {"special": true, "attack_scaling": 1.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.25, ST.DEFENSE)]),
		_skill("Chain Spark", "Hit all enemies (75% ATK); 60% chance to lower DEF by 25% for 2 turns.", 1, T.ALL_ENEMIES, 3,
			{"special": true, "attack_scaling": 0.75}, [_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.6, ST.DEFENSE)]),
		_skill("Tempest Break", "Hit all enemies (120% ATK).\nOverdrive (10): +40% damage.", 2, T.ALL_ENEMIES, 5,
			{"special": true, "attack_scaling": 1.2, "overdrive_kind": OD.BONUS_DAMAGE, "overdrive_cost": 10, "overdrive_value": 0.4}),
	]))

	# ---------------- Control / Disruption ----------------
	roster.append(_troop("hex_weaver", "Hex Weaver", A.CONTROL, [960, 100, 182, 95, 112, 114, 0.1, 1.5, 0.45], [
		_s1("Hex Bolt", "Strike one enemy (100% ATK); 35% chance to lower ATK by 25% for 2 turns.", {"special": true, "attack_scaling": 1.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.35, ST.ATTACK)]),
		_skill("Binding Sigil", "Strike one enemy (80% ATK); 50% chance to Stun for 1 turn.", 1, T.SINGLE_ENEMY, 3,
			{"special": true, "attack_scaling": 0.8}, [_fx(K.STUN, ET.SKILL_TARGETS, 0.0, 1, 0.5)]),
		_skill("Unravel", "Hit all enemies (70% ATK) and lower their SPE by 20% for 2 turns.\nOverdrive (10): all effects are guaranteed.", 2, T.ALL_ENEMIES, 4,
			{"special": true, "attack_scaling": 0.7, "overdrive_kind": OD.GUARANTEE_EFFECTS, "overdrive_cost": 10},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 1.0, ST.SPEED)]),
	]))
	roster.append(_troop("frost_warden", "Frost Warden", A.CONTROL, [1070, 100, 176, 120, 130, 106, 0.1, 1.5, 0.4], [
		_s1("Rime Strike", "Strike one enemy (90% ATK); 60% chance to lower its SPE by 15% for 1 turn.", {"special": true, "attack_scaling": 0.9},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.15, 1, 0.6, ST.SPEED)]),
		_passive("Permafrost Heart", "Passive: when debuffed, cleanse own debuffs and gain +15% SPE for 2 turns (3-turn internal cooldown).",
			TR.ON_DEBUFF_RECEIVED, 3, T.SELF, [_fx(K.CLEANSE, ET.SELF, 0.0), _fx(K.STAT_MOD, ET.SELF, 0.15, 2, 1.0, ST.SPEED)]),
		_skill("Glacial Prison", "Hit all enemies (85% ATK); 80% chance to lower SPE by 25% for 2 turns.\nOverdrive (10): cooldown -2.", 2, T.ALL_ENEMIES, 5,
			{"special": true, "attack_scaling": 0.85, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 10, "overdrive_value": 2.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.8, ST.SPEED)]),
	]))

	# ---------------- Bruiser / Turn-2 ----------------
	roster.append(_troop("iron_bastion", "Iron Bastion", A.BRUISER, [1130, 122, 80, 128, 92, 95, 0.05, 1.5, 0.0], [
		_s1("Shield Bash", "Strike one enemy (50% ATK + 5% max HP).", {"attack_scaling": 0.5, "hp_scaling": 0.05}),
		_passive("Bulwark Instinct", "Passive: when the partner is hit, shield it for 10% of Bastion's max HP for 2 turns (2-turn internal cooldown).",
			TR.ON_ALLY_HIT, 2, T.SINGLE_ALLY, [_fx(K.SHIELD, ET.SKILL_TARGETS, 0.10, 2)]),
		_skill("Earthshaker", "Hit all enemies (40% ATK + 8% max HP, up to +50% at low HP) and raise own DEF by 30% for 2 turns.\nOverdrive (10): +50% damage.", 2, T.ALL_ENEMIES, 4,
			{"attack_scaling": 0.4, "hp_scaling": 0.08, "missing_hp_bonus": 0.65, "overdrive_kind": OD.BONUS_DAMAGE, "overdrive_cost": 10, "overdrive_value": 0.5},
			[_fx(K.STAT_MOD, ET.SELF, 0.3, 2, 1.0, ST.DEFENSE)]),
	]))
	roster.append(_troop("blood_reaver", "Blood Reaver", A.BRUISER, [950, 140, 80, 95, 80, 100, 0.15, 1.6, 0.0], [
		_s1("Rending Cleave", "Strike one enemy (100% ATK, up to +30% at low HP).", {"attack_scaling": 1.0, "missing_hp_bonus": 0.3}),
		_skill("Rally Cry", "Raise ATK of both allies by 30% for 2 turns and the partner's SPE by 15%.", 1, T.ALL_ALLIES, 3,
			{}, [_fx(K.STAT_MOD, ET.ALLIES, 0.3, 2, 1.0, ST.ATTACK), _fx(K.STAT_MOD, ET.PARTNER, 0.15, 2, 1.0, ST.SPEED)]),
		_skill("Crimson Execution", "Strike one enemy (190% ATK, up to +65% at low HP, +20% vs debuffed) and heal 12% max HP.\nOverdrive (10): cooldown -2.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 1.9, "missing_hp_bonus": 0.65, "bonus_vs_debuffed": 0.2, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 10, "overdrive_value": 2.0},
			[_fx(K.HEAL, ET.SELF, 0.12)]),
	]))

	# ---------------- Pivot / Switch-Synergy ----------------
	roster.append(_troop("swift_courier", "Swift Courier", A.PIVOT, [940, 190, 90, 95, 85, 120, 0.15, 1.5, 0.2], [
		_s1("Quick Jab", "Strike one enemy (95% ATK). Generates 2 Team Energy.", {"attack_scaling": 0.95, "energy_gain": 2}),
		_passive("Slipstream Entry", "Passive: on switch-in, gain +20% SPE for 2 turns and 2 Team Energy (2-turn internal cooldown).",
			TR.ON_SWITCH_IN, 2, T.SELF, [_fx(K.STAT_MOD, ET.SELF, 0.2, 2, 1.0, ST.SPEED), _fx(K.ENERGY, ET.SELF, 2.0)]),
		_skill("Relay Strike", "Strike one enemy (140% ATK), raise the partner's SPE by 20% for 2 turns, then switch out with a benched troop.\nOverdrive (8): cooldown -2.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 1.4, "self_switch_after": true, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 8, "overdrive_value": 2.0},
			[_fx(K.STAT_MOD, ET.PARTNER, 0.2, 2, 1.0, ST.SPEED)]),
	]))
	roster.append(_troop("grove_keeper", "Grove Keeper", A.PIVOT, [980, 90, 135, 105, 115, 107, 0.05, 1.5, 0.1], [
		_s1("Thorn Lash", "Strike one enemy (85% ATK) and heal the partner for 4% of max HP.", {"special": true, "attack_scaling": 0.85},
			[_fx(K.HEAL, ET.PARTNER, 0.04)]),
		_passive("Verdant Arrival", "Passive: on switch-in, heal both allies 10% of max HP and cleanse their debuffs (3-turn internal cooldown).",
			TR.ON_SWITCH_IN, 3, T.ALL_ALLIES, [_fx(K.HEAL, ET.ALLIES, 0.10), _fx(K.CLEANSE, ET.ALLIES, 0.0)]),
		_skill("Sanctuary Bloom", "Heal both allies 18% max HP, shield them for 12% for 2 turns, raise DEF by 25% for 2 turns.\nOverdrive (10): cooldown -2.", 2, T.ALL_ALLIES, 5,
			{"overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 10, "overdrive_value": 2.0},
			[_fx(K.HEAL, ET.ALLIES, 0.18), _fx(K.SHIELD, ET.ALLIES, 0.12, 2), _fx(K.STAT_MOD, ET.ALLIES, 0.25, 2, 1.0, ST.DEFENSE)]),
	]))
	return roster
