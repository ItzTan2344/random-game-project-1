class_name ArenaEnvironment
extends Node3D
## Dusk colosseum around the battle slots: sky, fog, warm key + cool rim light, a tiled stone platform with team pads,
## brazier pillars, a banner wall and drifting embers. Purely cosmetic; built in code like the troops.
## Platform top is y=0; slots sit at x=±1.5, z=±1.3 (BattleStage).

const STONE: Array[Color] = [Color("#3e3745"), Color("#36303d"), Color("#463e4c"), Color("#312b37")]
const GROUT := Color("#2a2530")
const RIM := Color("#3b3542")
const GROUND := Color("#1f2a2b")
const GROUND_ALT := Color("#26332f")
const ROCK := Color("#3d4146")
const WOOD := Color("#4a3426")
const BRASS := Color("#c9a24a")
const FLAME := Color("#ffb347")
const FLAME_CORE := Color("#fff1c2")
const EYE := Color("#1b1b24")

const TILE := 0.75
const COLS := 10
const ROWS := 7

var _near_color: Color
var _far_color: Color
var _flames: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _t: float = 0.0
## Crowd: one MultiMesh for bodies, one for heads; per-person base position + phase, bobbed in _process.
var _crowd_bodies: MultiMesh
var _crowd_heads: MultiMesh
var _crowd_eyes: MultiMesh
var _crowd_yaw: Array[float] = []
var _crowd_base: Array[Vector3] = []
var _crowd_phase: Array[float] = []
var _cheer: float = 0.0


func _init(near_color: Color, far_color: Color) -> void:
	_near_color = near_color
	_far_color = far_color


func _ready() -> void:
	_build_environment()
	_build_platform()
	_build_surroundings()
	_build_stands()
	_build_props()
	_build_grass()
	_build_embers()


func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		var f: Node3D = _flames[i]
		var k: float = float(i) * 1.7
		f.scale = Vector3(1.0 + 0.12 * sin(_t * 9.0 + k), 1.0 + 0.22 * sin(_t * 13.0 + k * 2.0), 1.0 + 0.12 * cos(_t * 8.0 + k))
		f.rotation.y = _t * 1.5 + k
	for i in _lights.size():
		_lights[i].light_energy = 1.3 + 0.35 * sin(_t * 11.0 + float(i) * 2.3) + 0.15 * sin(_t * 23.0 + float(i))
	_cheer = maxf(_cheer - delta, 0.0)
	var amp: float = 0.04 + 0.22 * minf(_cheer, 1.0)
	var speed: float = 3.0 + 9.0 * minf(_cheer, 1.0)
	for i in _crowd_base.size():
		var hop: float = absf(sin(_t * speed + _crowd_phase[i])) * amp
		var b: Vector3 = _crowd_base[i] + Vector3(0, hop, 0)
		var yaw: float = _crowd_yaw[i]
		_crowd_bodies.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), b))
		_set_head(i, b, yaw + sin(_t * 0.7 + _crowd_phase[i]) * 0.4)


## Crowd jumps for a moment (crits, knockouts).
func cheer(seconds: float = 1.4) -> void:
	_cheer = maxf(_cheer, seconds)


func _build_environment() -> void:
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#141433")
	sky_mat.sky_horizon_color = Color("#a8576a")
	sky_mat.ground_horizon_color = Color("#3a2a3e")
	sky_mat.ground_bottom_color = Color("#0e0f1a")
	sky_mat.sun_angle_max = 30.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a86b8")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#4b3352")
	env.fog_depth_begin = 18.0
	env.fog_depth_end = 42.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Warm low sun from the front-left, cool moonlit rim from behind.
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_color = Color("#ffd8b0")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 200, 0)
	rim.light_color = Color("#7f9dff")
	rim.light_energy = 0.55
	add_child(rim)


