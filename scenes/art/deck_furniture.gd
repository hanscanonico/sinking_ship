class_name DeckFurniture
extends RefCounted
## What stands on her open decks as a box or a short cylinder (ShipArt), drawn as what it
## is, as FurnitureDressing draws a room's furniture: a box a deck rests on is a casing,
## plated and painted as her houses are, topped where the deck stops short of its edge;
## a box over one of her structure's hatch openings
## in the deck it stands on is the hatch's coaming under its tarpaulin (DeckWorks.hatch);
## a box at one of her boat stations, out to her deck's edge, is a boat stowed on chocks
## under its davits; any other is, by its shape, a skylight, a seat locker, a bench or a
## post; a cylinder no funnel and too short for a mast is a ventilator. Each is drawn to
## its box and inside it — its sides where the blocker's are, its top the blocker's, as
## art-lint holds every blocker drawn, so a body is held off the whole of it and it reads
## solid there; a boat fills its box over its stems, a bench's back and arms stand under
## a step over its seat, and a ventilator's cowl spreads over its trunk only over head
## height — and the box is sim data that never grows to fit a piece (D6).

## What a box, or a ventilator's cylinder, on an open deck is drawn as (piece_of()).
enum Piece { HATCH, CASING, SKYLIGHT, LOCKER, POST, BOAT, BENCH, VENT }

## How near the height of the deck a box stands on a hatch opening lies, to be its hatch.
const HATCH_AT := 0.1

