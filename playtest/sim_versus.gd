extends SceneTree
## Versus simulation script: squad_gemini vs squad_gemini2
## Usage: godot --headless --path D:\Game\random_project -s res://playtest/sim_versus.gd

const SQUAD_G1_PATH: String = "res://playtest/squad_gemini.json"
const SQUAD_G2_PATH: String = "res://playtest/squad_gemini2.json"
const MATCH_PAIRS: int = 250  # 250 pairs = 500 matches (>= 400 matches)
const SEED_START: int = 50000
const MAX_STEPS: int = 3000

func _initialize() -> void:
	print("=== VERSUS PLAYTEST SIMULATION START ===")
	var g1_ids: Array[StringName] = _load_squad_ids(SQUAD_G1_PATH)
	var g2_ids: Array[StringName] = _load_squad_ids(SQUAD_G2_PATH)

	if g1_ids.is_empty() or g2_ids.is_empty():
		push_error("Failed to load squads: G1 size=%d, G2 size=%d" % [g1_ids.size(), g2_ids.size()])
		quit(1)
		return

	print("Squad Gemini 1: ", g1_ids)
	print("Squad Gemini 2: ", g2_ids)

	var g1_troops: Array[TroopData] = TroopRegistry.build_squad(g1_ids)
	var g2_troops: Array[TroopData] = TroopRegistry.build_squad(g2_ids)

	var total_matches: int = MATCH_PAIRS * 2
	var g1_wins_total: int = 0
	var g2_wins_total: int = 0
	var side_a_wins_total: int = 0
	var side_b_wins_total: int = 0

	# Swapped condition trackers
	var g1_wins_as_side_a: int = 0
	var g1_matches_as_side_a: int = 0
	var g2_wins_as_side_a: int = 0
	var g2_matches_as_side_a: int = 0

	var total_cycles: int = 0
	var min_cycle: int = 9999
	var max_cycle: int = 0
	var frenzy_matches: int = 0

	# Per troop stats: troop_id -> {picked: int, won: int, damage: int, kos: int, deaths: int}
	var g1_troop_stats: Dictionary = {}
	for tid in g1_ids:
		g1_troop_stats[String(tid)] = {"picked": 0, "won": 0, "damage": 0, "kos": 0, "deaths": 0}

	var g2_troop_stats: Dictionary = {}
	for tid in g2_ids:
		g2_troop_stats[String(tid)] = {"picked": 0, "won": 0, "damage": 0, "kos": 0, "deaths": 0}

	var tie_break_opportunities: int = 0

	print("\nRunning %d matches (paired seeds %d to %d with side-swapping)..." % [
		total_matches, SEED_START, SEED_START + MATCH_PAIRS - 1
	])

	for i in MATCH_PAIRS:
		var seed_val: int = SEED_START + i

		# --- Match 1: G1 on Side 0 (Side A), G2 on Side 1 (Side B) ---
		var res1: Dictionary = _play_match(g1_troops, g2_troops, seed_val)
		if res1.get("ok", false):
			var w1: int = res1["winner"]
			var c1: int = res1["cycle"]
			total_cycles += c1
			min_cycle = mini(min_cycle, c1)
			max_cycle = maxi(max_cycle, c1)
			if c1 > CombatTypes.FRENZY_START_CYCLE:
				frenzy_matches += 1

			g1_matches_as_side_a += 1
			if w1 == 0:
				g1_wins_total += 1
				side_a_wins_total += 1
				g1_wins_as_side_a += 1
			else:
				g2_wins_total += 1
				side_b_wins_total += 1

			_record_match_stats(res1, "g1", "g2", w1, g1_troop_stats, g2_troop_stats)
			tie_break_opportunities += int(res1.get("speed_ties", 0))

		# --- Match 2: G2 on Side 0 (Side A), G1 on Side 1 (Side B) ---
		var res2: Dictionary = _play_match(g2_troops, g1_troops, seed_val)
		if res2.get("ok", false):
			var w2: int = res2["winner"]
			var c2: int = res2["cycle"]
			total_cycles += c2
			min_cycle = mini(min_cycle, c2)
			max_cycle = maxi(max_cycle, c2)
			if c2 > CombatTypes.FRENZY_START_CYCLE:
				frenzy_matches += 1

			g2_matches_as_side_a += 1
			if w2 == 0:
				g2_wins_total += 1
				side_a_wins_total += 1
				g2_wins_as_side_a += 1
			else:
				g1_wins_total += 1
				side_b_wins_total += 1

			_record_match_stats(res2, "g2", "g1", w2, g2_troop_stats, g1_troop_stats)
			tie_break_opportunities += int(res2.get("speed_ties", 0))

	# Print comprehensive results
	print("\n================== SIMULATION RESULTS ==================")
	print("Total Matches: %d (%d seed pairs)" % [total_matches, MATCH_PAIRS])
	print("Gemini 1 Wins: %d (%.2f%%)" % [g1_wins_total, 100.0 * g1_wins_total / total_matches])
	print("Gemini 2 Wins: %d (%.2f%%)" % [g2_wins_total, 100.0 * g2_wins_total / total_matches])
	print("Side A (Side 0) Wins: %d (%.2f%%) | Side B (Side 1) Wins: %d (%.2f%%)" % [
		side_a_wins_total, 100.0 * side_a_wins_total / total_matches,
		side_b_wins_total, 100.0 * side_b_wins_total / total_matches
	])

	print("\n--- SIDE A BIAS ANALYSIS (SWAPPED SIDES) ---")
	print("When G1 on Side A (G2 on Side B): G1 won %d/%d (%.2f%%) | G2 won %d/%d (%.2f%%)" % [
		g1_wins_as_side_a, g1_matches_as_side_a, 100.0 * g1_wins_as_side_a / g1_matches_as_side_a,
		g1_matches_as_side_a - g1_wins_as_side_a, g1_matches_as_side_a, 100.0 * (g1_matches_as_side_a - g1_wins_as_side_a) / g1_matches_as_side_a
	])
	print("When G2 on Side A (G1 on Side B): G2 won %d/%d (%.2f%%) | G1 won %d/%d (%.2f%%)" % [
		g2_wins_as_side_a, g2_matches_as_side_a, 100.0 * g2_wins_as_side_a / g2_matches_as_side_a,
		g2_matches_as_side_a - g2_wins_as_side_a, g2_matches_as_side_a, 100.0 * (g2_matches_as_side_a - g2_wins_as_side_a) / g2_matches_as_side_a
	])
	print("Total observed opposing active speed-tie events: %d" % tie_break_opportunities)

	print("\n--- PACING ---")
	print("Rounds: Avg = %.2f | Min = %d | Max = %d | Frenzy (>15) = %d (%.2f%%)" % [
		float(total_cycles) / float(total_matches),
		min_cycle, max_cycle,
		frenzy_matches, 100.0 * frenzy_matches / total_matches
	])

	print("\n--- GEMINI 1 TROOP PERFORMANCE ---")
	print("%-16s %7s %7s %7s %7s %9s %8s %7s" % [
		"Troop", "Matches", "Picked", "Pick%", "Win%", "Avg Dmg", "Avg KOs", "Deaths"
	])
	var g1_keys: Array = g1_troop_stats.keys()
	g1_keys.sort()
	for tid in g1_keys:
		var st: Dictionary = g1_troop_stats[tid]
		var picked: int = st["picked"]
		var pick_pct: float = 100.0 * picked / total_matches
		var win_pct: float = (100.0 * st["won"] / picked) if picked > 0 else 0.0
		var avg_dmg: float = (float(st["damage"]) / picked) if picked > 0 else 0.0
		var avg_kos: float = (float(st["kos"]) / picked) if picked > 0 else 0.0
		print("%-16s %7d %7d %6.1f%% %6.1f%% %9.1f %8.2f %7d" % [
			tid, total_matches, picked, pick_pct, win_pct, avg_dmg, avg_kos, st["deaths"]
		])

	print("\n--- GEMINI 2 TROOP PERFORMANCE ---")
	print("%-16s %7s %7s %7s %7s %9s %8s %7s" % [
		"Troop", "Matches", "Picked", "Pick%", "Win%", "Avg Dmg", "Avg KOs", "Deaths"
	])
	var g2_keys: Array = g2_troop_stats.keys()
	g2_keys.sort()
	for tid in g2_keys:
		var st: Dictionary = g2_troop_stats[tid]
		var picked: int = st["picked"]
		var pick_pct: float = 100.0 * picked / total_matches
		var win_pct: float = (100.0 * st["won"] / picked) if picked > 0 else 0.0
		var avg_dmg: float = (float(st["damage"]) / picked) if picked > 0 else 0.0
		var avg_kos: float = (float(st["kos"]) / picked) if picked > 0 else 0.0
		print("%-16s %7d %7d %6.1f%% %6.1f%% %9.1f %8.2f %7d" % [
			tid, total_matches, picked, pick_pct, win_pct, avg_dmg, avg_kos, st["deaths"]
		])

	print("=== VERSUS PLAYTEST SIMULATION COMPLETE ===")
	quit(0)


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

	var uid_info: Dictionary = {}
	for uid in engine.state.troops:
		var inst: TroopInstance = engine.state.get_troop(uid)
		uid_info[uid] = {"side": inst.side, "id": String(inst.data.troop_id)}

	var st: CombatState = engine.state
	var all_events: Array[CombatEvent] = []
	var speed_ties: int = 0
	var last_damager: Dictionary = {}

	for step in MAX_STEPS:
		if st.phase == CombatTypes.Phase.FINISHED:
			return {
				"ok": true,
				"winner": st.winner,
				"cycle": st.cycle,
				"picks": picks,
				"events": all_events,
				"uid_info": uid_info,
				"last_damager": last_damager,
				"speed_ties": speed_ties
			}
		if st.phase != CombatTypes.Phase.ACTION_WAIT and st.phase != CombatTypes.Phase.STANDBY:
			return {"ok": false, "error": "Stuck in phase: %d" % st.phase}

		# Check speed ties right before actions are locked/resolved
		if st.phase == CombatTypes.Phase.ACTION_WAIT:
			var actives_0: Array[TroopInstance] = st.actives(0)
			var actives_1: Array[TroopInstance] = st.actives(1)
			for t0 in actives_0:
				for t1 in actives_1:
					if absf(t0.get_stat(CombatTypes.Stat.SPEED) - t1.get_stat(CombatTypes.Stat.SPEED)) <= CombatTypes.EPSILON:
						speed_ties += 1

		var evs: Array[CombatEvent] = _ai_step(engine, ais)
		all_events.append_array(evs)
		for ev in evs:
			if ev.type == CombatTypes.EventType.DAMAGE:
				if ev.actor != -1:
					last_damager[ev.target] = ev.actor

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


