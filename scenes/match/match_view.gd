class_name MatchView
extends Node3D
## Draws the match from two snapshots (D5): the ship root follows the interpolated
## pose, the ship drawn — dressed, or the greybox — the sinking's events as of the
## same moment, read off the schedule here and handed in, and every seat is a
## Brawler with a blob shadow, placed in ship space and standing up the frame of the
## faces the match stands on (Faces, SH32) — except the seat whose eyes the view is in,
## which is not drawn (D14) — and every prop is placed where the snapshots have it
## (PropPlacing): a crate where it stands, a ring hung on its span or carried before its
## holder, whose hands reach for it, hidden once lost (SH10, #273); every bonus aboard at
## its spot, in greybox (BonusGreybox, #307), and every seat with a bonus wearing its kind's
## mark (Brawler.wear_bonus). Once she has broken
## (SH33) a seat stands in the space of its piece, where that piece's pose has it in the
## world. It never moves a body itself, and never reads a live PlayerState.

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
## The most bodies in water the water's rings are drawn round (water.gdshader).
const MAX_WADERS := 8
## How many props in a row a frame asks at once whether they are as last drawn.
const STILL_RUN := 16

var _driver: SimDriver
var _schedule: SinkSchedule
var _faces: Faces
var _pieces: Pieces
## Per seat, where it is drawn in its piece's space — its feet — how tall it is there
## (BrawlRules.height_at: a crawler lower), and that piece's place in the world as drawn
## this frame.
var _feet := PackedVector3Array()
var _heights := PackedFloat64Array()
var _rules: BrawlRules
var _worlds: Array[Transform3D] = []
var _structure: ShipStructure
var _rooms: Array[ShipRoom] = []
var _bodies: Array[Brawler] = []
## Per seat, the facing it is drawn with, in its face's plane.
var _facings := PackedFloat64Array()
var _shadows: Array[MeshInstance3D] = []
## Her props as the ship drawn draws them: the dressed art's (PropArt), or per prop the
## greybox's node; per prop the snapshot entry it was last drawn still at, so a prop
## that has not moved since is passed over; the props a hand may hold (GrabReach); and
## the layout.
var _prop_art: PropArt
var _props: Array[Node3D] = []
var _still: Array = []
var _holdable := PackedInt32Array()
var _layout: ShipLayout
## The bonuses aboard, drawn at their spots (#307); and the kinds they may be, whose mark a
## seat with one wears: none in a match without bonuses.
var _bonus_greybox: BonusGreybox
var _bonus_kinds: Array[BonusKind] = []
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
## What the sinking has done by the tick drawn, worked out once a tick rather than every
## frame (_show_sinking): the railings gone — the pose's failed ones and those the
## snapshot's railings have broken — and the collapses fired; for that tick and those
## railings.
var _gone := PackedInt32Array()
var _collapses: Array[SinkSchedule.Scheduled] = []
var _sinking_tick := -1
var _sinking_hp := PackedFloat64Array()
## The bodies in the sea the sea's rings are drawn round (waders), and the tick they
## are as of.
var _waders := PackedVector4Array()
var _waders_tick := -1

@onready var _ship: Node3D = $Ship
@onready var _greybox: ShipGreybox = $Ship/Greybox
@onready var _art: ShipArt = $Ship/ShipArt


## Draws [param sim]'s match as [param driver] steps it; [param local_seat] gets a
## marker overhead (look_out_of), and each correction to its predicted body is drawn
## away over [param correction_time] seconds (D12). The ship is drawn as [param dressing]
## dressed her, its art taking the place of the ship's own; with none she is dressed here
## and now, which takes seconds (ShipDressing).
func setup(
	driver: SimDriver,
	sim: MatchSim,
	local_seat: int,
	correction_time: float = 0.0,
	dressing: ShipDressing = null
) -> void:
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
	_layout = ship
	var leaves := ShipPieces.leaves_of(_schedule)
	_broken = not leaves.is_empty()
	_aft = leaves[0] if _broken else 0
	var stretches: Array[ShipArt] = []
	if _greybox.visible:
		_greybox.build(_pieces.layout(leaves[0]) if _broken else ship, rules.railing_height)
		_props = _greybox.props()
		_prop_art = null
	else:
		if dressing == null:
			dressing = ShipDressing.new(sim.config, _art.cut_above)
		dressing.finish()
		_wear(dressing.art)
		stretches = dressing.stretches
		_props = []
		_prop_art = _art.prop_art
	_still.clear()
	_still.resize(ship.props.size())
	_holdable = GrabReach.holdable_of(ship)
	if _bonus_greybox == null:
		_bonus_greybox = BonusGreybox.new()
		_bonus_greybox.name = "Bonuses"
		_ship.add_child(_bonus_greybox)
	_bonus_greybox.setup(ship, sim.config.bonus_rules)
	_bonus_kinds.clear()
	if sim.config.bonus_rules != null:
		_bonus_kinds.assign(sim.config.bonus_rules.kinds)
	if _drawn_pieces == null:
		_drawn_pieces = ShipPieces.new()
		_drawn_pieces.name = "Pieces"
		add_child(_drawn_pieces)
	_drawn_pieces.setup(sim, _ship, _art, _greybox, stretches)
	_sinking_tick = -1
	for body: Brawler in _bodies:
		body.queue_free()
	for shadow: MeshInstance3D in _shadows:
		shadow.queue_free()
	_bodies.clear()
	_shadows.clear()
	_facings.resize(sim.config.seats)
	_feet.resize(sim.config.seats)
	_heights.resize(sim.config.seats)
	_rules = rules
	_worlds.resize(sim.config.seats)
	for seat in sim.config.seats:
		_add_seat(seat, rules, seat == local_seat)
	_process(0.0)


