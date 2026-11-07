class_name HitFX
extends RefCounted
## Juicy voxel combat VFX: impact bursts, heals, buffs/debuffs, cast rings, KO puffs, and projectiles.
## All spawn functions create self-cleaning Node3D trees under parent.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


# =====================================================================
# Public API
# =====================================================================

## Burst of small cubes flying out with gravity and spinning, plus a short bright expanding flash.
## When crit is true: larger burst, more cubes, and a white-gold shockwave square on the ground.
static func impact(parent: Node3D, pos: Vector3, color: Color, crit: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var root: Node3D = Node3D.new()
	root.position = pos
	parent.add_child(root)

	var duration: float = 0.55 if crit else 0.42
	var cube_count: int = 18 if crit else 10
	var base_size: float = 0.22 if crit else 0.16

	# Flash: bright expanding emissive cube shell
	var flash_color: Color = Color.WHITE.lerp(color, 0.25)
	var flash_mat: StandardMaterial3D = get_emissive_material(flash_color, 4.0)
	var flash_size: Vector3 = Vector3.ONE * (0.8 if crit else 0.55)
	var flash: MeshInstance3D = _spawn_cube(root, flash_size, Vector3.ZERO, flash_mat)
	flash.scale = Vector3.ONE * 0.2
	flash.rotation_degrees = Vector3(randf_range(0.0, 360.0), randf_range(0.0, 360.0), randf_range(0.0, 360.0))

	var tw_flash: Tween = root.create_tween().set_parallel(true)
	tw_flash.tween_property(flash, "scale", Vector3.ONE * (1.8 if crit else 1.3), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw_flash.tween_property(flash, "transparency", 1.0, 0.15).set_ease(Tween.EASE_IN)
	tw_flash.tween_property(flash, "rotation_degrees:y", flash.rotation_degrees.y + 90.0, 0.15)

	# Ground shockwave ring on crit
	if crit:
		var gold_mat: StandardMaterial3D = get_emissive_material(Color("#fff3aa"), 3.6)
		var shockwave: Node3D = _spawn_square_frame(root, 0.9, 0.08, 0.02, gold_mat)
		shockwave.position = Vector3(0.0, -pos.y + 0.02, 0.0)
		shockwave.scale = Vector3.ONE * 0.25
		var tw_shock: Tween = root.create_tween().set_parallel(true)
		tw_shock.tween_property(shockwave, "scale", Vector3.ONE * 2.3, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_shock.tween_property(shockwave, "rotation_degrees:y", 45.0, 0.45).set_ease(Tween.EASE_OUT)
		for child: Node in shockwave.get_children():
			tw_shock.tween_property(child, "transparency", 1.0, 0.42).set_delay(0.03).set_ease(Tween.EASE_IN)

	# Flying debris cubes
	var mat_main: StandardMaterial3D = get_emissive_material(color, 3.2)
	var mat_bright: StandardMaterial3D = get_emissive_material(color.lightened(0.4), 3.8)
	var mat_gold: StandardMaterial3D = get_emissive_material(Color("#fff3aa"), 4.0)

	for i: int in cube_count:
		var mat: StandardMaterial3D = mat_main
		if crit and (i % 3 == 0):
			mat = mat_gold
		elif i % 2 == 0:
			mat = mat_bright

		var size_scale: float = randf_range(0.8, 1.3)
		var cube_size: Vector3 = Vector3.ONE * (base_size * size_scale)
		var cube: MeshInstance3D = _spawn_cube(root, cube_size, Vector3.ZERO, mat)
		cube.scale = Vector3.ZERO

		var angle: float = (float(i) / float(cube_count)) * TAU + randf_range(-0.25, 0.25)
		var dist: float = randf_range(1.2, 2.2) if crit else randf_range(0.8, 1.5)
		var target_x: float = cos(angle) * dist
		var target_z: float = sin(angle) * dist
		var peak_y: float = randf_range(0.6, 1.3) if crit else randf_range(0.4, 0.8)
		var fall_y: float = -randf_range(0.2, 0.7)

		var up_dur: float = duration * 0.38
		var down_dur: float = duration - up_dur

		var tw_y: Tween = cube.create_tween()
		tw_y.tween_property(cube, "position:y", peak_y, up_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_y.tween_property(cube, "position:y", fall_y, down_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

		var tw_h: Tween = cube.create_tween().set_parallel(true)
		tw_h.tween_property(cube, "position:x", target_x, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_h.tween_property(cube, "position:z", target_z, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_h.tween_property(cube, "rotation_degrees", Vector3(randf_range(-360.0, 360.0), randf_range(-360.0, 360.0), randf_range(-360.0, 360.0)), duration)

		# Scale pop and shrink
		var tw_s: Tween = cube.create_tween()
		tw_s.tween_property(cube, "scale", Vector3.ONE * 1.25, 0.06).set_ease(Tween.EASE_OUT)
		tw_s.tween_property(cube, "scale", Vector3.ZERO, duration - 0.06).set_ease(Tween.EASE_IN)

	var cleaner: Tween = root.create_tween()
	cleaner.tween_interval(duration + 0.05)
	cleaner.finished.connect(root.queue_free)


## Green/mint cubes rising and fading, plus a soft expanding ring at the feet.
static func heal(parent: Node3D, pos: Vector3) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var root: Node3D = Node3D.new()
	root.position = pos
	parent.add_child(root)

	var duration: float = 0.7
	var mint: Color = Color("#55efc4")
	var mint_bright: Color = Color("#a8ffeb")
	var mat_mint: StandardMaterial3D = get_emissive_material(mint, 3.0)
	var mat_bright: StandardMaterial3D = get_emissive_material(mint_bright, 3.6)

	# Soft ground ring at feet
	var ring: Node3D = _spawn_square_frame(root, 0.95, 0.06, 0.02, mat_mint)
	ring.position = Vector3(0.0, -pos.y + 0.02, 0.0)
	ring.scale = Vector3.ONE * 0.35

	var tw_ring: Tween = root.create_tween().set_parallel(true)
	tw_ring.tween_property(ring, "scale", Vector3.ONE * 1.35, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw_ring.tween_property(ring, "rotation_degrees:y", 45.0, 0.6).set_ease(Tween.EASE_OUT)
	for child: Node in ring.get_children():
		tw_ring.tween_property(child, "transparency", 1.0, 0.55).set_delay(0.05).set_ease(Tween.EASE_IN)

	# Rising mint cubes
	var count: int = 10
	for i: int in count:
		var mat: StandardMaterial3D = mat_bright if i % 2 == 0 else mat_mint
		var cube_size: Vector3 = Vector3.ONE * randf_range(0.18, 0.28)
		var start_offset: Vector3 = Vector3(randf_range(-0.4, 0.4), randf_range(-pos.y + 0.1, -pos.y + 0.5), randf_range(-0.4, 0.4))
		var cube: MeshInstance3D = _spawn_cube(root, cube_size, start_offset, mat)
		cube.scale = Vector3.ZERO

		var rise_y: float = start_offset.y + randf_range(1.2, 1.8)
		var drift_x: float = start_offset.x + randf_range(-0.25, 0.25)
		var drift_z: float = start_offset.z + randf_range(-0.25, 0.25)
		var cube_dur: float = randf_range(0.5, duration)

		var tw_pos: Tween = cube.create_tween().set_parallel(true)
		tw_pos.tween_property(cube, "position:y", rise_y, cube_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_pos.tween_property(cube, "position:x", drift_x, cube_dur).set_ease(Tween.EASE_OUT)
		tw_pos.tween_property(cube, "position:z", drift_z, cube_dur).set_ease(Tween.EASE_OUT)
		tw_pos.tween_property(cube, "rotation_degrees", Vector3(randf_range(-180.0, 180.0), randf_range(-180.0, 180.0), randf_range(-180.0, 180.0)), cube_dur)

		var tw_scale: Tween = cube.create_tween()
		tw_scale.tween_property(cube, "scale", Vector3.ONE * 1.15, 0.12).set_ease(Tween.EASE_OUT)
		tw_scale.tween_property(cube, "scale", Vector3.ZERO, cube_dur - 0.12).set_ease(Tween.EASE_IN)

	var cleaner: Tween = root.create_tween()
	cleaner.tween_interval(duration + 0.05)
	cleaner.finished.connect(root.queue_free)


## Rising spiral of small cubes in color (blue for buffs, orange-red for debuffs).
static func buff(parent: Node3D, pos: Vector3, color: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var root: Node3D = Node3D.new()
	root.position = pos
	parent.add_child(root)

	var duration: float = 0.65
	var count: int = 9
	var mat_main: StandardMaterial3D = get_emissive_material(color, 3.2)
	var mat_bright: StandardMaterial3D = get_emissive_material(color.lightened(0.35), 3.8)

	for i: int in count:
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(0.0, -pos.y, 0.0)
		root.add_child(pivot)

		var start_angle: float = float(i) * (TAU / float(count))
		pivot.rotation.y = start_angle

		var mat: StandardMaterial3D = mat_bright if i % 2 == 0 else mat_main
		var cube_size: Vector3 = Vector3.ONE * randf_range(0.16, 0.23)
		var start_y: float = float(i) * 0.12
		var cube: MeshInstance3D = _spawn_cube(pivot, cube_size, Vector3(0.55, start_y, 0.0), mat)
		cube.scale = Vector3.ZERO

		var tw_rot: Tween = pivot.create_tween()
		tw_rot.tween_property(pivot, "rotation:y", start_angle + TAU * 0.85, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		var tw_cube: Tween = cube.create_tween().set_parallel(true)
		tw_cube.tween_property(cube, "position:y", start_y + 1.5, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_cube.tween_property(cube, "rotation_degrees", Vector3(randf_range(-240.0, 240.0), randf_range(-240.0, 240.0), randf_range(-240.0, 240.0)), duration)

		var tw_s: Tween = cube.create_tween()
		tw_s.tween_property(cube, "scale", Vector3.ONE * 1.2, 0.12).set_ease(Tween.EASE_OUT)
		tw_s.tween_property(cube, "scale", Vector3.ZERO, duration - 0.12).set_ease(Tween.EASE_IN)

	var cleaner: Tween = root.create_tween()
	cleaner.tween_interval(duration + 0.05)
	cleaner.finished.connect(root.queue_free)


## Magic circle at feet: two overlapped rotated square frames that grow and fade over ~0.5 s.
static func cast(parent: Node3D, pos: Vector3, color: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var root: Node3D = Node3D.new()
	root.position = pos
	parent.add_child(root)

	var duration: float = 0.5
	var ground_y: float = -pos.y + 0.02
	var mat_main: StandardMaterial3D = get_emissive_material(color, 3.4)
	var mat_bright: StandardMaterial3D = get_emissive_material(color.lightened(0.3), 4.0)

	var frame1: Node3D = _spawn_square_frame(root, 1.25, 0.06, 0.02, mat_main)
	frame1.position = Vector3(0.0, ground_y, 0.0)
	frame1.scale = Vector3.ONE * 0.15

	var frame2: Node3D = _spawn_square_frame(root, 1.25, 0.06, 0.02, mat_bright)
	frame2.position = Vector3(0.0, ground_y + 0.002, 0.0)
	frame2.rotation.y = PI * 0.25
	frame2.scale = Vector3.ONE * 0.15

	var tw_f1: Tween = frame1.create_tween().set_parallel(true)
	tw_f1.tween_property(frame1, "scale", Vector3.ONE * 1.4, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_f1.tween_property(frame1, "rotation:y", PI * 0.5, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for child: Node in frame1.get_children():
		tw_f1.tween_property(child, "transparency", 1.0, 0.25).set_delay(0.25).set_ease(Tween.EASE_IN)

	var tw_f2: Tween = frame2.create_tween().set_parallel(true)
	tw_f2.tween_property(frame2, "scale", Vector3.ONE * 1.4, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_f2.tween_property(frame2, "rotation:y", PI * 0.25 - PI * 0.5, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for child: Node in frame2.get_children():
		tw_f2.tween_property(child, "transparency", 1.0, 0.25).set_delay(0.25).set_ease(Tween.EASE_IN)

	# 4 corner accent sparks
	for i: int in 4:
		var spark: MeshInstance3D = _spawn_cube(root, Vector3.ONE * 0.14, Vector3(0.0, ground_y + 0.01, 0.0), mat_bright)
		spark.scale = Vector3.ZERO
		var spark_ang: float = float(i) * (TAU * 0.25)
		var spark_tw: Tween = spark.create_tween().set_parallel(true)
		spark_tw.tween_property(spark, "position:x", cos(spark_ang) * 0.9, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		spark_tw.tween_property(spark, "position:z", sin(spark_ang) * 0.9, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		spark_tw.tween_property(spark, "rotation_degrees:y", 180.0, duration)
		var spark_scale_tw: Tween = spark.create_tween()
		spark_scale_tw.tween_property(spark, "scale", Vector3.ONE * 1.2, 0.12).set_ease(Tween.EASE_OUT)
		spark_scale_tw.tween_property(spark, "scale", Vector3.ZERO, duration - 0.12).set_ease(Tween.EASE_IN)

	var cleaner: Tween = root.create_tween()
	cleaner.tween_interval(duration + 0.05)
	cleaner.finished.connect(root.queue_free)


## Grey/white puff of larger cubes, plus a dark ground scorch square that fades over ~1 s.
static func ko(parent: Node3D, pos: Vector3) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var root: Node3D = Node3D.new()
	root.position = pos
	parent.add_child(root)

	var total_duration: float = 1.0

	# Dark ground scorch square
	var scorch_mat: StandardMaterial3D = get_flat_material(Color(0.1, 0.11, 0.14, 0.88))
	var scorch: MeshInstance3D = _spawn_cube(root, Vector3(1.4, 0.015, 1.4), Vector3(0.0, -pos.y + 0.01, 0.0), scorch_mat)
	scorch.scale = Vector3(0.3, 1.0, 0.3)
	var tw_scorch: Tween = scorch.create_tween()
	tw_scorch.tween_property(scorch, "scale", Vector3.ONE, 0.08).set_ease(Tween.EASE_OUT)
	tw_scorch.tween_interval(0.35)
	tw_scorch.tween_property(scorch, "transparency", 1.0, 0.55).set_ease(Tween.EASE_IN)

	# Puff of larger smoke cubes
	var count: int = 12
	var smoke_palette: Array[Color] = [
		Color("#f1f2f6"),
		Color("#ced6e0"),
		Color("#747d8c"),
		Color("#57606f")
	]

	for i: int in count:
		var smoke_color: Color = smoke_palette[i % smoke_palette.size()]
		var mat: StandardMaterial3D = get_emissive_material(smoke_color, 1.2)
		var cube_size: Vector3 = Vector3.ONE * randf_range(0.32, 0.46)
		var cube: MeshInstance3D = _spawn_cube(root, cube_size, Vector3(0.0, randf_range(0.1, 0.5), 0.0), mat)
		cube.scale = Vector3.ZERO

		var angle: float = (float(i) / float(count)) * TAU + randf_range(-0.3, 0.3)
		var dist: float = randf_range(0.6, 1.3)
		var target_x: float = cos(angle) * dist
		var target_z: float = sin(angle) * dist
		var peak_y: float = randf_range(0.8, 1.7)
		var fall_y: float = peak_y - randf_range(0.15, 0.45)
		var puff_dur: float = randf_range(0.65, 0.85)

		var up_dur: float = puff_dur * 0.45
		var down_dur: float = puff_dur - up_dur

		var tw_y: Tween = cube.create_tween()
		tw_y.tween_property(cube, "position:y", peak_y, up_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_y.tween_property(cube, "position:y", fall_y, down_dur).set_ease(Tween.EASE_IN_OUT)

		var tw_h: Tween = cube.create_tween().set_parallel(true)
		tw_h.tween_property(cube, "position:x", target_x, puff_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_h.tween_property(cube, "position:z", target_z, puff_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw_h.tween_property(cube, "rotation_degrees", Vector3(randf_range(-270.0, 270.0), randf_range(-270.0, 270.0), randf_range(-270.0, 270.0)), puff_dur)

		var tw_scale: Tween = cube.create_tween()
		tw_scale.tween_property(cube, "scale", Vector3.ONE * 1.2, 0.12).set_ease(Tween.EASE_OUT)
		tw_scale.tween_property(cube, "scale", Vector3.ZERO, puff_dur - 0.12).set_ease(Tween.EASE_IN)

	var cleaner: Tween = root.create_tween()
	cleaner.tween_interval(total_duration + 0.05)
	cleaner.finished.connect(root.queue_free)


## Emissive cube with a short trail that arcs from from to to, then frees itself on arrival.
static func projectile(parent: Node3D, from: Vector3, to: Vector3, color: Color, duration: float = 0.25) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var root: Node3D = Node3D.new()
	parent.add_child(root)

	var head_mat: StandardMaterial3D = get_emissive_material(color, 3.8)
	var head: MeshInstance3D = _spawn_cube(root, Vector3.ONE * 0.32, from, head_mat)

	var trail_cubes: Array[MeshInstance3D] = []
	var trail_sizes: Array[float] = [0.24, 0.17, 0.11]
	var trail_mats: Array[StandardMaterial3D] = [
		get_emissive_material(color.lightened(0.2), 3.0),
		get_emissive_material(color, 2.4),
		get_emissive_material(color.darkened(0.2), 1.8)
	]

	for i: int in trail_sizes.size():
		var t_cube: MeshInstance3D = _spawn_cube(root, Vector3.ONE * trail_sizes[i], from, trail_mats[i])
		trail_cubes.append(t_cube)

	var dist: float = from.distance_to(to)
	var arc_height: float = clampf(dist * 0.28, 0.35, 1.2)
	var travel_dur: float = maxf(0.05, duration)

	var tw: Tween = root.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(head):
			return
		var pos_head: Vector3 = from.lerp(to, t)
		pos_head.y += 4.0 * arc_height * t * (1.0 - t)
		head.position = pos_head
		head.rotation_degrees.z = t * 360.0
		head.rotation_degrees.x = t * 180.0

		for k: int in trail_cubes.size():
			var c: MeshInstance3D = trail_cubes[k]
			if not is_instance_valid(c):
				continue
			var trail_t: float = maxf(0.0, t - float(k + 1) * 0.06)
			var pos_trail: Vector3 = from.lerp(to, trail_t)
			pos_trail.y += 4.0 * arc_height * trail_t * (1.0 - trail_t)
			c.position = pos_trail
			c.rotation_degrees.z = trail_t * 360.0
	, 0.0, 1.0, travel_dur)

	tw.finished.connect(root.queue_free)


# =====================================================================
# Resource Caches & Internal Helpers
# =====================================================================

## Returns a cached emissive unshaded material for blooms.
static func get_emissive_material(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var key: String = "%s_%.2f" % [color.to_html(true), energy]
	if not _materials.has(key):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = mat
	return _materials[key]


## Returns a cached flat unshaded material (e.g. For scorch marks).
static func get_flat_material(color: Color) -> StandardMaterial3D:
	var key: String = "flat_%s" % color.to_html(true)
	if not _materials.has(key):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = mat
	return _materials[key]


## Returns a cached BoxMesh by size.
static func get_box_mesh(size: Vector3) -> BoxMesh:
	if not _meshes.has(size):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		_meshes[size] = mesh
	return _meshes[size]


static func _spawn_cube(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = get_box_mesh(size)
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


static func _spawn_square_frame(parent: Node3D, size: float, thickness: float, height: float, mat: Material) -> Node3D:
	var frame: Node3D = Node3D.new()
	var half_s: float = size * 0.5
	var offset: float = half_s - thickness * 0.5

	# Top and Bottom bars (along X)
	var tb_size: Vector3 = Vector3(size, height, thickness)
	_spawn_cube(frame, tb_size, Vector3(0.0, 0.0, offset), mat)
	_spawn_cube(frame, tb_size, Vector3(0.0, 0.0, -offset), mat)

	# Left and Right bars (along Z)
	var lr_len: float = maxf(0.01, size - 2.0 * thickness)
	var lr_size: Vector3 = Vector3(thickness, height, lr_len)
	_spawn_cube(frame, lr_size, Vector3(-offset, 0.0, 0.0), mat)
	_spawn_cube(frame, lr_size, Vector3(offset, 0.0, 0.0), mat)

	parent.add_child(frame)
	return frame
