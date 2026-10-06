extends GutTest
## The baked timeline (§5b.4, SH28): a pure function of (ship, scenario, seed); its
## compaction within keep_level, keep_turn_deg and keep_air of the bake; its events at their own
## seconds, each warned before it happens; its bytes read back exactly; and its digest
## moved by any byte. Bakes alone, no match played.

const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"
## A wide gash forward: she lurches and stands on end before she is gone.
const STEEP_HIT := "res://tests/fixtures/sinking/hits/steep.tres"
const SEED := 1701
## How far apart, in physics seconds, the compaction is read between the bake's states.
const BETWEEN := 0.5

var _structure: ShipStructure
var _scenario: SinkScenario
var _sea: SeaPhysics


func before_all() -> void:
	_structure = SimFixtures.steamer().structure
	_scenario = load(SimFixtures.STEAMER_SINKING)
	_sea = SeaPhysics.load_default()


## The bake of the explicit hit at [param path], under [param sea] — the shipped
## physics unless told.
func _bake(path: String, sea: SeaPhysics = null) -> SinkBake:
	var physics := sea if sea != null else _sea
	var damage := HitMapper.map_explicit(load(path), _structure, _scenario.hit)
	return SinkBake.new(SinkStepper.new(_structure, damage, physics), physics, _scenario.bake_cap)


## The default match on [param seed_value]: its sinking is the must-sink rule's.
func _config(seed_value: int) -> MatchConfig:
	return MatchConfig.from_rules(load("res://data/match/default.tres"), seed_value)


## The angle in degrees between two unit quaternions, w x y z, in 64-bit floats.
func _degrees_apart(one: PackedFloat64Array, other: PackedFloat64Array) -> float:
	var dot := 0.0
	for part in 4:
		dot += one[part] * other[part]
	return rad_to_deg(2.0 * acos(minf(absf(dot), 1.0)))


func _truth(bake: SinkBake, state: int) -> PackedFloat64Array:
	return SinkTimeline.quaternion_of(bake.rotations().slice(state * 9, state * 9 + 9))