func _build_platform() -> void:
	var w: float = TILE * COLS
	var d: float = TILE * ROWS
	# Grout bed, rim and two steps down to the ground.
	_box(Vector3(w + 0.1, 0.36, d + 0.1), Vector3(0, -0.2, 0), GROUT)
	_box(Vector3(w + 0.5, 0.3, d + 0.5), Vector3(0, -0.27, 0), RIM)
	_box(Vector3(w + 1.3, 0.25, d + 1.3), Vector3(0, -0.5, 0), STONE[3].darkened(0.35))
	_box(Vector3(w + 2.1, 0.2, d + 2.1), Vector3(0, -0.7, 0), STONE[3].darkened(0.5))

	# Tiles: one MultiMesh draw, colour per instance; team halves tinted, slight height jitter.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(TILE - 0.05, 0.2, TILE - 0.05)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = COLS * ROWS
	for r in ROWS:
		for c in COLS:
			var i: int = r * COLS + c
			var x: float = (float(c) - (COLS - 1) * 0.5) * TILE
			var z: float = (float(r) - (ROWS - 1) * 0.5) * TILE
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, -0.1 + rng.randf_range(-0.012, 0.012), z)))
			var col: Color = STONE[rng.randi() % STONE.size()]
			if absf(x) < 2.4 and absf(z) > 0.3 and absf(z) < 2.3:
				col = col.lerp((_near_color if z > 0.0 else _far_color).darkened(0.45), 0.4)
			mm.set_instance_color(i, col)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

	# Brass center line and glowing team-pad frames.
	_box(Vector3(w, 0.03, 0.06), Vector3(0, 0.005, 0), BRASS.darkened(0.2), 0.25)
	for side in 2:
		var z: float = 1.3 if side == 0 else -1.3
		var col: Color = _near_color if side == 0 else _far_color
		_frame(Vector3(0, 0.012, z), Vector2(4.6, 1.85), 0.05, col.darkened(0.2), 0.9)

	# Small corner studs on the rim.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(Vector3(0.4, 0.14, 0.4), Vector3(sx * (w * 0.5 + 0.05), 0.0, sz * (d * 0.5 + 0.05)), BRASS.darkened(0.35))


func _build_surroundings() -> void:
	_box(Vector3(80, 0.2, 80), Vector3(0, -0.9, 0), GROUND)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	# Scattered turf patches and rocks, kept off the platform and out of the near-camera strip.
	for i in 34:
		var p: Vector3 = Vector3(rng.randf_range(-13, 13), -0.8, rng.randf_range(-11, 6))
		if absf(p.x) < 5.4 and absf(p.z) < 4.2:
			continue
		if rng.randf() < 0.6:
			_box(Vector3(rng.randf_range(0.8, 2.2), 0.06, rng.randf_range(0.8, 2.2)), p + Vector3(0, 0.03, 0), GROUND_ALT)
		else:
			var s: float = rng.randf_range(0.25, 0.6)
			_box(Vector3(s, s * 0.7, s * 0.9), p + Vector3(0, s * 0.35, 0), ROCK, 0.0, Vector3(0, rng.randf_range(0, 90), 0))

	# Brazier pillars behind the far side (none in front: they would sit under the camera and the cards).
	for sx: float in [-1.0, 1.0]:
		_brazier(Vector3(sx * 4.7, -0.8, -3.6), 2.4)

	# Back wall with crenellations and banners in the far team's colour.
	var wall_z: float = -5.6
	_box(Vector3(14, 1.6, 0.8), Vector3(0, 0.0, wall_z), RIM)
	for i in 8:
		_box(Vector3(0.9, 0.5, 0.8), Vector3(-6.3 + i * 1.8, 1.05, wall_z), RIM.lightened(0.05))
	for bx: float in [-3.0, 0.0, 3.0]:
		var banner_col: Color = BRASS if bx == 0.0 else _far_color.darkened(0.15)
		_box(Vector3(1.2, 0.08, 0.1), Vector3(bx, 0.95, wall_z + 0.45), WOOD)
		_box(Vector3(0.95, 1.4, 0.06), Vector3(bx, 0.2, wall_z + 0.45), banner_col)
		_box(Vector3(0.95, 0.12, 0.07), Vector3(bx, -0.45, wall_z + 0.46), banner_col.darkened(0.3))
		_box(Vector3(0.3, 0.3, 0.08), Vector3(bx, 0.35, wall_z + 0.5), FLAME_CORE if bx == 0.0 else BRASS, 0.4)


