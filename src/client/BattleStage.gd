class_name BattleStage
extends SubViewportContainer
## 3D arena between the card rows. Holds one VoxelTroop per active slot; BattleUI drives it from events and snapshots.
## Purely cosmetic: cards stay the click targets and the source of truth for numbers.

const AVATAR_PATH := "res://src/client/avatars/%s.gd"
const SLOT_X: Array[float] = [-1.5, 1.5]
const SIDE_Z := 1.3

var viewer_side: int = CombatTypes.Side.A

var _world: Node3D
var _slots: Array[VoxelTroop] = [null, null, null, null]
var _slot_uids: Array[int] = [-1, -1, -1, -1]
static var _scripts: Dictionary = {}
var _cam: Camera3D
var _rings: Array[Node3D] = []
var _ring_mats: Array[StandardMaterial3D] = []
var _t: float = 0.0


func _init(p_viewer_side: int) -> void:
	viewer_side = p_viewer_side
	stretch = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	_world = Node3D.new()
	viewport.add_child(_world)

	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.64, 0.72)
	_world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	_world.add_child(sun)

	# Arena floor: a slab with a center line and one colored pad per side.
	var floor_box: MeshInstance3D = _slab(Vector3(7.5, 0.2, 5.2), Vector3(0, -0.1, 0), Color("#2a3142"))
	_world.add_child(floor_box)
	_world.add_child(_slab(Vector3(7.5, 0.02, 0.06), Vector3(0, 0.005, 0), Color("#4a5470")))
	for side in 2:
		_world.add_child(_slab(Vector3(4.6, 0.02, 1.6), Vector3(0, 0.005, _side_z(side)), BattleUI.SIDE_COLORS[side].darkened(0.55)))

	# One square ring per slot: gold under the acting troop, red under valid targets.
	for i in 4:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var ring: Node3D = Node3D.new()
		for k in 4:
			var bar: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(1.5, 0.04, 0.12)
			bar.mesh = mesh
			bar.material_override = mat
			bar.rotation_degrees.y = 90.0 * k
			bar.position = Vector3(0, 0.03, 0.69).rotated(Vector3.UP, deg_to_rad(90.0 * k))
			ring.add_child(bar)
		ring.position = Vector3(SLOT_X[i % 2], 0, _side_z(i >> 1))
		ring.visible = false
		_world.add_child(ring)
		_rings.append(ring)
		_ring_mats.append(mat)

	_cam = Camera3D.new()
	# High and far with a narrow FOV: near troops don't hide the far ones, fallen ones stay in frame.
	_cam.fov = 26.0
	_world.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 9.8, 13.3), Vector3(0, 0.5, 0.1))


func _process(delta: float) -> void:
	_t += delta
	var s: float = 1.0 + 0.06 * sin(_t * 5.0)
	for ring in _rings:
		ring.scale = Vector3(s, 1.0, s)


## Shows a ring under uid's slot (Color(0,0,0,0) hides it).
func set_ring(uid: int, color: Color) -> void:
	var i: int = _slot_uids.find(uid)
	if i == -1:
		return
	_rings[i].visible = color.a > 0.0
	_ring_mats[i].albedo_color = color


func clear_rings() -> void:
	for ring in _rings:
		ring.visible = false


## Screen position (this control's parent space) at uid's chest (far-side heads sit under the foe cards), or Vector2.INF if it isn't on the field.
func head_position(uid: int) -> Vector2:
	var model: VoxelTroop = model_for(uid)
	if model == null or _cam == null:
		return Vector2.INF
	return position + _cam.unproject_position(model.global_position + Vector3(0, 1.6, 0))


## Nearest troop to a screen point (same space as head_position), within radius px; -1 if none.
func pick(point: Vector2, radius: float = 70.0) -> int:
	var best: int = -1
	var best_d: float = radius
	for i in 4:
		if _slots[i] == null:
			continue
		var p: Vector2 = position + _cam.unproject_position(_slots[i].global_position + Vector3(0, 0.9, 0))
		var d: float = p.distance_to(point)
		if d < best_d:
			best_d = d
			best = _slot_uids[i]
	return best


## Puts troop_id's model in a slot (switch-in, replacement, battle start). Same uid already there: no-op.
func place(side: int, slot: int, uid: int, troop_id: String, animate: bool) -> void:
	var i: int = side * 2 + slot
	if _slot_uids[i] == uid and _slots[i] != null:
		return
	if _slots[i] != null:
		_slots[i].queue_free()
	var model: VoxelTroop = script_for(troop_id).new()
	model.position = Vector3(SLOT_X[slot], 0, _side_z(side))
	# Models face +Z; turn each side to face the other.
	model.rotation_degrees.y = 180.0 if _side_z(side) > 0.0 else 0.0
	_world.add_child(model)
	_slots[i] = model
	_slot_uids[i] = uid
	if animate:
		model.play(&"enter")


func clear_slot(side: int, slot: int) -> void:
	var i: int = side * 2 + slot
	if _slots[i] != null:
		_slots[i].queue_free()
	_slots[i] = null
	_slot_uids[i] = -1


func clear() -> void:
	for side in 2:
		for slot in CombatTypes.ACTIVE_SLOTS:
			clear_slot(side, slot)


func play(uid: int, anim: StringName) -> void:
	var model: VoxelTroop = model_for(uid)
	if model != null:
		model.play(anim)


func model_for(uid: int) -> VoxelTroop:
	var i: int = _slot_uids.find(uid)
	return _slots[i] if i != -1 else null


## Viewer's side sits near the camera.
func _side_z(side: int) -> float:
	return SIDE_Z if side == viewer_side else -SIDE_Z


static func script_for(troop_id: String) -> GDScript:
	if not _scripts.has(troop_id):
		var path: String = AVATAR_PATH % troop_id
		_scripts[troop_id] = load(path) if ResourceLoader.exists(path) else VoxelTroop
	return _scripts[troop_id]


func _slab(box_size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	m.mesh = mesh
	m.material_override = VoxelTroop.material(color)
	m.position = pos
	return m
