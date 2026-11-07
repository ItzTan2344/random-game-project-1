class_name ArchetypeEmblem
extends Control
## Draws an archetype's pixel emblem.

var _arch: ArchetypeData
var _px: int = 3


func _init(p_arch: ArchetypeData, pixel: int = 3) -> void:
	_arch = p_arch
	_px = pixel
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: int = 0
	for row: String in _arch.emblem:
		w = maxi(w, row.length())
	custom_minimum_size = Vector2(w * _px, _arch.emblem.size() * _px)


func _draw() -> void:
	for y: int in _arch.emblem.size():
		var row: String = _arch.emblem[y]
		for x: int in row.length():
			var k: String = row[x]
			if k == "1" or k == "2":
				draw_rect(Rect2(x * _px, y * _px, _px, _px), _arch.color if k == "1" else _arch.color_light)
