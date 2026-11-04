extends GutTest
## The bots' reads of the water natively (#410, NativeWater) against the GDScript they
## stand in for: on her real ships' walk graphs under the poses of a match's sinking, a
## graph whose loops go to the extension and one whose loops run in GDScript give the
## same answers bit for bit — every zone's floor over its water, height and flooding,
## the share of her decks under, the portals each way of searching may not go through,
## the highest zone a search reaches, and a bot's refuge from it over a window. Where the
## extension is not loaded there is nothing to hold it to; CI sets
## SINKING_NATIVE_REQUIRED, so a missing library there fails.

const SHIPS: Array[String] = [
	"res://data/ships/steamer.tres", "res://data/ships/small_titanic.tres"
]
## The shares of her sinking asked at, from the start, which holds no water inside her.
const SHARES: Array[float] = [0.0, 0.5, 0.8, 0.95]
## Of a ship's starts — every platform's middle — how many each pose searches from.
const STARTS := 3


func test_her_ships_read_the_water_alike_as_she_sinks() -> void:
	if not _loaded():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1515
	var profile := BotProfile.for_tier(&"normal")
	for path in SHIPS:
		var layout: ShipLayout = load(path)
		var sim := SimFixtures.sim(1, _sinking(path), layout)
		var native := WalkGraph.new(layout, sim.surfaces, SimFixtures.rules())
		var reference := WalkGraph.new(layout, sim.surfaces, SimFixtures.rules())
		assert_not_null(native._water, "%s reads the water natively" % path)
		_in_gdscript(reference)
		var refuges: Array[BotRefuge] = [
			BotRefuge.new(native, profile), BotRefuge.new(reference, profile)
		]
		refuges[1]._water = null
		var end := sim.schedule.plunge_tick()
		if end <= 0:
			end = sim.schedule.end_tick()
		for share: float in SHARES:
			var tick := int(end * share)
			var pose := sim.schedule.pose_at(tick)
			var picks: Array = []
			for pick in STARTS:
				var platform := rng.randi_range(0, layout.platforms.size() - 1)
				var middle := layout.platforms[platform].area.get_center()
				(
					picks
					. append(
						[
							Vector3(middle.x, layout.platforms[platform].height, middle.y),
							platform,
							rng.randi_range(-1, native.zone_count() - 1),
						]
					)
				)
			var answers: Array = []
			for side in 2:
				var graph: WalkGraph = native if side == 0 else reference
				answers.append(_ask(graph, refuges[side], pose, tick, picks))
			_assert_alike(answers[0], answers[1], "%s at %d%%" % [path, int(share * 100)])


## What [param graph] and [param refuge] answer of [param pose], seen on [param tick],
## from each of [param picks] — a start and the zone a refuge was kept in.
func _ask(graph: WalkGraph, refuge: BotRefuge, pose: ShipPose, tick: int, picks: Array) -> Array:
	var answers: Array = [graph.flooded_share(pose)]
	for way in 3:
		answers.append(graph._closed_ways(pose, way == 2, way == 1))
	answers.append(graph.lowest_all(pose))
	answers.append(graph.heights_all(pose))
	var flooded := PackedByteArray()
	for zone in graph.zone_count():
		flooded.append(1 if graph.flooded(zone, pose) else 0)
	answers.append(flooded)
	for pick: Array in picks:
		var found := graph.search(pick[0], pick[1], pose)
		answers.append(graph.highest_in(found, pose))
		answers.append(refuge.choose(found, pose, tick, pick[2]))
	return answers


## Points [param graph]'s loops at GDScript: the reference.
func _in_gdscript(graph: WalkGraph) -> void:
	graph._water = null
	for points: StillPoints in [graph._ends, graph._middles, graph._centres, graph._corners]:
		points.water = null


## Whether the extension is loaded: a failure where CI requires it, pending elsewhere.
func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeWater"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false


func _assert_alike(native: Array, reference: Array, what: String) -> void:
	if native == reference:
		assert_true(true, what)
		return
	for index in mini(native.size(), reference.size()):
		if native[index] != reference[index]:
			fail_test(
				(
					"%s: answer %d is %s natively, %s in GDScript"
					% [what, index, native[index], reference[index]]
				)
			)
			return
	fail_test("%s: %d answers natively, %d in GDScript" % [what, native.size(), reference.size()])


## Her sinking: the steamer's own, baked from a hit, her cells flooding one by one; the
## small Titanic's keyframed — settling by the head and heeling — as baking the steamer's
## hit into her structure takes minutes.
func _sinking(path: String) -> SinkScenario:
	if path.ends_with("steamer.tres"):
		return load(SimFixtures.STEAMER_SINKING)
	return SimFixtures.scenario(
		[[0.0, 0.0, 0.0, 0.0], [60.0, 6.0, 3.0, 2.0], [120.0, 14.0, 8.0, 5.0]]
	)
