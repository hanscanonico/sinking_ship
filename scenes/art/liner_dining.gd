class_name LinerDining
extends RefCounted
## A liner's dining saloon (RoomDressing.Kind.DINING): her first-, second- and
## third-class dining saloons, dressed by rule from their walls and their area, never
## by hand. Every one is lined in white enamel over a plank floor, takes curtains at
## its glass and pilasters along each full wall. The first-class saloon — the one whose
## name says "first" — is the grand one: a carpet wall to wall, pilasters on a
## FIRST_PITCH, a sideboard flat on each inside wall run long enough for one, a sconce
## in each bay between the pilasters, and overhead a coffered ceiling with a
## chandelier round each of the pendants it is lit by. The others are plainer:
## pilasters on a PLAIN_PITCH, a serving hatch on the wall nearest the galley, a clock
## on the forward wall, fire buckets on a shelf on a side wall, and the pendants.
## Its tables are drawn on their blockers' footprints (tables()), every one inside its
## box and solid on each side up to its top, as art-lint holds every blocker drawn: a
## square table is laid — a white cloth hanging to HEM, a dark chair tucked under each
## of its edges and a plate before each — and a long one is a bare mess table of planks
## with a bench along each side. Nothing of a table stands out of its box, nor more
## than SETTING over its top, where a body on it stands (D6: no box ever grows to fit).
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6). What
## hangs overhead hangs as high as the ceiling lets it, no lower than CLEAR_HIGH where
## it can, over the head of a body standing on a table.

## How far apart the pilasters stand along a wall, about: in the first-class saloon
## and in the others.
const FIRST_PITCH := 3.0
const PLAIN_PITCH := 4.0
## A pilaster's width along its wall and how far it stands out; its capital's.
const PILASTER := Vector2(0.3, 0.1)
const CAPITAL := Vector2(0.38, 0.115)
const CAPITAL_HEIGHT := 0.18
## A sideboard flat on its wall: its length, its depth, its height; and the shortest
## wall run that takes one.
const SIDEBOARD := Vector3(1.8, 0.115, 1.0)
const SIDEBOARD_RUN := 3.0
## A sconce's height over the floor, the globe's half size and how far out it stands.
const SCONCE_HEIGHT := 1.6
const SCONCE_GLOBE := 0.035
const SCONCE_OUT := 0.075
## Its model, its origin on the wall's face at its plate's middle, SCONCE_HEIGHT over
## the floor; its globe's middle SCONCE_LIFT over that.
const SCONCE_MODEL := "sconce_globe"
const SCONCE_LIFT := 0.03
## A coffered ceiling: about how far apart its girders stand, how deep and how wide.
const COFFER := 3.0
const COFFER_DEPTH := 0.24
const COFFER_WIDTH := 0.2
## How high over its floor what hangs overhead keeps, where the ceiling lets it: over
## a head on a table (HEADROOM over a table's top).
const CLEAR_HIGH := RoomDressing.HEADROOM + 0.75
## A chandelier round a pendant: its hoop's radius and width, how many drops on it.
const HOOP := 0.42
const HOOP_WIDTH := 0.07
const DROPS := 6
## A serving hatch: its half size and its middle's height over the floor.
const HATCH := Vector2(0.55, 0.35)
const HATCH_HEIGHT := 1.3
## The clock's middle's height over the floor and its radius.
const CLOCK_HEIGHT := 2.05
const CLOCK := 0.16
## A table: how far its cloth or its apron stands in from its box's sides, within
## art-lint's margin, so a chair's back or a bench shows proud of it inside the box;
## how far over the floor a laid table's cloth hangs; a long table is one at least
## LONG times as long as it is wide.
const CLOTH_IN := 0.035
const HEM := 0.15
const LONG := 2.0
## A chair tucked under a laid table's edge: its back's width and depth, how far under
## the table's top it stops, and the plate before it — its radius, how far in from the
## edge its middle stands, how far over the cloth it lies (no more than SETTING).
const CHAIR := Vector2(0.44, 0.03)
const CHAIR_UNDER := 0.03
const PLATE := 0.11
const PLATE_IN := 0.26
const SETTING := 0.004
## A mess table: its top's thickness, its bench's depth and seat height, and how high
## over the floor its apron's foot stands.
const BOARD := 0.05
const BENCH := Vector2(0.28, 0.45)
const APRON_FOOT := 0.53
## The most triangles one table and what stands in its box may draw.
const TABLE_BUDGET := 60
## How far along a wall either side of a pane a piece keeps clear of it.
const GLASS_CLEAR := CabinDressing.GLASS_CLEAR

