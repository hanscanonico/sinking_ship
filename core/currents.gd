class_name Currents
extends RefCounted
## The water moving round her openings (#616, D12): the flow the bake found through each
## (ShipPose.flows, m³ a second, either way) drives a current about it — drawn in on the
## side whose water stands higher and thrown out as a jet on the other — that carries a
## swimmer, pushes a wader and drifts a prop afloat (Movement, Hazards). One per piece of
## her, of that piece's structure, read under that piece's pose (ShipPose.of_piece); its
## points that piece's ship space. Nothing here is match state: every answer is the pose's
## and the point's, so a snapshot and the digest hold none of it (D5).
##
## Through an opening passing Q the water goes at u0 = Q / A_wet, A_wet its flow area —
## as far as it is open — times the share of it under the water upstream (the whole of a
## hole in a floor), never faster than √(2 g Δh) across it. Upstream, at a body r from
## its nearest point with the water h deep there, it is drawn in: through a wall at
## Q / (π r h), a half-plane's sink spread over the depth; into a hole in a floor at
## Q / (2 π r h), from every side; from the open sea into her at Q / (2 π r²), a
## hemisphere's sink — each at most u0. Downstream a wall opening b wide throws a jet
## along its normal: u0 · min(1, √(5 b / d)) at d out on its axis, nothing outside a
## half-width of b / 2 + 0.1 d; a hole in a floor throws none sideways. The sky over her
## decks is her outside as the sea is (SinkOpenings): a deckhouse's door or window under
## the sea in the plunge draws the sea in as a gash does. An opening that seeps rather
## than pours (LEAK, FLOOR_GAPS, VENT) and one passing less than current_least_flow move
## nothing. Every opening within current_reach adds in
## passage order (D4), the sum at most the fastest u0 among them; under current_least it
## is none.
##
## Her openings are kept on a grid (SpatialIndex) by how far their currents reach, built
## once: a point asks only those whose reach it is in, and an opening's u0 is found once
## a pose, the first time a point near it asks.
##
## Water falling through a hole in a floor — a stairwell's, a hatch's — from the side over
## it lands on the deck below: pours() names each one pouring so (Falls, #631).

## The kinds of opening that seep rather than pour: they move no water a body feels.
const SEEPS: Array[ShipOpening.Kind] = [
	ShipOpening.Kind.LEAK, ShipOpening.Kind.FLOOR_GAPS, ShipOpening.Kind.VENT
]
## The kinds of opening in a floor whose water falls onto the deck below (pours).
const FALLS: Array[ShipOpening.Kind] = [ShipOpening.Kind.STAIRWELL, ShipOpening.Kind.HATCH]
## How far over a point its cell is looked for: a wader's feet stand on its floor's top,
## which belongs to the space over it already, and a crate's underside likewise.
const LIFT := 0.05
## The shallowest water a sink's speed is spread over, in metres: a film over a floor
## would draw at any speed, which u0 caps anyway.
const SHALLOWEST := 0.05
## A body nearer an opening than this, in metres, is at it: no way to it but through it.
const AT := 0.01
## The side of the grid's squares, in current_reach: an opening's reach covers a few.
const GRID := 0.5

var _rules: BrawlRules
var _gravity: float
## The openings that may pour, each once by name; per one its two sides — a cell of the
## structure, or -1 for the sea — and the way along its axis from its first side to its
## second, +1 or -1.
var _openings: Array[ShipOpening] = []
var _sides := PackedInt32Array()
var _onward := PackedFloat64Array()
## Per opening, for a hole in a floor water may fall through (FALLS): where across her
## plane its pour may land — the cell under it, x/z — and the farthest it may fall there,
## that cell's diagonal; an empty rectangle and 0 for any other.
var _landing: Array[Rect2] = []
var _drop := PackedFloat64Array()
## The passages' names the openings were last matched against (ShipPose.passages), and,
## in passage order, those of the openings that are among them, by index, with their
## passages; and the grid of their reaches, numbered in that order, with each one's reach.
var _names: Array[StringName] = []
var _used := PackedInt32Array()
var _passage := PackedInt32Array()
var _index: SpatialIndex
var _reaches: Array[Rect2] = []
## Per used opening, under the pose last asked about: the speed through it — u0; NAN until
## first asked, 0 for none — and its upstream side, 0 or 1.
var _pose: ShipPose
var _speed := PackedFloat64Array()
var _upstream := PackedByteArray()
## The used openings in a floor water may fall through (FALLS), and those pouring under
## the pose last asked about (pours), and that pose.
var _holes := PackedInt32Array()
var _pours: Array[Pour] = []
var _poured: ShipPose


