class_name TroopCard
extends PanelContainer
## One field slot: name, HP/shield, CR, status chips. Click to target.

signal clicked(uid: int)

const ARCHETYPE_NAMES: Array[String] = ["Aggro", "Control", "Bruiser", "Pivot"]
const ARCHETYPE_COLORS: Array[Color] = [Color("#e0603a"), Color("#7a6ff0"), Color("#c9a13b"), Color("#3fb58c")]
const STAT_SHORT: Array[String] = ["ATK", "DEF", "SPD", "CRIT", "EFF", "RES"]
const BUFF := Color("#6fb8ff")
const DEBUFF := Color("#ff8a65")

var uid: int = -1
var side: int = 0
var slot: int = 0

var _style: StyleBoxFlat
var _portrait: TextureRect
var _name_label: Label
var _arch_box: HBoxContainer
var _hp_trail: ProgressBar
var _hp_bar: ProgressBar
var _hp_label: Label
var _cr_bar: ProgressBar
var _chips: HFlowContainer
var _max_hp: int = 1
var _shield: int = 0
var _highlight: int = 0
var _hovered: bool = false
var _trail_tween: Tween


func _init(p_side: int, p_slot: int) -> void:
	side = p_side
	slot = p_slot
	custom_minimum_size = Vector2(310, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = UITheme.box(Color.BLACK, UITheme.EDGE, 2, 5, 8)
	_style.content_margin_top = 8
	_style.content_margin_left = 8
	add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var frame: PanelContainer = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var fs: StyleBoxFlat = UITheme.box(BattleUI.SIDE_COLORS[side].darkened(0.7), BattleUI.SIDE_COLORS[side].darkened(0.2), 2, 3, 5)
	fs.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fs)
	row.add_child(frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(62, 62)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_portrait)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	row.add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	_name_label = Label.new()
	_name_label.theme_type_variation = &"Header"
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)
	_arch_box = HBoxContainer.new()
	header.add_child(_arch_box)

	# HP: a pale trail bar behind the real one drains after a hit.
	var hp_stack: Control = Control.new()
	hp_stack.custom_minimum_size = Vector2(0, 18)
	hp_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hp_stack)
	_hp_trail = _bar(hp_stack, Color("#f4e2b8"))
	_hp_bar = _bar(hp_stack, UITheme.HEAL)
	_hp_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_hp_label = Label.new()
	_hp_label.add_theme_font_override("font", UITheme.pixel_font())
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_constant_override("outline_size", 4)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_stack.add_child(_hp_label)
	_cr_bar = _bar(box, UITheme.GOLD)
	_cr_bar.custom_minimum_size = Vector2(0, 7)
	_cr_bar.tooltip_text = "Combat Readiness"

	_chips = HFlowContainer.new()
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.custom_minimum_size = Vector2(0, 20)
	_chips.add_theme_constant_override("h_separation", 4)
	_chips.add_theme_constant_override("v_separation", 4)
	box.add_child(_chips)
	clear_card()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and uid != -1:
		clicked.emit(uid)


func clear_card() -> void:
	uid = -1
	_name_label.text = "— empty —"
	_name_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_portrait.texture = null
	_clear(_arch_box)
	_hp_bar.value = 0
	_hp_trail.value = 0
	_hp_label.text = ""
	_cr_bar.value = 0
	_clear(_chips)
	modulate = Color(1, 1, 1, 0.45)
	set_highlight(0)


func bind(p_uid: int, troop_name: String, archetype: int, portrait: Texture2D) -> void:
	uid = p_uid
	_portrait.texture = portrait
	_name_label.text = troop_name
	_name_label.add_theme_color_override("font_color", UITheme.TEXT)
	_clear(_arch_box)
	_arch_box.add_child(UITheme.chip(ARCHETYPE_NAMES[archetype], ARCHETYPE_COLORS[archetype], 11))
	modulate = Color.WHITE


