class_name LinerService
extends RefCounted
## A ship's rooms of service (RoomDressing.Kind.SERVICE), each by what its name says,
## every one lined in white glazed tile over a red quarry-tile floor.
## A galley — the liner's and the trawler's alike, scaled to the room — with a course
## of blue tile round its walls, a rack of pots and pans hung over HEADROOM along each
## full wall, a dresser of plates flat on each wall with a clear stretch for one, and
## fire buckets on a shelf overhead. A gymnasium on linoleum, with wall bars between
## the windows of one long wall, a tall mirror on the other, a notice board, a brass
## plaque and a clock beside it, and curtains at its windows. An office — the purser's,
## the post office — on linoleum, with pigeonhole racks along its walls, a clock and a
## notice board, and in the post office a row of mail sacks on hooks overhead.
## No range, hot press or counter stands out in a room: a body would walk through it,
## and none has a blocker to stand in yet (D6) — blocks() is where they will be drawn
## once the layout gives them one.
## Between a step over the floor and a body's height, nothing it draws stands more than
## FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m) anything
## may, and fades near the eye (RoomDressing.overhead()) — art-lint holds it to that,
## and no blocker is ever widened to hide a piece (D6). Nothing is drawn beside a stair.

const FINISH := ShipMesh.Finish
const HEADROOM := RoomDressing.HEADROOM
const PIECE := RoomDressing.PIECE
## The colours of a room of service: glazed white tile, its blue course, red quarry
## tile underfoot; linoleum; tinned and copper pans; cork and paper.
const TILE := Color("e4e2d8")
const TILE_COURSE := Color("3f5d80")
const QUARRY := Color("8a4a36")
const LINOLEUM := Color("6b5a43")
const TIN := Color("9da3a6")
const COPPER := Color("b06a3e")
const CORK := Color("a4794f")
const PAPER := Color("e8e1cc")
## How far out from its wall a fitting flat on it stands at most, and the gymnasium's
## wall bars.
const FLAT := 0.11
const BARS := 0.08
## How far over its floor linoleum is laid.
const LINOLEUM_DEPTH := 0.006
## The galley's rack overhead: how far out its bar hangs, how high over HEADROOM at
## most, and the stretch along it one bay of three pieces fills at most.
const RACK_OUT := 0.28
const RACK_TOP := 0.4
const RACK_BAY := 1.5
## How high the blue course of tile runs round a galley, and how deep it is.
const COURSE := Vector2(1.7, 0.05)
## A dresser's plate rack: from and to how high over the floor, and its widest.
const DRESSER := Vector2(0.95, 1.8)
const DRESSER_WIDTH := 1.8
## A bay of wall bars: how wide, how many at most, how far apart its rungs.
const BAR_BAY := 0.6
const BAR_BAYS := 4
const RUNG := 0.15
## A pigeonhole rack: from and to how high over the floor, its widest, and one hole.
const PIGEONHOLES := Vector2(0.95, 1.75)
const PIGEONHOLE_WIDTH := 2.4
const HOLE := Vector2(0.24, 0.2)
## How far apart the post office's mail sacks hang.
const SACK_SPACING := 0.55

static var tile := ShipMesh.Paint.new(FINISH.HOUSE, ArtPalette.HOUSE, FINISH.PLAIN, TILE)
static var quarry := ShipMesh.Paint.new(FINISH.DECK, ArtPalette.DECK, FINISH.PLAIN, QUARRY)
static var course := ShipMesh.Paint.new(FINISH.PLAIN, TILE_COURSE)
static var linoleum := ShipMesh.Paint.new(FINISH.PLAIN, LINOLEUM)
static var tin := ShipMesh.Paint.new(FINISH.PLAIN, TIN)
static var copper := ShipMesh.Paint.new(FINISH.PLAIN, COPPER)
static var cork := ShipMesh.Paint.new(FINISH.PLAIN, CORK)
static var paper := ShipMesh.Paint.new(FINISH.PLAIN, PAPER)

var _space: ShipSpace
var _cabins: CabinDressing


func _init(space: ShipSpace, cabins: CabinDressing) -> void:
	_space = space
	_cabins = cabins


