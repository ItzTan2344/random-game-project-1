extends SceneTree
## Balance probe: random 6-troop squads from the roster, AI vs AI. Picks are random 4 of 6 (not the AI's draft) so every troop is sampled evenly. Prints per-troop pick count and win rate.
## Run: godot --headless -s res://tools/balance_sim.gd [-- N [SEED]]

const DEFAULT_MATCHES: int = 600


func _initialize() -> void:
	var matches: int = DEFAULT_MATCHES
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		matches = int(args[0])
	var all: Array[TroopData] = []
	for d: TroopData in TroopRegistry.load_all().values():
		all.append(d)
	all.sort_custom(func(a: TroopData, b: TroopData) -> bool: return String(a.troop_id) < String(b.troop_id))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 12345
	var picked: Dictionary = {}
	var won: Dictionary = {}
	var side_wins: Array[int] = [0, 0]
	var rounds: int = 0
	for m in matches:
		var squads: Array = [_squad(all, rng), _squad(all, rng)]
		var engine: CombatEngine = CombatEngine.new(m)
		var ais: Array[AIController] = [AIController.new(0, m * 3 + 1), AIController.new(1, m * 7 + 2)]
		engine.start_preview(squads[0], squads[1])
		var chosen: Array = [[], []]
		for side in 2:
			var p: Array[int] = _random_picks(rng)
			for i in p:
				chosen[side].append(String(squads[side][i].troop_id))
			engine.submit_draft(side, p)
		var st: CombatState = engine.state
		var guard: int = 0
		while st.phase != CombatTypes.Phase.FINISHED and guard < 3000:
			guard += 1
			if st.phase == CombatTypes.Phase.ACTION_WAIT:
				for side in 2:
					if st.phase == CombatTypes.Phase.ACTION_WAIT and not st.team(side).actions_locked:
						engine.submit_actions(side, ais[side].choose_actions(engine))
			elif st.phase == CombatTypes.Phase.STANDBY:
				for side in 2:
					if not st.team(side).pending_slots.is_empty():
						engine.submit_replacement(side, st.team(side).pending_slots[0], ais[side].choose_replacement(engine))
						break
		if st.phase != CombatTypes.Phase.FINISHED:
			continue
		side_wins[st.winner] += 1
		rounds += st.cycle
		for side in 2:
			for id: String in chosen[side]:
				picked[id] = int(picked.get(id, 0)) + 1
				if side == st.winner:
					won[id] = int(won.get(id, 0)) + 1
	print("matches %d  side A %d / side B %d  avg rounds %.1f" % [matches, side_wins[0], side_wins[1], float(rounds) / matches])
	var ids: Array = picked.keys()
	ids.sort()
	for id: String in ids:
		print("  %-14s picked %4d  win %3d%%" % [id, picked[id], roundi(100.0 * int(won.get(id, 0)) / picked[id])])
	quit(0)


func _squad(all: Array[TroopData], rng: RandomNumberGenerator) -> Array[TroopData]:
	var pool: Array[TroopData] = all.duplicate()
	var out: Array[TroopData] = []
	for i in CombatTypes.DRAFT_BRING:
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func _random_picks(rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = [0, 1, 2, 3, 4, 5]
	var out: Array[int] = []
	for i in CombatTypes.DRAFT_PICK:
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out
