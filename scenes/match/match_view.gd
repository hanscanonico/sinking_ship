class_name MatchView
extends Node3D
## Draws the match from two snapshots (D5): the ship root follows the interpolated
## pose, the ship drawn — dressed, or the greybox — the sinking's events as of the
## same moment, read off the schedule here and handed in, and every seat is a
## Brawler with a blob shadow, placed in ship space — except the seat whose eyes the
## view is in, which is not drawn (D14) — and every crate of the cargo is placed where
## the snapshots have it, hidden once lost (SH10). It never moves a body itself, and
## never reads a live PlayerState.

## The seat colours now live in ArtPalette; this name stays for code outside the art.
const SEAT_COLOURS: Array[Color] = ArtPalette.SEAT_COLOURS
const SHADOW_COLOUR := Color(0.0, 0.0, 0.0, 0.45)
## Lift off the deck so the shadow never fights the planks for depth.
const SHADOW_LIFT := 0.02
## Half the span over which the ground's slope under a seat is measured.
const SLOPE_PROBE := 0.05
## A telegraphed collapse blinks this many ticks on and off; a collapsed deck takes
## FALL_SECONDS to fall.
const BLINK_TICKS := 6
const FALL_SECONDS := 0.5

var _driver: SimDriver
var _schedule: SinkSchedule
var _surfaces: Surfaces
var _bodies: Array[Brawler] = []
var _shadows: Array[MeshInstance3D] = []
## Per crate of the layout's cargo, the node the ship drawn draws it under.
var _crates: Array[Node3D] = []
## The seat the camera looks out of, or -1 for none.
var _eye_seat := -1
## The seat this player plays: drawn where its prediction has it, but for a
## correction being drawn away.
var _local_seat := -1
var _smoother := CorrectionSmoother.new(0.0)

@onready var _ship: Node3D = $Ship
@onready var _greybox: ShipGreybox = $Ship/Greybox
@onready var _art: ShipArt = $Ship/ShipArt


## Draws [param sim]'s match as [param driver] steps it; [param local_seat] gets a
## marker overhead (look_out_of), and each correction to its predicted body is drawn
## away over [param correction_time] seconds (D12).
func setup(driver: SimDriver, sim: MatchSim, local_seat: int, correction_time: float = 0.0) -> void:
	if _driver != null:
		_driver.corrected.disconnect(_on_corrected)
	_driver = driver
	_driver.corrected.connect(_on_corrected)
	_local_seat = local_seat
	_smoother = CorrectionSmoother.new(correction_time)
	_schedule = sim.schedule
	_surfaces = sim.surfaces
	var ship := sim.config.ship
	var rules := sim.config.rules
	if _greybox.visible:
		_greybox.build(ship, rules.railing_height)
		_crates = _greybox.crates()
	else:
		var falls: Array[StringName] = []
		for event: SinkEvent in sim.config.scenario.events:
			if event.kind == SinkEvent.Kind.COLLAPSE:
				falls.append(event.platform)
		# Any railing may break (SH10), not only those the scenario fails.
		var fails := PackedInt32Array(range(ship.railings.size()))
		_art.build(ship, rules.railing_height, rules.body_radius, falls, fails)
		_crates = _art.crates()
	for body: Brawler in _bodies:
		body.queue_free()
	for shadow: MeshInstance3D in _shadows:
		shadow.queue_free()
	_bodies.clear()
	_shadows.clear()
	for seat in sim.config.seats:
		_add_seat(seat, rules, seat == local_seat)
	_process(0.0)


## Draws every seat but [param seat] from now on — the view is in its eyes — or
## every seat when it is -1, the observer camera's view, the only one the local
## seat's marker shows in: through a seat's eyes the first-person HUD names every
## seat, and the marker would hang before them as a blank shape.
func look_out_of(seat: int) -> void:
	_eye_seat = seat
	_bodies[_local_seat].show_marker(seat == -1)
	if seat != -1:
		_bodies[seat].visible = false
		_shadows[seat].visible = false


## The seat whose eyes the view is in, or -1 for none.
func eye_seat() -> int:
	return _eye_seat


