# Ash Ranger (Aggro): hooded archer, charcoal cloak, longbow, quiver of ember arrows.
extends VoxelTroop

const CLOAK := Color("#3a3a40")
const CLOAK_DARK := Color("#26262b")
const LEATHER := Color("#8a5a32")
const EMBER := Color("#ff7a2e")
const WOOD := Color("#5e3d22")


func _build() -> void:
	humanoid(SKIN, CLOAK, CLOAK_DARK, LEATHER)
	# Belt, chest strap, short cape.
	box(Vector3(0.62, 0.08, 0.38), Vector3(0, 0.06, 0), LEATHER, body)
	box(Vector3(0.08, 0.66, 0.02), Vector3(0, 0.3, 0.19), LEATHER, body, Vector3(0, 0, 35))
	box(Vector3(0.6, 0.5, 0.06), Vector3(0, 0.26, -0.21), CLOAK_DARK, body)
	# Hood: cap, sides, back, peak; ember scarf over the mouth.
	box(Vector3(0.78, 0.18, 0.7), Vector3(0, 0.66, -0.02), CLOAK, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.06, 0.5, 0.6), Vector3(side * 0.38, 0.36, -0.04), CLOAK, head)
	box(Vector3(0.78, 0.56, 0.08), Vector3(0, 0.36, -0.34), CLOAK, head)
	box(Vector3(0.2, 0.12, 0.2), Vector3(0, 0.78, -0.3), CLOAK, head)
	box(Vector3(0.72, 0.16, 0.06), Vector3(0, 0.1, 0.33), EMBER, head)
	# Quiver on the back with glowing arrow tips.
	box(Vector3(0.18, 0.5, 0.18), Vector3(0.14, 0.4, -0.3), LEATHER, body, Vector3(0, 0, -15))
	for i in 3:
		box(Vector3(0.05, 0.08, 0.05), Vector3(0.1 + i * 0.05, 0.72, -0.3), EMBER, body)
	# Longbow in the left hand: grip, two limbs, string.
	box(Vector3(0.08, 0.2, 0.08), Vector3(0, 0, 0.06), WOOD, hand_l)
	box(Vector3(0.07, 0.6, 0.07), Vector3(0, 0.36, 0.14), WOOD, hand_l, Vector3(-15, 0, 0))
	box(Vector3(0.07, 0.6, 0.07), Vector3(0, -0.36, 0.14), WOOD, hand_l, Vector3(15, 0, 0))
	box(Vector3(0.02, 1.3, 0.02), Vector3(0, 0, 0.02), CLOAK_DARK, hand_l)
	# Arrow nocked in the right hand.
	box(Vector3(0.04, 0.04, 0.6), Vector3(0, 0, 0.3), WOOD, hand_r)
	box(Vector3(0.08, 0.08, 0.1), Vector3(0, 0, 0.62), EMBER, hand_r)
