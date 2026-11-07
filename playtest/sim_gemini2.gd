extends SceneTree
## Playtest simulation script for gemini2 vs gemini
## Usage: godot --headless --path D:\Game\random_project -s res://playtest/sim_gemini2.gd

const SQUAD_GEMINI_PATH: String = "res://playtest/squad_gemini.json"
const SQUAD_GEMINI2_PATH: String = "res://playtest/squad_gemini2.json"
const MAX_STEPS: int = 3000

func _initialize() -> void:
	print("--- GEMINI 2 PLAYTEST SIMULATION START ---")
	var gemini_ids: Array[StringName] = _load_squad_ids(SQUAD_GEMINI_PATH)
	if gemini_ids.is_empty():
		print("Warning: squad_gemini.json not found or empty, using random squad")
		var rnd: Array[TroopData] = TroopRegistry.random_squad(42)
		for t in rnd:
			gemini_ids.append(t.troop_id)
	print("Gemini 1 squad: ", gemini_ids)

	var candidate_data: Dictionary = {
		"Candidate 16 (Tide + Sentinel + Bastion + Courier + Fox)": [
			"tide_caller", "tide_warden", "forge_sentinel", "forge_bastion", "storm_courier", "void_fox"
		],
		"Candidate 19 (Double Tide + Double Void + Sentinel + Courier)": [
			"tide_caller", "tide_warden", "forge_sentinel", "storm_courier", "void_fox", "void_weaver"
		],
		"Candidate 20 (Triple Tide + Sentinel + Courier + Fox)": [
			"tide_caller", "tide_warden", "tide_oracle", "forge_sentinel", "storm_courier", "void_fox"
		],
		"Candidate 21 (Tide + Double Storm + Sentinel + Fox)": [
			"tide_caller", "tide_warden", "storm_courier", "storm_lancer", "forge_sentinel", "void_fox"
		],
		"Candidate 22 (Tide + Storm + Sentinel + Fox + Reaver)": [
			"tide_caller", "tide_warden", "forge_sentinel", "storm_courier", "void_fox", "ember_reaver"
		]
	}

	var best_name: String = ""
	var best_squad: Array[StringName] = []
	var best_winrate: float = -1.0

	print("\nEvaluating 10 candidate squads (60 matches each: 30 side A, 30 side B)...")
	for c_name: String in candidate_data:
		var raw_list: Array = candidate_data[c_name]
		var c_ids: Array[StringName] = []
		for item in raw_list:
			c_ids.append(StringName(str(item)))
		var wr: float = _evaluate_matchup(c_ids, gemini_ids, 30)
		print("  %s: Win rate = %.1f%%" % [c_name, wr * 100.0])
		if wr > best_winrate:
			best_winrate = wr
			best_name = c_name
			best_squad = c_ids

	print("\nSelected Best Squad: %s (Win rate: %.1f%%)" % [best_name, best_winrate * 100.0])
	print("Best squad IDs: ", best_squad)

	# Save squad_gemini2.json
	_save_squad_ids(SQUAD_GEMINI2_PATH, best_squad)
	print("Saved best squad to: %s" % SQUAD_GEMINI2_PATH)

	# Now run the comprehensive tournament: 120 match pairs (240 matches total >= 200 matches)
	print("\nRunning comprehensive tournament: 120 seeds (240 matches with side swap)...")
	_run_tournament(best_squad, gemini_ids, 120)

	print("--- SIMULATION COMPLETE ---")
	quit(0)


