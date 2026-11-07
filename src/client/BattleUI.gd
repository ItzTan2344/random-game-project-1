class_name BattleUI
extends Control
## Programmatic battle UI. Renders snapshots, animates event logs, and emits player intents.
## It never touches the engine: BattleClient forwards the intents to the server.

signal draft_submitted(picks: Array[int])
signal actions_locked(actions: Dictionary)
signal replacement_requested(slot: int, bench_index: int)
signal restart_requested
signal squad_chosen(ids: Array[StringName])

const SIDE_COLORS: Array[Color] = [Color("#5fa8ff"), Color("#ff7a6b")]
const OVERDRIVE_NAMES: Array[String] = ["", "Guarantee Effects", "Reduce Cooldown", "Act First", "Bonus Damage"]
const TARGET_NAMES: Array[String] = ["Single enemy", "All enemies", "Single ally", "Self", "Both allies"]

@export var playback_speed: float = 0.65 # <1 = slower; event delays are divided by this

var viewer_side: int = CombatTypes.Side.A
var snapshot: Dictionary = {}

var _names: Dictionary = {}
var _sides: Dictionary = {}
var _energy: Array[int] = [0, 0]
var _cards: Array[TroopCard] = []
var _stage: BattleStage
var _input_locked: bool = true
var _pending_skill: int = -1
var _selected_troop_uid: int = -1
var _chosen_actions: Dictionary = {}
var _acting_actor: int = -1
var _timeline_order: Array = []
var _draft_picks: Array[int] = []
var _draft_built: bool = false
var _draft_time_left: float = 0.0
var _float_stack: Dictionary = {}
var _damage: Dictionary = {}
var _portraits: Portraits

var _status_label: Label
var _frenzy_box: HBoxContainer
var _energy_bars: Array[ProgressBar] = [null, null]
var _energy_labels: Array[Label] = [null, null]
var _timeline_box: HBoxContainer
var _bench_boxes: Array[HBoxContainer] = [null, null]
var _skill_buttons: Array[Button] = []
var _overdrive_button: Button
var _lock_button: Button
var _switch_buttons: Array[Button] = []
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _log_panel: PanelContainer
var _log: RichTextLabel
var _float_layer: Control
var _squad_panel: PanelContainer
var _squad_grid: GridContainer
var _squad_status: Label
var _squad_find: Button
var _squad_picks: Array[StringName] = []
var _squad_buttons: Dictionary[StringName, Button] = {}
var _draft_panel: PanelContainer
var _draft_grid: GridContainer
var _draft_buttons: Array[Button] = []
var _draft_badges: Array[Label] = []
var _picked_style: StyleBoxFlat
var _enemy_preview: GridContainer
var _draft_timer_bar: ProgressBar
var _draft_timer_label: Label
var _draft_status: Label
var _draft_lock: Button
var _tray_buttons: Array[Button] = []
var _standby_panel: PanelContainer
var _standby_label: Label
var _standby_buttons: HBoxContainer
var _result_panel: PanelContainer
var _result_label: Label
var _result_sub: Label
var _result_cols: HBoxContainer


# =====================================================================
# Build
# =====================================================================

## The 3D arena fills the screen; the HUD floats over it.
## Top bar (status / turn order / energy), foe cards, arena gap, prompt, your cards + bench, skill bar. The log is a drawer.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	_portraits = Portraits.new()
	add_child(_portraits)
	var bg: TextureRect = TextureRect.new()
	var grad: GradientTexture2D = GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.colors = PackedColorArray([Color("#222b44"), UITheme.BG])
	grad.fill_from = Vector2(0.5, 0.0)
	grad.fill_to = Vector2(0.5, 1.0)
	bg.texture = grad
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	for i in 4:
		_cards.append(null)
	_stage = BattleStage.new(viewer_side)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	add_child(_vignette())

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 14)
	add_child(margin)
	var hud: VBoxContainer = _vbox(margin, 10)

	# --- Top bar ---
	var top: HBoxContainer = _hbox(hud, 12)
	var status_row: HBoxContainer = _hbox(_panel(top), 10)
	_status_label = _label(status_row, &"Header")
	_frenzy_box = _hbox(status_row, 4)
	var tl_panel: PanelContainer = _panel(top)
	tl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl_row: HBoxContainer = _hbox(tl_panel, 6)
	_label(tl_row, &"Dim").text = "SPEED ORDER"
	_timeline_box = _hbox(tl_row, 6)
	var energy_panel: PanelContainer = _panel(top)
	energy_panel.tooltip_text = "Team Energy: spend it on Overdrive."
	energy_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var energy_grid: GridContainer = GridContainer.new()
	energy_grid.columns = 3
	energy_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_grid.add_theme_constant_override("v_separation", 2)
	energy_grid.add_theme_constant_override("h_separation", 8)
	energy_panel.add_child(energy_grid)
	for side: int in [viewer_side, 1 - viewer_side]:
		var tag: Label = _label(energy_grid, &"Dim")
		tag.text = "YOU" if side == viewer_side else "FOE"
		tag.add_theme_color_override("font_color", SIDE_COLORS[side])
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.max_value = CombatTypes.ENERGY_CAP
		bar.custom_minimum_size = Vector2(150, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", UITheme.bar_box(UITheme.GOLD if side == viewer_side else SIDE_COLORS[side]))
		energy_grid.add_child(bar)
		var num: Label = _label(energy_grid, &"Header")
		num.add_theme_font_size_override("font_size", 15)
		num.custom_minimum_size = Vector2(52, 0)
		_energy_bars[side] = bar
		_energy_labels[side] = num
	var log_toggle: Button = Button.new()
	log_toggle.text = "LOG"
	log_toggle.tooltip_text = "Battle log (L)"
	log_toggle.pressed.connect(_toggle_log)
	top.add_child(log_toggle)

	_add_side_row(hud, CombatTypes.other_side(viewer_side))
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud.add_child(gap)

	var prompt_row: CenterContainer = _center(hud)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.05, 0.08, 0.85), UITheme.EDGE, 2, 2, 8))
	prompt_row.add_child(_prompt_panel)
	_prompt_label = _label(_prompt_panel, &"Header")
	_prompt_label.add_theme_font_size_override("font_size", 17)

	_add_side_row(hud, viewer_side)

	# --- Skill bar ---
	var actions: HBoxContainer = _hbox(_center(hud), 10)
	for i in 3:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(210, 66)
		b.pressed.connect(_on_skill_pressed.bind(i))
		actions.add_child(b)
		_skill_buttons.append(b)
	_overdrive_button = Button.new()
	_overdrive_button.toggle_mode = true
	_overdrive_button.custom_minimum_size = Vector2(160, 66)
	_overdrive_button.toggled.connect(func(on: bool) -> void:
		_overdrive_button.theme_type_variation = &"GoldButton" if on else &""
		_refresh_controls())
	actions.add_child(_overdrive_button)
	_lock_button = Button.new()
	_lock_button.text = "LOCK IN"
	_lock_button.theme_type_variation = &"GoldButton"
	_lock_button.custom_minimum_size = Vector2(160, 66)
	_lock_button.pressed.connect(_on_lock_actions_pressed)
	actions.add_child(_lock_button)

	_float_layer = Control.new()
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_float_layer)

	# --- Log drawer (right edge, hidden by default) ---
	_log_panel = PanelContainer.new()
	_log_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.06, 0.09, 0.94), UITheme.EDGE, 2, 2, 8))
	_log_panel.anchor_left = 1.0
	_log_panel.anchor_right = 1.0
	_log_panel.anchor_bottom = 1.0
	_log_panel.offset_left = -390
	_log_panel.offset_right = -14
	_log_panel.offset_top = 80
	_log_panel.offset_bottom = -14
	_log_panel.visible = false
	add_child(_log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log_panel.add_child(_log)

	_build_squad_panel()
	_build_draft_panel()
	_build_standby_panel()
	_build_result_panel()
	_refresh_controls()


## Side tag, two cards in slot order, then the bench. Your bench entries double as switch buttons.
func _add_side_row(parent: Control, side: int) -> void:
	var row: HBoxContainer = _hbox(_center(parent), 12)
	var tag: Label = _label(row, &"Header")
	tag.text = "YOU" if side == viewer_side else "FOE"
	tag.add_theme_color_override("font_color", SIDE_COLORS[side])
	tag.custom_minimum_size = Vector2(60, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for slot in CombatTypes.ACTIVE_SLOTS:
		var card: TroopCard = TroopCard.new(side, slot)
		card.clicked.connect(_on_card_clicked)
		row.add_child(card)
		_cards[side * 2 + slot] = card
	var bench: VBoxContainer = _vbox(row, 6)
	bench.custom_minimum_size = Vector2(200, 0)
	bench.alignment = BoxContainer.ALIGNMENT_CENTER
	_label(bench, &"Dim").text = "BENCH — click to switch" if side == viewer_side else "BENCH"
	if side == viewer_side:
		for i in 2:
			var b: Button = Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 15)
			b.add_theme_constant_override("icon_max_width", 30)
			b.pressed.connect(_on_switch_pressed.bind(i))
			bench.add_child(b)
			_switch_buttons.append(b)
	else:
		_bench_boxes[side] = _hbox(bench, 6)


## Squad select: the whole roster, built from data at show time, so new troops appear without code changes.
func _build_squad_panel() -> void:
	_squad_panel = _overlay(Color(UITheme.BG, 0.62), true)
	var v: VBoxContainer = _vbox(_squad_panel, 14)
	var head: HBoxContainer = _hbox(v, 18)
	_label(head, &"Title").text = "BUILD YOUR SQUAD"
	var sub: Label = _label(head, &"Dim")
	sub.text = "Choose %d troops to bring. You pick %d of them after you see the opponent. Hover a troop for its skills." % [CombatTypes.DRAFT_BRING, CombatTypes.DRAFT_PICK]
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_squad_grid = GridContainer.new()
	_squad_grid.columns = 6
	_squad_grid.add_theme_constant_override("h_separation", 10)
	_squad_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_squad_grid)
	var bottom: HBoxContainer = _hbox(v, 12)
	_squad_status = _label(bottom, &"Header")
	_squad_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_squad_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_squad_find = Button.new()
	_squad_find.text = "FIND MATCH"
	_squad_find.theme_type_variation = &"GoldButton"
	_squad_find.custom_minimum_size = Vector2(240, 60)
	_squad_find.add_theme_font_size_override("font_size", 22)
	_squad_find.pressed.connect(_on_squad_find)
	bottom.add_child(_squad_find)


