extends GutTest
## CuePlanner's cargo passes over the runs of crates the step before found still without
## asking them again: over a whole sinking, tick by tick, it plans the cues asking every
## crate every step does.

const RunMatch := preload("res://tools/run_match.gd")


## A planner asking every crate of every step, none passed over.
class EveryCrate:
	extends CuePlanner

	func _init(config: MatchConfig, surfaces: Surfaces, schedule: SinkSchedule) -> void:
		super(config, surfaces, schedule, 0)

	func _cargo(then: Array, now: Array, tick: int, cues: Array[AudioCue]) -> void:
		var lifted := false
		for index in now.size():
			lifted = _crate(then[index], now[index], index, tick, cues, lifted)


func test_the_cargo_heard_is_that_of_asking_every_crate() -> void:
	var config := RunMatch.default_config(1701)
	config.scenario = load(SimFixtures.STEAMER_SCRIPT)
	var runner := RunMatch.bots_only(config)
	var sim := runner.sim
	var planner := CuePlanner.new(sim.config, sim.surfaces, sim.schedule, 0)
	var every := EveryCrate.new(sim.config, sim.surfaces, sim.schedule)
	var previous := sim.snapshot()
	var heard := 0
	var passed_over := 0
	while not runner.is_over() and runner.tick() < sim.schedule.end_tick():
		runner.step()
		var current := sim.snapshot()
		var found := _described(planner.plan(previous, current))
		assert_eq(found, _described(every.plan(previous, current)), "at %d" % current["tick"])
		for line in found:
			heard += 1 if "SCRAPE" in line or "THUD" in line else 0
		passed_over += planner._runs_still.count(1)
		previous = current
	assert_gt(heard, 0, "cargo heard")
	assert_gt(passed_over, 0, "still runs passed over")


func _described(cues: Array[AudioCue]) -> PackedStringArray:
	var lines := PackedStringArray()
	for cue: AudioCue in cues:
		lines.append("%s at %s" % [cue.describe(), cue.position])
	return lines
