extends SceneTree
## Headless verification: godot --headless -s res://tests/combat_simulation_test.gd
## Exit code 0 = all checks passed.

const MATCH_SEEDS: int = 40
const MAX_STEPS: int = 3000

var _checks: int = 0
var _failures: int = 0
## Each test bumps this as its last line; a script error aborts the function and leaves it short.
var _sections_done: int = 0
const SECTIONS: int = 10


func _initialize() -> void:
	_test_formulas()
	_test_speed_order_and_damage()
	_test_cooldowns()
	_test_switch_rules()
	_test_caps_overdrive_and_effects()
	_test_standby_and_retarget()
	_test_roster_and_passives()
	_test_full_matches()
	_test_determinism()
	_test_server_loop()
	print("\n%d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# ---------------------------------------------------------------- helpers

func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  FAIL: " + label)


func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func _make_skill(slot: int, target_type: int, cooldown: int, atk: float, effects: Array[EffectData] = []) -> SkillData:
	var s: SkillData = SkillData.new()
	s.skill_name = "S%d" % (slot + 1)
	s.slot = slot
	s.target_type = target_type
	s.cooldown = cooldown
	s.attack_scaling = atk
	s.effects = effects
	return s


func _make_effect(kind: int, target: int, magnitude: float, duration: int = 0, stat: int = CombatTypes.Stat.ATTACK) -> EffectData:
	var e: EffectData = EffectData.new()
	e.kind = kind
	e.target = target
	e.magnitude = magnitude
	e.duration = duration
	e.stat = stat
	return e


## Deterministic dummy: 0 crit, 0 effectiveness, no dual attacks.
func _make_troop(id: String, hp: int, atk: int, def: int, spd: int, skills: Array[SkillData] = []) -> TroopData:
	var t: TroopData = TroopData.new()
	t.troop_id = StringName(id)
	t.display_name = id
	t.max_hp = hp
	t.attack = atk
	t.defense = def
	t.special_attack = atk
	t.special_defense = def
	t.speed = spd
	t.crit_chance = 0.0
	if skills.is_empty():
		skills = [
			_make_skill(0, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0),
			_make_skill(1, CombatTypes.TargetType.SINGLE_ENEMY, 2, 1.5),
			_make_skill(2, CombatTypes.TargetType.ALL_ENEMIES, 4, 1.2),
		]
	t.skills = skills
	return t


func _dummy_squad(prefix: String, speeds: Array[int], skills: Array[SkillData] = []) -> Array[TroopData]:
	var squad: Array[TroopData] = []
	for i in speeds.size():
		squad.append(_make_troop("%s%d" % [prefix, i], 1000, 150, 150, speeds[i], skills))
	return squad


func _start(squad_a: Array[TroopData], squad_b: Array[TroopData], seed_value: int = 1) -> CombatEngine:
	var engine: CombatEngine = CombatEngine.new(seed_value)
	engine.start_preview(squad_a, squad_b)
	var picks: Array[int] = [0, 1, 2, 3]
	engine.submit_draft(0, picks)
	engine.submit_draft(1, picks)
	return engine


func _has_event(events: Array[CombatEvent], type: int) -> bool:
	for e in events:
		if e.type == type:
			return true
	return false


func _is_rejected(events: Array[CombatEvent]) -> bool:
	return events.size() == 1 and events[0].type == CombatTypes.EventType.ACTION_REJECTED


# ---------------------------------------------------------------- tests

## Default actions (S1 on the first legal target) for every troop of `side` that must act, plus overrides.
func _acts(engine: CombatEngine, side: int, overrides: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for t in engine.acting_troops(side):
		out[t.uid] = CombatAction.cast(0, engine._default_target(t, 0))
	for uid: int in overrides:
		out[uid] = overrides[uid]
	return out


## Both sides lock in; returns the events of the resolving submit.
func _round(engine: CombatEngine, overrides_a: Dictionary = {}, overrides_b: Dictionary = {}) -> Array[CombatEvent]:
	var first: Array[CombatEvent] = engine.submit_actions(0, _acts(engine, 0, overrides_a))
	var second: Array[CombatEvent] = engine.submit_actions(1, _acts(engine, 1, overrides_b))
	first.append_array(second)
	return first


func _actor_sequence(events: Array[CombatEvent]) -> Array[int]:
	var out: Array[int] = []
	for e in events:
		if e.type == CombatTypes.EventType.TURN_STARTED:
			out.append(e.actor)
	return out


# ---------------------------------------------------------------- tests

func _test_formulas() -> void:
	print("[formulas]")
	_check(_near(CombatMath.effect_chance(0.5, 0.0), 0.5), "EFF 0 leaves the chance alone")
	_check(_near(CombatMath.effect_chance(0.5, 0.4), 0.7), "EFF +40% scales 50% to 70%")
	_check(_near(CombatMath.effect_chance(0.8, 0.5), 1.0), "effect chance caps at 100%")
	_check(_near(CombatMath.effect_chance(0.0, 1.0), 0.0), "0% base stays 0%")
	_check(_near(CombatMath.mitigation(CombatTypes.DEFENSE_CONSTANT), 0.5), "DEFENSE_CONSTANT DEF halves damage")
	_check(CombatMath.final_damage(200.0, CombatTypes.DEFENSE_CONSTANT, false, 1.5, 1.0) == 100, "200 raw vs DEFENSE_CONSTANT DEF = 100")
	_check(CombatMath.final_damage(200.0, CombatTypes.DEFENSE_CONSTANT, true, 1.5, 1.0) == 150, "crit x1.5 = 150")
	_check(_near(CombatMath.frenzy_damage_mult(15), 1.0) and _near(CombatMath.frenzy_damage_mult(17), 1.10), "frenzy damage +5%/round after 15")
	_check(_near(CombatMath.frenzy_heal_mult(17), 0.90) and _near(CombatMath.frenzy_heal_mult(60), 0.0), "frenzy healing -5%/round, floor 0")
	_sections_done += 1


func _test_speed_order_and_damage() -> void:
	print("[speed order + damage]")
	var engine: CombatEngine = _start(_dummy_squad("a", [200, 100, 90, 90, 90, 90]), _dummy_squad("b", [150, 50, 90, 90, 90, 90]))
	var st: CombatState = engine.state
	_check(st.phase == CombatTypes.Phase.ACTION_WAIT, "battle reaches ACTION_WAIT after draft")
	var a0: TroopInstance = st.team(0).active[0]
	var a1: TroopInstance = st.team(0).active[1]
	var b0: TroopInstance = st.team(1).active[0]
	var b1: TroopInstance = st.team(1).active[1]
	_check(engine.predicted_order() == [a0.uid, b0.uid, a1.uid, b1.uid], "predicted order is by Speed")
	_check(st.team(0).bench.size() == 2 and st.team(1).bench.size() == 2, "2 active + 2 bench per side")
	_check(st.cycle == 1, "round 1")

	var hp_before: int = b0.hp
	var first: Array[CombatEvent] = engine.submit_actions(0, _acts(engine, 0, {a0.uid: CombatAction.cast(0, b0.uid)}))
	_check(not _has_event(first, CombatTypes.EventType.DAMAGE), "nothing resolves until both sides lock in")
	_check(st.team(0).actions_locked and not st.team(1).actions_locked, "side A is locked, B is not")
	_check(_is_rejected(engine.submit_actions(0, _acts(engine, 0))), "locking twice is rejected")
	var events: Array[CombatEvent] = engine.submit_actions(1, _acts(engine, 1))
	_check(_actor_sequence(events) == [a0.uid, b0.uid, a1.uid, b1.uid], "actions resolve in Speed order")
	# 150 ATK * 1.0 mitigated by 150 DEF per hit; both of A's troops target b0
	var per_hit: int = CombatMath.final_damage(150.0, 150.0, false, 1.5, 1.0)
	_check(hp_before - b0.hp == per_hit * 2, "two S1 hits of %d each (got %d)" % [per_hit, hp_before - b0.hp])
	_check(st.cycle == 2, "round counter advances after resolution")
	_check(st.team(0).energy == 0, "dummy S1 has no energy gain")

	# Special skills use SPA vs SPD.
	var sp: SkillData = _make_skill(0, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0)
	sp.special = true
	var skills: Array[SkillData] = [sp, _make_skill(1, CombatTypes.TargetType.SINGLE_ENEMY, 2, 1.0), _make_skill(2, CombatTypes.TargetType.SINGLE_ENEMY, 4, 1.0)]
	var squad_a: Array[TroopData] = _dummy_squad("a", [300, 60, 60, 60, 60, 60], skills)
	for d in squad_a:
		d.special_attack = 400
		d.attack = 1
	var squad_b: Array[TroopData] = _dummy_squad("b", [50, 50, 50, 50, 50, 50])
	for d in squad_b:
		d.special_defense = int(CombatTypes.DEFENSE_CONSTANT)
		d.defense = 0
	var e2: CombatEngine = _start(squad_a, squad_b)
	var victim: TroopInstance = e2.state.team(1).active[0]
	var before: int = victim.hp
	_round(e2, {e2.state.team(0).active[0].uid: CombatAction.cast(0, victim.uid)})
	# 400 SPA / (1 + 300/300) = 200 per hit, two hits
	_check(before - victim.hp == 400, "special damage uses SPA vs SPD (got %d)" % (before - victim.hp))
	_sections_done += 1


func _test_cooldowns() -> void:
	print("[cooldowns]")
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60]), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var a0: TroopInstance = st.team(0).active[0]
	var foe: int = st.team(1).active[0].uid
	_check(_is_rejected(engine.submit_actions(0, {a0.uid: CombatAction.cast(0, foe)})), "every active troop needs an action")
	_round(engine, {a0.uid: CombatAction.cast(1, foe)})  # S2, cooldown 2
	_check(a0.cooldowns[1] == 1, "cooldown 2 ticks to 1 at the end of the round")
	_check(_is_rejected(engine.submit_actions(0, _acts(engine, 0, {a0.uid: CombatAction.cast(1, foe)}))), "S2 rejected while on cooldown")
	_check(not engine.legal_skills(a0).has(1), "S2 not in legal skills")
	_check(_is_rejected(engine.submit_actions(0, _acts(engine, 0, {a0.uid: CombatAction.cast(0, a0.uid)}))), "own troop is not a valid enemy target")
	_round(engine)
	_check(a0.cooldowns[1] == 0, "cooldown reaches 0 after another round")
	_check(engine.legal_skills(a0).has(1), "S2 legal again")
	_sections_done += 1