## `roster`: TroopData.to_summary() of every troop. `preselected`: last squad, kept if those troops still exist.
func show_squad_select(roster: Array[Dictionary], preselected: Array[StringName]) -> void:
	_clear(_squad_grid)
	_squad_buttons.clear()
	_squad_picks.clear()
	var sorted_roster: Array[Dictionary] = roster.duplicate()
	sorted_roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["archetype"] != b["archetype"]:
			return String(a["archetype"]) < String(b["archetype"])
		return int(a["role"]) < int(b["role"]))
	for s: Dictionary in sorted_roster:
		var id: StringName = StringName(s["troop_id"])
		var b: Button = _troop_tile(s)
		b.pressed.connect(_on_squad_toggle.bind(id))
		_squad_grid.add_child(b)
		_squad_buttons[id] = b
	for id in preselected:
		if _squad_buttons.has(id) and _squad_picks.size() < CombatTypes.DRAFT_BRING:
			_squad_picks.append(id)
	_set_overlay(_squad_panel, true)
	_refresh_squad()


func _on_squad_toggle(id: StringName) -> void:
	if _squad_picks.has(id):
		_squad_picks.erase(id)
	elif _squad_picks.size() < CombatTypes.DRAFT_BRING:
		_squad_picks.append(id)
	_refresh_squad()


func _on_squad_find() -> void:
	if _squad_picks.size() != CombatTypes.DRAFT_BRING:
		return
	_squad_panel.visible = false
	squad_chosen.emit(_squad_picks.duplicate())


func _refresh_squad() -> void:
	for id: StringName in _squad_buttons:
		var picked: bool = _squad_picks.has(id)
		var b: Button = _squad_buttons[id]
		for state: String in ["normal", "hover"]:
			if picked:
				b.add_theme_stylebox_override(state, _picked_style)
			else:
				b.remove_theme_stylebox_override(state)
	_squad_find.disabled = _squad_picks.size() != CombatTypes.DRAFT_BRING
	_squad_status.text = "%d / %d chosen" % [_squad_picks.size(), CombatTypes.DRAFT_BRING]


