class_name MatchView
extends Node3D
## Draws the match from two snapshots (D5): the ship root follows the interpolated
## pose, the ship drawn — dressed, or the greybox — the sinking's events as of the
## same moment, read off the schedule here and handed in, and every seat is a
## Brawler with a blob shadow, placed in ship space and standing up the frame of the
## faces the match stands on (Faces, SH32) — except the seat whose eyes the view is in,
## which is not drawn (D14) — and every crate of the cargo is placed where the snapshots
## have it, hidden once lost (SH10). Once she has broken (SH33) a seat stands in the space
## of its piece, where that piece's pose has it in the world. It never moves a body
## itself, and never reads a live PlayerState.

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
var _faces: Faces
var _pieces: Pieces
## Per seat, where it is drawn in its piece's space — its feet — and that piece's place
## in the world as drawn this frame.
var _feet := PackedVector3Array()
var _worlds: Array[Transform3D] = []
var _structure: ShipStructure
var _rooms: Array[ShipRoom] = []
var _bodies: Array[Brawler] = []
## Per seat, the facing it is drawn with, in its face's plane.
var _facings := PackedFloat64Array()
var _shadows: Array[MeshInstance3D] = []
## Per crate of the layout's cargo, the node the ship drawn draws it under.
var _crates: Array[Node3D] = []
## The seat the camera looks out of, or -1 for none.
var _eye_seat := -1
## The seat this player plays: drawn where its prediction has it, but for a
## correction being drawn away.
var _local_seat := -1
var _smoother := CorrectionSmoother.new(0.0)
## The water inside her, at each cell's level (InnerWater); null without a physical
## sinking.
var _inner: InnerWater
## Once she breaks (SH33), every piece of her drawn: the first by the ship's own node, art
## and water, kept to its stretch — her aftmost piece, _aft; the rest beside it.
var _broken := false
var _aft := 0
var _drawn_pieces: ShipPieces

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
	_faces = sim.faces
	_pieces = sim.pieces
	_structure = sim.config.ship.structure
	_rooms = sim.config.ship.rooms
	var ship := sim.config.ship
	var rules := sim.config.rules
	var leaves := ShipPieces.leaves_of(_schedule)
	_broken = not leaves.is_empty()
	_aft = leaves[0] if _broken else 0
	var falls: Array[StringName] = []
	for scheduled: SinkSchedule.Scheduled in _schedule.scheduled():
		if scheduled.event.kind == SinkEvent.Kind.COLLAPSE:
			falls.append(scheduled.event.platform)
	# Any railing may break (SH10), not only those the scenario fails.
	var fails := PackedInt32Array(range(ship.railings.size()))
	if _greybox.visible:
		_greybox.build(_pieces.layout(leaves[0]) if _broken else ship, rules.railing_height)
		_crates = _greybox.crates()
	else:
		_art.span = ShipPieces.first_span(_schedule)
		_art.build(ship, rules.railing_height, rules.body_radius, falls, fails, _open_ports())
		_crates = _art.crates()
	if _drawn_pieces == null:
		_drawn_pieces = ShipPieces.new()
		_drawn_pieces.name = "Pieces"
		add_child(_drawn_pieces)
	_drawn_pieces.setup(sim, _ship, _art, _greybox, falls, fails, _open_ports())
	for body: Brawler in _bodies:
		body.queue_free()
	for shadow: MeshInstance3D in _shadows:
		shadow.queue_free()
	_bodies.clear()
	_shadows.clear()
	_facings.resize(sim.config.seats)
	_feet.resize(sim.config.seats)
	_worlds.resize(sim.config.seats)
	for seat in sim.config.seats:
		_add_seat(seat, rules, seat == local_seat)
	_process(0.0)


## The middles of the portholes the match's hit left open: drawn open.
func _open_ports() -> PackedVector3Array:
	var found := PackedVector3Array()
	var damage := _schedule.damage()
	if damage == null or _structure == null:
		return found
	for opening: ShipOpening in _structure.openings:
		if opening.kind == ShipOpening.Kind.PORTHOLE and opening.name in damage.left_open:
			found.append(opening.centre)
	return found


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


