class_name BattleUI
extends Control
## Programmatic battle UI. Renders snapshots, animates event logs, and emits player intents.
## It never touches the engine: BattleClient forwards the intents to the server.

signal draft_submitted(picks: Array[int])
signal skill_requested(skill_index: int, target_uid: int, overdrive: bool)
signal switch_requested(bench_index: int)
signal replacement_requested(slot: int, bench_index: int)
signal restart_requested

const SIDE_COLORS: Array[Color] = [Color("#5fa8ff"), Color("#ff7a6b")]
const OVERDRIVE_NAMES: Array[String] = ["", "Ignore Resistance", "Reduce Cooldown", "Extra Turn", "Bonus Damage"]
const TARGET_NAMES: Array[String] = ["Single enemy", "All enemies", "Single ally", "Self", "Both allies"]

@export var playback_speed: float = 1.0

var viewer_side: int = CombatTypes.Side.A
var snapshot: Dictionary = {}

var _names: Dictionary = {}
var _sides: Dictionary = {}
var _energy: Array[int] = [0, 0]
var _cards: Array[TroopCard] = []
var _input_locked: bool = true
var _pending_skill: int = -1
var _draft_picks: Array[int] = []
var _draft_built: bool = false
var _draft_time_left: float = 0.0

var _status_label: Label
var _energy_label: Label
var _timeline_box: HBoxContainer
var _bench_labels: Array[Label] = []
var _skill_buttons: Array[Button] = []
var _overdrive_check: CheckBox
var _switch_buttons: Array[Button] = []
var _prompt_label: Label
var _log: RichTextLabel
var _draft_panel: PanelContainer
var _draft_grid: GridContainer
var _draft_buttons: Array[Button] = []
var _enemy_preview: VBoxContainer
var _draft_timer_label: Label
var _draft_status: Label
var _draft_lock: Button
var _standby_panel: PanelContainer
var _standby_label: Label
var _standby_buttons: HBoxContainer
var _result_panel: PanelContainer
var _result_label: Label


# =====================================================================
# Build
# =====================================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#11141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 16)
	add_child(margin)
	var root_row: HBoxContainer = HBoxContainer.new()
	root_row.add_theme_constant_override("separation", 16)
	margin.add_child(root_row)

	var field: VBoxContainer = VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 10)
	root_row.add_child(field)

	var top: HBoxContainer = HBoxContainer.new()
	field.add_child(top)
	_status_label = _label(top, 18)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy_label = _label(top, 16)

	var tl_row: HBoxContainer = HBoxContainer.new()
	tl_row.add_theme_constant_override("separation", 8)
	field.add_child(tl_row)
	_label(tl_row, 14).text = "Turn order:"
	_timeline_box = HBoxContainer.new()
	_timeline_box.add_theme_constant_override("separation", 6)
	tl_row.add_child(_timeline_box)

	for i in 4:
		_cards.append(null)
	_bench_labels = [null, null]
	_add_side_row(field, CombatTypes.other_side(viewer_side))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_child(spacer)
	_add_side_row(field, viewer_side)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	field.add_child(actions)
	for i in 3:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(190, 58)
		b.text = "S%d" % (i + 1)
		b.pressed.connect(_on_skill_pressed.bind(i))
		actions.add_child(b)
		_skill_buttons.append(b)
	_overdrive_check = CheckBox.new()
	_overdrive_check.text = "Overdrive"
	_overdrive_check.tooltip_text = "Spend Team Energy to empower the next skill (see each skill's tooltip)."
	actions.add_child(_overdrive_check)

	var switch_row: HBoxContainer = HBoxContainer.new()
	switch_row.add_theme_constant_override("separation", 8)
	field.add_child(switch_row)
	_label(switch_row, 14).text = "Switch:"
	for i in 2:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(220, 34)
		b.pressed.connect(_on_switch_pressed.bind(i))
		switch_row.add_child(b)
		_switch_buttons.append(b)
	_prompt_label = _label(field, 16)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(340, 0)
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_size_override("bold_font_size", 13)
	root_row.add_child(_log)

	_build_draft_panel()
	_build_standby_panel()
	_build_result_panel()
	_refresh_controls()


