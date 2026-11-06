# Swift Courier (Pivot): slim runner, streaming scarf, satchel, winged cap.
extends VoxelTroop

const TUNIC := Color("#3fb58c")
const TUNIC_DARK := Color("#24735a")
const SCARF := Color("#ffd23f")
const LEATHER := Color("#8a5a33")
const FEATHER := Color("#f5f5f0")
const PAPER := Color("#fff8e1")


func _build() -> void:
	humanoid(SKIN, TUNIC, TUNIC_DARK, LEATHER, 0.85)
	# Cap with a visor and side feathers.
	box(Vector3(0.74, 0.18, 0.66), Vector3(0, 0.66, 0), TUNIC_DARK, head)
	box(Vector3(0.5, 0.04, 0.22), Vector3(0, 0.58, 0.38), TUNIC_DARK, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.04, 0.2, 0.32), Vector3(side * 0.39, 0.66, -0.1), FEATHER, head, Vector3(-30, 0, 0))
	# Scarf wrap and a tail streaming back.
	box(Vector3(0.56, 0.12, 0.4), Vector3(0, 0.56, 0), SCARF, body)
	box(Vector3(0.14, 0.08, 0.5), Vector3(0.12, 0.54, -0.42), SCARF, body, Vector3(-15, 0, 0))
	box(Vector3(0.12, 0.06, 0.3), Vector3(0.14, 0.6, -0.78), SCARF, body, Vector3(-30, 0, 0))
	# Strap across the chest and the satchel on the hip.
	box(Vector3(0.08, 0.66, 0.4), Vector3(0, 0.3, 0), LEATHER, body, Vector3(0, 0, -35))
	box(Vector3(0.12, 0.26, 0.32), Vector3(-0.32, 0.08, 0.02), LEATHER, body)
	box(Vector3(0.13, 0.08, 0.33), Vector3(-0.32, 0.18, 0.02), TUNIC_DARK, body)
	# Winged boots.
	for leg: Node3D in [leg_l, leg_r]:
		box(Vector3(0.04, 0.12, 0.2), Vector3(signf(leg.position.x) * 0.14, -0.42, -0.06), FEATHER, leg, Vector3(-30, 0, 0))
	# A letter in hand.
	box(Vector3(0.04, 0.18, 0.26), Vector3(0, 0.02, 0.12), PAPER, hand_r)
