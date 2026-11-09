extends GutTest
## No body walks out through the line of the Titanic's shell (#573), and none walks off a
## flight's side further down than a step (#574). Where her plates draw shell plating or a
## bulwark along a deck's edge, it holds a body; where they draw an open rail, a railing
## stands. A body walked into the sea off B deck forward of its house, off C deck under her
## poop and her forecastle and off the outboard sides of the A deck ladders down to the
## forward well, and off No. 2 hold's ladders into the void past the tank top's floor: walks
## a bot reaches. Her stairs and ladders were railed along every open side, and an escape
## ladder ran in its own cased way: a body stepped off the side of 34 of her flights and
## fell as far as 7.2 m, off her boiler rooms' escape ladders onto the stokehold floor. So
## every walk a body sets out on along her — off each side of each of her floors a metre
## apart, off each side of each of her flights at its quarters, half a metre in from the
## edge, straight out of it — from where the walk graph reaches from her first spawn ends
## out of the sea, and none off a flight falls further than a step: on her and on her
## sisters.

const SHIPS: Array[String] = [
	"res://data/ships/titanic.tres",
	"res://tests/fixtures/ships/titanic_britannic.tres",
	"res://tests/fixtures/ships/titanic_olympic_1913.tres",
]
## How far in from an edge a walk sets out, in metres.
const IN_FROM := 0.5
## How long a body walks, then how long it is given to land, in seconds.
const WALK := 1.5
const SETTLE := 3.0
## The ticks a body stands still for before its walk is over.
const STOOD := 3
## Bodies walk side by side, each set out this far from every other one (metres): further
## than two walks and their falls carry them, so no two meet.
const APART := 16.0

var _rules := SimFixtures.rules()
## Per ship of SHIPS, by its path: what went wrong on its walks (_gone_wrong).
var _walked_on := {}


func before_all() -> void:
	for path: String in SHIPS:
		_walked_on[path] = _gone_wrong(load(path))


func test_no_walk_on_her_leaves_her_shell() -> void:
	for path: String in SHIPS:
		assert_eq(_ending(_walked_on[path], "", " ends swimming "), PackedStringArray(), path)


func test_no_walk_off_her_flights_sides_falls_past_a_step() -> void:
	for path: String in SHIPS:
		assert_eq(_ending(_walked_on[path], "ramp ", " falls "), PackedStringArray(), path)


func test_a_walk_into_the_sea_is_found() -> void:
	# The steamer with her railings taken away (test data): a body walks off her decks' edges.
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	layout.railings = []
	layout.props = []
	var found := _ending(_gone_wrong(layout), "", " ends swimming ")
	assert_gt(found.size(), 0, "walks off her open edges")


func test_a_fall_off_a_flights_side_is_found() -> void:
	# The steamer's hull round a bare deck railed along her sides and a flight up onto a
	# deck 3 m over it, nothing along its sides (test data): a body walks off them onto the
	# deck under them.
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	var railings: Array[ShipRailing] = []
	for z: float in [-1.5, 1.5]:
		var railing := ShipRailing.new()
		railing.from = Vector2(-12.0, z)
		railing.to = Vector2(8.0, z)
		railings.append(railing)
	var deck := ShipPlatform.new()
	deck.name = &"main deck"
	deck.area = Rect2(-12.0, -1.5, 20.0, 3.0)
	var upper := ShipPlatform.new()
	upper.name = &"upper deck"
	upper.area = Rect2(4.0, -1.5, 4.0, 3.0)
	upper.height = 3.0
	var flight := ShipRamp.new()
	flight.area = Rect2(-2.0, -0.6, 6.0, 1.2)
	flight.end_height = 3.0
	var platforms: Array[ShipPlatform] = [deck, upper]
	var ramps: Array[ShipRamp] = [flight]
	layout.platforms = platforms
	layout.ramps = ramps
	layout.blockers = []
	layout.railings = railings
	layout.ladders = []
	layout.props = []
	layout.rooms = []
	layout.bonus_spots = []
	layout.spawns = [Vector3(-10.0, 0.0, 0.0)]
	var found := _ending(_gone_wrong(layout), "ramp ", " falls ")
	assert_eq(found.size(), 6, "off both its sides at each of its quarters")