## [param timeline] read at [param seconds] of physics, as SinkSchedule reads it between
## two kept states: the sea, every cell's head, her rotation, and every cell's pocket.
func _read(timeline: SinkTimeline, seconds: float) -> Array:
	var frame := timeline.frame_at(seconds)
	var next := mini(frame + 1, timeline.count() - 1)
	var span := timeline.times[next] - timeline.times[frame]
	var weight := clampf((seconds - timeline.times[frame]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var heads := PackedFloat64Array()
	var pockets := PackedFloat64Array()
	for cell in timeline.cells:
		var a := timeline.heads[frame * timeline.cells + cell]
		heads.append(lerpf(a, timeline.heads[next * timeline.cells + cell], weight))
		pockets.append(timeline.pocket(frame, next, weight, cell))
	var sea := lerpf(timeline.seas[frame], timeline.seas[next], weight)
	return [sea, heads, timeline.blended(frame, next, weight), pockets]


func test_timeline_is_pure_in_ship_scenario_and_seed() -> void:
	var straight := _config(SEED).sinking().timeline
	# Another stream rolled first, and the bake run a few steps a slice: the same bytes.
	SeedStreams.derive(SEED, "match").randi()
	var sliced := _config(SEED)
	var slices := 0
	while not sliced.bake_some(7):
		slices += 1
	assert_gt(slices, 10, "baked across many slices")
	assert_eq(sliced.sinking().timeline.digest(), straight.digest(), "the same seed, the same")
	assert_eq(sliced.sinking().timeline.to_bytes(), straight.to_bytes(), "byte for byte")
	assert_ne(_config(SEED + 1).sinking().timeline.digest(), straight.digest(), "another seed")
	var given: SinkScenario = _scenario.duplicate()
	given.explicit_hit = load(FAST_HIT)
	var config := _config(SEED)
	config.scenario = given
	assert_ne(config.sinking().timeline.digest(), straight.digest(), "another scenario")


func test_compaction_stays_within_tolerance() -> void:
	var bake := _bake(STEEP_HIT)
	var timeline := bake.timeline()
	var every := bake.uncompacted()
	assert_lt(timeline.count(), every.count(), "states dropped")
	assert_eq(every.count(), bake.times().size(), "the uncompacted keeps them all")
	var turn := _sea.keep_turn_deg + 1e-3
	var level := _sea.keep_level + 1e-6
	var air := _sea.keep_air + 1.0 / SinkTimeline.PER_METRE
	var worst := Vector3.ZERO
	var pockets := 0
	for state in bake.times().size():
		# At the microsecond the timeline holds it at: a pocket comes or goes on a kept
		# state's very second.
		var at := roundi(bake.times()[state] * SinkTimeline.PER_SECOND) / SinkTimeline.PER_SECOND
		var read := _read(timeline, at)
		worst.x = maxf(worst.x, absf(read[0] - bake.seas()[state]))
		for cell in bake.cells():
			var off: float = read[1][cell] - bake.heads()[state * bake.cells() + cell]
			# Up her, and in the world, where her height in the sea carries it too.
			worst.x = maxf(worst.x, maxf(absf(off), absf(off - read[0] + bake.seas()[state])))
			var truth := bake.pockets()[state * bake.cells() + cell]
			var pocket: float = read[3][cell]
			assert_eq(pocket > 0.0, truth > 0.0, "a pocket where the bake has one")
			worst.z = maxf(worst.z, absf(pocket - truth))
			pockets += 1 if truth > 0.0 else 0
		worst.y = maxf(worst.y, _degrees_apart(read[2], _truth(bake, state)))
	assert_lte(worst.x, level, "every state's water within keep_level")
	assert_lte(worst.y, turn, "every state's attitude within keep_turn_deg")
	assert_gt(pockets, 0, "air trapped on the way")
	assert_lte(worst.z, air, "every pocket's pressure within keep_air")
	# Between the states too, against the uncompacted read the same way: no step.
	var seconds := 0.0
	var between := Vector2.ZERO
	while seconds < timeline.length():
		var one := _read(timeline, seconds)
		var other := _read(every, seconds)
		between.x = maxf(between.x, absf(one[0] - other[0]))
		for cell in timeline.cells:
			between.x = maxf(between.x, absf(one[1][cell] - other[1][cell]))
		between.y = maxf(between.y, _degrees_apart(one[2], other[2]))
		seconds += BETWEEN
	assert_lte(between.x, level + 1.0 / SinkTimeline.PER_METRE, "water, read between")
	assert_lte(between.y, turn, "attitude, read between")


func test_events_keep_their_exact_times() -> void:
	var bake := _bake(STEEP_HIT)
	bake.run(1 << 62)
	var baked := PackedFloat64Array()
	for event: SinkTimeline.Event in bake.events():
		baked.append(event.seconds)
	var timeline := SinkTimeline.from_bytes(bake.timeline().to_bytes())
	assert_eq(timeline.events.size(), baked.size(), "every event kept")
	var kinds := {}
	for index in baked.size():
		var event := timeline.events[index]
		kinds[event.kind] = true
		assert_almost_eq(event.seconds, baked[index], 0.5 / SinkTimeline.PER_SECOND)
		if event.kind == SinkTimeline.Kind.LURCHING:
			continue
		var frame := timeline.frame_at(event.seconds)
		assert_eq(timeline.times[frame], event.seconds, "a kept state at its very second")
	for kind: SinkTimeline.Kind in [
		SinkTimeline.Kind.FULL, SinkTimeline.Kind.SPILLING, SinkTimeline.Kind.LURCHED
	]:
		assert_true(kinds.has(kind), "%s among them" % SinkTimeline.Kind.keys()[kind])


func test_the_step_lands_on_each_ceiling_it_reaches() -> void:
	# With the failures stage off: a wall's panel giving way just under a ceiling pours in
	# faster than LAND_TRIES guesses close on (SH31).
	var level: SeaPhysics = _sea.duplicate()
	level.attitude = false
	level.failures = false
	var bake := _bake(FAST_HIT, level)
	bake.run(1 << 62)
	# Level, each cell's ceiling stays put: how far its water is from full is read off
	# it — a full cell's head is the push it passes on.
	var cells := bake.cells()
	var full := 0
	for event: SinkTimeline.Event in bake.events():
		if event.kind != SinkTimeline.Kind.FULL:
			continue
		var cell := _structure.cell_named(event.name)
		var state := bake.times().find(event.seconds)
		var room := bake.room(cell, bake.waters()[state * cells + cell])
		var before := bake.room(cell, bake.waters()[(state - 1) * cells + cell])
		assert_gt(before, SinkBake.REACHED, "%s: under it a step before" % event.name)
		assert_almost_eq(room, 0.0, 1e-2, "%s: landed on its ceiling" % event.name)
		full += 1
	assert_gt(full, 2, "cells filled to their ceilings")


func test_every_warning_comes_before_its_event() -> void:
	var lurches := 0
	var falls := 0
	var timelines: Array[SinkTimeline] = [_bake(STEEP_HIT).timeline()]
	for choice: MustSink.Choice in SimFixtures.match_hits(12):
		timelines.append(choice.timeline)
	for timeline: SinkTimeline in timelines:
		for event: SinkTimeline.Event in timeline.events:
			assert_lte(event.warned, event.seconds, "warned no later than it happens")
			if event.kind == SinkTimeline.Kind.FUNNEL_FALLING:
				# A funnel's fall, at its creak (SH31): never less than fall_warning ahead.
				falls += 1
				assert_lte(event.warned, maxf(event.seconds - _sea.fall_warning, 0.0))
				var creaked := false
				for warning: SinkTimeline.Event in timeline.events:
					if warning.kind == SinkTimeline.Kind.FUNNEL_STRAINING:
						creaked = creaked or warning.seconds == event.warned
				assert_true(creaked, "its creak at its warning's second")
				continue
			if event.kind != SinkTimeline.Kind.LURCHED:
				assert_eq(event.warned, event.seconds, "nothing else is warned of")
				continue
			lurches += 1
			if event.warned > 0.0:
				assert_lte(event.warned, event.seconds - _sea.lurch_warning, "a second ahead")
			var told := false
			for warning: SinkTimeline.Event in timeline.events:
				if warning.kind == SinkTimeline.Kind.LURCHING and warning.seconds == event.warned:
					told = told or warning.heel_deg == event.heel_deg
			assert_true(told, "a lurch coming at its warning's second")
	assert_gt(lurches, 0, "lurches among them")
	assert_gt(falls, 0, "and funnels' falls")


func test_bytes_round_trip_exactly() -> void:
	var timeline := _config(SEED).sinking().timeline
	for made: SinkTimeline in [timeline, _bake(STEEP_HIT).timeline()]:
		var bytes := made.to_bytes()
		var back := SinkTimeline.from_bytes(bytes)
		assert_not_null(back)
		assert_eq(back.to_bytes(), bytes, "the same bytes again")
		assert_eq(back.digest(), made.digest())
		assert_eq(back.times, made.times)
		assert_eq(back.seas, made.seas)
		assert_eq(back.rotations, made.rotations)
		assert_eq(back.heads, made.heads)
		assert_eq(back.origin, made.origin)
		assert_eq(
			[back.end, back.gone_at, back.rest, back.steps, back.length()],
			[made.end, made.gone_at, made.rest, made.steps, made.length()]
		)
		assert_eq(back.events.size(), made.events.size())
		for index in back.events.size():
			var one := back.events[index]
			var other := made.events[index]
			assert_eq(
				[one.seconds, one.kind, one.name, one.heel_deg, one.lasts, one.warned],
				[other.seconds, other.kind, other.name, other.heel_deg, other.lasts, other.warned]
			)
	# A page at a time, as a client takes them: out of order, or not as claimed, refused.
	var sections := timeline.sections()
	assert_gt(sections.size(), 2, "more than one page")
	var coming := SinkTimeline.opened(sections[0])
	assert_eq(coming.count(), 0)
	assert_eq(coming.total(), timeline.count())
	assert_false(coming.add_page(sections[2]), "the second page before the first")
	for page in range(1, sections.size()):
		assert_true(coming.add_page(sections[page]), "page %d" % page)
	assert_true(coming.is_whole())
	assert_eq(coming.digest(), timeline.digest())


func test_hash_changes_with_any_byte() -> void:
	var bytes := _bake(FAST_HIT).timeline().to_bytes()
	var digest := SinkTimeline.digest_of_bytes(bytes)
	var same := 0
	for index in bytes.size():
		var changed := bytes.duplicate()
		changed[index] ^= 0x01 << (index % 8)
		if SinkTimeline.digest_of_bytes(changed) == digest:
			same += 1
	assert_eq(same, 0, "every one of %d bytes moves the digest" % bytes.size())
	var opened := SinkTimeline.from_bytes(bytes)
	var tampered := bytes.duplicate()
	tampered[tampered.size() - 3] ^= 0x10
	assert_null(SinkTimeline.from_bytes(tampered), "a page not as its header claims is refused")
	assert_eq(opened.digest(), digest)
