# Clockwork Sentinel (Control): brass automaton, visor eye, spinning gear on the back, piston fist.
extends VoxelTroop

const BRASS := Color("#c9973a")
const BRASS_DARK := Color("#8a6420")
const IRON := Color("#4a4e57")
const EYE_GLOW := Color("#5ff0ff")
const COPPER := Color("#b5653a")

var _gear: Node3D


func _build() -> void:
	humanoid(IRON, BRASS, BRASS_DARK, IRON, 1.1)
	# Rivets and a chest dial.
	box(Vector3(0.24, 0.24, 0.04), Vector3(0, 0.34, 0.2), IRON, body)
	box(Vector3(0.04, 0.16, 0.02), Vector3(0, 0.38, 0.225), EYE_GLOW, body, Vector3(0, 0, 30))
	box(Vector3(0.68, 0.08, 0.4), Vector3(0, 0.06, 0), COPPER, body)
	# Boxy metal head: plating over the skin box, visor slit with one cyan eye, antenna.
	box(Vector3(0.74, 0.66, 0.66), Vector3(0, 0.31, 0), BRASS, head)
	box(Vector3(0.6, 0.12, 0.04), Vector3(0, 0.34, 0.34), IRON, head)
	box(Vector3(0.16, 0.08, 0.02), Vector3(0, 0.34, 0.365), EYE_GLOW, head)
	box(Vector3(0.04, 0.24, 0.04), Vector3(0.2, 0.76, 0), IRON, head)
	box(Vector3(0.08, 0.08, 0.08), Vector3(0.2, 0.9, 0), EYE_GLOW, head)
	# Shoulder bolts.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.26, 0.14, 0.28), Vector3(0, 0.04, 0), IRON, arm)
	# Piston fist on the right arm.
	box(Vector3(0.12, 0.3, 0.12), Vector3(0, 0.1, 0), IRON, hand_r)
	box(Vector3(0.28, 0.24, 0.28), Vector3(0, -0.1, 0.04), COPPER, hand_r)
	# Back gear (animated): hub plus four teeth.
	_gear = _pivot(body, Vector3(0, 0.36, -0.24))
	box(Vector3(0.36, 0.36, 0.06), Vector3.ZERO, BRASS_DARK, _gear)
	for i in 4:
		box(Vector3(0.1, 0.62, 0.05), Vector3.ZERO, BRASS_DARK, _gear, Vector3(0, 0, i * 45.0))
	box(Vector3(0.12, 0.12, 0.08), Vector3(0, 0, -0.02), IRON, _gear)


func _process(delta: float) -> void:
	super(delta)
	if _gear != null and not dead:
		_gear.rotation.z += delta * 1.5
