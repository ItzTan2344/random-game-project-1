class_name BattleStage
extends SubViewportContainer
## 3D arena between the card rows. Holds one VoxelTroop per active slot; BattleUI drives it from events and snapshots.
## Purely cosmetic: cards stay the click targets and the source of truth for numbers.

const AVATAR_PATH := "res://src/client/avatars/%s.gd"
const SLOT_X: Array[float] = [-1.5, 1.5]
const SIDE_Z := 1.3
const CAM_POS := Vector3(0, 9.8, 13.3)
const CAM_LOOK := Vector3(0, 0.5, 0.1)

var viewer_side: int = CombatTypes.Side.A

var _world: Node3D
var _slots: Array[VoxelTroop] = [null, null, null, null]
var _slot_uids: Array[int] = [-1, -1, -1, -1]
static var _scripts: Dictionary = {}
var _cam: Camera3D
var _rings: Array[Node3D] = []
var _ring_mats: Array[StandardMaterial3D] = []
var _t: float = 0.0
var _arena: ArenaEnvironment


func _init(p_viewer_side: int) -> void:
	viewer_side = p_viewer_side
	stretch = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	_world = Node3D.new()
	viewport.add_child(_world)

	var near: int = viewer_side
	_arena = ArenaEnvironment.new(BattleUI.SIDE_COLORS[near], BattleUI.SIDE_COLORS[1 - near])
	_world.add_child(_arena)

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
	_cam.look_at_from_position(CAM_POS, CAM_LOOK)


func _process(delta: float) -> void:
	_t += delta
	var s: float = 1.0 + 0.06 * sin(_t * 5.0)
	for ring in _rings:
		ring.scale = Vector3(s, 1.0, s)
	# Slow handheld drift so the scene never feels frozen.
	var drift: Vector3 = Vector3(sin(_t * 0.23) * 0.35, sin(_t * 0.31) * 0.12, 0.0)
	_cam.look_at_from_position(CAM_POS + drift, CAM_LOOK)


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


# =====================================================================
# Combat VFX (HitFX), anchored on a troop's chest; no-ops if uid isn't on the field.
# =====================================================================

func fx_impact(uid: int, color: Color, crit: bool) -> void:
	var p: Vector3 = _chest(uid)
	if p != Vector3.INF:
		HitFX.impact(_world, p, color, crit)


func fx_heal(uid: int) -> void:
	var p: Vector3 = _chest(uid)
	if p != Vector3.INF:
		HitFX.heal(_world, p)


func fx_buff(uid: int, color: Color) -> void:
	var p: Vector3 = _chest(uid)
	if p != Vector3.INF:
		HitFX.buff(_world, p, color)


func fx_cast(uid: int, color: Color) -> void:
	var p: Vector3 = _chest(uid)
	if p != Vector3.INF:
		HitFX.cast(_world, p, color)


func fx_ko(uid: int) -> void:
	var p: Vector3 = _chest(uid)
	if p != Vector3.INF:
		HitFX.ko(_world, p)


func fx_projectile(from_uid: int, to_uid: int, color: Color, duration: float) -> void:
	var a: Vector3 = _chest(from_uid)
	var b: Vector3 = _chest(to_uid)
	if a != Vector3.INF and b != Vector3.INF:
		HitFX.projectile(_world, a, b, color, duration)


## Crowd in the stands jumps up for a moment.
func cheer() -> void:
	_arena.cheer()


func _chest(uid: int) -> Vector3:
	var model: VoxelTroop = model_for(uid)
	return model.global_position + Vector3(0, 1.0, 0) if model != null else Vector3.INF