func _build_draft_panel() -> void:
	_draft_panel = _overlay(Color(UITheme.BG, 0.62), true)
	_picked_style = UITheme.box(Color("#3b3522"), UITheme.GOLD, 3, 6, 8)
	var v: VBoxContainer = _vbox(_draft_panel, 14)
	var head: HBoxContainer = _hbox(v, 18)
	_label(head, &"Title").text = "TEAM PREVIEW"
	var sub: Label = _label(head, &"Dim")
	sub.text = "Bring 6, pick 4. Picks #1–#2 lead the field, #3–#4 wait on the bench. Hover a troop for its skills."
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var timer_row: HBoxContainer = _hbox(v, 10)
	_draft_timer_bar = ProgressBar.new()
	_draft_timer_bar.show_percentage = false
	_draft_timer_bar.max_value = CombatTypes.DRAFT_SECONDS
	_draft_timer_bar.custom_minimum_size = Vector2(0, 14)
	_draft_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_draft_timer_bar.add_theme_stylebox_override("fill", UITheme.bar_box(UITheme.GOLD))
	timer_row.add_child(_draft_timer_bar)
	_draft_timer_label = _label(timer_row, &"Header")
	_draft_timer_label.custom_minimum_size = Vector2(56, 0)
	_draft_timer_label.tooltip_text = "Your first 4 troops are picked automatically when time runs out."
	_draft_timer_label.mouse_filter = Control.MOUSE_FILTER_STOP

	var cols: HBoxContainer = _hbox(v, 34)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left: VBoxContainer = _vbox(cols, 8)
	_label(left, &"Header").text = "YOUR SQUAD"
	_draft_grid = GridContainer.new()
	_draft_grid.columns = 3
	_draft_grid.add_theme_constant_override("h_separation", 10)
	_draft_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(_draft_grid)
	var right: VBoxContainer = _vbox(cols, 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var opp: Label = _label(right, &"Header")
	opp.text = "OPPONENT — brings 4 of these"
	opp.add_theme_color_override("font_color", SIDE_COLORS[1 - viewer_side])
	_enemy_preview = GridContainer.new()
	_enemy_preview.columns = 2
	_enemy_preview.add_theme_constant_override("h_separation", 10)
	_enemy_preview.add_theme_constant_override("v_separation", 10)
	right.add_child(_enemy_preview)

	# Pick tray: click a filled slot to drop that pick.
	var bottom: HBoxContainer = _hbox(v, 10)
	for i in CombatTypes.DRAFT_PICK:
		if i == 2:
			bottom.add_child(_spacer(14))
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(112, 118)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 76)
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = "Click to remove this pick."
		b.pressed.connect(_on_tray_pressed.bind(i))
		bottom.add_child(b)
		_tray_buttons.append(b)
	var fill: Control = _spacer(0)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(fill)
	var lock_col: VBoxContainer = _vbox(bottom, 8)
	lock_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_draft_status = _label(lock_col, &"")
	_draft_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_draft_lock = Button.new()
	_draft_lock.text = "LOCK IN"
	_draft_lock.theme_type_variation = &"GoldButton"
	_draft_lock.custom_minimum_size = Vector2(220, 60)
	_draft_lock.add_theme_font_size_override("font_size", 22)
	_draft_lock.size_flags_horizontal = Control.SIZE_SHRINK_END
	_draft_lock.pressed.connect(_on_draft_lock)
	lock_col.add_child(_draft_lock)


func _build_standby_panel() -> void:
	_standby_panel = _overlay(UITheme.PANEL, false)
	var v: VBoxContainer = _vbox(_standby_panel, 14)
	_standby_label = _label(v, &"Header")
	_standby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_standby_buttons = _hbox(v, 12)
	_standby_buttons.alignment = BoxContainer.ALIGNMENT_CENTER


func _build_result_panel() -> void:
	_result_panel = _overlay(UITheme.PANEL, false)
	var v: VBoxContainer = _vbox(_result_panel, 14)
	_result_label = _label(v, &"Title")
	_result_label.add_theme_font_size_override("font_size", 56)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_sub = _label(v, &"Dim")
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_cols = _hbox(v, 24)
	var again: Button = Button.new()
	again.text = "PLAY AGAIN"
	again.theme_type_variation = &"GoldButton"
	again.custom_minimum_size = Vector2(220, 52)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func() -> void: restart_requested.emit())
	v.add_child(again)