func _brazier(base: Vector3, height: float) -> void:
	_box(Vector3(0.8, 0.25, 0.8), base + Vector3(0, 0.12, 0), RIM.darkened(0.2))
	_box(Vector3(0.55, height, 0.55), base + Vector3(0, 0.25 + height * 0.5, 0), STONE[1])
	var top: Vector3 = base + Vector3(0, 0.25 + height, 0)
	_box(Vector3(0.85, 0.12, 0.85), top + Vector3(0, 0.06, 0), BRASS.darkened(0.25))
	_box(Vector3(0.7, 0.22, 0.7), top + Vector3(0, 0.23, 0), BRASS.darkened(0.45))
	var flame: Node3D = Node3D.new()
	flame.position = top + Vector3(0, 0.38, 0)
	add_child(flame)
	_box(Vector3(0.42, 0.42, 0.42), Vector3(0, 0.14, 0), FLAME, 1.6, Vector3(0, 45, 0), flame)
	_box(Vector3(0.24, 0.38, 0.24), Vector3(0.03, 0.34, 0.02), FLAME_CORE, 2.2, Vector3(0, 20, 0), flame)
	_flames.append(flame)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = top + Vector3(0, 0.8, 0)
	light.light_color = Color("#ff9a4a")
	light.omni_range = 5.5
	light.omni_attenuation = 1.4
	add_child(light)
	_lights.append(light)


## Stepped stone stands down both long sides, filled with a bobbing voxel crowd.
func _build_stands() -> void:
	const TIERS := 3
	const Z_FROM := -3.6
	const Z_TO := 2.4
	var shirts: Array[Color] = [Color("#c0392b"), Color("#2e86de"), Color("#27ae60"), Color("#f39c12"), Color("#8e44ad"), Color("#d35400"), Color("#16a085"), Color("#7f8c8d"), Color("#e8d8b0")]
	var skins: Array[Color] = [Color("#f1c27d"), Color("#e0ac69"), Color("#c68642"), Color("#8d5524"), Color("#ffdbac")]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23
	var seats: Array[Vector3] = []
	var shirt_cols: Array[Color] = []
	var skin_cols: Array[Color] = []
	var mid_z: float = (Z_FROM + Z_TO) * 0.5
	var length: float = Z_TO - Z_FROM
	for sx: float in [-1.0, 1.0]:
		for t in TIERS:
			var x: float = sx * (6.3 + 0.75 * float(t))
			var top: float = -0.8 + 0.4 * float(t + 1)
			_box(Vector3(0.75, top + 0.8, length), Vector3(x, (top - 0.8) * 0.5, mid_z), RIM if t % 2 == 0 else RIM.lightened(0.06))
			var z: float = Z_FROM + 0.3
			while z < Z_TO - 0.2:
				if rng.randf() > 0.18:
					seats.append(Vector3(x + rng.randf_range(-0.08, 0.08), top + 0.22, z + rng.randf_range(-0.06, 0.06)))
					shirt_cols.append(shirts[rng.randi() % shirts.size()])
					skin_cols.append(skins[rng.randi() % skins.size()])
				z += 0.52
		# Back rail with brass trim.
		var rail_x: float = sx * (6.3 + 0.75 * TIERS - 0.25)
		var rail_y: float = -0.8 + 0.4 * TIERS
		_box(Vector3(0.2, 0.5, length), Vector3(rail_x, rail_y + 0.25, mid_z), RIM.darkened(0.2))
		_box(Vector3(0.24, 0.06, length), Vector3(rail_x, rail_y + 0.52, mid_z), BRASS.darkened(0.3))
	_crowd_bodies = _color_multimesh(Vector3(0.34, 0.44, 0.3), seats.size())
	_crowd_heads = _color_multimesh(Vector3(0.28, 0.28, 0.28), seats.size())
	_crowd_eyes = _color_multimesh(Vector3(0.05, 0.07, 0.02), seats.size() * 2)
	for i in seats.size():
		_crowd_base.append(seats[i])
		_crowd_phase.append(rng.randf_range(0.0, TAU))
		# Models face +Z; turn each spectator toward the arena centre line.
		_crowd_yaw.append(PI * 0.5 if seats[i].x < 0.0 else -PI * 0.5)
		_crowd_bodies.set_instance_color(i, shirt_cols[i])
		_crowd_heads.set_instance_color(i, skin_cols[i])
		_crowd_eyes.set_instance_color(i * 2, EYE)
		_crowd_eyes.set_instance_color(i * 2 + 1, EYE)
		_crowd_bodies.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _crowd_yaw[i]), seats[i]))
		_set_head(i, seats[i], _crowd_yaw[i])


