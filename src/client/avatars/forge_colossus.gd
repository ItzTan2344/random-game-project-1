# Forge Colossus (Tanker): bulky grey golem, moss patches, glowing rune, boulder fists.
extends VoxelTroop

const STONE := Color("#7d7f86")
const STONE_DARK := Color("#55575e")
const MOSS := Color("#5f9c3e")
const RUNE := Color("#ffb23f")


func _build() -> void:
	humanoid(STONE, STONE, STONE_DARK, STONE_DARK, 1.4)
	# Chest slab with a glowing rune.
	box(Vector3(0.7, 0.4, 0.06), Vector3(0, 0.34, 0.2), STONE_DARK, body)
	box(Vector3(0.08, 0.24, 0.02), Vector3(0, 0.34, 0.235), RUNE, body)
	box(Vector3(0.2, 0.06, 0.02), Vector3(0, 0.38, 0.235), RUNE, body)
	# Moss on the shoulders and back.
	box(Vector3(0.9, 0.08, 0.4), Vector3(0, 0.62, -0.02), MOSS, body)
	box(Vector3(0.3, 0.3, 0.06), Vector3(-0.2, 0.3, -0.21), MOSS, body)
	# Small head sunk between the shoulders: brow ridge, glowing eyes, moss tuft.
	box(Vector3(0.76, 0.14, 0.2), Vector3(0, 0.46, 0.26), STONE_DARK, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.12, 0.08, 0.02), Vector3(side * 0.15, 0.32, 0.325), RUNE, head)
	box(Vector3(0.4, 0.1, 0.3), Vector3(0.1, 0.66, -0.1), MOSS, head)
	# Rock pauldrons.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.36, 0.22, 0.36), Vector3(0, 0.04, 0), STONE_DARK, arm, Vector3(0, 20, 8))
	# Boulder fists.
	for hand: Node3D in [hand_l, hand_r]:
		box(Vector3(0.36, 0.34, 0.36), Vector3(0, -0.06, 0.02), STONE_DARK, hand, Vector3(10, 15, 5))
		box(Vector3(0.14, 0.1, 0.14), Vector3(0.08, 0.1, 0.1), MOSS, hand)