func _test_switch_rules() -> void:
	print("[switch rules]")
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60]), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var team: TeamState = st.team(0)
	var leaver: TroopInstance = team.active[0]
	var incoming: TroopInstance = team.bench[0]
	incoming.hp = 400
	incoming.cooldowns[2] = 3
	incoming.effects.append(ActiveEffect.new(CombatTypes.EffectKind.STAT_MOD, CombatTypes.Stat.DEFENSE, -0.3, 2, 0, -1, 0))
	incoming.effects.append(ActiveEffect.new(CombatTypes.EffectKind.STAT_MOD, CombatTypes.Stat.ATTACK, 0.2, 2, 0, -1, 0))
	var both: Dictionary = {leaver.uid: CombatAction.switch_to(0), team.active[1].uid: CombatAction.switch_to(0)}
	_check(_is_rejected(engine.submit_actions(0, both)), "two switches to the same bench troop rejected")
	var events: Array[CombatEvent] = _round(engine, {leaver.uid: CombatAction.switch_to(0)})
	_check(_has_event(events, CombatTypes.EventType.SWITCHED), "SWITCHED event emitted")
	_check(team.active[0] == incoming and team.bench[0] == leaver, "troops swapped slot <-> bench")
	_check(incoming.hp <= 400 and incoming.cooldowns[2] >= 2, "incoming keeps HP and cooldowns (ticked at most once)")
	_check(incoming.stat_modifier(CombatTypes.Stat.DEFENSE) == 0.0, "stat debuff cleansed on entry")
	_check(_near(incoming.stat_modifier(CombatTypes.Stat.ATTACK), 0.2), "buffs kept on entry")
	_check(team.energy >= CombatTypes.SWITCH_ENERGY, "switch grants Team Energy")
	_check(team.slot_switch_cd[0] == 1, "slot has a 1-round switch cooldown after the round")
	_check(not engine.can_switch(incoming), "cannot switch the troop that just switched in")
	_check(_is_rejected(engine.submit_actions(0, _acts(engine, 0, {incoming.uid: CombatAction.switch_to(0)}))), "switch rejected during slot cooldown")
	_round(engine)
	_check(team.slot_switch_cd[0] == 0, "slot cooldown clears after one more round")
	_check(engine.can_switch(incoming), "switch available again")
	_sections_done += 1


