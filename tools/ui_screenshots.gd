extends SceneTree
## Windowed UI capture: plays the draft and the first human turn, saving PNGs to res://renders/.
## Run (not headless): <godot console exe> --path D:\Game\random_project -s res://tools/ui_screenshots.gd

const OUT := "res://renders/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var client: BattleClient = load("res://src/client/main.tscn").instantiate()
	client.match_seed = 7
	root.add_child(client)
	_run(client)


func _run(client: BattleClient) -> void:
	await process_frame
	var ui: BattleUI = client.ui
	await _until(func() -> bool: return not ui.snapshot.is_empty())
	await _frames(20)
	_shot("1_draft")
	for i in CombatTypes.DRAFT_PICK:
		ui._on_draft_toggle(i)
	await _frames(5)
	_shot("2_draft_picked")
	ui._on_draft_lock()
	await _until(func() -> bool: return _my_turn(ui))
	await _frames(30)
	_shot("3_battle")
	var legal: Dictionary = ui.snapshot["legal"]
	var uids: Array = legal.keys()
	var first_uid: int = int(uids[0])
	ui.select_troop(first_uid)
	var skills: Array = legal[first_uid]["skills"]
	var target_skill_idx: int = -1
	for i in skills.size():
		if not (skills[i]["targets"] as Array).is_empty():
			target_skill_idx = i
			ui._on_skill_pressed(i)
			break
	await _frames(10)
	_shot("4_targeting")
	if target_skill_idx != -1:
		var targets: Array = skills[target_skill_idx]["targets"]
		ui._on_card_clicked(int(targets[0]))
	else:
		_pick_first_legal_action(ui, first_uid)
	for uid in legal:
		var uid_int: int = int(uid)
		if not ui._chosen_actions.has(uid_int):
			ui.select_troop(uid_int)
			_pick_first_legal_action(ui, uid_int)
	await _frames(10)
	ui._on_lock_actions_pressed()
	# Play out the match: pick actions for all troops, lock in, mid-battle shot after a few turns.
	ui.playback_speed = 3.0
	var turns: int = 0
	var standby_shot: bool = false
	while int(ui.snapshot.get("phase", -1)) != CombatTypes.Phase.FINISHED:
		await _until(func() -> bool: return _my_turn(ui) or int(ui.snapshot.get("phase", -1)) == CombatTypes.Phase.FINISHED or (ui._standby_panel.visible and not ui._input_locked))
		if ui._standby_panel.visible:
			if not standby_shot:
				standby_shot = true
				await _frames(20)
				_shot("5b_standby")
			(ui._standby_buttons.get_child(0) as Button).pressed.emit()
			continue
		if not _my_turn(ui):
			continue
		turns += 1
		if turns == 4:
			ui._toggle_log()
			await _frames(5)
			_shot("5_midbattle")
			ui._toggle_log()
		var leg: Dictionary = ui.snapshot.get("legal", {})
		for uid in leg:
			var uid_int: int = int(uid)
			ui.select_troop(uid_int)
			_pick_first_legal_action(ui, uid_int)
		ui._on_lock_actions_pressed()
		await _frames(2)
	await _frames(30)
	_shot("6_result")
	quit(0)


func _pick_first_legal_action(ui: BattleUI, uid: int) -> void:
	var entry: Dictionary = ui.snapshot["legal"][uid]
	var skills: Array = entry["skills"]
	for i in range(skills.size() - 1, -1, -1):
		if bool(skills[i]["ready"]):
			var targets: Array = skills[i]["targets"]
			if targets.is_empty():
				ui._choose_skill(uid, i, -1)
				return
			else:
				ui._choose_skill(uid, i, int(targets[0]))
				return
	if bool(entry["can_switch"]):
		var bench: Array = entry["bench"]
		for b_idx in bench:
			if not ui._is_bench_taken_by_other(int(b_idx), uid):
				ui._on_switch_pressed(int(b_idx))
				return


func _my_turn(ui: BattleUI) -> bool:
	if ui._input_locked:
		return false
	if int(ui.snapshot.get("phase", -1)) != CombatTypes.Phase.ACTION_WAIT:
		return false
	var leg: Dictionary = ui.snapshot.get("legal", {})
	if leg.is_empty():
		return false
	var mine_locked: bool = bool(ui.snapshot.get("teams", [{}, {}])[ui.viewer_side].get("actions_locked", false))
	return not mine_locked


func _until(cond: Callable) -> void:
	var waited: int = 0
	while not cond.call():
		await process_frame
		waited += 1
		if waited > 3000:
			push_error("ui_screenshots: timed out")
			quit(1)
			return


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(shot_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + shot_name + ".png"))
	print("saved ", shot_name)
