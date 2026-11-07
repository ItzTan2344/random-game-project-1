# Void Arcanist (Duelist): deep purple robe, hollow dark face, orbiting void shards.
extends VoxelTroop

const ROBE := Color("#3c2366")
const ROBE_DARK := Color("#24143f")
const VOID := Color("#0e0a18")
const GLOW := Color("#b57bff")
const TRIM := Color("#d9c4ff")

var _orbit: Node3D


func _build() -> void:
	humanoid(Color("#c9b8e8"), ROBE, ROBE_DARK, ROBE_DARK)
	# Long robe skirt with glowing hem and trim.
	box(Vector3(0.66, 0.54, 0.42), Vector3(0, -0.24, 0), ROBE, body)
	box(Vector3(0.68, 0.06, 0.44), Vector3(0, -0.48, 0), GLOW, body)
	box(Vector3(0.1, 0.6, 0.02), Vector3(0, 0.3, 0.19), TRIM, body)
	# Deep hood: the face is a void with two glowing eyes.
	box(Vector3(0.8, 0.7, 0.68), Vector3(0, 0.33, -0.04), ROBE_DARK, head)
	box(Vector3(0.56, 0.46, 0.04), Vector3(0, 0.28, 0.31), VOID, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.1, 0.06, 0.02), Vector3(side * 0.13, 0.32, 0.335), GLOW, head)
	box(Vector3(0.3, 0.2, 0.3), Vector3(0, 0.72, -0.2), ROBE_DARK, head, Vector3(-20, 0, 0))
	# Wide sleeves.
	for arm: Node3D in [arm_l, arm_r]:
		box(Vector3(0.28, 0.16, 0.3), Vector3(0, -0.34, 0), ROBE_DARK, arm)
	# Orb in the left hand.
	box(Vector3(0.2, 0.2, 0.2), Vector3(0, 0.08, 0.1), GLOW, hand_l, Vector3(45, 45, 0))
	# Orbiting shards behind the shoulders (animated).
	_orbit = _pivot(body, Vector3(0, 0.9, -0.1))
	for i in 4:
		var a: float = TAU * float(i) / 4.0
		box(Vector3(0.12, 0.12, 0.12), Vector3(cos(a) * 0.6, sin(a * 2.0) * 0.08, sin(a) * 0.6), GLOW if i % 2 == 0 else VOID, _orbit, Vector3(45, 45, 0))


func _process(delta: float) -> void:
	super(delta)
	if _orbit != null and not dead:
		_orbit.rotation.y += delta * 1.2
