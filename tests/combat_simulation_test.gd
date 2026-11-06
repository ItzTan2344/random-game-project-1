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
	_test_cr_timeline_and_damage()
	_test_cooldowns()
	_test_switch_rules()
	_test_caps_and_overdrive()
	_test_standby_replacement()
	_test_passive_and_dual_attack_cap()
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


## Deterministic dummy: 0 crit, 0 effectiveness/resistance, no dual attacks.
func _make_troop(id: String, hp: int, atk: int, def: int, spd: int, skills: Array[SkillData] = []) -> TroopData:
	var t: TroopData = TroopData.new()
	t.troop_id = StringName(id)
	t.display_name = id
	t.max_hp = hp
	t.attack = atk
	t.defense = def
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

func _test_formulas() -> void:
	print("[formulas]")
	_check(_near(CombatMath.hit_chance(0.6, 0.2), 1.0), "hit chance clamps to 1.0")
	_check(_near(CombatMath.hit_chance(0.2, 0.5), 0.7), "hit chance 1 + 0.2 - 0.5 = 0.7")
	_check(_near(CombatMath.hit_chance(0.0, 1.5), 0.0), "hit chance clamps to 0.0")
	_check(_near(CombatMath.mitigation(300.0), 0.5), "300 DEF halves damage")
	_check(CombatMath.final_damage(200.0, 300.0, false, 1.5, 1.0) == 100, "200 raw vs 300 DEF = 100")
	_check(CombatMath.final_damage(200.0, 300.0, true, 1.5, 1.0) == 150, "crit x1.5 = 150")
	_check(_near(CombatMath.time_to_full(50.0, 100.0), 0.5), "time to full 50 CR at 100 SPD = 0.5")
	_check(_near(CombatMath.clamp_cr_push(45.0), 30.0) and _near(CombatMath.clamp_cr_push(-45.0), -30.0), "CR push capped at +/-30")
	_check(CombatMath.cycle_at(0.5) == 1 and CombatMath.cycle_at(1.0) == 1 and CombatMath.cycle_at(1.01) == 2, "cycle boundaries")
	_check(_near(CombatMath.frenzy_damage_mult(15), 1.0) and _near(CombatMath.frenzy_damage_mult(17), 1.10), "frenzy damage +5%/cycle after 15")
	_check(_near(CombatMath.frenzy_heal_mult(17), 0.90) and _near(CombatMath.frenzy_heal_mult(60), 0.0), "frenzy healing -5%/cycle, floor 0")
	_sections_done += 1


func _test_cr_timeline_and_damage() -> void:
	print("[cr timeline + damage]")
	var engine: CombatEngine = _start(_dummy_squad("a", [200, 100, 90, 90, 90, 90]), _dummy_squad("b", [150, 50, 90, 90, 90, 90]))
	var st: CombatState = engine.state
	_check(st.phase == CombatTypes.Phase.ACTION_WAIT, "battle reaches ACTION_WAIT after draft")
	var a0: TroopInstance = st.team(0).active[0]
	var a1: TroopInstance = st.team(0).active[1]
	var b0: TroopInstance = st.team(1).active[0]
	var b1: TroopInstance = st.team(1).active[1]
	_check(st.current_actor == a0, "fastest troop (200 SPD) acts first")
	_check(_near(st.timeline_time, 0.5), "timeline advanced 0.5 units")
	_check(_near(a1.cr, 50.0) and _near(b0.cr, 75.0) and _near(b1.cr, 25.0), "others gained speed * time CR")
	_check(st.cycle == 1, "still cycle 1")
	_check(st.team(0).bench.size() == 2 and st.team(1).bench.size() == 2, "2 active + 2 bench per side")

	var hp_before: int = b0.hp
	engine.submit_action(0, CombatAction.cast(0, b0.uid))
	# 150 ATK * 1.0 / (1 + 150/300) = 100
	_check(hp_before - b0.hp == 100, "S1 damage matches formula (expected 100, got %d)" % (hp_before - b0.hp))
	_check(st.team(0).energy == 0, "dummy S1 has no energy gain")
	# Next: b0 had 75 CR at 150 SPD -> 25/150 = 0.1667; a1 50 CR at 100 -> 0.5. b0 next.
	_check(st.current_actor == b0, "CR order: b0 acts second")
	_check(_near(a0.cr, 0.0 + 200.0 * (25.0 / 150.0), 0.01), "actor CR reset to 0 then regained")
	_sections_done += 1


