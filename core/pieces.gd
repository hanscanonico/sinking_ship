class_name Pieces
extends RefCounted
## Her pieces as a match stands on them (§5b.3, "Pieces"; D6, SH33): one per piece of her
## the schedule has (SinkSchedule.piece_count) — the whole ship first, her own layout and
## Surfaces; each piece she breaks into her layout cut to its stretch (cut), its decks
## torn back tear metres from every cut (SeaPhysics), so a body at a torn end falls. A
## piece's space is her ship space, set in the world by the piece's own pose
## (ShipPose.of_piece): a body lives in the space of the piece under it, and one that
## leaves its piece's stretch in the air or the sea and is over another piece's is carried
## across through the world (carry). Each piece is asked as the whole ship is — its Faces,
## its Surfaces per frame, the one door to every spatial question on it (D13) — built the
## first time it is. A piece's layout numbers its railings and ladders its own way: rail()
## turns one of its railings into hers.

## A stretch narrower than this, in metres, is none.
const SLIVER := 1e-6

var _layout: ShipLayout
var _schedule: SinkSchedule
var _keep_deg: float
var _turns: bool
var _tear: float
## Her own span along her; per piece built so far, its layout, Faces and the railings of
## hers each of its railings is.
var _ends: Vector2
var _layouts: Dictionary[int, ShipLayout] = {}
var _faces: Dictionary[int, Faces] = {}
var _rails: Dictionary[int, PackedInt32Array] = {}
## Per piece, the last pose honoured and the same with its failed railings numbered
## among the piece's (_renumbered).
var _posed_from: Dictionary[int, ShipPose] = {}
var _posed: Dictionary[int, ShipPose] = {}


## The pieces of [param layout] [param schedule] has, the whole ship's faces
## [param whole]; each piece's faces keeping to [param keep_deg] and turning as
## [param turns] says (Faces).
func _init(
	layout: ShipLayout, schedule: SinkSchedule, whole: Faces, keep_deg: float, turns: bool
) -> void:
	_layout = layout
	_schedule = schedule
	_keep_deg = keep_deg
	_turns = turns
	_tear = SeaPhysics.load_default().tear
	_layouts[0] = layout
	_faces[0] = whole
	_rails[0] = PackedInt32Array()
	if layout.structure != null and schedule.piece_count() > 1:
		_ends = PieceStructure.span_of(layout.structure)


## How many pieces of her there are, whole ship first.
func count() -> int:
	return _schedule.piece_count()


## Piece [param piece]'s layout: hers cut to its stretch.
func layout(piece: int) -> ShipLayout:
	if not _layouts.has(piece):
		var span := _schedule.span_of(piece)
		var rails := PackedInt32Array()
		_layouts[piece] = cut(_layout, _schedule.structure_of(piece), span, _ends, _tear, rails)
		_rails[piece] = rails
		_posed_from[piece] = null
	return _layouts[piece]


## Piece [param piece]'s faces (Faces), its decks' frame its layout's own Surfaces.
func faces(piece: int) -> Faces:
	if not _faces.has(piece):
		var cut_layout := layout(piece)
		_faces[piece] = Faces.new(cut_layout, Surfaces.new(cut_layout), _keep_deg, _turns)
	return _faces[piece]


## The railing of hers that railing [param railing] of piece [param piece]'s layout is.
func rail(piece: int, railing: int) -> int:
	layout(piece)
	return railing if _rails[piece].is_empty() else _rails[piece][railing]


## Stands piece [param piece]'s decks' Surfaces as [param pose] — the whole ship's, or
## the piece's own — has it at its tick (Surfaces.honour): the piece's pose, its railings
## failed and those of hers [param broken] by the match among its own numbers, and of the
## crates of [param props] those over its stretch.
func honour(piece: int, pose: ShipPose, broken: PackedInt32Array, props: Array[PropState]) -> void:
	var surfaces := faces(piece).surfaces(Faces.Up.DECK)
	if piece == 0:
		surfaces.honour(pose, broken, props)
		return
	var own := pose.of_piece(piece)
	if own != _posed_from[piece]:
		_posed_from[piece] = own
		_posed[piece] = _renumbered(piece, own)
	var gone := PackedInt32Array()
	var rails := _rails[piece]
	for railing in rails.size():
		if rails[railing] in broken:
			gone.append(railing)
	var aboard: Array[PropState] = []
	for crate: PropState in props:
		if piece_at(own.standing, crate.pos.x) == piece:
			aboard.append(crate)
	surfaces.honour(_posed[piece], gone, aboard)


