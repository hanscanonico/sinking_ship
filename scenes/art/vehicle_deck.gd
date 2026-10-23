class_name VehicleDeck
extends RefCounted
## A ferry's vehicle deck (RoomDressing.Kind.VEHICLE): bare painted steel for the cars it
## carries — none aboard tonight — lined in riveted bulkhead steel over a green-grey deck
## (linings()). Down its length the yellow lines of its lanes, LANE apart, broken round
## every stair up from it or down through it, each stair kept clear inside a yellow box,
## and its lashing points along them; up the linings of its sides stiffeners, a red fire
## hose box every FIRE_HOSE_SPACING, and its notices — NO SMOKING towards either end, and
## amidships that no passenger is to stay on it at sea. All of it flat: on the deck no
## prouder than PAINT, under a step; on the walls no deeper than a wall fitting
## (FurnishingCheck.TOLERANCE), so nothing it draws stands where a body does.

## A lane's breadth between its lines, a line's width, and how far the lines stay off the
## walls; how proud of the deck the paint stands.
const LANE := 2.7
const LINE := 0.1
const LINE_OFF_WALL := 0.9
const PAINT := 0.004
## How far round a stair its keep-clear box runs, and how far apart a line is tried
## along it for the deck under it; a line no shorter is drawn.
const KEEP_CLEAR := 0.4
const STEP := 0.2
const SHORTEST := 0.6
## A lashing point every LASHING along a line, LASHING_OFF either side of it, and its
## radius.
const LASHING := 2.4
const LASHING_OFF := 0.45
const LASHING_RADIUS := 0.06
## The stiffeners up the linings of its sides: how far apart, and their section, along
## the wall and out from it.
const STIFFENER_PITCH := 0.75
const STIFFENER := Vector2(0.06, 0.07)
## A fire hose box: how far apart along a side at most, its size along the wall, up it
## and out from it, and its middle's height over the deck.
const FIRE_HOSE_SPACING := 12.0
const FIRE_HOSE := Vector3(0.6, 0.75, 0.1)
const FIRE_HOSE_HEIGHT := 1.35
## The notices: their letters' size, how high their middle stands over the deck, and how
## far in from a side's ends the NO SMOKING ones hang.
const NOTICE_FONT := 56
const NOTICE_HEIGHT := 2.4
const NOTICE_IN := 4.0
const NO_SMOKING := "NO SMOKING"
const AT_SEA := "PASSENGERS MUST NOT REMAIN\nON THE CAR DECK AT SEA"

var _space: ShipSpace
var _layout: ShipLayout
var _cut_above: float


func _init(space: ShipSpace, cut_above := INF) -> void:
	_space = space
	_layout = space.layout
	_cut_above = cut_above


## What a vehicle deck lines its walls, floor, ceiling and beams with (RoomDressing.Part):
## riveted bulkhead steel, its own painted steel deck, plating and steel beams overhead.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	paints.assign(
		[ShipPaints.bulkhead, ShipPaints.car_deck, ShipPaints.steel_overhead, ShipPaints.steel_beam]
	)
	return paints


## [param room]'s own, into [param mesh], its notices' letters under [param signs].
func build(mesh: ShipMesh, signs: Node3D, room: ShipRoom) -> void:
	var stairs := stairs_of(room)
	for z: float in lines(room):
		var from := Vector2(room.area.position.x + LINE_OFF_WALL, z)
		var to := Vector2(room.area.end.x - LINE_OFF_WALL, z)
		for run: Vector2 in runs(room, stairs, from, to):
			var a := from.lerp(to, run.x / from.distance_to(to))
			var b := from.lerp(to, run.y / from.distance_to(to))
			_paint(mesh, room, a, b)
			_lashings(mesh, room, stairs, a, b)
	for stair: Rect2 in stairs:
		_keep_clear(mesh, room, stairs, stair.grow(KEEP_CLEAR))
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.length() < 2.0 or not wall.outdoors_beyond():
			continue
		var along := Vector2(wall.from + 0.3, wall.to - 0.3)
		for run: Vector2 in RoomDressing.clear_of_stairs(
			_layout, wall, along, EngineRoom.STAIR_REACH
		):
			_stiffeners(mesh, wall, run)
			_fire_hoses(mesh, wall, run)
		_notices(mesh, signs, wall)