const WHITE_ENAMEL := Color("f1ede2")
const WHITE_CEILING := Color("f4f1e8")
const PLANKS := Color("9a6f48")
const CARPET := Color("a8463c")
const GILT := Color("c9a55a")
const SCONCE_GLASS := Color("fff0c8")
const HATCH_SHUTTER := Color("8a6a48")
const CHINA := Color("dce3ec")
const DEAL := Color("d2b98e")

## The saloons' linings (RoomDressing.Part): white enamel walls, a plank floor, a
## white ceiling on white beams.
static var wall_paint := ShipMesh.Paint.new(
	ShipMesh.Finish.HOUSE, ArtPalette.HOUSE, ShipMesh.Finish.CABIN, WHITE_ENAMEL
)
static var floor_paint := ShipMesh.Paint.new(
	ShipMesh.Finish.DECK, ArtPalette.DECK, ShipMesh.Finish.DECK, PLANKS
)
static var ceiling_paint := ShipMesh.Paint.new(
	ShipMesh.Finish.PLAIN, ArtPalette.CEILING, ShipMesh.Finish.PLAIN, WHITE_CEILING
)
static var beam_paint := ShipMesh.Paint.new(
	ShipMesh.Finish.PLAIN, ArtPalette.BEAM, ShipMesh.Finish.PLAIN, WHITE_CEILING
)
## What the pieces are made of.
static var white := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, WHITE_CEILING)
static var carpet := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, CARPET)
static var gilt := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, GILT)
static var sconce_glass := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, SCONCE_GLASS)
static var shutter := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, HATCH_SHUTTER)
static var curtain := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.SALOON_CURTAIN)
static var china := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, CHINA)
static var deal := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, DEAL)

var _space: ShipSpace
var _cabins: CabinDressing


func _init(space: ShipSpace, cabins: CabinDressing) -> void:
	_space = space
	_cabins = cabins


## Whether [param room], a dining saloon, is the first-class one: what its name says.
static func first_class(room: ShipRoom) -> bool:
	return String(room.name).to_lower().contains("first")


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for pane: Array in glass:
		if not pane[3]:
			CabinDressing.curtains(mesh, pane[1], pane[2], curtain)
	var first := first_class(room)
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		_wall(mesh, wall, first, glass)
	if first:
		_carpet(mesh, room)
		_coffers(mesh, room)
		for hang: Vector3 in _hangs(room):
			_chandelier(mesh, hang)
	else:
		_service(mesh, room, glass)
	tables(mesh, room)


## [param room]'s furniture (ShipSpace.furniture()), into [param mesh]: each table
## laid (laid_table()) or a mess table (mess_table()) by its shape, anything else as
## FurnitureDressing draws it.
func tables(mesh: ShipMesh, room: ShipRoom) -> void:
	var others: Array[ShipBlocker] = []
	for blocker: ShipBlocker in _space.furniture(room):
		if FurnitureDressing.piece_of(blocker) != FurnitureDressing.Piece.TABLE:
			others.append(blocker)
		elif long_table(blocker.area):
			mess_table(mesh, blocker.area, blocker.bottom, blocker.top)
		else:
			laid_table(mesh, blocker.area, blocker.bottom, blocker.top)
	FurnitureDressing.build(mesh, room, others)


