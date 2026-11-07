# Ember Reaver (Tanker): scythe, white spiky hair, tattered cape.
extends VoxelTroop

const COAT := Color("#8e1b2a")
const BLACK := Color("#1c1418")
const PALE := Color("#dcc8b8")
const HAIR := Color("#ece8e2")
const RED_EYE := Color("#ff2b3d")
const BLADE := Color("#b9c0c9")
const WOOD := Color("#3a2620")
const CAPE_LENGTHS: Array[float] = [0.8, 1.0, 0.7]


func _build() -> void:
	humanoid(PALE, COAT, BLACK, BLACK)
	# Glowing eyes over the default ones.
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.12, 0.08, 0.02), Vector3(side * 0.15, 0.3, 0.32), RED_EYE, head)
	# Spiky hair.
	box(Vector3(0.74, 0.14, 0.66), Vector3(0, 0.64, 0), HAIR, head)
	box(Vector3(0.74, 0.36, 0.12), Vector3(0, 0.44, -0.3), HAIR, head)
	for i in 3:
		box(Vector3(0.14, 0.24, 0.14), Vector3(-0.2 + i * 0.2, 0.76, -0.1 + i * 0.03), HAIR, head, Vector3(-20, 0, 20 - i * 20))
	# Belt with a red buckle, high collar.
	box(Vector3(0.62, 0.08, 0.38), Vector3(0, 0.06, 0), BLACK, body)
	box(Vector3(0.12, 0.1, 0.02), Vector3(0, 0.06, 0.2), RED_EYE, body)
	box(Vector3(0.66, 0.16, 0.42), Vector3(0, 0.56, -0.02), BLACK, body)
	# Tattered cape: strips of uneven length.
	for i in 3:
		var length: float = CAPE_LENGTHS[i]
		box(Vector3(0.2, length, 0.04), Vector3(-0.2 + i * 0.2, 0.56 - length * 0.5, -0.21), COAT, body)
	# Scythe: shaft held upright, blade sweeping forward from the top.
	box(Vector3(0.07, 1.6, 0.07), Vector3(0, 0.3, 0), WOOD, hand_r)
	box(Vector3(0.06, 0.12, 0.5), Vector3(0, 1.08, 0.24), BLADE, hand_r)
	box(Vector3(0.06, 0.1, 0.3), Vector3(0, 0.98, 0.58), BLADE, hand_r, Vector3(-30, 0, 0))
	box(Vector3(0.08, 0.08, 0.1), Vector3(0, 1.08, -0.02), RED_EYE, hand_r)