## Where [param seat] is drawn, in the world.
func seat_world_position(seat: int) -> Vector3:
	return _bodies[seat].global_position


## Where [param seat]'s feet are drawn, in ship space.
func seat_feet(seat: int) -> Vector3:
	return _bodies[seat].position


## The ship-plane facing [param seat] is drawn with.
func seat_facing(seat: int) -> float:
	return -_bodies[seat].rotation.y


## Where the ship is drawn: ship space to the world.
func ship_to_world() -> Transform3D:
	return _ship.global_transform


func _on_corrected(by: Vector3) -> void:
	_smoother.absorb(by)


func _process(delta: float) -> void:
	if _driver == null or _driver.current.is_empty():
		return
	_smoother.advance(delta)
	var previous := _driver.previous
	var current := _driver.current
	var alpha := _driver.alpha
	_ship.transform = (_schedule.pose_at(previous["tick"]).transform.interpolate_with(
		_schedule.pose_at(current["tick"]).transform, alpha
	))
	_show_sinking(
		lerpf(previous["tick"], current["tick"], alpha), MatchState.broken_in(current["railing_hp"])
	)
	_show_cargo(previous["props"], current["props"], alpha)
	var seats_then: Array = previous["seats"]
	var seats_now: Array = current["seats"]
	for index in seats_now.size():
		var now: Dictionary = seats_now[index]
		var then: Dictionary = seats_then[index]
		var seat: int = now["seat"]
		var body := _bodies[seat]
		body.visible = not now["out"] and seat != _eye_seat
		_shadows[seat].visible = false
		if now["out"]:
			continue
		var pos: Vector3 = (then["pos"] as Vector3).lerp(now["pos"], alpha)
		if seat == _local_seat:
			pos += _smoother.offset
		body.position = pos
		body.rotation.y = -lerp_angle(then["facing"], now["facing"], alpha)
		body.show_state(then, now, alpha)
		# A swimmer stands on nothing: no ring tilted to a deck under the sea, no shadow.
		var below := Surfaces.NONE
		if now["state"] != PlayerState.Body.SWIMMING:
			below = _surfaces.landing(pos)
		body.show_ground(Vector3.UP if below == Surfaces.NONE else _ground_normal(below, pos))
		if below != Surfaces.NONE:
			var ground := _surfaces.height_at(below, pos)
			_shadows[seat].visible = body.visible
			_shadows[seat].position = Vector3(pos.x, ground + SHADOW_LIFT, pos.z)


## Hands the ship drawn what the schedule's events have done by [param tick] —
## fractional, as the view interpolates between two snapshots: the platforms whose
## collapse is telegraphed and whether the blink is lit now, how far (0…1) each
## collapsed platform has fallen, by name, and the failed railings — with them those
## the match has [param broken].
func _show_sinking(tick: float, broken: PackedInt32Array) -> void:
	var now := floori(tick)
	var pose := _schedule.pose_at(now)
	var fallen := {}
	for scheduled: SinkSchedule.Scheduled in _schedule.fired(now):
		if scheduled.event.kind == SinkEvent.Kind.COLLAPSE:
			var since := (tick - scheduled.at) * Ticks.SECONDS_PER_TICK
			fallen[scheduled.event.platform] = clampf(since / FALL_SECONDS, 0.0, 1.0)
	var lit := now / BLINK_TICKS % 2 == 0
	var gone := pose.broken_railings.duplicate()
	gone.append_array(broken)
	if _greybox.visible:
		_greybox.show_sinking(pose.collapsing, fallen, gone, lit)
	else:
		_art.show_sinking(pose.collapsing, fallen, gone, lit)


## Each crate [param alpha] of the way from where [param then] has it to where
## [param now] does — the two snapshots' "props" — and hidden once it is lost.
func _show_cargo(then: Array, now: Array, alpha: float) -> void:
	for index in _crates.size():
		var entry: Dictionary = now[index]
		_crates[index].visible = entry["state"] != PropState.Body.LOST
		_crates[index].position = (then[index]["pos"] as Vector3).lerp(entry["pos"], alpha)


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
