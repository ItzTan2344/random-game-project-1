class_name VoxelTroop
extends Node3D
## Base for code-built voxel troops: shared mesh/material caches, a standard humanoid rig, and procedural animations.
## Subclasses override _build() (call humanoid() first, then add gear). Models face +Z with feet on y=0.

const SKIN := Color("#f1c27d")
const EYE := Color("#1b1b24")

static var _materials: Dictionary = {}
static var _meshes_by_size: Dictionary = {}

## Whole-body moves (lunge, knockback, fall) act on pose so idle motion on the limbs never fights them.
var pose: Node3D
var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var dead: bool = false

var _tween: Tween
var _flash_tween: Tween
var _flash: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _t: float = 0.0


func _ready() -> void:
	pose = _pivot(self, Vector3.ZERO)
	_build()
	for m: Node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m as MeshInstance3D)
	_t = float(get_instance_id() % 997) * 0.1
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1, 1, 1, 0)


## Fallback look for troops without their own script.
func _build() -> void:
	humanoid(SKIN, Color("#8a93a6"), Color("#4a5060"), Color("#2b2f3a"))


func _process(delta: float) -> void:
	if dead or body == null:
		return
	_t += delta
	# Bob the torso down into the legs (never up, so no gap opens at the hip).
	body.position.y = 0.6 - (sin(_t * 2.4) + 1.0) * 0.02
	head.rotation_degrees.z = sin(_t * 1.1) * 2.0


# =====================================================================
# Building
# =====================================================================

## Standard chibi body, ~1.9 units tall. bulk widens torso, legs, and arm spacing.
func humanoid(skin: Color, top: Color, bottom: Color, shoes: Color, bulk: float = 1.0) -> void:
	var half_w: float = 0.3 * bulk
	for side: float in [-1.0, 1.0]:
		var leg: Node3D = _pivot(pose, Vector3(side * 0.15 * bulk, 0.6, 0))
		box(Vector3(0.24 * bulk, 0.5, 0.26), Vector3(0, -0.25, 0), bottom, leg)
		box(Vector3(0.26 * bulk, 0.12, 0.34), Vector3(0, -0.54, 0.04), shoes, leg)
		if side < 0.0:
			leg_r = leg
		else:
			leg_l = leg
	body = _pivot(pose, Vector3(0, 0.6, 0))
	box(Vector3(half_w * 2.0, 0.6, 0.36), Vector3(0, 0.3, 0), top, body)
	# Facing +Z, the model's right hand is on -X.
	for side: float in [-1.0, 1.0]:
		var arm: Node3D = _pivot(body, Vector3(side * (half_w + 0.11), 0.52, 0))
		box(Vector3(0.2, 0.42, 0.22), Vector3(0, -0.17, 0), top, arm)
		var hand: Node3D = _pivot(arm, Vector3(0, -0.44, 0))
		box(Vector3(0.18, 0.14, 0.2), Vector3.ZERO, skin, hand)
		if side < 0.0:
			arm_r = arm
			hand_r = hand
		else:
			arm_l = arm
			hand_l = hand
	head = _pivot(body, Vector3(0, 0.6, 0))
	box(Vector3(0.7, 0.62, 0.62), Vector3(0, 0.31, 0), skin, head)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.12, 0.16, 0.02), Vector3(side * 0.15, 0.3, 0.315), EYE, head)


func box(size: Vector3, pos: Vector3, color: Color, parent: Node3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = _box_mesh(size)
	m.material_override = material(color)
	m.position = pos
	m.rotation_degrees = rot_deg
	parent.add_child(m)
	return m


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		_materials[color] = mat
	return _materials[color]


static func _box_mesh(size: Vector3) -> BoxMesh:
	if not _meshes_by_size.has(size):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		_meshes_by_size[size] = mesh
	return _meshes_by_size[size]


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


# =====================================================================
# Animation
# =====================================================================

## anim: attack, cast, hit, buff, death, enter. Restarting mid-animation snaps back to rest first.
func play(anim: StringName) -> void:
	if dead:
		return
	if _tween != null:
		_tween.kill()
	_rest()
	_tween = create_tween().set_parallel(true)
	match anim:
		&"attack":
			_tween.tween_property(pose, "position:z", 0.6, 0.12)
			_tween.tween_property(arm_r, "rotation_degrees:x", -160.0, 0.12)
			_tween.chain().tween_property(arm_r, "rotation_degrees:x", -40.0, 0.08)
			_tween.chain().tween_property(pose, "position:z", 0.0, 0.22).set_delay(0.08)
			_tween.tween_property(arm_r, "rotation_degrees:x", 0.0, 0.22).set_delay(0.08)
		&"cast":
			for arm: Node3D in [arm_l, arm_r]:
				_tween.tween_property(arm, "rotation_degrees:z", signf(arm.position.x) * 150.0, 0.15)
				_tween.tween_property(arm, "rotation_degrees:z", 0.0, 0.25).set_delay(0.3)
			_tween.tween_property(pose, "position:y", 0.25, 0.15)
			_tween.tween_property(pose, "position:y", 0.0, 0.25).set_delay(0.3)
			flash(Color("#ffe27a"))
		&"hit":
			_tween.tween_property(pose, "position:z", -0.3, 0.08)
			_tween.tween_property(pose, "rotation_degrees:x", -12.0, 0.08)
			_tween.chain().tween_property(pose, "position:z", 0.0, 0.2)
			_tween.tween_property(pose, "rotation_degrees:x", 0.0, 0.2)
			flash(Color.WHITE)
		&"buff":
			_tween.tween_property(pose, "position:y", 0.2, 0.12).set_ease(Tween.EASE_OUT)
			_tween.chain().tween_property(pose, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)
			flash(Color("#7dffa0"))
		&"death":
			dead = true
			_tween.tween_property(pose, "rotation_degrees:x", 90.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.tween_property(pose, "position:y", -0.1, 0.45)
			flash(Color("#ff4040"))
		&"enter":
			pose.scale = Vector3.ONE * 0.05
			_tween.tween_property(pose, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Falls face-forward (toward the arena center, never out of frame). Jumps straight to the fallen pose (snapshot sync for a troop already KO'd).
func set_dead() -> void:
	if dead:
		return
	if _tween != null:
		_tween.kill()
	_rest()
	dead = true
	pose.rotation_degrees.x = 90.0
	pose.position.y = -0.1


func flash(color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.albedo_color = Color(color, 0.75)
	for m: MeshInstance3D in _meshes:
		m.material_overlay = _flash
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "albedo_color:a", 0.0, 0.3)
	_flash_tween.tween_callback(_clear_flash)


func _clear_flash() -> void:
	for m: MeshInstance3D in _meshes:
		m.material_overlay = null


func _rest() -> void:
	pose.position = Vector3.ZERO
	pose.rotation = Vector3.ZERO
	pose.scale = Vector3.ONE
	for arm: Node3D in [arm_l, arm_r]:
		arm.rotation = Vector3.ZERO
