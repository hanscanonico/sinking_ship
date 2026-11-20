class_name BotFloorWay
extends RefCounted
## A bot's way over the floor to the portal its route goes through next (D10, #491), or to
## its target in its own zone (#497). The walk graph routes as if a zone's floor were open
## from portal to portal, and it is not always: a passage holds the solid side of the stair
## down into it and, beside it, the hole of the stair on down; a staircase's room walls in its
## lift well; a house stands on an open deck, and her gear on her forecastle and poop.
## While a body could walk straight at the point its route gives — the next LOOK metres of
## that walk on a floor, or the leg's own stair, clear of all that holds a body back — the
## bot walks straight there; else round by the floor: the shortest way to the portal, or the
## target, over a grid of CELL squares, each one a body could stand on, never a stair but its
## own — through whatever zones the floor runs through, and over squares FINER of CELL
## across where none is found over CELL's — then along that way as far as it could walk
## straight. It looks once a think, the bot's own think_period, and walks at what
## it found in between. Asked of the Surfaces of the frame it stands in; nothing here rolls
## the bot's stream. The search runs in the game's extension where it is loaded, square for
## square (NativeSurfaces.floor_way, #410): its GDScript is the web's, and the twin the
## extension's answers are held to (test_floor_way_native).

## The side of a square of the floor a way round is found over, in metres.
const CELL := 0.25
## How far along a walk straight at its point the bot looks before it trusts it, in metres.
const LOOK := 2.0
## How far round the box of the bot and the portal a way round is looked for, in metres.
const MARGIN := 6.0
## The most squares a search for a way round settles before it gives up.
const MOST := 4096
## The side of a square, as a part of CELL, a way round none was found for over CELL's
## squares is looked for again over, as far round: a doorway the #360 rule's 0.9 m clear
## leaves a body's middle a lane narrower than CELL, which no square's middle need fall in.
const FINER := 0.5
## How near its end a way none was found to over CELL's squares must be for it to look
## again over FINER's: a doorway's clear width is what keeps a near end from a body, and a
## search over a far one's floor finer still settles too many squares to find it.
const NARROW := MARGIN
## How near the way round it found the bot keeps to it: further off, it looks again — and how
## far its target may move off the end of a way round to it before that way is for where the
## target stood.
const NEAR := 1.0
## The squares ahead along the way that it tries to walk straight to, furthest first.
const AHEAD: Array[int] = [12, 8, 4, 2, 1]
## A body's radius by this is what a square holds: a doorway a body's width wide still lets
## one through.
const SNUG := 0.95
## A body's radius by this is what a walk straight is looked along by, a step of twice it at
## a time: the jamb of a doorway it lines up on (WalkGraph.toward) stands in no walk's way, a
## stair's side or a wall does.
const LEAN := 0.5
## The most ways round it looks for along one leg — or one walk at its target in its own
## zone — once off the last it found.
const FINDS := 4

var _surfaces: Surfaces
var _rules: BrawlRules
## What a square holds, and what a walk straight is looked along by (SNUG, LEAN).
var _snug: float
var _lean: float
## Ticks between its looks: the bot's think_period.
var _every: int
## Ticks to its next look, and where it walks till then: Vector3.INF for the point its route
## gives.
var _wait := 0
var _aim := Vector3.INF
## The way round it found last, its points from where it stood to the portal or the target,
## the leg it is for — null for its target in its own zone — and how many more it may look for
## along that leg; empty for none.
var _way := PackedVector3Array()
var _way_leg: WalkGraph.Portal = null
var _finds := FINDS
## Whether a search over CELL's squares found no way round along this leg from further than
## NARROW off its end, where it does not look over FINER's: it looks again only once within
## NARROW of it (#567).
var _beyond := false
## What the extension's search is handed of these and the rules (NativeSurfaces.floor_way):
## over CELL's squares, and over FINER's.
var _native_rules: PackedFloat64Array
var _native_fine: PackedFloat64Array
## How many squares its last search in GDScript settled (test_floor_way_native).
var _settled := 0


