class_name Faces
extends RefCounted
## Every face of the ship's boxes as a surface (§5b.3, D6, D8, SH32): the tops and
## undersides of her decks, both sides of every wall and blocker, and the outside of her
## hull. Every face in the data is square to one of her axes, so "up in the ship" is the
## axis nearest the world's up, and the match moves along it: in that axis's frame —
## its up the frame's y, its plane the frame's x/z — the faces turned up are floors, the
## faces turned down ceilings, the rest walls, and a doorway in a face now a floor is a
## hole. Each frame's ship is a layout of her solids as boxes, its floors slabs over
## them, asked through a Surfaces of its own — the same door, its searches run along
## that axis. Her own layout is the frame of her decks, unchanged. Stairs are floors
## only there, and railings, ladders and crates stand only there. The watertight doors
## she shuts at the hit stand in every other frame as they do on her decks (DoorLeaves):
## each leaf a box as far across its doorway as the pose has it, none once it has given
## way.
##
## The frame changes only once the floor it has tilts past brace_holds_to — the top of
## the band where nobody walks (BrawlRules) — and then to the axis nearest up: a ship
## lolling at 45° does not flip a match between two frames, and a brace holds where it
## is through the band.

## Which of her directions points up: her deck (upright), her keel (upside down), her
## starboard or port side (on her beam ends), her bow or her stern (on end).
enum Up { DECK, KEEL, STARBOARD, PORT, BOW, STERN }

## Her hull's outside, as boxes cut from her sections (est.): bands this tall up her
## side from her keel to her deck edge, each a plate this thick inside her shell; the
## deck edge is the highest outline point within EDGE_SHARE of her widest; bands
## within SAME of each other in breadth are one plate.
const BAND := 0.25
const PLATE := 0.1
const EDGE_SHARE := 0.95
const SAME := 0.05
## A watertight door's leaf, shut across its doorway, as a box this thick.
const LEAF := 0.05

var _layout: ShipLayout
var _deck: Surfaces
## The tilt a frame's floor keeps it to, in degrees (BrawlRules.brace_holds_to), and
## whether a match turns from her decks at all (SeaPhysics.capsized_movement).
var _keep_deg: float
var _turns: bool
## Her solids in ship space, as boxes: her decks as slabs, her blockers and her hull's
## plates.
var _solids: Array[AABB] = []
## The watertight doors the ship shuts at the hit, in her structure's order.
var _doors: Array[ShipOpening] = []
## Per frame, built the first time it is asked for: its Surfaces and its layout, built
## again when a leaf has moved, and how far each door was shut in them; its cells.
var _surfaces: Dictionary[int, Surfaces] = {}
var _layouts: Dictionary[int, ShipLayout] = {}
var _shut: Dictionary[int, PackedFloat64Array] = {}
var _cells: Dictionary[int, CellMap] = {}


## The faces of [param layout], whose own frame [param deck] answers for, with the
## watertight doors the ship shuts at the hit. A frame keeps to [param keep_deg] of
## tilt; without [param turns] a match stands on her decks.
func _init(layout: ShipLayout, deck: Surfaces, keep_deg: float, turns: bool) -> void:
	_layout = layout
	_deck = deck
	_keep_deg = keep_deg
	_turns = turns
	for platform: ShipPlatform in layout.platforms:
		var area := platform.area
		_solids.append(
			AABB(
				Vector3(area.position.x, platform.height - layout.deck_thickness, area.position.y),
				Vector3(area.size.x, layout.deck_thickness, area.size.y)
			)
		)
	for blocker: ShipBlocker in layout.blockers:
		var area := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			area = Rect2(
				blocker.centre - Vector2.ONE * blocker.radius, Vector2.ONE * blocker.radius * 2.0
			)
		_solids.append(
			AABB(
				Vector3(area.position.x, blocker.bottom, area.position.y),
				Vector3(area.size.x, blocker.top - blocker.bottom, area.size.y)
			)
		)
	if layout.structure == null:
		return
	_hull(layout.structure)
	for door: ShipOpening in layout.structure.openings:
		if door.shuts_at_hit:
			_doors.append(door)


## The frame a match on her stands in under [param pose], having stood in
## [param current] (up_after, as her keep and her stage say).
func up_at(pose: ShipPose, current: int) -> int:
	return up_after(pose, current, _keep_deg) if _turns else current


