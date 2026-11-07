# Void Fox (Pivot): black and crimson ninja, fox mask with ears, twin daggers, swaying tail.
extends VoxelTroop

const CLOTH := Color("#1f1d26")
const CLOTH_DARK := Color("#14121a")
const CRIMSON := Color("#c8283c")
const MASK := Color("#f4efe6")
const STEEL := Color("#c9d1dc")

var _tail: Node3D


func _build() -> void:
	humanoid(SKIN, CLOTH, CLOTH_DARK, CLOTH_DARK)
	# Crimson sash with a trailing tie.
	box(Vector3(0.64, 0.1, 0.4), Vector3(0, 0.08, 0), CRIMSON, body)
	box(Vector3(0.1, 0.3, 0.04), Vector3(0.2, -0.08, -0.21), CRIMSON, body, Vector3(0, 0, 15))
	# Hood and fox mask: white face plate, red markings, pointed snout, ears.
	box(Vector3(0.76, 0.64, 0.66), Vector3(0, 0.33, -0.02), CLOTH, head)
	box(Vector3(0.62, 0.4, 0.04), Vector3(0, 0.3, 0.32), MASK, head)
	box(Vector3(0.22, 0.14, 0.14), Vector3(0, 0.2, 0.4), MASK, head)
	box(Vector3(0.06, 0.05, 0.04), Vector3(0, 0.24, 0.48), CLOTH_DARK, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.14, 0.04, 0.02), Vector3(side * 0.15, 0.36, 0.345), CRIMSON, head, Vector3(0, 0, side * 15))
		box(Vector3(0.16, 0.24, 0.08), Vector3(side * 0.24, 0.76, 0), CLOTH, head, Vector3(0, 0, side * -12))
		box(Vector3(0.08, 0.14, 0.04), Vector3(side * 0.24, 0.74, 0.04), CRIMSON, head, Vector3(0, 0, side * -12))
	# Twin daggers held point-forward.
	for hand: Node3D in [hand_l, hand_r]:
		box(Vector3(0.06, 0.06, 0.12), Vector3(0, 0, 0.12), CRIMSON, hand)
		box(Vector3(0.04, 0.1, 0.36), Vector3(0, 0, 0.34), STEEL, hand)
	# Tail (animated sway): base, body, white tip.
	_tail = _pivot(body, Vector3(0, 0.05, -0.2))
	box(Vector3(0.18, 0.18, 0.3), Vector3(0, 0.04, -0.14), CRIMSON, _tail, Vector3(-30, 0, 0))
	box(Vector3(0.22, 0.22, 0.3), Vector3(0, 0.2, -0.36), CRIMSON, _tail, Vector3(-45, 0, 0))
	box(Vector3(0.16, 0.16, 0.16), Vector3(0, 0.38, -0.5), MASK, _tail, Vector3(-45, 0, 0))


func _process(delta: float) -> void:
	super(delta)
	if _tail != null and not dead:
		_tail.rotation.y = sin(_t * 2.0) * 0.4
