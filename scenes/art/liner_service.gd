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
## the post office, the Marconi room, the chart room (OFFICES) — on linoleum, with
## pigeonhole racks along its walls, a clock and a notice board, and in the post office
## a row of mail sacks on hooks overhead. A lavatory, a pantry, any other room of
## service is its tile alone.
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
## tile underfoot; linoleum.
const TILE := Color("e4e2d8")
const TILE_COURSE := Color("3f5d80")
const QUARRY := Color("8a4a36")
const LINOLEUM := Color("6b5a43")
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
## The modelled ware hung from it (assets/models), each with its origin on the bar's
## axis at its underside, x along the wall, z out of it: a copper pan by the radius it
## is made for, its rim's top PAN_HANDLE under the bar; the stockpot, its box over all
## STOCKPOT; a ladle by how far under the bar it hangs. RoomDressing.variant() picks
## the largest no bigger than the room under the bar allows, and none hangs where
## even the least is too big.
const PANS := {0.12: "copper_pan_120", 0.075: "copper_pan_75"}
const PAN_HANDLE := 0.07
const STOCKPOT_MODEL := "stockpot"
const STOCKPOT := AABB(Vector3(-0.1, -0.19, -0.086), Vector3(0.2, 0.19, 0.172))
const LADLES := {0.35: "ladle_35", 0.22: "ladle_22"}
## How high the blue course of tile runs round a galley, and how deep it is.
const COURSE := Vector2(1.7, 0.05)
## A dresser's plate rack: from and to how high over the floor, and its widest; the
## modelled racks by their width, the widest no wider than the stretch allows
## (RoomDressing.variant()), each with its origin on the floor at the wall's face
## under its middle.
const DRESSER := Vector2(0.95, 1.8)
const DRESSER_WIDTH := 1.8
const DRESSERS := {1.8: "dresser_180", 1.4: "dresser_140"}
## A bay of wall bars: how wide, how many at most; the modelled bay, its origin on
## the floor at the wall's face under its middle, and its box.
const BAR_BAY := 0.6
const BAR_BAYS := 4
const WALL_BARS_MODEL := "wall_bars"
const WALL_BARS := AABB(Vector3(-0.3, 0.0, 0.01), Vector3(0.6, 2.28, 0.07))
## A pigeonhole rack: from and to how high over the floor, its widest, and one hole.
const PIGEONHOLES := Vector2(0.95, 1.75)
const PIGEONHOLE_WIDTH := 2.4
const HOLE := Vector2(0.24, 0.2)
## How far apart the post office's mail sacks hang; the modelled sack on its hook,
## its origin on the wall's face under the hook at HEADROOM, and its box.
const SACK_SPACING := 0.55
const MAIL_SACK_MODEL := "mail_sack"
const MAIL_SACK := AABB(Vector3(-0.134, 0.02, 0.0), Vector3(0.268, 0.415, 0.271))
## The gymnasium's plaque and a notice board (assets/models), each with its origin on
## the wall's face at its middle, PLAQUE_HEIGHT and NOTICE_HEIGHT over the floor, and
## each one's box there.
const PLAQUE_MODEL := "plaque"
const PLAQUE := AABB(Vector3(-0.2, -0.14, 0.0), Vector3(0.4, 0.28, 0.022))
const PLAQUE_HEIGHT := 1.5
const NOTICE_BOARD_MODEL := "notice_board"
const NOTICE_BOARD := AABB(Vector3(-0.325, -0.245, 0.0), Vector3(0.65, 0.49, 0.026))
const NOTICE_HEIGHT := 1.45
## What a room of service's name holds when it is an office, "officer" read as no
## "office": the purser's and the post office, and a liner's wireless rooms and her
## bridge's chart and navigating rooms, whose racks take forms and charts.
const OFFICES: Array[String] = [
	"office", "marconi room", "silent room", "chart room", "navigating room"
]

static var tile := ShipMesh.Paint.new(FINISH.HOUSE, ArtPalette.HOUSE, FINISH.PLAIN, TILE)
static var quarry := ShipMesh.Paint.new(FINISH.DECK, ArtPalette.DECK, FINISH.PLAIN, QUARRY)
static var course := ShipMesh.Paint.new(FINISH.PLAIN, TILE_COURSE)
static var linoleum := ShipMesh.Paint.new(FINISH.PLAIN, LINOLEUM)

var _space: ShipSpace
var _cabins: CabinDressing


func _init(space: ShipSpace, cabins: CabinDressing) -> void:
	_space = space
	_cabins = cabins


