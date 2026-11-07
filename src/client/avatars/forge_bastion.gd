# Forge Bastion (Tanker): bulky full plate, great helm, tower shield, mace.
extends VoxelTroop

const IRON := Color("#5d6470")
const IRON_DARK := Color("#3b4049")
const GOLD := Color("#c9a13b")
const VISOR := Color("#14161b")


func _build() -> void:
	humanoid(IRON, IRON, IRON_DARK, IRON_DARK, 1.35)
	# Gold-trimmed breastplate and belt.
	box(Vector3(0.66, 0.4, 0.05), Vector3(0, 0.34, 0.19), IRON_DARK, body)
	box(Vector3(0.12, 0.4, 0.06), Vector3(0, 0.34, 0.2), GOLD, body)
	box(Vector3(0.84, 0.1, 0.4), Vector3(0, 0.06, 0), GOLD, body)
	# Great helm swallows the head: shell, T-shaped visor, gold ridge.
	box(Vector3(0.76, 0.68, 0.68), Vector3(0, 0.32, 0), IRON, head)
	box(Vector3(0.5, 0.06, 0.02), Vector3(0, 0.34, 0.345), VISOR, head)
	box(Vector3(0.06, 0.3, 0.02), Vector3(0, 0.16, 0.345), VISOR, head)
	box(Vector3(0.1, 0.12, 0.72), Vector3(0, 0.7, 0), GOLD, head)
	# Massive layered pauldrons.
	for arm: Node3D in [arm_l, arm_r]:
		var out: float = signf(arm.position.x)
		box(Vector3(0.38, 0.16, 0.38), Vector3(out * 0.04, 0.06, 0), IRON_DARK, arm)
		box(Vector3(0.4, 0.04, 0.4), Vector3(out * 0.04, 0.0, 0), GOLD, arm)
	# Tower shield with gold rim and boss.
	box(Vector3(0.12, 1.1, 0.7), Vector3(0.16, 0.15, 0.08), IRON_DARK, hand_l)
	box(Vector3(0.13, 1.12, 0.06), Vector3(0.16, 0.15, 0.43), GOLD, hand_l)
	box(Vector3(0.13, 0.06, 0.72), Vector3(0.16, 0.7, 0.08), GOLD, hand_l)
	box(Vector3(0.14, 0.2, 0.2), Vector3(0.18, 0.2, 0.08), GOLD, hand_l)
	# Flanged mace.
	box(Vector3(0.07, 0.07, 0.6), Vector3(0, 0, 0.26), IRON_DARK, hand_r)
	box(Vector3(0.22, 0.22, 0.22), Vector3(0, 0, 0.62), IRON, hand_r, Vector3(0, 0, 45))
	box(Vector3(0.08, 0.08, 0.08), Vector3(0, 0, 0.78), GOLD, hand_r)
