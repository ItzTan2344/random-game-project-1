class_name Portraits
extends Node
## Renders each troop's VoxelTroop once (head and shoulders) into a small offscreen SubViewport.
## The ViewportTextures are shared by cards, turn-order chips, the draft, standby and result screens.

const PX := 128

var _textures: Dictionary = {}


func texture(troop_id: String) -> Texture2D:
	if _textures.has(troop_id):
		return _textures[troop_id]
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	vp.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	vp.add_child(sun)
	var model: VoxelTroop = BattleStage.script_for(troop_id).new()
	model.process_mode = Node.PROCESS_MODE_DISABLED
	vp.add_child(model)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	# Three-quarter view of the head and upper torso.
	cam.look_at_from_position(Vector3(1.1, 1.75, 3.1), Vector3(0, 1.35, 0))
	_textures[troop_id] = vp.get_texture()
	return _textures[troop_id]


## Framed portrait square: side/accent-coloured border, dark backdrop.
func icon(troop_id: String, accent: Color, px: int) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s: StyleBoxFlat = UITheme.box(accent.darkened(0.7), accent, 2, 3, 5)
	s.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", s)
	var t: TextureRect = TextureRect.new()
	t.texture = texture(troop_id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)
	return p
