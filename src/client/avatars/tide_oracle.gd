# Tide Oracle (Controller): white and teal robes, blindfold, floating mirror halo.
extends VoxelTroop

const ROBE := Color("#e8eef2")
const ROBE_SHADE := Color("#b8c6cf")
const TEAL := Color("#2fb7a6")
const MIRROR := Color("#cfefff")
const GOLD := Color("#e0b84a")

var _halo: Node3D


func _build() -> void:
	humanoid(SKIN, ROBE, ROBE_SHADE, TEAL)
	# Robe skirt, teal sash, collar.
	box(Vector3(0.66, 0.52, 0.42), Vector3(0, -0.22, 0), ROBE, body)
	box(Vector3(0.64, 0.1, 0.4), Vector3(0, 0.08, 0), TEAL, body)
	box(Vector3(0.66, 0.1, 0.4), Vector3(0, 0.56, 0), GOLD, body)
	box(Vector3(0.14, 0.52, 0.02), Vector3(0, -0.22, 0.215), TEAL, body)
	# Teal blindfold over the eyes, tied at the back; long pale hair.
	box(Vector3(0.74, 0.12, 0.66), Vector3(0, 0.3, 0), TEAL, head)
	box(Vector3(0.12, 0.26, 0.06), Vector3(0.08, 0.2, -0.34), TEAL, head, Vector3(0, 0, 15))
	box(Vector3(0.76, 0.18, 0.68), Vector3(0, 0.66, 0), ROBE_SHADE, head)
	box(Vector3(0.74, 0.7, 0.1), Vector3(0, 0.2, -0.32), ROBE_SHADE, head)
	# Hand mirror in the left hand.
	box(Vector3(0.05, 0.22, 0.05), Vector3(0, 0.08, 0.06), GOLD, hand_l)
	box(Vector3(0.06, 0.26, 0.26), Vector3(0, 0.3, 0.06), GOLD, hand_l)
	box(Vector3(0.07, 0.2, 0.2), Vector3(0, 0.3, 0.06), MIRROR, hand_l)
	# Halo of mirror panes behind the head (animated).
	_halo = _pivot(head, Vector3(0, 0.4, -0.5))
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		box(Vector3(0.16, 0.2, 0.03), Vector3(cos(a) * 0.5, sin(a) * 0.5, 0), MIRROR, _halo, Vector3(0, 0, rad_to_deg(a)))
	box(Vector3(0.14, 0.14, 0.04), Vector3.ZERO, GOLD, _halo, Vector3(0, 0, 45))


func _process(delta: float) -> void:
	super(delta)
	if _halo != null and not dead:
		_halo.rotation.z += delta * 0.6