## A box no wider either way than POST_SIDE is a post — a towing hook's —; one no taller
## than LOCKER_TOP and no deeper than LOCKER_DEPTH a seat, a bench or a seat locker
## (BENCH_LONGEST), a lifejacket box to sit on; any other a skylight. Heights are read
## within ShipSpace.SLIVER.
const POST_SIDE := 0.7
const LOCKER_TOP := 0.5
const LOCKER_DEPTH := 0.7
## A skylight: the frame of its two lids, how deep at the coaming's top and how wide round
## their glass, the glass set GLASS_DOWN under the frame's top; the brass glazing bars
## across each lid, BAR wide, at most BAR_SPACING apart; and the brass guard rods along
## it over the glass, GUARD round, their axes GUARD_RISE over the frame's top, at most
## GUARD_SPACING apart.
const LID := 0.07
const LID_FRAME := 0.06
const GLASS_DOWN := 0.012
const BAR := 0.022
const BAR_SPACING := 0.35
const GUARD := 0.012
const GUARD_RISE := 0.012
const GUARD_SPACING := 0.25
## A seat locker: its slatted teak lid, LOCKER_LID thick, its slats SLAT_GAP apart
## (one every SLAT across it at most); its panelled front, a frame of LOCKER_RAIL round
## each panel, a panel every PANEL_SPAN along it at most, drawn FLUSH off the face; and
## its brass hinges along its back.
const LOCKER_LID := 0.04
const SLAT := 0.11
const SLAT_GAP := 0.012
const LOCKER_RAIL := 0.05
const PANEL_SPAN := 0.9
const HINGE := Vector3(0.1, 0.02, 0.05)
## A seat no longer than BENCH_LONGEST is a bench, a longer one a seat locker. A bench is
## a teak seat with a low back and arms (BENCH_MODEL, its origin on the deck under the
## middle of its box, x along it, z out of its front), BENCH long, tall and deep, its back
## no more than BENCH_RISE over its seat and its arms ARM_RISE: under a step, where a body
## standing on it has its feet.
const BENCH_LONGEST := 2.0
const BENCH_MODEL := "deck_bench"
const BENCH := Vector3(1.8, 0.45, 0.55)
const BENCH_RISE := 0.3
const ARM_RISE := 0.18
## A boat stowed on chocks under her davits: a box at one of her structure's boat stations
## (its LIFEBOAT fittings) on the fitting's side, out to the edge of the deck it stands on,
## STOWED_BOAT long, tall and in from the edge. The boat (BOAT_MODEL, its origin on the
## deck under the middle of its keel, x along it) is BOAT_BEAM across and stands BOAT_OFF
## in from the edge, its stems at the box's ends and its stem heads at its top; a davit
## (DAVIT_MODEL, its origin on the deck at the edge, z in) stands DAVIT_IN in from each end,
## its frame in the BOAT_OFF the boat leaves and its arm over the boat to its head,
## DAVIT_HEAD in and up, its fall down to the boat's hook under it; its box over all is
## DAVIT_BOX, inside the boat's.
const BOAT_MODEL := "stowed_boat"
const STOWED_BOAT := Vector3(9.0, 1.5, 3.15)
const BOAT_BEAM := 2.7
const BOAT_OFF := 0.45
const DAVIT_MODEL := "boat_davit"
const DAVIT_IN := 0.7
const DAVIT_HEAD := Vector2(1.8, 3.4)
const DAVIT_BOX := AABB(Vector3(-0.17, 0.0, 0.03), Vector3(0.34, 3.57, 1.85))
## A cylinder no funnel and no taller than VENT_TALLEST is a ventilator, drawn as the one
## made for the largest trunk no bigger than its own (VENTS, by radius; RoomDressing.
## variant()): its origin on the deck at its trunk's axis, its cowl's mouth forward (+x).
## Each stands as tall over its deck as VENT_HEIGHTS gives for its trunk, its cowl over
## head height (HEAD_ROOM over the deck at least) reaching out past its trunk no more than
## COWL_REACH; a mushroom top stands a hop up, inside its footprint.
const VENT_TALLEST := 5.0
const VENTS := {0.25: "mushroom_vent", 0.3: "cowl_vent_30", 0.45: "cowl_vent_45"}
const VENT_HEIGHTS := {0.25: 0.8, 0.3: 2.5, 0.45: 3.4}
const HEAD_ROOM := 1.75
const COWL_REACH := 0.75
## How far a face drawn on a piece's own face stands off it, as FurnitureDressing.FLUSH.
const FLUSH := 0.001
## A towing hook's post: its steel body under a cap plate CAP deep; on its top the hook's
## pivot, HOOK_PIVOT, and its arm reaching HOOK_REACH aft to its jaw, HOOK_JAW tall;
## nothing of it higher over the cap than HOOK_RISE.
const CAP := 0.05
const HOOK_PIVOT := Vector3(0.16, 0.08, 0.16)
const HOOK_REACH := 0.24
const HOOK_JAW := 0.09
const HOOK_ARM := Vector2(0.06, 0.05)
const HOOK_RISE := 0.12


## [param blocker], a box standing on an open deck of [param space]'s ship or a
## ventilator (is_vent()), drawn into [param mesh] to [param top] — its own top, or a
## plank short of it where a deck rests on it — as piece_of() says it is.
static func build(mesh: ShipMesh, space: ShipSpace, blocker: ShipBlocker, top: float) -> void:
	var area := blocker.area
	match piece_of(space, blocker):
		Piece.HATCH:
			DeckWorks.hatch(mesh, area, blocker.bottom, top)
		Piece.CASING:
			mesh.box(area, blocker.bottom, top, ShipPaints.wall, ShipMesh.SIDES)
			# Where the deck resting on it stops short of its edge, it stands up to its own
			# top there, as a wall does under a deck (ShipArt): the Titanic's No. 4 hatch
			# trunks, under the end of A deck's step.
			for bare: Rect2 in space.uncovered(area, blocker.top):
				mesh.box(bare, top, blocker.top, ShipPaints.wall, ShipMesh.TOP | ShipMesh.SIDES)
		Piece.SKYLIGHT:
			skylight(mesh, area, blocker.bottom, top)
		Piece.LOCKER:
			locker(mesh, area, blocker.bottom, top, back_of(space.layout, blocker))
		Piece.POST:
			towing_post(mesh, area, blocker.bottom, top)
		Piece.BOAT:
			boat(mesh, area, blocker.bottom)
		Piece.BENCH:
			bench(mesh, blocker, back_of(space.layout, blocker))
		Piece.VENT:
			vent(mesh, blocker)