func _set_head(i: int, body_pos: Vector3, yaw: float) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw)
	var head: Vector3 = body_pos + Vector3(0, 0.36, 0)
	_crowd_heads.set_instance_transform(i, Transform3D(basis, head))
	_crowd_eyes.set_instance_transform(i * 2, Transform3D(basis, head + basis * Vector3(0.07, 0.02, 0.145)))
	_crowd_eyes.set_instance_transform(i * 2 + 1, Transform3D(basis, head + basis * Vector3(-0.07, 0.02, 0.145)))


## One-draw-call batch of coloured boxes; caller fills transforms and colours.
func _color_multimesh(box_size: Vector3, count: int) -> MultiMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mm


## Clutter in the gap between platform and stands: lantern posts, crates, barrels, a weapon rack.
func _build_props() -> void:
	const GY := -0.8
	for sx: float in [-1.0, 1.0]:
		_lantern(Vector3(sx * 5.45, GY, 0.9))
	_crate(Vector3(-5.5, GY, -1.6), 0.6, 10.0)
	_crate(Vector3(-5.45, GY + 0.6, -1.55), 0.45, -14.0)
	_crate(Vector3(-5.6, GY, -0.85), 0.5, 30.0)
	_barrel(Vector3(-5.35, GY, 2.3))
	_barrel(Vector3(-5.75, GY, 2.75))
	_barrel(Vector3(5.5, GY, 2.5))
	_crate(Vector3(5.6, GY, -2.6), 0.55, -8.0)
	var rack: Node3D = Node3D.new()
	rack.position = Vector3(5.55, GY, -0.9)
	add_child(rack)
	for rz: float in [-0.55, 0.55]:
		_box(Vector3(0.1, 1.0, 0.1), Vector3(0, 0.5, rz), WOOD, 0.0, Vector3.ZERO, rack)
	_box(Vector3(0.08, 0.08, 1.3), Vector3(0, 0.85, 0), WOOD.darkened(0.2), 0.0, Vector3.ZERO, rack)
	for k in 3:
		var z: float = -0.35 + 0.35 * float(k)
		_box(Vector3(0.05, 1.3, 0.05), Vector3(-0.12, 0.65, z), WOOD.lightened(0.15), 0.0, Vector3(0, 0, -10), rack)
		_box(Vector3(0.08, 0.2, 0.03), Vector3(-0.24, 1.35, z), Color("#c8ced8"), 0.0, Vector3(0, 0, -10), rack)
	_box(Vector3(0.5, 0.5, 0.08), Vector3(-0.1, 0.45, 0.85), Color("#8a5a3a"), 0.0, Vector3(0, 0, -12), rack)
	_box(Vector3(0.18, 0.18, 0.1), Vector3(-0.14, 0.45, 0.85), BRASS, 0.0, Vector3(0, 0, -12), rack)


func _lantern(base: Vector3) -> void:
	_box(Vector3(0.14, 1.9, 0.14), base + Vector3(0, 0.95, 0), WOOD)
	_box(Vector3(0.5, 0.08, 0.08), base + Vector3(0, 1.85, 0), WOOD)
	var hang: Vector3 = base + Vector3(0, 1.55, 0)
	_box(Vector3(0.28, 0.06, 0.28), hang + Vector3(0, 0.2, 0), BRASS.darkened(0.4))
	_box(Vector3(0.22, 0.3, 0.22), hang, Color("#ffc46b"), 2.4)
	_box(Vector3(0.28, 0.05, 0.28), hang - Vector3(0, 0.17, 0), BRASS.darkened(0.4))
	var light: OmniLight3D = OmniLight3D.new()
	light.position = hang
	light.light_color = Color("#ffb060")
	light.omni_range = 3.2
	light.omni_attenuation = 1.6
	add_child(light)
	_lights.append(light)