## [param pose], piece [param piece]'s, with its failed railings numbered among the
## piece's own: what the piece's Surfaces honours, one for each pose it is handed.
func _renumbered(piece: int, pose: ShipPose) -> ShipPose:
	var made := ShipPose.new(pose.sink, pose.trim_deg, pose.heel_deg, pose.transform)
	made.levels = pose.levels
	made.pockets = pose.pockets
	made.cells = pose.cells
	made.lit = pose.lit
	made.doors_shut = pose.doors_shut
	made.opened = pose.opened
	made.falls = pose.falls
	made.felled = pose.felled
	made.collapsed = pose.collapsed
	made.collapsing = pose.collapsing
	made.standing = pose.standing
	var rails := _rails[piece]
	for railing in rails.size():
		if rails[railing] in pose.broken_railings:
			made.broken_railings.append(railing)
	return made


## Of [param standing] — the pieces she is in, aft to fore — the one whose stretch holds
## [param x] along her, past its torn ends; -1 where none does: between two of them.
func piece_at(standing: PackedInt32Array, x: float) -> int:
	if standing.size() == 1:
		return standing[0]
	for piece: int in standing:
		var span := _walked(piece)
		if x >= span.x and x <= span.y:
			return piece
	return -1


## The stretch of piece [param piece] a body stands on: its span less the tear at every
## end of it that is a cut.
func _walked(piece: int) -> Vector2:
	var span := _schedule.span_of(piece)
	var low := span.x + (_tear if span.x > _ends.x + SLIVER else -INF)
	var high := span.y - (_tear if span.y < _ends.y - SLIVER else -INF)
	return Vector2(low, high)


## Carries [param player], in piece [param from]'s space, into piece [param to]'s under
## [param pose] — the whole ship's: through the world, its points and velocities turned
## from one piece's pose to the other's, its fall measured on from the same height.
static func carry(player: PlayerState, from: int, to: int, pose: ShipPose) -> void:
	var leaving := pose.of_piece(from).transform
	var arriving := pose.of_piece(to).transform.affine_inverse()
	var turn := arriving.basis * leaving.basis
	var was := player.pos.y
	player.pos = arriving * (leaving * player.pos)
	player.fall_from += player.pos.y - was
	player.vel = turn * player.vel
	player.held_vel = turn * player.held_vel
	player.climb_to = arriving * (leaving * player.climb_to)
	player.piece = to


## [param snapshot] with every seat's points in piece [param piece]'s space, under
## [param pose] — the whole ship's: a seat on another piece carried there through the
## world, as it stands now, on no surface of this one. Itself while she is whole.
static func seen_from(snapshot: Dictionary, piece: int, pose: ShipPose) -> Dictionary:
	if pose.pieces.is_empty():
		return snapshot
	var into := pose.of_piece(piece).transform.affine_inverse()
	var seats: Array[Dictionary] = []
	for entry: Dictionary in snapshot["seats"]:
		if entry["piece"] == piece:
			seats.append(entry)
			continue
		var made := entry.duplicate()
		var from := pose.of_piece(entry["piece"]).transform
		var turn := into.basis * from.basis
		for key: String in ["pos", "climb_to"]:
			made[key] = into * (from * (entry[key] as Vector3))
		for key: String in ["vel", "held_vel"]:
			made[key] = turn * (entry[key] as Vector3)
		made["surface"] = Surfaces.NONE
		seats.append(made)
	var seen := snapshot.duplicate()
	seen["seats"] = seats
	return seen