func _test_cooldowns() -> void:
	print("[cooldowns]")
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60]), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var a0: TroopInstance = st.current_actor
	var foe: int = st.team(1).active[0].uid
	_check(a0 == st.team(0).active[0], "fast troop acts")
	engine.submit_action(0, CombatAction.cast(1, foe))  # S2, cooldown 2
	_check(a0.cooldowns[1] == 1, "cooldown 2 ticks to 1 at end of use turn")
	_check(st.current_actor == a0, "300 SPD troop acts again before 50 SPD foes")
	_check(_is_rejected(engine.submit_action(0, CombatAction.cast(1, foe))), "S2 rejected while on cooldown")
	_check(not engine.legal_skills(a0).has(1), "S2 not in legal skills")
	engine.submit_action(0, CombatAction.cast(0, foe))
	_check(a0.cooldowns[1] == 0, "cooldown reaches 0 after another turn")
	_check(engine.legal_skills(a0).has(1), "S2 legal again")
	_check(_is_rejected(engine.submit_action(1, CombatAction.cast(0, a0.uid))), "wrong side rejected")
	_check(_is_rejected(engine.submit_action(0, CombatAction.cast(0, a0.uid))), "own troop is not a valid enemy target")
	_sections_done += 1


func _test_switch_rules() -> void:
	print("[switch rules]")
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60]), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var team: TeamState = st.team(0)
	var leaver: TroopInstance = st.current_actor
	var incoming: TroopInstance = team.bench[0]
	incoming.hp = 400
	incoming.cooldowns[2] = 3
	incoming.effects.append(ActiveEffect.new(CombatTypes.EffectKind.STAT_MOD, CombatTypes.Stat.DEFENSE, -0.3, 2, 0, -1, 0))
	incoming.effects.append(ActiveEffect.new(CombatTypes.EffectKind.STAT_MOD, CombatTypes.Stat.ATTACK, 0.2, 2, 0, -1, 0))
	var events: Array[CombatEvent] = engine.submit_action(0, CombatAction.switch_to(0))
	_check(_has_event(events, CombatTypes.EventType.SWITCHED), "SWITCHED event emitted")
	_check(team.active[0] == incoming and team.bench[0] == leaver, "troops swapped slot <-> bench")
	_check(incoming.hp == 400 and incoming.cooldowns[2] == 3, "incoming keeps HP and cooldowns")
	_check(incoming.stat_modifier(CombatTypes.Stat.DEFENSE) == 0.0, "stat debuff cleansed on entry")
	_check(_near(incoming.stat_modifier(CombatTypes.Stat.ATTACK), 0.2), "buffs kept on entry")
	_check(team.energy == CombatTypes.SWITCH_ENERGY, "switch grants Team Energy")
	_check(team.slot_switch_cd[0] == 1, "slot gets 1-turn switch cooldown")
	# incoming (60 SPD, 50 CR) vs a1 (60 SPD, ~50 CR) vs foes (50 SPD, ~25 CR)
	var guard: int = 0
	while st.current_actor != incoming and guard < 20:
		var actor: TroopInstance = st.current_actor
		engine.submit_action(actor.side, CombatAction.cast(0, engine.valid_targets(actor, 0)[0]))
		guard += 1
	_check(st.current_actor == incoming, "incoming troop gets a turn")
	_check(not engine.can_switch(incoming), "cannot switch on first turn after switching in")
	_check(_is_rejected(engine.submit_action(0, CombatAction.switch_to(0))), "switch rejected during slot cooldown")
	engine.submit_action(0, CombatAction.cast(0, engine.valid_targets(incoming, 0)[0]))
	_check(team.slot_switch_cd[0] == 0, "slot cooldown clears after the incoming troop's turn")
	_sections_done += 1


