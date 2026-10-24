extends GutTest
## Crates at rest are passed over (Hazards): stepping one would leave it as it is, so a
## match plays the same whether they are or not — a laid deck's tables and chairs walked
## into, shoved, lifted as the water comes, carried downhill as she heels and set down as
## it falls, among laden crates sliding past their grip — and one continued from a
## snapshot of it, or reset to one as a predicting client resets, plays on the same (D5).

const SHOVE := InputFrame.SHOVE
## How long a match runs: calm, then flooding, heeling and draining.
const SECONDS := 26.0
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"
## The steamer's watertight door in her engine room's after bulkhead: the x of its wall,
## and the floor of its doorway.
const DOOR_X := -3.0
const DOOR_FLOOR := -2.6


func after_each() -> void:
	Hazards.never_rest = false


## Two laid tables, a chair at each quarter, and two crates on the flat deck, a bridge
## 2.5 m over its fore end: she is not gone while it stands out of the water.
func _layout() -> ShipLayout:
	var props: Array[ShipProp] = []
	for x: float in [-6.0, 0.0]:
		props.append(SimFixtures.table(Vector3(x, 0.0, 0.0)))
		var off := 0.82
		props.append(SimFixtures.chair(Vector3(x + off, 0.0, 0.0), 180.0))
		props.append(SimFixtures.chair(Vector3(x - off, 0.0, 0.0), 0.0))
		props.append(SimFixtures.chair(Vector3(x, 0.0, off), -90.0))
		props.append(SimFixtures.chair(Vector3(x, 0.0, -off), 90.0))
	props.append(SimFixtures.crate(Vector3(6.0, 0.0, -2.0)))
	props.append(SimFixtures.crate(Vector3(6.0, 0.0, 2.0)))
	var layout := SimFixtures.crated(props)
	layout.platforms = layout.platforms.duplicate()
	var bridge := ShipPlatform.new()
	bridge.name = &"bridge"
	bridge.area = Rect2(11.0, -4.0, 4.0, 8.0)
	bridge.height = 2.5
	layout.platforms.append(bridge)
	return layout


## Calm for eight seconds; sunk until the deck is 0.65 m under by fourteen, every piece
## afloat; heeled a little to starboard by twenty, carrying them downhill — short of the
## sea sweeping any off at her side (crate_adrift_depth); and risen until 0.2 m of water
## is left, every piece set down again.
func _sinking() -> SinkScenario:
	var edge := SimFixtures.deck().freeboard
	return (
		SimFixtures
		. scenario(
			[
				[0.0, 0.0, 0.0, 0.0],
				[8.0, 0.0, 0.0, 0.0],
				[14.0, edge + 0.65, 0.0, 0.0],
				[20.0, edge + 0.65, 0.0, 4.0],
				[SECONDS, edge + 0.2, 0.0, 0.0],
			]
		)
	)


## What each seat sends at [param tick]: seat 0 walks to and fro through the aft table's
## chairs and shoves now and then; seat 1 walks into the fore table and back; seat 2
## stands by the crates and shoves them; seats 3 and 4 wait on the bridge, so the match
## goes on as the water takes the others.
func _frames(tick: int) -> Array[InputFrame]:
	var shove := SHOVE if tick % 45 < 2 else 0
	var to_and_fro := 1.0 if (tick / 60) % 2 == 0 else -1.0
	var frames: Array[InputFrame] = [
		SimFixtures.frame(0, Vector2(0.8 * to_and_fro, 0.25 * to_and_fro), shove, 0.0),
		SimFixtures.frame(1, Vector2(-to_and_fro, 0.0), 0, 180.0),
		SimFixtures.frame(2, Vector2(0.0, 0.0), SHOVE if tick % 70 < 2 else 0, 0.0),
		SimFixtures.frame(3),
		SimFixtures.frame(4),
	]
	return frames


func _started() -> MatchSim:
	var sim := SimFixtures.sim(5, _sinking(), _layout())
	SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.3))
	SimFixtures.place(sim, 1, Vector3(3.0, 0.0, 0.0), 180.0)
	SimFixtures.place(sim, 2, Vector3(4.6, 0.0, -2.0))
	SimFixtures.place(sim, 3, Vector3(12.0, 2.5, -2.0))
	SimFixtures.place(sim, 4, Vector3(14.0, 2.5, 2.0))
	return sim


## Every snapshot of the match, from its start, with crates at rest passed over or —
## [param stepping] — every crate stepped every tick.
func _played(stepping: bool) -> Array[Dictionary]:
	Hazards.never_rest = stepping
	var sim := _started()
	var snapshots: Array[Dictionary] = [sim.snapshot()]
	for tick in Ticks.from_seconds(SECONDS):
		sim.step(_frames(tick))
		snapshots.append(sim.snapshot())
	Hazards.never_rest = false
	return snapshots