## The ship's dressed art as drawn: what setup's dressing made.
func art() -> ShipArt:
	return _art


## The platforms [param schedule]'s sinking collapses: built to fall.
static func falls_of(schedule: SinkSchedule) -> Array[StringName]:
	var falls: Array[StringName] = []
	for scheduled: SinkSchedule.Scheduled in schedule.scheduled():
		if scheduled.event.kind == SinkEvent.Kind.COLLAPSE:
			falls.append(scheduled.event.platform)
	return falls


## The middles of the portholes of [param structure] that [param schedule]'s hit left
## open: drawn open.
static func open_ports_of(schedule: SinkSchedule, structure: ShipStructure) -> PackedVector3Array:
	var found := PackedVector3Array()
	var damage := schedule.damage()
	if damage == null or structure == null:
		return found
	for opening: ShipOpening in structure.openings:
		if opening.kind == ShipOpening.Kind.PORTHOLE and opening.name in damage.left_open:
			found.append(opening.centre)
	return found


## Draws the ship as [param dressed] — a ShipArt built outside the tree — in place of
## the art drawn so far, which goes; as visible as that was.
func _wear(dressed: ShipArt) -> void:
	if dressed == _art:
		return
	var at := _art.get_index()
	dressed.visible = _art.visible
	_ship.remove_child(_art)
	_art.queue_free()
	_ship.add_child(dressed)
	_ship.move_child(dressed, at)
	_art = dressed


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


## The bodies in water the water's rings are drawn round (water.gdshader, waders): of
## those whose world [param feet] stand more than CellMap.DRY under the world height of
## the water they are in, [param water_heights] — the same index — the [param max_count]
## nearest [param eye], nearest first, each its foot point on that water and how fast it
## moves, [param speeds] clamped to 0…1. A dry body leaves none — one on the floor of a
## dry cell, whose level is that floor, included.
static func waders(
	feet: PackedVector3Array,
	water_heights: PackedFloat32Array,
	speeds: PackedFloat32Array,
	eye: Vector3,
	max_count: int
) -> PackedVector4Array:
	var wet: Array[Vector2] = []
	for index in feet.size():
		if water_heights[index] - feet[index].y > CellMap.DRY:
			wet.append(Vector2(eye.distance_squared_to(feet[index]), index))
	wet.sort()
	var found := PackedVector4Array()
	for near: Vector2 in wet.slice(0, max_count):
		var index := int(near.y)
		var at := feet[index]
		found.append(Vector4(at.x, water_heights[index], at.z, clampf(speeds[index], 0.0, 1.0)))
	return found


## [param water_heights] with every body in the other water standing in none (waders):
## those in a cell — [param in_cell], the same index — for the sea, or, given
## [param cells], those in the sea for her cells. So the sea rings only round the bodies
## in it and a cell's water only round those in a cell, never across her side.
static func water_of(
	water_heights: PackedFloat32Array, in_cell: PackedByteArray, cells: bool
) -> PackedFloat32Array:
	var kept := water_heights.duplicate()
	for index in kept.size():
		if (in_cell[index] != 0) != cells:
			kept[index] = -INF
	return kept


## The bodies in the sea as drawn this tick, nearest the eye first (waders): rings round
## each on the sea it stands or swims in. Worked out once a tick.
func waders_drawn() -> PackedVector4Array:
	return _waders