func _add_side_row(parent: Control, side: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var tag: Label = _label(row, 14)
	tag.text = "YOU" if side == viewer_side else "FOE"
	tag.add_theme_color_override("font_color", SIDE_COLORS[side])
	tag.custom_minimum_size = Vector2(40, 0)
	for slot in CombatTypes.ACTIVE_SLOTS:
		var card: TroopCard = TroopCard.new(side, slot)
		card.clicked.connect(_on_card_clicked)
		row.add_child(card)
		_cards[side * 2 + slot] = card
	var bench: Label = _label(row, 12)
	bench.custom_minimum_size = Vector2(170, 0)
	bench.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bench_labels[side] = bench


func _build_draft_panel() -> void:
	_draft_panel = _overlay(Color(0.05, 0.06, 0.09, 1.0), true)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_draft_panel.add_child(v)
	var title: Label = _label(v, 26)
	title.text = "TEAM PREVIEW — bring 6, pick 4"
	_draft_timer_label = _label(v, 16)
	_label(v, 14).text = "Click your troops in order: #1–#2 lead the field, #3–#4 wait on the bench. Hover for skills."
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left: VBoxContainer = VBoxContainer.new()
	cols.add_child(left)
	_label(left, 18).text = "Your squad"
	_draft_grid = GridContainer.new()
	_draft_grid.columns = 2
	_draft_grid.add_theme_constant_override("h_separation", 8)
	_draft_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(_draft_grid)
	var right: VBoxContainer = VBoxContainer.new()
	cols.add_child(right)
	_label(right, 18).text = "Opponent's squad (they will bring 4)"
	_enemy_preview = VBoxContainer.new()
	right.add_child(_enemy_preview)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	_draft_lock = Button.new()
	_draft_lock.text = "Lock In"
	_draft_lock.custom_minimum_size = Vector2(160, 44)
	_draft_lock.pressed.connect(_on_draft_lock)
	bottom.add_child(_draft_lock)
	_draft_status = _label(bottom, 15)


func _build_standby_panel() -> void:
	_standby_panel = _overlay(Color(0.08, 0.1, 0.15, 0.95), false)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_standby_panel.add_child(v)
	_standby_label = _label(v, 18)
	_standby_buttons = HBoxContainer.new()
	_standby_buttons.add_theme_constant_override("separation", 10)
	v.add_child(_standby_buttons)


func _build_result_panel() -> void:
	_result_panel = _overlay(Color(0.08, 0.1, 0.15, 0.95), false)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_result_panel.add_child(v)
	_result_label = _label(v, 30)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var again: Button = Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(200, 44)
	again.pressed.connect(func() -> void: restart_requested.emit())
	v.add_child(again)


func _overlay(color: Color, full: bool) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0 if full else 10)
	style.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", style)
	add_child(p)
	if full:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		p.grow_horizontal = Control.GROW_DIRECTION_BOTH
		p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	return p


# =====================================================================
# Public API (called by BattleClient)
# =====================================================================

func reset() -> void:
	snapshot = {}
	_names.clear()
	_sides.clear()
	_energy = [0, 0]
	_draft_picks.clear()
	_draft_built = false
	_pending_skill = -1
	for child in _draft_grid.get_children():
		child.queue_free()
	for child in _enemy_preview.get_children():
		child.queue_free()
	_draft_buttons.clear()
	for card in _cards:
		card.clear_card()
	_log.clear()
	_result_panel.visible = false
	_standby_panel.visible = false


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		_pending_skill = -1
	_refresh_controls()