## Whether [param room], a room of service, is an office: what its name says (OFFICES).
static func office(room: ShipRoom) -> bool:
	var name := String(room.name).to_lower().replace("officer", "")
	for word: String in OFFICES:
		if name.contains(word):
			return true
	return false


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
## copper stockpot and a ladle hanging from it — no bay beside a stair, nor where the
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
			var name := ""
			match item:
				0:
					name = _fitting(PANS, (drop - PAN_HANDLE) * 0.5)
				1:
					name = STOCKPOT_MODEL if drop >= -STOCKPOT.position.y else ""
				2:
					name = _fitting(LADLES, drop)
			if name != "":
				var place := Transform3D(
					RoomDressing.facing(wall.normal), wall.at(along, hang, RACK_OUT)
				)
				mesh.model(ShipModel.named(name), place)


## The model of the largest of [param variants] no bigger than [param size]
## (RoomDressing.variant()); none, "", when even the least of them is bigger.
static func _fitting(variants: Dictionary, size: float) -> String:
	for made: float in variants:
		if made <= size + ShipMesh.SLIVER:
			return RoomDressing.variant(variants, size)
	return ""


## A dresser's plate rack flat on [param wall] in the middle of [param span] along
## it, the widest of DRESSERS no wider than DRESSER_WIDTH nor the span allows, from
## DRESSER.x to DRESSER.y over the floor and FLAT deep: a pine rack under a cornice,
## three shelves of plates stood on edge behind a rail. None where the span is too
## narrow for the narrowest.
func _dresser(mesh: ShipMesh, wall: RoomDressing.Wall, span: Vector2) -> void:
	var name := _fitting(DRESSERS, minf(DRESSER_WIDTH, span.y - span.x - 0.2))
	if name == "":
		return
	var along := (span.x + span.y) * 0.5
	var place := Transform3D(RoomDressing.facing(wall.normal), wall.at(along, 0.0))
	mesh.model(ShipModel.named(name), place)


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
## stairs, BAR_BAYS of them at most nearest its middle, each the modelled bay
## (WALL_BARS_MODEL): an upright at each side and rungs between, none standing out
## more than BARS — none where the ceiling leaves no room over it.
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
		if _headroom(wall, bay) - 0.08 < WALL_BARS.end.y - ShipMesh.SLIVER:
			continue
		var place := Transform3D(RoomDressing.facing(wall.normal), wall.at(bay, 0.0))
		mesh.model(ShipModel.named(WALL_BARS_MODEL), place)


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


## A brass plaque flat on [param wall] at [param along] (PLAQUE_MODEL), on a teak
## board, engraved.
func _plaque(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var place := Transform3D(RoomDressing.facing(wall.normal), wall.at(along, PLAQUE_HEIGHT))
	mesh.model(ShipModel.named(PLAQUE_MODEL), place)


## A notice board flat on [param wall] at [param along] (NOTICE_BOARD_MODEL): cork
## in a frame, notices pinned to it.
func _notice_board(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var place := Transform3D(RoomDressing.facing(wall.normal), wall.at(along, NOTICE_HEIGHT))
	mesh.model(ShipModel.named(NOTICE_BOARD_MODEL), place)


## A clock flat on [param wall] at [param along], [param height] over the floor
## (RoomDressing.CLOCK_MODEL): a white dial in a brass bezel, and its hands.
func _clock(mesh: ShipMesh, wall: RoomDressing.Wall, along: float, height: float) -> void:
	var face := Transform3D(RoomDressing.facing(wall.normal), wall.at(along, height))
	mesh.model(ShipModel.named(RoomDressing.CLOCK_MODEL), face)


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
## (MAIL_SACK_MODEL) — none beside a stair, nor where the ceiling leaves no room for
## one.
func _mail_sacks(mesh: ShipMesh, wall: RoomDressing.Wall) -> void:
	var count := floori((wall.length() - 0.4) / SACK_SPACING)
	var first := wall.middle() - (count - 1) * SACK_SPACING * 0.5
	for index in count:
		var along := first + index * SACK_SPACING
		if _beside_a_stair(wall, along - 0.3, along + 0.3):
			continue
		if _headroom(wall, along) - 0.08 < HEADROOM + MAIL_SACK.end.y:
			continue
		var place := Transform3D(RoomDressing.facing(wall.normal), wall.at(along, HEADROOM))
		mesh.model(ShipModel.named(MAIL_SACK_MODEL), place)


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
