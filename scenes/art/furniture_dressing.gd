class_name FurnitureDressing
extends RefCounted
## The furniture standing on a room's floor (RoomDressing): every low box the layout
## sets there (ShipSpace.furniture()), which the rules hold bodies out of below its top
## and let a body jump onto, drawn as what its shape says it is — a table laid with its
## cloth, a bench, a counter, a galley range or a gymnasium's apparatus. Each is drawn
## to its box and inside it: its sides stand where the box's do, from near its foot to
## its top, and its top is the box's, as art-lint holds every blocker drawn (the art
## aligns to the data, D6) — a body is held off the whole of it, so it reads solid
## there — and nothing of it stands out of its footprint where a body does
## (FurnishingCheck). The box is sim data and never grows to fit a piece.

## What a box of furniture is drawn as (piece_of()).
enum Piece { TABLE, BENCH, COUNTER, RANGE, APPARATUS }

## A piece no taller than BENCH_TOP is a bench; one under COUNTER_TOP a table; one
## taller a counter when narrower than RANGE_DEPTH, a range when not, and an apparatus
## when no longer than APPARATUS_LENGTH. Heights are read within ShipSpace.SLIVER: a
## deck's height in single precision is a hair off its own.
const BENCH_TOP := 0.5
const COUNTER_TOP := 0.9
const RANGE_DEPTH := 1.0
const APPARATUS_LENGTH := 2.0
## A table's cloth hangs to HEM over the floor, under a quarter of its height, where
## its legs show — a leg's side, how far in from the cloth's corners each stands, and
## how far apart its legs stand at most along it.
const HEM := 0.15
const LEG := 0.06
const LEG_INSET := 0.05
const LEG_SPAN := 2.0
## A bench's seat thickness, and how far in from the seat's edges its body stands.
const SEAT := 0.06
const BENCH_INSET := 0.03
## A counter's top strip; a range's iron top plate, its oven doors — one every
## OVEN_SPAN along it — and the hot plates standing HOB proud of its plate.
const STRIP := 0.04
const PLATE := 0.04
const OVEN := Vector2(0.5, 0.36)
const OVEN_SPAN := 1.2
const HOB_RADIUS := 0.16
const HOB := 0.01
## An apparatus's leather top, and the plate on each of its long sides.
const PAD := 0.08
const NAMEPLATE := Vector2(0.4, 0.12)
## How far a face drawn on a piece's own face stands off it: inside the margin
## art-lint allows a box, so nothing of a piece pokes out of it.
const FLUSH := 0.001