## Plays one event; awaits a short beat for the ones that matter so logs read sequentially.
func play_event(e: Dictionary) -> void:
	var d: Dictionary = e["data"]
	var actor: int = int(e["actor"])
	var target: int = int(e["target"])
	var value: float = float(e["value"])
	var delay: float = 0.0
	match int(e["type"]):
		CombatTypes.EventType.PREVIEW_STARTED:
			_log_line("[b]Team Preview[/b] — pick 4 of your 6.")
		CombatTypes.EventType.DRAFT_LOCKED:
			_log_line("%s locked in their picks." % _side_name(int(d["side"])))
		CombatTypes.EventType.BATTLE_STARTED:
			_draft_panel.visible = false
			_log_line("[b]Battle start![/b]")
		CombatTypes.EventType.TROOP_ENTERED:
			_names[actor] = String(d["name"])
			_sides[actor] = int(d["side"])
			var card: TroopCard = _cards[int(d["side"]) * 2 + int(d["slot"])]
			card.bind(actor, String(d["name"]), int(d["archetype"]))
			card.set_hp(int(d["hp"]), int(d["max_hp"]), int(d["shield"]))
			card.set_cr(float(d["cr"]))
			card.set_effects([], [])
			card.float_text("Enter", Color.WHITE)
			_log_line("%s enters the field (%d%% CR)." % [_cn(actor), roundi(value)])
			delay = 0.3
		CombatTypes.EventType.TIMELINE_ADVANCED:
			var crs: Dictionary = d["cr"]
			for uid: int in crs:
				var c: TroopCard = _card_for(uid)
				if c != null:
					c.set_cr(float(crs[uid]))
		CombatTypes.EventType.CYCLE_ADVANCED:
			_log_line("[color=#7d8597]— Cycle %d —[/color]" % int(value))
		CombatTypes.EventType.FRENZY_CHANGED:
			_log_line("[color=#ff5050][b]BATTLE FRENZY x%d[/b] — damage x%.2f, healing x%.2f[/color]" % [int(value), float(d["damage_mult"]), float(d["heal_mult"])])
			delay = 0.3
		CombatTypes.EventType.TURN_STARTED:
			_highlight_actor(actor)
		CombatTypes.EventType.TURN_SKIPPED:
			_float(actor, "Stunned", Color("#b7a6ff"))
			_log_line("%s is stunned and loses the turn." % _cn(actor))
			delay = 0.4
		CombatTypes.EventType.SKILL_USED:
			var od: String = " [color=#ffd24a](Overdrive)[/color]" if bool(d["overdrive"]) else ""
			var on: String = " on %s" % _cn(target) if target != -1 else ""
			_log_line("%s uses [b]%s[/b]%s%s." % [_cn(actor), String(d["skill_name"]), on, od])
			var c2: TroopCard = _card_for(actor)
			if c2 != null:
				c2.flash(Color(1.6, 1.5, 0.8))
			delay = 0.25
		CombatTypes.EventType.OVERDRIVE_ACTIVATED:
			_float(actor, "OVERDRIVE", Color("#ffd24a"))
		CombatTypes.EventType.DAMAGE:
			var c3: TroopCard = _card_for(target)
			if c3 != null:
				c3.update_hp(int(d["hp_after"]), int(d["shield_after"]))
				c3.flash(Color(1.8, 0.6, 0.6))
			var crit: bool = bool(d["crit"])
			_float(target, ("-%d!" if crit else "-%d") % int(value), Color("#ff6b6b") if not crit else Color("#ffb347"))
			var src: String = "Burn" if String(d["tag"]) == "dot" else _n(actor)
			var absorbed: String = " (%d absorbed)" % int(d["absorbed"]) if int(d["absorbed"]) > 0 else ""
			_log_line("  %s → %s: [color=#ff8080]%d[/color]%s%s" % [src, _cn(target), int(value), " CRIT" if crit else "", absorbed])
			delay = 0.35
		CombatTypes.EventType.HEAL:
			var c4: TroopCard = _card_for(target)
			if c4 != null:
				c4.update_hp(int(d["hp_after"]))
			_float(target, "+%d" % int(value), Color("#6be38a"))
			_log_line("  %s heals %s for [color=#80ff9a]%d[/color]" % [_cn(actor), _cn(target), int(value)])
			delay = 0.2
		CombatTypes.EventType.EFFECT_APPLIED:
			var fx: String = TroopCard.effect_text(d)
			_float(target, fx, Color("#ff9f80") if bool(d["debuff"]) else Color("#9fd4ff"))
			_log_line("  %s: %s (%d turns)" % [_cn(target), fx, int(d["duration"])])
			delay = 0.15
		CombatTypes.EventType.EFFECT_RESISTED:
			_float(target, "Resist", Color("#c0c0c0"))
			_log_line("  %s resisted." % _cn(target))
			delay = 0.15
		CombatTypes.EventType.EFFECT_EXPIRED, CombatTypes.EventType.TURN_ENDED, CombatTypes.EventType.ACTION_REQUESTED:
			pass
		CombatTypes.EventType.CLEANSED:
			_float(target, "Cleansed", Color("#9fd4ff"))
		CombatTypes.EventType.CR_CHANGED:
			var c5: TroopCard = _card_for(target)
			if c5 != null:
				c5.set_cr(float(d["cr_after"]))
			_float(target, "CR %+d%%" % roundi(value), Color("#e8c547"))
			delay = 0.1
		CombatTypes.EventType.ENERGY_CHANGED:
			_energy[int(d["side"])] = int(value)
			_refresh_status()
		CombatTypes.EventType.DUAL_ATTACK:
			_float(actor, "Dual Attack!", Color("#ffd24a"))
			_log_line("%s joins with a [b]Dual Attack[/b]!" % _cn(actor))
			delay = 0.2
		CombatTypes.EventType.PASSIVE_TRIGGERED:
			_float(actor, String(d["skill_name"]), Color("#9fd4ff"))
			_log_line("  [i]%s — %s[/i]" % [_cn(actor), String(d["skill_name"])])
			delay = 0.25
		CombatTypes.EventType.SWITCHED:
			_names[target] = String(d["incoming_name"])
			_sides[target] = int(d["side"])
			_log_line("%s pulls back; %s steps in." % [_cn(actor), _cn(target)])
			delay = 0.2
		CombatTypes.EventType.KO:
			_float(actor, "KO", Color("#ff4040"))
			var c6: TroopCard = _card_for(actor)
			if c6 != null:
				c6.modulate = Color(1, 1, 1, 0.35)
			_log_line("[color=#ff5050]%s is knocked out![/color]" % _cn(actor))
			delay = 0.45
		CombatTypes.EventType.EXTRA_TURN:
			_float(actor, "Extra Turn!", Color("#ffd24a"))
			_log_line("%s takes an extra turn!" % _cn(actor))
		CombatTypes.EventType.STANDBY_REQUESTED:
			_log_line("[color=#e8c547]Standby — fill the empty slot from the bench.[/color]")
		CombatTypes.EventType.REPLACED:
			_names[actor] = String(d["name"])
			_sides[actor] = int(d["side"])
			_log_line("%s sends in %s." % [_side_name(int(d["side"])), _cn(actor)])
		CombatTypes.EventType.BATTLE_ENDED:
			_log_line("[b]%s wins after %d cycles.[/b]" % [_side_name(int(d["winner"])), int(d["cycle"])])
		CombatTypes.EventType.ACTION_REJECTED:
			if int(d["side"]) == viewer_side or int(d["side"]) == -1:
				_prompt("Rejected: %s" % String(d["reason"]), Color("#ff6b6b"))
	if delay > 0.0 and is_inside_tree():
		await get_tree().create_timer(delay / maxf(playback_speed, 0.01)).timeout


