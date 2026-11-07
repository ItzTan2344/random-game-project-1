extends SceneTree
## Authoring tool: (re)writes the roster to res://src/data/troops/*.tres.
## The .tres files are the source of truth afterwards; re-running this overwrites Inspector edits.
## Run: godot --headless -s res://tools/build_roster.gd

const OUT_DIR: String = "res://src/data/troops/"
const ARCH_DIR: String = "res://src/data/archetypes/"
const K = CombatTypes.EffectKind
const T = CombatTypes.TargetType
const ET = CombatTypes.EffectTarget
const ST = CombatTypes.Stat
const OD = CombatTypes.OverdriveKind
const TR = CombatTypes.Trigger
const A = CombatTypes.Role


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARCH_DIR))
	for a in _archetypes():
		var aerr: Error = ResourceSaver.save(a, ARCH_DIR + String(a.archetype_id) + ".tres")
		if aerr != OK:
			push_error("Failed to save archetype %s: %s" % [a.archetype_id, error_string(aerr)])
			quit(1)
			return
	print("build_roster: wrote archetypes to %s" % ARCH_DIR)
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


func _troop(id: String, name: String, archetype: StringName, role: int, stats: Array, skills: Array[SkillData]) -> TroopData:
	var t: TroopData = TroopData.new()
	t.troop_id = StringName(id)
	t.display_name = name
	t.archetype = archetype
	t.role = role
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


func _arch(id: String, name: String, color: String, dark: String, light: String, tagline: String, emblem: Array[String], frame: int, pattern: StringName, desc: String, stat: int, amount: float) -> ArchetypeData:
	var a: ArchetypeData = ArchetypeData.new()
	a.archetype_id = StringName(id)
	a.display_name = name
	a.color = Color(color)
	a.color_dark = Color(dark)
	a.color_light = Color(light)
	a.tagline = tagline
	a.emblem = PackedStringArray(emblem)
	a.frame_width = frame
	a.pattern = pattern
	a.description = desc
	a.synergy = [_fx(K.STAT_MOD, ET.SELF, amount, 0, 1.0, stat)]
	return a


## Field synergy while both active troops share the archetype. Placeholder stat bonuses; the card look is final-ish.
func _archetypes() -> Array[ArchetypeData]:
	return [
		_arch("ember", "Ember", "#e8512e", "#241412", "#f8d05c", "Fan every ember into an inferno; leave nothing unburnt.", ["..1..", "..1..", ".111.", ".111.", "11111", "11111", "22222"], 2, &"embers", "Both active troops: +10% ATK.", ST.ATTACK, 0.1),
		_arch("tide", "Tide", "#2f7bff", "#0f2142", "#cfe8ff", "The tide does not strike; it drowns, chills, and recedes at will.", ["...11", "..111", ".1111", "11112", "2222.", ".222.", "..2.."], 2, &"waves", "Both active troops: +10% EFF.", ST.EFFECTIVENESS, 0.1),
		_arch("grove", "Grove", "#6bbf59", "#1c281d", "#a9713f", "From poisoned loam to ancient canopy, the wild endures and devours.", ["..1..", ".111.", ".121.", ".111.", "1.1.1", "1.1.1", "11.11"], 2, &"grain", "Both active troops: +10% special defense.", ST.SPECIAL_DEFENSE, 0.1),
		_arch("forge", "Forge", "#a9b6c4", "#22262e", "#c2692b", "Steeled in blast furnaces, grinding forward in clockwork unison.", ["1.1.1", "11111", "11211", "11111", ".111.", "11111", "11111"], 4, &"tread", "Both active troops: +10% DEF.", ST.DEFENSE, 0.1),
		_arch("void", "Void", "#8e4fe0", "#0e0a18", "#e24fb0", "From the unmade dark, we unravel reality.", ["..1..", ".111.", "11011", "10201", "11011", ".111.", "..1.."], 2, &"dust", "Both active troops: +10% crit chance.", ST.CRIT_CHANCE, 0.1),
		_arch("storm", "Storm", "#ffe23a", "#181e29", "#ffffff", "Strike before the thunder sounds, vanish before the rain falls.", ["...11", "..11.", ".11..", "1111.", "..22.", ".22..", "22.."], 1, &"chevrons", "Both active troops: +5% SPE.", ST.SPEED, 0.05),
	]


