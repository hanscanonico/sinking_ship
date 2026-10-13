class_name LinerBath
extends RefCounted
## A liner's baths (RoomDressing.Kind.BATH), both lined in white glazed tile over a
## pale tiled floor. The swimming bath's pool — the box the layout stands on its floor
## (is_pool()) — is drawn as what it is: tiled sides with a blue course under a tiled
## rim, and inside the rim the water, brimming WATER_DOWN under the rim's top (art-lint
## probes the box's top all over, the water too, and wants a face within 5 cm of it
## everywhere), a brass ladder's handles over the rim at its aft end; round its walls a
## blue course of tile and a skirting, and a clock. The Turkish bath — her cooling room —
## is tiled in deep blue inside green borders to a dado, arched niches over it on its
## inside walls, a green frieze over HEADROOM under the ceiling, and a bronze lantern
## round each of its pendants. Any other box on a bath's floor is FurnitureDressing's.
## No mid-room furniture: the pool is the one box on a bath's floor, and no blocker is
## ever widened or added to hold a piece (D6). Between a step over the floor and a
## body's height, nothing it draws stands more than FurnishingCheck.TOLERANCE (0.12 m)
## out from a wall; over HEADROOM (1.85 m) anything may, and so may anything standing
## inside a BOX blocker's footprint — art-lint holds it to that. Nothing is drawn
## beside a stair or across a pane.

const FINISH := ShipMesh.Finish
const HEADROOM := RoomDressing.HEADROOM
## A box on a bath's floor at least this broad both ways is its pool.
const POOL_WIDTH := 2.0
## The pool: its rim's width, how far under the rim's top the water stands — within
## art-lint's 5 cm of the box's top, which it probes over the water too — and the blue
## course round its sides, from and to how far under the rim.
const RIM := 0.3
const WATER_DOWN := 0.035
const POOL_COURSE := Vector2(0.14, 0.08)
## How far outside the box a face drawn on its side stands: inside art-lint's margin.
const FLUSH := 0.001
## The ladder's handles: how far apart, how high over the rim — under a step, so a body
## on the rim never meets them — how far back over it, and their bar's side.
const LADDER_SPAN := 0.45
const HANDLE := 0.2
const HANDLE_BACK := 0.16
const HANDLE_BAR := 0.035
## The swimming bath's blue course of tile round its walls: its middle's height over
## the floor, its half height; its skirting's height; how far out tile stands.
const COURSE_HEIGHT := 1.25
const COURSE := 0.04
const SKIRTING := 0.15
const TILE_OUT := 0.006
## How long a bay of tiling along a wall is at most, so no mesh it joins outgrows its
## chunk (ShipMesh).
const BAY := 1.2
## The clock's middle's height over the floor and its radius.
const CLOCK_HEIGHT := 2.05
const CLOCK := 0.16
## The Turkish bath's dado: how high, and the green border round each bay's blue field.
const DADO := 1.0
const BORDER := 0.06
## Its niches: how wide, from and to how high (the arch's foot), the arch's rise, the
## bronze frame's side and how far it stands out, and about how far apart they stand.
const NICHE_WIDTH := 0.5
const NICHE := Vector2(1.1, 1.65)
const ARCH := 0.22
const FRAME := 0.04
const FRAME_OUT := 0.05
const NICHE_PITCH := 3.6
## Its frieze over HEADROOM: from how high over the floor, how deep at most, how far out.
const FRIEZE := 1.95
const FRIEZE_DEPTH := 0.32
const FRIEZE_OUT := 0.05
## A bronze lantern round each pendant: its hoop's radius and width, how far under the
## globe's middle it hangs, how many sides.
const LANTERN := 0.2
const LANTERN_WIDTH := 0.05
const LANTERN_DROP := 0.1
const LANTERN_SIDES := 8