## Water falling through a hole in a floor onto the deck below (pours): the hole, the m³ a
## second through it, how fast it goes through — u0 — and the side under it, a cell or -1
## for the sea.
class Pour:
	var opening: ShipOpening
	var flow: float
	var speed: float
	var lower: int


## The currents of [param structure]'s openings and [param more] — a hit's, the panels of
## its walls — each of them that joins two of its cells or one and the sea, under
## [param rules], water falling at [param gravity] (SeaPhysics).
func _init(
	rules: BrawlRules, structure: ShipStructure, more: Array[ShipOpening] = [], gravity := 9.81
) -> void:
	_rules = rules
	_gravity = gravity
	var named: Dictionary[StringName, bool] = {}
	var all: Array[ShipOpening] = structure.openings.duplicate()
	all.append_array(more)
	for opening: ShipOpening in all:
		if named.has(opening.name) or opening.kind in SEEPS or opening.joins.size() != 2:
			continue
		if opening.facing() == -1:
			continue
		var first := _side_of(structure, opening.joins[0])
		var second := _side_of(structure, opening.joins[1])
		if first == -2 or second == -2 or first == second:
			continue
		named[opening.name] = true
		_openings.append(opening)
		_sides.append_array([first, second])
		var axis := opening.facing()
		var onward := 0.0
		if second != -1:
			onward = signf(_middle(structure, second, axis) - opening.centre[axis])
		else:
			onward = -signf(_middle(structure, first, axis) - opening.centre[axis])
		_onward.append(onward if onward != 0.0 else 1.0)
		var lower := second if onward < 0.0 else first
		if axis == 1 and opening.kind in FALLS and lower != -1:
			var box := structure.cells[lower]
			_landing.append(
				Rect2(box.low.x, box.low.z, box.high.x - box.low.x, box.high.z - box.low.z)
			)
			_drop.append((box.high - box.low).length())
		else:
			_landing.append(Rect2())
			_drop.append(0.0)


## The currents of piece [param piece] of [param config]'s match, under [param schedule]:
## null without a structure — no cells, no openings, nothing moves.
static func of_piece(config: MatchConfig, schedule: SinkSchedule, piece: int) -> Currents:
	var structure := config.ship.structure if piece == 0 else schedule.structure_of(piece)
	if structure == null:
		return null
	var more: Array[ShipOpening] = []
	if schedule.damage() != null:
		more.append_array(schedule.damage().openings)
	more.append_array(schedule.failing())
	return Currents.new(config.rules, structure, more, SeaPhysics.load_default().gravity)


## Its openings among [param passages] (ShipPose.passages), in passage order: per one,
## [the opening, its passage's place among them, its first side, its second] — a cell, or
## -1 for the sea — as the currents match them (WaterFronts).
func joined(passages: Array[StringName]) -> Array[Array]:
	var at: Dictionary[StringName, int] = {}
	for index in _openings.size():
		at[_openings[index].name] = index
	var found: Array[Array] = []
	for passage in passages.size():
		if at.has(passages[passage]):
			var index: int = at[passages[passage]]
			found.append([_openings[index], passage, _sides[index * 2], _sides[index * 2 + 1]])
	return found


## Cell [param place] of [param structure], -1 for her outside — the sea or the sky over
## her decks, whose water is the sea's — -2 for a cell it has not.
static func _side_of(structure: ShipStructure, place: StringName) -> int:
	if place == ShipOpening.SEA or place == ShipOpening.SKY:
		return -1
	var cell := structure.cell_named(place)
	return cell if cell != -1 else -2


## The middle of [param structure]'s cell [param cell] along [param axis].
static func _middle(structure: ShipStructure, cell: int, axis: int) -> float:
	var box := structure.cells[cell]
	return (box.low[axis] + box.high[axis]) * 0.5


