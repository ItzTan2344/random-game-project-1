class_name TroopCard
extends PanelContainer
## One field slot: name, HP/shield, CR, statuses. Click to target.

signal clicked(uid: int)

const ARCHETYPE_NAMES: Array[String] = ["Aggro", "Control", "Bruiser", "Pivot"]
const ARCHETYPE_COLORS: Array[Color] = [Color("#e0603a"), Color("#7a6ff0"), Color("#c9a13b"), Color("#3fb58c")]
const STAT_SHORT: Array[String] = ["ATK", "DEF", "SPD", "CRIT", "EFF", "RES"]

var uid: int = -1
var side: int = 0
var slot: int = 0

var _style: StyleBoxFlat
var _name_label: Label
var _arch_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _cr_bar: ProgressBar
var _status_label: Label
var _max_hp: int = 1
var _shield: int = 0


func _init(p_side: int, p_slot: int) -> void:
	side = p_side
	slot = p_slot
	custom_minimum_size = Vector2(250, 128)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = custom_minimum_size * 0.5
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("#1d2230")
	_style.set_corner_radius_all(8)
	_style.set_border_width_all(2)
	_style.border_color = Color("#2c3448")
	_style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", _style)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	_name_label = _label(header, 17)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arch_label = _label(header, 12)
	_hp_bar = _bar(box, Color("#4cc26a"), 16)
	_hp_label = _label(_hp_bar, 12)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cr_bar = _bar(box, Color("#e8c547"), 6)
	_status_label = _label(box, 11)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color(1, 1, 1, 0.8)
	clear_card()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and uid != -1:
		clicked.emit(uid)


func clear_card() -> void:
	uid = -1
	_name_label.text = "— empty —"
	_arch_label.text = ""
	_hp_bar.value = 0
	_hp_label.text = ""
	_cr_bar.value = 0
	_status_label.text = ""
	modulate = Color(1, 1, 1, 0.45)
	set_highlight(0)


func bind(p_uid: int, troop_name: String, archetype: int) -> void:
	uid = p_uid
	_name_label.text = troop_name
	_arch_label.text = ARCHETYPE_NAMES[archetype]
	_arch_label.add_theme_color_override("font_color", ARCHETYPE_COLORS[archetype])
	modulate = Color.WHITE


func set_hp(hp: int, max_hp: int, shield: int) -> void:
	_max_hp = max_hp
	_shield = shield
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [hp, max_hp] + ("  (+%d)" % shield if shield > 0 else "")
	if hp <= 0:
		modulate = Color(1, 1, 1, 0.35)


## Mid-playback update; shield -1 keeps the last known value.
func update_hp(hp: int, shield: int = -1) -> void:
	set_hp(hp, _max_hp, _shield if shield < 0 else shield)


func set_cr(cr: float) -> void:
	_cr_bar.value = cr


func set_effects(effects: Array, cooldowns: Array) -> void:
	var parts: PackedStringArray = []
	for e: Dictionary in effects:
		parts.append(effect_text(e) + " %dt" % int(e["remaining"]))
	var cd_text: PackedStringArray = []
	for i in cooldowns.size():
		if int(cooldowns[i]) > 0:
			cd_text.append("S%d:%d" % [i + 1, int(cooldowns[i])])
	if not cd_text.is_empty():
		parts.append("CD " + " ".join(cd_text))
	_status_label.text = "  ".join(parts)


## 0 = none, 1 = acting, 2 = targetable.
func set_highlight(mode: int) -> void:
	match mode:
		1:
			_style.border_color = Color("#e8c547")
		2:
			_style.border_color = Color("#ff5a5a")
		_:
			_style.border_color = Color("#2c3448")


func flash(color: Color) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "self_modulate", color, 0.06)
	tw.tween_property(self, "self_modulate", Color.WHITE, 0.2)
	var shake: Tween = create_tween()
	shake.tween_property(self, "scale", Vector2(1.04, 1.04), 0.06)
	shake.tween_property(self, "scale", Vector2.ONE, 0.12)


func float_text(text: String, color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.top_level = true
	lbl.z_index = 10
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	add_child(lbl)
	lbl.global_position = global_position + Vector2(size.x * 0.5 - 30.0 + randf_range(-25.0, 25.0), 10.0)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 50.0, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


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


func _label(parent: Control, font_size: int) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color, height: float) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size = Vector2(0, height)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#0e1118")
	bg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b