func _load_squad_ids(path: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if not FileAccess.file_exists(path):
		return out
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var json_res = JSON.parse_string(file.get_as_text())
	if json_res is Array:
		for item in json_res:
			out.append(StringName(str(item)))
	return out


func _save_squad_ids(path: String, ids: Array[StringName]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for write: " + path)
		return
	var str_array: Array[String] = []
	for id in ids:
		str_array.append(String(id))
	file.store_string(JSON.stringify(str_array, "  ") + "\n")
	file.close()


func _evaluate_matchup(squad_g2: Array[StringName], squad_g1: Array[StringName], pair_count: int) -> float:
	var g2_troops: Array[TroopData] = TroopRegistry.build_squad(squad_g2)
	var g1_troops: Array[TroopData] = TroopRegistry.build_squad(squad_g1)
	var g2_wins: int = 0
	var total_matches: int = pair_count * 2

	for i in pair_count:
		var seed_base: int = 20000 + i * 17
		# Game 1: G2 on Side 0, G1 on Side 1
		var res1: Dictionary = _play_match(g2_troops, g1_troops, seed_base)
		if res1.get("ok", false) and res1["winner"] == 0:
			g2_wins += 1

		# Game 2: G1 on Side 0, G2 on Side 1
		var res2: Dictionary = _play_match(g1_troops, g2_troops, seed_base)
		if res2.get("ok", false) and res2["winner"] == 1:
			g2_wins += 1

	return float(g2_wins) / float(total_matches)


func _play_match(squad_a: Array[TroopData], squad_b: Array[TroopData], seed_value: int) -> Dictionary:
	var engine: CombatEngine = CombatEngine.new(seed_value)
	var ais: Array[AIController] = [
		AIController.new(0, seed_value * 3 + 1),
		AIController.new(1, seed_value * 7 + 2)
	]
	engine.start_preview(squad_a, squad_b)
	var picks: Array = [[], []]
	for side in 2:
		var p: Array[int] = ais[side].choose_draft(engine.state.team(side).squad)
		for idx in p:
			picks[side].append(String(engine.state.team(side).squad[idx].troop_id))
		var ev: Array[CombatEvent] = engine.submit_draft(side, p)
		if ev.size() == 1 and ev[0].type == CombatTypes.EventType.ACTION_REJECTED:
			return {"ok": false, "error": "Draft rejected: " + str(ev[0].data)}

	var st: CombatState = engine.state
	var all_events: Array[CombatEvent] = []
	for step in MAX_STEPS:
		if st.phase == CombatTypes.Phase.FINISHED:
			return {
				"ok": true,
				"winner": st.winner,
				"cycle": st.cycle,
				"picks": picks,
				"events": all_events
			}
		if st.phase != CombatTypes.Phase.ACTION_WAIT and st.phase != CombatTypes.Phase.STANDBY:
			return {"ok": false, "error": "Stuck in phase: %d" % st.phase}

		var evs: Array[CombatEvent] = _ai_step(engine, ais)
		all_events.append_array(evs)

	return {"ok": false, "error": "Exceeded max steps"}


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


func _run_tournament(squad_g2: Array[StringName], squad_g1: Array[StringName], pair_count: int) -> void:
	var g2_troops: Array[TroopData] = TroopRegistry.build_squad(squad_g2)
	var g1_troops: Array[TroopData] = TroopRegistry.build_squad(squad_g1)

	var total_matches: int = pair_count * 2
	var g2_wins: int = 0
	var g1_wins: int = 0
	var side_a_wins: int = 0
	var side_b_wins: int = 0

	var total_cycles: int = 0
	var min_cycle: int = 9999
	var max_cycle: int = 0
	var frenzy_matches: int = 0

	var g2_picks: Dictionary = {}
	var g2_troop_wins: Dictionary = {}
	var g1_picks: Dictionary = {}
	var g1_troop_wins: Dictionary = {}

	# Metric tracking
	var skill_usage: Dictionary = {}
	var overdrives_used: Dictionary = {}
	var stuns_applied: int = 0
	var dual_attacks: int = 0
	var passives_triggered: Dictionary = {}
	var switches_performed: int = 0
	var kos_per_troop: Dictionary = {}

	for i in pair_count:
		var seed_base: int = 50000 + i * 31

		# Game 1: G2 on Side 0, G1 on Side 1
		var res1: Dictionary = _play_match(g2_troops, g1_troops, seed_base)
		if res1.get("ok", false):
			var w1: int = res1["winner"]
			var c1: int = res1["cycle"]
			total_cycles += c1
			min_cycle = mini(min_cycle, c1)
			max_cycle = maxi(max_cycle, c1)
			if c1 > CombatTypes.FRENZY_START_CYCLE:
				frenzy_matches += 1
			if w1 == 0:
				g2_wins += 1
				side_a_wins += 1
			else:
				g1_wins += 1
				side_b_wins += 1

			for id in res1["picks"][0]:
				g2_picks[id] = int(g2_picks.get(id, 0)) + 1
				if w1 == 0:
					g2_troop_wins[id] = int(g2_troop_wins.get(id, 0)) + 1
			for id in res1["picks"][1]:
				g1_picks[id] = int(g1_picks.get(id, 0)) + 1
				if w1 == 1:
					g1_troop_wins[id] = int(g1_troop_wins.get(id, 0)) + 1

			_tally_events(res1["events"], skill_usage, overdrives_used, kos_per_troop, passives_triggered)

		# Game 2: G1 on Side 0, G2 on Side 1
		var res2: Dictionary = _play_match(g1_troops, g2_troops, seed_base)
		if res2.get("ok", false):
			var w2: int = res2["winner"]
			var c2: int = res2["cycle"]
			total_cycles += c2
			min_cycle = mini(min_cycle, c2)
			max_cycle = maxi(max_cycle, c2)
			if c2 > CombatTypes.FRENZY_START_CYCLE:
				frenzy_matches += 1
			if w2 == 1:
				g2_wins += 1
				side_b_wins += 1
			else:
				g1_wins += 1
				side_a_wins += 1

			for id in res2["picks"][0]:
				g1_picks[id] = int(g1_picks.get(id, 0)) + 1
				if w2 == 0:
					g1_troop_wins[id] = int(g1_troop_wins.get(id, 0)) + 1
			for id in res2["picks"][1]:
				g2_picks[id] = int(g2_picks.get(id, 0)) + 1
				if w2 == 1:
					g2_troop_wins[id] = int(g2_troop_wins.get(id, 0)) + 1

			_tally_events(res2["events"], skill_usage, overdrives_used, kos_per_troop, passives_triggered)

	print("\n================== TOURNAMENT RESULTS ==================")
	print("Total matches: %d (Pairs: %d with side swap)" % [total_matches, pair_count])
	print("Gemini 2 wins: %d (%.1f%%)" % [g2_wins, 100.0 * float(g2_wins) / float(total_matches)])
	print("Gemini 1 wins: %d (%.1f%%)" % [g1_wins, 100.0 * float(g1_wins) / float(total_matches)])
	print("Side A (First/Lower UID) wins: %d (%.1f%%) | Side B wins: %d (%.1f%%)" % [
		side_a_wins, 100.0 * float(side_a_wins) / float(total_matches),
		side_b_wins, 100.0 * float(side_b_wins) / float(total_matches)
	])
	print("Rounds: Avg = %.2f, Min = %d, Max = %d, Frenzy matches = %d (%.1f%%)" % [
		float(total_cycles) / float(total_matches),
		min_cycle, max_cycle,
		frenzy_matches, 100.0 * float(frenzy_matches) / float(total_matches)
	])

	print("\n--- Gemini 2 Troop Performance ---")
	var g2_keys: Array = g2_picks.keys()
	g2_keys.sort()
	for id in g2_keys:
		var p_cnt: int = g2_picks[id]
		var w_cnt: int = int(g2_troop_wins.get(id, 0))
		print("  %-16s picked %3d/%d (%4.1f%%)  win rate %4.1f%%" % [
			id, p_cnt, total_matches, 100.0 * float(p_cnt) / float(total_matches),
			100.0 * float(w_cnt) / float(p_cnt) if p_cnt > 0 else 0.0
		])

	print("\n--- Gemini 1 Troop Performance ---")
	var g1_keys: Array = g1_picks.keys()
	g1_keys.sort()
	for id in g1_keys:
		var p_cnt: int = g1_picks[id]
		var w_cnt: int = int(g1_troop_wins.get(id, 0))
		print("  %-16s picked %3d/%d (%4.1f%%)  win rate %4.1f%%" % [
			id, p_cnt, total_matches, 100.0 * float(p_cnt) / float(total_matches),
			100.0 * float(w_cnt) / float(p_cnt) if p_cnt > 0 else 0.0
		])

	print("\n--- Top Skills Used ---")
	var skill_keys: Array = skill_usage.keys()
	skill_keys.sort_custom(func(a, b): return skill_usage[a] > skill_usage[b])
	for i in mini(15, skill_keys.size()):
		var k = skill_keys[i]
		print("  %-25s used %4d times" % [k, skill_usage[k]])

	print("\n--- Overdrives Used ---")
	var od_keys: Array = overdrives_used.keys()
	od_keys.sort_custom(func(a, b): return overdrives_used[a] > overdrives_used[b])
	for k in od_keys:
		print("  %-25s OD used %4d times" % [k, overdrives_used[k]])

	print("\n--- Passives Triggered ---")
	var p_keys: Array = passives_triggered.keys()
	p_keys.sort_custom(func(a, b): return passives_triggered[a] > passives_triggered[b])
	for k in p_keys:
		print("  %-25s triggered %4d times" % [k, passives_triggered[k]])


func _tally_events(events: Array[CombatEvent], skills: Dictionary, ods: Dictionary, kills: Dictionary, passives: Dictionary) -> void:
	for e in events:
		if e.type == CombatTypes.EventType.SKILL_USED:
			var s_name: String = str(e.data.get("skill_name", "Unknown"))
			skills[s_name] = int(skills.get(s_name, 0)) + 1
		elif e.type == CombatTypes.EventType.OVERDRIVE_ACTIVATED:
			var kind: int = int(e.data.get("kind", 0))
			var kind_str: String = CombatTypes.OverdriveKind.keys()[kind] if kind < CombatTypes.OverdriveKind.size() else str(kind)
			ods[kind_str] = int(ods.get(kind_str, 0)) + 1
		elif e.type == CombatTypes.EventType.PASSIVE_TRIGGERED:
			var trigger: int = int(e.data.get("trigger", 0))
			var tr_str: String = CombatTypes.Trigger.keys()[trigger] if trigger < CombatTypes.Trigger.size() else str(trigger)
			passives[tr_str] = int(passives.get(tr_str, 0)) + 1
		elif e.type == CombatTypes.EventType.KO:
			var victim_id: int = e.actor
			kills[victim_id] = int(kills.get(victim_id, 0)) + 1
