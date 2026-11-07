extends SceneTree
## Headless playtest simulation: Gemini squad vs Opponent (Muse if present, else TroopRegistry.random_squad).
## Swaps sides every match to cancel speed-tie edge. Run:
## godot --headless --path D:\Game\random_project -s res://playtest/playtest_sim.gd

const MATCH_COUNT: int = 400
const MAX_STEPS: int = 3000
const SQUAD_GEMINI_PATH: String = "res://playtest/squad_gemini.json"
const SQUAD_MUSE_PATH: String = "res://playtest/squad_muse.json"
const RESULTS_JSON_PATH: String = "res://playtest/sim_results.json"


func _initialize() -> void:
	var gemini_ids: Array[StringName] = _load_squad_ids(SQUAD_GEMINI_PATH)
	if gemini_ids.is_empty():
		push_error("Failed to load Gemini squad from " + SQUAD_GEMINI_PATH)
		quit(1)
		return

	var muse_ids: Array[StringName] = _load_squad_ids(SQUAD_MUSE_PATH)
	if muse_ids.is_empty():
		muse_ids = _load_squad_ids("res://playtest/squad_gemini2.json")
	var opponent_name: String = "Muse"
	var static_opponent: bool = true
	if muse_ids.is_empty():
		opponent_name = "RandomSquad"
		static_opponent = false
		print("squad_muse.json not found; using TroopRegistry.random_squad for opponent.")
	else:
		print("Loaded Muse squad: ", muse_ids)

	var squad_gemini: Array[TroopData] = TroopRegistry.build_squad(gemini_ids)
	var squad_muse: Array[TroopData] = []
	if static_opponent:
		squad_muse = TroopRegistry.build_squad(muse_ids)

	print("Running %d matches: Gemini vs %s (alternating sides)" % [MATCH_COUNT, opponent_name])

	var gemini_wins: int = 0
	var opponent_wins: int = 0
	var side_a_wins: int = 0
	var side_b_wins: int = 0
	var total_rounds: int = 0
	var max_rounds: int = 0
	var min_rounds: int = 9999
	var frenzy_matches: int = 0
	var round_distribution: Dictionary = {}

	# Per-troop stats separated by team
	# structure: team -> troop_id -> {brought: int, picked: int, won: int, damage: int, kos: int, deaths: int}
	var team_stats: Dictionary = {
		"gemini": {},
		"opponent": {}
	}

	for d in squad_gemini:
		team_stats["gemini"][String(d.troop_id)] = {
			"brought": 0, "picked": 0, "won": 0, "damage": 0, "kos": 0, "deaths": 0
		}

	for m in range(MATCH_COUNT):
		var seed_val: int = 30000 + m
		var opp_squad: Array[TroopData] = squad_muse if static_opponent else TroopRegistry.random_squad(seed_val * 13)

		# Record 'brought' for both teams
		for d in squad_gemini:
			team_stats["gemini"][String(d.troop_id)]["brought"] += 1
		for d in opp_squad:
			var tid: String = String(d.troop_id)
			if not team_stats["opponent"].has(tid):
				team_stats["opponent"][tid] = {
					"brought": 0, "picked": 0, "won": 0, "damage": 0, "kos": 0, "deaths": 0
				}
			team_stats["opponent"][tid]["brought"] += 1

		# Even m: Gemini is side 0 (A), Opponent is side 1 (B)
		# Odd m: Opponent is side 0 (A), Gemini is side 1 (B)
		var gemini_side: int = 0 if (m % 2 == 0) else 1
		var opp_side: int = 1 - gemini_side

		var squads: Array = [[], []]
		squads[gemini_side] = squad_gemini
		squads[opp_side] = opp_squad

		var engine: CombatEngine = CombatEngine.new(seed_val)
		var ais: Array[AIController] = [
			AIController.new(0, seed_val * 3 + 1),
			AIController.new(1, seed_val * 7 + 2)
		]
		engine.start_preview(squads[0], squads[1])

		# Draft pick-4
		var chosen_ids: Array = [[], []]
		for s in 2:
			var picks: Array[int] = ais[s].choose_draft(engine.state.team(s).squad)
			engine.submit_draft(s, picks)
			var team_key: String = "gemini" if (s == gemini_side) else "opponent"
			for idx in picks:
				var tdata: TroopData = engine.state.team(s).squad[idx]
				var tid: String = String(tdata.troop_id)
				chosen_ids[s].append(tid)
				team_stats[team_key][tid]["picked"] += 1

		# Map instance UID to (team_key, troop_id)
		var uid_info: Dictionary = {}
		for uid in engine.state.troops:
			var inst: TroopInstance = engine.state.get_troop(uid)
			var t_key: String = "gemini" if (inst.side == gemini_side) else "opponent"
			uid_info[uid] = {"team": t_key, "id": String(inst.data.troop_id)}

		var st: CombatState = engine.state
		var guard: int = 0
		var last_damager: Dictionary = {} # target_uid -> source_uid

		while st.phase != CombatTypes.Phase.FINISHED and guard < MAX_STEPS:
			guard += 1
			var step_events: Array[CombatEvent] = []
			if st.phase == CombatTypes.Phase.ACTION_WAIT:
				for s in 2:
					if st.phase == CombatTypes.Phase.ACTION_WAIT and not st.team(s).actions_locked:
						step_events.append_array(engine.submit_actions(s, ais[s].choose_actions(engine)))
			elif st.phase == CombatTypes.Phase.STANDBY:
				for s in 2:
					if not st.team(s).pending_slots.is_empty():
						var bench_idx: int = ais[s].choose_replacement(engine)
						step_events.append_array(engine.submit_replacement(s, st.team(s).pending_slots[0], bench_idx))
						break

			for ev in step_events:
				if ev.type == CombatTypes.EventType.DAMAGE:
					var src_uid: int = ev.actor
					var val: int = int(ev.value)
					var tgt_uid: int = ev.target
					if src_uid != -1 and uid_info.has(src_uid):
						var s_info: Dictionary = uid_info[src_uid]
						team_stats[s_info["team"]][s_info["id"]]["damage"] += val
						last_damager[tgt_uid] = src_uid
				elif ev.type == CombatTypes.EventType.KO:
					var dead_uid: int = ev.actor
					if uid_info.has(dead_uid):
						var d_info: Dictionary = uid_info[dead_uid]
						team_stats[d_info["team"]][d_info["id"]]["deaths"] += 1
						if last_damager.has(dead_uid):
							var k_uid: int = last_damager[dead_uid]
							if uid_info.has(k_uid):
								var k_info: Dictionary = uid_info[k_uid]
								team_stats[k_info["team"]][k_info["id"]]["kos"] += 1

		if st.phase != CombatTypes.Phase.FINISHED:
			printerr("Match %d did not terminate!" % m)
			continue

		var winner: int = st.winner
		if winner == 0:
			side_a_wins += 1
		else:
			side_b_wins += 1

		var is_gemini_win: bool = (winner == gemini_side)
		if is_gemini_win:
			gemini_wins += 1
		else:
			opponent_wins += 1

		# Win count for picked troops
		for s in 2:
			var t_key: String = "gemini" if (s == gemini_side) else "opponent"
			var won: bool = (s == winner)
			if won:
				for tid: String in chosen_ids[s]:
					team_stats[t_key][tid]["won"] += 1

		total_rounds += st.cycle
		max_rounds = maxi(max_rounds, st.cycle)
		min_rounds = mini(min_rounds, st.cycle)
		if st.cycle > CombatTypes.FRENZY_START_CYCLE:
			frenzy_matches += 1
		round_distribution[st.cycle] = int(round_distribution.get(st.cycle, 0)) + 1

	var avg_rounds: float = float(total_rounds) / MATCH_COUNT
	var gemini_wr: float = 100.0 * gemini_wins / MATCH_COUNT
	var opp_wr: float = 100.0 * opponent_wins / MATCH_COUNT
	var side_a_wr: float = 100.0 * side_a_wins / MATCH_COUNT
	var side_b_wr: float = 100.0 * side_b_wins / MATCH_COUNT

	print("\n=================== SIMULATION RESULTS ===================")
	print("Matches: %d | Gemini vs %s" % [MATCH_COUNT, opponent_name])
	print("Gemini: %d wins (%.1f%%) | %s: %d wins (%.1f%%)" % [gemini_wins, gemini_wr, opponent_name, opponent_wins, opp_wr])
	print("Side A (First): %d wins (%.1f%%) | Side B (Second): %d wins (%.1f%%)" % [side_a_wins, side_a_wr, side_b_wins, side_b_wr])
	print("Rounds: avg %.2f | min %d | max %d | Frenzy (>15): %d (%.1f%%)" % [
		avg_rounds, min_rounds, max_rounds, frenzy_matches, 100.0 * frenzy_matches / MATCH_COUNT
	])

	print("\n--- GEMINI SQUAD STATS ---")
	print("%-16s %7s %7s %7s %7s %9s %8s %7s" % [
		"Troop", "Brought", "Picked", "Pick%", "Win%", "Avg Dmg", "Avg KOs", "Deaths"
	])
	for tid in team_stats["gemini"]:
		var data: Dictionary = team_stats["gemini"][tid]
		var brought: int = data["brought"]
		var picked: int = data["picked"]
		var pick_pct: float = (100.0 * picked / brought) if brought > 0 else 0.0
		var win_pct: float = (100.0 * data["won"] / picked) if picked > 0 else 0.0
		var avg_dmg: float = (float(data["damage"]) / picked) if picked > 0 else 0.0
		var avg_kos: float = (float(data["kos"]) / picked) if picked > 0 else 0.0
		print("%-16s %7d %7d %6.1f%% %6.1f%% %9.1f %8.2f %7d" % [
			tid, brought, picked, pick_pct, win_pct, avg_dmg, avg_kos, data["deaths"]
		])

	print("\n--- OPPONENT ROSTER STATS ---")
	print("%-16s %7s %7s %7s %7s %9s %8s %7s" % [
		"Troop", "Brought", "Picked", "Pick%", "Win%", "Avg Dmg", "Avg KOs", "Deaths"
	])
	var opp_keys: Array = team_stats["opponent"].keys()
	opp_keys.sort()
	for tid in opp_keys:
		var data: Dictionary = team_stats["opponent"][tid]
		var brought: int = data["brought"]
		var picked: int = data["picked"]
		var pick_pct: float = (100.0 * picked / brought) if brought > 0 else 0.0
		var win_pct: float = (100.0 * data["won"] / picked) if picked > 0 else 0.0
		var avg_dmg: float = (float(data["damage"]) / picked) if picked > 0 else 0.0
		var avg_kos: float = (float(data["kos"]) / picked) if picked > 0 else 0.0
		print("%-16s %7d %7d %6.1f%% %6.1f%% %9.1f %8.2f %7d" % [
			tid, brought, picked, pick_pct, win_pct, avg_dmg, avg_kos, data["deaths"]
		])

	# Write results json
	var save_dict: Dictionary = {
		"matches": MATCH_COUNT,
		"opponent_name": opponent_name,
		"gemini_wins": gemini_wins,
		"opponent_wins": opponent_wins,
		"gemini_wr": gemini_wr,
		"side_a_wins": side_a_wins,
		"side_b_wins": side_b_wins,
		"avg_rounds": avg_rounds,
		"min_rounds": min_rounds,
		"max_rounds": max_rounds,
		"frenzy_matches": frenzy_matches,
		"round_distribution": round_distribution,
		"team_stats": team_stats
	}
	var f: FileAccess = FileAccess.open(RESULTS_JSON_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(save_dict, "  "))
		f.close()
		print("Saved simulation results to " + RESULTS_JSON_PATH)

	print("==========================================================")
	quit(0)


func _load_squad_ids(path: String) -> Array[StringName]:
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var json_str: String = f.get_as_text()
	f.close()
	var test_json: JSON = JSON.new()
	var err: Error = test_json.parse(json_str)
	if err != OK:
		printerr("JSON parse error on %s: %s" % [path, test_json.get_error_message()])
		return []
	var data = test_json.data
	var out: Array[StringName] = []
	if typeof(data) == TYPE_ARRAY:
		for item in data:
			out.append(StringName(String(item)))
	elif typeof(data) == TYPE_DICTIONARY:
		var list = data.get("squad", data.get("troops", []))
		for item in list:
			out.append(StringName(String(item)))
	return out
