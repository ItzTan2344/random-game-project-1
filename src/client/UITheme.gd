class_name UITheme
## Code-built theme: chunky, bevelled panels and buttons to match the voxel troops.
## Set once on the UI root; children inherit. Pixel font for titles, buttons and numbers; default font for body text.

const BG := Color("#10131c")
const PANEL := Color("#1c2233")
const PANEL_LIGHT := Color("#28304a")
const EDGE := Color("#07090f")
const TEXT := Color("#e9ecf5")
const TEXT_DIM := Color("#8d96ad")
const GOLD := Color("#f2c94c")
const DANGER := Color("#ff6b6b")
const HEAL := Color("#6be38a")

const PIXEL_FONT_PATH := "res://assets/fonts/PixelifySans.ttf"

static var _pixel: Font


static func pixel_font() -> Font:
	if _pixel == null:
		var base: FontFile = load(PIXEL_FONT_PATH)
		var v: FontVariation = FontVariation.new()
		v.base_font = base
		v.variation_opentype = {"wght": 600}
		_pixel = v
	return _pixel


static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 15
	var px: Font = pixel_font()

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", EDGE)

	# Panels: dark slab with a thicker bottom edge (bevel).
	t.set_stylebox("panel", "PanelContainer", box(PANEL, EDGE, 2, 5, 8))
	t.set_stylebox("panel", "TooltipPanel", box(Color("#0d1018"), GOLD.darkened(0.4), 2, 2, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)

	# Buttons: raised slab; pressed drops the bevel; disabled goes flat.
	var face: Color = Color("#34405f")
	t.set_stylebox("normal", "Button", box(face, EDGE, 2, 6, 8))
	t.set_stylebox("hover", "Button", box(face.lightened(0.15), GOLD.darkened(0.2), 2, 6, 8))
	t.set_stylebox("pressed", "Button", box(face.darkened(0.15), EDGE, 2, 2, 8, 4))
	t.set_stylebox("hover_pressed", "Button", box(face.darkened(0.05), GOLD.darkened(0.2), 2, 2, 8, 4))
	t.set_stylebox("disabled", "Button", box(Color("#1a1f2d"), Color("#0b0e16"), 2, 2, 8, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", px)
	t.set_font_size("font_size", "Button", 17)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("#566079"))

	# Gold call-to-action button (Lock In, Play again, Overdrive when armed).
	t.set_type_variation("GoldButton", "Button")
	t.set_stylebox("normal", "GoldButton", box(GOLD.darkened(0.15), EDGE, 2, 6, 8))
	t.set_stylebox("hover", "GoldButton", box(GOLD, Color.WHITE, 2, 6, 8))
	t.set_stylebox("pressed", "GoldButton", box(GOLD.lightened(0.1), Color.WHITE, 2, 2, 8, 4))
	t.set_stylebox("hover_pressed", "GoldButton", box(GOLD.lightened(0.2), Color.WHITE, 2, 2, 8, 4))
	t.set_color("font_color", "GoldButton", EDGE)
	t.set_color("font_hover_color", "GoldButton", EDGE)
	t.set_color("font_pressed_color", "GoldButton", EDGE)
	t.set_color("font_hover_pressed_color", "GoldButton", EDGE)

	# Label variations.
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", px)
	t.set_font_size("font_size", "Title", 34)
	t.set_constant("outline_size", "Title", 8)
	t.set_type_variation("Header", "Label")
	t.set_font("font", "Header", px)
	t.set_font_size("font_size", "Header", 20)
	t.set_constant("outline_size", "Header", 5)
	t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", TEXT_DIM)
	t.set_font_size("font_size", "Dim", 13)

	# Bars.
	var track: StyleBoxFlat = bar_box(Color("#0b0e15"))
	track.border_color = EDGE
	track.set_border_width_all(2)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", bar_box(HEAL))
	t.set_font("font", "ProgressBar", px)

	# Log.
	t.set_font_size("normal_font_size", "RichTextLabel", 13)
	t.set_font_size("bold_font_size", "RichTextLabel", 13)
	t.set_color("default_color", "RichTextLabel", Color("#c9cfde"))
	return t


## Flat slab: border all round, a thicker bottom edge for the bevel, optional extra top margin (pressed shift).
static func box(bg: Color, edge: Color, border: int, bottom: int, radius: int, shift: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.border_width_bottom = bottom
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8 + shift
	s.content_margin_bottom = 8
	s.anti_aliasing = false
	return s


## Bar fill/track: no padding, so bars can be thin.
static func bar_box(color: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(3)
	s.anti_aliasing = false
	return s


## Small pill used for status effects, turn-order chips and badges (body font: the pixel font blurs below ~14px).
static func chip(text: String, color: Color, font_size: int = 12) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s: StyleBoxFlat = box(color.darkened(0.6), color, 2, 2, 4)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color.lightened(0.35))
	p.add_child(l)
	return p