func _init(walk_graph: WalkGraph, rules: BrawlRules, think_period: int) -> void:
	_surfaces = walk_graph.surfaces()
	_rules = rules
	_snug = rules.body_radius * SNUG
	_lean = rules.body_radius * LEAN
	_every = think_period
	_native_rules = PackedFloat64Array(
		[
			CELL,
			MARGIN,
			MOST,
			_snug,
			rules.step_height,
			rules.body_height,
			rules.crawl_height,
			rules.railing_height
		]
	)
	_native_fine = _native_rules.duplicate()
	_native_fine[0] = CELL * FINER
	_native_fine[2] = MOST / (FINER * FINER)


## Where a body at [param from] on [param surface] walks to go on along [param leg] toward
## [param to] — the walk graph's point for it (WalkGraph.toward) — or, with no leg, to
## [param to] in its own zone, where its target stands: [param to] itself while a walk
## straight at it holds, or the bot is off its feet; else the furthest point along the way
## round to the leg's entry, or to [param to], that it could walk straight to — [param to]
## once that is the way's end, or with no way round found. Between its looks, the same.
## On the leg's own stair, as it reckons, [param to]: the way round ends at the stair's near
## end, and it is through it (#550). A railing beside the stair holds its reckoned body off
## the stair as it holds its body (BotReckoning.by_steps, #557).
func toward(from: Vector3, surface: int, leg: WalkGraph.Portal, to: Vector3) -> Vector3:
	if surface == Surfaces.NONE:
		return to
	if _way_leg != leg:
		_way.clear()
		_way_leg = leg
		_finds = FINDS
		_beyond = false
		_wait = 0
	elif leg == null and not _way.is_empty() and _flat(_way[_way.size() - 1], to) > NEAR:
		# Its target has moved on from where the way round to it ends.
		_way.clear()
		_wait = 0
	if leg != null and leg.ramp != WalkGraph.NONE and surface == _surfaces.ramp_surface(leg.ramp):
		_wait = 0
		return to
	if _wait > 0:
		_wait -= 1
		return to if _aim == Vector3.INF else _aim
	_wait = _every - 1
	_aim = _look(from, surface, leg, to)
	return to if _aim == Vector3.INF else _aim


## Whether a body at [param from] is on the way round it holds for [param leg], within NEAR
## of a point of it: through whatever zones that way takes it, it is still on its leg.
func holds(leg: WalkGraph.Portal, from: Vector3) -> bool:
	return leg != null and leg == _way_leg and _nearest(from) != -1


## One look (toward): Vector3.INF to walk at [param to], else the point of the way round to
## walk to. None found, it looks for none again along the leg — unless it looked from where no
## body could stand, where its reckoning, carried on by a walk that a blocker stopped, puts
## it: none from there says nothing of the leg, and it looks again next think; or from
## further than NARROW off its end, where it looks again once within NARROW (#567).
func _look(from: Vector3, surface: int, leg: WalkGraph.Portal, to: Vector3) -> Vector3:
	var keep := PackedInt32Array([surface])
	if leg != null and leg.ramp != WalkGraph.NONE:
		keep.append(_surfaces.ramp_surface(leg.ramp))
	var heads := _heads(from, leg, to)
	var near := _nearest(from)
	if near == -1:
		_way.clear()
		if _finds == 0 or _holds(from, to, heads, keep):
			return Vector3.INF
		var end := to if leg == null else leg.entry
		var narrow := _flat(from, end) <= NARROW
		if _beyond and not narrow:
			return Vector3.INF
		_way = _find(from, end, keep)
		if _way.is_empty() and narrow:
			_way = _find(from, end, keep, true)
		var ends := _way.is_empty() and _stands(from, surface, keep, _snug)
		if ends and not narrow:
			# A doorway's lane may fall between CELL's squares: none found over them says
			# nothing of the leg till FINER's are looked over too, within NARROW.
			_beyond = true
		else:
			_finds = 0 if ends else _finds - 1
		if _way.is_empty():
			return Vector3.INF
		near = 0
	var last := _way.size() - 1
	for ahead: int in AHEAD:
		var at := mini(near + ahead, last)
		if _walks(from, _way[at], keep, INF):
			if at == last and _holds(from, to, heads, keep):
				return Vector3.INF
			return _way[at]
	return _way[mini(near + 1, last)]


## Whether a walk straight from [param from] at [param to] holds, as far as LOOK (_walks), and
## walked on to [param heads] (_heads), as far as LOOK, never steps onto a stair not of
## [param keep] (_strays): off a stair's foot or head a walk is taken up or down it, into a
## zone whose route is back the way it came.
func _holds(from: Vector3, to: Vector3, heads: Vector3, keep: PackedInt32Array) -> bool:
	if not _walks(from, to, keep, LOOK):
		return false
	return heads == to or not _strays(from, heads, keep, LOOK)