## Where [param seat]'s feet are drawn, in the space of its piece of her: her ship space
## while she is whole.
func seat_feet(seat: int) -> Vector3:
	return _feet[seat]


## Where [param seat]'s piece of her is drawn: its space to the world (ship_to_world while
## she is whole).
func seat_to_world(seat: int) -> Transform3D:
	return _worlds[seat]


## The facing [param seat] is drawn with, in the plane of the faces it stands on.
func seat_facing(seat: int) -> float:
	return _facings[seat]


## Draws the water inside her in [param sea]'s material, when her sinking is the
## physics': each cell's at its own level, her watertight doors, and the pours between.
func flood_with(sea: ShaderMaterial) -> void:
	if _inner != null:
		_inner.queue_free()
		_inner = null
	if _schedule.timeline() == null:
		return
	_inner = InnerWater.new()
	_inner.name = "InnerWater"
	_ship.add_child(_inner)
	if _broken:
		_drawn_pieces.flood_with(sea, _inner)
		return
	var paints: Dictionary = {} if _greybox.visible else _art.paints()
	_inner.setup(_structure, _rooms, _schedule.passages(), _schedule.failing(), sea, paints)


## How far the world point [param eye] stands above the water it is in — its cell's,
## or the sea's — as the ship is drawn and her water now stands; below 0, under it.
func above_water(eye: Vector3) -> float:
	var pose := _eye_pose()
	var ship_point := _eye_world().affine_inverse() * eye
	return eye.y - pose.water_level(ship_point)


## Whether [param eye], in the world, is inside one of her cells.
func indoors(eye: Vector3) -> bool:
	return _eye_pose().cell_at(_eye_world().affine_inverse() * eye) != CellMap.NONE


## The pose of the piece of her the eyes are on, and where it is drawn: the whole ship's
## for the observer.
func _eye_pose() -> ShipPose:
	var pose := _schedule.pose_at(_driver.current["tick"])
	return pose if _eye_seat == -1 else pose.of_piece(_driver.current["seats"][_eye_seat]["piece"])


func _eye_world() -> Transform3D:
	return _ship.global_transform if _eye_seat == -1 else _worlds[_eye_seat]


## Where the ship is drawn: ship space to the world.
func ship_to_world() -> Transform3D:
	return _ship.global_transform


## The node the [param at]th piece she ends in is drawn under, and where it is drawn
## (ShipPieces): the ship's own for the first, and for a hull that never breaks.
func piece_node(at: int) -> Node3D:
	return _drawn_pieces.holder(at) if _broken else _ship


func piece_to_world(at: int) -> Transform3D:
	return piece_node(at).global_transform


func _on_corrected(by: Vector3) -> void:
	_smoother.absorb(by)