## Authoritative reconciliation after each log batch.
func apply_snapshot(snap: Dictionary) -> void:
	snapshot = snap
	var troops: Dictionary = snap["troops"]
	for uid: int in troops:
		_names[uid] = String(troops[uid]["name"])
		_sides[uid] = int(troops[uid]["side"])
	var teams: Array = snap["teams"]
	_energy = [int(teams[0]["energy"]), int(teams[1]["energy"])]
	var phase: int = int(snap["phase"])
	if phase == CombatTypes.Phase.PREVIEW:
		_show_draft(snap)
	else:
		_draft_panel.visible = false
	_refresh_field()
	_refresh_status()
	_refresh_timeline()
	_refresh_controls()
	_result_panel.visible = phase == CombatTypes.Phase.FINISHED
	if _result_panel.visible:
		var won: bool = int(snap["winner"]) == viewer_side
		_result_label.text = "VICTORY" if won else "DEFEAT"
		_result_label.add_theme_color_override("font_color", Color("#6be38a") if won else Color("#ff6b6b"))


# =====================================================================
# Refresh
# =====================================================================

func _refresh_field() -> void:
	var troops: Dictionary = snapshot["troops"]
	var teams: Array = snapshot["teams"]
	for side in 2:
		var team: Dictionary = teams[side]
		var active: Array = team["active"]
		for slot in CombatTypes.ACTIVE_SLOTS:
			var card: TroopCard = _cards[side * 2 + slot]
			var uid: int = int(active[slot]) if slot < active.size() else -1
			if uid < 0 or not troops.has(uid):
				card.clear_card()
				continue
			var t: Dictionary = troops[uid]
			card.bind(uid, String(t["name"]), int(t["archetype"]))
			card.set_hp(int(t["hp"]), int(t["max_hp"]), int(t["shield"]))
			card.set_cr(float(t["cr"]))
			card.set_effects(t["effects"], t["cooldowns"])
		var lines: PackedStringArray = ["Bench:"]
		for b in team["bench"]:
			var buid: int = int(b)
			if buid == -2:
				lines.append("• ???")
			elif buid >= 0 and troops.has(buid):
				var bt: Dictionary = troops[buid]
				lines.append("• %s  %s" % [bt["name"], "KO" if not bool(bt["alive"]) else "%d%%" % roundi(100.0 * int(bt["hp"]) / int(bt["max_hp"]))])
		_bench_labels[side].text = "\n".join(lines)


