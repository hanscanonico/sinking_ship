class_name LinerPublic
extends RefCounted
## A liner's public rooms (RoomDressing.Kind.PUBLIC) and her grand staircase's landings
## (Kind.STAIRCASE), each dressed by the first of STYLES its name holds: the smoking
## room panelled in dark mahogany between pilasters, a picture between each two, brass
## sconces along it and a coffered ceiling; the lounge in pale panels with mirrors and
## sconces between them, a chandelier for each pendant; the reading and writing room
## white, its inside walls lined with bookcases, with a clock; the verandah café's walls
## a green trellis over a wicker floor, baskets hung from its ceiling; the restaurant
## warm walnut panels with mirrors, sconces and coffers; the reception room white panels
## between pilasters, a long mirror on its after wall; third class's general room and
## open space plain enamel over the ship's own planks, a notice board, fire buckets and
## a clock; the after entrance and each landing oak panelling round a carved clock
## panel — each landing a chandelier for each pendant, the boat deck's under a glass
## dome. Every window keeps its curtains; a room named for none of them keeps a
## saloon's dressing (CabinDressing.saloon).
## Between a step over the floor and a body's height, nothing it draws stands more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall — every piece there is
## DEPTH deep at most, flat on its wall, and none stands by a stair; over HEADROOM
## (1.85 m) anything may: the coffers, the chandeliers, the dome, the baskets. These
## rooms have no blocker inside them, and none is ever added to hide a piece (D6): no
## furniture stands out in a room. The panelling is drawn over each wall, clear of its
## glass, rather than lined (RoomDressing.Part), as one lining serves every public room
## and landing alike.

## What a room is dressed as, by its name.
enum Style {SALOON, LANDING, ENTRANCE, SMOKING, LOUNGE, READING, CAFE, RESTAURANT, RECEPTION, THIRD}

## The first of these a room's name holds, any case, says its Style.
const STYLES: Array[Array] = [
	["staircase", Style.LANDING],
	["entrance", Style.ENTRANCE],
	["smoking", Style.SMOKING],
	["lounge", Style.LOUNGE],
	["reading", Style.READING],
	["café", Style.CAFE],
	["restaurant", Style.RESTAURANT],
	["reception", Style.RECEPTION],
	["general room", Style.THIRD],
	["open space", Style.THIRD],
]

## The rooms' own colours: woods, painted panels, glass and cloth.
const MAHOGANY := Color("6e3522")
const MAHOGANY_DEEP := Color("4a2014")
const OAK := Color("9a6b3e")
const OAK_CARVED := Color("b88752")
const WALNUT := Color("7a4528")
const PALE_PANEL := Color("e9e0c9")
const WHITE_PANEL := Color("f3f0e7")
const CREAM_CEILING := Color("efe4c8")
const GILT := ArtPalette.GILT
const MIRROR_GLASS := Color("cfdde3")
const SCONCE_GLASS := ArtPalette.SCONCE_GLASS
const TRELLIS := Color("5c7d48")
const TRELLIS_GROUND := Color("dfe4cf")
const WICKER := Color("c9a56b")
const FOLIAGE := Color("4b7537")
const CORK := Color("9b7448")
const SMOKING_CURTAIN := Color("6e2422")
const LOUNGE_CURTAIN := Color("b98a6a")
const CAFE_CURTAIN := Color("8aa36e")
const RESTAURANT_CURTAIN := Color("a8545a")
const BOOKS: Array[Color] = [
	Color("6b2a22"), Color("2f4a3a"), Color("2a3550"), Color("7a5a2a"), Color("50303a")
]

## The deepest a piece stands out from its wall under HEADROOM: within the tolerance.
const DEPTH := 0.11
## How far proud of its wall the panelling stands, and how wide its panels are at most.
const CLAD_OUT := 0.006
const PANEL_PITCH := 1.25
## A panel this tall or taller is a full one, not a strip under or over a window.
const FULL_PANEL := 1.5
## Round a window's pane, how much of its frame the panelling keeps clear of; round a
## porthole, how far from its middle.
const HOLE_MARGIN := 0.07
const PORTHOLE_CLEAR := 0.22
## The highest a wall's panelling rises over its floor, and a doorway's lintel.
const CLAD_MOST := 3.5
const LINTEL := 2.12
## A pilaster's width and depth, and how far apart they stand.
const PILASTER := Vector2(0.24, 0.1)
const PILASTER_PITCH := 2.5
## Sconces: how far apart in the smoking room, and how high their plate.
const SCONCE_PITCH := 3.0
const SCONCE_HEIGHT := 1.7
## A mirror's half size and how high its middle, and how far apart they hang.
const MIRROR := Vector2(0.4, 0.55)
const MIRROR_HEIGHT := 1.55
const MIRROR_PITCH := 2.5
## A coffer's side, and its ribs' width and depth under the ceiling.
const COFFER := 3.0
const RIB := Vector2(0.14, 0.14)
## The trellis: how far apart its laths run, and how wide each is.
const LATTICE := 0.6
const LATH := 0.03
## The wicker floor's squares.
const MATTING := 2.0
## Hanging baskets: how far apart, their radius and how far under the ceiling.
const BASKET_PITCH := 3.0
const BASKET := 0.18
const BASKET_DROP := 0.35
## A bookcase: its bays' width at most, its bottom and top over the floor, its shelves.
const BAY := 1.3
const BOOKCASE := Vector2(0.95, 2.35)
const SHELVES := 3
## A chandelier's ring, and the dome's glass: radii.
const CHANDELIER := 0.4
const DOME := 1.5
## A chandelier (CHANDELIER_MODEL, its hub at its origin): how far over its hub it
## stands at most, where the rod from the ceiling meets it, and how far under it.
const CHANDELIER_MODEL := "chandelier"
const CHANDELIER_RISE := 0.12
const CHANDELIER_DEPTH := 0.15