## What [param blocker], a box on an open deck of [param space]'s ship or a ventilator
## (is_vent()), is drawn as: a ventilator's cylinder its cowl; a hatch's coaming where she
## has no structure to say otherwise; a casing where a deck rests on it; a hatch's
## coaming where one of her structure's hatch openings lies under it in the deck it
## stands on; a boat where it stands at one of her boat stations; else by its shape.
static func piece_of(space: ShipSpace, blocker: ShipBlocker) -> Piece:
	var layout := space.layout
	if blocker.shape == ShipBlocker.Shape.CYLINDER:
		return Piece.VENT
	if layout.structure == null:
		return Piece.HATCH
	if space.deck_on(blocker):
		return Piece.CASING
	if _over_a_hatch(layout.structure, blocker):
		return Piece.HATCH
	if _at_a_boat_station(layout, blocker):
		return Piece.BOAT
	var size := blocker.area.size
	if maxf(size.x, size.y) <= POST_SIDE:
		return Piece.POST
	var height := blocker.top - blocker.bottom
	if height <= LOCKER_TOP + ShipSpace.SLIVER and minf(size.x, size.y) <= LOCKER_DEPTH:
		return Piece.BENCH if maxf(size.x, size.y) <= BENCH_LONGEST else Piece.LOCKER
	return Piece.SKYLIGHT


## Whether [param blocker] of [param layout] is a ventilator: a cylinder that is no funnel
## (ShipArt.is_funnel) and no taller than VENT_TALLEST, which a mast is.
static func is_vent(layout: ShipLayout, blocker: ShipBlocker) -> bool:
	return (
		blocker.shape == ShipBlocker.Shape.CYLINDER
		and blocker.top - blocker.bottom <= VENT_TALLEST
		and not ShipArt.is_funnel(layout, blocker)
	)


## A boat stowed on chocks over [param area] from [param bottom], a box at one of her boat
## stations out to her deck's edge on the side its middle lies: the boat (BOAT_MODEL)
## BOAT_OFF in from the edge, its stems at the box's ends, and at the edge DAVIT_IN in from
## each end a davit (DAVIT_MODEL) leaning in over it.
static func boat(mesh: ShipMesh, area: Rect2, bottom: float) -> void:
	var side := signf(area.get_center().y)
	var edge := area.end.y if side > 0.0 else area.position.y
	var middle := area.get_center().x
	var inward := _turned(Vector2(0.0, -side))
	var keel := Vector3(middle, bottom, edge - side * (BOAT_OFF + BOAT_BEAM * 0.5))
	mesh.model(ShipModel.named(BOAT_MODEL), Transform3D(inward, keel))
	var davit := ShipModel.named(DAVIT_MODEL)
	for end: float in [-1.0, 1.0]:
		var foot := Vector3(middle + end * (area.size.x * 0.5 - DAVIT_IN), bottom, edge)
		mesh.model(davit, Transform3D(inward, foot))


## A bench over [param blocker]'s box (BENCH_MODEL) on the deck it stands on, its back to
## whatever lies [param back] of it (back_of()) — standing clear of any, to her centre line
## along it, or aft across it.
static func bench(mesh: ShipMesh, blocker: ShipBlocker, back: Vector2) -> void:
	var area := blocker.area
	var middle := area.get_center()
	if back == Vector2.ZERO:
		var along_x := area.size.x >= area.size.y
		var inboard := -signf(middle.y) if middle.y != 0.0 else 1.0
		back = Vector2(0.0, inboard) if along_x else Vector2.LEFT
	var at := Vector3(middle.x, blocker.bottom, middle.y)
	mesh.model(ShipModel.named(BENCH_MODEL), Transform3D(_turned(-back), at))