func _refresh_status() -> void:
	if snapshot.is_empty():
		_status_label.text = "ET"
		return
	var phase: int = int(snapshot["phase"])
	var text: String = "Team Preview" if phase == CombatTypes.Phase.PREVIEW else "Cycle %d  ·  Turn %d" % [int(snapshot["cycle"]), int(snapshot["turn"])]
	var frenzy: int = int(snapshot["frenzy_stacks"])
	if frenzy > 0:
		text += "   BATTLE FRENZY x%d (+%d%% dmg, -%d%% heal)" % [frenzy, frenzy * 5, frenzy * 5]
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color("#ff6060") if frenzy > 0 else Color.WHITE)
	_energy_label.text = "Energy  You %d/%d   Foe %d/%d" % [_energy[viewer_side], CombatTypes.ENERGY_CAP, _energy[1 - viewer_side], CombatTypes.ENERGY_CAP]


func _refresh_timeline() -> void:
	for child in _timeline_box.get_children():
		child.queue_free()
	var troops: Dictionary = snapshot.get("troops", {})
	for uid in snapshot.get("timeline", []):
		if not troops.has(uid):
			continue
		var l: Label = _label(_timeline_box, 13)
		l.text = String(troops[uid]["name"])
		l.add_theme_color_override("font_color", SIDE_COLORS[int(troops[uid]["side"])])


func _refresh_controls() -> void:
	if _skill_buttons.is_empty():
		return
	var phase: int = int(snapshot.get("phase", CombatTypes.Phase.PREVIEW))
	var legal: Dictionary = snapshot.get("legal", {})
	var my_turn: bool = not _input_locked and phase == CombatTypes.Phase.ACTION_WAIT and not legal.is_empty()
	for i in _skill_buttons.size():
		var b: Button = _skill_buttons[i]
		if not my_turn:
			b.disabled = true
			b.text = "S%d" % (i + 1)
			b.tooltip_text = ""
			continue
		var info: Dictionary = legal["skills"][i]
		var state_text: String = "Passive" if bool(info["passive"]) else ("Ready" if bool(info["ready"]) else "Cooldown %d" % int(info["cooldown_left"]))
		b.text = "S%d  %s\n%s" % [i + 1, String(info["name"]), state_text]
		b.disabled = not bool(info["ready"])
		var od_kind: int = int(info["overdrive_kind"])
		var od_text: String = "\nOverdrive: %s (%d Energy)%s" % [OVERDRIVE_NAMES[od_kind], int(info["overdrive_cost"]), "" if bool(info["can_overdrive"]) else " — not enough Energy"] if od_kind != 0 else ""
		b.tooltip_text = "%s\nTarget: %s%s" % [String(info["description"]), TARGET_NAMES[int(info["target_type"])], od_text]
	_overdrive_check.disabled = not my_turn
	_overdrive_check.text = "Overdrive (%d/%d)" % [_energy[viewer_side], CombatTypes.ENERGY_CAP]

	var bench_ids: Array = snapshot["teams"][viewer_side]["bench"] if snapshot.has("teams") else []
	var switchable: Array = legal.get("bench", [])
	for i in _switch_buttons.size():
		var b: Button = _switch_buttons[i]
		var uid: int = int(bench_ids[i]) if i < bench_ids.size() else -1
		b.text = "→ %s" % _n(uid) if uid >= 0 else "—"
		b.disabled = not my_turn or not switchable.has(i)

	var pending: Array = snapshot["teams"][viewer_side]["pending_slots"] if snapshot.has("teams") else []
	_standby_panel.visible = not _input_locked and phase == CombatTypes.Phase.STANDBY and not pending.is_empty()
	if _standby_panel.visible:
		_fill_standby(int(pending[0]))

	if my_turn:
		var actor: int = int(legal["actor"])
		_prompt("Your turn: %s — pick a skill or switch." % _n(actor), Color.WHITE)
		_highlight_actor(actor)
	elif phase == CombatTypes.Phase.ACTION_WAIT:
		_prompt("Opponent is acting…" if not legal.has("actor") else "…", Color("#a0a8b8"))
	elif phase == CombatTypes.Phase.STANDBY and pending.is_empty():
		_prompt("Opponent is choosing a replacement…", Color("#a0a8b8"))
	elif phase != CombatTypes.Phase.STANDBY:
		_prompt("", Color.WHITE)


