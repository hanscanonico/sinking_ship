class_name FurnitureDressing
extends RefCounted
## The furniture standing on a room's floor (RoomDressing): every low box the layout
## sets there (ShipSpace.furniture()), which the rules hold bodies out of below its top
## and let a body jump onto, drawn as what its shape says it is, in its room's manner
## (LinerPublic.style_of) — a table laid with its cloth, a card table under its baize,
## a writing desk, a restaurant's table laid for dinner or a crew's mess table; an
## armchair or a settee in its room's upholstery; a bench, a counter, a galley range,
## a gymnasium's apparatus or a working space's stack of stores.
## Each is drawn to its box and inside it: its sides stand where the box's do, from near
## its foot to its top, and its top is the box's, as art-lint holds every blocker drawn
## (the art aligns to the data, D6) — a body is held off the whole of it, so it reads
## solid there; a seat's arms and back stand over its top under a step — and nothing of
## it stands out of its footprint where a body does (FurnishingCheck). The box is sim
## data and never grows to fit a piece.

## What a box of furniture is drawn as (piece_of()).
enum Piece { TABLE, BENCH, COUNTER, RANGE, APPARATUS, ARMCHAIR, SETTEE }

## A piece no taller than BENCH_TOP is a seat — an armchair when no larger either way
## than ARMCHAIR_SIDE, a settee when SETTEE_DEPTH deep or deeper, else a bench; one
## under COUNTER_TOP a table; one taller a counter when narrower than RANGE_DEPTH, a
## range when not, and an apparatus when no longer than APPARATUS_LENGTH. Heights are
## read within ShipSpace.SLIVER: a deck's height in single precision is a hair off its
## own.
const BENCH_TOP := 0.5
const ARMCHAIR_SIDE := 0.9
const SETTEE_DEPTH := 0.7
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
## The upholstered seats (assets/models), each with its origin on the floor under the
## middle of its box, x along it, z out of its front: ARMCHAIR and SETTEE long, tall to
## their seats and deep, their arms ARM_RISE and their backs BACK_RISE over the seat,
## under a step. Their coverings are painted upholstery, their cushions linen and their
## frames teak, which the room swaps for its own (_coverings()).
const ARMCHAIR_MODEL := "armchair"
const SETTEE_MODEL := "settee"
const ARMCHAIR := Vector3(0.8, 0.45, 0.8)
const SETTEE := Vector3(2.0, 0.45, 0.8)
const ARM_RISE := 0.17
const BACK_RISE := 0.33
## A seat faces the nearest table whose middle stands within SEAT_REACH of its own; a
## settee with its back within BACK_REACH of its room's side stands back to it; any
## other seat stands back to its room's nearest side.
const SEAT_REACH := 1.6
const BACK_REACH := 0.25
## A crew's room — its name holds CREW — sits at mess tables, a long table with its
## benches inside its box (LinerDining.mess_table); a working space — its name holds
## WORKING — keeps its stores in stacks, an apparatus's shape there: stowed crates
## STORES_CRATE a side or the most that fit across it, one on another to its top
## (stores()).
const CREW := "quarters"
const WORKING := "working"
const STORES_CRATE := 0.7
## A writing desk: its top board, the leather let into it INSET in from its edges, and
## a drawer's panel every DRAWER along its front.
const DESK_BOARD := 0.035
const INSET := 0.06
const DRAWER := 0.4

static var _baize := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.BAIZE)
static var _mahogany := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, LinerPublic.MAHOGANY)
static var _walnut := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, LinerPublic.WALNUT)
static var _oak := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, LinerPublic.OAK)
static var _wicker := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, LinerPublic.WICKER)
static var _velvet := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.VELVET)
static var _cushion := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, LinerPublic.CAFE_CURTAIN)


