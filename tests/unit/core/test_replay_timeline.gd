extends GutTest
## A replay timeline sought to a tick stands exactly where stepping straight to it
## stands (D5), steps on from there with the match's own events, and clamps to the
## replay (R2, #210). The keyframe interval is the replay data's, not a constant.

const RunMatch := preload("res://tools/run_match.gd")
const SEED := 1701
const PLAYED_SECONDS := 25
## A tick in the countdown, one in play, and the end.
const SOUGHT := [45, 400, PLAYED_SECONDS * Ticks.RATE]

var _file: ReplayFile


func before_all() -> void:
	var chosen := MatchChoices.new()
	chosen.seed_text = str(SEED)
	var played := RunMatch.bots_only(chosen.config(_rules()))
	played.run(PLAYED_SECONDS * Ticks.RATE)
	_file = ReplayFile.record(chosen, played.input_log, 1_760_000_000, _rules())


func _rules() -> MatchRules:
	return load(RunMatch.DEFAULT_MATCH)


func _timeline() -> ReplayTimeline:
	return ReplayTimeline.new(_file, ReplayRules.load_default(), _rules())


func _stepped_to(timeline: ReplayTimeline, to: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	while timeline.tick() < to:
		events.append_array(timeline.step())
	return events


static func _dicts(events: Array[SimEvent]) -> Array[Dictionary]:
	var dicts: Array[Dictionary] = []
	for event: SimEvent in events:
		dicts.append(event.to_dict())
	return dicts


func test_the_keyframe_interval_is_the_replay_data() -> void:
	assert_gt(ReplayRules.load_default().keyframe_every, 0)


func test_sought_back_from_the_end_it_stands_where_stepping_straight_stands() -> void:
	var straight := _timeline()
	var sought := _timeline()
	sought.seek(sought.last_tick())
	assert_true(sought.at_end(), "at the end")
	for to: int in SOUGHT:
		_stepped_to(straight, to)
		sought.seek(to)
		assert_eq(sought.tick(), to, "at %d" % to)
		assert_eq(
			SnapshotDigest.quantized(sought.snapshot()),
			SnapshotDigest.quantized(straight.snapshot()),
			"digest at %d" % to
		)
		assert_eq(sought.snapshot(), straight.snapshot(), "snapshot at %d" % to)


func test_sought_back_it_steps_on_with_the_match_s_own_events() -> void:
	var timeline := _timeline()
	var from: int = SOUGHT[1]
	_stepped_to(timeline, from)
	var first_time := _dicts(_stepped_to(timeline, from + 2 * Ticks.RATE))
	timeline.seek(from)
	var again := _dicts(_stepped_to(timeline, from + 2 * Ticks.RATE))
	assert_eq(again, first_time, "the same events again")
	timeline.seek(0)
	assert_eq(_dicts(_stepped_to(timeline, from)).size() > 0, true, "events from the start")


func test_seeking_past_either_end_clamps() -> void:
	var timeline := _timeline()
	timeline.seek(timeline.last_tick() + 500)
	assert_eq(timeline.tick(), timeline.last_tick(), "no further than the end")
	assert_eq(timeline.step(), [] as Array[SimEvent], "nothing to step at the end")
	timeline.seek(-50)
	assert_eq(timeline.tick(), timeline.first_tick(), "no earlier than the start")