## [param pieces] (ShipSpace.furniture()) of [param _room], into [param mesh].
static func build(mesh: ShipMesh, _room: ShipRoom, pieces: Array[ShipBlocker]) -> void:
	for blocker: ShipBlocker in pieces:
		match piece_of(blocker):
			Piece.TABLE:
				table(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.BENCH:
				bench(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.COUNTER:
				counter(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.RANGE:
				range_stove(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.APPARATUS:
				apparatus(mesh, blocker.area, blocker.bottom, blocker.top)


## What [param blocker] is drawn as, by its height and its footprint.
static func piece_of(blocker: ShipBlocker) -> Piece:
	var height := blocker.top - blocker.bottom
	var size := blocker.area.size
	if height <= BENCH_TOP + ShipSpace.SLIVER:
		return Piece.BENCH
	if height < COUNTER_TOP - ShipSpace.SLIVER:
		return Piece.TABLE
	if maxf(size.x, size.y) <= APPARATUS_LENGTH:
		return Piece.APPARATUS
	return Piece.RANGE if minf(size.x, size.y) >= RANGE_DEPTH else Piece.COUNTER


## A table over [param area], laid: a white cloth over its top at [param top], hanging
## to HEM over its foot at [param bottom], and under it the feet of its legs, one at
## each corner and a pair more every LEG_SPAN along a long one.
static func table(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom + HEM, top, ShipPaints.linen)
	for spot: Vector2 in _posts(area.grow(-LEG_INSET), LEG, LEG_SPAN):
		var leg := Rect2(spot - Vector2.ONE * LEG * 0.5, Vector2.ONE * LEG)
		mesh.box(leg, bottom, bottom + HEM, ShipPaints.frame, ShipMesh.SIDES)


## A bench over [param area]: a teak seat at [param top] on a body of dark wood set
## BENCH_INSET in from its edges.
static func bench(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, top - SEAT, top, ShipPaints.teak)
	mesh.box(area.grow(-BENCH_INSET), bottom, top - SEAT, ShipPaints.frame, ShipMesh.SIDES)


## A counter over [param area]: a solid body of dark wood under a lighter teak strip
## at [param top].
static func counter(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom, top - STRIP, ShipPaints.frame, ShipMesh.SIDES)
	mesh.box(area, top - STRIP, top, ShipPaints.teak)


## A galley range over [param area]: a black iron body under a steel top plate,
## hot plates standing on it along its middle up to [param top], and oven doors along
## both its long faces.
static func range_stove(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom, top - PLATE, ShipPaints.dark, ShipMesh.SIDES)
	mesh.box(area, top - PLATE, top - HOB, ShipPaints.steel, ShipMesh.SIDES | ShipMesh.TOP)
	var along_x := area.size.x >= area.size.y
	var length := area.size.x if along_x else area.size.y
	var depth := area.size.y if along_x else area.size.x
	var ovens := maxi(1, floori(length / OVEN_SPAN))
	var middle := area.get_center()
	var axis := Vector2.RIGHT if along_x else Vector2.DOWN
	var across := Vector2.DOWN if along_x else Vector2.RIGHT
	var right := Vector3(axis.x, 0.0, axis.y)
	var door_height := bottom + (top - PLATE - bottom) * 0.55
	for index in ovens:
		var along := (index + 0.5) * length / ovens - length * 0.5
		var spot := middle + axis * along
		var hob := minf(HOB_RADIUS, depth * 0.25)
		mesh.cylinder(spot, hob, top - HOB, top, 8, ShipPaints.dark, true)
		for side: float in [-1.0, 1.0]:
			var face := spot + across * side * (depth * 0.5 + FLUSH)
			var normal := Vector3(across.x, 0.0, across.y) * side
			var door := Vector3(face.x, door_height, face.y)
			RoomDressing.panel(mesh, door, right, OVEN * 0.5, normal, ShipPaints.steel)


## A gymnasium's apparatus over [param area] — a rowing machine, an electric camel:
## a black cased body under a leather top at [param top], a bright plate on each of its
## long sides.
static func apparatus(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom, top - PAD, ShipPaints.dark, ShipMesh.SIDES)
	mesh.box(area, top - PAD, top, ShipPaints.leather)
	var along_x := area.size.x >= area.size.y
	var depth := area.size.y if along_x else area.size.x
	var middle := area.get_center()
	var across := Vector2.DOWN if along_x else Vector2.RIGHT
	var right := Vector3.RIGHT if along_x else Vector3.BACK
	for side: float in [-1.0, 1.0]:
		var face := middle + across * side * (depth * 0.5 + FLUSH)
		var normal := Vector3(across.x, 0.0, across.y) * side
		var plate := Vector3(face.x, (bottom + top) * 0.5, face.y)
		RoomDressing.panel(mesh, plate, right, NAMEPLATE * 0.5, normal, ShipPaints.bright_steel)


## The middles of a piece's posts over [param area], [param side] across: one at each
## corner, and a pair more every [param span] along it.
static func _posts(area: Rect2, side: float, span: float) -> Array[Vector2]:
	var inner := area.grow(-side * 0.5)
	var along_x := inner.size.x >= inner.size.y
	var length := inner.size.x if along_x else inner.size.y
	var spans := maxi(1, ceili(length / span))
	var spots: Array[Vector2] = []
	for index in spans + 1:
		var at := length * index / spans
		if along_x:
			spots.append(Vector2(inner.position.x + at, inner.position.y))
			spots.append(Vector2(inner.position.x + at, inner.end.y))
		else:
			spots.append(Vector2(inner.position.x, inner.position.y + at))
			spots.append(Vector2(inner.end.x, inner.position.y + at))
	return spots