## Whether a table over [param area] is a long one: a mess table's.
static func long_table(area: Rect2) -> bool:
	return maxf(area.size.x, area.size.y) >= LONG * minf(area.size.x, area.size.y)


## A laid table over [param area] from [param bottom] to [param top]: a white cloth
## CLOTH_IN inside its sides from HEM over the floor to its top, under each edge a dark
## chair tucked in — its back flush with the box's side, from the floor to CHAIR_UNDER
## under the top — and before each chair a plate lying on the cloth.
static func laid_table(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	var cloth := area.grow(-CLOTH_IN)
	_box(mesh, cloth, bottom + HEM, top, ShipPaints.linen, ShipMesh.SIDES | ShipMesh.TOP)
	var middle := area.get_center()
	var half := area.size * 0.5
	for side: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var reach := absf(side.dot(half))
		var along := Vector2(absf(side.y), absf(side.x))
		var edge := middle + side * (reach - ShipMesh.SLIVER - CHAIR.y * 0.5)
		var size := along * CHAIR.x + Vector2(absf(side.x), absf(side.y)) * CHAIR.y
		var back := Rect2(edge - size * 0.5, size)
		var faces := ShipMesh.TOP | _facing(side) | _facing(along) | _facing(-along)
		_box(mesh, back, bottom, top - CHAIR_UNDER, ShipPaints.frame, faces)
		var plate := middle + side * (reach - PLATE_IN)
		_plate(mesh, Vector3(plate.x, top + SETTING, plate.y), PLATE, china)


## A mess table over [param area] from [param bottom] to [param top]: a bare board of
## scrubbed deal over an apron CLOTH_IN inside its sides from APRON_FOOT up, a bench along
## each of its long sides from the floor to its seat of deal, and a trestle's foot across each
## end between them.
static func mess_table(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	_box(mesh, area, top - BOARD, top, deal, ShipMesh.SIDES | ShipMesh.TOP)
	var apron := area.grow(-CLOTH_IN)
	_box(mesh, apron, bottom + APRON_FOOT, top - BOARD, ShipPaints.frame, ShipMesh.SIDES)
	var along_x := area.size.x >= area.size.y
	var across := Vector2.DOWN if along_x else Vector2.RIGHT
	var middle := area.get_center()
	var depth := absf(across.dot(area.size))
	var length := absf((Vector2.ONE - across).dot(area.size))
	var seat := bottom + BENCH.y
	for side: float in [-1.0, 1.0]:
		var at := middle + across * side * (depth - BENCH.x) * 0.5
		var size := (Vector2.ONE - across) * length + across * BENCH.x
		var bench := Rect2(at - size * 0.5, size)
		_box(mesh, bench, bottom, seat, ShipPaints.teak, ShipMesh.SIDES)
		_box(mesh, bench, bottom, seat, deal, ShipMesh.TOP)
	var gap := depth - BENCH.x * 2.0
	var ends := Vector2.ONE - across
	for side: float in [-1.0, 1.0]:
		var at := middle + ends * side * (length * 0.5 - CLOTH_IN)
		var size := across * gap + ends * CHAIR.y
		_box(
			mesh, Rect2(at - size * 0.5, size), bottom, seat, ShipPaints.frame, _facing(ends * side)
		)


## The face of a box facing [param side] in the ship plane (ShipMesh.POS_X…).
static func _facing(side: Vector2) -> int:
	if side.x > 0.5:
		return ShipMesh.POS_X
	if side.x < -0.5:
		return ShipMesh.NEG_X
	return ShipMesh.POS_Z if side.y > 0.5 else ShipMesh.NEG_Z


## A box over [param area] from [param bottom] to [param top], the [param faces] of it
## (ShipMesh.TOP…), each one quad uncut at ShipMesh's chunk lines and unrimmed — a
## table is drawn in a few triangles.
static func _box(
	mesh: ShipMesh, area: Rect2, bottom: float, top: float, paint: ShipMesh.Paint, faces: int
) -> void:
	var x0 := area.position.x
	var x1 := area.end.x
	var z0 := area.position.y
	var z1 := area.end.y
	var up := Vector3.UP * (top - bottom)
	if faces & ShipMesh.TOP:
		var a := Vector3(x0, top, z0)
		var c := Vector3(x1, top, z1)
		mesh.quad(a, Vector3(x1, top, z0), c, Vector3(x0, top, z1), Vector3.UP, paint, 0)
	var sides: Array[Array] = [
		[ShipMesh.POS_X, Vector3(x1, bottom, z0), Vector3(x1, bottom, z1), Vector3.RIGHT],
		[ShipMesh.NEG_X, Vector3(x0, bottom, z0), Vector3(x0, bottom, z1), Vector3.LEFT],
		[ShipMesh.POS_Z, Vector3(x0, bottom, z1), Vector3(x1, bottom, z1), Vector3.BACK],
		[ShipMesh.NEG_Z, Vector3(x0, bottom, z0), Vector3(x1, bottom, z0), Vector3.FORWARD],
	]
	for side: Array in sides:
		if faces & (side[0] as int):
			var a: Vector3 = side[1]
			var b: Vector3 = side[2]
			mesh.quad(a, b, b + up, a + up, side[3], paint, 0)


## A plate lying at [param centre], [param radius] across: a flat hexagon of four
## triangles.
static func _plate(mesh: ShipMesh, centre: Vector3, radius: float, paint: ShipMesh.Paint) -> void:
	var ring := PackedVector3Array()
	for index in 6:
		var turn := TAU * index / 6.0
		ring.append(centre + Vector3(cos(turn), 0.0, sin(turn)) * radius)
	var none := PackedFloat32Array([0.0, 0.0, 0.0])
	for index in range(1, 5):
		var corners := PackedVector3Array([ring[0], ring[index], ring[index + 1]])
		mesh.triangle(corners, none, Vector3.UP, paint)


## The lights [param room] is lit by: in the first-class saloon a pendant at the heart
## of each chandelier, where RoomDressing would hang its own — as many, so its light
## costs no more; none, keeping RoomDressing's pendants, in the others.
func lights(room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	if first_class(room):
		for hang: Vector3 in _hangs(room):
			found.append(RoomDressing.Light.new(hang, ShipLamp.Kind.PENDANT))
	return found


## What a dining saloon lines its walls, floor, ceiling and beams with
## (RoomDressing.Part): white enamel, planks, a white ceiling and beams.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = [wall_paint, floor_paint, ceiling_paint, beam_paint]
	return paints


## Where along [param wall] its pilasters stand, from end to end of it about
## [param pitch] apart — an odd number of bays between them when [param odd], so a
## bay is in its middle — each a pilaster's half width in from its ends.
static func pilasters(wall: RoomDressing.Wall, pitch: float, odd: bool) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	var from := wall.from + PILASTER.x * 0.5
	var span := wall.length() - PILASTER.x
	if span <= 0.0:
		return found
	var count := maxi(1, roundi(span / pitch))
	if odd and count % 2 == 0:
		count += 1 if span / pitch > count else -1
	for index in count + 1:
		found.append(from + span * index / count)
	return found


## The middle of each bay between [param posts] (pilasters()).
static func bays(posts: PackedFloat32Array) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for index in posts.size() - 1:
		found.append((posts[index] + posts[index + 1]) * 0.5)
	return found


## [param wall]'s own: its pilasters, and in the first-class saloon a sideboard on an
## inside run long enough and a sconce in each bay.
func _wall(mesh: ShipMesh, wall: RoomDressing.Wall, first: bool, glass: Array[Array]) -> void:
	var posts := pilasters(wall, FIRST_PITCH if first else PLAIN_PITCH, first)
	if posts.size() < 2:
		return
	for along: float in posts:
		if _free(wall, along - CAPITAL.x * 0.5, along + CAPITAL.x * 0.5, glass):
			_pilaster(mesh, wall, along, first)
	if not first:
		return
	for along: float in bays(posts):
		if _free(wall, along - SCONCE_GLOBE, along + SCONCE_GLOBE, glass):
			_sconce(mesh, wall, along)
	var middle := wall.middle()
	var half := SIDEBOARD.x * 0.5
	if (
		wall.length() >= SIDEBOARD_RUN
		and not wall.outdoors_beyond()
		and _free(wall, middle - half, middle + half, glass)
	):
		_sideboard(mesh, wall, middle)


## Whether [param a]…[param b] along [param wall] is clear of its glass and of any
## stair beside it.
func _free(wall: RoomDressing.Wall, a: float, b: float, glass: Array[Array]) -> bool:
	var floor := wall.floor
	var beside := wall.rect(a, b, 0.0, 0.5)
	if RoomDressing.over_a_ramp(_space.layout, beside, floor - 0.01, floor + 2.5):
		return false
	for pane: Array in glass:
		if not (pane[2] as Vector3).is_equal_approx(wall.normal):
			continue
		var at := wall.right.dot((pane[1] as Vector3) - wall.at(0.0, 0.0))
		var reach: float = (pane[4] as Vector2).x + GLASS_CLEAR
		if b > at - reach and a < at + reach:
			return false
	return true


## A pilaster flat on [param wall] at [param along], from the floor to the ceiling:
## its shaft, and in the first-class saloon a gilt capital under the ceiling; none
## where no deck roofs the room by it. It stops at the wall's top where the wall stops
## short of the deck over it: a body may stand on a wall's top.
func _pilaster(mesh: ShipMesh, wall: RoomDressing.Wall, along: float, first: bool) -> void:
	# Under the deck over it a step in from the wall: none where no deck roofs it.
	var inside := wall.at(along, 0.0, 0.3)
	if _space.roof(wall.room, inside.x, inside.z) == -1:
		return
	var ceiling := _space.ceiling(wall.room, inside.x, inside.z) - ShipArt.PLANK
	var top := minf(ceiling, _wall_top(wall, along)) - wall.floor
	if top < RoomDressing.HEADROOM:
		return
	var half := PILASTER.x * 0.5
	_proud(mesh, wall, along - half, along + half, PILASTER.y, Vector2(0.0, top), white, false)
	if first:
		var capital := ShipModel.named(RoomDressing.variant(RoomDressing.CAPITALS, CAPITAL.x))
		mesh.model(capital, wall.place(wall.at(along, top)), {ShipPaints.white: gilt})


## How high [param wall] stands at [param along] it: the top of the highest wall
## standing on its floor there, the room's floor when none does.
func _wall_top(wall: RoomDressing.Wall, along: float) -> float:
	var inside := wall.at(along, 0.0, -ShipMesh.SLIVER * 2.0)
	var at := Vector2(inside.x, inside.z)
	var top := wall.floor
	for blocker: ShipBlocker in _space.layout.blockers:
		if not _space.is_wall(blocker) or blocker.bottom > wall.floor + 0.1:
			continue
		if blocker.area.grow(ShipMesh.SLIVER).has_point(at):
			top = maxf(top, blocker.top)
	return top


## A sconce flat on [param wall] at [param along] (SCONCE_MODEL): a gilt plate and a
## globe on it, lit by nothing but its own glow.
func _sconce(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var plate := wall.place(wall.at(along, SCONCE_HEIGHT))
	var paints := {ShipPaints.gilt: gilt, ShipPaints.sconce_glass: sconce_glass}
	mesh.model(ShipModel.named(SCONCE_MODEL), plate, paints)


## A sideboard flat on [param wall] at [param along]: a white cabinet of three doors
## under a gilt top.
func _sideboard(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var half := SIDEBOARD.x * 0.5
	var body := wall.rect(along - half, along + half, 0.0, SIDEBOARD.y - 0.01)
	RoomDressing.block(mesh, body, wall.floor, wall.floor + SIDEBOARD.z - 0.04, white)
	var top := wall.rect(along - half, along + half, 0.0, SIDEBOARD.y)
	var lid := wall.floor + SIDEBOARD.z
	RoomDressing.block(mesh, top, lid - 0.04, lid, gilt)
	for door in 3:
		var at := along + (door - 1) * SIDEBOARD.x / 3.0
		var face := wall.at(at, (SIDEBOARD.z - 0.04) * 0.5, SIDEBOARD.y - 0.005)
		var size := Vector2(SIDEBOARD.x / 6.0 - 0.04, (SIDEBOARD.z - 0.04) * 0.5 - 0.06)
		RoomDressing.panel(mesh, face, wall.right, size, wall.normal, ShipPaints.teak, 0)


## A carpet over [param room]'s floor, wall to wall, unless a stair stands in it: a
## piece to each of ShipMesh's chunks it lies in, uncut at the room lines.
func _carpet(mesh: ShipMesh, room: ShipRoom) -> void:
	var floor := room.floor_height
	var area := room.area.grow(-0.02)
	if RoomDressing.over_a_ramp(_space.layout, area, floor - 0.01, floor + 2.5):
		return
	var chunk := Vector2(ShipMesh.CHUNK.x, ShipMesh.CHUNK.z)
	var y := floor + 0.008
	var x := area.position.x
	while x < area.end.x - ShipMesh.SLIVER:
		var x_to := minf(area.end.x, (floorf(x / chunk.x) + 1.0) * chunk.x)
		var z := area.position.y
		while z < area.end.y - ShipMesh.SLIVER:
			var z_to := minf(area.end.y, (floorf(z / chunk.y) + 1.0) * chunk.y)
			var a := Vector3(x, y, z)
			var c := Vector3(x_to, y, z_to)
			mesh.quad(a, Vector3(x_to, y, z), c, Vector3(x, y, z_to), Vector3.UP, carpet, 0)
			z = z_to
		x = x_to


## A coffered ceiling over [param room]: girders across and along it about COFFER
## apart, cut into bays so each chandelier (_hangs()) hangs in the middle of one,
## each bay's girder under the ceiling over it, where a deck roofs it and the girder
## keeps over CLEAR_HIGH.
func _coffers(mesh: ShipMesh, room: ShipRoom) -> void:
	var area := room.area
	var cuts := Vector2i(_coffer_bays(area.size.x), _coffer_bays(area.size.y))
	var grid := Vector2(cuts)
	for line in range(1, cuts.x):
		for bay in cuts.y:
			var from := area.position + area.size * Vector2(line, bay) / grid
			var to := area.position + area.size * Vector2(line, bay + 1) / grid
			_girder(mesh, room, from, to)
	for line in range(1, cuts.y):
		for bay in cuts.x:
			var from := area.position + area.size * Vector2(bay, line) / grid
			var to := area.position + area.size * Vector2(bay + 1, line) / grid
			_girder(mesh, room, from, to)


## How many coffers across [param size] of a room: an odd number to each of
## RoomDressing's lamp squares (lights()), each about COFFER.
static func _coffer_bays(size: float) -> int:
	var squares := maxi(1, ceili(size / RoomDressing.LAMP_SPACING))
	var each := size / squares / COFFER
	var odd := maxi(1, roundi((each - 1.0) * 0.5) * 2 + 1)
	return squares * odd


## A girder of the coffered ceiling under [param room]'s ceiling from [param from] to
## [param to] (ship plane, along x or z): its underside and its sides.
func _girder(mesh: ShipMesh, room: ShipRoom, from: Vector2, to: Vector2) -> void:
	var middle := (from + to) * 0.5
	if _space.roof(room, middle.x, middle.y) == -1:
		return
	var top := _space.ceiling(room, middle.x, middle.y) - ShipArt.PLANK
	var bottom := top - COFFER_DEPTH
	if bottom < room.floor_height + CLEAR_HIGH:
		return
	var along := (to - from).normalized()
	var side := Vector2(-along.y, along.x) * COFFER_WIDTH * 0.5
	var a := Vector3(from.x - side.x, bottom, from.y - side.y)
	var b := Vector3(to.x - side.x, bottom, to.y - side.y)
	var c := Vector3(to.x + side.x, bottom, to.y + side.y)
	var d := Vector3(from.x + side.x, bottom, from.y + side.y)
	var up := Vector3.UP * COFFER_DEPTH
	var out := Vector3(side.x, 0.0, side.y).normalized()
	mesh.quad(a, b, c, d, Vector3.DOWN, white, 0)
	mesh.quad(a, b, b + up, a + up, -out, white, 0)
	mesh.quad(d, c, c + up, d + up, out, white, 0)


## Where under [param room]'s ceiling the first-class saloon's chandeliers hang: where
## RoomDressing hangs its pendants, the middle of each LAMP_SPACING square.
func _hangs(room: ShipRoom) -> Array[Vector3]:
	var area := room.area
	var spacing := RoomDressing.LAMP_SPACING
	var across := Vector2i(
		maxi(1, ceili(area.size.x / spacing)), maxi(1, ceili(area.size.y / spacing))
	)
	var found: Array[Vector3] = []
	for i in across.x:
		for j in across.y:
			var share := Vector2((i + 0.5) / across.x, (j + 0.5) / across.y)
			found.append(
				RoomDressing.under_ceiling(_space, room, area.position + area.size * share)
			)
	return found


## A chandelier round the pendant hung from [param hang]: a gilt hoop at its globe's
## height on three chains from the ceiling, glass drops standing round it.
func _chandelier(mesh: ShipMesh, hang: Vector3) -> void:
	var hoop := hang - Vector3.UP * (ShipLamp.CORD + 0.03)
	var inner := HOOP - HOOP_WIDTH
	RoomDressing.ring(mesh, hoop, Vector3.DOWN, inner, HOOP, gilt, DROPS)
	RoomDressing.ring(mesh, hoop + Vector3.UP * 0.012, Vector3.UP, inner, HOOP, gilt, DROPS)
	var middle := HOOP - HOOP_WIDTH * 0.5
	for drop in DROPS:
		var turn := TAU * (drop + 0.5) / DROPS
		var out := Vector3(cos(turn), 0.0, sin(turn)) * middle
		var place := Transform3D(Basis.IDENTITY, hoop + out + Vector3.UP * 0.07)
		mesh.turned_box(place, Vector3(0.05, 0.11, 0.05), sconce_glass, 0)
	for chain in 3:
		var turn := TAU * chain / 3.0
		var out := Vector3(cos(turn), 0.0, sin(turn))
		mesh.beam(hoop + out * middle, hang + out * 0.12, Vector2.ONE * 0.012, gilt, 0)


## A plain saloon's own: a serving hatch on the wall nearest the galley, a clock on
## the forward wall and fire buckets on the longest side wall with no stair beside it,
## each in the middle of a bay between its pilasters.
func _service(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var galley := _galley()
	var nearest: RoomDressing.Wall = null
	var forward: RoomDressing.Wall = null
	var side: RoomDressing.Wall = null
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.length() < (HATCH.x + PILASTER.x) * 2.0:
			continue
		if galley != null and not wall.outdoors_beyond():
			if nearest == null or _from_galley(wall, galley) < _from_galley(nearest, galley):
				nearest = wall
		if wall.side == 1 and (forward == null or wall.length() > forward.length()):
			forward = wall
		if wall.side % 2 == 0 and _free(wall, wall.from, wall.to, []):
			if side == null or wall.length() > side.length():
				side = wall
	if nearest != null:
		var along := _bay_by_middle(nearest)
		if _free(nearest, along - HATCH.x, along + HATCH.x, glass):
			_hatch(mesh, nearest, along)
	if forward != null:
		var along := _bay_by_middle(forward)
		if _free(forward, along - CLOCK, along + CLOCK, glass):
			_clock(mesh, forward, along)
	if side != null:
		RoomDressing.fire_buckets(mesh, side, _bay_by_middle(side))


## The ship's galley; null when she has none.
func _galley() -> ShipRoom:
	for room: ShipRoom in _space.layout.rooms:
		if String(room.name).to_lower().contains("galley"):
			return room
	return null


## How far [param wall]'s middle stands from [param galley]'s, in the ship plane.
static func _from_galley(wall: RoomDressing.Wall, galley: ShipRoom) -> float:
	var middle := wall.at(wall.middle(), 0.0)
	return Vector2(middle.x, middle.z).distance_to(galley.area.get_center())


## The middle of the bay between [param wall]'s plain pilasters nearest its middle.
static func _bay_by_middle(wall: RoomDressing.Wall) -> float:
	var best := wall.middle()
	var gap := INF
	for along: float in bays(pilasters(wall, PLAIN_PITCH, false)):
		if absf(along - wall.middle()) < gap:
			gap = absf(along - wall.middle())
			best = along
	return best


## A serving hatch in [param wall] at [param along]: a frame round two shutters
## drawn down, over a narrow sill.
func _hatch(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var centre := wall.at(along, HATCH_HEIGHT, 0.01)
	var rim := HATCH + Vector2.ONE * 0.06
	RoomDressing.panel(mesh, centre, wall.right, rim, wall.normal, ShipPaints.frame, 0)
	for half: float in [-1.0, 1.0]:
		var at := centre + wall.normal * 0.02 + wall.right * half * HATCH.x * 0.5
		var size := Vector2(HATCH.x * 0.5 - 0.02, HATCH.y)
		RoomDressing.panel(mesh, at, wall.right, size, wall.normal, shutter, 0)
	var sill := wall.rect(along - rim.x, along + rim.x, 0.0, 0.05)
	var low := wall.floor + HATCH_HEIGHT - rim.y
	RoomDressing.block(mesh, sill, low - 0.03, low, ShipPaints.frame)


## A clock flat on [param wall] at [param along] (RoomDressing.CLOCK_MODEL): a white
## dial in a brass bezel, with its hands.
func _clock(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var face := Transform3D(RoomDressing.facing(wall.normal), wall.at(along, CLOCK_HEIGHT))
	mesh.model(ShipModel.named(RoomDressing.CLOCK_MODEL), face)


## A box flat on [param wall] from [param a] to [param b] along it, [param out] from
## its face and [param span].x to [param span].y over the floor: its front and its
## ends, and its underside when [param under] says — no face against the wall or the
## ceiling it stands on.
static func _proud(
	mesh: ShipMesh,
	wall: RoomDressing.Wall,
	a: float,
	b: float,
	out: float,
	span: Vector2,
	paint: ShipMesh.Paint,
	under: bool
) -> void:
	var low_a := wall.at(a, span.x)
	var low_b := wall.at(b, span.x)
	var front_a := wall.at(a, span.x, out)
	var front_b := wall.at(b, span.x, out)
	var up := Vector3.UP * (span.y - span.x)
	mesh.quad(front_a, front_b, front_b + up, front_a + up, wall.normal, paint, 0)
	mesh.quad(low_a, front_a, front_a + up, low_a + up, -wall.right, paint, 0)
	mesh.quad(low_b, front_b, front_b + up, low_b + up, wall.right, paint, 0)
	if under:
		mesh.quad(low_a, low_b, front_b, front_a, Vector3.DOWN, paint, 0)