func _crate(base: Vector3, size: float, yaw: float) -> void:
	var n: Node3D = Node3D.new()
	n.position = base + Vector3(0, size * 0.5, 0)
	n.rotation_degrees.y = yaw
	add_child(n)
	_box(Vector3(size, size, size), Vector3.ZERO, Color("#8b6a45"), 0.0, Vector3.ZERO, n)
	_box(Vector3(size + 0.02, size * 0.16, size + 0.02), Vector3(0, size * 0.35, 0), Color("#5e452c"), 0.0, Vector3.ZERO, n)
	_box(Vector3(size + 0.02, size * 0.16, size + 0.02), Vector3(0, -size * 0.35, 0), Color("#5e452c"), 0.0, Vector3.ZERO, n)


func _barrel(base: Vector3) -> void:
	_box(Vector3(0.46, 0.62, 0.46), base + Vector3(0, 0.31, 0), Color("#7a5235"))
	_box(Vector3(0.5, 0.06, 0.5), base + Vector3(0, 0.12, 0), Color("#3a3a40"))
	_box(Vector3(0.5, 0.06, 0.5), base + Vector3(0, 0.5, 0), Color("#3a3a40"))
	_box(Vector3(0.38, 0.02, 0.38), base + Vector3(0, 0.63, 0), Color("#5e3f28"))


## Grass tufts on the turf: one MultiMesh of thin blades, kept off the platform and stands.
func _build_grass() -> void:
	var greens: Array[Color] = [Color("#2f6b2a"), Color("#3b7d2c"), Color("#4a8f33"), Color("#285a26")]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31
	var blades: Array[Transform3D] = []
	var cols: Array[Color] = []
	for i in 160:
		var c: Vector3 = Vector3(rng.randf_range(-12, 12), -0.8, rng.randf_range(-10, 6))
		if absf(c.x) < 5.3 and absf(c.z) < 4.3:
			continue
		if absf(c.x) > 6.0 and absf(c.x) < 8.7 and c.z > -3.8 and c.z < 2.6:
			continue
		var col: Color = greens[rng.randi() % greens.size()]
		for k in 3:
			var h: float = rng.randf_range(0.6, 1.2)
			var basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))).scaled(Vector3(1, h, 1))
			blades.append(Transform3D(basis, c + Vector3(rng.randf_range(-0.12, 0.12), 0.12 * h, rng.randf_range(-0.12, 0.12))))
			cols.append(col.lightened(rng.randf_range(0.0, 0.15)))
	var mm: MultiMesh = _color_multimesh(Vector3(0.04, 0.28, 0.04), blades.size())
	for i in blades.size():
		mm.set_instance_transform(i, blades[i])
		mm.set_instance_color(i, cols[i])


func _build_embers() -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = 45
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-10, -1, -8), Vector3(20, 8, 16))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.5, 0.2, 5.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0.05, 0.04, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	p.position = Vector3(0, 0.2, 0)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.035)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.6, 0.25)
	mesh.material = mat
	p.draw_pass_1 = mesh
	add_child(p)


## Thin glowing rectangle outline lying flat at center (size x by z).
func _frame(center: Vector3, size: Vector2, thick: float, color: Color, energy: float) -> void:
	_box(Vector3(size.x, 0.02, thick), center + Vector3(0, 0, size.y * 0.5), color, energy)
	_box(Vector3(size.x, 0.02, thick), center - Vector3(0, 0, size.y * 0.5), color, energy)
	_box(Vector3(thick, 0.02, size.y), center + Vector3(size.x * 0.5, 0, 0), color, energy)
	_box(Vector3(thick, 0.02, size.y), center - Vector3(size.x * 0.5, 0, 0), color, energy)


## Static box. energy > 0 makes it emissive (blooms with glow).
func _box(box_size: Vector3, pos: Vector3, color: Color, energy: float = 0.0, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	m.mesh = mesh
	m.material_override = _glow_material(color, energy) if energy > 0.0 else VoxelTroop.material(color)
	m.position = pos
	m.rotation_degrees = rot_deg
	parent.add_child(m)
	return m


static var _glow_mats: Dictionary = {}


static func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var key: String = "%s/%f" % [color.to_html(), energy]
	if not _glow_mats.has(key):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		_glow_mats[key] = mat
	return _glow_mats[key]
