class_name ArchetypePattern
extends RefCounted
## Background pattern for an archetype card. Call from a CanvasItem's _draw().


static func _h(x: int, y: int) -> int:
	return absi(hash(Vector2i(x, y)))


static func draw(ci: CanvasItem, size: Vector2, a: ArchetypeData) -> void:
	var w: int = int(size.x)
	var h: int = int(size.y)
	var c: Color = a.color
	var l: Color = a.color_light
	match a.pattern:
		&"embers":
			for gx: int in range(4, w - 4, 14):
				for gy: int in range(4, h - 4, 14):
					if _h(gx, gy) % 4 == 0:
						var heat: float = float(gy) / float(h)
						ci.draw_rect(Rect2(gx + _h(gy, gx) % 6, gy, 2, 2), Color(l, 0.12 + 0.4 * heat))
			ci.draw_rect(Rect2(3, h - 6, w - 6, 3), Color(c, 0.55))
		&"waves":
			for y: int in range(6, h - 4, 10):
				for x: int in range(3, w - 8, 8):
					var off: int = ((y / 10) % 2) * 4
					ci.draw_rect(Rect2(x + off, y + ((x / 8) % 2) * 2, 6, 2), Color(c, 0.16))
			ci.draw_rect(Rect2(3, 3, w - 6, 2), Color(l, 0.35))
		&"grain":
			for gx: int in range(3, w - 3, 4):
				for gy: int in range(3, h - 3, 4):
					if (gx / 4 + gy / 4) % 2 == 0 and _h(gx, gy) % 3 == 0:
						ci.draw_rect(Rect2(gx, gy, 2, 2), Color(c, 0.14))
			for p: Vector2 in [Vector2(3, 3), Vector2(w - 9, 3), Vector2(3, h - 9), Vector2(w - 9, h - 9)]:
				ci.draw_rect(Rect2(p, Vector2(6, 6)), Color(l, 0.6))
		&"tread":
			for k: int in range(-h, w, 10):
				var t0: int = maxi(3, -k + 3)
				var t1: int = mini(h - 3, w - k - 3)
				if t1 > t0:
					ci.draw_line(Vector2(k + t0, h - t0), Vector2(k + t1, h - t1), Color(c, 0.12), 2.0)
			for p: Vector2 in [Vector2(5, 5), Vector2(w - 8, 5), Vector2(5, h - 8), Vector2(w - 8, h - 8)]:
				ci.draw_rect(Rect2(p, Vector2(4, 4)), Color(c, 0.8))
				ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 2)), Color(l, 0.9))
			ci.draw_rect(Rect2(4, h - 8, w - 8, 3), Color(l, 0.3))
		&"dust":
			for gx: int in range(4, w - 4, 9):
				for gy: int in range(4, h - 4, 9):
					var r: int = _h(gx, gy) % 7
					if r == 0:
						ci.draw_rect(Rect2(gx, gy, 2, 2), Color(l, 0.45))
					elif r == 1:
						ci.draw_rect(Rect2(gx, gy, 1, 1), Color(c, 0.55))
			ci.draw_rect(Rect2(5, 5, w - 10, h - 10), Color(c, 0.3), false, 1.0)
		&"chevrons":
			for k: int in range(4, w - 12, 16):
				ci.draw_polyline(PackedVector2Array([Vector2(k, 3), Vector2(k + 9, h * 0.5), Vector2(k, h - 3)]), Color(c, 0.12), 2.0)
			ci.draw_line(Vector2(0, h - 3), Vector2(w, h - 3), Color(l, 0.45), 1.0)
