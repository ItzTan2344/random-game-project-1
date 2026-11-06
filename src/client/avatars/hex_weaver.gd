# Hex Weaver (Control): open hood, long robe, orbiting rune cubes.
extends VoxelTroop

const ROBE := Color("#7a6ff0")
const ROBE_DARK := Color("#463c9e")
const TRIM := Color("#e8c547")
const PALE := Color("#e6cdb0")
const RUNE := Color("#7df9ff")
const RUNE_HOT := Color("#ff6bd6")

var _orbit: Node3D


func _build() -> void:
	humanoid(PALE, ROBE, ROBE_DARK, ROBE_DARK)
	# Robe skirt over the legs, gold trim and belt.
	box(Vector3(0.66, 0.5, 0.42), Vector3(0, -0.22, 0), ROBE, body)
	box(Vector3(0.68, 0.06, 0.44), Vector3(0, -0.44, 0), TRIM, body)
	box(Vector3(0.62, 0.08, 0.38), Vector3(0, 0.08, 0), TRIM, body)
	box(Vector3(0.1, 0.5, 0.02), Vector3(0, 0.3, 0.19), TRIM, body)
	# Hood frames the face: top, sides, back, and a drooping peak.
	box(Vector3(0.8, 0.14, 0.7), Vector3(0, 0.66, -0.02), ROBE_DARK, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.06, 0.62, 0.7), Vector3(side * 0.39, 0.32, -0.02), ROBE_DARK, head)
	box(Vector3(0.8, 0.62, 0.08), Vector3(0, 0.32, -0.36), ROBE_DARK, head)
	box(Vector3(0.3, 0.22, 0.3), Vector3(0, 0.78, -0.24), ROBE_DARK, head, Vector3(-25, 0, 0))
	# Wide sleeves.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.26, 0.16, 0.28), Vector3(0, -0.34, 0), ROBE_DARK, arm)
	# Hex orb in the off hand.
	box(Vector3(0.16, 0.16, 0.16), Vector3(0, 0.02, 0.12), RUNE_HOT, hand_l, Vector3(45, 45, 0))
	# Three rune cubes circling the waist.
	_orbit = _pivot(pose, Vector3(0, 1.0, 0))
	for i in 3:
		var a: float = TAU * float(i) / 3.0
		box(Vector3(0.14, 0.14, 0.14), Vector3(cos(a) * 0.75, sin(a * 2.0) * 0.12, sin(a) * 0.75), RUNE, _orbit, Vector3(45, 0, 45))


func _process(delta: float) -> void:
	super(delta)
	_orbit.rotation.y += delta * 1.4