func _test_caps_overdrive_and_effects() -> void:
	print("[caps + overdrive + effects]")
	var stun_fx: EffectData = _make_effect(CombatTypes.EffectKind.STUN, CombatTypes.EffectTarget.SKILL_TARGETS, 0.0, 1)
	stun_fx.chance = 0.0
	var od_skill: SkillData = _make_skill(2, CombatTypes.TargetType.SINGLE_ENEMY, 4, 1.0, [stun_fx])
	od_skill.overdrive_kind = CombatTypes.OverdriveKind.REDUCE_COOLDOWN
	od_skill.overdrive_cost = 10
	od_skill.overdrive_value = 2.0
	var skills: Array[SkillData] = [_make_skill(0, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0), _make_skill(1, CombatTypes.TargetType.SELF, 2, 0.0), od_skill]
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60], skills), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var a0: TroopInstance = st.team(0).active[0]
	var a1: TroopInstance = st.team(0).active[1]
	var b0: TroopInstance = st.team(1).active[0]

	a0.effects.append(ActiveEffect.new(CombatTypes.EffectKind.STAT_MOD, CombatTypes.Stat.SPEED, 0.5, 3, 0, -1, 0))
	_check(_near(a0.get_stat(CombatTypes.Stat.SPEED), 300.0 * 1.3), "speed buff capped at +30%")
	a0.effects.clear()

	st.team(0).energy = 5
	_check(_is_rejected(engine.submit_actions(0, _acts(engine, 0, {a0.uid: CombatAction.cast(2, b0.uid, true)}))), "overdrive rejected without enough energy")
	st.team(0).energy = 15
	var two: Dictionary = {a0.uid: CombatAction.cast(2, b0.uid, true), a1.uid: CombatAction.cast(2, b0.uid, true)}
	_check(_is_rejected(engine.submit_actions(0, two)), "two overdrives can't share energy that covers only one")
	st.team(0).energy = 12
	_round(engine, {a0.uid: CombatAction.cast(2, b0.uid, true)})
	_check(st.team(0).energy == 2, "overdrive spends its cost (12 - 10 = 2)")
	_check(a0.cooldowns[2] == 1, "REDUCE_COOLDOWN: 4 - 2 = 2, ticked to 1 (got %d)" % a0.cooldowns[2])

	# GUARANTEE_EFFECTS: a 0% effect still lands.
	var gskill: SkillData = _make_skill(2, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0, [stun_fx])
	gskill.overdrive_kind = CombatTypes.OverdriveKind.GUARANTEE_EFFECTS
	gskill.overdrive_cost = 5
	var gs: Array[SkillData] = [_make_skill(0, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0), skills[1], gskill]
	var e2: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60], gs), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var foe: TroopInstance = e2.state.team(1).active[0]
	var hero: TroopInstance = e2.state.team(0).active[0]
	e2.state.team(0).energy = 20
	_round(e2, {hero.uid: CombatAction.cast(2, foe.uid, false)})
	_check(not foe.is_stunned(), "0% effect never procs without Overdrive")
	_round(e2, {hero.uid: CombatAction.cast(2, foe.uid, true)})
	_check(foe.is_stunned(), "GUARANTEE_EFFECTS makes the effect land")
	# Stunned troops lose their action next round and are not asked for one.
	_check(e2.acting_troops(1).size() == 1, "stunned troop is not asked for an action")
	var skipped: Array[CombatEvent] = _round(e2)
	_check(_actor_sequence(skipped).has(foe.uid) == false, "stunned troop does not act")
	_check(not foe.is_stunned(), "stun (1 round) has worn off after that round")

	# ACT_FIRST: a slow troop jumps the queue.
	var fskill: SkillData = _make_skill(2, CombatTypes.TargetType.SINGLE_ENEMY, 4, 1.0)
	fskill.overdrive_kind = CombatTypes.OverdriveKind.ACT_FIRST
	fskill.overdrive_cost = 15
	var fs: Array[SkillData] = [_make_skill(0, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0), skills[1], fskill]
	var e3: CombatEngine = _start(_dummy_squad("a", [10, 10, 60, 60, 60, 60], fs), _dummy_squad("b", [200, 190, 60, 60, 60, 60]))
	var slow: TroopInstance = e3.state.team(0).active[1]
	e3.state.team(0).energy = 20
	var ev: Array[CombatEvent] = _round(e3, {slow.uid: CombatAction.cast(2, e3.state.team(1).active[0].uid, true)})
	_check(_actor_sequence(ev)[0] == slow.uid, "ACT_FIRST overdrive acts before faster troops")
	_sections_done += 1