## [param pieces] (ShipSpace.furniture()) of [param room], into [param mesh], each in
## the manner of its room (LinerPublic.style_of).
static func build(mesh: ShipMesh, room: ShipRoom, pieces: Array[ShipBlocker]) -> void:
	var style := LinerPublic.style_of(room)
	var named := String(room.name).to_lower()
	for blocker: ShipBlocker in pieces:
		match piece_of(blocker):
			Piece.TABLE:
				if CREW in named and LinerDining.long_table(blocker.area):
					LinerDining.mess_table(mesh, blocker.area, blocker.bottom, blocker.top)
				else:
					_table_in(mesh, style, room, blocker)
			Piece.BENCH:
				bench(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.COUNTER:
				counter(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.RANGE:
				range_stove(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.APPARATUS:
				if WORKING in named:
					stores(mesh, blocker.area, blocker.bottom, blocker.top)
				else:
					apparatus(mesh, blocker.area, blocker.bottom, blocker.top)
			Piece.ARMCHAIR, Piece.SETTEE:
				var facing := facing_of(room, pieces, blocker)
				seat(mesh, blocker, facing, _coverings(style))


## What [param blocker] is drawn as, by its height and its footprint.
static func piece_of(blocker: ShipBlocker) -> Piece:
	var height := blocker.top - blocker.bottom
	var size := blocker.area.size
	if height <= BENCH_TOP + ShipSpace.SLIVER:
		if maxf(size.x, size.y) <= ARMCHAIR_SIDE:
			return Piece.ARMCHAIR
		return Piece.SETTEE if minf(size.x, size.y) >= SETTEE_DEPTH else Piece.BENCH
	if height < COUNTER_TOP - ShipSpace.SLIVER:
		return Piece.TABLE
	if maxf(size.x, size.y) <= APPARATUS_LENGTH:
		return Piece.APPARATUS
	return Piece.RANGE if minf(size.x, size.y) >= RANGE_DEPTH else Piece.COUNTER


## A table [param blocker] in [param room], of [param style]: a smoking room's card
## table under its baize, a reading and writing room's writing desk facing into the
## room, a restaurant's table laid for dinner with its chairs (LinerDining.laid_table),
## any other under its white cloth.
static func _table_in(
	mesh: ShipMesh, style: LinerPublic.Style, room: ShipRoom, blocker: ShipBlocker
) -> void:
	var area := blocker.area
	match style:
		LinerPublic.Style.SMOKING:
			table(mesh, area, blocker.bottom, blocker.top, _baize)
		LinerPublic.Style.READING:
			writing_desk(mesh, area, blocker.bottom, blocker.top, front_of(room, area))
		LinerPublic.Style.RESTAURANT:
			LinerDining.laid_table(mesh, area, blocker.bottom, blocker.top)
		_:
			table(mesh, area, blocker.bottom, blocker.top)


## A table over [param area], laid: a cloth in [param cloth] over its top at
## [param top], hanging to HEM over its foot at [param bottom], and under it the feet of
## its legs, one at each corner and a pair more every LEG_SPAN along a long one.
static func table(
	mesh: ShipMesh, area: Rect2, bottom: float, top: float, cloth := ShipPaints.linen
) -> void:
	mesh.box(area, bottom + HEM, top, cloth)
	for spot: Vector2 in _posts(area.grow(-LEG_INSET), LEG, LEG_SPAN):
		var leg := Rect2(spot - Vector2.ONE * LEG * 0.5, Vector2.ONE * LEG)
		mesh.box(leg, bottom, bottom + HEM, ShipPaints.frame, ShipMesh.SIDES)


## A writing desk over [param area]: a mahogany carcass from [param bottom] under a board
## at [param top], leather let into the board, and a drawer's panel every DRAWER along
## its front, the long side [param front] points out of (front_of()).
static func writing_desk(
	mesh: ShipMesh, area: Rect2, bottom: float, top: float, front: Vector2
) -> void:
	mesh.box(area, bottom, top - DESK_BOARD, _mahogany, ShipMesh.SIDES)
	mesh.box(area, top - DESK_BOARD, top, _mahogany, ShipMesh.SIDES | ShipMesh.TOP)
	mesh.box(area.grow(-INSET), top, top + FLUSH, ShipPaints.leather, ShipMesh.TOP)
	var along_x := area.size.x >= area.size.y
	var length := area.size.x if along_x else area.size.y
	var depth := area.size.y if along_x else area.size.x
	var drawers := maxi(1, floori(length / DRAWER))
	var middle := area.get_center()
	var axis := Vector2.RIGHT if along_x else Vector2.DOWN
	var right := Vector3(axis.x, 0.0, axis.y)
	var normal := Vector3(front.x, 0.0, front.y)
	var high := top - DESK_BOARD - 0.08
	for drawer in drawers:
		var along := (drawer + 0.5) * length / drawers - length * 0.5
		var face := middle + axis * along + front * (depth * 0.5 + FLUSH)
		var at := Vector3(face.x, high, face.y)
		var half := Vector2(length / drawers * 0.5 - 0.03, 0.05)
		RoomDressing.panel(mesh, at, right, half, normal, _walnut)


## The way out of [param area]'s long side that faces into [param room]: away from the
## room's edge nearer its other long side, where a writing desk's sitter sits.
static func front_of(room: ShipRoom, area: Rect2) -> Vector2:
	var across := Vector2.DOWN if area.size.x >= area.size.y else Vector2.RIGHT
	var middle := area.get_center()
	var half := absf(across.dot(area.size)) * 0.5
	var ahead := _side_off(room.area, middle + across * half, across)
	var behind := _side_off(room.area, middle - across * half, -across)
	return across if ahead >= behind else -across


## Stores stacked over [param area] from [param bottom] to [param top]: stowed crates
## (CargoHold.crate) side by side across it, STORES_CRATE a side or the most that fit, and
## one on another, the largest that fits under its top, up to it.
static func stores(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	var across := Vector2i(
		maxi(1, roundi(area.size.x / STORES_CRATE)), maxi(1, roundi(area.size.y / STORES_CRATE))
	)
	var cell := area.size / Vector2(across)
	var model := CargoHold.stowed_crate(minf(cell.x, cell.y), top - bottom)
	var height := 0.0
	for made: float in CargoHold.STOWED_CRATES:
		if CargoHold.STOWED_CRATES[made] == model:
			height = CargoHold.STOWED_CRATE_HEIGHTS[made]
	var levels := maxi(1, floori((top - bottom) / height + ShipSpace.SLIVER))
	for i in across.x:
		for j in across.y:
			var spot := Rect2(area.position + cell * Vector2(i, j), cell)
			for level in levels:
				var foot := bottom + (top - bottom) * level / levels
				CargoHold.crate(mesh, spot, foot, foot + (top - bottom) / levels)


## A seat [param blocker] — an armchair or a settee (ARMCHAIR_MODEL, SETTEE_MODEL) — on
## its floor facing [param facing], a unit vector in the ship plane, in
## [param coverings] (_coverings()).
static func seat(
	mesh: ShipMesh, blocker: ShipBlocker, facing: Vector2, coverings: Dictionary
) -> void:
	var model := ARMCHAIR_MODEL if piece_of(blocker) == Piece.ARMCHAIR else SETTEE_MODEL
	var middle := blocker.area.get_center()
	var front := Vector3(facing.x, 0.0, facing.y)
	var turn := Basis(Vector3.UP.cross(front), Vector3.UP, front)
	var at := Vector3(middle.x, blocker.bottom, middle.y)
	mesh.model(ShipModel.named(model), Transform3D(turn, at), coverings)


## The way [param blocker], a seat among [param pieces] of [param room], faces: a settee
## with its back along its room's side away from it; else toward the nearest table
## within SEAT_REACH; else away from its room's nearest side — a settee across its
## length, along one of its box's sides.
static func facing_of(room: ShipRoom, pieces: Array[ShipBlocker], blocker: ShipBlocker) -> Vector2:
	var area := blocker.area
	var middle := area.get_center()
	var settee := piece_of(blocker) == Piece.SETTEE
	var ways: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	if settee and area.size.x < area.size.y:
		ways = [Vector2.RIGHT, Vector2.LEFT]
	elif settee:
		ways = [Vector2.DOWN, Vector2.UP]
	var sides := room.area
	if settee:
		for way: Vector2 in ways:
			var back := middle - way * absf(way.dot(area.size)) * 0.5
			if _side_off(sides, back, -way) <= BACK_REACH:
				return way
	var nearest := INF
	var toward := Vector2.ZERO
	for other: ShipBlocker in pieces:
		if piece_of(other) != Piece.TABLE:
			continue
		var apart := other.area.get_center() - middle
		if apart.length() < minf(nearest, SEAT_REACH):
			nearest = apart.length()
			toward = apart
	if toward != Vector2.ZERO:
		var best := ways[0]
		for way: Vector2 in ways:
			if way.dot(toward) > best.dot(toward):
				best = way
		return best
	var away := ways[0]
	var closest := INF
	for way: Vector2 in ways:
		var back := middle - way * absf(way.dot(area.size)) * 0.5
		var off := _side_off(sides, back, -way)
		if off < closest:
			closest = off
			away = way
	return away


## How far [param point] stands from [param sides]' edge the way [param out] points.
static func _side_off(sides: Rect2, point: Vector2, out: Vector2) -> float:
	if out.x > 0.0:
		return sides.end.x - point.x
	if out.x < 0.0:
		return point.x - sides.position.x
	if out.y > 0.0:
		return sides.end.y - point.y
	return point.y - sides.position.y


## A room's seats' coverings by its [param style], as ShipMesh.model()'s paints: the
## smoking room's leather on mahogany, the verandah café's and the reception room's
## wicker under cushions, the landings' and the entrance's velvet on oak, any other's
## velvet on walnut.
static func _coverings(style: LinerPublic.Style) -> Dictionary:
	match style:
		LinerPublic.Style.SMOKING:
			return {
				ShipPaints.upholstery: ShipPaints.leather,
				ShipPaints.linen: ShipPaints.leather,
				ShipPaints.teak: _mahogany,
			}
		LinerPublic.Style.CAFE, LinerPublic.Style.RECEPTION:
			return {
				ShipPaints.upholstery: _wicker,
				ShipPaints.linen: _cushion,
				ShipPaints.teak: _wicker,
			}
		LinerPublic.Style.LANDING, LinerPublic.Style.ENTRANCE:
			return {
				ShipPaints.upholstery: _velvet,
				ShipPaints.linen: _velvet,
				ShipPaints.teak: _oak,
			}
	return {ShipPaints.upholstery: _velvet, ShipPaints.linen: _velvet, ShipPaints.teak: _walnut}


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