## Where [param seat] is drawn, in the world.
func seat_world_position(seat: int) -> Vector3:
	return _bodies[seat].global_position


## Where [param seat]'s feet are drawn, in the space of its piece of her: her ship space
## while she is whole.
func seat_feet(seat: int) -> Vector3:
	return _feet[seat]


## How tall [param seat] is where it is drawn: a crawler's crawl_height, anyone else's
## body_height.
func seat_height(seat: int) -> float:
	return _heights[seat]


## How tall a body with its feet at [param feet] in her ship space stands, upright:
## where an eye stood in ship space looks from.
func height_at(feet: Vector3) -> float:
	return _rules.height_at(_faces.surfaces(Faces.Up.DECK), feet)


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


## What lights [param eye], in the world (ShipPower.Power): its cell's lamps' power,
## or outside her the sky's (ShipPose.lit_at).
func lit_at(eye: Vector3) -> int:
	return _eye_pose().lit_at(_eye_world().affine_inverse() * eye)


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
		lerpf(previous["tick"], current["tick"], alpha), current["railing_hp"], pose_then, alpha
	)
	_show_props(previous, current, alpha)
	_bonus_greybox.show_bonuses(current)
	var seats_then: Array = previous["seats"]
	var seats_now: Array = current["seats"]
	var carried := {}
	var entries: Array = current["props"]
	for index: int in _holdable:
		var holder: int = entries[index]["holder"]
		if holder != -1:
			carried[holder] = index
	var wading: bool = current["tick"] != _waders_tick
	var wet_feet := PackedVector3Array()
	var wet_water := PackedFloat32Array()
	var wet_speeds := PackedFloat32Array()
	var wet_in_cell := PackedByteArray()
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
		if wading:
			var in_water := pose_now.of_piece(piece)
			var foot := global_transform * world * pos
			var water := in_water.water_level(pos)
			if now["state"] == PlayerState.Body.SWIMMING:
				foot.y = minf(foot.y, water - 2.0 * CellMap.DRY)
			var vel: Vector3 = now["vel"]
			wet_in_cell.append(1 if in_water.cell_at(pos) != CellMap.NONE else 0)
			wet_feet.append(foot)
			wet_water.append(water)
			wet_speeds.append(Vector2(vel.x, vel.z).length() / _rules.walk_speed)
		_facings[seat] = (
			now["facing"] if turned else lerp_angle(then["facing"], now["facing"], alpha)
		)
		var placed := (
			_ship.transform.affine_inverse() * world if piece != 0 else Transform3D.IDENTITY
		)
		body.transform = placed * Transform3D(to_ship * Basis(Vector3.UP, -_facings[seat]), pos)
		var feet := to_ship.transposed() * pos
		var below := here.landing(feet)
		_heights[seat] = _rules.height_on(here, feet, below)
		# Posed even unseen, through its eyes: the hands of a body drawn reaching for it
		# stop at its guard (Brawler.keep_apart).
		body.show_state(then, now, alpha, _heights[seat] < _rules.body_height)
		var bonus: int = now["bonus"]
		body.wear_bonus(_bonus_kinds[bonus] if bonus != -1 else null)
		if carried.has(seat):
			body.carry(_drawn(carried[seat]), _layout.props[carried[seat]].radius)
		if not body.visible:
			continue
		# A swimmer stands on nothing: no ring tilted to a deck under the sea, no shadow.
		if now["state"] == PlayerState.Body.SWIMMING:
			below = Surfaces.NONE
		var normal := Vector3.UP if below == Surfaces.NONE else _ground_normal(here, below, feet)
		body.show_ground(placed.basis * (to_ship * normal))
		if below != Surfaces.NONE:
			var ground := here.height_at(below, feet)
			_shadows[seat].visible = true
			_shadows[seat].transform = (
				placed
				* Transform3D(to_ship, to_ship * Vector3(feet.x, ground + SHADOW_LIFT, feet.z))
			)
	Brawler.keep_apart(_bodies, _eye_seat)
	if wading:
		_show_waders(current["tick"], wet_feet, wet_water, wet_speeds, wet_in_cell)


## Works out the bodies in water as of [param tick] from where each seat in the match
## stands — [param feet], the [param water] it is in, whether in a cell's — [param in_cell]
## — or the sea's, and how fast it moves, [param speeds] as a share of walk_speed —
## nearest the eye drawing them: those in the sea for the sea (waders_drawn), those in
## her cells handed to her water.
func _show_waders(
	tick: int,
	feet: PackedVector3Array,
	water: PackedFloat32Array,
	speeds: PackedFloat32Array,
	in_cell: PackedByteArray
) -> void:
	_waders_tick = tick
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3.ZERO
	_waders = waders(feet, water_of(water, in_cell, false), speeds, eye, MAX_WADERS)
	var inside := waders(feet, water_of(water, in_cell, true), speeds, eye, MAX_WADERS)
	if _broken:
		_drawn_pieces.show_waders(inside)
	elif _inner != null:
		_inner.show_waders(inside)