func _fill_standby(slot: int) -> void:
	_standby_label.text = "Standby — choose who fills slot %d" % (slot + 1)
	for child in _standby_buttons.get_children():
		child.queue_free()
	var team: Dictionary = snapshot["teams"][viewer_side]
	var troops: Dictionary = snapshot["troops"]
	var bench: Array = team["bench"]
	for i in bench.size():
		var uid: int = int(bench[i])
		if uid < 0 or not troops.has(uid) or not bool(troops[uid]["alive"]):
			continue
		var t: Dictionary = troops[uid]
		var b: Button = Button.new()
		b.text = "%s\n%d / %d HP" % [t["name"], int(t["hp"]), int(t["max_hp"])]
		b.custom_minimum_size = Vector2(200, 56)
		b.pressed.connect(func() -> void:
			set_input_locked(true)
			replacement_requested.emit(slot, i))
		_standby_buttons.add_child(b)


func _show_draft(snap: Dictionary) -> void:
	_draft_panel.visible = true
	var teams: Array = snap["teams"]
	var mine: Dictionary = teams[viewer_side]
	if not _draft_built:
		_draft_built = true
		_draft_time_left = CombatTypes.DRAFT_SECONDS
		var squad: Array = mine["squad"]
		for i in squad.size():
			var b: Button = Button.new()
			b.custom_minimum_size = Vector2(300, 64)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = _squad_tooltip(squad[i])
			b.pressed.connect(_on_draft_toggle.bind(i))
			_draft_grid.add_child(b)
			_draft_buttons.append(b)
		for s: Dictionary in teams[1 - viewer_side]["squad"]:
			var l: Label = _label(_enemy_preview, 14)
			l.text = "%s  [%s]   HP %d  ATK %d  DEF %d  SPD %d" % [s["name"], TroopCard.ARCHETYPE_NAMES[int(s["archetype"])], s["max_hp"], s["attack"], s["defense"], s["speed"]]
			l.tooltip_text = _squad_tooltip(s)
			l.mouse_filter = Control.MOUSE_FILTER_PASS
	_refresh_draft()


func _refresh_draft() -> void:
	if snapshot.is_empty():
		return
	var mine: Dictionary = snapshot["teams"][viewer_side]
	var squad: Array = mine["squad"]
	var locked: bool = bool(mine["locked"])
	for i in _draft_buttons.size():
		var s: Dictionary = squad[i]
		var order: int = _draft_picks.find(i)
		var tag: String = "" if order == -1 else ("#%d LEAD   " % (order + 1) if order < 2 else "#%d BENCH   " % (order + 1))
		_draft_buttons[i].text = "%s%s  [%s]\nHP %d  ATK %d  DEF %d  SPD %d" % [tag, s["name"], TroopCard.ARCHETYPE_NAMES[int(s["archetype"])], s["max_hp"], s["attack"], s["defense"], s["speed"]]
		_draft_buttons[i].disabled = locked
		_draft_buttons[i].modulate = Color("#ffe58a") if order != -1 else Color.WHITE
	_draft_lock.disabled = locked or _draft_picks.size() != CombatTypes.DRAFT_PICK
	var opp_locked: bool = bool(snapshot["teams"][1 - viewer_side]["locked"])
	_draft_status.text = ("Locked in. " if locked else "%d / %d picked. " % [_draft_picks.size(), CombatTypes.DRAFT_PICK]) + ("Opponent is ready." if opp_locked else "Opponent is choosing…")