## The colours of the baths: white glazed tile on the walls, pale tile underfoot, the
## blue course; the water; the Turkish bath's deep blue and green tile, and bronze.
const TILE := Color("e9e6dc")
const FLOOR_TILE := Color("cfc8b4")
const TILE_COURSE := Color("2f5f86")
const WATER := Color("5aaebb")
const MOORISH_BLUE := Color("1f3f6e")
const MOORISH_GREEN := Color("2f6a55")
const NICHE_SHADOW := Color("1a2a33")
const BRONZE := Color("8c6a3a")

## The baths' linings (RoomDressing.Part): white tile walls over a pale tiled floor.
static var tile := ShipMesh.Paint.new(FINISH.HOUSE, ArtPalette.HOUSE, FINISH.PLAIN, TILE)
static var floor_tile := ShipMesh.Paint.new(FINISH.DECK, ArtPalette.DECK, FINISH.PLAIN, FLOOR_TILE)
## What the pieces are made of.
static var white_tile := ShipMesh.Paint.new(FINISH.PLAIN, TILE)
static var course := ShipMesh.Paint.new(FINISH.PLAIN, TILE_COURSE)
static var water := ShipMesh.Paint.new(FINISH.PLAIN, WATER)
static var moorish_blue := ShipMesh.Paint.new(FINISH.PLAIN, MOORISH_BLUE)
static var moorish_green := ShipMesh.Paint.new(FINISH.PLAIN, MOORISH_GREEN)
static var niche_shadow := ShipMesh.Paint.new(FINISH.PLAIN, NICHE_SHADOW)
static var bronze := ShipMesh.Paint.new(FINISH.PLAIN, BRONZE)

var _space: ShipSpace
var _cabins: CabinDressing


func _init(space: ShipSpace, cabins: CabinDressing) -> void:
	_space = space
	_cabins = cabins


## Whether [param room], a bath, is the Turkish bath: what its name says.
static func turkish(room: ShipRoom) -> bool:
	return String(room.name).to_lower().contains("turkish")


## Whether [param blocker], a box on a bath's floor, is its pool: broad both ways.
static func is_pool(blocker: ShipBlocker) -> bool:
	return minf(blocker.area.size.x, blocker.area.size.y) >= POOL_WIDTH


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()): its walls by its kind of bath, its pool, and any other box
## on its floor as FurnitureDressing draws it.
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var walls := RoomDressing.walls(_space, room)
	if turkish(room):
		for wall: RoomDressing.Wall in walls:
			_moorish_wall(mesh, wall, glass)
		for hang: Vector3 in _hangs(room):
			_lantern(mesh, room, hang)
	else:
		for wall: RoomDressing.Wall in walls:
			_course(mesh, wall, glass)
		_clock(mesh, walls, glass)
	var others: Array[ShipBlocker] = []
	for blocker: ShipBlocker in _space.furniture(room):
		if is_pool(blocker):
			pool(mesh, blocker.area, blocker.bottom, blocker.top)
		else:
			others.append(blocker)
	FurnitureDressing.build(mesh, room, others)


