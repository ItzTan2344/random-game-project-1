# Frost Warden (Control): ice tower shield, crystal pauldrons, cape.
extends VoxelTroop

const ICE := Color("#9fd8ff")
const ICE_DEEP := Color("#4f9fd6")
const SNOW := Color("#f2f7ff")
const CAPE := Color("#7a6ff0")
const STEEL := Color("#8c9bb0")


func _build() -> void:
	humanoid(SKIN, SNOW, STEEL, ICE_DEEP)
	# Chest plate, belt, cape.
	box(Vector3(0.5, 0.34, 0.04), Vector3(0, 0.36, 0.19), ICE, body)
	box(Vector3(0.62, 0.08, 0.38), Vector3(0, 0.06, 0), ICE_DEEP, body)
	box(Vector3(0.62, 0.86, 0.05), Vector3(0, 0.16, -0.21), CAPE, body)
	# Helmet with crystal spikes.
	box(Vector3(0.74, 0.2, 0.66), Vector3(0, 0.62, 0), ICE_DEEP, head)
	box(Vector3(0.74, 0.36, 0.1), Vector3(0, 0.4, -0.31), ICE_DEEP, head)
	box(Vector3(0.12, 0.3, 0.12), Vector3(0, 0.84, 0.05), ICE, head, Vector3(0, 45, 0))
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.1, 0.24, 0.1), Vector3(side * 0.22, 0.78, -0.02), ICE, head, Vector3(0, 45, side * -20))
	# Crystal pauldrons: a slab and an upward shard each.
	for arm: Node3D in [arm_l, arm_r]:
		var out: float = signf(arm.position.x)
		box(Vector3(0.3, 0.12, 0.32), Vector3(0, 0.05, 0), ICE_DEEP, arm)
		box(Vector3(0.1, 0.26, 0.1), Vector3(out * 0.08, 0.2, 0), ICE, arm, Vector3(0, 45, out * -25))
	# Ice tower shield on the off arm, short ice spear in the main hand.
	box(Vector3(0.1, 0.8, 0.56), Vector3(0.14, 0.12, 0.06), ICE, hand_l)
	box(Vector3(0.11, 0.62, 0.08), Vector3(0.15, 0.12, 0.06), SNOW, hand_l)
	box(Vector3(0.11, 0.08, 0.4), Vector3(0.15, 0.2, 0.06), SNOW, hand_l)
	box(Vector3(0.06, 0.06, 0.9), Vector3(0, 0, 0.32), STEEL, hand_r)
	box(Vector3(0.12, 0.12, 0.24), Vector3(0, 0, 0.84), ICE, hand_r, Vector3(0, 0, 45))
