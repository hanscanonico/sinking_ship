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
## Its tables are not drawn here yet: mid-room furniture stands only in a blocker's
## footprint, and the tables' blockers are sim data (D6) a later slice lays — it draws
## them on their footprints in tables().
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
## How far along a wall either side of a pane a piece keeps clear of it.
const GLASS_CLEAR := CabinDressing.GLASS_CLEAR

const WHITE_ENAMEL := Color("f1ede2")
const WHITE_CEILING := Color("f4f1e8")
const PLANKS := Color("9a6f48")
const CARPET := Color("7a2a2c")
const GILT := Color("c9a55a")
const SCONCE_GLASS := Color("fff0c8")
const HATCH_SHUTTER := Color("8a6a48")

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


## [param room]'s tables, into [param mesh]: none yet — they stand on blockers a
## later slice lays, and draws here on their footprints.
func tables(_mesh: ShipMesh, _room: ShipRoom) -> void:
	pass


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
		var cap := CAPITAL.x * 0.5
		var span := Vector2(top - CAPITAL_HEIGHT, top)
		_proud(mesh, wall, along - cap, along + cap, CAPITAL.y, span, gilt, true)


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


## A sconce flat on [param wall] at [param along]: a gilt plate and a globe on it,
## lit by nothing but its own glow.
func _sconce(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var plate := wall.at(along, SCONCE_HEIGHT, 0.006)
	RoomDressing.panel(mesh, plate, wall.right, Vector2(0.05, 0.09), wall.normal, gilt, 0)
	var globe := wall.at(along, SCONCE_HEIGHT + 0.03, SCONCE_OUT)
	var size := Vector3.ONE * SCONCE_GLOBE * 2.0
	mesh.turned_box(wall.place(globe), size, sconce_glass, 0)


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


## A clock flat on [param wall] at [param along]: a white face in a brass rim, with
## its hands.
func _clock(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var face := wall.at(along, CLOCK_HEIGHT, 0.03)
	var rim := face + wall.normal * 0.004
	RoomDressing.disc(mesh, face, wall.normal, CLOCK * 0.82, ShipPaints.enamel, 8)
	RoomDressing.ring(mesh, rim, wall.normal, CLOCK * 0.78, CLOCK, ShipPaints.brass, 8)
	var hands := face + wall.normal * 0.008
	var size := Vector2(0.012, 0.004)
	mesh.beam(hands, hands + Vector3.UP * CLOCK * 0.6, size, ShipPaints.dark, 0)
	var minute := hands + (wall.right * 0.7 - Vector3.UP * 0.4).normalized() * CLOCK * 0.45
	mesh.beam(hands, minute, size, ShipPaints.dark, 0)


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