func _overlay(color: Color, full: bool) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UITheme.box(color, UITheme.GOLD.darkened(0.3), 0 if full else 3, 0 if full else 7, 0 if full else 12)
	style.set_content_margin_all(32)
	p.add_theme_stylebox_override("panel", style)
	add_child(p)
	if full:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.material = _frosted(color)
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
	_float_stack.clear()
	_damage.clear()
	_energy = [0, 0]
	_draft_picks.clear()
	_draft_built = false
	_pending_skill = -1
	_selected_troop_uid = -1
	_chosen_actions.clear()
	_acting_actor = -1
	_timeline_order.clear()
	_clear(_draft_grid)
	_clear(_enemy_preview)
	_draft_buttons.clear()
	_draft_badges.clear()
	for card in _cards:
		card.clear_card()
	_stage.clear()
	_log.clear()
	_result_panel.visible = false
	_standby_panel.visible = false
	_squad_panel.visible = false


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
			card.bind(actor, String(d["name"]), int(d["role"]), _portraits.texture(String(d["troop_id"])), StringName(d["archetype"]), bool(d["synergy"]))
			card.set_hp(int(d["hp"]), int(d["max_hp"]), int(d["shield"]))
			card.set_effects([], [])
			_stage.place(int(d["side"]), int(d["slot"]), actor, String(d["troop_id"]), true)
			_log_line("%s enters the field." % _cn(actor))
			delay = 0.3
		CombatTypes.EventType.ROUND_STARTED:
			var order: Array = d.get("order", [])
			_timeline_order = Array(order).duplicate()
			_acting_actor = -1
			_refresh_timeline()
			_chosen_actions.clear()
			_refresh_chosen_action_display()
			_log_line("[color=#7d8597]— Turn %d —[/color]" % int(value))
			delay = 0.2
		CombatTypes.EventType.ACTIONS_LOCKED:
			var locked_side: int = int(d.get("side", -1))
			_log_line("%s locked in actions." % _side_name(locked_side))
		CombatTypes.EventType.CYCLE_ADVANCED:
			_log_line("[color=#7d8597]— Turn %d —[/color]" % int(value))
		CombatTypes.EventType.FRENZY_CHANGED:
			_log_line("[color=#ff5050][b]BATTLE FRENZY x%d[/b] — damage x%.2f, healing x%.2f[/color]" % [int(value), float(d["damage_mult"]), float(d["heal_mult"])])
			delay = 0.3
		CombatTypes.EventType.TURN_STARTED:
			_acting_actor = actor
			_highlight_actor(actor)
			_refresh_timeline()
			delay = 0.15
		CombatTypes.EventType.TURN_ENDED:
			_acting_actor = -1
			_highlight_actor(-1)
			_refresh_timeline()
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
			var hostile: bool = target != -1 and _sides.get(target, -1) != _sides.get(actor, -1)
			_stage.play(actor, &"attack" if hostile else &"cast")
			if hostile:
				_stage.fx_projectile(actor, target, Color("#ffd27a"), 0.22 / maxf(playback_speed, 0.01))
			else:
				_stage.fx_cast(actor, Color("#ffd24a") if bool(d["overdrive"]) else Color("#8fd0ff"))
			delay = 0.25
		CombatTypes.EventType.OVERDRIVE_ACTIVATED:
			_float(actor, "OVERDRIVE", Color("#ffd24a"))
		CombatTypes.EventType.DAMAGE:
			var c3: TroopCard = _card_for(target)
			if c3 != null:
				c3.update_hp(int(d["hp_after"]), int(d["shield_after"]))
				c3.flash(Color(1.8, 0.6, 0.6))
			_stage.play(target, &"hit")
			_stage.fx_impact(target, Color("#ff8a3d") if String(d["tag"]) == "dot" else Color("#ff5a5a"), bool(d["crit"]))
			if bool(d["crit"]):
				_stage.cheer()
			if actor >= 0:
				_damage[actor] = int(_damage.get(actor, 0)) + int(value)
			var crit: bool = bool(d["crit"])
			_float(target, ("-%d!" if crit else "-%d") % int(value), Color("#ff6b6b") if not crit else Color("#ffb347"))
			var src: String = "Burn" if String(d["tag"]) == "dot" else _n(actor)
			var absorbed: String = " (%d absorbed)" % int(d["absorbed"]) if int(d["absorbed"]) > 0 else ""
			_log_line("  %s → %s: [color=#ff8080]%d[/color]%s%s" % [src, _cn(target), int(value), " CRIT" if crit else "", absorbed])
			delay = 0.35
		CombatTypes.EventType.HEAL:
			if int(value) <= 0:
				return
			var c4: TroopCard = _card_for(target)
			if c4 != null:
				c4.update_hp(int(d["hp_after"]))
			_float(target, "+%d" % int(value), Color("#6be38a"))
			_stage.play(target, &"buff")
			_stage.fx_heal(target)
			_log_line("  %s heals %s for [color=#80ff9a]%d[/color]" % [_cn(actor), _cn(target), int(value)])
			delay = 0.2
		CombatTypes.EventType.EFFECT_APPLIED:
			var fx: String = TroopCard.effect_text(d)
			_float(target, fx, Color("#ff9f80") if bool(d["debuff"]) else Color("#9fd4ff"))
			_stage.fx_buff(target, Color("#ff6a3d") if bool(d["debuff"]) else Color("#5fb8ff"))
			_log_line("  %s: %s (%d turns)" % [_cn(target), fx, int(d["duration"])])
			delay = 0.15
		CombatTypes.EventType.EFFECT_RESISTED:
			_float(target, "Resist", Color("#c0c0c0"))
			_log_line("  %s resisted." % _cn(target))
			delay = 0.15
		CombatTypes.EventType.EFFECT_EXPIRED, CombatTypes.EventType.ACTION_REQUESTED:
			pass
		CombatTypes.EventType.CLEANSED:
			_float(target, "Cleansed", Color("#9fd4ff"))
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
			_stage.play(actor, &"death")
			_stage.fx_ko(actor)
			_stage.cheer()
			_log_line("[color=#ff5050]%s is knocked out![/color]" % _cn(actor))
			delay = 0.45
		CombatTypes.EventType.STANDBY_REQUESTED:
			_log_line("[color=#e8c547]Standby — fill the empty slot from the bench.[/color]")
		CombatTypes.EventType.REPLACED:
			_names[actor] = String(d["name"])
			_sides[actor] = int(d["side"])
			_log_line("%s sends in %s." % [_side_name(int(d["side"])), _cn(actor)])
		CombatTypes.EventType.BATTLE_ENDED:
			_log_line("[b]%s wins after %d turns.[/b]" % [_side_name(int(d["winner"])), int(d["cycle"])])
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
	if phase == CombatTypes.Phase.ACTION_WAIT:
		_timeline_order = snap.get("timeline", []).duplicate()
		if not snap["teams"][viewer_side]["actions_locked"]:
			var legal: Dictionary = snap.get("legal", {})
			for uid: int in _chosen_actions.keys():
				if not legal.has(uid):
					_chosen_actions.erase(uid)
			if not legal.has(_selected_troop_uid) and not legal.is_empty():
				_selected_troop_uid = int(legal.keys()[0])
		else:
			_chosen_actions.clear()
	else:
		_chosen_actions.clear()
	_refresh_field()
	_refresh_status()
	_refresh_timeline()
	_refresh_controls()
	var finished: bool = phase == CombatTypes.Phase.FINISHED
	(_timeline_box.get_parent() as Control).visible = not finished
	if finished and not _result_panel.visible:
		_fill_result(snap)
		_highlight_actor(-1)
	_set_overlay(_result_panel, finished)


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
				_stage.clear_slot(side, slot)
				continue
			var t: Dictionary = troops[uid]
			_stage.place(side, slot, uid, String(t["troop_id"]), false)
			if not bool(t["alive"]):
				_stage.model_for(uid).set_dead()
			card.bind(uid, String(t["name"]), int(t["role"]), _portraits.texture(String(t["troop_id"])), StringName(t["archetype"]), bool(t["synergy"]))
			card.set_hp(int(t["hp"]), int(t["max_hp"]), int(t["shield"]))
			card.set_effects(t["effects"], t["cooldowns"])
			if t.has("stats"):
				var st: Dictionary = t["stats"]
				card.tooltip_text = "%s\nHP %d/%d\nATK %d  SPA %d\nDEF %d  SPD %d\nSPE %d  EFF %d%%" % [
					t["name"], t["hp"], t["max_hp"],
					roundi(st["atk"]), roundi(st["spa"]),
					roundi(st["def"]), roundi(st["spd"]),
					roundi(st["spe"]), roundi(st["eff"] * 100.0)
				]
		if _bench_boxes[side] == null:
			continue
		_clear(_bench_boxes[side])
		for b in team["bench"]:
			var buid: int = int(b)
			if buid == -2:
				_bench_boxes[side].add_child(UITheme.chip("???", UITheme.TEXT_DIM, 13))
			elif buid >= 0 and troops.has(buid):
				_bench_boxes[side].add_child(UITheme.chip(_bench_text(troops[buid]), SIDE_COLORS[side], 13))
	_refresh_chosen_action_display()


func _refresh_status() -> void:
	for side in 2:
		_energy_bars[side].value = _energy[side]
		_energy_labels[side].text = "%d/%d" % [_energy[side], CombatTypes.ENERGY_CAP]
	_clear(_frenzy_box)
	if snapshot.is_empty():
		_status_label.text = "ET"
		return
	var phase: int = int(snapshot["phase"])
	_status_label.text = "TEAM PREVIEW" if phase == CombatTypes.Phase.PREVIEW else "TURN %d" % int(snapshot["cycle"])
	var frenzy: int = int(snapshot["frenzy_stacks"])
	if frenzy > 0:
		var c: PanelContainer = UITheme.chip("FRENZY x%d" % frenzy, UITheme.DANGER, 14)
		c.tooltip_text = "Battle Frenzy: +%d%% damage, -%d%% healing" % [frenzy * 5, frenzy * 5]
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		_frenzy_box.add_child(c)


## Turn order as side-framed portraits; the acting troop is drawn larger.
func _refresh_timeline() -> void:
	_clear(_timeline_box)
	var troops: Dictionary = snapshot.get("troops", {})
	for uid in _timeline_order:
		if not troops.has(uid):
			continue
		var t: Dictionary = troops[uid]
		var is_acting: bool = (uid == _acting_actor)
		var ic: PanelContainer = _portraits.icon(String(t["troop_id"]), SIDE_COLORS[int(t["side"])], 46 if is_acting else 32)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.tooltip_text = "%s (%s)" % [t["name"], "you" if int(t["side"]) == viewer_side else "foe"]
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		if is_acting:
			var s: StyleBoxFlat = ic.get_theme_stylebox("panel") as StyleBoxFlat
			if s != null:
				s.border_color = UITheme.GOLD
				s.shadow_color = Color(UITheme.GOLD, 0.4)
				s.shadow_size = 6
		_timeline_box.add_child(ic)


