class_name ShipPieces
extends Node3D
## A hull that breaks drawn piece by piece (§5b.3, "Pieces"; R27, SH33): a node per piece
## of her that never broke (SinkTimeline.leaves), set in the world where the piece's pose
## has it — before it broke away, where the piece it was part of stood — the first
## MatchView's own ship, the rest here. Dressed, her art is pre-cut at every weak spot of
## hers: a whole ShipArt per stretch between two of them, kept to it (ShipArt.span,
## PieceClip), each riding the piece it lies in — the first MatchView's own — and drawn
## torn back as the piece's decks are, tear metres from a cut, once the cut is made; as
## the greybox, each piece is its own layout (Pieces.layout). Each piece's water and lamps
## are its own pose's (ShipPose.of_piece). It reads the schedule only, never the sim (D5).

var _schedule: SinkSchedule
var _pieces: Pieces
var _tear: float
## The leaves, and per leaf: the node it is drawn under (the ship's own for the first),
## its greybox, its water, its stretch along her and the ticks its aft end and its fore
## end are torn — never, for one of her own ends. Per stretch between her weak spots, its
## dressed art, its stretch and the leaf it lies in.
var _leaves := PackedInt32Array()
var _holders: Array[Node3D] = []
var _greyboxes: Array[ShipGreybox] = []
var _waters: Array[InnerWater] = []
var _spans := PackedVector2Array()
var _torn := PackedInt32Array()
var _arts: Array[ShipArt] = []
var _cuts := PackedVector2Array()
var _cut_leaf := PackedInt32Array()


## The pieces of [param schedule]'s sinking she ends in, aft to fore; none for a hull that
## never breaks.
static func leaves_of(schedule: SinkSchedule) -> PackedInt32Array:
	if schedule.piece_count() == 1:
		return PackedInt32Array()
	return schedule.timeline().leaves


## Draws every piece of [param sim]'s ship past the first, which [param ship] — its node
## — [param art] and [param greybox] draw: dressed as [param art] is built, with
## [param falls], [param fails] and [param open_ports] as MatchView builds it, or as the
## greybox while [param greybox] is visible.
func setup(
	sim: MatchSim,
	ship: Node3D,
	art: ShipArt,
	greybox: ShipGreybox,
	falls: Array[StringName],
	fails: PackedInt32Array,
	open_ports: PackedVector3Array
) -> void:
	for child: Node in get_children():
		child.queue_free()
	_schedule = sim.schedule
	_pieces = sim.pieces
	_tear = SeaPhysics.load_default().tear
	_leaves = leaves_of(_schedule)
	_holders = [ship]
	_greyboxes = [greybox if greybox.visible else null]
	_waters = [null]
	_spans.clear()
	_torn.clear()
	_arts.clear()
	_cuts = cuts_of(_schedule)
	_cut_leaf.clear()
	var rules := sim.config.rules
	for at in _leaves.size():
		var leaf := _leaves[at]
		_spans.append(_schedule.span_of(leaf))
		_torn.append_array([_torn_tick(leaf, true), _torn_tick(leaf, false)])
		_waters.append(null)
		if at == 0:
			continue
		var holder := Node3D.new()
		holder.name = "Piece%d" % leaf
		add_child(holder)
		_holders.append(holder)
		_greyboxes.append(null)
		if greybox.visible:
			_greyboxes[at] = ShipGreybox.new()
			_greyboxes[at].cut_above = greybox.cut_above
			holder.add_child(_greyboxes[at])
			_greyboxes[at].build(_pieces.layout(leaf), rules.railing_height)
	var bare: ShipLayout = sim.config.ship.duplicate()
	bare.props = []
	for cut in _cuts.size():
		var middle := (_cuts[cut].x + _cuts[cut].y) * 0.5
		var at := 0
		while _spans[at].y < middle:
			at += 1
		_cut_leaf.append(at)
		if greybox.visible:
			_arts.append(null)
		elif cut == 0:
			_arts.append(art)
		else:
			var dressed := ShipArt.new()
			dressed.name = "Stretch%d" % cut
			dressed.cut_above = art.cut_above
			dressed.span = _cuts[cut]
			_holders[at].add_child(dressed)
			dressed.build(bare, rules.railing_height, rules.body_radius, falls, fails, open_ports)
			_arts.append(dressed)


## The node the [param at]th piece she ends in is drawn under.
func holder(at: int) -> Node3D:
	return _holders[at]


## The stretches her dressed art is cut into, aft to fore, when [param schedule]'s
## sinking breaks her: from end to end of her, cut at every weak spot of hers; none for a
## hull that never breaks.
static func cuts_of(schedule: SinkSchedule) -> PackedVector2Array:
	var found := PackedVector2Array()
	if leaves_of(schedule).is_empty():
		return found
	var structure := schedule.structure_of(0)
	var from := PieceStructure.span_of(structure).x
	for spot: WeakSpot in structure.strength.weak:
		found.append(Vector2(from, spot.x))
		from = spot.x
	found.append(Vector2(from, PieceStructure.span_of(structure).y))
	return found


