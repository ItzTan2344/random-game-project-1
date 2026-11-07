# Storm Herald (Pivot): gold and white tabard, plumed helm, tall war banner on a pole.
extends VoxelTroop

const TABARD := Color("#f2ede0")
const GOLD := Color("#e0b23a")
const GOLD_DARK := Color("#a07a1e")
const STEEL := Color("#b9c2cf")
const FLAG := Color("#2f5fb8")
const WOOD := Color("#6b4a2a")


func _build() -> void:
	humanoid(SKIN, STEEL, GOLD_DARK, GOLD_DARK)
	# Tabard over the armour with a gold sun emblem.
	box(Vector3(0.5, 0.86, 0.04), Vector3(0, 0.16, 0.2), TABARD, body)
	box(Vector3(0.2, 0.2, 0.02), Vector3(0, 0.36, 0.225), GOLD, body, Vector3(0, 0, 45))
	box(Vector3(0.64, 0.08, 0.4), Vector3(0, 0.06, 0), GOLD, body)
	# Open-face helm with a blue plume.
	box(Vector3(0.76, 0.2, 0.68), Vector3(0, 0.62, 0), STEEL, head)
	box(Vector3(0.76, 0.46, 0.1), Vector3(0, 0.34, -0.32), STEEL, head)
	box(Vector3(0.1, 0.08, 0.06), Vector3(0, 0.44, 0.34), STEEL, head)
	box(Vector3(0.1, 0.26, 0.5), Vector3(0, 0.84, -0.1), FLAG, head, Vector3(15, 0, 0))
	# Gold pauldrons.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.28, 0.12, 0.3), Vector3(0, 0.04, 0), GOLD, arm)
	# Banner: pole, gold finial, crossbar, flag with an emblem.
	box(Vector3(0.07, 2.2, 0.07), Vector3(0, 0.6, 0.06), WOOD, hand_r)
	box(Vector3(0.12, 0.16, 0.12), Vector3(0, 1.76, 0.06), GOLD, hand_r, Vector3(0, 45, 0))
	box(Vector3(0.05, 0.05, 0.6), Vector3(0, 1.6, 0.34), GOLD, hand_r)
	box(Vector3(0.03, 0.66, 0.56), Vector3(0, 1.26, 0.34), FLAG, hand_r)
	box(Vector3(0.04, 0.18, 0.18), Vector3(0, 1.3, 0.34), GOLD, hand_r, Vector3(45, 0, 0))