## A ventilator on the deck under [param blocker]'s axis: the one made for the largest
## trunk no bigger than its own (VENTS), its cowl's mouth forward.
static func vent(mesh: ShipMesh, blocker: ShipBlocker) -> void:
	var foot := Vector3(blocker.centre.x, blocker.bottom, blocker.centre.y)
	var made := RoomDressing.variant(VENTS, blocker.radius)
	mesh.model(ShipModel.named(made), Transform3D(Basis.IDENTITY, foot))


## A skylight over [param area]: a teak coaming from [param bottom], and over it, up to
## [param top], two lids hinged on a brass ridge along its middle — each a teak frame
## round glass divided by brass glazing bars —, brass guard rods along it over the glass.
static func skylight(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom, top - LID, ShipPaints.teak, ShipMesh.SIDES)
	var along_x := area.size.x >= area.size.y
	var length := area.size.x if along_x else area.size.y
	var width := area.size.y if along_x else area.size.x
	var glass_top := top - GLASS_DOWN
	for half: float in [0.0, 0.5]:
		var lid := _part(area, along_x, 0.0, 1.0, half, half + 0.5)
		mesh.box(
			lid.grow(-LID_FRAME), glass_top - 0.01, glass_top, ShipPaints.glass_out, ShipMesh.TOP
		)
		for strip: Rect2 in _frame_round(lid, LID_FRAME):
			mesh.box(strip, top - LID, top, ShipPaints.frame, ShipMesh.TOP | ShipMesh.SIDES)
		var bars := maxi(1, ceili((length - LID_FRAME * 2.0) / BAR_SPACING)) - 1
		for bar in bars:
			var at := (bar + 1.0) / (bars + 1.0)
			var glass := lid.grow(-LID_FRAME)
			var strip := _part(glass, along_x, at, at, 0.0, 1.0).grow_individual(
				BAR * 0.5 if along_x else 0.0,
				0.0 if along_x else BAR * 0.5,
				BAR * 0.5 if along_x else 0.0,
				0.0 if along_x else BAR * 0.5
			)
			mesh.box(strip, glass_top - 0.01, glass_top + 0.004, ShipPaints.brass, ShipMesh.TOP)
	var half_ridge := LID_FRAME * 0.25
	var ridge := _part(area, along_x, 0.0, 1.0, 0.5, 0.5).grow_individual(
		0.0 if along_x else half_ridge,
		half_ridge if along_x else 0.0,
		0.0 if along_x else half_ridge,
		half_ridge if along_x else 0.0
	)
	mesh.box(ridge, top - 0.01, top + 0.006, ShipPaints.brass, ShipMesh.TOP | ShipMesh.SIDES)
	var rods := maxi(2, ceili(width / GUARD_SPACING)) - 1
	for rod in rods:
		var across := (rod + 1.0) / (rods + 1.0)
		if absf(across - 0.5) < 0.05:
			continue
		var line := _part(area, along_x, 0.0, 1.0, across, across)
		var from := Vector3(line.position.x, top + GUARD_RISE, line.position.y)
		var to := Vector3(line.end.x, top + GUARD_RISE, line.end.y)
		var inset := (Vector3.RIGHT if along_x else Vector3.BACK) * LID_FRAME * 0.5
		mesh.beam(from + inset, to - inset, Vector2.ONE * GUARD, ShipPaints.brass, 0)