func _squad_tooltip(s: Dictionary) -> String:
	var lines: PackedStringArray = []
	for sk: Dictionary in s["skills"]:
		lines.append("S%d %s%s: %s" % [int(sk["slot"]) + 1, sk["name"], " (passive)" if bool(sk["passive"]) else " (CD %d)" % int(sk["cooldown"]), sk["description"]])
	return "\n".join(lines)


# =====================================================================
# Input
# =====================================================================

func _process(delta: float) -> void:
	if _draft_panel != null and _draft_panel.visible and not snapshot.is_empty() and not bool(snapshot["teams"][viewer_side]["locked"]):
		_draft_time_left = maxf(0.0, _draft_time_left - delta)
		_draft_timer_label.text = "Time left: %ds (auto-picks the first 4 when it runs out)" % ceili(_draft_time_left)


func _unhandled_input(event: InputEvent) -> void:
	if _pending_skill != -1 and event.is_action_pressed("ui_cancel"):
		_pending_skill = -1
		_refresh_controls()
		_clear_target_highlights()


func _on_draft_toggle(index: int) -> void:
	if _draft_picks.has(index):
		_draft_picks.erase(index)
	elif _draft_picks.size() < CombatTypes.DRAFT_PICK:
		_draft_picks.append(index)
	_refresh_draft()


func _on_draft_lock() -> void:
	if _draft_picks.size() == CombatTypes.DRAFT_PICK:
		set_input_locked(true)
		draft_submitted.emit(_draft_picks.duplicate())


func _on_skill_pressed(index: int) -> void:
	var info: Dictionary = snapshot["legal"]["skills"][index]
	var targets: Array = info["targets"]
	if targets.is_empty():
		_send_skill(index, -1)
		return
	_pending_skill = index
	_clear_target_highlights()
	for card in _cards:
		if targets.has(card.uid):
			card.set_highlight(2)
	_prompt("Choose a target for %s (Esc to cancel)." % String(info["name"]), Color("#ffb3b3"))


func _on_card_clicked(uid: int) -> void:
	if _pending_skill == -1 or _input_locked:
		return
	var targets: Array = snapshot["legal"]["skills"][_pending_skill]["targets"]
	if targets.has(uid):
		_send_skill(_pending_skill, uid)


func _send_skill(index: int, target_uid: int) -> void:
	var info: Dictionary = snapshot["legal"]["skills"][index]
	var overdrive: bool = _overdrive_check.button_pressed and bool(info["can_overdrive"])
	_overdrive_check.button_pressed = false
	_clear_target_highlights()
	set_input_locked(true)
	skill_requested.emit(index, target_uid, overdrive)


func _on_switch_pressed(bench_index: int) -> void:
	_clear_target_highlights()
	set_input_locked(true)
	switch_requested.emit(bench_index)


# =====================================================================
# Helpers
# =====================================================================

func _card_for(uid: int) -> TroopCard:
	for card in _cards:
		if card.uid == uid:
			return card
	return null


func _highlight_actor(uid: int) -> void:
	for card in _cards:
		card.set_highlight(1 if card.uid == uid and uid != -1 else 0)


func _clear_target_highlights() -> void:
	_highlight_actor(int(snapshot.get("current_actor", -1)))


func _float(uid: int, text: String, color: Color) -> void:
	var card: TroopCard = _card_for(uid)
	if card != null and card.is_inside_tree():
		card.float_text(text, color)


func _n(uid: int) -> String:
	if uid == -2:
		return "???"
	return String(_names.get(uid, "?"))


## Side-colored name for the log (mirror matches are otherwise ambiguous).
func _cn(uid: int) -> String:
	if not _sides.has(uid):
		return _n(uid)
	return "[color=#%s]%s[/color]" % [SIDE_COLORS[int(_sides[uid])].to_html(false), _n(uid)]


func _side_name(side: int) -> String:
	return "You" if side == viewer_side else "Opponent"


func _prompt(text: String, color: Color) -> void:
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", color)


func _log_line(bbcode: String) -> void:
	_log.append_text(bbcode + "\n")


func _label(parent: Control, font_size: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l