## The current, x/z in ship space, at [param point] — a body's feet or a crate's underside,
## in the water — under [param pose], this piece's.
func at(pose: ShipPose, point: Vector3) -> Vector2:
	if pose.flows.is_empty() or _openings.is_empty() or pose.levels.is_empty():
		return Vector2.ZERO
	_ready_for(pose)
	if _used.is_empty():
		return Vector2.ZERO
	var found := _index.near(Rect2(Vector2(point.x, point.z), Vector2.ZERO))
	if found.is_empty():
		return Vector2.ZERO
	var cell := pose.cell_at(point + Vector3.UP * LIFT)
	var depth := -1.0
	var sum := Vector2.ZERO
	var fastest := 0.0
	for used: int in found:
		var through := _through(pose, used)
		if through <= 0.0:
			continue
		var index := _used[used]
		var opening := _openings[index]
		var half := opening.size * 0.5
		var near := opening.centre + (point - opening.centre).clamp(-half, half)
		var toward := Vector2(near.x - point.x, near.z - point.z)
		var away := toward.length()
		if away > _rules.current_reach:
			continue
		var up := _upstream[used]
		var axis := opening.facing()
		# The way the water goes through it, and how far past it downstream the point is.
		var onward := _onward[index] if up == 0 else -_onward[index]
		var past := (point[axis] - opening.centre[axis]) * onward
		var moved := Vector2.ZERO
		if cell == _sides[index * 2 + up] and (axis == 1 or past < 0.0):
			if depth < 0.0 and cell != -1:
				depth = maxf(pose.water_height(point) - pose.cells.floor_of(cell), SHALLOWEST)
			moved = _drawn(used, cell, point, near, toward, away, depth)
		elif cell == _sides[index * 2 + 1 - up] and axis != 1 and past > 0.0:
			moved = _jet(opening, axis, onward, through, past, point)
		if moved != Vector2.ZERO:
			sum += moved
			fastest = maxf(fastest, through)
	sum = sum.limit_length(fastest)
	return sum if sum.length() >= _rules.current_least else Vector2.ZERO


## The fastest the water anywhere in [param area] — across her plane, this piece's ship
## space — can carry a body under [param pose], this piece's (ContactWatch): x the fastest
## u0 of an opening whose current reaches into it, the most any sum of currents there goes
## (at); y the fastest a hole's pour landing in it can hit the deck — u0 and a fall of its
## lower cell's diagonal — which throws a body under it at current_wade_share of that
## (Falls, Movement). Bounds, not answers: the sim never asks it.
func fastest_in(pose: ShipPose, area: Rect2) -> Vector2:
	if pose.flows.is_empty() or _openings.is_empty() or pose.levels.is_empty():
		return Vector2.ZERO
	_ready_for(pose)
	var most := Vector2.ZERO
	if _used.is_empty():
		return most
	for used: int in _index.near(area):
		if not _reaches[used].intersects(area, true):
			continue
		var through := _through(pose, used)
		if through <= 0.0:
			continue
		most.x = maxf(most.x, through)
		var drop := _drop[_used[used]]
		if drop > 0.0:
			most.y = maxf(most.y, sqrt(through * through + 2.0 * _gravity * drop))
	return most


## The holes in a floor water falls through under [param pose], this piece's: each of FALLS
## passing at least current_least_flow, the water over it standing higher than under it.
func pours(pose: ShipPose) -> Array[Pour]:
	if is_same(pose, _poured):
		return _pours
	_poured = pose
	_pours = []
	if pose.flows.is_empty() or _openings.is_empty() or pose.levels.is_empty():
		return _pours
	_ready_for(pose)
	for used: int in _holes:
		var through := _through(pose, used)
		var index := _used[used]
		var upper := 1 if _onward[index] > 0.0 else 0
		if through <= 0.0 or _upstream[used] != upper:
			continue
		var pour := Pour.new()
		pour.opening = _openings[index]
		pour.flow = pose.flows[_passage[used]]
		pour.speed = through
		pour.lower = _sides[index * 2 + 1 - upper]
		_pours.append(pour)
	return _pours


## The pull toward used opening [param used] of a body at [param point] on its upstream
## side, [param side] — a cell, or the sea — [param away] across from its nearest point
## [param near] that way, [param toward], in water [param depth] deep there.
func _drawn(
	used: int, side: int, point: Vector3, near: Vector3, toward: Vector2, away: float, depth: float
) -> Vector2:
	if away <= AT:
		return Vector2.ZERO
	var through := _speed[used]
	var flow := _pose.flows[_passage[used]]
	var speed := through
	if side == -1:
		var r := point.distance_to(near)
		speed = flow / (TAU * r * r)
	else:
		var spread := TAU if _openings[_used[used]].facing() == 1 else PI
		speed = flow / (spread * away * depth)
	return toward / away * minf(speed, through)