func _record_match_stats(res: Dictionary, side0_team_name: String, side1_team_name: String, winner: int, side0_stats: Dictionary, side1_stats: Dictionary) -> void:
	var picks0: Array = res["picks"][0]
	var picks1: Array = res["picks"][1]
	var uid_info: Dictionary = res["uid_info"]
	var last_damager: Dictionary = res["last_damager"]

	# Picks & wins
	for tid in picks0:
		side0_stats[tid]["picked"] += 1
		if winner == 0:
			side0_stats[tid]["won"] += 1
	for tid in picks1:
		side1_stats[tid]["picked"] += 1
		if winner == 1:
			side1_stats[tid]["won"] += 1

	# Damage, KOs, Deaths
	for ev in res["events"]:
		if ev.type == CombatTypes.EventType.DAMAGE:
			var src_uid: int = ev.actor
			var val: int = int(ev.value)
			if src_uid != -1 and uid_info.has(src_uid):
				var info: Dictionary = uid_info[src_uid]
				if info["side"] == 0:
					side0_stats[info["id"]]["damage"] += val
				else:
					side1_stats[info["id"]]["damage"] += val
		elif ev.type == CombatTypes.EventType.KO:
			var dead_uid: int = ev.actor
			if uid_info.has(dead_uid):
				var d_info: Dictionary = uid_info[dead_uid]
				if d_info["side"] == 0:
					side0_stats[d_info["id"]]["deaths"] += 1
				else:
					side1_stats[d_info["id"]]["deaths"] += 1
				if last_damager.has(dead_uid):
					var k_uid: int = last_damager[dead_uid]
					if uid_info.has(k_uid):
						var k_info: Dictionary = uid_info[k_uid]
						if k_info["side"] == 0:
							side0_stats[k_info["id"]]["kos"] += 1
						else:
							side1_stats[k_info["id"]]["kos"] += 1


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