func _test_standby_and_retarget() -> void:
	print("[standby + retarget]")
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 290, 60, 60, 60, 60]), _dummy_squad("b", [50, 40, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var victim: TroopInstance = st.team(1).active[1]
	var other: TroopInstance = st.team(1).active[0]
	victim.hp = 1
	var a0: TroopInstance = st.team(0).active[0]
	var a1: TroopInstance = st.team(0).active[1]
	var other_before: int = other.hp
	var events: Array[CombatEvent] = _round(engine, {a0.uid: CombatAction.cast(0, victim.uid), a1.uid: CombatAction.cast(0, victim.uid)})
	_check(_has_event(events, CombatTypes.EventType.KO), "KO emitted")
	_check(other.hp < other_before, "second attacker retargets the surviving foe")
	_check(not _actor_sequence(events).has(victim.uid), "a KO'd troop does not act later in the round")
	_check(st.phase == CombatTypes.Phase.STANDBY, "engine pauses in STANDBY")
	_check(st.team(1).pending_slots == [1], "slot 1 pending for side B")
	_check(_is_rejected(engine.submit_actions(0, {})), "actions rejected during STANDBY")
	_check(_is_rejected(engine.submit_replacement(1, 0, 0)), "replacement into a non-empty slot rejected")
	var incoming: TroopInstance = st.team(1).bench[1]
	engine.submit_replacement(1, 1, 1)
	_check(st.team(1).active[1] == incoming, "replacement enters the KO'd slot")
	_check(st.team(1).bench[1] == victim, "fallen troop moves to the bench")
	_check(st.phase == CombatTypes.Phase.ACTION_WAIT, "battle resumes after replacement")
	_check(not st.team(1).is_bench_ready(1), "fallen troop cannot be switched back in")
	_sections_done += 1


func _test_roster_and_passives() -> void:
	print("[roster + passives]")
	var squad_a: Array[TroopData] = TroopRegistry.random_squad(1)
	var squad_b: Array[TroopData] = TroopRegistry.random_squad(2)
	_check(squad_a.size() == 6 and squad_b.size() == 6, "random squads have 6 troops")
	var all: Dictionary[StringName, TroopData] = TroopRegistry.load_all()
	_check(all.size() >= CombatTypes.DRAFT_BRING, "roster has at least %d troops" % CombatTypes.DRAFT_BRING)
	var per_role: Dictionary = {}
	var special_skills: int = 0
	for d: TroopData in all.values():
		per_role[d.role] = int(per_role.get(d.role, 0)) + 1
		_check(d.skills.size() == 3, "%s has 3 skills" % d.display_name)
		_check(d.attack > 0 and d.special_attack > 0 and d.defense > 0 and d.special_defense > 0 and d.speed > 0, "%s has all seven stats" % d.display_name)
		_check(d.skills[0].cooldown == 0 and d.skills[0].dual_attack_chance <= CombatTypes.DUAL_ATTACK_CAP, "%s S1: no cooldown, dual <= cap" % d.display_name)
		var s2: SkillData = d.skills[1]
		_check(s2.is_passive or (s2.cooldown >= 2 and s2.cooldown <= 3), "%s S2 cooldown 2-3 or passive" % d.display_name)
		_check(not s2.is_passive or s2.cooldown > 0, "%s passive has an internal cooldown" % d.display_name)
		_check(d.skills[2].cooldown >= 4 and d.skills[2].cooldown <= 5, "%s S3 cooldown 4-5" % d.display_name)
		for s in d.skills:
			special_skills += 1 if s.special else 0
	_check(special_skills > 0, "some skills are special")
	for arch in CombatTypes.Role.values():
		_check(int(per_role.get(arch, 0)) >= 1, "role %s has troops" % CombatTypes.Role.keys()[arch])

	# Archetypes: every troop has a family; two same-family actives get its synergy, which ends when one falls.
	for d: TroopData in all.values():
		_check(ArchetypeRegistry.find(d.archetype) != null, "%s has a valid archetype" % d.display_name)
	var fam: Array[TroopData] = _dummy_squad("a", [300, 300, 300, 300, 60, 60])
	fam[0] = all[&"ember_aggro"]
	fam[1] = all[&"ember_ranger"]
	var fam_engine: CombatEngine = _start(fam, _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var f0: TroopInstance = fam_engine.state.team(0).active[0]
	_check(_near(f0.stat_modifier(CombatTypes.Stat.ATTACK), 0.1), "ember pair gets +10% ATK synergy")
	f0.hp = 0
	fam_engine._refresh_synergy()
	_check(fam_engine.state.team(0).active[1].synergy.is_empty(), "synergy ends when the partner falls")

	# Courier entry passive: +20% SPE and 2 Team Energy on switch-in.
	var courier: TroopData = all[&"storm_courier"]
	var squad: Array[TroopData] = _dummy_squad("a", [300, 60, 60, 60, 60, 60])
	squad[2] = courier
	var engine: CombatEngine = _start(squad, _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var team: TeamState = engine.state.team(0)
	var events: Array[CombatEvent] = _round(engine, {team.active[0].uid: CombatAction.switch_to(0)})
	var c: TroopInstance = team.active[0]
	_check(c.data == courier, "courier switched in")
	_check(_has_event(events, CombatTypes.EventType.PASSIVE_TRIGGERED), "entry passive triggered")
	_check(team.energy >= CombatTypes.SWITCH_ENERGY + 1, "switch energy + passive energy")
	_check(_near(c.stat_modifier(CombatTypes.Stat.SPEED), 0.2), "courier gains +20% SPE")
	_check(c.passive_icd >= 1, "passive internal cooldown set")
	_sections_done += 1


func _test_full_matches() -> void:
	print("[full matches: %d seeds, AI vs AI, real roster]" % MATCH_SEEDS)
	var wins: Array[int] = [0, 0]
	var total_cycles: int = 0
	var max_cycle: int = 0
	var frenzy_matches: int = 0
	var appearances: Dictionary = {}
	var troop_wins: Dictionary = {}
	for s in MATCH_SEEDS:
		var result: Dictionary = _run_ai_match(1000 + s)
		if not result["ok"]:
			_check(false, "match seed %d: %s" % [1000 + s, result["error"]])
			continue
		wins[result["winner"]] += 1
		total_cycles += int(result["cycle"])
		max_cycle = maxi(max_cycle, int(result["cycle"]))
		if int(result["cycle"]) > CombatTypes.FRENZY_START_CYCLE:
			frenzy_matches += 1
		for side in 2:
			for id: String in result["picks"][side]:
				appearances[id] = int(appearances.get(id, 0)) + 1
				if side == result["winner"]:
					troop_wins[id] = int(troop_wins.get(id, 0)) + 1
	_check(wins[0] + wins[1] == MATCH_SEEDS, "every match ended with a winner")
	print("  side A wins %d / side B wins %d, avg rounds %.1f, max rounds %d, frenzy reached in %d" % [wins[0], wins[1], float(total_cycles) / MATCH_SEEDS, max_cycle, frenzy_matches])
	var ids: Array = appearances.keys()
	ids.sort()
	for id: String in ids:
		print("  %-14s picked %2d  win rate %3d%%" % [id, appearances[id], roundi(100.0 * troop_wins.get(id, 0) / appearances[id])])
	_sections_done += 1


## Advances one engine step with AI input; returns the events (empty when finished).
func _ai_step(engine: CombatEngine, ais: Array[AIController]) -> Array[CombatEvent]:
	var st: CombatState = engine.state
	var events: Array[CombatEvent] = []
	if st.phase == CombatTypes.Phase.ACTION_WAIT:
		for side in 2:
			if st.phase == CombatTypes.Phase.ACTION_WAIT and not st.team(side).actions_locked:
				events.append_array(engine.submit_actions(side, ais[side].choose_actions(engine)))
	elif st.phase == CombatTypes.Phase.STANDBY:
		for side in 2:
			if not st.team(side).pending_slots.is_empty():
				events.append_array(engine.submit_replacement(side, st.team(side).pending_slots[0], ais[side].choose_replacement(engine)))
				break
	return events


func _run_ai_match(seed_value: int) -> Dictionary:
	var engine: CombatEngine = CombatEngine.new(seed_value)
	var ais: Array[AIController] = [AIController.new(0, seed_value * 3), AIController.new(1, seed_value * 7)]
	engine.start_preview(TroopRegistry.random_squad(1), TroopRegistry.random_squad(2))
	var picks: Array = [[], []]
	for side in 2:
		var p: Array[int] = ais[side].choose_draft(engine.state.team(side).squad)
		for i in p:
			picks[side].append(String(engine.state.team(side).squad[i].troop_id))
		var ev: Array[CombatEvent] = engine.submit_draft(side, p)
		if _is_rejected(ev):
			return {"ok": false, "error": "draft rejected: %s" % ev[0].data["reason"]}
	var st: CombatState = engine.state
	for step in MAX_STEPS:
		if st.phase == CombatTypes.Phase.FINISHED:
			return {"ok": true, "winner": st.winner, "cycle": st.cycle, "picks": picks}
		if st.phase != CombatTypes.Phase.ACTION_WAIT and st.phase != CombatTypes.Phase.STANDBY:
			return {"ok": false, "error": "stuck in phase %s" % CombatTypes.Phase.keys()[st.phase]}
		var events: Array[CombatEvent] = _ai_step(engine, ais)
		for e in events:
			if e.type == CombatTypes.EventType.ACTION_REJECTED:
				return {"ok": false, "error": "AI action rejected: %s" % e.data["reason"]}
		var err: String = _invariants(st)
		if err != "":
			return {"ok": false, "error": err}
	return {"ok": false, "error": "no winner after %d steps (round %d)" % [MAX_STEPS, st.cycle]}


func _invariants(st: CombatState) -> String:
	for t: TroopInstance in st.troops.values():
		if t.hp < 0 or t.hp > t.max_hp():
			return "%s hp out of range: %d" % [t.data.display_name, t.hp]
		for cd in t.cooldowns:
			if cd < 0:
				return "negative cooldown"
	for team in st.teams:
		if team.energy < 0 or team.energy > CombatTypes.ENERGY_CAP:
			return "energy out of range: %d" % team.energy
	return ""


func _test_determinism() -> void:
	print("[determinism]")
	var a: Array[Dictionary] = _event_trace(4242)
	var b: Array[Dictionary] = _event_trace(4242)
	_check(a.size() > 50 and a == b, "same seed -> identical event log (%d events)" % a.size())
	var cached: TroopData = TroopRegistry.load_all()[&"ember_aggro"]
	var on_disk: TroopData = ResourceLoader.load(TroopRegistry.TROOP_DIR + "ember_aggro.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(cached.max_hp == on_disk.max_hp and cached.skills[0].cooldown == on_disk.skills[0].cooldown, "TroopData templates unchanged after matches")
	_sections_done += 1


func _event_trace(seed_value: int) -> Array[Dictionary]:
	var engine: CombatEngine = CombatEngine.new(seed_value)
	var ais: Array[AIController] = [AIController.new(0, 11), AIController.new(1, 13)]
	var trace: Array[Dictionary] = []
	for e in engine.start_preview(TroopRegistry.random_squad(1), TroopRegistry.random_squad(2)):
		trace.append(e.to_dict())
	for side in 2:
		for e in engine.submit_draft(side, ais[side].choose_draft(engine.state.team(side).squad)):
			trace.append(e.to_dict())
	for step in MAX_STEPS:
		var events: Array[CombatEvent] = _ai_step(engine, ais)
		if events.is_empty():
			break
		for e in events:
			trace.append(e.to_dict())
	return trace


func _test_server_loop() -> void:
	print("[server loop]")
	var server: LocalServer = LocalServer.new()
	root.add_child(server)
	var batches: Array[int] = [0]
	var last_snapshot: Array[Dictionary] = [{}]
	server.events_published.connect(func(events: Array[Dictionary], snapshot: Dictionary) -> void:
		batches[0] += 1
		last_snapshot[0] = snapshot)
	var no_ai: Array[int] = [1]
	server.start_match(77, TroopRegistry.random_squad(1), TroopRegistry.random_squad(2), no_ai, 0)
	var snap: Dictionary = last_snapshot[0]
	_check(snap["phase"] == CombatTypes.Phase.PREVIEW, "server starts in PREVIEW")
	_check((snap["teams"][1]["squad"] as Array).size() == 6, "client sees opponent's 6 in team preview")
	server.client_ready()  # AI (side B) drafts
	_check(server.engine.state.team(1).locked, "AI locked its draft")
	_check((last_snapshot[0]["teams"][1]["picks"] as Array).is_empty(), "opponent picks hidden from viewer")
	var picks: Array[int] = [0, 1, 2, 3]
	server.request_draft(0, picks)
	server.client_ready()
	snap = last_snapshot[0]
	_check(snap["phase"] != CombatTypes.Phase.PREVIEW, "battle started after both drafts")
	var hidden_bench: bool = (snap["teams"][1]["bench"] as Array).has(-2)
	_check(hidden_bench, "unrevealed enemy bench hidden in snapshot")
	# Human (side A) locks S1 for each troop; the AI locks its own.
	var guard: int = 0
	while not server.is_finished() and guard < MAX_STEPS:
		guard += 1
		snap = last_snapshot[0]
		var st: CombatState = server.engine.state
		if st.phase == CombatTypes.Phase.ACTION_WAIT and not st.team(0).actions_locked:
			var legal: Dictionary = snap["legal"]
			if guard < 3:
				_check(legal.size() == 2 and not (snap["teams"][0]["actions_locked"] as bool), "legal actions listed for both of my troops")
			var actions: Dictionary = {}
			for uid: int in legal:
				actions[uid] = CombatAction.cast(0, int(legal[uid]["skills"][0]["targets"][0]))
			server.lock_actions(0, actions)
		elif st.phase == CombatTypes.Phase.STANDBY and not st.team(0).pending_slots.is_empty():
			server.choose_replacement(0, st.team(0).pending_slots[0], st.team(0).first_ready_bench())
		server.client_ready()
	_check(server.is_finished(), "server-driven match finished (winner side %d, %d batches)" % [server.engine.state.winner, batches[0]])
	server.queue_free()
	_sections_done += 1
