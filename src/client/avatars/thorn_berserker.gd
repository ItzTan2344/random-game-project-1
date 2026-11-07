# Thorn Berserker (Bruiser): bare-armed brute, bark armour with thorns, wild red hair, spiked club.
extends VoxelTroop

const BARK := Color("#6a4429")
const BARK_DARK := Color("#43291a")
const THORN := Color("#e8dcb0")
const HAIR := Color("#c2352b")
const PAINT := Color("#a82020")


func _build() -> void:
	humanoid(SKIN, BARK, BARK_DARK, BARK_DARK, 1.15)
	# Bare upper arms with war paint.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.21, 0.24, 0.23), Vector3(0, -0.24, 0), SKIN, arm)
		box(Vector3(0.22, 0.05, 0.24), Vector3(0, -0.2, 0), PAINT, arm)
	# Thorns on the chest and shoulders.
	for x: float in [-0.2, 0.0, 0.2]:
		box(Vector3(0.06, 0.06, 0.14), Vector3(x, 0.44, 0.24), THORN, body, Vector3(45, 0, 0))
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.06, 0.18, 0.06), Vector3(side * 0.42, 0.66, 0), THORN, body, Vector3(0, 0, side * -30))
	box(Vector3(0.72, 0.08, 0.42), Vector3(0, 0.06, 0), BARK_DARK, body)
	# Wild hair, face paint stripe, angry brow.
	box(Vector3(0.78, 0.22, 0.7), Vector3(0, 0.68, -0.02), HAIR, head)
	box(Vector3(0.6, 0.3, 0.12), Vector3(0, 0.5, -0.34), HAIR, head)
	for i in 3:
		box(Vector3(0.12, 0.2, 0.12), Vector3(-0.22 + i * 0.22, 0.86, -0.06), HAIR, head, Vector3(-15, 0, (i - 1) * 20.0))
	box(Vector3(0.7, 0.05, 0.02), Vector3(0, 0.22, 0.315), PAINT, head)
	box(Vector3(0.5, 0.05, 0.03), Vector3(0, 0.42, 0.32), BARK_DARK, head)
	# Two-handed spiked club.
	box(Vector3(0.1, 0.9, 0.1), Vector3(0, 0.2, 0.08), BARK_DARK, hand_r)
	box(Vector3(0.24, 0.4, 0.24), Vector3(0, 0.78, 0.08), BARK, hand_r)
	for i in 4:
		var a: float = TAU * float(i) / 4.0
		box(Vector3(0.06, 0.06, 0.16), Vector3(cos(a) * 0.14, 0.8, 0.08 + sin(a) * 0.14), THORN, hand_r, Vector3(0, rad_to_deg(-a) + 90.0, 0))
