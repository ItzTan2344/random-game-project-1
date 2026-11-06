# Grove Keeper (Pivot): antler crown, mossy beard, leafy staff.
extends VoxelTroop

const ROBE := Color("#6b4a2e")
const ROBE_DARK := Color("#4a3220")
const MOSS := Color("#3fb58c")
const LEAF := Color("#7ed957")
const ANTLER := Color("#e9dcc3")
const BEARD := Color("#d9d4c7")
const WOOD := Color("#5a3d24")


func _build() -> void:
	humanoid(SKIN, ROBE, ROBE_DARK, ROBE_DARK)
	# Robe skirt with a moss hem, vine belt, moss mantle.
	box(Vector3(0.66, 0.5, 0.42), Vector3(0, -0.22, 0), ROBE, body)
	box(Vector3(0.68, 0.08, 0.44), Vector3(0, -0.44, 0), MOSS, body)
	box(Vector3(0.62, 0.08, 0.38), Vector3(0, 0.08, 0), MOSS, body)
	box(Vector3(0.7, 0.14, 0.44), Vector3(0, 0.54, 0), MOSS, body)
	# Beard and brows.
	box(Vector3(0.5, 0.3, 0.08), Vector3(0, 0.08, 0.34), BEARD, head)
	box(Vector3(0.3, 0.14, 0.06), Vector3(0, -0.08, 0.36), BEARD, head)
	box(Vector3(0.5, 0.05, 0.03), Vector3(0, 0.42, 0.32), BEARD, head)
	# Leaf crown and branching antlers.
	box(Vector3(0.74, 0.1, 0.66), Vector3(0, 0.64, 0), LEAF, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.07, 0.36, 0.07), Vector3(side * 0.26, 0.84, -0.04), ANTLER, head, Vector3(0, 0, side * -25))
		box(Vector3(0.06, 0.2, 0.06), Vector3(side * 0.42, 1.0, -0.04), ANTLER, head, Vector3(0, 0, side * -60))
		box(Vector3(0.06, 0.2, 0.06), Vector3(side * 0.3, 1.06, 0.02), ANTLER, head, Vector3(20, 0, side * 10))
	# Staff topped with a knot and leaf cubes.
	box(Vector3(0.08, 1.7, 0.08), Vector3(0, 0.35, 0.06), WOOD, hand_r)
	box(Vector3(0.18, 0.18, 0.18), Vector3(0, 1.22, 0.06), WOOD, hand_r, Vector3(0, 45, 0))
	box(Vector3(0.14, 0.14, 0.14), Vector3(0.1, 1.34, 0.12), LEAF, hand_r, Vector3(30, 30, 0))
	box(Vector3(0.12, 0.12, 0.12), Vector3(-0.1, 1.3, 0.0), MOSS, hand_r, Vector3(0, 30, 30))
	box(Vector3(0.1, 0.1, 0.1), Vector3(0, 1.4, -0.06), LEAF, hand_r, Vector3(45, 0, 45))