## [param layout] cut to [param span] along her, its structure [param structure] (the
## piece's, PieceStructure): every platform, ramp, wall and room cut at the span's ends
## and every deck torn back [param tear] metres from an end that is a cut — not one of
## hers, [param ends] — a stair cut keeping its slope; railings and ladders cut with their
## decks, each numbered among the piece's, [param rails] filled with the railing of hers
## each is; a round blocker kept where its middle stands. Her crates and spawns all kept,
## numbered as hers.
static func cut(
	layout: ShipLayout,
	structure: ShipStructure,
	span: Vector2,
	ends: Vector2,
	tear: float,
	rails: PackedInt32Array
) -> ShipLayout:
	var low := span.x + tear if span.x > ends.x + SLIVER else -INF
	var high := span.y - tear if span.y < ends.y - SLIVER else INF
	var made := ShipLayout.new()
	made.freeboard = layout.freeboard
	made.deck_thickness = layout.deck_thickness
	made.min_seats = layout.min_seats
	made.max_seats = layout.max_seats
	made.dressed = layout.dressed
	made.spawns = layout.spawns
	made.props = layout.props
	made.structure = structure
	var kept := PackedInt32Array()
	for platform: ShipPlatform in layout.platforms:
		var area := _cut_area(platform.area, low, high)
		kept.append(made.platforms.size() if area.size.x > SLIVER else -1)
		if area.size.x > SLIVER:
			var piece := platform.duplicate() as ShipPlatform
			piece.area = area
			made.platforms.append(piece)
	for ramp: ShipRamp in layout.ramps:
		var area := _cut_area(ramp.area, low, high)
		if area.size.x <= SLIVER:
			continue
		var piece := ramp.duplicate() as ShipRamp
		piece.area = area
		if ramp.axis == ShipRamp.Axis.X:
			piece.start_height = ramp.height_at(area.position.x, area.position.y)
			piece.end_height = ramp.height_at(area.end.x, area.position.y)
		made.ramps.append(piece)
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			if blocker.centre.x >= low and blocker.centre.x <= high:
				made.blockers.append(blocker)
			continue
		var area := _cut_area(blocker.area, low, high)
		if area.size.x > SLIVER:
			var piece := blocker.duplicate() as ShipBlocker
			piece.area = area
			made.blockers.append(piece)
	for index in layout.railings.size():
		var railing := layout.railings[index]
		var piece := _cut_edge(railing, kept, low, high) as ShipRailing
		if piece != null:
			made.railings.append(piece)
			rails.append(index)
	for ladder: ShipLadder in layout.ladders:
		var piece := _cut_edge(ladder, kept, low, high) as ShipLadder
		if piece != null:
			made.ladders.append(piece)
	for room: ShipRoom in layout.rooms:
		var area := _cut_area(room.area, low, high)
		if area.size.x > SLIVER:
			var piece := room.duplicate() as ShipRoom
			piece.area = area
			made.rooms.append(piece)
	return made


## [param area] (x/z) cut to run from [param low] to [param high] along her: its width
## none where nothing of it lies there.
static func _cut_area(area: Rect2, low: float, high: float) -> Rect2:
	var from := maxf(area.position.x, low)
	var to := minf(area.end.x, high)
	return Rect2(from, area.position.y, maxf(to - from, 0.0), area.size.y)


## A railing or a ladder [param edge] — its platform, from and to — cut to run from
## [param low] to [param high] along her, on its platform as [param kept] numbers the
## piece's; null where its platform or its whole run is gone.
static func _cut_edge(edge: Resource, kept: PackedInt32Array, low: float, high: float) -> Resource:
	var platform: int = kept[edge.platform]
	if platform == -1:
		return null
	var from: Vector2 = edge.from
	var to: Vector2 = edge.to
	if from.x == to.x:
		if from.x < low or from.x > high:
			return null
	else:
		var start := clampf(minf(from.x, to.x), low, high)
		var end := clampf(maxf(from.x, to.x), low, high)
		if end - start <= SLIVER:
			return null
		var forward := to.x > from.x
		from = Vector2(start if forward else end, from.y)
		to = Vector2(end if forward else start, to.y)
	var piece := edge.duplicate()
	piece.platform = platform
	piece.from = from
	piece.to = to
	return piece