## The ship-plane areas of [param room]'s stairs, every ramp with an end at its floor
## and its middle over it: those up from it and those down through it.
func stairs_of(room: ShipRoom) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for ramp: ShipRamp in _layout.ramps:
		var ends := [ramp.start_height, ramp.end_height]
		var at_floor := ends.any(
			func(height: float) -> bool: return absf(height - room.floor_height) < 0.05
		)
		if at_floor and room.area.has_point(ramp.area.get_center()):
			found.append(ramp.area)
	return found


## The heights along [param room]'s breadth, z, its lane lines run at: LANE apart from
## its middle, LINE_OFF_WALL and more off its sides.
static func lines(room: ShipRoom) -> PackedFloat32Array:
	var middle := room.area.get_center().y
	var reach := room.area.size.y * 0.5 - LINE_OFF_WALL
	var found := PackedFloat32Array()
	var count := floori(reach / LANE)
	for k in range(-count, count + 1):
		found.append(middle + k * LANE)
	return found


## The stretches of the line from [param from] to [param to] — distances along it — over
## [param room]'s deck (on_deck()), each SHORTEST or longer.
func runs(room: ShipRoom, stairs: Array[Rect2], from: Vector2, to: Vector2) -> Array[Vector2]:
	var length := from.distance_to(to)
	var count := maxi(1, ceili(length / STEP))
	var found: Array[Vector2] = []
	var start := NAN
	for i in count + 1:
		var along := length * i / count
		var on := on_deck(room, stairs, from.lerp(to, float(i) / count))
		if on and is_nan(start):
			start = along
		if (not on or i == count) and not is_nan(start):
			var end := along if on else length * (i - 1) / count
			if end - start >= SHORTEST:
				found.append(Vector2(start, end))
			start = NAN
	return found


## Whether ship-plane point [param at] is [param room]'s deck to paint: a platform at its
## floor's height under it, clear of every one of [param stairs] by KEEP_CLEAR — its box's
## line runs there — and of everything standing on that floor.
func on_deck(room: ShipRoom, stairs: Array[Rect2], at: Vector2) -> bool:
	var floor := room.floor_height
	var under := false
	for platform: ShipPlatform in _layout.platforms:
		if absf(platform.height - floor) < 0.05 and platform.contains(at.x, at.y):
			under = true
			break
	if not under:
		return false
	for stair: Rect2 in stairs:
		if stair.grow(KEEP_CLEAR + LINE).has_point(at):
			return false
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.bottom > floor + 0.05 or blocker.top <= floor + 0.05:
			continue
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			if at.distance_to(blocker.centre) <= blocker.radius + LINE:
				return false
		elif blocker.area.grow(LINE).has_point(at):
			return false
	return true


## A line of lane paint from [param a] to [param b] on [param room]'s deck.
func _paint(mesh: ShipMesh, room: ShipRoom, a: Vector2, b: Vector2) -> void:
	var area := Rect2(a, Vector2.ZERO).expand(b).grow(LINE * 0.5)
	RoomDressing.block(mesh, area, room.floor_height, room.floor_height + PAINT, ShipPaints.lane)


## The lashing points along the line from [param a] to [param b]: one LASHING_OFF either
## side of it every LASHING, where the deck is under it.
func _lashings(
	mesh: ShipMesh, room: ShipRoom, stairs: Array[Rect2], a: Vector2, b: Vector2
) -> void:
	var length := a.distance_to(b)
	var along := (b - a) / length
	var across := Vector2(-along.y, along.x)
	var count := floori(length / LASHING)
	for k in count + 1:
		var on_line := a + along * (length - count * LASHING) * 0.5 + along * k * LASHING
		for side: float in [-1.0, 1.0]:
			var at := on_line + across * side * LASHING_OFF
			if not on_deck(room, stairs, at):
				continue
			var centre := Vector3(at.x, room.floor_height + PAINT, at.y)
			RoomDressing.disc(mesh, centre, Vector3.UP, LASHING_RADIUS, ShipPaints.dark, 8)


## A yellow box round [param area], a stair's kept clear, where the deck is under it.
func _keep_clear(mesh: ShipMesh, room: ShipRoom, stairs: Array[Rect2], area: Rect2) -> void:
	var corners: Array[Vector2] = [
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y),
	]
	var others: Array[Rect2] = []
	for stair: Rect2 in stairs:
		if not stair.grow(KEEP_CLEAR).is_equal_approx(area):
			others.append(stair)
	for index in 4:
		var from := corners[index]
		var to := corners[(index + 1) % 4]
		for run: Vector2 in runs(room, others, from, to):
			var a := from.lerp(to, run.x / from.distance_to(to))
			var b := from.lerp(to, run.y / from.distance_to(to))
			_paint(mesh, room, a, b)


