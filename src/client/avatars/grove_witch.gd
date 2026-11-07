# Grove Witch (Controller): swamp-green rags, wide crooked hat, bubbling cauldron staff.
extends VoxelTroop

const RAGS := Color("#4f6b3a")
const RAGS_DARK := Color("#33472a")
const HAT := Color("#2b2a24")
const BREW := Color("#9be84a")
const WOOD := Color("#4a3522")
const SKIN_GREEN := Color("#b7c98f")


func _build() -> void:
	humanoid(SKIN_GREEN, RAGS, RAGS_DARK, HAT)
	# Tattered skirt with ragged strips.
	box(Vector3(0.66, 0.46, 0.42), Vector3(0, -0.2, 0), RAGS, body)
	for i in 4:
		box(Vector3(0.12, 0.14, 0.43), Vector3(-0.24 + i * 0.16, -0.48 - (i % 2) * 0.05, 0), RAGS_DARK, body)
	box(Vector3(0.64, 0.08, 0.4), Vector3(0, 0.08, 0), BREW, body)
	# Long nose and stringy hair.
	box(Vector3(0.1, 0.1, 0.16), Vector3(0, 0.22, 0.38), SKIN_GREEN, head)
	box(Vector3(0.74, 0.5, 0.1), Vector3(0, 0.28, -0.33), HAT, head)
	# Wide-brimmed crooked hat: brim, band, three stacked cones bent backward.
	box(Vector3(1.1, 0.06, 1.0), Vector3(0, 0.64, 0), HAT, head)
	box(Vector3(0.62, 0.1, 0.58), Vector3(0, 0.72, 0), BREW, head)
	box(Vector3(0.56, 0.22, 0.52), Vector3(0, 0.86, -0.02), HAT, head)
	box(Vector3(0.38, 0.22, 0.36), Vector3(0, 1.04, -0.1), HAT, head, Vector3(-12, 0, 0))
	box(Vector3(0.2, 0.22, 0.2), Vector3(0, 1.2, -0.24), HAT, head, Vector3(-30, 0, 0))
	# Staff with a little cauldron and bubbles.
	box(Vector3(0.08, 1.7, 0.08), Vector3(0, 0.35, 0.06), WOOD, hand_r)
	box(Vector3(0.3, 0.22, 0.3), Vector3(0, 1.26, 0.06), HAT, hand_r)
	box(Vector3(0.24, 0.04, 0.24), Vector3(0, 1.38, 0.06), BREW, hand_r)
	box(Vector3(0.08, 0.08, 0.08), Vector3(0.05, 1.46, 0.1), BREW, hand_r)
	box(Vector3(0.06, 0.06, 0.06), Vector3(-0.06, 1.54, 0.02), BREW, hand_r)
