# Ember Aggro (Duelist): twin blades, flame topknot.
extends VoxelTroop

const TUNIC := Color("#e0603a")
const PANTS := Color("#3a2a2a")
const BOOTS := Color("#24191a")
const HAIR := Color("#3b2416")
const STEEL := Color("#d8dde6")
const FLAME := Color("#ffb02e")
const FLAME_TIP := Color("#ffe066")
const LEATHER := Color("#6b4226")


func _build() -> void:
	humanoid(SKIN, TUNIC, PANTS, BOOTS)
	# Belt and diagonal sash.
	box(Vector3(0.62, 0.08, 0.38), Vector3(0, 0.06, 0), LEATHER, body)
	box(Vector3(0.12, 0.66, 0.38), Vector3(0, 0.3, 0), PANTS, body, Vector3(0, 0, 32))
	# Hair cap, back hair, flame topknot.
	box(Vector3(0.74, 0.16, 0.66), Vector3(0, 0.64, 0), HAIR, head)
	box(Vector3(0.74, 0.4, 0.12), Vector3(0, 0.42, -0.3), HAIR, head)
	box(Vector3(0.24, 0.2, 0.24), Vector3(0, 0.8, -0.08), TUNIC, head)
	box(Vector3(0.18, 0.2, 0.18), Vector3(0, 0.96, -0.08), FLAME, head, Vector3(0, 45, 0))
	box(Vector3(0.1, 0.16, 0.1), Vector3(0.02, 1.1, -0.06), FLAME_TIP, head, Vector3(0, 0, 15))
	# Shoulder guard on the off arm.
	box(Vector3(0.26, 0.12, 0.28), Vector3(0, 0.04, 0), LEATHER, arm_l)
	# Twin blades held forward.
	for hand: Node3D in [hand_l, hand_r]:
		box(Vector3(0.26, 0.06, 0.08), Vector3(0, 0, 0.12), LEATHER, hand)
		box(Vector3(0.08, 0.04, 0.66), Vector3(0, 0, 0.48), STEEL, hand)
		box(Vector3(0.09, 0.05, 0.12), Vector3(0, 0, 0.84), FLAME, hand)