func _process(delta: float) -> void:
	if _driver == null or _driver.current.is_empty():
		return
	_smoother.advance(delta)
	var previous := _driver.previous
	var current := _driver.current
	var alpha := _driver.alpha
	var pose_then := _schedule.pose_at(previous["tick"])
	var pose_now := _schedule.pose_at(current["tick"])
	_ship.transform = pose_then.of_piece(_aft).transform.interpolate_with(
		pose_now.of_piece(_aft).transform, alpha
	)
	if _inner != null and not _broken:
		_inner.show_water(pose_then, pose_now, alpha)
	_show_sinking(
		lerpf(previous["tick"], current["tick"], alpha),
		MatchState.broken_in(current["railing_hp"]),
		pose_then,
		alpha
	)
	_show_cargo(previous["props"], current["props"], alpha)
	var seats_then: Array = previous["seats"]
	var seats_now: Array = current["seats"]
	# Bodies stand up the frame the match stands in now on their piece; across a change of
	# frame — or of piece — they are drawn in the new one, facing as it has them.
	for index in seats_now.size():
		var now: Dictionary = seats_now[index]
		var then: Dictionary = seats_then[index]
		var seat: int = now["seat"]
		var piece: int = now["piece"]
		var up := MatchState.up_of(current, now)
		var moved: bool = piece != then["piece"]
		var turned := moved or up != MatchState.up_of(previous, then)
		var to_ship := Faces.to_ship(up)
		var here := (_faces if piece == 0 else _pieces.faces(piece)).surfaces(up)
		var world := _ship.transform
		if piece != 0:
			world = pose_then.of_piece(piece).transform.interpolate_with(
				pose_now.of_piece(piece).transform, alpha
			)
		_worlds[seat] = world
		var body := _bodies[seat]
		body.visible = not now["out"] and seat != _eye_seat
		_shadows[seat].visible = false
		if now["out"]:
			continue
		var pos: Vector3 = now["pos"] if moved else (then["pos"] as Vector3).lerp(now["pos"], alpha)
		if seat == _local_seat:
			pos += _smoother.offset
		_feet[seat] = pos
		_facings[seat] = (
			now["facing"] if turned else lerp_angle(then["facing"], now["facing"], alpha)
		)
		var placed := (
			_ship.transform.affine_inverse() * world if piece != 0 else Transform3D.IDENTITY
		)
		body.transform = placed * Transform3D(to_ship * Basis(Vector3.UP, -_facings[seat]), pos)
		body.show_state(then, now, alpha)
		# A swimmer stands on nothing: no ring tilted to a deck under the sea, no shadow.
		var feet := to_ship.transposed() * pos
		var below := Surfaces.NONE
		if now["state"] != PlayerState.Body.SWIMMING:
			below = here.landing(feet)
		var normal := Vector3.UP if below == Surfaces.NONE else _ground_normal(here, below, feet)
		body.show_ground(placed.basis * (to_ship * normal))
		if below != Surfaces.NONE:
			var ground := here.height_at(below, feet)
			_shadows[seat].visible = body.visible
			_shadows[seat].transform = (
				placed
				* Transform3D(to_ship, to_ship * Vector3(feet.x, ground + SHADOW_LIFT, feet.z))
			)
	Brawler.keep_apart(_bodies, _eye_seat)


## Hands the ship drawn what the schedule's events have done by [param tick] —
## fractional, as the view interpolates between two snapshots: the platforms whose
## collapse is telegraphed and whether the blink is lit now, how far (0…1) each
## collapsed platform has fallen, by name, and the failed railings — with them those
## the match has [param broken] — and, dressed, what lights each cell, the glass broken
## and how far each funnel has fallen (SH31). A hull that breaks has each piece drawn as
## its own pose has it, [param then] the pose [param alpha] of the way from (ShipPieces).
func _show_sinking(tick: float, broken: PackedInt32Array, then: ShipPose, alpha: float) -> void:
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
	if _broken:
		_drawn_pieces.show_pieces(then, pose, alpha, tick, pose.collapsing, fallen, gone, lit)
	elif _greybox.visible:
		_greybox.show_sinking(pose.collapsing, fallen, gone, lit)
		_greybox.show_power(pose)
		_greybox.show_falls(pose.falls, tick)
	else:
		_art.show_sinking(pose.collapsing, fallen, gone, lit)
		_art.show_power(pose)
		_art.show_falls(pose.falls, tick)


## Each crate [param alpha] of the way from where [param then] has it to where
## [param now] does — the two snapshots' "props" — and hidden once it is lost.
func _show_cargo(then: Array, now: Array, alpha: float) -> void:
	for index in _crates.size():
		var entry: Dictionary = now[index]
		_crates[index].visible = entry["state"] != PropState.Body.LOST
		_crates[index].position = (then[index]["pos"] as Vector3).lerp(entry["pos"], alpha)


## The up of [param surface] of [param here] under [param pos], in that Surfaces'
## frame, from its heights a short step either side.
func _ground_normal(here: Surfaces, surface: int, pos: Vector3) -> Vector3:
	var along_x := (
		here.height_at(surface, pos + Vector3.RIGHT * SLOPE_PROBE)
		- here.height_at(surface, pos + Vector3.LEFT * SLOPE_PROBE)
	)
	var along_z := (
		here.height_at(surface, pos + Vector3.BACK * SLOPE_PROBE)
		- here.height_at(surface, pos + Vector3.FORWARD * SLOPE_PROBE)
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
