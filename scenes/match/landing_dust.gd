class_name LandingDust
extends Node3D
## A puff of dust where a falling body comes down, kicked up by the sim's Landed
## event at the feet its snapshot puts there (D5), and a bigger one for a harder
## landing. Never under the seat whose eyes the view is in, as MatchView draws no
## body there (D14). And a burst of splinters from the middle of a railing span as
## it breaks (RailingBroke, SH10). Presentation only (D12): it moves nothing.

const COLOUR := Color(0.78, 0.74, 0.66, 0.55)
const GRAINS := 14
const LIFETIME := 0.45
## How fast the grains spread over the deck, in m/s, and how much more for every
## tick of stagger the drop cost.
const SPREAD_SPEED := 1.2
const SPREAD_PER_STAGGER := 0.12
const GRAIN_SIZE := 0.07
## A breaking span's splinters: their colour, and how hard they fly.
const SPLINTER := Color(0.62, 0.42, 0.26)
const SPLINTER_STAGGER := 20

var _driver: SimDriver
var _view: MatchView
var _grain: QuadMesh


func setup(driver: SimDriver, view: MatchView) -> void:
	if _driver != null:
		_driver.stepped.disconnect(_on_stepped)
	_driver = driver
	_view = view
	_driver.stepped.connect(_on_stepped)
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOUR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	_grain = QuadMesh.new()
	_grain.size = Vector2.ONE * GRAIN_SIZE
	_grain.material = material


func _on_stepped(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.RAILING_BROKE:
			var config := _driver.runner.sim.config
			var middle := config.ship.railing_middle(
				event.railing, config.rules.railing_height * 0.5
			)
			var puff := _puff(_view.ship_to_world() * middle, SPLINTER_STAGGER)
			puff.color = SPLINTER
		if event.kind != SimEvent.Kind.LANDED or event.seat == _view.eye_seat():
			continue
		var feet: Vector3 = _driver.current["seats"][event.seat]["pos"]
		_puff(_view.ship_to_world() * feet, event.stagger_ticks)


func _puff(at: Vector3, stagger_ticks: int) -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.mesh = _grain
	puff.amount = GRAINS
	puff.lifetime = LIFETIME
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.direction = Vector3.UP
	puff.spread = 80.0
	puff.flatness = 0.6
	puff.initial_velocity_min = SPREAD_SPEED * 0.5
	puff.initial_velocity_max = SPREAD_SPEED + SPREAD_PER_STAGGER * stagger_ticks
	puff.gravity = Vector3(0.0, -2.0, 0.0)
	puff.damping_min = 2.0
	puff.damping_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	puff.color_ramp = fade
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	puff.global_position = at
	puff.finished.connect(puff.queue_free)
	puff.emitting = true
	return puff