## A seat locker over [param area] standing against whatever lies [param back] of it (a
## unit vector in the ship plane, zero for nothing): a panelled teak box from
## [param bottom] under a slatted lid at [param top], hinged along its back in brass.
static func locker(mesh: ShipMesh, area: Rect2, bottom: float, top: float, back: Vector2) -> void:
	mesh.box(area, bottom, top - LOCKER_LID, ShipPaints.teak, ShipMesh.SIDES)
	var along_x := area.size.x >= area.size.y
	var length := area.size.x if along_x else area.size.y
	var depth := area.size.y if along_x else area.size.x
	var slats := maxi(2, ceili(depth / SLAT))
	for slat in slats:
		var from := float(slat) / slats
		var to := float(slat + 1) / slats
		var piece := _part(area, along_x, 0.0, 1.0, from, to)
		var gap := SLAT_GAP * 0.5
		piece = piece.grow_individual(
			0.0 if along_x else -gap,
			-gap if along_x else 0.0,
			0.0 if along_x else -gap,
			-gap if along_x else 0.0
		)
		mesh.box(piece, top - LOCKER_LID, top, ShipPaints.teak, ShipMesh.TOP | ShipMesh.SIDES)
	var panels := maxi(1, ceili(length / PANEL_SPAN))
	var middle := area.get_center()
	var axis := Vector2.RIGHT if along_x else Vector2.DOWN
	var across := Vector2.DOWN if along_x else Vector2.RIGHT
	var right := Vector3(axis.x, 0.0, axis.y)
	var high := (top - LOCKER_LID - bottom) - LOCKER_RAIL * 2.0
	for side: float in [-1.0, 1.0]:
		if across * side == back:
			continue
		for panel in panels:
			var along := (panel + 0.5) * length / panels - length * 0.5
			var face := middle + axis * along + across * side * (depth * 0.5 + FLUSH)
			var normal := Vector3(across.x, 0.0, across.y) * side
			var at := Vector3(face.x, bottom + LOCKER_RAIL + high * 0.5, face.y)
			var half := Vector2(length / panels * 0.5 - LOCKER_RAIL, high * 0.5)
			RoomDressing.panel(mesh, at, right, half, normal, ShipPaints.frame)
	if back != Vector2.ZERO:
		var hinge_at := middle + back * (depth * 0.5 - HINGE.z)
		for end: float in [-0.3, 0.3]:
			var spot := hinge_at + axis * length * end
			var size := (
				Vector3(HINGE.x, HINGE.y, HINGE.z)
				if along_x
				else Vector3(HINGE.z, HINGE.y, HINGE.x)
			)
			mesh.turned_box(
				Transform3D(Basis.IDENTITY, Vector3(spot.x, top + HINGE.y * 0.5, spot.y)),
				size,
				ShipPaints.brass,
				0
			)


## A towing hook's post over [param area]: a steel post from [param bottom] under a cap
## plate at [param top], and on it the hook's pivot and its arm reaching aft to the jaw.
static func towing_post(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom, top - CAP, ShipPaints.dark, ShipMesh.SIDES)
	mesh.box(area, top - CAP, top, ShipPaints.steel)
	var middle := area.get_center()
	var pivot := Vector3(middle.x, top + HOOK_PIVOT.y * 0.5, middle.y)
	mesh.turned_box(Transform3D(Basis.IDENTITY, pivot), HOOK_PIVOT, ShipPaints.steel)
	var reach := minf(HOOK_REACH, area.size.x * 0.5 - HOOK_ARM.x * 0.5)
	var arm_y := top + HOOK_PIVOT.y * 0.5
	var heel := Vector3(middle.x, arm_y, middle.y)
	var jaw := heel + Vector3(-reach, 0.0, 0.0)
	mesh.beam(heel, jaw, HOOK_ARM, ShipPaints.dark)
	var tip := jaw + Vector3(0.0, minf(HOOK_JAW, HOOK_RISE - HOOK_PIVOT.y * 0.5), 0.0)
	mesh.beam(jaw, tip, HOOK_ARM, ShipPaints.dark)