## Where a body at [param from] walking at [param to], the point the walk graph gives it for
## [param leg] (WalkGraph.toward), heads: in front of the leg's way through, that point stays
## a body's width on along the body's own line, which it walks on to where that line crosses
## the way through (WalkGraph._line); else [param to] itself, and [param to] once it lies
## further.
func _heads(from: Vector3, leg: WalkGraph.Portal, to: Vector3) -> Vector3:
	if leg == null:
		return to
	var offset := Vector2(from.x - leg.entry.x, from.z - leg.entry.z)
	if offset.dot(leg.along) >= 0.0:
		return to
	var room := maxf(leg.half_width - _rules.body_radius * 2.0, 0.0)
	var across := leg.along.orthogonal()
	var side := across * clampf(offset.dot(across), -room, room)
	var crossing := leg.entry + Vector3(side.x, 0.0, side.y)
	return crossing if _flat(from, crossing) > _flat(from, to) else to


## The index of the point of the way round held that lies nearest [param from], within
## NEAR of it; -1 when none does, or none is held.
func _nearest(from: Vector3) -> int:
	var best := -1
	var best_distance := NEAR
	for index in _way.size():
		var distance := Vector2(_way[index].x - from.x, _way[index].z - from.z).length()
		if distance <= best_distance:
			best = index
			best_distance = distance
	return best


## Whether a body could walk straight from [param from] at [param to], as far as
## [param reach] metres of it: its feet carried along it a step at a time — up and down a
## stair on [param keep] — every one where a body LEAN of its radius round could stand
## (_stands).
func _walks(from: Vector3, to: Vector3, keep: PackedInt32Array, reach: float) -> bool:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var length := minf(flat.length(), reach)
	var stride := _lean * 2.0
	if length < stride:
		return true
	var way := flat.normalized()
	var steps := ceili(length / stride)
	var feet := from.y
	for index in range(1, steps + 1):
		var at := Vector2(from.x, from.z) + way * (length * index / steps)
		var point := Vector3(at.x, feet, at.y)
		var surface := _surfaces.under(point, _rules.step_height)
		if not _stands(point, surface, keep, _lean):
			return false
		feet = _surfaces.height_at(surface, point)
	return true


## Whether a walk straight from [param from] at [param to], as far as [param reach] metres of
## it, its feet carried along it a step at a time as _walks carries them, steps onto a stair
## not of [param keep] before it leaves every surface.
func _strays(from: Vector3, to: Vector3, keep: PackedInt32Array, reach: float) -> bool:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var length := minf(flat.length(), reach)
	var steps := ceili(length / (_lean * 2.0))
	var feet := from.y
	for index in range(1, steps + 1):
		var at := Vector2(from.x, from.z) + flat.normalized() * (length * index / steps)
		var point := Vector3(at.x, feet, at.y)
		var surface := _surfaces.under(point, _rules.step_height)
		if surface == Surfaces.NONE:
			return false
		if _surfaces.is_ramp(surface) and not surface in keep:
			return true
		feet = _surfaces.height_at(surface, point)
	return false


## Whether a body [param radius] round could stand with its feet at [param point] on
## [param surface]: a floor, not a stair but one of [param keep], and nothing there holding
## it back, as the sim holds a body on its feet — no blocker, stair side or deck edge too
## high to step onto, crate or railing.
func _stands(point: Vector3, surface: int, keep: PackedInt32Array, radius: float) -> bool:
	if surface == Surfaces.NONE or _surfaces.is_ramp(surface) and not surface in keep:
		return false
	var feet := Vector3(point.x, _surfaces.height_at(surface, point), point.z)
	var contacts := _surfaces.obstacle_contacts(
		feet, radius, _rules.body_height, _rules.step_height, Surfaces.NONE, _rules.crawl_height
	)
	if not contacts.is_empty():
		return false
	var railed := _surfaces.rail_contacts(
		feet, radius, surface, _rules.step_height, _rules.railing_height
	)
	return railed.is_empty()