static var _mahogany := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, MAHOGANY)
static var _mahogany_deep := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, MAHOGANY_DEEP)
static var _oak := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, OAK)
static var _oak_carved := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, OAK_CARVED)
static var _walnut := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, WALNUT)
static var _pale := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, PALE_PANEL)
static var _white := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, WHITE_PANEL)
static var _cream := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, CREAM_CEILING)
static var _gilt := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, GILT)
static var _mirror := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, MIRROR_GLASS)
static var _sconce := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, SCONCE_GLASS)
static var _trellis := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, TRELLIS)
static var _trellis_ground := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, TRELLIS_GROUND)
static var _wicker := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, WICKER)
static var _foliage := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, FOLIAGE)
static var _cork := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, CORK)
static var _books: Array[ShipMesh.Paint] = _paints(BOOKS)

var _space: ShipSpace
var _cabins: CabinDressing


func _init(space: ShipSpace, cabins: CabinDressing) -> void:
	_space = space
	_cabins = cabins


static func _paints(colours: Array[Color]) -> Array[ShipMesh.Paint]:
	var found: Array[ShipMesh.Paint] = []
	for colour: Color in colours:
		found.append(ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, colour))
	return found


## What [param room] is dressed as: the first of STYLES its name holds.
static func style_of(room: ShipRoom) -> Style:
	var name := String(room.name).to_lower()
	for named: Array in STYLES:
		if name.contains(named[0]):
			return named[1]
	return Style.SALOON


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var style := style_of(room)
	if style == Style.SALOON:
		_cabins.saloon(mesh, room, glass)
		return
	_curtains(mesh, style, glass)
	match style:
		Style.LANDING, Style.ENTRANCE:
			_landing(mesh, room, glass, style == Style.LANDING)
		Style.SMOKING:
			_smoking_room(mesh, room, glass)
		Style.LOUNGE:
			_lounge(mesh, room, glass)
		Style.READING:
			_reading_room(mesh, room, glass)
		Style.CAFE:
			_cafe(mesh, room, glass)
		Style.RESTAURANT:
			_restaurant(mesh, room, glass)
		Style.RECEPTION:
			_reception(mesh, room, glass)
		Style.THIRD:
			_third_class(mesh, room, glass)


## The lights [param room] is lit by: a landing's and the lounge's a pendant in the
## middle of each chandelier, one for each pendant it had (chandeliers()); none keeps
## RoomDressing's pendants.
func lights(room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	if style_of(room) in [Style.LANDING, Style.LOUNGE]:
		for at: Vector2 in chandeliers(room):
			var hang := RoomDressing.under_ceiling(_space, room, at)
			found.append(RoomDressing.Light.new(hang, ShipLamp.Kind.PENDANT))
	return found


## What a public room lines its walls, floor, ceiling and beams with
## (RoomDressing.Part); empty keeps the ship's own — each room's panelling is its own,
## drawn over its walls (build()).
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	return paints


## Where [param room]'s chandeliers hang, ship plane: the middle of each
## RoomDressing.LAMP_SPACING square it is cut into, where its pendants hung.
static func chandeliers(room: ShipRoom) -> Array[Vector2]:
	var area := room.area
	var spacing := RoomDressing.LAMP_SPACING
	var across := Vector2i(
		maxi(1, ceili(area.size.x / spacing)), maxi(1, ceili(area.size.y / spacing))
	)
	var found: Array[Vector2] = []
	for i in across.x:
		for j in across.y:
			var share := Vector2((i + 0.5) / across.x, (j + 0.5) / across.y)
			found.append(area.position + area.size * share)
	return found


## Curtains drawn back from each window of [param glass], in [param style]'s colour.
func _curtains(mesh: ShipMesh, style: Style, glass: Array[Array]) -> void:
	var colour := ArtPalette.SALOON_CURTAIN
	match style:
		Style.SMOKING:
			colour = SMOKING_CURTAIN
		Style.LOUNGE, Style.RECEPTION:
			colour = LOUNGE_CURTAIN
		Style.CAFE:
			colour = CAFE_CURTAIN
		Style.RESTAURANT:
			colour = RESTAURANT_CURTAIN
	var curtain := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, colour)
	for pane: Array in glass:
		if not pane[3]:
			CabinDressing.curtains(mesh, pane[1], pane[2], curtain)


## A landing of the grand staircase or the after entrance: oak panelling round a
## carved clock panel; a landing a chandelier for each pendant, the boat deck's under
## a glass dome (when [param landing]).
func _landing(mesh: ShipMesh, room: ShipRoom, glass: Array[Array], landing: bool) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		_clad(mesh, wall, _holes(wall, glass), _oak, ShipMesh.RIM_ALL)
	_lintels(mesh, room, _oak)
	var clock := _clock_wall(room, glass)
	if clock != null:
		_clock_panel(mesh, clock, clock.middle())
	if not landing:
		return
	for at: Vector2 in chandeliers(room):
		_chandelier(mesh, room, at)
	if String(room.name).to_lower().contains("boat deck"):
		_dome(mesh, room)