## The frame a match stands in under [param pose], having stood in [param current]:
## [param current] while its floor is tilted no further than [param keep_deg] from
## level, else the axis nearest the world's up — ties to the first of Up's order.
static func up_after(pose: ShipPose, current: int, keep_deg: float) -> int:
	var world_up := (pose.transform.basis.inverse() * Vector3.UP).normalized()
	if world_up.dot(axis(current)) >= cos(deg_to_rad(keep_deg)):
		return current
	var nearest := Up.DECK
	for up: int in Up.values():
		if world_up.dot(axis(up)) > world_up.dot(axis(nearest)):
			nearest = up
	return nearest


## Her axis that is the frame [param up]'s up, in ship space.
static func axis(up: int) -> Vector3:
	return to_ship(up) * Vector3.UP


## The rotation from ship space to the frame [param up]'s: square to her axes, so a
## point's numbers are only moved and turned in sign — nothing is rounded.
static func to_frame(up: int) -> Basis:
	match up:
		Up.KEEL:
			return Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
		Up.STARBOARD:
			return Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
		Up.PORT:
			return Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		Up.BOW:
			return Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
		Up.STERN:
			return Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	return Basis.IDENTITY


static func to_ship(up: int) -> Basis:
	return to_frame(up).transposed()


## [param pose] as the frame [param up] reads it: the same ship and water, its points in
## that frame — its heights along that up, its gravity turned into it, its slope that
## of the frame's floors. Her funnels' falls stay her decks': their strips are laid on
## them (FallenFunnels), so no other frame meets one.
func framed(pose: ShipPose, up: int) -> ShipPose:
	if up == Up.DECK:
		return pose
	var made := ShipPose.new(
		pose.sink,
		pose.trim_deg,
		pose.heel_deg,
		pose.transform * Transform3D(to_ship(up), Vector3.ZERO)
	)
	made.levels = pose.levels
	made.pockets = pose.pockets
	if pose.cells != null:
		if not _cells.has(up):
			_cells[up] = pose.cells.framed(to_ship(up))
		made.cells = _cells[up]
	made.lit = pose.lit
	made.doors_shut = pose.doors_shut
	made.opened = pose.opened
	made.collapsed = pose.collapsed
	made.collapsing = pose.collapsing
	made.broken_railings = pose.broken_railings
	made.lurch_warning = pose.lurch_warning
	made.lurch = pose.lurch
	return made


## The Surfaces of the frame [param up]: her own for her decks', else her solids' and
## the watertight doors' leaves as far across as [param pose] has them
## (DoorLeaves.shut_in) — built again only once a leaf has moved; without a pose, as last
## built. A jammed door, or one before the hit, the pose has open.
func surfaces(up: int, pose: ShipPose = null) -> Surfaces:
	if up == Up.DECK:
		return _deck
	if pose == null and _surfaces.has(up):
		return _surfaces[up]
	var shut := PackedFloat64Array()
	for door: ShipOpening in _doors:
		shut.append(0.0 if pose == null else DoorLeaves.shut_in(pose, door.name))
	if not _surfaces.has(up) or _shut[up] != shut:
		_shut[up] = shut
		_layouts[up] = _framed_layout(up, shut)
		_surfaces[up] = Surfaces.new(_layouts[up])
	return _surfaces[up]


## Her layout in the frame [param up]: her own for her decks', else that of the frame's
## Surfaces as last built (surfaces).
func layout(up: int) -> ShipLayout:
	if up == Up.DECK:
		return _layout
	surfaces(up)
	return _layouts[up]


## Her layout in the frame [param up], each door [param shut] that far: each solid a box
## blocker in that frame and its top a slab of a floor over it, then each door's leaf
## (DoorLeaves.leaf) a box blocker, there or not — numbered after every solid, so that
## no surface's number moves with a leaf — and nothing else.
func _framed_layout(up: int, shut: PackedFloat64Array) -> ShipLayout:
	var made := ShipLayout.new()
	made.freeboard = _layout.freeboard
	made.deck_thickness = _layout.deck_thickness
	made.min_seats = _layout.min_seats
	made.max_seats = _layout.max_seats
	var turn := to_frame(up)
	for solid: AABB in _solids:
		var blocker := _blocker(turn, solid)
		made.blockers.append(blocker)
		var top := ShipPlatform.new()
		top.area = blocker.area
		top.height = blocker.top
		top.slab = true
		made.platforms.append(top)
	for door in _doors.size():
		made.blockers.append(_blocker(turn, DoorLeaves.leaf(_doors[door], shut[door], LEAF)))
	return made