## The shortest way round by the floor from [param from] to [param end] — a leg's entry, or
## the bot's target — over the squares of a grid round the two, MARGIN past their box, that a
## body could stand on with its feet at [param from]'s height (_stands, [param keep]), eight
## ways — never across a corner — as points from the middle of its first square on to
## [param end]; empty when the search settles MOST squares, or all it can reach, before it
## comes within a square and a half of [param end]. [param fine], over squares FINER of
## CELL across, as many more of them as cover as much floor.
func _find(
	from: Vector3, end: Vector3, keep: PackedInt32Array, fine := false
) -> PackedVector3Array:
	var mirror := _surfaces.native
	if mirror != null:
		return mirror.floor_way(from, end, keep, _native_fine if fine else _native_rules)
	var side := CELL * FINER if fine else CELL
	var most := int(MOST / (FINER * FINER)) if fine else MOST
	var start := Vector2(from.x, from.z)
	var goal := Vector2(end.x, end.z)
	var box := Rect2(start, Vector2.ZERO).expand(goal).grow(MARGIN)
	var origin := (box.position / side).floor() * side
	var width := ceili((box.end.x - origin.x) / side)
	var height := ceili((box.end.y - origin.y) / side)
	var cells := width * height
	var first := _cell(start, origin, width, side)
	# Per square: 0 not yet asked, 1 a body stands there, 2 it does not; the cost to it, the
	# square it was reached from, and whether it is settled.
	var stands := PackedByteArray()
	stands.resize(cells)
	stands[first] = 1
	var cost := PackedFloat64Array()
	cost.resize(cells)
	cost.fill(INF)
	cost[first] = 0.0
	var came := PackedInt32Array()
	came.resize(cells)
	came.fill(-1)
	var done := PackedByteArray()
	done.resize(cells)
	var open := WalkGraph.OpenSet.new()
	open.push(start.distance_to(goal), first)
	var settled := 0
	var reached := -1
	while not open.is_empty() and settled < most:
		var cell := open.pop()
		if done[cell] == 1:
			continue
		done[cell] = 1
		settled += 1
		if _middle(cell, origin, width, side).distance_to(goal) <= side * 1.5:
			reached = cell
			break
		var x := cell % width
		var z := floori(float(cell) / width)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var nz := z + dz
				if dx == 0 and dz == 0 or nx < 0 or nz < 0 or nx >= width or nz >= height:
					continue
				var next := nz * width + nx
				if done[next] == 1 or not _square(next, origin, width, side, from.y, stands, keep):
					continue
				# Never across a corner: both squares it passes between stand too.
				if (
					dx != 0
					and dz != 0
					and not (
						_square(z * width + nx, origin, width, side, from.y, stands, keep)
						and _square(nz * width + x, origin, width, side, from.y, stands, keep)
					)
				):
					continue
				var through := cost[cell] + side * Vector2(dx, dz).length()
				if through < cost[next]:
					cost[next] = through
					came[next] = cell
					open.push(through + _middle(next, origin, width, side).distance_to(goal), next)
	_settled = settled
	var way := PackedVector3Array()
	if reached == -1:
		return way
	way.append(end)
	var back := reached
	while back != -1:
		var middle := _middle(back, origin, width, side)
		way.append(Vector3(middle.x, from.y, middle.y))
		back = came[back]
	way.reverse()
	return way


## Whether a body could stand on square [param cell] of the grid from [param origin],
## [param width] squares wide, each [param side] across, with its feet at [param feet]
## (_stands): asked once, then read from [param stands].
func _square(
	cell: int,
	origin: Vector2,
	width: int,
	side: float,
	feet: float,
	stands: PackedByteArray,
	keep: PackedInt32Array
) -> bool:
	if stands[cell] == 0:
		var middle := _middle(cell, origin, width, side)
		var point := Vector3(middle.x, feet, middle.y)
		var surface := _surfaces.under(point, _rules.step_height)
		stands[cell] = 1 if _stands(point, surface, keep, _snug) else 2
	return stands[cell] == 1


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _cell(point: Vector2, origin: Vector2, width: int, side: float) -> int:
	var at := ((point - origin) / side).floor()
	return int(at.y) * width + int(at.x)


static func _middle(cell: int, origin: Vector2, width: int, side: float) -> Vector2:
	var at := Vector2(cell % width, floori(float(cell) / width))
	return origin + (at + Vector2(0.5, 0.5)) * side