## A pool over [param area] from [param bottom] to [param top], all inside its box:
## tiled sides with a blue course under the rim, a tiled rim RIM wide, the water
## WATER_DOWN under the rim's top inside it, and a ladder's handles over the rim at
## its aft end.
static func pool(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	var water_top := top - WATER_DOWN
	mesh.box(area, bottom, top, white_tile, ShipMesh.SIDES)
	var band := area.grow(FLUSH)
	mesh.box(band, top - POOL_COURSE.x, top - POOL_COURSE.y, course, ShipMesh.SIDES)
	var inner := area.grow(-RIM)
	var x0 := area.position.x
	var z0 := area.position.y
	# The rim, a strip along each side: its top and its face into the water.
	var strips: Array[Array] = [
		[Rect2(x0, z0, area.size.x, RIM), ShipMesh.POS_Z],
		[Rect2(x0, inner.end.y, area.size.x, RIM), ShipMesh.NEG_Z],
		[Rect2(x0, inner.position.y, RIM, inner.size.y), ShipMesh.POS_X],
		[Rect2(inner.end.x, inner.position.y, RIM, inner.size.y), ShipMesh.NEG_X],
	]
	for strip: Array in strips:
		mesh.box(strip[0], water_top, top, white_tile, ShipMesh.TOP | (strip[1] as int))
	mesh.box(inner, water_top - 0.01, water_top, water, ShipMesh.TOP)
	# The ladder's handles: up out of the water by the aft end's inner face, over the
	# rim and down onto it.
	var middle := area.get_center().y
	var face := inner.position.x + HANDLE_BAR
	var section := Vector2.ONE * HANDLE_BAR
	for side: float in [-1.0, 1.0]:
		var z := middle + side * LADDER_SPAN * 0.5
		var high := Vector3(face, top + HANDLE, z)
		var back := Vector3(face - HANDLE_BACK, top + HANDLE, z)
		mesh.beam(Vector3(face, water_top, z), high, section, ShipPaints.brass, 0)
		mesh.beam(high, back, section, ShipPaints.brass, 0)
		mesh.beam(back, Vector3(back.x, top, z), section, ShipPaints.brass, 0)


## The swimming bath's [param wall]: a blue course of tile at COURSE_HEIGHT and a blue
## skirting, flat on it, a bay at a time — none where a pane or a stair is.
func _course(mesh: ShipMesh, wall: RoomDressing.Wall, glass: Array[Array]) -> void:
	for bay: Vector2 in _bays(wall):
		if not _free(wall, bay.x, bay.y, glass):
			continue
		var half := (bay.y - bay.x) * 0.5
		var along := (bay.x + bay.y) * 0.5
		var band := wall.at(along, COURSE_HEIGHT, TILE_OUT)
		RoomDressing.panel(mesh, band, wall.right, Vector2(half, COURSE), wall.normal, course, 0)
		var skirt := wall.at(along, SKIRTING * 0.5, TILE_OUT)
		var size := Vector2(half, SKIRTING * 0.5)
		RoomDressing.panel(mesh, skirt, wall.right, size, wall.normal, course, 0)


## A clock on the longest of [param walls] clear at its middle: a white face in a brass
## rim, with its hands.
func _clock(mesh: ShipMesh, walls: Array[RoomDressing.Wall], glass: Array[Array]) -> void:
	var best: RoomDressing.Wall = null
	for wall: RoomDressing.Wall in walls:
		var middle := wall.middle()
		if not _free(wall, middle - CLOCK, middle + CLOCK, glass):
			continue
		if best == null or wall.length() > best.length():
			best = wall
	if best == null:
		return
	var face := best.at(best.middle(), CLOCK_HEIGHT, 0.03)
	RoomDressing.disc(mesh, face, best.normal, CLOCK * 0.82, ShipPaints.enamel, 8)
	var rim := face + best.normal * 0.004
	RoomDressing.ring(mesh, rim, best.normal, CLOCK * 0.78, CLOCK, ShipPaints.brass, 8)
	var hands := face + best.normal * 0.008
	var size := Vector2(0.012, 0.004)
	mesh.beam(hands, hands + Vector3.UP * CLOCK * 0.6, size, ShipPaints.dark, 0)
	var minute := hands + (best.right * 0.7 - Vector3.UP * 0.4).normalized() * CLOCK * 0.45
	mesh.beam(hands, minute, size, ShipPaints.dark, 0)


## The Turkish bath's [param wall]: a dado of deep blue tile in green borders and a
## green frieze over HEADROOM under the ceiling, a bay at a time, and on an inside wall
## an arched niche about every NICHE_PITCH — none where a pane or a stair is.
func _moorish_wall(mesh: ShipMesh, wall: RoomDressing.Wall, glass: Array[Array]) -> void:
	for bay: Vector2 in _bays(wall):
		if not _free(wall, bay.x, bay.y, glass):
			continue
		var half := (bay.y - bay.x) * 0.5
		var along := (bay.x + bay.y) * 0.5
		var border := wall.at(along, DADO * 0.5, TILE_OUT)
		var size := Vector2(half, DADO * 0.5)
		RoomDressing.panel(mesh, border, wall.right, size, wall.normal, moorish_green, 0)
		var field := border + wall.normal * TILE_OUT
		size -= Vector2.ONE * BORDER
		RoomDressing.panel(mesh, field, wall.right, size, wall.normal, moorish_blue, 0)
		_frieze(mesh, wall, bay)
	if wall.outdoors_beyond():
		return
	var count := floori(wall.length() / NICHE_PITCH)
	for index in count:
		var along := wall.from + wall.length() * (index + 0.5) / count
		var half := NICHE_WIDTH * 0.5 + FRAME
		if _free(wall, along - half, along + half, glass):
			_niche(mesh, wall, along)


## The frieze along [param bay] of [param wall], from FRIEZE over the floor up to
## FRIEZE_DEPTH, no higher than the ceiling: its front, its underside and a bronze line
## along it; none where no deck roofs the room or the ceiling leaves no room for it.
func _frieze(mesh: ShipMesh, wall: RoomDressing.Wall, bay: Vector2) -> void:
	var inside := wall.at((bay.x + bay.y) * 0.5, 0.0, 0.3)
	if _space.roof(wall.room, inside.x, inside.z) == -1:
		return
	var ceiling := _space.ceiling(wall.room, inside.x, inside.z) - ShipArt.PLANK - wall.floor
	var top := minf(ceiling, FRIEZE + FRIEZE_DEPTH)
	if top - FRIEZE < 0.1:
		return
	var low_a := wall.at(bay.x, FRIEZE)
	var low_b := wall.at(bay.y, FRIEZE)
	var front_a := wall.at(bay.x, FRIEZE, FRIEZE_OUT)
	var front_b := wall.at(bay.y, FRIEZE, FRIEZE_OUT)
	var up := Vector3.UP * (top - FRIEZE)
	mesh.quad(front_a, front_b, front_b + up, front_a + up, wall.normal, moorish_green, 0)
	mesh.quad(low_a, low_b, front_b, front_a, Vector3.DOWN, bronze, 0)
	var line := wall.at((bay.x + bay.y) * 0.5, FRIEZE + 0.05, FRIEZE_OUT + 0.002)
	var half := Vector2((bay.y - bay.x) * 0.5, 0.012)
	RoomDressing.panel(mesh, line, wall.right, half, wall.normal, bronze, 0)


## An arched niche on [param wall] at [param along]: its shadowed back flat on the
## wall under a pointed head, and a bronze frame round it — two jambs, the arch's two
## sides and a sill.
func _niche(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var half := NICHE_WIDTH * 0.5
	var back := wall.at(along, (NICHE.x + NICHE.y) * 0.5, TILE_OUT)
	var size := Vector2(half, (NICHE.y - NICHE.x) * 0.5)
	RoomDressing.panel(mesh, back, wall.right, size, wall.normal, niche_shadow, 0)
	var crown := wall.at(along, NICHE.y + ARCH, TILE_OUT)
	var head := PackedVector3Array(
		[wall.at(along - half, NICHE.y, TILE_OUT), crown, wall.at(along + half, NICHE.y, TILE_OUT)]
	)
	mesh.triangle(head, PackedFloat32Array([0.0, 0.0, 0.0]), wall.normal, niche_shadow)
	var out := wall.normal * (FRAME_OUT - FRAME * 0.5)
	var section := Vector2.ONE * FRAME
	var top := crown - wall.normal * TILE_OUT + out
	for side: float in [-1.0, 1.0]:
		var at := along + side * (half + FRAME * 0.5)
		var jamb := wall.at(at, NICHE.y) + out
		mesh.beam(wall.at(at, NICHE.x - FRAME) + out, jamb, section, bronze, 0)
		mesh.beam(jamb, top, section, bronze, 0)
	var sill := wall.rect(along - half - FRAME, along + half + FRAME, 0.0, FRAME_OUT)
	RoomDressing.block(mesh, sill, wall.floor + NICHE.x - FRAME, wall.floor + NICHE.x, bronze)


## A bronze lantern round the pendant hung from [param hang] in [param room]: a hoop
## under its globe on four rods from a cap under the ceiling — none where it would hang
## under HEADROOM.
func _lantern(mesh: ShipMesh, room: ShipRoom, hang: Vector3) -> void:
	var hoop := hang - Vector3.UP * (ShipLamp.CORD + LANTERN_DROP)
	if hoop.y < room.floor_height + HEADROOM + ShipMesh.SLIVER:
		return
	var inner := LANTERN - LANTERN_WIDTH
	RoomDressing.ring(mesh, hoop, Vector3.DOWN, inner, LANTERN, bronze, LANTERN_SIDES)
	var lid := hoop + Vector3.UP * 0.012
	RoomDressing.ring(mesh, lid, Vector3.UP, inner, LANTERN, bronze, LANTERN_SIDES)
	var cap := hang - Vector3.UP * 0.05
	RoomDressing.disc(mesh, cap, Vector3.DOWN, LANTERN * 0.5, bronze, LANTERN_SIDES)
	var middle := LANTERN - LANTERN_WIDTH * 0.5
	var rod := Vector2.ONE * 0.012
	for index in 4:
		var turn := TAU * (index + 0.5) / 4.0
		var out := Vector3(cos(turn), 0.0, sin(turn))
		mesh.beam(hoop + out * middle, cap + out * LANTERN * 0.45, rod, bronze, 0)


## The lights [param room] is lit by: in the Turkish bath a pendant in each bronze
## lantern, where RoomDressing would hang its own — as many, so its light costs no
## more; none, keeping RoomDressing's pendants, in the swimming bath.
func lights(room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	if turkish(room):
		for hang: Vector3 in _hangs(room):
			found.append(RoomDressing.Light.new(hang, ShipLamp.Kind.PENDANT))
	return found


## What a bath lines its walls, floor, ceiling and beams with (RoomDressing.Part):
## white glazed tile over a pale tiled floor, the ship's own ceiling and beams.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = [tile, floor_tile, null, null]
	return paints


## Where under [param room]'s ceiling its pendants hang: where RoomDressing hangs
## them, the middle of each LAMP_SPACING square.
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


## [param wall] cut into bays no longer than BAY, end to end, each (from, to) along it.
static func _bays(wall: RoomDressing.Wall) -> PackedVector2Array:
	var found := PackedVector2Array()
	var count := maxi(1, ceili(wall.length() / BAY))
	for index in count:
		var a := wall.from + wall.length() * index / count
		found.append(Vector2(a, wall.from + wall.length() * (index + 1) / count))
	return found


## Whether [param wall] from [param a] to [param b] along it is clear for a piece: no
## stair beside it, no pane of [param glass] in it.
func _free(wall: RoomDressing.Wall, a: float, b: float, glass: Array[Array]) -> bool:
	var floor := wall.floor
	var beside := wall.rect(a, b, 0.0, 0.5)
	if RoomDressing.over_a_ramp(_space.layout, beside, floor - 0.01, floor + 2.5):
		return false
	for pane: Array in glass:
		if not (pane[2] as Vector3).is_equal_approx(wall.normal):
			continue
		var at := wall.right.dot((pane[1] as Vector3) - wall.at(0.0, 0.0))
		var reach: float = (pane[4] as Vector2).x + CabinDressing.GLASS_CLEAR
		if b > at - reach and a < at + reach:
			return false
	return true
