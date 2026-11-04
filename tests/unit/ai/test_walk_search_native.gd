extends GutTest
## The native walk search (#410) against the GDScript it stands in for: the same
## questions put to a NativeWalkSearch and to WalkSearch's own code get the same answers,
## bit for bit — on made-up graphs dense with ties, and on her real ships' graphs under
## the poses of a match's sinking, asked in an order that leaves each search settled part
## way between questions. Where the extension is not loaded (no make native) there is
## nothing to hold it to; CI builds it and sets SINKING_NATIVE_REQUIRED, so a missing
## library there fails rather than passes.

const SHIPS: Array[String] = [
	"res://data/ships/steamer.tres", "res://data/ships/small_titanic.tres"
]
## Of a ship's starts — every platform's middle, every stair's — how many each pose asks
## from, and of its zones how many each search asks after on the way.
const STARTS := 8
const ASKED := 8


## Whether the extension is loaded: a failure where CI requires it, pending elsewhere.
func _loaded() -> bool:
	if ClassDB.class_exists(WalkSearch.NATIVE_GRAPH):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false


func test_made_up_graphs_answer_alike() -> void:
	if not _loaded():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 410
	for graph in 60:
		var zones := rng.randi_range(1, 40)
		var out: Array[PackedInt32Array] = []
		for zone in zones:
			out.append(PackedInt32Array())
		var portal_to := PackedInt32Array()
		var entry := PackedVector3Array()
		var exit := PackedVector3Array()
		var length := PackedFloat64Array()
		var closed := PackedByteArray()
		for portal in rng.randi_range(0, zones * 4):
			out[rng.randi_range(0, zones - 1)].append(portal)
			portal_to.append(rng.randi_range(0, zones - 1))
			# Whole metres on a small grid, so that many ways cost the same: the heap's ties.
			entry.append(Vector3(rng.randi_range(0, 3), 0.0, rng.randi_range(0, 3)))
			exit.append(Vector3(rng.randi_range(0, 3), 0.0, rng.randi_range(0, 3)))
			length.append(float(rng.randi_range(0, 2)) if rng.randf() < 0.8 else rng.randf() * 3.0)
			closed.append(1 if rng.randf() < 0.15 else 0)
		var pace := PackedFloat64Array()
		for zone in zones:
			pace.append(1.0 if rng.randf() < 0.7 else 1.0 / 0.3)
		var starts: Array = []
		for start in rng.randi_range(1, 3):
			# A zone of -1 too: a GDScript packed array takes it as its last.
			(
				starts
				. append(
					[
						rng.randi_range(-1, zones - 1),
						float(rng.randi_range(0, 2)),
						Vector3(rng.randi_range(0, 3), 0.0, rng.randi_range(0, 3)),
						rng.randi_range(-1, portal_to.size() - 1),
					]
				)
			)
		var questions := _questions(rng, zones)
		var native := WalkSearch.native_graph(out, portal_to, entry, exit, length, pace)
		var answers: Array = []
		for side: Object in [native, null]:
			var found := WalkSearch.new(zones, side)
			for start: Array in starts:
				found.reach(start[0], start[1], start[2], start[3])
			found.walk(out, portal_to, entry, exit, length, pace, closed)
			answers.append(_ask(found, questions, zones))
		_assert_alike(answers[0], answers[1], "made-up graph %d" % graph)


func test_her_ships_answer_alike_as_she_sinks() -> void:
	if not _loaded():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1912
	for path in SHIPS:
		var layout: ShipLayout = load(path)
		var sim := SimFixtures.sim(1, _sinking(path), layout)
		var graph := WalkGraph.new(layout, sim.surfaces, SimFixtures.rules())
		var native: Object = graph._native_graph
		assert_not_null(native, "%s lays its graph out for the native search" % path)
		var starts := _starts(layout, sim.surfaces)
		var end := sim.schedule.plunge_tick()
		if end <= 0:
			end = sim.schedule.end_tick()
		for share: float in [0.35, 0.6, 0.8, 0.95]:
			var pose := sim.schedule.pose_at(int(end * share))
			for pick in STARTS:
				var start: Array = starts[rng.randi_range(0, starts.size() - 1)]
				var questions := _questions(rng, graph.zone_count())
				for way in 3:
					var answers: Array = []
					for side: Object in [native, null]:
						graph._native_graph = side
						var found := graph.search(start[0], start[1], pose, way == 2, way == 1)
						answers.append(_ask(found, questions, graph.zone_count()))
					graph._native_graph = native
					_assert_alike(
						answers[0],
						answers[1],
						"%s at %d%% from %s, way %d" % [path, int(share * 100), start[0], way]
					)


## Every platform's middle on it, and every stair's middle on it: where a search starts.
func _starts(layout: ShipLayout, surfaces: Surfaces) -> Array:
	var starts: Array = []
	for platform in layout.platforms.size():
		var middle := layout.platforms[platform].area.get_center()
		starts.append([Vector3(middle.x, layout.platforms[platform].height, middle.y), platform])
	for ramp in layout.ramps.size():
		var middle := (layout.ramps[ramp].end_point(0) + layout.ramps[ramp].end_point(1)) / 2.0
		starts.append([middle, surfaces.platform_count() + ramp])
	return starts


## The zones a search is asked after and how far each settling may go, drawn once so
## both sides are asked the same.
func _questions(rng: RandomNumberGenerator, zones: int) -> Array:
	var asked: Array = []
	for question in ASKED:
		asked.append([rng.randi_range(-1, zones), rng.randf_range(0.0, 40.0)])
	return asked


## What [param found] answers, in an order that settles it part way between questions:
## whether it reaches each zone asked and its cost within a bound, every zone it
## reaches, the ways, then every cost and every zone's way.
func _ask(found: WalkSearch, questions: Array, zones: int) -> Array:
	var answers: Array = [found.is_empty()]
	for question: Array in questions:
		answers.append(found.reaches(question[0]))
		answers.append(found.cost_to(question[0], question[1]))
	answers.append(found.reached())
	for question: Array in questions:
		answers.append(found.way_to(question[0]))
		answers.append(found.cost_to(question[0]))
	answers.append(found.costs())
	for zone in zones:
		answers.append(found.way_to(zone))
	return answers


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
