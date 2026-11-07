# Tide Caller (Pivot): blue and seafoam robes, shell pauldrons, coral crown, trident.
extends VoxelTroop

const SEA := Color("#2a6fb5")
const SEA_DARK := Color("#1b4a7a")
const FOAM := Color("#8fe3d0")
const SHELL := Color("#f2c9b0")
const CORAL := Color("#ff7f6e")
const STEEL := Color("#c9d6dc")


func _build() -> void:
	humanoid(SKIN, SEA, SEA_DARK, SEA_DARK)
	# Wave-hem skirt and foam sash.
	box(Vector3(0.66, 0.48, 0.42), Vector3(0, -0.2, 0), SEA, body)
	for i in 3:
		box(Vector3(0.2, 0.08, 0.44), Vector3(-0.22 + i * 0.22, -0.44 + (i % 2) * 0.04, 0), FOAM, body)
	box(Vector3(0.64, 0.08, 0.4), Vector3(0, 0.08, 0), FOAM, body)
	# Seafoam hair and coral crown.
	box(Vector3(0.76, 0.16, 0.68), Vector3(0, 0.66, 0), FOAM, head)
	box(Vector3(0.74, 0.5, 0.1), Vector3(0, 0.3, -0.32), FOAM, head)
	for i in 3:
		box(Vector3(0.07, 0.2 + (i % 2) * 0.1, 0.07), Vector3(-0.2 + i * 0.2, 0.84 + (i % 2) * 0.05, 0.1), CORAL, head)
	# Shell pauldrons.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.3, 0.12, 0.32), Vector3(0, 0.06, 0), SHELL, arm)
		box(Vector3(0.22, 0.06, 0.24), Vector3(0, 0.14, 0), SHELL, arm)
	# Trident: shaft, crossbar, three prongs.
	box(Vector3(0.07, 1.7, 0.07), Vector3(0, 0.35, 0.06), SEA_DARK, hand_r)
	box(Vector3(0.36, 0.06, 0.06), Vector3(0, 1.2, 0.06), STEEL, hand_r)
	for x: float in [-0.15, 0.0, 0.15]:
		box(Vector3(0.05, 0.26 if x == 0.0 else 0.2, 0.05), Vector3(x, 1.34 if x == 0.0 else 1.31, 0.06), STEEL, hand_r)