func _test_caps_and_overdrive() -> void:
	print("[caps + overdrive]")
	var push_skill: SkillData = _make_skill(1, CombatTypes.TargetType.SELF, 2, 0.0, [
		_make_effect(CombatTypes.EffectKind.CR_CHANGE, CombatTypes.EffectTarget.SELF, 25.0),
		_make_effect(CombatTypes.EffectKind.CR_CHANGE, CombatTypes.EffectTarget.SELF, 25.0),
	])
	var od_skill: SkillData = _make_skill(2, CombatTypes.TargetType.SINGLE_ENEMY, 4, 1.0)
	od_skill.overdrive_kind = CombatTypes.OverdriveKind.REDUCE_COOLDOWN
	od_skill.overdrive_cost = 10
	od_skill.overdrive_value = 2.0
	var skills: Array[SkillData] = [_make_skill(0, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0), push_skill, od_skill]
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60], skills), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var a0: TroopInstance = st.current_actor
	var events: Array[CombatEvent] = engine.submit_action(0, CombatAction.cast(1, -1))
	var pushed: float = 0.0
	for e in events:
		if e.type == CombatTypes.EventType.CR_CHANGED and e.target == a0.uid:
			pushed += e.value
	_check(_near(pushed, 30.0), "two +25 pushes in one skill capped at +30 total (got %.1f)" % pushed)

	a0.effects.append(ActiveEffect.new(CombatTypes.EffectKind.STAT_MOD, CombatTypes.Stat.SPEED, 0.5, 3, 0, -1, 0))
	_check(_near(a0.get_stat(CombatTypes.Stat.SPEED), 300.0 * 1.3), "speed buff capped at +30%")
	a0.effects.clear()

	st.team(0).energy = 5
	while st.current_actor.side != 0:
		engine.submit_action(1, CombatAction.cast(0, engine.valid_targets(st.current_actor, 0)[0]))
	var actor: TroopInstance = st.current_actor
	var foe: int = engine.valid_targets(actor, 2)[0]
	_check(_is_rejected(engine.submit_action(0, CombatAction.cast(2, foe, true))), "overdrive rejected without enough energy")
	st.team(0).energy = 12
	engine.submit_action(0, CombatAction.cast(2, foe, true))
	_check(st.team(0).energy == 2, "overdrive spends its cost (12 - 10 = 2)")
	_check(actor.cooldowns[2] == 1, "REDUCE_COOLDOWN: 4 - 2 = 2, ticked to 1 at turn end (got %d)" % actor.cooldowns[2])

	# Extra turn
	var et_skill: SkillData = _make_skill(2, CombatTypes.TargetType.SINGLE_ENEMY, 4, 1.0)
	et_skill.overdrive_kind = CombatTypes.OverdriveKind.EXTRA_TURN
	et_skill.overdrive_cost = 15
	var et_skills: Array[SkillData] = [_make_skill(0, CombatTypes.TargetType.SINGLE_ENEMY, 0, 1.0), push_skill, et_skill]
	var e2: CombatEngine = _start(_dummy_squad("a", [100, 60, 60, 60, 60, 60], et_skills), _dummy_squad("b", [99, 99, 99, 99, 99, 99]))
	var hero: TroopInstance = e2.state.current_actor
	_check(hero.side == 0, "100 SPD acts before 99 SPD")
	e2.state.team(0).energy = 20
	var ev: Array[CombatEvent] = e2.submit_action(0, CombatAction.cast(2, e2.valid_targets(hero, 2)[0], true))
	_check(_has_event(ev, CombatTypes.EventType.EXTRA_TURN) and e2.state.current_actor == hero, "EXTRA_TURN overdrive grants an immediate turn")
	_sections_done += 1


