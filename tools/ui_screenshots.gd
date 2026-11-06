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
	var skills: Array = ui.snapshot["legal"]["skills"]
	for i in skills.size():
		if not (skills[i]["targets"] as Array).is_empty():
			ui._on_skill_pressed(i)
			break
	await _frames(10)
	_shot("4_targeting")
	# Play out the match: first ready skill on its first target, mid-battle shot after a few turns.
	ui.playback_speed = 3.0
	var turns: int = 0
	var standby_shot: bool = false
	while int(ui.snapshot["phase"]) != CombatTypes.Phase.FINISHED:
		await _until(func() -> bool: return _my_turn(ui) or int(ui.snapshot["phase"]) == CombatTypes.Phase.FINISHED or (ui._standby_panel.visible and not ui._input_locked))
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
		if turns == 6:
			ui._toggle_log()
			await _frames(5)
			_shot("5_midbattle")
			ui._toggle_log()
		var legal: Array = ui.snapshot["legal"]["skills"]
		for i in range(legal.size() - 1, -1, -1):
			if bool(legal[i]["ready"]):
				var targets: Array = legal[i]["targets"]
				ui._send_skill(i, int(targets[0]) if not targets.is_empty() else -1)
				break
		await _frames(2)
	await _frames(30)
	_shot("6_result")
	quit(0)


func _my_turn(ui: BattleUI) -> bool:
	return not ui._input_locked and int(ui.snapshot.get("phase", -1)) == CombatTypes.Phase.ACTION_WAIT and not (ui.snapshot.get("legal", {}) as Dictionary).is_empty()


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
