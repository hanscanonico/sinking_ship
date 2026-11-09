extends GutTest
## Every way the walk graph keeps through a doorway beside a stair, on the Titanic and her two
## sisters, is one a body walks in the sim, the portal's own way, her level and dry (#561,
## #575): set down in the zone the portal leads out of, short of its line on one of a fan of
## lines across it, and walked straight along its way, a body comes to stand in the zone it
## leads into, past the line, never pressed into a wall on the way. A way the graph keeps that
## no body walks steers a bot into it for good. Only the doorways a stair stands by: there a
## body is on a stair, held by its railings, or in the zone of a stair's end (WalkDoors,
## WayThrough), and there the graph and the sim parted — a strip by a stair's railing on C
## deck narrower than a body, a box behind a partition in the grand staircase on C deck, the
## stairs run on through doorways on D, E and F decks.

const TITANIC := "res://data/ships/titanic.tres"
const BRITANNIC := "res://tests/fixtures/ships/titanic_britannic.tres"
const OLYMPIC := "res://tests/fixtures/ships/titanic_olympic_1913.tres"
## How many lines either side of a portal's middle a body is tried along, spread evenly out
## to SPARE past either side of its width; and how far back from its line on each a body is
## set down, in metres.
const LINES := 8
const SPARE := 0.2
const BACKS: Array[float] = [0.5, 0.8, 1.2]
## How long a body walks along a portal's way on each try, in ticks: two seconds.
const WALK := 60
## How far past a doorway's line a body stands to have gone through it, in metres.
const PAST := 0.001
## How much less than a body's radius round its feet a blocker it is pressed into reaches: a
## body pushed further into a wall than this, on its feet, is squeezed through a gap narrower
## than a body, which is no way (#561).
const PRESSED := 0.02
## How near a stair's area, grown by this, a doorway portal's line stands to be tried, in
## metres; and how far out of the stair's heights its floor may stand.
const NEAR := 1.2
const STOREY := 0.5
## Where the other body stands out of the way: on her poop deck, aft.
const ASTERN := Vector3(-137.9, 3.3125, 0.0)
## How many ticks one sim is walked before a fresh one is made.
const FRESH := 20000

var _rules: BrawlRules


func before_all() -> void:
	_rules = SimFixtures.rules()


func test_every_way_through_a_doorway_by_a_stair_is_walked() -> void:
	var ships: Array[ShipLayout] = [load(TITANIC), load(BRITANNIC), load(OLYMPIC)]
	for layout: ShipLayout in ships:
		var path := layout.resource_path.get_file()
		var graph := WalkGraph.new(layout, Surfaces.new(layout), _rules)
		var sim := _sim(layout)
		var tried := 0
		var dead: Array[String] = []
		for portal: WalkGraph.Portal in graph.portals():
			if portal.ramp != WalkGraph.NONE or not _by_a_stair(layout, portal):
				continue
			if sim.is_over() or sim.state.tick > FRESH:
				sim = _sim(layout)
			tried += 1
			if not _walked(sim, graph, portal):
				dead.append("%d -> %d at %s" % [portal.from_zone, portal.to_zone, portal.entry])
		assert_gt(tried, 0, "%s has doorways by a stair" % path)
		assert_eq(dead.size(), 0, "%s's ways no body walks: %s" % [path, ", ".join(dead)])


## A sim of [param layout] with two bodies, her held level and dry.
func _sim(layout: ShipLayout) -> MatchSim:
	var sim := SimFixtures.sim(2, null, layout)
	HeldPose.hold(sim, HeldPose.flooded(layout, -layout.freeboard, {}))
	return sim


## Whether [param portal]'s line stands within NEAR of a stair of [param layout], its floor
## within STOREY of the stair's heights.
func _by_a_stair(layout: ShipLayout, portal: WalkGraph.Portal) -> bool:
	var at := Vector2(portal.entry.x, portal.entry.z)
	for ramp: ShipRamp in layout.ramps:
		var low := minf(ramp.start_height, ramp.end_height) - STOREY
		var high := maxf(ramp.start_height, ramp.end_height) + STOREY
		if portal.entry.y >= low and portal.entry.y <= high and ramp.area.grow(NEAR).has_point(at):
			return true
	return false


## Whether a body in [param sim]'s seat 0 walks through [param portal] of [param graph] its
## own way on any try: set down in its from_zone on one of the lines across it (LINES), the
## middle first and on out either way, BACKS back from its line, and walked WALK ticks
## straight along it, it stands in its to_zone PAST its line, never PRESSED into a blocker on
## its feet before.
func _walked(sim: MatchSim, graph: WalkGraph, portal: WalkGraph.Portal) -> bool:
	var way := portal.along.normalized()
	var aside := Vector3(-way.y, 0.0, way.x)
	var half := portal.half_width + SPARE
	var line := Vector2(portal.entry.x, portal.entry.z)
	for index in LINES * 2 + 1:
		var off := half * ceili(index * 0.5) * (1.0 if index % 2 == 0 else -1.0) / LINES
		for back: float in BACKS:
			var start := portal.entry + aside * off - Vector3(way.x, 0.0, way.y) * back
			var surface := sim.surfaces.under(start, _rules.step_height)
			if surface == Surfaces.NONE:
				continue
			start.y = sim.surfaces.height_at(surface, start)
			SimFixtures.place(sim, 0, start)
			SimFixtures.place(sim, 1, ASTERN)
			if graph.zone_at(start, sim.state.seats[0].surface) != portal.from_zone:
				continue
			if _walks_through(sim, graph, portal, way, line):
				return true
	return false


## Whether the body in [param sim]'s seat 0, walked WALK ticks along [param way], comes to
## stand in [param portal]'s to_zone PAST [param line], never PRESSED before.
func _walks_through(
	sim: MatchSim, graph: WalkGraph, portal: WalkGraph.Portal, way: Vector2, line: Vector2
) -> bool:
	var frame := SimFixtures.frame(0, way)
	for _tick in WALK:
		SimFixtures.step(sim, {0: frame})
		var seat := sim.state.seats[0]
		if seat.surface == Surfaces.NONE:
			continue
		var pressed := sim.surfaces.obstacle_contacts(
			seat.pos,
			_rules.body_radius - PRESSED,
			_rules.body_height,
			_rules.step_height,
			Surfaces.NONE,
			_rules.crawl_height
		)
		if seat.body == PlayerState.Body.GROUNDED and not pressed.is_empty():
			return false
		var past := (Vector2(seat.pos.x, seat.pos.z) - line).dot(way)
		if graph.zone_at(seat.pos, seat.surface) == portal.to_zone and past >= PAST:
			return true
	return false