## The stiffeners up [param wall] along [param run], STIFFENER_PITCH apart, floor to
## deckhead.
func _stiffeners(mesh: ShipMesh, wall: RoomDressing.Wall, run: Vector2) -> void:
	var count := floori((run.y - run.x) / STIFFENER_PITCH)
	for k in count + 1:
		var along := run.x + (run.y - run.x - count * STIFFENER_PITCH) * 0.5 + k * STIFFENER_PITCH
		var foot := wall.at(along, 0.0)
		var top := _space.ceiling(wall.room, foot.x, foot.z) - ShipArt.PLANK
		var half := STIFFENER.x * 0.5
		var area := wall.rect(along - half, along + half, 0.0, STIFFENER.y)
		RoomDressing.block(mesh, area, wall.floor, top, ShipPaints.bulkhead)


## A red fire hose box on [param wall] in the middle of every FIRE_HOSE_SPACING of
## [param run], a white plate on its face.
func _fire_hoses(mesh: ShipMesh, wall: RoomDressing.Wall, run: Vector2) -> void:
	var count := floori((run.y - run.x) / FIRE_HOSE_SPACING)
	for k in count:
		var along := lerpf(run.x, run.y, (k + 0.5) / count)
		var half := FIRE_HOSE.x * 0.5
		var area := wall.rect(along - half, along + half, 0.0, FIRE_HOSE.z)
		var low := wall.floor + FIRE_HOSE_HEIGHT - FIRE_HOSE.y * 0.5
		RoomDressing.block(
			mesh, area, low, low + FIRE_HOSE.y, ShipPaints.fire_bucket, ShipMesh.RIM_ALL
		)
		var plate := wall.at(along, FIRE_HOSE_HEIGHT + FIRE_HOSE.y * 0.3, FIRE_HOSE.z + 0.002)
		RoomDressing.panel(
			mesh, plate, wall.right, Vector2(0.2, 0.06), wall.normal, ShipPaints.enamel
		)


## [param wall]'s notices, under [param signs]: on a side long enough, NO SMOKING
## NOTICE_IN from either end, and amidships that passengers are not to stay on it at sea.
func _notices(mesh: ShipMesh, signs: Node3D, wall: RoomDressing.Wall) -> void:
	if wall.length() < NOTICE_IN * 2.0 + 4.0:
		return
	_notice(mesh, signs, wall, wall.from + NOTICE_IN, NO_SMOKING, ArtPalette.NOTICE_RED)
	_notice(mesh, signs, wall, wall.to - NOTICE_IN, NO_SMOKING, ArtPalette.NOTICE_RED)
	_notice(mesh, signs, wall, wall.middle(), AT_SEA, ArtPalette.INK)


## A notice reading [param text] in [param ink] on a white enamel plate rimmed in red,
## flat on [param wall] at [param along], NOTICE_HEIGHT over the deck: its letters under
## [param signs], gone as a jumping eye comes near, as RoomDressing's door signs are.
func _notice(
	mesh: ShipMesh, signs: Node3D, wall: RoomDressing.Wall, along: float, text: String, ink: Color
) -> void:
	var font := ThemeDB.fallback_font
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, NOTICE_FONT)
	var half := size * RoomDressing.SIGN_PIXEL * 0.5 + Vector2(0.08, 0.06)
	var centre := wall.at(along, NOTICE_HEIGHT)
	var red := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.NOTICE_RED)
	var rim := half + Vector2.ONE * 0.025
	RoomDressing.panel(mesh, centre + wall.normal * 0.01, wall.right, rim, wall.normal, red)
	var plate := centre + wall.normal * 0.014
	RoomDressing.panel(mesh, plate, wall.right, half, wall.normal, ShipPaints.enamel)
	var letters := Label3D.new()
	letters.text = text
	letters.font_size = NOTICE_FONT
	letters.pixel_size = RoomDressing.SIGN_PIXEL
	letters.modulate = ink
	letters.outline_size = 0
	letters.shaded = true
	letters.double_sided = false
	letters.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	letters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	letters.visibility_range_begin = (RoomDressing.NEAR_FADE.x + RoomDressing.NEAR_FADE.y) * 0.5
	letters.basis = Basis.looking_at(-wall.normal)
	letters.position = centre + wall.normal * 0.02
	letters.visible = centre.y < _cut_above
	signs.add_child(letters)