func _refresh_controls() -> void:
	if _skill_buttons.is_empty():
		return
	var phase: int = int(snapshot.get("phase", CombatTypes.Phase.PREVIEW))
	var legal: Dictionary = snapshot.get("legal", {})
	var mine_locked: bool = bool(snapshot.get("teams", [{}, {}])[viewer_side].get("actions_locked", false)) if snapshot.has("teams") else false
	var my_turn: bool = not _input_locked and phase == CombatTypes.Phase.ACTION_WAIT and not legal.is_empty() and not mine_locked

	if my_turn:
		if not legal.has(_selected_troop_uid):
			_selected_troop_uid = int(legal.keys()[0])
	else:
		_selected_troop_uid = -1

	var legal_entry: Dictionary = legal.get(_selected_troop_uid, {}) if my_turn else {}
	var skills: Array = legal_entry.get("skills", [])
	var avail_energy: int = _get_available_energy(_selected_troop_uid) if my_turn else 0

	for i in _skill_buttons.size():
		var b: Button = _skill_buttons[i]
		if not my_turn or skills.is_empty() or i >= skills.size():
			b.disabled = true
			b.text = "S%d\n—" % (i + 1)
			b.tooltip_text = ""
			continue
		var info: Dictionary = skills[i]
		var is_special: bool = bool(info.get("special", false))
		var special_tag: String = " [SPECIAL]" if is_special else ""
		var state_text: String = "Passive" if bool(info["passive"]) else ("Ready" if bool(info["ready"]) else "Cooldown %d" % int(info["cooldown_left"]))
		b.text = "%s%s\n[%d] %s" % [String(info["name"]), special_tag, i + 1, state_text]
		b.disabled = not bool(info["ready"])
		var od_kind: int = int(info["overdrive_kind"])
		var od_cost: int = int(info["overdrive_cost"])
		var can_od: bool = od_kind != CombatTypes.OverdriveKind.NONE and od_cost <= avail_energy
		var od_text: String = "\nOverdrive: %s (%d Energy)%s" % [OVERDRIVE_NAMES[od_kind], od_cost, "" if can_od else " — not enough Energy"] if od_kind != 0 else ""
		var spec_tooltip: String = "[SPECIAL - SPA vs SPD]\n" if is_special else ""
		b.tooltip_text = "%s%s\nTarget: %s%s" % [spec_tooltip, String(info["description"]), TARGET_NAMES[int(info["target_type"])], od_text]

	var can_any_od: bool = false
	for s_info: Dictionary in skills:
		var ok: int = int(s_info.get("overdrive_kind", 0))
		var oc: int = int(s_info.get("overdrive_cost", 0))
		if ok != CombatTypes.OverdriveKind.NONE and oc <= avail_energy and bool(s_info.get("ready", false)):
			can_any_od = true
			break

	_overdrive_button.disabled = not my_turn or not can_any_od
	if not my_turn or not can_any_od:
		_overdrive_button.button_pressed = false
	_overdrive_button.text = "OVERDRIVE\n[O] %s" % ("ARMED" if _overdrive_button.button_pressed else "off")
	_overdrive_button.tooltip_text = "Spend Team Energy to empower the next skill (each skill's tooltip shows the effect and cost).\nAvailable Energy: %d" % avail_energy

	var bench_ids: Array = snapshot["teams"][viewer_side]["bench"] if snapshot.has("teams") else []
	var switchable: Array = legal_entry.get("bench", [])
	var can_switch: bool = bool(legal_entry.get("can_switch", false))
	for i in _switch_buttons.size():
		var b: Button = _switch_buttons[i]
		var uid: int = int(bench_ids[i]) if i < bench_ids.size() else -1
		var known: bool = uid >= 0 and snapshot["troops"].has(uid)
		var is_taken: bool = _is_bench_taken_by_other(i, _selected_troop_uid)
		var btext: String = _bench_text(snapshot["troops"][uid]) if known else "—"
		if is_taken:
			btext += " (Taken)"
		b.text = btext
		b.icon = _portraits.texture(String(snapshot["troops"][uid]["troop_id"])) if known else null
		b.disabled = not my_turn or not can_switch or not switchable.has(i) or is_taken

	_lock_button.disabled = not my_turn or not _can_lock_actions()

	var pending: Array = snapshot["teams"][viewer_side]["pending_slots"] if snapshot.has("teams") else []
	var standby: bool = not _input_locked and phase == CombatTypes.Phase.STANDBY and not pending.is_empty()
	if standby:
		_fill_standby(int(pending[0]))
	_set_overlay(_standby_panel, standby)

	if my_turn:
		if _pending_skill != -1:
			var p_info: Dictionary = skills[_pending_skill]
			_prompt("CHOOSE A TARGET — %s   (Esc to cancel)" % String(p_info["name"]), UITheme.DANGER.lightened(0.3))
		elif _can_lock_actions():
			_prompt("ALL ACTIONS CHOSEN — Press LOCK IN (or click a troop to edit)", UITheme.GOLD)
		else:
			_prompt("PICK ACTION for %s (or click another troop to switch)" % _n(_selected_troop_uid), UITheme.GOLD)
		_highlight_actor(_selected_troop_uid)
	elif phase == CombatTypes.Phase.ACTION_WAIT:
		if mine_locked:
			_prompt("Waiting for opponent\u2026", Color("#a0a8b8"))
		elif legal.is_empty():
			_prompt("", Color.WHITE)
		else:
			_prompt("Waiting\u2026", Color("#a0a8b8"))
		_highlight_actor(-1)
	elif phase == CombatTypes.Phase.STANDBY and pending.is_empty():
		_prompt("Opponent is choosing a replacement\u2026", Color("#a0a8b8"))
	else:
		_prompt("", Color.WHITE)


func _fill_standby(slot: int) -> void:
	_standby_label.text = "STANDBY — choose who fills slot %d" % (slot + 1)
	_clear(_standby_buttons)
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
		b.icon = _portraits.texture(String(t["troop_id"]))
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 96)
		b.custom_minimum_size = Vector2(190, 170)
		b.pressed.connect(func() -> void:
			set_input_locked(true)
			replacement_requested.emit(slot, i))
		_standby_buttons.add_child(b)


func _show_draft(snap: Dictionary) -> void:
	_set_overlay(_draft_panel, true)
	var teams: Array = snap["teams"]
	var mine: Dictionary = teams[viewer_side]
	if not _draft_built:
		_draft_built = true
		_draft_time_left = CombatTypes.DRAFT_SECONDS
		var squad: Array = mine["squad"]
		for i in squad.size():
			_draft_grid.add_child(_draft_tile(squad[i], i))
		for s: Dictionary in teams[1 - viewer_side]["squad"]:
			_enemy_preview.add_child(_enemy_tile(s))
	_refresh_draft()


## Clickable squad tile: portrait framed in the role colour, name, role chip, stats, pick badge.
func _draft_tile(s: Dictionary, index: int) -> Button:
	var b: Button = _troop_tile(s)
	b.pressed.connect(_on_draft_toggle.bind(index))
	var badge: Label = _label(b, &"Header")
	badge.position = Vector2(10, 6)
	badge.add_theme_color_override("font_color", UITheme.GOLD)
	_draft_badges.append(badge)
	_draft_buttons.append(b)
	return b


