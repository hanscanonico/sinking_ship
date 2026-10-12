extends GutTest
## FrameMeter's timers stand in for the match's own pieces (make fps SPLIT=1): the
## match they time plays exactly as the untimed one — the same digest, the same view —
## and every part they time is measured.

const TICKS := 200


## A bots-only match on the flat deck under a lurch, every seat a bot and the client
## only watching, as make fps plays it; timed into [param split] when one is given.
## Steps it TICKS beats and returns it.
func _played(split: FrameSplit) -> LoopbackMatch:
	var sinking := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [20.0, 1.0, 3.0, 6.0]])
	var config := SimFixtures.config(4, sinking, 1701)
	var profile := BotProfile.for_tier(&"normal")
	var played: LoopbackMatch
	var conditions := NetConditions.new()
	var rules := NetRules.load_default()
	if split == null:
		var bots := BotInputSource.fill(config, profile)
		played = LoopbackMatch.new(config, rules, conditions, -1, null, bots)
	else:
		FrameMeter.time_schedule(config, split)
		var bots := FrameMeter.time_sources(BotInputSource.fill(config, profile), split)
		played = FrameMeter.Loopback.new(config, rules, conditions, -1, null, bots, {}, split)
	for _beat in TICKS:
		played.step()
	return played


func test_a_timed_match_plays_as_the_untimed_one() -> void:
	var untimed := _played(null)
	var timed := _played(FrameSplit.new())
	assert_eq(timed.host.tick(), untimed.host.tick())
	assert_eq(timed.host.runner.digest.hex(), untimed.host.runner.digest.hex(), "the same match")
	assert_eq(
		SnapshotDigest.quantized(timed.client.view()),
		SnapshotDigest.quantized(untimed.client.view()),
		"the same view"
	)


func test_every_part_of_a_step_is_timed() -> void:
	var split := FrameSplit.new()
	_played(split)
	split.close(0)
	assert_eq(split.mean(&"steps"), float(TICKS), "every beat counted")
	assert_gt(split.mean(&"match"), 0.0)
	for part: StringName in [&"bots", &"host_sim", &"snapshot", &"wire", &"reconcile"]:
		assert_gt(split.mean(part), 0.0, "%s timed" % part)
	assert_gt(split.mean(&"poses"), float(TICKS), "a pose and more built each beat")
	var parts := 0.0
	for part: StringName in split.parts_of(&"match"):
		parts += split.mean(part)
	assert_lt(parts, split.mean(&"match"), "the parts are inside the step")