## Hands the ship drawn what the schedule's events have done by [param tick] —
## fractional, as the view interpolates between two snapshots: the platforms whose
## collapse is telegraphed and whether the blink is lit now, how far (0…1) each
## collapsed platform has fallen, by name, and the failed railings — with them those
## the match has broken, as the snapshot's [param railing_hp] has them — and, dressed,
## what lights each cell, the glass broken and how far each funnel has fallen (SH31). A
## hull that breaks has each piece drawn as its own pose has it, [param then] the pose
## [param alpha] of the way from (ShipPieces).
func _show_sinking(
	tick: float, railing_hp: PackedFloat64Array, then: ShipPose, alpha: float
) -> void:
	var now := floori(tick)
	var pose := _schedule.pose_at(now)
	if now != _sinking_tick or railing_hp != _sinking_hp:
		_sinking_tick = now
		_sinking_hp = railing_hp
		_collapses.clear()
		for scheduled: SinkSchedule.Scheduled in _schedule.fired(now):
			if scheduled.event.kind == SinkEvent.Kind.COLLAPSE:
				_collapses.append(scheduled)
		_gone = pose.broken_railings.duplicate()
		_gone.append_array(MatchState.broken_in(railing_hp))
	var fallen := {}
	for scheduled: SinkSchedule.Scheduled in _collapses:
		var since := (tick - scheduled.at) * Ticks.SECONDS_PER_TICK
		fallen[scheduled.event.platform] = clampf(since / FALL_SECONDS, 0.0, 1.0)
	var lit := now / BLINK_TICKS % 2 == 0
	if _broken:
		_drawn_pieces.show_pieces(then, pose, alpha, tick, pose.collapsing, fallen, _gone, lit)
	elif _greybox.visible:
		_greybox.show_sinking(pose.collapsing, fallen, _gone, lit)
		_greybox.show_power(pose)
		_greybox.show_falls(pose.falls, tick)
	else:
		_art.show_sinking(pose.collapsing, fallen, _gone, lit)
		_art.show_power(pose)
		_art.show_falls(pose.falls, tick)


## Each prop [param alpha] of the way from where snapshot [param then] draws it to where
## [param now] does (PropPlacing), and hidden once it is lost. One the two hold alike —
## not afloat, where it bobs, nor held, where it goes as its holder looks — and drawn so
## last is left as it is: a laid saloon at rest costs a frame next to nothing, STILL_RUN
## props at a time asked whether they are as drawn.
func _show_props(then: Dictionary, now: Dictionary, alpha: float) -> void:
	var then_props: Array = then["props"]
	var now_props: Array = now["props"]
	for first in range(0, now_props.size(), STILL_RUN):
		var last := mini(first + STILL_RUN, now_props.size())
		var drawn := _still.slice(first, last)
		if now_props.slice(first, last) != drawn or then_props.slice(first, last) != drawn:
			_show_props_of(then, now, alpha, first, last)


## Props [param first] to [param last] of _show_props', one by one.
func _show_props_of(then: Dictionary, now: Dictionary, alpha: float, first: int, last: int) -> void:
	var height := _rules.railing_height
	var then_props: Array = then["props"]
	var now_props: Array = now["props"]
	for index in range(first, last):
		var entry: Dictionary = now_props[index]
		var before: Dictionary = then_props[index]
		var state: PropState.Body = entry["state"]
		var still := (
			entry == before and state != PropState.Body.FLOATING and state != PropState.Body.HELD
		)
		if still and _still[index] == entry:
			continue
		_still[index] = entry if still else null
		var shown := state != PropState.Body.LOST
		var placed := Transform3D.IDENTITY
		if shown:
			var was := PropPlacing.of(before, _layout, height, then["seats"], then["tick"])
			var drawn := PropPlacing.of(entry, _layout, height, now["seats"], now["tick"])
			placed = was.interpolate_with(drawn, alpha)
		if _prop_art != null:
			_prop_art.place(index, placed, shown)
		else:
			_props[index].visible = shown
			_props[index].transform = placed


## Where prop [param index] is drawn now, in the world.
func _drawn(index: int) -> Transform3D:
	return _prop_art.drawn(index) if _prop_art != null else _props[index].global_transform


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
