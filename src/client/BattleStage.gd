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
var _scripts: Dictionary = {}


func _init(p_viewer_side: int) -> void:
	viewer_side = p_viewer_side
	stretch = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 200)
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

	var cam: Camera3D = Camera3D.new()
	# High and far with a narrow FOV: near troops don't hide the far ones, fallen ones stay in frame.
	cam.fov = 26.0
	_world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 7.0, 9.5), Vector3(0, 0.4, 0.2))


## Puts troop_id's model in a slot (switch-in, replacement, battle start). Same uid already there: no-op.
func place(side: int, slot: int, uid: int, troop_id: String, animate: bool) -> void:
	var i: int = side * 2 + slot
	if _slot_uids[i] == uid and _slots[i] != null:
		return
	if _slots[i] != null:
		_slots[i].queue_free()
	var model: VoxelTroop = _script_for(troop_id).new()
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


func _script_for(troop_id: String) -> GDScript:
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