## Whether [param room], a room of service, is an office: what its name says.
static func office(room: ShipRoom) -> bool:
	return String(room.name).to_lower().contains("office")


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var name := String(room.name).to_lower()
	if name.contains("galley"):
		_galley(mesh, room, glass)
	elif name.contains("gymnasium"):
		_gymnasium(mesh, room, glass)
	elif office(room):
		_office(mesh, room, glass, name.contains("post"))
	blocks(mesh, room)


## What stands on [param room]'s BOX blockers, into [param mesh]: a galley's range
## and hot press, an office's counter. Nothing yet: the layout gives them no blocker,
## and nothing a body would walk through is drawn (D6).
func blocks(_mesh: ShipMesh, _room: ShipRoom) -> void:
	pass


## The lights [param room] is lit by; none keeps RoomDressing's pendants.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a room of service lines its walls, floor, ceiling and beams with
## (RoomDressing.Part): white tile over red quarry tile under the ship's own overhead.
## A gymnasium's and an office's linoleum is laid over it (_linoleum_floor()).
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = [tile, quarry, null, null]
	return paints


## A galley: a course of blue tile round it clear of its glass, a rack of pans over
## every full wall — but over the fire buckets' shelf at the start of the longest one
## clear of a stair — and a dresser on the widest stretch clear of glass of each wall
## between it and another room; of all its walls, when none is.
func _galley(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var around := RoomDressing.walls(_space, room)
	var buckets: RoomDressing.Wall = null
	for wall: RoomDressing.Wall in around:
		if wall.length() < 2.0 or _beside_a_stair(wall, wall.from, wall.from + 1.2):
			continue
		if buckets == null or wall.length() > buckets.length():
			buckets = wall
	var inside := around.filter(
		func(wall: RoomDressing.Wall) -> bool: return not wall.outdoors_beyond()
	)
	var best: RoomDressing.Wall = null
	var best_span := Vector2.ZERO
	for wall: RoomDressing.Wall in around:
		for span: Vector2 in _clear_spans(wall, glass, true):
			_band(mesh, wall, span, COURSE, course)
		var start := wall.from + 0.2
		if wall == buckets:
			RoomDressing.fire_buckets(mesh, wall, wall.from + 0.55)
			start = wall.from + 1.2
		_pan_rack(mesh, wall, start, wall.to - 0.2)
		var widest := _widest(_clear_spans(wall, glass, false))
		if inside.has(wall):
			_dresser(mesh, wall, widest)
		elif inside.is_empty() and widest.y - widest.x > best_span.y - best_span.x:
			best = wall
			best_span = widest
	if best != null:
		_dresser(mesh, best, best_span)


## A rack of pots and pans along [param wall] from [param from] to [param to], all
## over HEADROOM, bay by bay: a bar out from the wall on a bracket, a copper pan, a
## tinned pot and a ladle hanging from it — no bay beside a stair, nor where the
## ceiling leaves no room under it.
func _pan_rack(mesh: ShipMesh, wall: RoomDressing.Wall, from: float, to: float) -> void:
	if to - from < RACK_BAY * 0.5:
		return
	var bays := maxi(1, floori((to - from) / RACK_BAY))
	var bay := (to - from) / bays
	for index in bays:
		var a := from + bay * index
		var b := a + bay
		if _beside_a_stair(wall, a, b):
			continue
		var top := minf(HEADROOM + RACK_TOP, _headroom(wall, (a + b) * 0.5) - 0.12)
		if top - HEADROOM < 0.25:
			continue
		var bar := wall.rect(a, b, RACK_OUT - 0.015, RACK_OUT + 0.015)
		RoomDressing.block(mesh, bar, wall.floor + top - 0.03, wall.floor + top, ShipPaints.steel)
		# A bracket to the wall at every other bay's start, and the last's end.
		for at: float in [
			a + 0.05 if index % 2 == 0 else NAN, b - 0.05 if index == bays - 1 else NAN
		]:
			if not is_nan(at):
				var bracket := wall.rect(at - 0.015, at + 0.015, 0.0, RACK_OUT + 0.015)
				RoomDressing.block(
					mesh, bracket, wall.floor + top, wall.floor + top + 0.03, ShipPaints.steel
				)
		var hang := top - 0.03
		var drop := hang - HEADROOM - 0.02
		for item in 3:
			var along := a + bay * (item + 0.5) / 3.0
			match item:
				0:
					_pan(mesh, wall, along, hang, minf(0.12, (drop - 0.07) * 0.5))
				1:
					_pot(mesh, wall, along, hang, minf(0.15, drop - 0.04))
				2:
					_ladle(mesh, wall, along, hang, drop)


## A copper pan of [param radius] hanging face out by its handle from a bar
## [param from] over the floor at [param along] on [param wall].
func _pan(
	mesh: ShipMesh, wall: RoomDressing.Wall, along: float, from: float, radius: float
) -> void:
	if radius < 0.05:
		return
	var hook := wall.at(along, from, RACK_OUT + 0.016)
	var handle := Vector2(0.015, 0.035)
	var grip := hook - Vector3.UP * handle.y
	RoomDressing.panel(mesh, grip, wall.right, handle, wall.normal, tin, 0)
	var centre := hook - Vector3.UP * (handle.y * 2.0 + radius)
	_fan(mesh, centre, wall.normal, radius, copper, 8)


## A tinned pot [param depth] deep hanging by its bail from a bar [param from] over
## the floor at [param along] on [param wall].
func _pot(mesh: ShipMesh, wall: RoomDressing.Wall, along: float, from: float, depth: float) -> void:
	if depth < 0.08:
		return
	var bail := wall.at(along, from, RACK_OUT + 0.016)
	var loop := bail - Vector3.UP * 0.02
	RoomDressing.panel(mesh, loop, wall.right, Vector2(0.06, 0.02), wall.normal, tin, 0)
	var top := wall.at(along, from - 0.04, RACK_OUT)
	var rim := PackedVector3Array()
	for index in 6:
		var turn := TAU * index / 6.0
		rim.append(top + Vector3(cos(turn), 0.0, sin(turn)) * 0.09)
	for index in 6:
		var a := rim[index]
		var b := rim[(index + 1) % 6]
		var down := Vector3.UP * depth
		var na := (a - top).normalized()
		var nb := (b - top).normalized()
		var side := PackedVector3Array([a - down, b - down, b, a])
		mesh.smooth_quad(side, PackedVector3Array([na, nb, nb, na]), tin)
		var lid := PackedVector3Array([a, b, top])
		mesh.triangle(lid, PackedFloat32Array([0.0, 0.0, 0.0]), Vector3.UP, tin)


## A ladle [param drop] long hanging from a bar [param from] over the floor at
## [param along] on [param wall].
func _ladle(
	mesh: ShipMesh, wall: RoomDressing.Wall, along: float, from: float, drop: float
) -> void:
	if drop < 0.12:
		return
	var hook := wall.at(along, from, RACK_OUT + 0.016)
	var stem := Vector2(0.008, (drop - 0.08) * 0.5)
	RoomDressing.panel(mesh, hook - Vector3.UP * stem.y, wall.right, stem, wall.normal, tin, 0)
	_fan(mesh, hook - Vector3.UP * (drop - 0.045), wall.normal, 0.04, tin, 6)


## A dresser's plate rack flat on [param wall] in the middle of [param span] along
## it, DRESSER_WIDTH wide at most, from DRESSER.x to DRESSER.y over the floor and FLAT
## deep: a back board between two posts under a cornice, three shelves of plates stood
## on edge behind a rail. None where the span is too narrow for one.
func _dresser(mesh: ShipMesh, wall: RoomDressing.Wall, span: Vector2) -> void:
	var width := minf(DRESSER_WIDTH, span.y - span.x - 0.2)
	if width < 0.8:
		return
	var along := (span.x + span.y) * 0.5
	var a := along - width * 0.5
	var b := along + width * 0.5
	var floor := wall.floor
	var back := wall.at(along, (DRESSER.x + DRESSER.y) * 0.5, 0.006)
	var half := Vector2(width * 0.5, (DRESSER.y - DRESSER.x) * 0.5)
	RoomDressing.panel(mesh, back, wall.right, half, wall.normal, ShipPaints.teak)
	for post: float in [a, b - 0.04]:
		var side := wall.rect(post, post + 0.04, 0.0, FLAT)
		RoomDressing.block(mesh, side, floor + DRESSER.x, floor + DRESSER.y, ShipPaints.frame)
	var cornice := wall.rect(a - 0.02, b + 0.02, 0.0, FLAT)
	RoomDressing.block(mesh, cornice, floor + DRESSER.y - 0.04, floor + DRESSER.y, ShipPaints.frame)
	var plates := floori((width - 0.12) / 0.2)
	var first := a + 0.06 + (width - 0.12 - plates * 0.2) * 0.5
	for shelf in 3:
		var low := DRESSER.x + shelf * 0.28
		var board := wall.rect(a + 0.04, b - 0.04, 0.0, FLAT - 0.01)
		RoomDressing.block(mesh, board, floor + low, floor + low + 0.02, ShipPaints.frame)
		for plate in plates:
			var centre := wall.at(first + 0.2 * (plate + 0.5), low + 0.11, 0.04)
			var paint := ShipPaints.enamel if (plate + shelf) % 3 != 0 else course
			_fan(mesh, centre, wall.normal, 0.085, paint, 8)
		var rail := wall.rect(a + 0.04, b - 0.04, FLAT - 0.015, FLAT - 0.005)
		RoomDressing.block(mesh, rail, floor + low + 0.07, floor + low + 0.085, ShipPaints.frame)


## A gymnasium: linoleum underfoot; wall bars between the windows of the long wall
## with the most glass; a tall mirror on the other's widest stretch clear of glass,
## a notice board, a brass plaque and a clock on its next; curtains at its windows.
func _gymnasium(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	_linoleum_floor(mesh, room)
	var curtain := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.SALOON_CURTAIN)
	for pane: Array in glass:
		if not pane[3]:
			CabinDressing.curtains(mesh, pane[1], pane[2], curtain)
	var long := 0 if room.area.size.x >= room.area.size.y else 1
	var panes := PackedInt32Array([0, 0, 0, 0])
	for pane: Array in glass:
		for side in 4:
			if _on_side(room, side, pane):
				panes[side] += 1
	var bars := long if panes[long] >= panes[long + 2] else long + 2
	var stretches: Array[Vector2] = []
	var on: Array[RoomDressing.Wall] = []
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.side == bars:
			_wall_bars(mesh, wall, glass)
		elif wall.side == (bars + 2) % 4:
			for span: Vector2 in _clear_spans(wall, glass, false):
				stretches.append(span)
				on.append(wall)
	var order := range(stretches.size())
	order.sort_custom(
		func(i: int, j: int) -> bool:
			return stretches[i].y - stretches[i].x > stretches[j].y - stretches[j].x
	)
	if order.size() > 0:
		var span := stretches[order[0]]
		var width := minf(1.4, span.y - span.x - 0.4)
		if width >= 0.6:
			_mirror(mesh, on[order[0]], (span.x + span.y) * 0.5, width)
	if order.size() > 1:
		var span := stretches[order[1]]
		var wall := on[order[1]]
		if span.y - span.x >= 1.6:
			var middle := (span.x + span.y) * 0.5
			_notice_board(mesh, wall, middle - 0.35)
			_plaque(mesh, wall, middle + 0.45)
			_clock(mesh, wall, middle - 0.35, minf(2.05, _headroom(wall, middle) - 0.25))


## Wall bars along [param wall], bay by bay between its [param glass] and clear of
## stairs, BAR_BAYS of them at most nearest its middle: an upright at each side of a
## bay from the floor to under the ceiling, rungs between them every RUNG, none
## standing out more than BARS.
func _wall_bars(mesh: ShipMesh, wall: RoomDressing.Wall, glass: Array[Array]) -> void:
	var bays: Array[float] = []
	var pitch := BAR_BAY + 0.02
	for span: Vector2 in _clear_spans(wall, glass, false, 0.03):
		var count := floori((span.y - span.x) / pitch)
		var first := (span.x + span.y - count * pitch) * 0.5
		for index in count:
			bays.append(first + (index + 0.5) * pitch)
	var middle := wall.middle()
	bays.sort_custom(func(a: float, b: float) -> bool: return absf(a - middle) < absf(b - middle))
	for bay: float in bays.slice(0, BAR_BAYS):
		var top := minf(2.3, _headroom(wall, bay) - 0.08)
		var a := bay - BAR_BAY * 0.5
		var b := bay + BAR_BAY * 0.5
		for upright: float in [a, b - 0.05]:
			var post := wall.rect(upright, upright + 0.05, 0.01, BARS)
			RoomDressing.block(mesh, post, wall.floor, wall.floor + top, ShipPaints.teak)
		var rung := RUNG
		while rung < top - 0.05:
			var bar := wall.rect(a + 0.05, b - 0.05, 0.03, 0.06)
			RoomDressing.block(
				mesh, bar, wall.floor + rung, wall.floor + rung + 0.03, ShipPaints.frame
			)
			rung += RUNG


## A tall mirror flat on [param wall] centred at [param along], [param width] wide,
## in a dark frame.
func _mirror(mesh: ShipMesh, wall: RoomDressing.Wall, along: float, width: float) -> void:
	var top := minf(2.15, _headroom(wall, along) - 0.1)
	var centre := wall.at(along, (0.9 + top) * 0.5, 0.01)
	var half := Vector2(width * 0.5, (top - 0.9) * 0.5)
	var rim := half + Vector2.ONE * 0.04
	RoomDressing.panel(mesh, centre, wall.right, rim, wall.normal, ShipPaints.frame)
	var glass := centre + wall.normal * 0.005
	RoomDressing.panel(mesh, glass, wall.right, half, wall.normal, ShipPaints.mirror, 0)


## A brass plaque flat on [param wall] at [param along], on a teak board, lettered.
func _plaque(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var centre := wall.at(along, 1.5, 0.008)
	RoomDressing.panel(mesh, centre, wall.right, Vector2(0.2, 0.14), wall.normal, ShipPaints.teak)
	var plate := centre + wall.normal * 0.004
	var brass := Vector2(0.16, 0.1)
	RoomDressing.panel(mesh, plate, wall.right, brass, wall.normal, ShipPaints.brass, 0)
	for line in 3:
		var at := plate + wall.normal * 0.003 + Vector3.UP * (0.05 - line * 0.05)
		var letters := Vector2(0.12 - line * 0.02, 0.008)
		RoomDressing.panel(mesh, at, wall.right, letters, wall.normal, ShipPaints.dark, 0)


## A notice board flat on [param wall] at [param along]: cork in a frame, papers
## pinned to it.
func _notice_board(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var centre := wall.at(along, 1.45, 0.01)
	var half := Vector2(0.3, 0.22)
	var rim := half + Vector2.ONE * 0.025
	RoomDressing.panel(mesh, centre, wall.right, rim, wall.normal, ShipPaints.frame)
	var board := centre + wall.normal * 0.004
	RoomDressing.panel(mesh, board, wall.right, half, wall.normal, cork, 0)
	var sheets: Array[Vector4] = [
		Vector4(-0.17, 0.08, 0.08, 0.1),
		Vector4(0.06, 0.1, 0.1, 0.07),
		Vector4(0.12, -0.1, 0.09, 0.09),
		Vector4(-0.12, -0.11, 0.07, 0.08),
	]
	for sheet: Vector4 in sheets:
		var at := board + wall.normal * 0.003 + wall.right * sheet.x + Vector3.UP * sheet.y
		var size := Vector2(sheet.z, sheet.w)
		RoomDressing.panel(mesh, at, wall.right, size, wall.normal, paper, 0)


## A clock flat on [param wall] at [param along], [param height] over the floor: a
## white face in a brass rim, and its hands.
func _clock(mesh: ShipMesh, wall: RoomDressing.Wall, along: float, height: float) -> void:
	var clock := wall.at(along, height, 0.03)
	var normal := wall.normal
	_fan(mesh, clock, normal, 0.13, ShipPaints.enamel, 12)
	RoomDressing.ring(mesh, clock + normal * 0.004, normal, 0.12, 0.15, ShipPaints.brass, 12)
	var hands := clock + normal * 0.008
	mesh.beam(hands, hands + Vector3.UP * 0.09, Vector2(0.012, 0.004), ShipPaints.dark, 0)
	var minute := hands + (wall.right * 0.7 - Vector3.UP * 0.4).normalized() * 0.07
	mesh.beam(hands, minute, Vector2(0.012, 0.004), ShipPaints.dark, 0)


## An office: linoleum underfoot; a pigeonhole rack on each wall's widest stretch
## clear of glass and stairs, a notice board under a clock beside the rack on its
## longest wall; in a post office, [param post], mail sacks on hooks overhead along
## its longest wall, and the board and clock on the next.
func _office(mesh: ShipMesh, room: ShipRoom, glass: Array[Array], post: bool) -> void:
	_linoleum_floor(mesh, room)
	var around := RoomDressing.walls(_space, room)
	if around.is_empty():
		return
	around.sort_custom(
		func(a: RoomDressing.Wall, b: RoomDressing.Wall) -> bool: return a.length() > b.length()
	)
	var sacks: RoomDressing.Wall = around[0] if post else null
	var board: RoomDressing.Wall = around[0]
	if post and around.size() > 1:
		board = around[1]
	for wall: RoomDressing.Wall in around:
		if wall == sacks:
			_mail_sacks(mesh, wall)
		var widest := _widest(_clear_spans(wall, glass, false))
		var room_for := widest.y - widest.x - 0.4
		if wall == board and wall != sacks and room_for >= 1.8:
			_notice_board(mesh, wall, widest.x + 0.5)
			_clock(mesh, wall, widest.x + 0.5, minf(2.05, _headroom(wall, widest.x) - 0.2))
			widest.x += 1.0
			room_for -= 1.0
		var width := minf(PIGEONHOLE_WIDTH, room_for)
		if width >= 0.6:
			_pigeonholes(mesh, wall, (widest.x + widest.y) * 0.5, width)


## A pigeonhole rack flat on [param wall] centred at [param along], about
## [param width] wide and FLAT deep: a back board, a grid of thin shelves and
## dividers, letters and parcels in some of its holes.
func _pigeonholes(mesh: ShipMesh, wall: RoomDressing.Wall, along: float, width: float) -> void:
	var columns := maxi(1, floori(width / HOLE.x))
	var rows := maxi(1, floori((PIGEONHOLES.y - PIGEONHOLES.x) / HOLE.y))
	var a := along - columns * HOLE.x * 0.5
	var b := along + columns * HOLE.x * 0.5
	var floor := wall.floor
	var top := PIGEONHOLES.x + rows * HOLE.y
	var back := wall.at(along, (PIGEONHOLES.x + top) * 0.5, 0.006)
	var half := Vector2(columns * HOLE.x * 0.5, (top - PIGEONHOLES.x) * 0.5)
	RoomDressing.panel(mesh, back, wall.right, half, wall.normal, ShipPaints.teak, 0)
	for column in columns + 1:
		var at := a + column * HOLE.x
		var divider := wall.rect(at - 0.01, at + 0.01, 0.0, FLAT - 0.01)
		RoomDressing.block(mesh, divider, floor + PIGEONHOLES.x, floor + top, ShipPaints.frame)
	for row in rows + 1:
		var low := PIGEONHOLES.x + row * HOLE.y - 0.01
		var shelf := wall.rect(a, b, 0.0, FLAT - 0.01)
		RoomDressing.block(mesh, shelf, floor + low, floor + low + 0.02, ShipPaints.frame)
	for column in columns:
		for row in rows:
			# Letters in some holes, a parcel in others, by turns.
			var fill := (column * 7 + row * 3) % 5
			if fill > 2:
				continue
			var middle := a + (column + 0.5) * HOLE.x
			var low := PIGEONHOLES.x + row * HOLE.y + 0.01
			var high: float = [0.04, 0.09, 0.13][fill]
			var stack := wall.at(middle, low + high * 0.5, 0.08)
			var paint := ShipPaints.chart if fill < 2 else ShipPaints.sacking
			var size := Vector2(0.08, high * 0.5)
			RoomDressing.panel(mesh, stack, wall.right, size, wall.normal, paint, 0)


## Mail sacks along [param wall], SACK_SPACING apart, each on its hook over HEADROOM
## from under the ceiling — none beside a stair, nor where the ceiling leaves no room
## for one.
func _mail_sacks(mesh: ShipMesh, wall: RoomDressing.Wall) -> void:
	var count := floori((wall.length() - 0.4) / SACK_SPACING)
	var first := wall.middle() - (count - 1) * SACK_SPACING * 0.5
	for index in count:
		var along := first + index * SACK_SPACING
		if _beside_a_stair(wall, along - 0.3, along + 0.3):
			continue
		var rail := minf(HEADROOM + 0.45, _headroom(wall, along) - 0.08)
		if rail - HEADROOM < 0.3:
			continue
		var floor := wall.floor
		var hook := wall.rect(along - 0.02, along + 0.02, 0.0, 0.2)
		RoomDressing.block(mesh, hook, floor + rail - 0.03, floor + rail, ShipPaints.steel)
		var neck := wall.at(along, rail - 0.065, 0.3)
		var tie := Vector2(0.04, 0.035)
		RoomDressing.panel(mesh, neck, wall.right, tie, wall.normal, ShipPaints.rope, 0)
		var sack := wall.rect(along - 0.17, along + 0.17, 0.05, 0.3)
		RoomDressing.block(
			mesh, sack, floor + HEADROOM + 0.02, floor + rail - 0.1, ShipPaints.sacking
		)


## Linoleum laid LINOLEUM_DEPTH over [param room]'s floor in pieces no longer than
## PIECE: over each deck at its floor's height under it, round each stair standing on
## it.
func _linoleum_floor(mesh: ShipMesh, room: ShipRoom) -> void:
	var floor := room.floor_height
	var bare: Array[Rect2] = []
	for platform: ShipPlatform in _space.layout.platforms:
		if is_equal_approx(platform.height, floor) and platform.area.intersects(room.area):
			bare.append(platform.area.intersection(room.area))
	for ramp: ShipRamp in _space.layout.ramps:
		if ramp.base() > floor + 0.5 or maxf(ramp.start_height, ramp.end_height) < floor:
			continue
		var left: Array[Rect2] = []
		for rect: Rect2 in bare:
			left.append_array(_minus(rect, ramp.area))
		bare = left
	for rect: Rect2 in bare:
		var pieces := Vector2i(ceili(rect.size.x / PIECE), ceili(rect.size.y / PIECE))
		var size := rect.size / Vector2(pieces)
		for i in pieces.x:
			for j in pieces.y:
				var piece := Rect2(rect.position + size * Vector2(i, j), size)
				var y := floor + LINOLEUM_DEPTH
				var a := Vector3(piece.position.x, y, piece.position.y)
				var c := Vector3(piece.end.x, y, piece.end.y)
				var b := Vector3(c.x, y, a.z)
				var d := Vector3(a.x, y, c.z)
				mesh.quad(a, b, c, d, Vector3.UP, linoleum, 0)


## [param rect] with [param cut] taken out of it: up to four rectangles.
static func _minus(rect: Rect2, cut: Rect2) -> Array[Rect2]:
	var left: Array[Rect2] = []
	if not rect.intersects(cut):
		left.append(rect)
		return left
	var inner := rect.intersection(cut)
	var low := rect.position
	var high := rect.end
	var strips: Array[Rect2] = [
		Rect2(low.x, low.y, high.x - low.x, inner.position.y - low.y),
		Rect2(low.x, inner.end.y, high.x - low.x, high.y - inner.end.y),
		Rect2(low.x, inner.position.y, inner.position.x - low.x, inner.size.y),
		Rect2(inner.end.x, inner.position.y, high.x - inner.end.x, inner.size.y),
	]
	for strip: Rect2 in strips:
		if strip.size.x > ShipMesh.SLIVER and strip.size.y > ShipMesh.SLIVER:
			left.append(strip)
	return left


## A flat strip on [param wall] over [param span] along it, from [param height].x
## over the floor [param height].y high, a sliver out from its face, in pieces no
## longer than PIECE.
func _band(
	mesh: ShipMesh, wall: RoomDressing.Wall, span: Vector2, height: Vector2, paint: ShipMesh.Paint
) -> void:
	var pieces := ceili((span.y - span.x) / PIECE)
	if pieces < 1:
		return
	var step := (span.y - span.x) / pieces
	var half := Vector2(step * 0.5, height.y * 0.5)
	for piece in pieces:
		var centre := wall.at(span.x + step * (piece + 0.5), height.x + half.y, 0.004)
		RoomDressing.panel(mesh, centre, wall.right, half, wall.normal, paint, 0)


## A flat disc of [param radius] centred on [param centre] facing [param normal], a
## fan of [param segments] triangles, unrimmed: cheaper than RoomDressing.disc().
static func _fan(
	mesh: ShipMesh,
	centre: Vector3,
	normal: Vector3,
	radius: float,
	paint: ShipMesh.Paint,
	segments: int
) -> void:
	var axes := RoomDressing.across(normal)
	var weights := PackedFloat32Array([0.0, 0.0, 0.0])
	for index in segments:
		var turn := TAU * index / segments
		var next := TAU * (index + 1) / segments
		var a := centre + (axes[0] * cos(turn) + axes[1] * sin(turn)) * radius
		var b := centre + (axes[0] * cos(next) + axes[1] * sin(next)) * radius
		mesh.triangle(PackedVector3Array([centre, a, b]), weights, normal, paint)


## The widest of [param spans]; none, zero wide, when there are none.
static func _widest(spans: Array[Vector2]) -> Vector2:
	var widest := Vector2.ZERO
	for span: Vector2 in spans:
		if span.y - span.x > widest.y - widest.x:
			widest = span
	return widest


## How high over its floor [param wall]'s room is roofed by it at [param along].
func _headroom(wall: RoomDressing.Wall, along: float) -> float:
	var at := wall.at(along, 0.0, 0.1)
	return _space.ceiling(wall.room, at.x, at.z) - ShipArt.PLANK - wall.floor


## Whether a stair, up or down, stands beside [param wall] from [param a] to
## [param b] along it, between its floor and its ceiling.
func _beside_a_stair(wall: RoomDressing.Wall, a: float, b: float) -> bool:
	var beside := wall.rect(a, b, 0.0, 0.6)
	var high := wall.floor + _headroom(wall, (a + b) * 0.5)
	return RoomDressing.over_a_ramp(_space.layout, beside, wall.floor - 0.01, high)


## Whether [param pane] of [param room]'s glass stands in its side [param side].
func _on_side(room: ShipRoom, side: int, pane: Array) -> bool:
	var centre: Vector3 = pane[1]
	var across := centre.z if side % 2 == 0 else centre.x
	var out := ShipSpace.outward(side)
	var into := Vector3(-out.x, 0.0, -out.y)
	return absf(across - _space.side_line(room, side)) < 0.3 and into.dot(pane[2]) > 0.9


## The stretches along [param wall] clear by [param margin] of [param glass] — and of
## stairs, unless [param glass_only] — each as (from, to) along it, held 0.1 off its
## ends.
func _clear_spans(
	wall: RoomDressing.Wall, glass: Array[Array], glass_only: bool, margin := 0.12
) -> Array[Vector2]:
	var taken: Array[Vector2] = []
	for pane: Array in glass:
		if _on_side(wall.room, wall.side, pane):
			var centre: Vector3 = pane[1]
			var along := centre.x if wall.side % 2 == 0 else centre.z
			var half: float = (pane[4] as Vector2).x + margin
			taken.append(Vector2(along - half, along + half))
	if not glass_only:
		var beside := wall.rect(wall.from, wall.to, 0.0, 0.6)
		var high := wall.floor + _headroom(wall, wall.middle())
		for ramp: ShipRamp in _space.layout.ramps:
			var top := maxf(ramp.start_height, ramp.end_height)
			if ramp.area.intersects(beside) and ramp.base() < high and top > wall.floor - 0.01:
				var area := ramp.area
				if wall.side % 2 == 0:
					taken.append(Vector2(area.position.x - 0.1, area.end.x + 0.1))
				else:
					taken.append(Vector2(area.position.y - 0.1, area.end.y + 0.1))
	taken.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spans: Array[Vector2] = []
	var start := wall.from + 0.1
	for cut: Vector2 in taken:
		if cut.x - start > 0.1:
			spans.append(Vector2(start, minf(cut.x, wall.to - 0.1)))
		start = maxf(start, cut.y)
	if wall.to - 0.1 - start > 0.1:
		spans.append(Vector2(start, wall.to - 0.1))
	return spans