## The jet out of wall [param opening], flat across [param axis], going [param onward]
## along it [param through] fast, at a body [param out] metres out of it at
## [param point]: none outside its spread or past current_reach.
func _jet(
	opening: ShipOpening, axis: int, onward: float, through: float, out: float, point: Vector3
) -> Vector2:
	if out > _rules.current_reach:
		return Vector2.ZERO
	var along := 2 if axis == 0 else 0
	var wide := opening.size[along]
	if absf(point[along] - opening.centre[along]) > wide * 0.5 + 0.1 * out:
		return Vector2.ZERO
	var speed := through * minf(1.0, sqrt(5.0 * wide / out))
	var normal := Vector2(onward, 0.0) if axis == 0 else Vector2(0.0, onward)
	return normal * speed


## The speed water goes through used opening [param used] under [param pose] — u0 — found
## once a pose, with its upstream side: 0 where it passes none a body feels.
func _through(pose: ShipPose, used: int) -> float:
	if not is_nan(_speed[used]):
		return _speed[used]
	_speed[used] = 0.0
	var flow := pose.flows[_passage[used]]
	if flow < _rules.current_least_flow:
		return 0.0
	var index := _used[used]
	var opening := _openings[index]
	var first := _level(pose, _sides[index * 2])
	var second := _level(pose, _sides[index * 2 + 1])
	_upstream[used] = 0 if first >= second else 1
	var high := maxf(first, second)
	var bottom := opening.centre - Vector3.UP * opening.size.y * 0.5
	var share := 1.0
	if opening.facing() != 1:
		var top := pose.height_of(high, opening.centre)
		share = clampf((top - bottom.y) / opening.size.y, 0.0, 1.0)
	var open := 1.0 - float(pose.doors_shut.get(opening.name, 0.0))
	var area := opening.flow_area()
	var failed: int = pose.opened.get(opening.name, 0)
	if failed == 2:
		open = 1.0
	elif failed == 1 and opening.leak_area > 0.0:
		area = opening.leak_area
		open = 1.0
	var wet := area * share * open
	var head := high - maxf(minf(first, second), pose.world_height(bottom))
	if wet <= 0.0 or head <= 0.0:
		return 0.0
	_speed[used] = minf(flow / wet, sqrt(2.0 * _gravity * head))
	return _speed[used]


## The world height the water of [param side] stands at under [param pose]: its cell's,
## or the sea's 0.
static func _level(pose: ShipPose, side: int) -> float:
	return 0.0 if side == -1 else pose.levels[side]


## Matches the openings to [param pose]'s passages the first time they are asked of
## (ShipPose.passages: the bake's, the one list every pose of a match shares), and forgets
## the speeds of the pose before.
func _ready_for(pose: ShipPose) -> void:
	if not is_same(pose.passages, _names):
		_match(pose.passages)
		_pose = null
	if is_same(pose, _pose):
		return
	_pose = pose
	_speed.fill(NAN)


## The openings among [param passages], in their order, and the grid of how far each
## one's current reaches: its rectangle across her plane, current_reach round it.
func _match(passages: Array[StringName]) -> void:
	_names = passages
	_used.clear()
	_passage.clear()
	_holes.clear()
	var at: Dictionary[StringName, int] = {}
	for index in _openings.size():
		at[_openings[index].name] = index
	for passage in passages.size():
		if at.has(passages[passage]):
			var index: int = at[passages[passage]]
			if _openings[index].facing() == 1 and _openings[index].kind in FALLS:
				_holes.append(_used.size())
			_used.append(index)
			_passage.append(passage)
	_speed.resize(_used.size())
	_upstream.resize(_used.size())
	var reach := _rules.current_reach
	var areas: Array[Rect2] = []
	var bounds := Rect2()
	for used in _used.size():
		var opening := _openings[_used[used]]
		var low := opening.centre - opening.size * 0.5
		var area := Rect2(low.x, low.z, opening.size.x, opening.size.z).grow(reach)
		if _drop[_used[used]] > 0.0:
			area = area.merge(_landing[_used[used]])
		areas.append(area)
		bounds = area if used == 0 else bounds.merge(area)
	_index = SpatialIndex.new(bounds, reach * GRID)
	_reaches = areas
	for used in areas.size():
		_index.insert(used, areas[used])
