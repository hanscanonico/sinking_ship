class_name Underwater
extends CanvasLayer
## The view from under the sea (SH5): while the eye is below the sea plane — a dunk,
## a wave of the list, the plunge — the fog draws in, a tint brighter toward the
## surface and darker below lies over the view, with shafts of light slanting down
## (underwater.gdshader), the surface overhead is a bright wobbling ceiling
## (water.gdshader), motes drift past and the brawler's breath bubbles up. The fog
## is thin enough that the hull stays a dark shape some way off. Presentation only
## (D12): it reads where the eye is drawn and nothing else. is_under() is the one
## answer anything else that changes under the sea asks.

const OVERLAY := preload("res://scenes/match/underwater.gdshader")
const FOG := Color(0.04, 0.2, 0.28)
## How far the fog lets the eye see under the sea, in metres, and how late it thickens.
const FOG_END := 20.0
const FOG_CURVE := 1.3
## How many motes drift before the eye at once, in what box, how far ahead.
const MOTES := 60
const MOTE_REACH := Vector3(3.0, 2.0, 3.0)
const MOTE_AHEAD := 2.5
const MOTE_COLOUR := Color(0.85, 1.0, 0.92, 0.8)
## How many bubbles rise from the brawler's breath at once, from how far before and
## below the eye.
const BUBBLES := 14
const BREATH := Vector2(0.6, 0.15)
const BUBBLE_COLOUR := Color(0.85, 0.97, 1.0, 0.7)
## How much less steep than the sun's light the shafts run, as water bends it.
const REFRACTION := 1.33

var _world: WorldEnvironment
var _above: Environment
var _below: Environment
var _tint: ColorRect
var _overlay: ShaderMaterial
var _motes: CPUParticles3D
var _bubbles: CPUParticles3D
var _under := false


func _ready() -> void:
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.material = _overlay
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.hide()
	add_child(_tint)
	_motes = _drift(MOTES, 6.0, _bead(0.03, MOTE_COLOUR, 6))
	_motes.name = "Motes"
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = MOTE_REACH
	_motes.spread = 180.0
	_motes.initial_velocity_max = 0.08
	_motes.gravity = Vector3(0.0, 0.02, 0.0)
	_bubbles = _drift(BUBBLES, 1.6, _bead(0.014, BUBBLE_COLOUR, 12))
	_bubbles.name = "Bubbles"
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 0.12
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 12.0
	_bubbles.initial_velocity_min = 0.4
	_bubbles.initial_velocity_max = 0.8
	_bubbles.gravity = Vector3(0.0, 1.2, 0.0)
	_bubbles.scale_amount_min = 0.6
	_bubbles.scale_amount_max = 1.3


## Takes over [param sea_and_sky]'s environment: its dusk above the sea, and a copy
## with the fog closed in below it; and tells its sea what the view under it is.
func setup(sea_and_sky: SeaAndSky) -> void:
	_world = sea_and_sky.world()
	_above = sea_and_sky.dusk()
	_below = _above.duplicate()
	_below.fog_enabled = true
	_below.fog_light_color = FOG
	_below.fog_depth_begin = 0.0
	_below.fog_depth_end = FOG_END
	_below.fog_depth_curve = FOG_CURVE
	_below.fog_density = 1.0
	_below.fog_aerial_perspective = 0.0
	_below.fog_sky_affect = 1.0
	var water := sea_and_sky.water()
	water.set_shader_parameter(&"under_fog_colour", FOG)
	water.set_shader_parameter(&"under_fog_end", FOG_END)
	water.set_shader_parameter(&"under_fog_curve", FOG_CURVE)
	var sun := sea_and_sky.sun()
	var slant := Vector2(-sun.x, -sun.z) / REFRACTION
	var shafts := Vector3(slant.x, -sqrt(maxf(1.0 - slant.length_squared(), 0.0)), slant.y)
	_overlay.set_shader_parameter(&"shaft_axis", shafts)
	_world.environment = _above
	_under = false
	_show_under(false)


## Glows under the sea as [param quality] has the dusk glow above it.
func show_graphics(quality: GraphicsQuality) -> void:
	_below.glow_enabled = quality.glow


## Under the sea or not, by the eye at [param eye] in the world: the sea is the
## world plane y = 0.
func show_eye(eye: Vector3) -> void:
	var under := eye.y < 0.0
	# Placed before they start, so the motes fill in round the eye, not where it
	# last went under.
	if under:
		_follow(eye)
	if under != _under:
		_under = under
		_world.environment = _below if under else _above
		_show_under(under)


## Whether the eye is under the sea.
func is_under() -> bool:
	return _under


## Aims the tint and puts the motes and the breath's bubbles before the eye at
## [param eye], as the camera looks.
func _follow(eye: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	var basis := camera.global_basis
	var size := get_viewport().get_visible_rect().size
	var across := tan(deg_to_rad(camera.fov) / 2.0)
	_overlay.set_shader_parameter(&"eye_right", basis.x)
	_overlay.set_shader_parameter(&"eye_up", basis.y)
	_overlay.set_shader_parameter(&"eye_back", basis.z)
	_overlay.set_shader_parameter(&"eye_tan", Vector2(across, across * size.y / size.x))
	_overlay.set_shader_parameter(&"depth", -eye.y)
	_motes.global_position = eye - basis.z * MOTE_AHEAD
	_bubbles.global_position = eye - basis.z * BREATH.x + Vector3.DOWN * BREATH.y


func _show_under(under: bool) -> void:
	_tint.visible = under
	for particles: CPUParticles3D in [_motes, _bubbles]:
		particles.visible = under
		particles.emitting = under
		if under:
			particles.restart()


## A bounded cloud of [param amount] particles living [param lifetime] seconds, left
## in the world where they were let go, drawn as [param mesh]; filled at once when
## it starts, so the sea is never empty for the first moments under it.
func _drift(amount: int, lifetime: float, mesh: Mesh) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.local_coords = false
	particles.emitting = false
	particles.visible = false
	particles.mesh = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.2, Color.WHITE)
	fade.add_point(0.8, Color.WHITE)
	particles.color_ramp = fade
	add_child(particles)
	return particles


## A little ball of [param radius], [param sides] round.
func _bead(radius: float, colour: Color, sides: int) -> SphereMesh:
	var bead := SphereMesh.new()
	bead.radius = radius
	bead.height = radius * 2.0
	bead.radial_segments = sides
	bead.rings = roundi(sides * 0.5)
	bead.material = _unlit(colour)
	return bead


func _unlit(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	return material
