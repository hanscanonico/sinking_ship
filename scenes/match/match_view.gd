class_name MatchView
extends Node3D
## Draws the match from two snapshots (D5): the ship root follows the interpolated
## pose, and every seat is a coloured capsule with a facing nose and a blob shadow,
## placed in ship space. It never moves a body itself, and never reads a live
## PlayerState.

const SEAT_COLOURS: Array[Color] = [
	Color(0.9, 0.75, 0.15),
	Color(0.85, 0.25, 0.25),
	Color(0.25, 0.55, 0.9),
	Color(0.3, 0.75, 0.35),
	Color(0.7, 0.35, 0.85),
	Color(0.95, 0.5, 0.15),
	Color(0.2, 0.8, 0.8),
	Color(0.9, 0.45, 0.65),
]
const NOSE_COLOUR := Color(0.12, 0.12, 0.14)
const SHOVING_NOSE_COLOUR := Color(1.0, 1.0, 1.0)
const SHADOW_COLOUR := Color(0.0, 0.0, 0.0, 0.45)
const MARKER_COLOUR := Color(1.0, 1.0, 1.0)
## Lift off the deck so the shadow never fights the planks for depth.
const SHADOW_LIFT := 0.02

var _driver: SimDriver
var _schedule: SinkSchedule
var _surfaces: Surfaces
var _bodies: Array[Node3D] = []
var _shadows: Array[MeshInstance3D] = []
var _noses: Array[StandardMaterial3D] = []

@onready var _ship: Node3D = $Ship
@onready var _greybox: ShipGreybox = $Ship/Greybox


## Draws [param sim]'s match as [param driver] steps it; [param local_seat] gets a
## marker overhead.
func setup(driver: SimDriver, sim: MatchSim, local_seat: int) -> void:
	_driver = driver
	_schedule = sim.schedule
	_surfaces = sim.surfaces
	_greybox.build(sim.config.ship, sim.config.rules.railing_height)
	for body: Node3D in _bodies:
		body.queue_free()
	for shadow: MeshInstance3D in _shadows:
		shadow.queue_free()
	_bodies.clear()
	_shadows.clear()
	_noses.clear()
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
		var shoving: bool = (
			now["action"] == PlayerState.Action.WINDUP or now["action"] == PlayerState.Action.ACTIVE
		)
		_noses[seat].albedo_color = SHOVING_NOSE_COLOUR if shoving else NOSE_COLOUR
		var below := _surfaces.landing(pos)
		if below != Surfaces.NONE:
			var ground := _surfaces.height_at(below, pos)
			_shadows[seat].visible = true
			_shadows[seat].position = Vector3(pos.x, ground + SHADOW_LIFT, pos.z)


func _add_seat(seat: int, rules: BrawlRules, local: bool) -> void:
	var body := Node3D.new()
	body.name = "Seat%d" % seat
	_ship.add_child(body)
	_bodies.append(body)

	var capsule := CapsuleMesh.new()
	capsule.radius = rules.body_radius
	capsule.height = rules.body_height
	capsule.material = _material(SEAT_COLOURS[seat % SEAT_COLOURS.size()])
	_mesh(body, capsule, Vector3(0.0, rules.body_height * 0.5, 0.0))

	var nose := BoxMesh.new()
	nose.size = Vector3(0.35, 0.18, 0.18)
	var nose_material := _material(NOSE_COLOUR)
	nose.material = nose_material
	_noses.append(nose_material)
	_mesh(body, nose, Vector3(rules.body_radius + 0.1, rules.body_height * 0.72, 0.0))

	if local:
		var marker := PrismMesh.new()
		marker.size = Vector3(0.4, 0.35, 0.4)
		marker.material = _material(MARKER_COLOUR)
		var arrow := _mesh(body, marker, Vector3(0.0, rules.body_height + 0.45, 0.0))
		arrow.rotation.z = PI

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


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
