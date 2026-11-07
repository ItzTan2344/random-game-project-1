# Storm Lancer (Duelist): long lance, crested helm, lightning sigil.
extends VoxelTroop

const ARMOR := Color("#2d4e8a")
const ARMOR_DARK := Color("#1d3360")
const STEEL := Color("#c9d1dc")
const BOLT := Color("#ffd23f")
const CREST := Color("#e0603a")
const WOOD := Color("#7a5230")


func _build() -> void:
	humanoid(SKIN, ARMOR, ARMOR_DARK, ARMOR_DARK)
	# Lightning bolt on the chest.
	box(Vector3(0.08, 0.2, 0.02), Vector3(0.04, 0.42, 0.19), BOLT, body, Vector3(0, 0, -25))
	box(Vector3(0.16, 0.06, 0.02), Vector3(0, 0.3, 0.19), BOLT, body)
	box(Vector3(0.08, 0.2, 0.02), Vector3(-0.04, 0.18, 0.19), BOLT, body, Vector3(0, 0, -25))
	box(Vector3(0.62, 0.08, 0.38), Vector3(0, 0.06, 0), STEEL, body)
	# Crested helm: cap, back, cheek guards, crest.
	box(Vector3(0.76, 0.22, 0.68), Vector3(0, 0.6, 0), STEEL, head)
	box(Vector3(0.76, 0.42, 0.1), Vector3(0, 0.36, -0.32), STEEL, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.06, 0.34, 0.4), Vector3(side * 0.37, 0.28, 0.08), STEEL, head)
	box(Vector3(0.08, 0.2, 0.7), Vector3(0, 0.8, -0.04), CREST, head)
	box(Vector3(0.08, 0.14, 0.2), Vector3(0, 0.68, -0.44), CREST, head)
	# Pauldrons.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.28, 0.12, 0.3), Vector3(0, 0.04, 0), STEEL, arm)
	# Lance: grip guard, shaft, two-step tip with a spark.
	box(Vector3(0.2, 0.2, 0.08), Vector3(0, 0, 0.1), STEEL, hand_r)
	box(Vector3(0.07, 0.07, 1.5), Vector3(0, 0, 0.5), WOOD, hand_r)
	box(Vector3(0.14, 0.14, 0.22), Vector3(0, 0, 1.3), STEEL, hand_r)
	box(Vector3(0.07, 0.07, 0.2), Vector3(0, 0, 1.5), STEEL, hand_r)
	box(Vector3(0.05, 0.16, 0.05), Vector3(0, 0.12, 1.42), BOLT, hand_r, Vector3(0, 0, 30))
	# Small buckler.
	box(Vector3(0.08, 0.4, 0.4), Vector3(0.1, 0.05, 0.05), ARMOR_DARK, hand_l)
	box(Vector3(0.09, 0.14, 0.14), Vector3(0.12, 0.05, 0.05), BOLT, hand_l)