## [param box], in ship space, as a box blocker in the frame [param turn] takes it to.
static func _blocker(turn: Basis, box: AABB) -> ShipBlocker:
	var a := turn * box.position
	var b := turn * box.end
	var low := a.min(b)
	var high := a.max(b)
	var blocker := ShipBlocker.new()
	blocker.shape = ShipBlocker.Shape.BOX
	blocker.area = Rect2(low.x, low.z, high.x - low.x, high.z - low.z)
	blocker.bottom = low.y
	blocker.top = high.y
	return blocker


## Moves [param player]'s points from ship space into the frame [param up]'s.
static func into(player: PlayerState, up: int) -> void:
	_turned(player, to_frame(up))


## Moves [param player]'s points from the frame [param up]'s into ship space.
static func out_of(player: PlayerState, up: int) -> void:
	_turned(player, to_ship(up))


## [param snapshot] with its seats' points in the frame [param up] — the one a seat of it
## stands in (MatchState.up_of): what a reader that asks that frame's Surfaces about them
## reads — a bot's view, the HUD's crosshair. Itself on her decks.
static func framed_snapshot(snapshot: Dictionary, up: int) -> Dictionary:
	if up == Up.DECK:
		return snapshot
	var turn := to_frame(up)
	var seats: Array[Dictionary] = []
	for entry: Dictionary in snapshot["seats"]:
		var made := entry.duplicate()
		for key: String in ["pos", "vel", "held_vel", "climb_to"]:
			made[key] = turn * (entry[key] as Vector3)
		seats.append(made)
	var framed := snapshot.duplicate()
	framed["seats"] = seats
	return framed


static func _turned(player: PlayerState, turn: Basis) -> void:
	player.pos = turn * player.pos
	player.vel = turn * player.vel
	player.held_vel = turn * player.held_vel
	player.climb_to = turn * player.climb_to


## Her hull's outside from [param structure]'s sections: per section and side, a plate
## inside her shell for every band up her from her keel to her deck edge, the bands
## whose breadths stand within SAME of the next's run together as one.
func _hull(structure: ShipStructure) -> void:
	for section: HullSection in structure.sections:
		var low := INF
		for point: Vector2 in section.outline:
			low = minf(low, point.y)
		for side: int in [-1, 1]:
			var edge := _deck_edge(section, side)
			var from := low
			var inner := INF
			var outer := -INF
			var y := low
			while y < edge:
				var next := minf(y + BAND, edge)
				var at := absf(section.shell_at(y, side))
				var to := absf(section.shell_at(next, side))
				if is_nan(at) or is_nan(to):
					break
				var band_in := minf(at, to)
				var band_out := maxf(at, to)
				if outer > -INF and (absf(band_in - inner) > SAME or absf(band_out - outer) > SAME):
					_plate(section, side, from, y, inner, outer)
					from = y
					inner = band_in
					outer = band_out
				else:
					inner = minf(inner, band_in)
					outer = maxf(outer, band_out)
				y = next
			if outer > -INF:
				_plate(section, side, from, y, inner, outer)


## A plate of [param section]'s length on [param side] from [param bottom] to
## [param top], PLATE inside [param inner] out to [param outer].
func _plate(
	section: HullSection, side: int, bottom: float, top: float, inner: float, outer: float
) -> void:
	var near := (inner - PLATE) * side
	var far := outer * side
	_solids.append(
		AABB(
			Vector3(section.x - section.length * 0.5, bottom, minf(near, far)),
			Vector3(section.length, top - bottom, absf(far - near))
		)
	)


## How high [param section]'s deck edge stands on [param side]: its outline's highest
## point within EDGE_SHARE of its widest that side.
static func _deck_edge(section: HullSection, side: int) -> float:
	var widest := 0.0
	for point: Vector2 in section.outline:
		widest = maxf(widest, point.x * side)
	var edge := -INF
	for point: Vector2 in section.outline:
		if point.x * side >= widest * EDGE_SHARE:
			edge = maxf(edge, point.y)
	return edge
