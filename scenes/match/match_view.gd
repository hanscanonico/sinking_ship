class_name MatchView
extends Node3D
## Draws the match from two snapshots (D5): the ship root follows the interpolated
## pose, and every seat is a Brawler with a blob shadow, placed in ship space. It
## never moves a body itself, and never reads a live PlayerState.

## The seat colours now live in ArtPalette; this name stays for code outside the art.
const SEAT_COLOURS: Array[Color] = ArtPalette.SEAT_COLOURS
const SHADOW_COLOUR := Color(0.0, 0.0, 0.0, 0.45)
## Lift off the deck so the shadow never fights the planks for depth.
const SHADOW_LIFT := 0.02
## Half the span over which the ground's slope under a seat is measured.
const SLOPE_PROBE := 0.05

var _driver: SimDriver
var _schedule: SinkSchedule
var _surfaces: Surfaces
var _bodies: Array[Brawler] = []
var _shadows: Array[MeshInstance3D] = []

@onready var _ship: Node3D = $Ship
@onready var _greybox: ShipGreybox = $Ship/Greybox


## Draws [param sim]'s match as [param driver] steps it; [param local_seat] gets a
## marker overhead.
func setup(driver: SimDriver, sim: MatchSim, local_seat: int) -> void:
	_driver = driver
	_schedule = sim.schedule
	_surfaces = sim.surfaces
	_greybox.build(sim.config.ship, sim.config.rules.railing_height)
	for body: Brawler in _bodies:
		body.queue_free()
	for shadow: MeshInstance3D in _shadows:
		shadow.queue_free()
	_bodies.clear()
	_shadows.clear()
	var rules := sim.config.rules
	for seat in sim.config.seats:
		_add_seat(seat, rules, seat == local_seat)
	_process(0.0)


## Where [param seat] is drawn, in the world.
func seat_world_position(seat: int) -> Vector3:
	return _bodies[seat].global_position


func _process(_delta: float) -> void:
	if _driver == null or _driver.current.is_empty():
		return
	var previous := _driver.previous
	var current := _driver.current
	var alpha := _driver.alpha
	_ship.transform = (_schedule.pose_at(previous["tick"]).transform.interpolate_with(
		_schedule.pose_at(current["tick"]).transform, alpha
	))
	var seats_then: Array = previous["seats"]
	var seats_now: Array = current["seats"]
	for index in seats_now.size():
		var now: Dictionary = seats_now[index]
		var then: Dictionary = seats_then[index]
		var seat: int = now["seat"]
		var body := _bodies[seat]
		body.visible = not now["out"]
		_shadows[seat].visible = false
		if now["out"]:
			continue
		var pos: Vector3 = (then["pos"] as Vector3).lerp(now["pos"], alpha)
		body.position = pos
		body.rotation.y = -lerp_angle(then["facing"], now["facing"], alpha)
		body.show_state(then, now, alpha)
		var below := _surfaces.landing(pos)
		body.show_ground(Vector3.UP if below == Surfaces.NONE else _ground_normal(below, pos))
		if below != Surfaces.NONE:
			var ground := _surfaces.height_at(below, pos)
			_shadows[seat].visible = true
			_shadows[seat].position = Vector3(pos.x, ground + SHADOW_LIFT, pos.z)


## The up of [param surface] under [param pos], in ship space, from its heights a
## short step either side.
func _ground_normal(surface: int, pos: Vector3) -> Vector3:
	var along_x := (
		_surfaces.height_at(surface, pos + Vector3.RIGHT * SLOPE_PROBE)
		- _surfaces.height_at(surface, pos + Vector3.LEFT * SLOPE_PROBE)
	)
	var along_z := (
		_surfaces.height_at(surface, pos + Vector3.BACK * SLOPE_PROBE)
		- _surfaces.height_at(surface, pos + Vector3.FORWARD * SLOPE_PROBE)
	)
	return Vector3(-along_x, 2.0 * SLOPE_PROBE, -along_z).normalized()


func _add_seat(seat: int, rules: BrawlRules, local: bool) -> void:
	var body := Brawler.new()
	body.name = "Seat%d" % seat
	_ship.add_child(body)
	body.setup(seat, rules, local)
	_bodies.append(body)

	var disc := CylinderMesh.new()
	disc.top_radius = rules.body_radius * 1.1
	disc.bottom_radius = rules.body_radius * 1.1
	disc.height = 0.01
	var shadow_material := _material(SHADOW_COLOUR)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = shadow_material
	var shadow := MeshInstance3D.new()
	shadow.mesh = disc
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ship.add_child(shadow)
	_shadows.append(shadow)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