## The way a seat locker's back lies — a wall within reach behind its long side — as a
## unit vector in the ship plane; zero where it stands clear of any.
static func back_of(layout: ShipLayout, blocker: ShipBlocker) -> Vector2:
	var area := blocker.area
	var along_x := area.size.x >= area.size.y
	var across := Vector2.DOWN if along_x else Vector2.RIGHT
	var middle := area.get_center()
	var depth := area.size.y if along_x else area.size.x
	for side: float in [-1.0, 1.0]:
		var behind := middle + across * side * (depth * 0.5 + LOCKER_RAIL)
		for other: ShipBlocker in layout.blockers:
			if other == blocker or other.shape != ShipBlocker.Shape.BOX:
				continue
			if other.bottom <= blocker.bottom + ShipSpace.SLIVER and other.top >= blocker.top:
				if other.area.has_point(behind):
					return across * side
	return Vector2.ZERO


## Whether [param blocker] stands at one of [param layout]'s boat stations: one of her
## structure's LIFEBOAT fittings' x within it, on the fitting's side of her centre line,
## its side out there on the edge of the deck it stands on.
static func _at_a_boat_station(layout: ShipLayout, blocker: ShipBlocker) -> bool:
	var area := blocker.area
	var side := signf(area.get_center().y)
	var station := false
	for fitting: ShipFitting in layout.structure.fittings:
		if fitting.kind == ShipFitting.Kind.LIFEBOAT and fitting.side == int(side):
			station = station or (area.position.x <= fitting.x and fitting.x <= area.end.x)
	if not station:
		return false
	var edge := area.end.y if side > 0.0 else area.position.y
	var middle := area.get_center()
	for platform: ShipPlatform in layout.platforms:
		if absf(platform.height - blocker.bottom) > ShipSpace.SLIVER:
			continue
		if not platform.contains(middle.x, middle.y):
			continue
		var deck_edge := platform.area.end.y if side > 0.0 else platform.area.position.y
		if absf(deck_edge - edge) <= ShipSpace.SLIVER:
			return true
	return false


## A turn that faces a model's +z along [param out], a unit vector in the ship plane, its
## +y up.
static func _turned(out: Vector2) -> Basis:
	var facing := Vector3(out.x, 0.0, out.y)
	return Basis(Vector3.UP.cross(facing), Vector3.UP, facing)


## Whether one of [param structure]'s hatch openings lies under [param blocker], in the
## deck it stands on: not a manhole far under it in her double bottom.
static func _over_a_hatch(structure: ShipStructure, blocker: ShipBlocker) -> bool:
	var area := blocker.area.grow(ShipSpace.SLIVER)
	for opening: ShipOpening in structure.openings:
		if opening.kind != ShipOpening.Kind.HATCH:
			continue
		var under := Vector2(opening.centre.x, opening.centre.z)
		if absf(opening.centre.y - blocker.bottom) <= HATCH_AT and area.has_point(under):
			return true
	return false


## The part of [param area] from [param from] to [param to] of its length — along x when
## [param along_x], else along z — and from [param side_from] to [param side_to] of its
## width.
static func _part(
	area: Rect2, along_x: bool, from: float, to: float, side_from: float, side_to: float
) -> Rect2:
	var length_axis := Vector2.RIGHT if along_x else Vector2.DOWN
	var width_axis := Vector2.DOWN if along_x else Vector2.RIGHT
	var length := area.size.x if along_x else area.size.y
	var width := area.size.y if along_x else area.size.x
	var corner := area.position + length_axis * length * from + width_axis * width * side_from
	var far := area.position + length_axis * length * to + width_axis * width * side_to
	return Rect2(corner, Vector2.ZERO).expand(far)


## The four strips, [param band] wide, round the inside of [param area]'s edge.
static func _frame_round(area: Rect2, band: float) -> Array[Rect2]:
	return [
		Rect2(area.position.x, area.position.y, area.size.x, band),
		Rect2(area.position.x, area.end.y - band, area.size.x, band),
		Rect2(area.position.x, area.position.y + band, band, area.size.y - band * 2.0),
		Rect2(area.end.x - band, area.position.y + band, band, area.size.y - band * 2.0),
	]