func test_passing_over_crates_at_rest_changes_nothing() -> void:
	var passed_over := _played(false)
	var stepped := _played(true)
	assert_eq(passed_over.size(), stepped.size())
	for tick in passed_over.size():
		if passed_over[tick] != stepped[tick]:
			fail_test("the two diverged at tick %d" % tick)
			return
	var moved := 0
	var starts := _layout().props
	for entry: Dictionary in passed_over[-1]["props"]:
		var start: Vector3 = starts[entry["prop"]].pos
		moved += 1 if (entry["pos"] as Vector3).distance_to(start) > 0.5 else 0
		assert_eq(entry["state"], PropState.Body.GROUNDED, "every piece set down again")
	var lifted := {}
	for snapshot: Dictionary in passed_over:
		for entry: Dictionary in snapshot["props"]:
			if entry["state"] == PropState.Body.FLOATING:
				lifted[entry["prop"]] = true
	assert_gt(moved, 5, "the furniture was pushed and carried about")
	assert_eq(lifted.size(), starts.size(), "and the water lifted every piece")


## The steamer struck by the fast hit, a chair at rest in the doorway of her engine room's
## after bulkhead, in its leaf's path: every snapshot from a second before the hit to a
## second after the door is shut, crates at rest passed over or — [param stepping] —
## every crate stepped every tick.
func _door_shut_on_a_chair(stepping: bool) -> Array[Dictionary]:
	Hazards.never_rest = stepping
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	scenario.explicit_hit = load(FAST_HIT)
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	layout.props = layout.props.duplicate()
	layout.props.append(SimFixtures.chair(Vector3(DOOR_X + 0.1, DOOR_FLOOR, 0.0)))
	var sim := SimFixtures.sim(1, scenario, layout)
	SimFixtures.place(sim, 0, Vector3(-17.0, 1.2, 0.0))
	sim.state.tick = sim.schedule.hit_tick() - Ticks.RATE
	sim.state.phase = MatchState.Phase.LIVE
	var snapshots: Array[Dictionary] = []
	while sim.state.tick < sim.schedule.physics_tick(20.0) + Ticks.RATE:
		SimFixtures.step(sim, {})
		snapshots.append(sim.snapshot())
	Hazards.never_rest = false
	return snapshots


func test_a_door_shutting_on_furniture_at_rest_pushes_it_as_when_every_crate_steps() -> void:
	var passed_over := _door_shut_on_a_chair(false)
	var stepped := _door_shut_on_a_chair(true)
	assert_eq(passed_over.size(), stepped.size())
	for tick in passed_over.size():
		if passed_over[tick] != stepped[tick]:
			fail_test("the two diverged %d ticks in" % tick)
			return
	var start := Vector3(DOOR_X + 0.1, DOOR_FLOOR, 0.0)
	var chair: Dictionary = passed_over[-1]["props"][-1]
	assert_gt((chair["pos"] as Vector3).distance_to(start), 0.1, "the leaf pushed the chair")


func test_a_match_among_furniture_continues_from_any_snapshot() -> void:
	var played := _played(false)
	var config := _started().config
	for start: int in [Ticks.from_seconds(5.0), Ticks.from_seconds(14.0), Ticks.from_seconds(21.0)]:
		var resumed := MatchSim.from_snapshot(played[start], config)
		for tick in range(start, start + Ticks.RATE):
			resumed.step(_frames(tick))
			if resumed.snapshot() != played[tick + 1]:
				fail_test("continued from tick %d, it diverged at tick %d" % [start, tick])
				return
	pass_test("every continuation matched")


func test_a_match_reset_to_an_earlier_snapshot_plays_it_again_the_same() -> void:
	var played := _played(false)
	var sim := _started()
	for tick in Ticks.from_seconds(15.0):
		sim.step(_frames(tick))
	# A predicting client resets its own sim to the host's older snapshot and runs on.
	var start := Ticks.from_seconds(12.0)
	sim.restore(played[start])
	for tick in range(start, start + 2 * Ticks.RATE):
		sim.step(_frames(tick))
		if sim.snapshot() != played[tick + 1]:
			fail_test("reset to tick %d, it diverged at tick %d" % [start, tick])
			return
	pass_test("the reset match matched")


func test_a_match_reset_to_its_own_snapshot_keeps_its_crates_as_they_stand() -> void:
	var played := _played(false)
	var sim := _started()
	var start := Ticks.from_seconds(3.0)
	var then: Dictionary
	for tick in Ticks.from_seconds(6.0):
		if tick == start:
			then = sim.snapshot()
		sim.step(_frames(tick))
	var crates := sim.state.props.duplicate()
	sim.restore(then)
	var kept := 0
	for index in crates.size():
		if is_same(sim.state.props[index], crates[index]):
			kept += 1
		assert_true(is_same(sim.state.props[index].to_dict(), then["props"][index]))
	assert_gt(kept, 0, "a crate still as it stood is kept")
	assert_lt(kept, crates.size(), "one moved since is made again")
	for tick in range(start, start + 2 * Ticks.RATE):
		sim.step(_frames(tick))
		if sim.snapshot() != played[tick + 1]:
			fail_test("reset to tick %d, it diverged at tick %d" % [start, tick])
			return
	pass_test("the reset match matched")