## The smoking room: dark mahogany between pilasters, a picture between each two on its
## inside walls, brass sconces every SCONCE_PITCH clear of them and a coffered ceiling.
func _smoking_room(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var holes := _holes(wall, glass)
		_clad(mesh, wall, holes, _mahogany, 0)
		var head := _head(wall)
		var pilasters := _spots(wall, holes, PILASTER_PITCH, PILASTER.x, 0.0, head)
		for along: float in pilasters:
			_pilaster(mesh, wall, along, head, _mahogany_deep)
		if not wall.outdoors_beyond():
			for along: float in _betweens(wall, holes, pilasters, PILASTER_PITCH, 0.3):
				CabinDressing.picture(mesh, wall, along)
		_sconces(mesh, wall, holes, SCONCE_PITCH, pilasters, PILASTER.x * 0.5 + 0.08)
	_lintels(mesh, room, _mahogany)
	_coffers(mesh, room, _mahogany, _mahogany_deep)


## The lounge: pale panels, a mirror on every MIRROR_PITCH of wall clear of its glass,
## sconces between them, a chandelier for each pendant.
func _lounge(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var holes := _holes(wall, glass)
		_clad(mesh, wall, holes, _pale, ShipMesh.RIM_ALL)
		var mirrors := _mirrors(mesh, wall, holes, _gilt)
		_sconces(mesh, wall, holes, MIRROR_PITCH * 0.5, mirrors, MIRROR.x + 0.15)
	_lintels(mesh, room, _pale)
	for at: Vector2 in chandeliers(room):
		_chandelier(mesh, room, at)


## The reading and writing room: white, its inside walls lined with bookcases either
## side of a clock in the middle of the longest.
func _reading_room(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var inside: Array[RoomDressing.Wall] = []
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var holes := _holes(wall, glass)
		_clad(mesh, wall, holes, _white, 0)
		if wall.outdoors_beyond() or not holes.is_empty() or _by_a_ramp(wall, wall.from, wall.to):
			continue
		inside.append(wall)
	_lintels(mesh, room, _white)
	var longest: RoomDressing.Wall = null
	for wall: RoomDressing.Wall in inside:
		if longest == null or wall.length() > longest.length():
			longest = wall
	for wall: RoomDressing.Wall in inside:
		if wall == longest:
			_bookcases(mesh, wall, wall.from + 0.2, wall.middle() - 0.4)
			_bookcases(mesh, wall, wall.middle() + 0.4, wall.to - 0.2)
			_clock(mesh, wall, wall.middle(), 1.6, 0.16)
		else:
			_bookcases(mesh, wall, wall.from + 0.2, wall.to - 0.2)


## The verandah café: a green trellis over its walls, a wicker floor and baskets of
## green hung from its ceiling, clear of its lamps.
func _cafe(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var holes := _holes(wall, glass)
		_clad(mesh, wall, holes, _trellis_ground, 0)
		for rect: Rect2 in _clear_rects(wall, holes, 0.05, _head(wall) - 0.05):
			_lattice(mesh, wall, rect)
	_lintels(mesh, room, _trellis_ground)
	_matting(mesh, room)
	var area := room.area.grow(-1.0)
	var across := Vector2i(
		maxi(1, roundi(area.size.x / BASKET_PITCH)), maxi(1, roundi(area.size.y / BASKET_PITCH))
	)
	var lamps := chandeliers(room)
	for i in across.x:
		for j in across.y:
			var share := Vector2((i + 0.5) / across.x, (j + 0.5) / across.y)
			var at := area.position + area.size * share
			var by_lamp := false
			for lamp: Vector2 in lamps:
				by_lamp = by_lamp or lamp.distance_to(at) < 1.0
			if not by_lamp:
				_basket(mesh, room, at)


## The à la carte restaurant: warm walnut panels, mirrors on its walls clear of glass,
## sconces between them and a coffered cream ceiling.
func _restaurant(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var holes := _holes(wall, glass)
		_clad(mesh, wall, holes, _walnut, ShipMesh.RIM_ALL)
		var mirrors := _mirrors(mesh, wall, holes, _gilt)
		_sconces(mesh, wall, holes, MIRROR_PITCH * 0.5, mirrors, MIRROR.x + 0.15)
	_lintels(mesh, room, _walnut)
	_coffers(mesh, room, _cream, _walnut)


## The reception room: white panels between pilasters, a long mirror on its after
## wall between the two either side of its middle; its pendants kept.
func _reception(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var holes := _holes(wall, glass)
		_clad(mesh, wall, holes, _white, ShipMesh.RIM_ALL)
		var head := _head(wall)
		var pilasters := _spots(wall, holes, PILASTER_PITCH, PILASTER.x, 0.0, head)
		for along: float in pilasters:
			_pilaster(mesh, wall, along, head, _white)
		if wall.side != 3:
			continue
		var reach := wall.length() * 0.5
		for along: float in pilasters:
			if absf(along - wall.middle()) > 0.01:
				reach = minf(reach, absf(along - wall.middle()))
		var half := Vector2(reach - PILASTER.x * 0.5 - 0.15, MIRROR.y)
		var span := Rect2(
			wall.middle() - half.x, MIRROR_HEIGHT - half.y, half.x * 2.0, half.y * 2.0
		)
		if half.x > 0.3 and _clear(wall, holes, span.grow(0.04)):
			_mirror_at(mesh, wall, wall.middle(), half, _gilt)
	_lintels(mesh, room, _white)


## Third class's general room and open space: plain enamel over the ship's own planks,
## a notice board and a clock on the longest clear wall, fire buckets on the next.
func _third_class(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var clear: Array[RoomDressing.Wall] = []
	var spots_of := {}
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var holes := _holes(wall, glass)
		_clad(mesh, wall, holes, ShipPaints.enamel, 0)
		var spots := _spots(wall, holes, 1.6, 0.6, 0.9, RoomDressing.HEADROOM, 1.2)
		if not spots.is_empty():
			clear.append(wall)
			spots_of[wall] = spots
	_lintels(mesh, room, ShipPaints.enamel)
	if clear.is_empty():
		return
	clear.sort_custom(
		func(a: RoomDressing.Wall, b: RoomDressing.Wall) -> bool: return a.length() > b.length()
	)
	var board := clear[0]
	var spots: PackedFloat32Array = spots_of[board]
	var middle := floori(spots.size() / 2.0)
	_notice_board(mesh, board, spots[middle])
	if middle > 0:
		_clock(mesh, board, spots[middle - 1], 1.75, 0.14)
	var buckets := board
	var along := spots[spots.size() - 1]
	if clear.size() > 1:
		buckets = clear[1]
		along = buckets.middle()
	elif spots.size() < 3:
		return
	if not _by_a_ramp(buckets, along - 0.5, along + 0.5):
		RoomDressing.fire_buckets(mesh, buckets, along)


## Where [param glass] stands in [param wall]: each pane's frame as a Rect2 (along it,
## height over the floor), by where along it.
func _holes(wall: RoomDressing.Wall, glass: Array[Array]) -> Array[Rect2]:
	var holes: Array[Rect2] = []
	for pane: Array in glass:
		var into: Vector3 = pane[2]
		if into.dot(wall.normal) < 0.99:
			continue
		var centre: Vector3 = pane[1]
		var along := centre.x if wall.side % 2 == 0 else centre.z
		if along < wall.from - 0.01 or along > wall.to + 0.01:
			continue
		if absf((centre - wall.at(along, 0.0)).dot(wall.normal)) > 0.1:
			continue
		var half: Vector2 = pane[4]
		half = Vector2.ONE * PORTHOLE_CLEAR if pane[3] else half + Vector2.ONE * HOLE_MARGIN
		var middle := centre.y - wall.floor
		holes.append(Rect2(along - half.x, middle - half.y, half.x * 2.0, half.y * 2.0))
	holes.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return holes


## How high over its floor [param wall] stands, up to its deck's underside where it
## is lowest along the wall, CLAD_MOST at most.
func _head(wall: RoomDressing.Wall) -> float:
	var head := CLAD_MOST
	for along: float in [wall.from, wall.middle(), wall.to]:
		var at := wall.at(along, 0.0, 0.3)
		var ceiling := _space.ceiling(wall.room, at.x, at.z) - ShipArt.PLANK - 0.01
		head = minf(head, ceiling - wall.floor)
	return head


## The rectangles of [param wall] (along it, height over the floor) from [param low]
## to [param high] that none of [param holes] reaches into.
func _clear_rects(
	wall: RoomDressing.Wall, holes: Array[Rect2], low: float, high: float
) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var start := wall.from
	for hole: Rect2 in holes:
		var a := maxf(hole.position.x, start)
		var b := minf(hole.end.x, wall.to)
		if b <= a:
			continue
		if a > start:
			rects.append(Rect2(start, low, a - start, high - low))
		if hole.position.y > low:
			rects.append(Rect2(a, low, b - a, minf(hole.position.y, high) - low))
		if hole.end.y < high:
			var top := maxf(hole.end.y, low)
			rects.append(Rect2(a, top, b - a, high - top))
		start = b
	if wall.to > start:
		rects.append(Rect2(start, low, wall.to - start, high - low))
	var found: Array[Rect2] = []
	for rect: Rect2 in rects:
		if rect.size.x > ShipMesh.SLIVER and rect.size.y > ShipMesh.SLIVER:
			found.append(rect)
	return found


## Panels of [param paint] over [param wall] from its floor to its head, clear of
## [param holes], none wider than PANEL_PITCH: the edges [param rims] names darkened
## on each full-height panel, none on the strips under and over a window.
func _clad(
	mesh: ShipMesh, wall: RoomDressing.Wall, holes: Array[Rect2], paint: ShipMesh.Paint, rims: int
) -> void:
	for rect: Rect2 in _clear_rects(wall, holes, 0.0, _head(wall)):
		var pieces := maxi(1, ceili(rect.size.x / PANEL_PITCH - 0.01))
		var width := rect.size.x / pieces
		for index in pieces:
			var along := rect.position.x + width * (index + 0.5)
			var centre := wall.at(along, rect.get_center().y, CLAD_OUT)
			var half := Vector2(width, rect.size.y) * 0.5
			var edges := rims if rect.size.y > FULL_PANEL else 0
			RoomDressing.panel(mesh, centre, wall.right, half, wall.normal, paint, edges)


## Panelling of [param paint] over each doorway of [param room] between two of its
## walls, from its lintel up to its deck's underside.
func _lintels(mesh: ShipMesh, room: ShipRoom, paint: ShipMesh.Paint) -> void:
	var runs := _space.wall_runs(room)
	for side in 4:
		var half := -1.0
		for run: Array in runs:
			if run[0] == side:
				half = run[3]
		if half < 0.0:
			continue
		var along_x := side % 2 == 0
		var low := room.area.position.x if along_x else room.area.position.y
		var high := room.area.end.x if along_x else room.area.end.y
		for gap: Vector2 in RoomDressing._gaps(room, side, runs):
			if gap.y - gap.x > 1.3 or gap.x < low + 0.15 or gap.y > high - 0.15:
				continue
			var head := RoomDressing.Wall.new(_space, room, [side, gap.x, gap.y, half])
			var top := _head(head)
			if top - LINTEL < ShipMesh.SLIVER:
				continue
			var centre := head.at(head.middle(), (LINTEL + top) * 0.5, CLAD_OUT)
			var size := Vector2(head.length(), top - LINTEL) * 0.5
			RoomDressing.panel(mesh, centre, head.right, size, head.normal, paint, 0)


## Where along [param wall] pieces [param half] wide either side stand, [param pitch]
## apart and centred on it, from [param low] to [param high] over the floor: each
## clear of [param holes], of a stair beside the wall and of its ends by [param end].
func _spots(
	wall: RoomDressing.Wall,
	holes: Array[Rect2],
	pitch: float,
	half: float,
	low: float,
	high: float,
	end := 0.05
) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	var length := wall.length() - (half + end) * 2.0
	if length < 0.0:
		return found
	var count := floori(length / pitch) + 1
	for index in count:
		var along := wall.middle() + (index - (count - 1) * 0.5) * pitch
		var span := Rect2(along - half, low, half * 2.0, high - low)
		if _clear(wall, holes, span):
			found.append(along)
	return found


## The middles between each two of [param spots] along [param wall] [param pitch]
## apart, where a picture [param half] wide either side stands clear of [param holes].
func _betweens(
	wall: RoomDressing.Wall,
	holes: Array[Rect2],
	spots: PackedFloat32Array,
	pitch: float,
	half: float
) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for index in spots.size() - 1:
		if spots[index + 1] - spots[index] > pitch * 1.01:
			continue
		var along := (spots[index] + spots[index + 1]) * 0.5
		if _clear(wall, holes, Rect2(along - half, 1.2, half * 2.0, 0.5)):
			found.append(along)
	return found


## Whether [param span] (along [param wall], height over its floor) meets none of
## [param holes] and stands by no stair.
func _clear(wall: RoomDressing.Wall, holes: Array[Rect2], span: Rect2) -> bool:
	for hole: Rect2 in holes:
		if hole.intersects(span):
			return false
	return not _by_a_ramp(wall, span.position.x, span.end.x)


## Whether a stair stands beside [param wall] from [param a] to [param b] along it.
func _by_a_ramp(wall: RoomDressing.Wall, a: float, b: float) -> bool:
	var area := wall.rect(a, b, 0.0, 0.5)
	return RoomDressing.over_a_ramp(_space.layout, area, wall.floor - 0.01, wall.floor + 2.5)


## A pilaster on [param wall] at [param along], up to [param head]: a plinth, a shaft
## and a capital under the ceiling, in [param paint].
func _pilaster(
	mesh: ShipMesh, wall: RoomDressing.Wall, along: float, head: float, paint: ShipMesh.Paint
) -> void:
	var floor := wall.floor
	var half := PILASTER.x * 0.5
	var plinth := wall.rect(along - half - 0.03, along + half + 0.03, 0.0, DEPTH)
	RoomDressing.block(mesh, plinth, floor, floor + 0.15, paint)
	var shaft := wall.rect(along - half, along + half, 0.0, PILASTER.y)
	RoomDressing.block(mesh, shaft, floor + 0.15, floor + head - 0.16, paint)
	var capital := wall.rect(along - half - 0.04, along + half + 0.04, 0.0, DEPTH)
	RoomDressing.block(mesh, capital, floor + head - 0.16, floor + head, paint)


## A sconce on every [param pitch] of [param wall] clear of [param holes] and further
## than [param keep] from each of [param beside].
func _sconces(
	mesh: ShipMesh,
	wall: RoomDressing.Wall,
	holes: Array[Rect2],
	pitch: float,
	beside: PackedFloat32Array,
	keep: float
) -> void:
	var high := SCONCE_HEIGHT + 0.2
	for along: float in _spots(wall, holes, pitch, 0.06, SCONCE_HEIGHT - 0.1, high, 0.25):
		var near := false
		for other: float in beside:
			near = near or absf(other - along) < keep
		if not near:
			_sconce_on(mesh, wall, along)


## A brass sconce on [param wall] at [param along]: a plate, an arm and a glass shade.
func _sconce_on(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var plate := wall.at(along, SCONCE_HEIGHT, 0.012)
	RoomDressing.panel(
		mesh, plate, wall.right, Vector2(0.035, 0.07), wall.normal, ShipPaints.brass, 0
	)
	var arm := wall.at(along, SCONCE_HEIGHT, 0.02)
	mesh.beam(arm, wall.at(along, SCONCE_HEIGHT + 0.06, 0.075), Vector2.ONE * 0.014, _gilt, 0)
	var shade := wall.place(wall.at(along, SCONCE_HEIGHT + 0.11, 0.075))
	mesh.turned_box(shade, Vector3(0.07, 0.09, 0.065), _sconce, 0)


## A mirror on each MIRROR_PITCH of [param wall] clear of [param holes], framed in
## [param frame]; where along it each hangs.
func _mirrors(
	mesh: ShipMesh, wall: RoomDressing.Wall, holes: Array[Rect2], frame: ShipMesh.Paint
) -> PackedFloat32Array:
	var low := MIRROR_HEIGHT - MIRROR.y - 0.04
	var high := MIRROR_HEIGHT + MIRROR.y + 0.04
	var spots := _spots(wall, holes, MIRROR_PITCH, MIRROR.x + 0.04, low, high, 0.3)
	for along: float in spots:
		_mirror_at(mesh, wall, along, MIRROR, frame)
	return spots


## A mirror of [param half] size on [param wall] at [param along] in a frame of
## [param frame].
func _mirror_at(
	mesh: ShipMesh, wall: RoomDressing.Wall, along: float, half: Vector2, frame: ShipMesh.Paint
) -> void:
	var centre := wall.at(along, MIRROR_HEIGHT, 0.012)
	var rim := half + Vector2.ONE * 0.04
	RoomDressing.panel(mesh, centre, wall.right, rim, wall.normal, frame)
	var glass := centre + wall.normal * 0.005
	RoomDressing.panel(mesh, glass, wall.right, half, wall.normal, _mirror, 0)


## A clock of [param radius] on [param wall] at [param along], [param height] over the
## floor: a white face in a brass rim, its hands at ten to two.
func _clock(
	mesh: ShipMesh, wall: RoomDressing.Wall, along: float, height: float, radius: float
) -> void:
	var face := wall.at(along, height, 0.03)
	RoomDressing.disc(mesh, face, wall.normal, radius, ShipPaints.enamel, 8)
	var rim := face + wall.normal * 0.004
	RoomDressing.ring(mesh, rim, wall.normal, radius - 0.01, radius + 0.03, ShipPaints.brass, 8)
	var hands := face + wall.normal * 0.008
	var hour := hands + (wall.right * 0.6 + Vector3.UP * 0.5).normalized() * radius * 0.5
	var minute := hands + (-wall.right * 0.6 + Vector3.UP * 0.5).normalized() * radius * 0.75
	mesh.beam(hands, hour, Vector2(0.012, 0.004), ShipPaints.dark, 0)
	mesh.beam(hands, minute, Vector2(0.01, 0.004), ShipPaints.dark, 0)


## The wall of [param room] its clock panel stands on: its longest forward wall, else
## its longest, whose middle a panel stands on clear of [param glass] and stairs.
func _clock_wall(room: ShipRoom, glass: Array[Array]) -> RoomDressing.Wall:
	var best: RoomDressing.Wall = null
	var best_score := -INF
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		var span := Rect2(wall.middle() - 0.9, 0.8, 1.8, 1.7)
		if wall.length() < 2.0 or not _clear(wall, _holes(wall, glass), span):
			continue
		var score := wall.length() + (100.0 if wall.side == 1 else 0.0)
		if score > best_score:
			best = wall
			best_score = score
	return best


## A carved panel on [param wall] at [param along]: a clock at 1.6 m in a carved oak
## surround, a figure carved either side of it, under a pediment.
func _clock_panel(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var centre := wall.at(along, 1.6, 0.014)
	RoomDressing.panel(mesh, centre, wall.right, Vector2(0.8, 0.75), wall.normal, _oak_carved)
	var field := centre + wall.normal * 0.004
	RoomDressing.panel(mesh, field, wall.right, Vector2(0.7, 0.65), wall.normal, _oak)
	for side: float in [-1.0, 1.0]:
		# A figure: a robe up to its shoulders, a head over it.
		var at := along + side * 0.45
		var robe := wall.at(at, 1.45, 0.024)
		RoomDressing.panel(mesh, robe, wall.right, Vector2(0.11, 0.38), wall.normal, _oak_carved)
		var shoulders := wall.at(at, 1.88, 0.026)
		var span := Vector2(0.08, 0.05)
		RoomDressing.panel(mesh, shoulders, wall.right, span, wall.normal, _oak_carved, 0)
		var head := wall.at(at, 2.0, 0.028)
		RoomDressing.disc(mesh, head, wall.normal, 0.06, _oak_carved, 6)
	# Under a low ceiling (the boat deck's) it comes down rather than poke through.
	var top := minf(2.45, _head(wall))
	var pediment := wall.rect(along - 0.9, along + 0.9, 0.0, DEPTH)
	RoomDressing.block(mesh, pediment, wall.floor + top - 0.1, wall.floor + top, _oak_carved)
	_clock(mesh, wall, along, 1.6, 0.17)


## The coffered ceiling of [param room]: a panel of [param paint] under each COFFER
## square of its ceiling, ribs of [param rib] between them, all over HEADROOM and none
## over a stair.
func _coffers(mesh: ShipMesh, room: ShipRoom, paint: ShipMesh.Paint, rib: ShipMesh.Paint) -> void:
	var area := room.area.grow(-0.12)
	var across := Vector2i(
		maxi(1, roundi(area.size.x / COFFER)), maxi(1, roundi(area.size.y / COFFER))
	)
	var cell := area.size / Vector2(across)
	var floor := room.floor_height
	for i in across.x:
		for j in across.y:
			var square := Rect2(area.position + cell * Vector2(i, j), cell)
			var middle := square.get_center()
			var y := _space.ceiling(room, middle.x, middle.y) - ShipArt.PLANK - 0.01
			if y - RIB.y < floor + RoomDressing.HEADROOM + 0.1:
				continue
			if RoomDressing.over_a_ramp(_space.layout, square, floor - 0.01, y + 0.1):
				continue
			var a := Vector3(square.position.x, y, square.position.y)
			var c := Vector3(square.end.x, y, square.end.y)
			mesh.quad(a, Vector3(c.x, y, a.z), c, Vector3(a.x, y, c.z), Vector3.DOWN, paint, 0)
			# A rib along its far edges, short of the room's own.
			if i < across.x - 1:
				_rib(mesh, Vector3(c.x, y, a.z), c, rib)
			if j < across.y - 1:
				_rib(mesh, Vector3(a.x, y, c.z), c, rib)


## A rib under the ceiling from [param from] to [param to] (along x or z): its
## underside and its two sides.
func _rib(mesh: ShipMesh, from: Vector3, to: Vector3, paint: ShipMesh.Paint) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.UP).normalized() * RIB.x * 0.5
	var down := Vector3.DOWN * RIB.y
	var a := from - side + down
	var b := to - side + down
	mesh.quad(a, b, to + side + down, from + side + down, Vector3.DOWN, paint, 0)
	for out: float in [-1.0, 1.0]:
		var face := side * out
		mesh.quad(
			from + face,
			to + face,
			to + face + down,
			from + face + down,
			face.normalized(),
			paint,
			0
		)


## A trellis over [param rect] of [param wall]: laths LATTICE apart crossing each other
## on the diagonals, clipped to it.
func _lattice(mesh: ShipMesh, wall: RoomDressing.Wall, rect: Rect2) -> void:
	for slope: float in [1.0, -1.0]:
		var out := 0.018 if slope > 0.0 else 0.026
		var across := (Vector3.UP - wall.right * slope).normalized() * LATH * 0.5
		# A lath where along - slope × height is a whole number of LATTICE.
		var ends := PackedFloat32Array()
		var low_right := Vector2(rect.end.x, rect.position.y)
		var high_left := Vector2(rect.position.x, rect.end.y)
		for corner: Vector2 in [rect.position, rect.end, low_right, high_left]:
			ends.append(corner.x - slope * corner.y)
		ends.sort()
		for k in range(ceili(ends[0] / LATTICE), floori(ends[3] / LATTICE) + 1):
			var offset := k * LATTICE
			# Its heights where it crosses the rect's sides, kept within its bottom and top.
			var h0 := (rect.position.x - offset) * slope
			var h1 := (rect.end.x - offset) * slope
			var low := maxf(minf(h0, h1), rect.position.y)
			var high := minf(maxf(h0, h1), rect.end.y)
			if high - low < LATH:
				continue
			var p0 := wall.at(offset + slope * low, low, out)
			var p1 := wall.at(offset + slope * high, high, out)
			var corners := [p0 - across, p1 - across, p1 + across, p0 + across]
			mesh.quad(corners[0], corners[1], corners[2], corners[3], wall.normal, _trellis, 0)


## A wicker floor over [param room]: squares of matting, MATTING a side, a sliver over
## its deck and clear of any stair.
func _matting(mesh: ShipMesh, room: ShipRoom) -> void:
	var area := room.area.grow(-0.1)
	var across := Vector2i(
		maxi(1, roundi(area.size.x / MATTING)), maxi(1, roundi(area.size.y / MATTING))
	)
	var cell := area.size / Vector2(across)
	var y := room.floor_height + 0.01
	for i in across.x:
		for j in across.y:
			var square := Rect2(area.position + cell * Vector2(i, j), cell)
			if RoomDressing.over_a_ramp(_space.layout, square, y - 3.0, y + 3.0):
				continue
			var a := Vector3(square.position.x, y, square.position.y)
			var c := Vector3(square.end.x, y, square.end.y)
			var rims := ShipMesh.RIM_U0 | ShipMesh.RIM_V0
			mesh.quad(a, Vector3(c.x, y, a.z), c, Vector3(a.x, y, c.z), Vector3.UP, _wicker, rims)


## A basket of green hung from [param room]'s ceiling over [param at], over HEADROOM.
func _basket(mesh: ShipMesh, room: ShipRoom, at: Vector2) -> void:
	var hook := RoomDressing.under_ceiling(_space, room, at)
	var top := hook.y - BASKET_DROP
	var bottom := top - 0.16
	if bottom < room.floor_height + RoomDressing.HEADROOM + 0.05:
		return
	mesh.beam(hook, Vector3(at.x, top, at.y), Vector2.ONE * 0.012, ShipPaints.brass, 0)
	mesh.cylinder(at, BASKET, bottom, top, 6, _wicker, false)
	RoomDressing.disc(mesh, Vector3(at.x, bottom, at.y), Vector3.DOWN, BASKET, _wicker, 6)
	mesh.cylinder(at, BASKET + 0.06, top, top + 0.1, 6, _foliage)


## Bookcases on [param wall] from [param a] to [param b] along it, DEPTH deep from
## BOOKCASE.x to BOOKCASE.y over the floor: bays no wider than BAY between uprights,
## SHELVES shelves of spines in BOOKS' colours, by turns of each width and height.
func _bookcases(mesh: ShipMesh, wall: RoomDressing.Wall, a: float, b: float) -> void:
	if b - a < 0.6:
		return
	var floor := wall.floor
	var bays := maxi(1, ceili((b - a) / BAY))
	var width := (b - a) / bays
	var rise := (BOOKCASE.y - BOOKCASE.x) / SHELVES
	var back := wall.at((a + b) * 0.5, (BOOKCASE.x + BOOKCASE.y) * 0.5, CLAD_OUT + 0.002)
	var size := Vector2(b - a, BOOKCASE.y - BOOKCASE.x) * 0.5
	RoomDressing.panel(mesh, back, wall.right, size, wall.normal, _walnut, 0)
	for bay in bays + 1:
		var at := a + width * bay
		var upright := wall.rect(at - 0.02, at + 0.02, 0.0, DEPTH)
		RoomDressing.block(mesh, upright, floor + BOOKCASE.x, floor + BOOKCASE.y, _walnut)
	for shelf in SHELVES + 1:
		var level := floor + BOOKCASE.x + rise * shelf
		RoomDressing.block(mesh, wall.rect(a, b, 0.0, DEPTH), level - 0.02, level, _walnut)
	var spine := 0
	for shelf in SHELVES:
		var level := BOOKCASE.x + rise * shelf
		for bay in bays:
			var along := a + width * bay + 0.03
			var end := a + width * (bay + 1) - 0.03
			while along < end - 0.04:
				var wide := minf(0.04 + 0.02 * ((spine * 7) % 4), end - along)
				var tall := rise * (0.62 + 0.06 * ((spine * 5) % 4))
				var centre := wall.at(along + wide * 0.5, level + tall * 0.5, 0.09)
				var half := Vector2(wide * 0.5 - 0.002, tall * 0.5)
				var paint := _books[spine % _books.size()]
				RoomDressing.panel(mesh, centre, wall.right, half, wall.normal, paint, 0)
				along += wide
				spine += 1


## A notice board on [param wall] at [param along]: cork in a frame, papers pinned on it.
func _notice_board(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var centre := wall.at(along, 1.45, 0.012)
	RoomDressing.panel(mesh, centre, wall.right, Vector2(0.5, 0.35), wall.normal, ShipPaints.frame)
	var cork := centre + wall.normal * 0.004
	RoomDressing.panel(mesh, cork, wall.right, Vector2(0.46, 0.31), wall.normal, _cork, 0)
	for paper: Vector3 in [
		Vector3(-0.28, 0.12, 0.1),
		Vector3(-0.02, 0.1, 0.12),
		Vector3(0.27, 0.14, 0.09),
		Vector3(-0.2, -0.16, 0.08),
		Vector3(0.15, -0.14, 0.1),
	]:
		var at := cork + wall.normal * 0.003 + wall.right * paper.x + Vector3.UP * paper.y
		var half := Vector2(paper.z, paper.z * 1.3)
		RoomDressing.panel(mesh, at, wall.right, half, wall.normal, ShipPaints.chart, 0)


## A chandelier hung from [param room]'s ceiling over [param at], round its pendant's
## globe: a gilt canopy and rod down to the modelled chandelier (CHANDELIER_MODEL) —
## arms out to a ring of shaded lamps with crystal drops hung round it — all over
## HEADROOM; none where a stair rises under it.
func _chandelier(mesh: ShipMesh, room: ShipRoom, at: Vector2) -> void:
	var top := RoomDressing.under_ceiling(_space, room, at)
	var floor := room.floor_height
	var spot := Rect2(at, Vector2.ZERO).grow(CHANDELIER + 0.3)
	if RoomDressing.over_a_ramp(_space.layout, spot, floor - 0.01, top.y):
		return
	var hub := top + Vector3.DOWN * ShipLamp.CORD
	hub.y = maxf(hub.y, floor + RoomDressing.HEADROOM + CHANDELIER_DEPTH)
	if hub.y > top.y - CHANDELIER_RISE:
		return
	var canopy := Transform3D(Basis.IDENTITY, top + Vector3.DOWN * 0.03)
	mesh.turned_box(canopy, Vector3(0.22, 0.06, 0.22), _gilt, 0)
	mesh.beam(top, hub + Vector3.UP * 0.1, Vector2.ONE * 0.03, _gilt, 0)
	mesh.model(ShipModel.named(CHANDELIER_MODEL), Transform3D(Basis.IDENTITY, hub))


## The boat-deck landing's glass dome over [param room]'s middle: a disc of glass under
## its roof in a white rim, a white coaming stepped down round it, iron ribs across it.
func _dome(mesh: ShipMesh, room: ShipRoom) -> void:
	var middle := room.area.get_center()
	var top := RoomDressing.under_ceiling(_space, room, middle)
	if top.y - 0.1 < room.floor_height + RoomDressing.HEADROOM + 0.1:
		return
	var glass := top + Vector3.DOWN * 0.012
	RoomDressing.disc(mesh, glass, Vector3.DOWN, DOME, ShipPaints.glass_in, 8)
	var rim := top + Vector3.DOWN * 0.02
	var coaming := DOME + 0.12
	RoomDressing.ring(mesh, rim, Vector3.DOWN, DOME - 0.04, coaming, _white, 8)
	var step := top + Vector3.DOWN * 0.1
	RoomDressing.ring(mesh, step, Vector3.DOWN, coaming, coaming + 0.25, _white, 8)
	# The coaming's inside, from the step up to the rim, facing in.
	var axes := RoomDressing.across(Vector3.DOWN)
	for index in 8:
		var a := axes[0] * cos(TAU * index / 8.0) + axes[1] * sin(TAU * index / 8.0)
		var b := axes[0] * cos(TAU * (index + 1) / 8.0) + axes[1] * sin(TAU * (index + 1) / 8.0)
		var low_a := step + a * coaming
		var low_b := step + b * coaming
		var rise := rim - step
		mesh.quad(low_a, low_b, low_b + rise, low_a + rise, -(a + b).normalized(), _white, 0)
	for rib in 4:
		var out := Vector3(cos(PI * rib / 4.0), 0.0, sin(PI * rib / 4.0)) * DOME
		var under := glass + Vector3.DOWN * 0.015
		mesh.beam(under - out, under + out, Vector2(0.04, 0.025), ShipPaints.dark, 0)
