class_name ArchetypeBackdrop
extends Control
## Full-rect archetype tint + pattern + corner emblem, added as the first child of a tile.

var _arch: ArchetypeData


func _init(p_arch: ArchetypeData) -> void:
	_arch = p_arch
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(_arch.color_dark, 0.55))
	ArchetypePattern.draw(self, size, _arch)
	draw_rect(Rect2(0, 0, size.x, 3), _arch.color)
	var px: int = 3
	for y: int in _arch.emblem.size():
		var row: String = _arch.emblem[y]
		for x: int in row.length():
			if row[x] == "1" or row[x] == "2":
				draw_rect(Rect2(size.x - 10 - (row.length() - x) * px, 8 + y * px, px, px), _arch.color if row[x] == "1" else _arch.color_light)