## stats: [hp, atk, spa, def, spd, spe, crit, crit_dmg, eff]
func _roster() -> Array[TroopData]:
	var roster: Array[TroopData] = []

	# ---------------- Duelist ----------------
	roster.append(_troop("ember_aggro", "Ember Aggro", &"ember", A.DUELIST, [245, 103, 66, 48, 47, 68, 0.2, 1.5, 0.0], [
		_s1("Flicker Slash", "Strike one enemy (100% ATK).", {"attack_scaling": 1.0}),
		_skill("Blade Rush", "Strike one enemy (130% ATK) and gain +20% SPE for 2 turns.", 1, T.SINGLE_ENEMY, 2,
			{"attack_scaling": 1.3}, [_fx(K.STAT_MOD, ET.SELF, 0.2, 2, 1.0, ST.SPEED)]),
		_skill("Inferno Edge", "Strike one enemy (210% ATK, +30% vs debuffed) and Burn it for 2 turns.\nOverdrive (15): act first this round.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 2.1, "bonus_vs_debuffed": 0.3, "overdrive_kind": OD.ACT_FIRST, "overdrive_cost": 15},
			[_fx(K.DOT, ET.SKILL_TARGETS, 0.25, 2)]),
	]))
	roster.append(_troop("storm_lancer", "Storm Lancer", &"storm", A.DUELIST, [270, 72, 111, 57, 54, 67, 0.2, 1.5, 0.2], [
		_s1("Arc Thrust", "Strike one enemy (100% ATK); 25% chance to lower DEF for 2 turns.", {"special": true, "attack_scaling": 1.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.25, ST.DEFENSE)]),
		_skill("Chain Spark", "Hit all enemies (75% ATK); 60% chance to lower DEF by 25% for 2 turns.", 1, T.ALL_ENEMIES, 3,
			{"special": true, "attack_scaling": 0.75}, [_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.6, ST.DEFENSE)]),
		_skill("Tempest Break", "Hit all enemies (120% ATK).\nOverdrive (10): +40% damage.", 2, T.ALL_ENEMIES, 5,
			{"special": true, "attack_scaling": 1.2, "overdrive_kind": OD.BONUS_DAMAGE, "overdrive_cost": 10, "overdrive_value": 0.4}),
	]))

	# ---------------- Controller ----------------
	roster.append(_troop("void_weaver", "Void Weaver", &"void", A.CONTROLLER, [295, 60, 114, 59, 67, 68, 0.1, 1.5, 0.45], [
		_s1("Hex Bolt", "Strike one enemy (100% ATK); 35% chance to lower ATK by 25% for 2 turns.", {"special": true, "attack_scaling": 1.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.35, ST.ATTACK)]),
		_skill("Binding Sigil", "Strike one enemy (80% ATK); 50% chance to Stun for 1 turn.", 1, T.SINGLE_ENEMY, 3,
			{"special": true, "attack_scaling": 0.8}, [_fx(K.STUN, ET.SKILL_TARGETS, 0.0, 1, 0.5)]),
		_skill("Unravel", "Hit all enemies (70% ATK) and lower their SPE by 20% for 2 turns.\nOverdrive (10): all effects are guaranteed.", 2, T.ALL_ENEMIES, 4,
			{"special": true, "attack_scaling": 0.7, "overdrive_kind": OD.GUARANTEE_EFFECTS, "overdrive_cost": 10},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 1.0, ST.SPEED)]),
	]))
	roster.append(_troop("tide_warden", "Tide Warden", &"tide", A.CONTROLLER, [320, 60, 106, 72, 78, 64, 0.1, 1.5, 0.4], [
		_s1("Rime Strike", "Strike one enemy (90% ATK); 60% chance to lower its SPE by 15% for 1 turn.", {"special": true, "attack_scaling": 0.9},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.15, 1, 0.6, ST.SPEED)]),
		_passive("Permafrost Heart", "Passive: when debuffed, cleanse own debuffs and gain +15% SPE for 2 turns (3-turn internal cooldown).",
			TR.ON_DEBUFF_RECEIVED, 3, T.SELF, [_fx(K.CLEANSE, ET.SELF, 0.0), _fx(K.STAT_MOD, ET.SELF, 0.15, 2, 1.0, ST.SPEED)]),
		_skill("Glacial Prison", "Hit all enemies (85% ATK); 80% chance to lower SPE by 25% for 2 turns.\nOverdrive (10): cooldown -2.", 2, T.ALL_ENEMIES, 5,
			{"special": true, "attack_scaling": 0.85, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 10, "overdrive_value": 2.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.8, ST.SPEED)]),
	]))

	# ---------------- Tanker ----------------
	roster.append(_troop("forge_bastion", "Forge Bastion", &"forge", A.TANKER, [340, 73, 48, 77, 55, 57, 0.05, 1.5, 0.0], [
		_s1("Shield Bash", "Strike one enemy (50% ATK + 10% max HP).", {"attack_scaling": 0.5, "hp_scaling": 0.1}),
		_passive("Bulwark Instinct", "Passive: when the partner is hit, shield it for 10% of Bastion's max HP for 2 turns (2-turn internal cooldown).",
			TR.ON_ALLY_HIT, 2, T.SINGLE_ALLY, [_fx(K.SHIELD, ET.SKILL_TARGETS, 0.10, 2)]),
		_skill("Earthshaker", "Hit all enemies (40% ATK + 8% max HP, up to +50% at low HP) and raise own DEF by 30% for 2 turns.\nOverdrive (10): +50% damage.", 2, T.ALL_ENEMIES, 4,
			{"attack_scaling": 0.4, "hp_scaling": 0.16, "missing_hp_bonus": 0.65, "overdrive_kind": OD.BONUS_DAMAGE, "overdrive_cost": 10, "overdrive_value": 0.5},
			[_fx(K.STAT_MOD, ET.SELF, 0.3, 2, 1.0, ST.DEFENSE)]),
	]))
	roster.append(_troop("ember_reaver", "Ember Reaver", &"ember", A.TANKER, [290, 88, 48, 57, 49, 60, 0.15, 1.6, 0.0], [
		_s1("Rending Cleave", "Strike one enemy (100% ATK, up to +30% at low HP).", {"attack_scaling": 1.0, "missing_hp_bonus": 0.3}),
		_skill("Rally Cry", "Raise ATK of both allies by 30% for 2 turns and the partner's SPE by 15%.", 1, T.ALL_ALLIES, 3,
			{}, [_fx(K.STAT_MOD, ET.ALLIES, 0.3, 2, 1.0, ST.ATTACK), _fx(K.STAT_MOD, ET.PARTNER, 0.15, 2, 1.0, ST.SPEED)]),
		_skill("Crimson Execution", "Strike one enemy (190% ATK, up to +65% at low HP, +20% vs debuffed) and heal 12% max HP.\nOverdrive (10): cooldown -2.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 1.9, "missing_hp_bonus": 0.65, "bonus_vs_debuffed": 0.2, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 10, "overdrive_value": 2.0},
			[_fx(K.HEAL, ET.SELF, 0.12)]),
	]))

	# ---------------- Pivot / Switch-Synergy ----------------
	roster.append(_troop("storm_courier", "Storm Courier", &"storm", A.PIVOT, [280, 109, 54, 57, 51, 71, 0.15, 1.5, 0.2], [
		_s1("Quick Jab", "Strike one enemy (95% ATK). Generates 2 Team Energy.", {"attack_scaling": 0.95, "energy_gain": 2}),
		_passive("Slipstream Entry", "Passive: on switch-in, gain +20% SPE for 2 turns and 2 Team Energy (2-turn internal cooldown).",
			TR.ON_SWITCH_IN, 2, T.SELF, [_fx(K.STAT_MOD, ET.SELF, 0.2, 2, 1.0, ST.SPEED), _fx(K.ENERGY, ET.SELF, 2.0)]),
		_skill("Relay Strike", "Strike one enemy (140% ATK), raise the partner's SPE by 20% for 2 turns, then switch out with a benched troop.\nOverdrive (8): cooldown -2.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 1.4, "self_switch_after": true, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 8, "overdrive_value": 2.0},
			[_fx(K.STAT_MOD, ET.PARTNER, 0.2, 2, 1.0, ST.SPEED)]),
	]))
	roster.append(_troop("grove_keeper", "Grove Keeper", &"grove", A.PIVOT, [295, 54, 81, 63, 69, 64, 0.05, 1.5, 0.1], [
		_s1("Thorn Lash", "Strike one enemy (85% ATK) and heal the partner for 4% of max HP.", {"special": true, "attack_scaling": 0.85},
			[_fx(K.HEAL, ET.PARTNER, 0.04)]),
		_passive("Verdant Arrival", "Passive: on switch-in, heal both allies 10% of max HP and cleanse their debuffs (3-turn internal cooldown).",
			TR.ON_SWITCH_IN, 3, T.ALL_ALLIES, [_fx(K.HEAL, ET.ALLIES, 0.10), _fx(K.CLEANSE, ET.ALLIES, 0.0)]),
		_skill("Sanctuary Bloom", "Heal both allies 18% max HP, shield them for 12% for 2 turns, raise DEF by 25% for 2 turns.\nOverdrive (10): cooldown -2.", 2, T.ALL_ALLIES, 5,
			{"overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 10, "overdrive_value": 2.0},
			[_fx(K.HEAL, ET.ALLIES, 0.18), _fx(K.SHIELD, ET.ALLIES, 0.12, 2), _fx(K.STAT_MOD, ET.ALLIES, 0.25, 2, 1.0, ST.DEFENSE)]),
	]))

	# ---------------- Expansion: Duelist ----------------
	roster.append(_troop("ember_ranger", "Ember Ranger", &"ember", A.DUELIST, [260, 107, 54, 51, 48, 70, 0.3, 1.6, 0.0], [
		_s1("Ember Arrow", "Strike one enemy (100% ATK); 30% chance to Burn it for 2 turns.", {"attack_scaling": 1.0},
			[_fx(K.DOT, ET.SKILL_TARGETS, 0.2, 2, 0.3)]),
		_skill("Volley", "Hit all enemies (70% ATK, +25% vs debuffed).", 1, T.ALL_ENEMIES, 3,
			{"attack_scaling": 0.7, "bonus_vs_debuffed": 0.25}),
		_skill("Piercing Shot", "Strike one enemy (220% ATK).\nOverdrive (15): act first this round.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 2.2, "overdrive_kind": OD.ACT_FIRST, "overdrive_cost": 15}),
	]))
	roster.append(_troop("void_arcanist", "Void Arcanist", &"void", A.DUELIST, [250, 54, 117, 48, 57, 66, 0.15, 1.5, 0.1], [
		_s1("Void Bolt", "Strike one enemy (100% ATK).", {"special": true, "attack_scaling": 1.0}),
		_skill("Null Rift", "Strike one enemy (140% ATK); 70% chance to lower its SPD by 25% for 2 turns.", 1, T.SINGLE_ENEMY, 3,
			{"special": true, "attack_scaling": 1.4}, [_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.7, ST.SPECIAL_DEFENSE)]),
		_skill("Singularity", "Hit all enemies (130% ATK).\nOverdrive (10): +40% damage.", 2, T.ALL_ENEMIES, 5,
			{"special": true, "attack_scaling": 1.3, "overdrive_kind": OD.BONUS_DAMAGE, "overdrive_cost": 10, "overdrive_value": 0.4}),
	]))

	# ---------------- Expansion: Controller ----------------
	roster.append(_troop("grove_witch", "Grove Witch", &"grove", A.CONTROLLER, [280, 57, 96, 57, 63, 64, 0.1, 1.5, 0.5], [
		_s1("Bog Spit", "Strike one enemy (90% ATK); 40% chance to Poison it for 2 turns.", {"special": true, "attack_scaling": 0.9},
			[_fx(K.DOT, ET.SKILL_TARGETS, 0.3, 2, 0.4)]),
		_skill("Choking Fog", "Hit all enemies (60% ATK); 55% chance to Poison each for 2 turns.", 1, T.ALL_ENEMIES, 3,
			{"special": true, "attack_scaling": 0.6}, [_fx(K.DOT, ET.SKILL_TARGETS, 0.3, 2, 0.55)]),
		_skill("Withering Curse", "Strike one enemy (150% ATK, +40% vs debuffed); 80% chance to lower its ATK and SPA by 20% for 2 turns.\nOverdrive (10): all effects are guaranteed.", 2, T.SINGLE_ENEMY, 4,
			{"special": true, "attack_scaling": 1.5, "bonus_vs_debuffed": 0.4, "overdrive_kind": OD.GUARANTEE_EFFECTS, "overdrive_cost": 10},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.8, ST.ATTACK), _fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.8, ST.SPECIAL_ATTACK)]),
	]))
	roster.append(_troop("forge_sentinel", "Forge Sentinel", &"forge", A.CONTROLLER, [330, 99, 54, 78, 66, 65, 0.15, 1.5, 0.35], [
		_s1("Gear Jab", "Strike one enemy (100% ATK); 50% chance to lower its SPE by 15% for 1 turn.", {"attack_scaling": 1.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.15, 1, 0.5, ST.SPEED)]),
		_skill("Overclock", "Raise SPE of both allies by 20% for 2 turns and gain 2 Team Energy.", 1, T.ALL_ALLIES, 3,
			{}, [_fx(K.STAT_MOD, ET.ALLIES, 0.2, 2, 1.0, ST.SPEED), _fx(K.ENERGY, ET.SELF, 2.0)]),
		_skill("Time Lock", "Strike one enemy (120% ATK); 70% chance to Stun for 1 turn.\nOverdrive (10): cooldown -2.", 2, T.SINGLE_ENEMY, 5,
			{"attack_scaling": 1.5, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 10, "overdrive_value": 2.0},
			[_fx(K.STUN, ET.SKILL_TARGETS, 0.0, 1, 0.8)]),
	]))
	roster.append(_troop("tide_oracle", "Tide Oracle", &"tide", A.CONTROLLER, [305, 54, 107, 63, 75, 67, 0.1, 1.5, 0.4], [
		_s1("Glimmer", "Strike one enemy (95% ATK); 40% chance to lower its EFF by 25% for 2 turns.", {"special": true, "attack_scaling": 0.95},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.25, 2, 0.4, ST.EFFECTIVENESS)]),
		_passive("Reflecting Veil", "Passive: when debuffed, lower all enemies' EFF by 30% for 2 turns (3-turn internal cooldown).",
			TR.ON_DEBUFF_RECEIVED, 3, T.SELF, [_fx(K.STAT_MOD, ET.ENEMIES, -0.3, 2, 1.0, ST.EFFECTIVENESS)]),
		_skill("Shatter Sight", "Hit all enemies (80% ATK); 75% chance to lower ATK and SPA by 20% for 2 turns.\nOverdrive (10): all effects are guaranteed.", 2, T.ALL_ENEMIES, 5,
			{"special": true, "attack_scaling": 0.8, "overdrive_kind": OD.GUARANTEE_EFFECTS, "overdrive_cost": 10},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.75, ST.ATTACK), _fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.75, ST.SPECIAL_ATTACK)]),
	]))

	# ---------------- Expansion: Tanker ----------------
	roster.append(_troop("forge_colossus", "Forge Colossus", &"forge", A.TANKER, [375, 78, 42, 84, 69, 55, 0.05, 1.5, 0.0], [
		_s1("Rock Slam", "Strike one enemy (50% ATK + 12% max HP).", {"attack_scaling": 0.5, "hp_scaling": 0.12}),
		_passive("Stoneskin Link", "Passive: when the partner is hit, raise its DEF and SPD by 20% for 2 turns (2-turn internal cooldown).",
			TR.ON_ALLY_HIT, 2, T.SINGLE_ALLY, [_fx(K.STAT_MOD, ET.SKILL_TARGETS, 0.2, 2, 1.0, ST.DEFENSE), _fx(K.STAT_MOD, ET.SKILL_TARGETS, 0.2, 2, 1.0, ST.SPECIAL_DEFENSE)]),
		_skill("Quake", "Hit all enemies (40% ATK + 10% max HP); 60% chance to lower SPE by 20% for 2 turns.\nOverdrive (10): +50% damage.", 2, T.ALL_ENEMIES, 4,
			{"attack_scaling": 0.4, "hp_scaling": 0.2, "overdrive_kind": OD.BONUS_DAMAGE, "overdrive_cost": 10, "overdrive_value": 0.5},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.6, ST.SPEED)]),
	]))
	roster.append(_troop("grove_berserker", "Grove Berserker", &"grove", A.TANKER, [300, 90, 42, 54, 48, 59, 0.2, 1.6, 0.0], [
		_s1("Maul", "Strike one enemy (100% ATK, up to +40% at low HP).", {"attack_scaling": 1.0, "missing_hp_bonus": 0.4}),
		_skill("Bloodlust", "Raise own ATK by 30% and crit chance by 20% for 2 turns, and heal 8% max HP.", 1, T.SELF, 3,
			{}, [_fx(K.STAT_MOD, ET.SELF, 0.3, 2, 1.0, ST.ATTACK), _fx(K.STAT_MOD, ET.SELF, 0.2, 2, 1.0, ST.CRIT_CHANCE), _fx(K.HEAL, ET.SELF, 0.08)]),
		_skill("Savage Rend", "Strike one enemy (200% ATK, up to +50% at low HP).\nOverdrive (15): act first this round.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 2.0, "missing_hp_bonus": 0.5, "overdrive_kind": OD.ACT_FIRST, "overdrive_cost": 15}),
	]))

	# ---------------- Expansion: Pivot ----------------
	roster.append(_troop("tide_caller", "Tide Caller", &"tide", A.PIVOT, [300, 51, 101, 63, 72, 66, 0.05, 1.5, 0.15], [
		_s1("Splash", "Strike one enemy (85% ATK). Generates 2 Team Energy.", {"special": true, "attack_scaling": 0.85, "energy_gain": 2}),
		_passive("Tidal Ward", "Passive: on switch-in, shield both allies for 10% of max HP for 2 turns (3-turn internal cooldown).",
			TR.ON_SWITCH_IN, 3, T.ALL_ALLIES, [_fx(K.SHIELD, ET.ALLIES, 0.10, 2)]),
		_skill("Riptide", "Hit all enemies (90% ATK) and lower their SPE by 15% for 2 turns, then switch out with a benched troop.\nOverdrive (8): cooldown -2.", 2, T.ALL_ENEMIES, 4,
			{"special": true, "attack_scaling": 0.9, "self_switch_after": true, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 8, "overdrive_value": 2.0},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.15, 2, 1.0, ST.SPEED)]),
	]))
	roster.append(_troop("void_fox", "Void Fox", &"void", A.PIVOT, [270, 111, 48, 54, 51, 71, 0.2, 1.5, 0.25], [
		_s1("Nip", "Strike one enemy (85% ATK); 30% chance to lower its DEF by 20% for 2 turns.", {"attack_scaling": 0.85},
			[_fx(K.STAT_MOD, ET.SKILL_TARGETS, -0.2, 2, 0.3, ST.DEFENSE)]),
		_passive("Ambush", "Passive: on switch-in, lower all enemies' SPE by 15% for 2 turns (2-turn internal cooldown).",
			TR.ON_SWITCH_IN, 2, T.SELF, [_fx(K.STAT_MOD, ET.ENEMIES, -0.15, 2, 1.0, ST.SPEED)]),
		_skill("Vanishing Strike", "Strike one enemy (150% ATK, +30% vs debuffed), then switch out with a benched troop.\nOverdrive (12): act first this round.", 2, T.SINGLE_ENEMY, 4,
			{"attack_scaling": 1.5, "bonus_vs_debuffed": 0.3, "self_switch_after": true, "overdrive_kind": OD.ACT_FIRST, "overdrive_cost": 12}),
	]))
	roster.append(_troop("storm_herald", "Storm Herald", &"storm", A.PIVOT, [325, 94, 87, 72, 72, 67, 0.12, 1.5, 0.2], [
		_s1("Pennant Strike", "Strike one enemy (110% ATK). Generates 2 Team Energy.", {"attack_scaling": 1.1, "energy_gain": 2}),
		_skill("War Anthem", "Raise ATK and SPA of both allies by 30% for 2 turns.", 1, T.ALL_ALLIES, 3,
			{}, [_fx(K.STAT_MOD, ET.ALLIES, 0.3, 2, 1.0, ST.ATTACK), _fx(K.STAT_MOD, ET.ALLIES, 0.3, 2, 1.0, ST.SPECIAL_ATTACK)]),
		_skill("Fall Back", "Heal both allies 18% max HP and cleanse their debuffs, then switch out with a benched troop.\nOverdrive (8): cooldown -2.", 2, T.ALL_ALLIES, 4,
			{"self_switch_after": true, "overdrive_kind": OD.REDUCE_COOLDOWN, "overdrive_cost": 8, "overdrive_value": 2.0},
			[_fx(K.HEAL, ET.ALLIES, 0.18), _fx(K.CLEANSE, ET.ALLIES, 0.0)]),
	]))
	return roster