func set_hp(hp: int, max_hp: int, shield: int) -> void:
	_max_hp = max_hp
	_shield = shield
	_hp_bar.max_value = max_hp
	_hp_trail.max_value = max_hp
	if hp >= _hp_bar.value or _hp_trail.value < hp:
		_hp_trail.value = hp
	_hp_bar.value = hp
	if _trail_tween != null:
		_trail_tween.kill()
	_trail_tween = create_tween()
	_trail_tween.tween_property(_hp_trail, "value", float(hp), 0.4).set_delay(0.35)
	var ratio: float = float(hp) / maxf(1.0, float(max_hp))
	(_hp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = UITheme.HEAL if ratio > 0.5 else (UITheme.GOLD if ratio > 0.25 else UITheme.DANGER)
	_hp_label.text = "%d / %d" % [hp, max_hp] + ("  +%d" % shield if shield > 0 else "")
	if hp <= 0:
		modulate = Color(1, 1, 1, 0.35)


## Mid-playback update; shield -1 keeps the last known value.
func update_hp(hp: int, shield: int = -1) -> void:
	set_hp(hp, _max_hp, _shield if shield < 0 else shield)


func set_cr(cr: float) -> void:
	_cr_bar.value = cr


func set_effects(effects: Array, cooldowns: Array) -> void:
	_clear(_chips)
	for e: Dictionary in effects:
		var c: PanelContainer = UITheme.chip("%s %d" % [effect_text(e), int(e["remaining"])], DEBUFF if bool(e.get("debuff", false)) else BUFF, 11)
		c.tooltip_text = "%s — %d turn(s) left" % [effect_tooltip(e), int(e["remaining"])]
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		_chips.add_child(c)
	for i in cooldowns.size():
		if int(cooldowns[i]) > 0:
			var cd: PanelContainer = UITheme.chip("S%d CD %d" % [i + 1, int(cooldowns[i])], UITheme.TEXT_DIM, 11)
			cd.tooltip_text = "Skill %d is ready in %d turn(s)" % [i + 1, int(cooldowns[i])]
			cd.mouse_filter = Control.MOUSE_FILTER_PASS
			_chips.add_child(cd)


## 0 = none, 1 = acting, 2 = targetable.
func set_highlight(mode: int) -> void:
	_highlight = mode
	_restyle()


func flash(color: Color) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "self_modulate", color, 0.06)
	tw.tween_property(self, "self_modulate", Color.WHITE, 0.2)
	pivot_offset = size * 0.5
	var shake: Tween = create_tween()
	shake.tween_property(self, "scale", Vector2(1.04, 1.04), 0.06)
	shake.tween_property(self, "scale", Vector2.ONE, 0.12)


func _set_hover(on: bool) -> void:
	_hovered = on
	_restyle()


func _restyle() -> void:
	var base: Color = UITheme.PANEL.lerp(BattleUI.SIDE_COLORS[side], 0.1)
	_style.bg_color = base
	_style.border_color = UITheme.EDGE
	_style.shadow_size = 0
	match _highlight:
		1:
			_style.border_color = UITheme.GOLD
			_style.shadow_color = Color(UITheme.GOLD, 0.35)
			_style.shadow_size = 8
		2:
			_style.border_color = UITheme.DANGER
			_style.shadow_color = Color(UITheme.DANGER, 0.5 if _hovered else 0.25)
			_style.shadow_size = 10 if _hovered else 6
			if _hovered:
				_style.bg_color = base.lightened(0.15)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _highlight == 2 else Control.CURSOR_ARROW


static func effect_text(e: Dictionary) -> String:
	match int(e["kind"]):
		CombatTypes.EffectKind.STAT_MOD:
			return "%s%+d%%" % [STAT_SHORT[int(e["stat"])], roundi(float(e["magnitude"]) * 100.0)]
		CombatTypes.EffectKind.STUN:
			return "Stun"
		CombatTypes.EffectKind.DOT:
			return "Burn"
		CombatTypes.EffectKind.SHIELD:
			return "Shield"
	return CombatTypes.EffectKind.keys()[int(e["kind"])].capitalize()


static func effect_tooltip(e: Dictionary) -> String:
	match int(e["kind"]):
		CombatTypes.EffectKind.STAT_MOD:
			return "%s %s by %d%%" % [CombatTypes.Stat.keys()[int(e["stat"])].capitalize(), "lowered" if float(e["magnitude"]) < 0.0 else "raised", absi(roundi(float(e["magnitude"]) * 100.0))]
		CombatTypes.EffectKind.STUN:
			return "Stunned: loses its next turn"
		CombatTypes.EffectKind.DOT:
			return "Burn: takes damage every turn"
		CombatTypes.EffectKind.SHIELD:
			return "Shield: absorbs incoming damage"
	return effect_text(e)


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _bar(parent: Control, color: Color) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("fill", UITheme.bar_box(color))
	parent.add_child(b)
	if parent is VBoxContainer:
		return b
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b