func _test_standby_replacement() -> void:
	print("[standby]")
	var engine: CombatEngine = _start(_dummy_squad("a", [300, 60, 60, 60, 60, 60]), _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var st: CombatState = engine.state
	var victim: TroopInstance = st.team(1).active[1]
	victim.hp = 1
	var events: Array[CombatEvent] = engine.submit_action(0, CombatAction.cast(0, victim.uid))
	_check(_has_event(events, CombatTypes.EventType.KO), "KO emitted")
	_check(st.phase == CombatTypes.Phase.STANDBY, "engine pauses in STANDBY")
	_check(st.team(1).pending_slots == [1], "slot 1 pending for side B")
	_check(_is_rejected(engine.submit_action(0, CombatAction.cast(0, st.team(1).active[0].uid))), "actions rejected during STANDBY")
	_check(_is_rejected(engine.submit_replacement(1, 0, 0)), "replacement into a non-empty slot rejected")
	var incoming: TroopInstance = st.team(1).bench[1]
	engine.submit_replacement(1, 1, 1)
	_check(st.team(1).active[1] == incoming, "replacement enters the KO'd slot")
	_check(st.team(1).bench[1] == victim, "fallen troop moves to the bench")
	_check(st.phase == CombatTypes.Phase.ACTION_WAIT, "battle resumes after replacement")
	_check(incoming.cr >= CombatTypes.SWITCH_ENTRY_CR or st.current_actor == incoming, "replacement enters at 50% CR")
	_check(not st.team(1).is_bench_ready(1), "fallen troop cannot be switched back in")
	_sections_done += 1


func _test_passive_and_dual_attack_cap() -> void:
	print("[passives + dual attack]")
	var squad_a: Array[TroopData] = TroopRegistry.default_squad(0)
	var squad_b: Array[TroopData] = TroopRegistry.default_squad(1)
	_check(squad_a.size() == 6 and squad_b.size() == 6, "default squads have 6 troops")
	var all: Dictionary[StringName, TroopData] = TroopRegistry.load_all()
	_check(all.size() == 8, "roster has 8 troops")
	var per_arch: Dictionary = {}
	for d: TroopData in all.values():
		per_arch[d.archetype] = int(per_arch.get(d.archetype, 0)) + 1
		_check(d.skills.size() == 3, "%s has 3 skills" % d.display_name)
		_check(d.skills[0].cooldown == 0 and d.skills[0].dual_attack_chance <= CombatTypes.DUAL_ATTACK_CAP, "%s S1: no cooldown, dual <= cap" % d.display_name)
		var s2: SkillData = d.skills[1]
		_check(s2.is_passive or (s2.cooldown >= 2 and s2.cooldown <= 3), "%s S2 cooldown 2-3 or passive" % d.display_name)
		_check(not s2.is_passive or s2.cooldown > 0, "%s passive has an internal cooldown" % d.display_name)
		_check(d.skills[2].cooldown >= 4 and d.skills[2].cooldown <= 5, "%s S3 cooldown 4-5" % d.display_name)
	for arch in CombatTypes.Archetype.values():
		_check(per_arch.get(arch, 0) == 2, "2 troops in archetype %s" % CombatTypes.Archetype.keys()[arch])

	# Courier entry passive: +30% CR on switch-in => enters at 80%.
	var courier: TroopData = all[&"swift_courier"]
	var squad: Array[TroopData] = _dummy_squad("a", [300, 60, 60, 60, 60, 60])
	squad[2] = courier
	var engine: CombatEngine = _start(squad, _dummy_squad("b", [50, 50, 50, 50, 50, 50]))
	var team: TeamState = engine.state.team(0)
	var events: Array[CombatEvent] = engine.submit_action(0, CombatAction.switch_to(0))
	var c: TroopInstance = team.active[0]
	_check(c.data == courier, "courier switched in")
	_check(_has_event(events, CombatTypes.EventType.PASSIVE_TRIGGERED), "entry passive triggered")
	_check(team.energy == CombatTypes.SWITCH_ENERGY + 2, "switch energy + passive energy")
	_check(_near(c.cr, 80.0) or engine.state.current_actor == c, "courier entered at 50 + 30 CR")
	_check(c.passive_icd == 2, "passive internal cooldown set")
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
	print("  side A wins %d / side B wins %d, avg cycle %.1f, max cycle %d, frenzy reached in %d" % [wins[0], wins[1], float(total_cycles) / MATCH_SEEDS, max_cycle, frenzy_matches])
	var ids: Array = appearances.keys()
	ids.sort()
	for id: String in ids:
		print("  %-14s picked %2d  win rate %3d%%" % [id, appearances[id], roundi(100.0 * troop_wins.get(id, 0) / appearances[id])])
	_sections_done += 1


func _run_ai_match(seed_value: int) -> Dictionary:
	var engine: CombatEngine = CombatEngine.new(seed_value)
	var ais: Array[AIController] = [AIController.new(0, seed_value * 3), AIController.new(1, seed_value * 7)]
	engine.start_preview(TroopRegistry.default_squad(0), TroopRegistry.default_squad(1))
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
		var events: Array[CombatEvent] = []
		if st.phase == CombatTypes.Phase.FINISHED:
			return {"ok": true, "winner": st.winner, "cycle": st.cycle, "picks": picks}
		elif st.phase == CombatTypes.Phase.ACTION_WAIT:
			var side: int = st.current_actor.side
			events = engine.submit_action(side, ais[side].choose_action(engine))
		elif st.phase == CombatTypes.Phase.STANDBY:
			for side in 2:
				if not st.team(side).pending_slots.is_empty():
					events = engine.submit_replacement(side, st.team(side).pending_slots[0], ais[side].choose_replacement(engine))
					break
		else:
			return {"ok": false, "error": "stuck in phase %s" % CombatTypes.Phase.keys()[st.phase]}
		if _is_rejected(events):
			return {"ok": false, "error": "AI action rejected: %s" % events[0].data["reason"]}
		var err: String = _invariants(st)
		if err != "":
			return {"ok": false, "error": err}
	return {"ok": false, "error": "no winner after %d steps (cycle %d)" % [MAX_STEPS, st.cycle]}


func _invariants(st: CombatState) -> String:
	for t: TroopInstance in st.troops.values():
		if t.hp < 0 or t.hp > t.max_hp():
			return "%s hp out of range: %d" % [t.data.display_name, t.hp]
		if t.cr < 0.0 or t.cr > CombatTypes.CR_MAX + 0.001:
			return "%s cr out of range: %f" % [t.data.display_name, t.cr]
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
	var cached: TroopData = TroopRegistry.load_all()[&"ember_duelist"]
	var on_disk: TroopData = ResourceLoader.load(TroopRegistry.TROOP_DIR + "ember_duelist.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(cached.max_hp == on_disk.max_hp and cached.skills[0].cooldown == on_disk.skills[0].cooldown, "TroopData templates unchanged after matches")
	_sections_done += 1


func _event_trace(seed_value: int) -> Array[Dictionary]:
	var engine: CombatEngine = CombatEngine.new(seed_value)
	var ais: Array[AIController] = [AIController.new(0, 11), AIController.new(1, 13)]
	var trace: Array[Dictionary] = []
	for e in engine.start_preview(TroopRegistry.default_squad(0), TroopRegistry.default_squad(1)):
		trace.append(e.to_dict())
	for side in 2:
		for e in engine.submit_draft(side, ais[side].choose_draft(engine.state.team(side).squad)):
			trace.append(e.to_dict())
	var st: CombatState = engine.state
	for step in MAX_STEPS:
		var events: Array[CombatEvent] = []
		if st.phase == CombatTypes.Phase.ACTION_WAIT:
			events = engine.submit_action(st.current_actor.side, ais[st.current_actor.side].choose_action(engine))
		elif st.phase == CombatTypes.Phase.STANDBY:
			for side in 2:
				if not st.team(side).pending_slots.is_empty():
					events = engine.submit_replacement(side, st.team(side).pending_slots[0], ais[side].choose_replacement(engine))
					break
		else:
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
	server.start_match(77, TroopRegistry.default_squad(0), TroopRegistry.default_squad(1), no_ai, 0)
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
	# Human (side A) plays S1 on the first legal target; AI plays itself.
	var guard: int = 0
	while not server.is_finished() and guard < MAX_STEPS:
		guard += 1
		snap = last_snapshot[0]
		var st: CombatState = server.engine.state
		if st.phase == CombatTypes.Phase.ACTION_WAIT and st.current_actor.side == 0:
			var legal: Dictionary = snap["legal"]
			if guard < 3:
				_check(not legal.is_empty(), "legal actions present on human turn")
			var targets: Array = legal["skills"][0]["targets"]
			server.use_skill(0, 0, int(targets[0]))
		elif st.phase == CombatTypes.Phase.STANDBY and not st.team(0).pending_slots.is_empty():
			server.choose_replacement(0, st.team(0).pending_slots[0], st.team(0).first_ready_bench())
		server.client_ready()
	_check(server.is_finished(), "server-driven match finished (winner side %d, %d batches)" % [server.engine.state.winner, batches[0]])
	server.queue_free()
	_sections_done += 1