## Troop tile shared by squad select and the draft: portrait, name, role chip, stats; tooltip lists skills.
func _troop_tile(s: Dictionary) -> Button:
	var role_i: int = int(s["role"])
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(204, 256)
	b.tooltip_text = _squad_tooltip(s)
	var tile_arch: ArchetypeData = ArchetypeRegistry.find(StringName(s["archetype"]))
	if tile_arch != null:
		b.add_child(ArchetypeBackdrop.new(tile_arch))
	var v: VBoxContainer = _vbox(b, 4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic: PanelContainer = _portraits.icon(String(s["troop_id"]), TroopCard.ROLE_COLORS[role_i], 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var name_l: Label = _label(v, &"Header")
	name_l.text = String(s["name"])
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var chip: PanelContainer = UITheme.chip(TroopCard.ROLE_NAMES[role_i], TroopCard.ROLE_COLORS[role_i], 11)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var arch_chip: PanelContainer = _archetype_chip(s, Control.SIZE_SHRINK_CENTER)
	if arch_chip != null:
		v.add_child(arch_chip)
	v.add_child(chip)
	var stats: Label = _label(v, &"Dim")
	stats.text = "HP %d  SPE %d\nATK %d  SPA %d\nDEF %d  SPD %d  EFF %d%%" % [
		s["max_hp"], s["speed"], s["attack"], s["special_attack"],
		s["defense"], s["special_defense"], roundi(float(s["effectiveness"]) * 100.0)
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## Read-only opponent tile (hover for skills).
func _enemy_tile(s: Dictionary) -> PanelContainer:
	var role_i: int = int(s["role"])
	var p: PanelContainer = PanelContainer.new()
	p.tooltip_text = _squad_tooltip(s)
	var row: HBoxContainer = _hbox(p, 10)
	row.add_child(_portraits.icon(String(s["troop_id"]), SIDE_COLORS[1 - viewer_side], 56))
	var v: VBoxContainer = _vbox(row, 3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l: Label = _label(v, &"Header")
	name_l.text = String(s["name"])
	name_l.add_theme_font_size_override("font_size", 16)
	var chip: PanelContainer = UITheme.chip(TroopCard.ROLE_NAMES[role_i], TroopCard.ROLE_COLORS[role_i], 11)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var arch_chip: PanelContainer = _archetype_chip(s, Control.SIZE_SHRINK_BEGIN)
	if arch_chip != null:
		v.add_child(arch_chip)
	v.add_child(chip)
	_label(v, &"Dim").text = "HP %d  SPE %d  EFF %d%%\nATK %d  SPA %d  DEF %d  SPD %d" % [
		s["max_hp"], s["speed"], roundi(float(s["effectiveness"]) * 100.0),
		s["attack"], s["special_attack"], s["defense"], s["special_defense"]
	]
	return p


func _refresh_draft() -> void:
	if snapshot.is_empty():
		return
	var mine: Dictionary = snapshot["teams"][viewer_side]
	var squad: Array = mine["squad"]
	var locked: bool = bool(mine["locked"])
	for i in _draft_buttons.size():
		var order: int = _draft_picks.find(i)
		var b: Button = _draft_buttons[i]
		_draft_badges[i].text = "" if order == -1 else "#%d" % (order + 1)
		b.disabled = locked
		for state: String in ["normal", "hover", "disabled"]:
			if order != -1:
				b.add_theme_stylebox_override(state, _picked_style)
			else:
				b.remove_theme_stylebox_override(state)
	for i in _tray_buttons.size():
		var t: Button = _tray_buttons[i]
		var filled: bool = i < _draft_picks.size()
		t.icon = _portraits.texture(String(squad[_draft_picks[i]]["troop_id"])) if filled else null
		t.text = ("LEAD %d" if i < 2 else "BENCH %d") % (i + 1)
		t.disabled = locked or not filled
		if filled:
			t.add_theme_stylebox_override("disabled", _picked_style)
		else:
			t.remove_theme_stylebox_override("disabled")
	_draft_lock.disabled = locked or _draft_picks.size() != CombatTypes.DRAFT_PICK
	var opp_locked: bool = bool(snapshot["teams"][1 - viewer_side]["locked"])
	_draft_status.text = ("Locked in. " if locked else "%d / %d picked. " % [_draft_picks.size(), CombatTypes.DRAFT_PICK]) + ("Opponent is ready." if opp_locked else "Opponent is choosing…")


func _squad_tooltip(s: Dictionary) -> String:
	var lines: PackedStringArray = []
	var arch: ArchetypeData = ArchetypeRegistry.find(StringName(s["archetype"]))
	if arch != null:
		lines.append("%s family synergy: %s" % [arch.display_name, arch.description])
	for sk: Dictionary in s["skills"]:
		var spec: String = " [SPECIAL]" if bool(sk.get("special", false)) else ""
		lines.append("S%d %s%s%s: %s" % [int(sk["slot"]) + 1, sk["name"], spec, " (passive)" if bool(sk["passive"]) else " (CD %d)" % int(sk["cooldown"]), sk["description"]])
	return "\n".join(lines)


# =====================================================================
# Input
# =====================================================================

func _process(delta: float) -> void:
	if _draft_panel != null and _draft_panel.visible and not snapshot.is_empty() and not bool(snapshot["teams"][viewer_side]["locked"]):
		_draft_time_left = maxf(0.0, _draft_time_left - delta)
		_draft_timer_bar.value = _draft_time_left
		_draft_timer_label.text = "%ds" % ceili(_draft_time_left)
		_draft_timer_label.add_theme_color_override("font_color", UITheme.DANGER if _draft_time_left < 10.0 else UITheme.GOLD)


func _unhandled_input(event: InputEvent) -> void:
	if _pending_skill != -1 and event.is_action_pressed("ui_cancel"):
		_pending_skill = -1
		_clear_target_highlights()
		_refresh_controls()
		get_viewport().set_input_as_handled()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _pending_skill != -1:
		var picked: int = _stage.pick(mb.position)
		if picked != -1:
			_on_card_clicked(picked)
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			var b: Button = _skill_buttons[key.keycode - KEY_1]
			if not b.disabled:
				b.pressed.emit()
		KEY_O:
			if not _overdrive_button.disabled:
				_overdrive_button.button_pressed = not _overdrive_button.button_pressed
				_refresh_controls()
		KEY_ENTER, KEY_KP_ENTER:
			if not _lock_button.disabled:
				_lock_button.pressed.emit()
		KEY_L:
			_toggle_log()


func _on_draft_toggle(index: int) -> void:
	if _draft_picks.has(index):
		_draft_picks.erase(index)
	elif _draft_picks.size() < CombatTypes.DRAFT_PICK:
		_draft_picks.append(index)
	_refresh_draft()


func _on_tray_pressed(slot: int) -> void:
	if slot < _draft_picks.size():
		_draft_picks.remove_at(slot)
		_refresh_draft()


func _on_draft_lock() -> void:
	if _draft_picks.size() == CombatTypes.DRAFT_PICK:
		set_input_locked(true)
		draft_submitted.emit(_draft_picks.duplicate())


func select_troop(uid: int) -> void:
	if _input_locked:
		return
	var legal: Dictionary = snapshot.get("legal", {})
	if not legal.has(uid):
		return
	_selected_troop_uid = uid
	_pending_skill = -1
	_clear_target_highlights()
	_refresh_controls()


func _on_skill_pressed(index: int) -> void:
	if _selected_troop_uid == -1 or not snapshot.get("legal", {}).has(_selected_troop_uid):
		return
	var legal_entry: Dictionary = snapshot["legal"][_selected_troop_uid]
	var info: Dictionary = legal_entry["skills"][index]
	if not bool(info["ready"]):
		return
	var targets: Array = info["targets"]
	if targets.is_empty():
		_choose_skill(_selected_troop_uid, index, -1)
		return
	_pending_skill = index
	_clear_target_highlights()
	for card in _cards:
		if targets.has(card.uid):
			card.set_highlight(2)
		elif card.uid == _selected_troop_uid:
			card.set_highlight(1)
	for uid: int in targets:
		_stage.set_ring(uid, UITheme.DANGER)
	_prompt("CHOOSE A TARGET — %s   (Esc to cancel)" % String(info["name"]), UITheme.DANGER.lightened(0.3))


func _on_card_clicked(uid: int) -> void:
	if _input_locked:
		return
	if _pending_skill != -1:
		if snapshot.get("legal", {}).has(_selected_troop_uid):
			var targets: Array = snapshot["legal"][_selected_troop_uid]["skills"][_pending_skill]["targets"]
			if targets.has(uid):
				_choose_skill(_selected_troop_uid, _pending_skill, uid)
		return
	var legal: Dictionary = snapshot.get("legal", {})
	if legal.has(uid):
		select_troop(uid)


func _choose_skill(uid: int, index: int, target_uid: int) -> void:
	var can_od: bool = _can_afford_overdrive(uid, index)
	var use_overdrive: bool = _overdrive_button.button_pressed and can_od
	_overdrive_button.button_pressed = false
	_pending_skill = -1
	_clear_target_highlights()
	var act: CombatAction = CombatAction.cast(index, target_uid, use_overdrive)
	_chosen_actions[uid] = act
	_enforce_overdrive_limits(uid)
	_auto_advance_selected_troop()
	_refresh_chosen_action_display()
	_refresh_controls()


func _on_switch_pressed(bench_index: int) -> void:
	if _selected_troop_uid == -1 or not snapshot.get("legal", {}).has(_selected_troop_uid):
		return
	var legal_entry: Dictionary = snapshot["legal"][_selected_troop_uid]
	if not bool(legal_entry["can_switch"]) or not (legal_entry["bench"] as Array).has(bench_index):
		return
	if _is_bench_taken_by_other(bench_index, _selected_troop_uid):
		return
	_pending_skill = -1
	_clear_target_highlights()
	_chosen_actions[_selected_troop_uid] = CombatAction.switch_to(bench_index)
	_auto_advance_selected_troop()
	_refresh_chosen_action_display()
	_refresh_controls()


func _on_lock_actions_pressed() -> void:
	if not _can_lock_actions():
		return
	set_input_locked(true)
	actions_locked.emit(_chosen_actions.duplicate())


func _can_lock_actions() -> bool:
	var legal: Dictionary = snapshot.get("legal", {})
	if legal.is_empty():
		return false
	for uid: int in legal:
		if not _chosen_actions.has(uid):
			return false
	return true


func _auto_advance_selected_troop() -> void:
	var legal: Dictionary = snapshot.get("legal", {})
	for uid: int in legal:
		if not _chosen_actions.has(uid):
			_selected_troop_uid = uid
			return


func _is_bench_taken_by_other(bench_index: int, for_uid: int) -> bool:
	for uid: int in _chosen_actions:
		if uid != for_uid:
			var a: CombatAction = _chosen_actions[uid]
			if a.kind == CombatTypes.ActionKind.SWITCH and a.bench_index == bench_index:
				return true
			if a.kind == CombatTypes.ActionKind.SKILL and a.bench_index == bench_index and a.bench_index != -1:
				return true
	return false


func _get_available_energy(for_uid: int) -> int:
	var total: int = _energy[viewer_side]
	for uid: int in _chosen_actions:
		if uid != for_uid:
			var a: CombatAction = _chosen_actions[uid]
			if a.kind == CombatTypes.ActionKind.SKILL and a.overdrive:
				if snapshot.get("legal", {}).has(uid):
					var sk: Dictionary = snapshot["legal"][uid]["skills"][a.skill_index]
					total -= int(sk.get("overdrive_cost", 0))
	return maxi(0, total)


func _can_afford_overdrive(for_uid: int, skill_index: int) -> bool:
	if not snapshot.get("legal", {}).has(for_uid):
		return false
	var sk: Dictionary = snapshot["legal"][for_uid]["skills"][skill_index]
	var cost: int = int(sk.get("overdrive_cost", 0))
	var kind: int = int(sk.get("overdrive_kind", CombatTypes.OverdriveKind.NONE))
	if kind == CombatTypes.OverdriveKind.NONE or cost <= 0:
		return false
	return cost <= _get_available_energy(for_uid)


func _enforce_overdrive_limits(changed_uid: int) -> void:
	var spent: int = 0
	if _chosen_actions.has(changed_uid):
		var act: CombatAction = _chosen_actions[changed_uid]
		if act.kind == CombatTypes.ActionKind.SKILL and act.overdrive:
			var sk: Dictionary = snapshot["legal"][changed_uid]["skills"][act.skill_index]
			spent += int(sk.get("overdrive_cost", 0))
	for uid: int in _chosen_actions:
		if uid != changed_uid:
			var act2: CombatAction = _chosen_actions[uid]
			if act2.kind == CombatTypes.ActionKind.SKILL and act2.overdrive:
				var sk2: Dictionary = snapshot["legal"][uid]["skills"][act2.skill_index]
				var cost: int = int(sk2.get("overdrive_cost", 0))
				if spent + cost > _energy[viewer_side]:
					act2.overdrive = false
				else:
					spent += cost


func _action_text_for(uid: int) -> String:
	if not _chosen_actions.has(uid):
		return ""
	var act: CombatAction = _chosen_actions[uid]
	if act.kind == CombatTypes.ActionKind.SWITCH:
		var bench_ids: Array = snapshot.get("teams", [{}, {}])[viewer_side].get("bench", [])
		var bname: String = "?"
		if act.bench_index >= 0 and act.bench_index < bench_ids.size():
			var buid: int = int(bench_ids[act.bench_index])
			if snapshot.get("troops", {}).has(buid):
				bname = String(snapshot["troops"][buid]["name"])
		return "Switch → %s" % bname
	elif act.kind == CombatTypes.ActionKind.SKILL:
		if not snapshot.get("legal", {}).has(uid):
			return ""
		var sk: Dictionary = snapshot["legal"][uid]["skills"][act.skill_index]
		var sk_name: String = String(sk["name"])
		var od_prefix: String = "[OD] " if act.overdrive else ""
		if act.target_uid != -1:
			return "%s%s → %s" % [od_prefix, sk_name, _n(act.target_uid)]
		var target_type: int = int(sk.get("target_type", CombatTypes.TargetType.SINGLE_ENEMY))
		match target_type:
			CombatTypes.TargetType.ALL_ENEMIES:
				return "%s%s → All Foes" % [od_prefix, sk_name]
			CombatTypes.TargetType.ALL_ALLIES:
				return "%s%s → All Allies" % [od_prefix, sk_name]
			CombatTypes.TargetType.SELF:
				return "%s%s → Self" % [od_prefix, sk_name]
		return "%s%s" % [od_prefix, sk_name]
	return ""


func _refresh_chosen_action_display() -> void:
	for card in _cards:
		if card != null and card.side == viewer_side:
			card.set_chosen_action(_action_text_for(card.uid))


# =====================================================================
# Helpers
# =====================================================================

func _card_for(uid: int) -> TroopCard:
	for card in _cards:
		if card.uid == uid:
			return card
	return null


func _highlight_actor(uid: int) -> void:
	_stage.clear_rings()
	for card in _cards:
		card.set_highlight(1 if card.uid == uid and uid != -1 else 0)
	if uid != -1:
		_stage.set_ring(uid, UITheme.GOLD)


func _clear_target_highlights() -> void:
	if int(snapshot.get("phase", -1)) == CombatTypes.Phase.ACTION_WAIT:
		_highlight_actor(_selected_troop_uid)
	else:
		_highlight_actor(_acting_actor)


## Pops text over the troop's head in the arena (falls back to its card).
func _float(uid: int, text: String, color: Color) -> void:
	var pos: Vector2 = _stage.head_position(uid)
	if pos == Vector2.INF:
		var card: TroopCard = _card_for(uid)
		if card == null or not card.is_inside_tree():
			return
		pos = card.get_global_rect().get_center() - global_position
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", UITheme.pixel_font())
	lbl.add_theme_font_size_override("font_size", 30 if text.ends_with("!") else 24)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", UITheme.EDGE)
	lbl.add_theme_constant_override("outline_size", 8)
	_float_layer.add_child(lbl)
	# Texts on the same troop stack upward instead of overlapping.
	var n: int = int(_float_stack.get(uid, 0))
	_float_stack[uid] = n + 1
	var sz: Vector2 = lbl.get_minimum_size()
	lbl.position = pos + Vector2(randf_range(-20.0, 20.0) - sz.x * 0.5, -30.0 * float(n % 3))
	lbl.pivot_offset = sz * 0.5
	lbl.scale = Vector2(0.4, 0.4)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(func() -> void:
		_float_stack[uid] = maxi(0, int(_float_stack.get(uid, 1)) - 1)
		lbl.queue_free())


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
	if text != _prompt_label.text and text != "":
		_prompt_panel.pivot_offset = _prompt_panel.get_combined_minimum_size() * 0.5
		_prompt_panel.scale = Vector2(1.12, 1.12)
		_prompt_panel.create_tween().tween_property(_prompt_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", color)
	_prompt_panel.visible = text != ""


func _log_line(bbcode: String) -> void:
	_log.append_text(bbcode + "\n")


func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible


func _bench_text(t: Dictionary) -> String:
	return "%s  %s" % [t["name"], "KO" if not bool(t["alive"]) else "%d%%" % roundi(100.0 * int(t["hp"]) / int(t["max_hp"]))]


func _label(parent: Control, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _hbox(parent: Control, sep: int) -> HBoxContainer:
	var b: HBoxContainer = HBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	parent.add_child(b)
	return b


func _vbox(parent: Control, sep: int) -> VBoxContainer:
	var b: VBoxContainer = VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", sep)
	parent.add_child(b)
	return b


func _center(parent: Control) -> CenterContainer:
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _panel(parent: Control) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## Detaches right away so a refill in the same frame never sees the old children.
func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _spacer(w: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Shows or hides an overlay; showing pops it in (fade + slight scale).
func _set_overlay(p: Control, on: bool) -> void:
	if p.visible == on:
		return
	p.visible = on
	if not on:
		return
	p.pivot_offset = (p.size if p.size.x > 1.0 else p.get_combined_minimum_size()) * 0.5
	p.modulate.a = 0.0
	p.scale = Vector2(0.94, 0.94)
	var tw: Tween = p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_property(p, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Result summary: one column per side listing what each troop dealt; the top damage dealer is MVP.
func _fill_result(snap: Dictionary) -> void:
	var won: bool = int(snap["winner"]) == viewer_side
	_result_label.text = "VICTORY" if won else "DEFEAT"
	_result_label.add_theme_color_override("font_color", UITheme.GOLD if won else UITheme.DANGER)
	_result_sub.text = "Decided on turn %d" % int(snap["cycle"])
	_clear(_result_cols)
	var troops: Dictionary = snap["troops"]
	var mvp: int = -1
	for uid: int in troops:
		if mvp == -1 or int(_damage.get(uid, 0)) > int(_damage.get(mvp, 0)):
			mvp = uid
	for side: int in [viewer_side, 1 - viewer_side]:
		var col: VBoxContainer = _vbox(_result_cols, 6)
		col.custom_minimum_size = Vector2(300, 0)
		var total: int = 0
		var head: Label = _label(col, &"Header")
		for uid: int in troops:
			var t: Dictionary = troops[uid]
			if int(t["side"]) != side:
				continue
			var dealt: int = int(_damage.get(uid, 0))
			total += dealt
			var row: HBoxContainer = _hbox(col, 8)
			var ic: PanelContainer = _portraits.icon(String(t["troop_id"]), SIDE_COLORS[side], 40)
			if not bool(t["alive"]):
				ic.modulate = Color(1, 1, 1, 0.4)
			row.add_child(ic)
			var name_l: Label = _label(row, &"")
			name_l.text = String(t["name"]) + ("" if bool(t["alive"]) else "  (KO)")
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if uid == mvp and dealt > 0:
				var star: PanelContainer = UITheme.chip("MVP", UITheme.GOLD, 12)
				star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(star)
			var dmg: Label = _label(row, &"Header")
			dmg.text = str(dealt)
			dmg.add_theme_font_size_override("font_size", 16)
			dmg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.text = "%s — %d damage" % ["YOU" if side == viewer_side else "FOE", total]
		head.add_theme_color_override("font_color", SIDE_COLORS[side])


## Archetype (family) chip for a troop summary, or null if it has none.
func _archetype_chip(s: Dictionary, h_flags: int) -> PanelContainer:
	var arch: ArchetypeData = ArchetypeRegistry.find(StringName(s["archetype"]))
	if arch == null:
		return null
	var c: PanelContainer = UITheme.chip(arch.display_name, arch.color, 11)
	c.size_flags_horizontal = h_flags
	return c


## Soft dark edges over the arena so the eye lands on the troops.
func _vignette() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh: Shader = Shader.new()
	sh.code = "shader_type canvas_item;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 1.3);
	COLOR = vec4(0.03, 0.02, 0.07, smoothstep(0.3, 0.85, length(d)) * 0.75);
}
"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	r.material = mat
	return r


## Frosted glass: the panel's own rect shows the arena behind it, blurred and tinted (children draw normally).
func _frosted(tint: Color) -> ShaderMaterial:
	var sh: Shader = Shader.new()
	sh.code = "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 3.5).rgb;
	float edge = smoothstep(0.25, 0.95, length((SCREEN_UV - 0.5) * vec2(1.0, 1.3)));
	COLOR = vec4(mix(c, tint.rgb, clamp(tint.a + edge * 0.2, 0.0, 1.0)), 1.0);
}
"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tint", tint)
	return mat