## The lines of [param found] starting with [param what] that tell of [param ending].
func _ending(found: PackedStringArray, what: String, ending: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in found:
		if line.begins_with(what) and line.contains(ending):
			out.append(line)
	return out


## Every walk on [param layout] that ends in the sea or falls further than a step on its
## way, with where it set out and ended: held at her floating draught, every compartment
## dry.
func _gone_wrong(layout: ShipLayout) -> PackedStringArray:
	var surfaces := Surfaces.new(layout)
	var pose := HeldPose.flooded(layout, -layout.freeboard, {})
	var graph := WalkGraph.new(layout, surfaces, _rules)
	var spawn := layout.spawns[0]
	var costs := graph.search(spawn, surfaces.under(spawn, _rules.step_height), pose).costs()
	var walks: Array = []
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		var area := platform.area
		var x := ceilf(area.position.x)
		var along := PackedFloat64Array()
		while x <= area.end.x:
			along.append(x)
			x += 1.0
		if along.is_empty():
			along.append(area.get_center().x)
		for at: float in along:
			for side: float in [-1.0, 1.0]:
				var edge := area.position.y if side < 0.0 else area.end.y
				var start := Vector3(at, platform.height, edge - side * IN_FROM)
				if area.has_point(Vector2(start.x, start.z)):
					var what := "%s (platform %d)" % [platform.name, index]
					_add(walks, graph, costs, start, Vector2(0.0, side), what)
	for index in layout.ramps.size():
		var ramp := layout.ramps[index]
		var area := ramp.area
		for share: float in [0.25, 0.5, 0.75]:
			for side: float in [-1.0, 1.0]:
				var point := area.get_center()
				var move := Vector2(side, 0.0)
				if ramp.axis == ShipRamp.Axis.X:
					point.x = area.position.x + area.size.x * share
					move = Vector2(0.0, side)
				else:
					point.y = area.position.y + area.size.y * share
				var start := Vector3(point.x, ramp.height_at(point.x, point.y), point.y)
				_add(walks, graph, costs, start, move, "ramp %d" % index)
	var seats := mini(layout.max_seats, layout.spawns.size())
	var sim := SimFixtures.sim(seats, null, layout)
	HeldPose.hold(sim, pose)
	return _walked(sim, walks)


## [param walks] given one more: from [param start], along [param move], if a body stands
## there clear of every blocker on floor [param graph] reaches ([param costs]).
func _add(
	walks: Array,
	graph: WalkGraph,
	costs: PackedFloat64Array,
	start: Vector3,
	move: Vector2,
	what: String
) -> void:
	var surfaces := graph.surfaces()
	var surface := surfaces.under(start, _rules.step_height)
	if surface == Surfaces.NONE:
		return
	start.y = surfaces.height_at(surface, start)
	var radius := _rules.body_radius
	if not (
		surfaces.obstacle_contacts(start, radius, _rules.body_height, _rules.step_height).is_empty()
	):
		return
	var zone := graph.zone_at(start, surface)
	if zone != WalkGraph.NONE and costs[zone] < INF:
		walks.append([start, move, what])


## The walks of [param walks] that end in the sea or fall further than a step, walked by
## [param sim]'s seats side by side, in an order of its own that sets bodies out apart.
func _walked(sim: MatchSim, walks: Array) -> PackedStringArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = 573
	var pending := walks.duplicate()
	for k in range(pending.size() - 1, 0, -1):
		var other := rng.randi_range(0, k)
		var swap: Array = pending[k]
		pending[k] = pending[other]
		pending[other] = swap
	var seats := sim.config.seats
	var found := PackedStringArray()
	while not pending.is_empty():
		var batch: Array = []
		var rest: Array = []
		var k := 0
		while k < pending.size() and batch.size() < seats:
			var walk: Array = pending[k]
			var at: Vector3 = walk[0]
			var clear := true
			for other: Array in batch:
				var from: Vector3 = other[0]
				clear = clear and Vector2(at.x - from.x, at.z - from.z).length() >= APART
			if clear:
				batch.append(walk)
			else:
				rest.append(walk)
			k += 1
		rest.append_array(pending.slice(k))
		pending = rest
		found.append_array(_walk(sim, batch))
	found.sort()
	return found


## The walks of [param batch] that end in the sea or fall further than a step on the way:
## each a fresh body of one seat's, in turn. A fall is from where the body last stood to
## where it lands.
func _walk(sim: MatchSim, batch: Array) -> PackedStringArray:
	var moving := {}
	var still := {}
	for seat in sim.config.seats:
		still[seat] = SimFixtures.frame(seat)
	var last: Array[Vector3] = []
	var stood: Array[int] = []
	var going: Array[bool] = []
	var ground := PackedFloat64Array()
	var air_from := PackedFloat64Array()
	var worst := PackedFloat64Array()
	for seat in batch.size():
		_fresh(sim, seat)
		SimFixtures.place(sim, seat, batch[seat][0])
		moving[seat] = SimFixtures.frame(seat, batch[seat][1])
		last.append(batch[seat][0])
		stood.append(0)
		going.append(true)
		ground.append(batch[seat][0].y)
		air_from.append(NAN)
		worst.append(0.0)
	var found := PackedStringArray()
	var walking := Ticks.from_seconds(WALK)
	var left := batch.size()
	var tick := 0
	while left > 0 and tick < walking + Ticks.from_seconds(SETTLE):
		var frames := still.duplicate()
		for seat in batch.size():
			if going[seat] and tick < walking:
				frames[seat] = moving[seat]
		SimFixtures.step(sim, frames)
		for seat in batch.size():
			var player := sim.state.seats[seat]
			if not going[seat]:
				continue
			var start: Vector3 = batch[seat][0]
			if player.body == PlayerState.Body.SWIMMING:
				found.append(
					(
						"%s: from %s walking %s ends swimming at %s"
						% [batch[seat][2], start, batch[seat][1], player.pos]
					)
				)
				going[seat] = false
				left -= 1
			elif player.body == PlayerState.Body.AIRBORNE:
				if is_nan(air_from[seat]):
					air_from[seat] = ground[seat]
			else:
				if not is_nan(air_from[seat]):
					worst[seat] = maxf(worst[seat], air_from[seat] - player.pos.y)
					air_from[seat] = NAN
				ground[seat] = player.pos.y
			if going[seat] and player.body == PlayerState.Body.GROUNDED:
				stood[seat] = stood[seat] + 1 if player.pos.distance_to(last[seat]) < 0.001 else 0
				if stood[seat] >= STOOD or tick >= walking:
					going[seat] = false
					left -= 1
					if worst[seat] > _rules.step_height:
						found.append(
							(
								"%s: from %s walking %s falls %.2f m, ends at %s on surface %d"
								% [
									batch[seat][2],
									start,
									batch[seat][1],
									worst[seat],
									player.pos,
									player.surface
								]
							)
						)
			last[seat] = player.pos
		tick += 1
	return found


## [param seat]'s body as a match starts it: no stagger, cold or spent stamina of a walk before.
func _fresh(sim: MatchSim, seat: int) -> void:
	var player := sim.state.seats[seat]
	var fresh := PlayerState.new(seat)
	for property: Dictionary in fresh.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			player.set(property["name"], fresh.get(property["name"]))
	player.stamina = _rules.stamina_max
	player.cold = _rules.cold_meter