## The stretch MatchView's own dressed art is kept to, before it is built: her aftmost,
## when she breaks; all of her otherwise.
static func first_span(schedule: SinkSchedule) -> Vector2:
	var cuts := cuts_of(schedule)
	return Vector2(-INF, INF) if cuts.is_empty() else cuts[0]


## Draws every piece's water inside it, in [param sea]'s material — the first's
## [param first], MatchView's own — each piece's cells, openings and pours its own.
func flood_with(sea: ShaderMaterial, first: InnerWater) -> void:
	for at in _leaves.size():
		var leaf := _leaves[at]
		var water := first if at == 0 else InnerWater.new()
		if at > 0:
			if _waters[at] != null:
				_waters[at].queue_free()
			water.name = "InnerWater"
			_holders[at].add_child(water)
		_waters[at] = water
		var dressed := _arts[_cut_leaf.find(at)] if not _arts.is_empty() else null
		var paints: Dictionary = dressed.paints() if dressed != null else {}
		var structure := _schedule.structure_of(leaf)
		var layout := _pieces.layout(leaf)
		water.setup(
			structure,
			layout.rooms,
			_kept(_schedule.passages(), structure, _spans[at]),
			_kept(_schedule.failing(), structure, _spans[at]),
			sea,
			paints
		)


## Sets every piece where [param then] and [param now] — the whole ship's poses of two
## snapshots — have it [param alpha] of the way between, at [param tick], fractional: its
## node, its water, its lamps and its torn ends; the sinking's events drawn on each as
## MatchView hands them in.
func show_pieces(
	then: ShipPose,
	now: ShipPose,
	alpha: float,
	tick: float,
	collapsing: Array[StringName],
	fallen: Dictionary,
	broken: PackedInt32Array,
	lit: bool
) -> void:
	for at in _leaves.size():
		var leaf := _leaves[at]
		var own_then := then.of_piece(leaf)
		var own_now := now.of_piece(leaf)
		if at > 0:
			_holders[at].transform = own_then.transform.interpolate_with(own_now.transform, alpha)
		if _waters[at] != null:
			_waters[at].show_water(own_then, own_now, alpha)
		if _greyboxes[at] != null:
			_greyboxes[at].show_sinking(collapsing, fallen, _local(leaf, broken), lit)
			_greyboxes[at].show_power(own_now)
			_greyboxes[at].show_falls(now.falls, tick)
	for cut in _arts.size():
		var dressed := _arts[cut]
		if dressed == null:
			continue
		var at := _cut_leaf[cut]
		var span := _cuts[cut]
		if span.x == _spans[at].x and tick >= _torn[at * 2]:
			span.x += _tear
		if span.y == _spans[at].y and tick >= _torn[at * 2 + 1]:
			span.y -= _tear
		if dressed.span != span:
			dressed.show_span(span)
		dressed.show_sinking(collapsing, fallen, broken, lit)
		dressed.show_power(now.of_piece(_leaves[at]))
		dressed.show_falls(now.falls, tick)


## The tick leaf [param leaf]'s aft end — or fore end — is torn: when the piece whose cut
## made it broke away; never for one of her own ends.
func _torn_tick(leaf: int, aft: bool) -> int:
	var end := _schedule.span_of(leaf)[0 if aft else 1]
	var first := 1 << 62
	for piece in _schedule.piece_count():
		var span := _schedule.span_of(piece)
		var cut := span.x if aft else span.y
		if piece > 0 and cut == end and _schedule.parent_of(piece) != -1:
			var parent := _schedule.span_of(_schedule.parent_of(piece))
			if cut != (parent.x if aft else parent.y):
				first = mini(first, _schedule.physics_tick(_schedule.timeline().born[piece]))
	return first


## Of [param openings], those of the piece [param structure] whose stretch is
## [param span]: every cell they join its, their middle on it.
static func _kept(
	openings: Array[ShipOpening], structure: ShipStructure, span: Vector2
) -> Array[ShipOpening]:
	var found: Array[ShipOpening] = []
	for opening: ShipOpening in openings:
		var ours := opening.centre.x >= span.x and opening.centre.x <= span.y
		for place: StringName in opening.joins:
			if not place in [ShipOpening.SEA, ShipOpening.SKY]:
				ours = ours and structure.cell_named(place) != -1
		if ours:
			found.append(opening)
	return found


## [param broken], railings of hers, as leaf [param leaf]'s layout numbers its own.
func _local(leaf: int, broken: PackedInt32Array) -> PackedInt32Array:
	var found := PackedInt32Array()
	for railing in _pieces.layout(leaf).railings.size():
		if _pieces.rail(leaf, railing) in broken:
			found.append(railing)
	return found
