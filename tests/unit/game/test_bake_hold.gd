extends GutTest
## A match's sinking made on a thread (R20): the baker bakes a config's sinking there to
## the very sinking a straight bake makes, the frames meanwhile never baking; a config
## that takes the sinking under way is told of it once it is made; a bake stopped and
## taken up again is the same bake; and the held countdown shows only once a bake has
## outrun its grace, its bar never going back.

const MATCH_DATA := "res://data/match/default.tres"
const SEED := 1701
## The longest a test waits on a bake, in milliseconds, and how long it waits between
## frames.
const PATIENCE := 600000
const FRAME := 5


## [param baker]'s frames, FRAME apart, until it tells of one more sinking made — into
## [param baked] — or PATIENCE runs out; the microseconds those frames took.
static func _frames_until_baked(baker: SinkingBaker, baked: Array[MatchConfig]) -> int:
	var spent := 0
	var waited := 0
	var told := baked.size()
	while baked.size() == told and waited < PATIENCE:
		var began := Time.get_ticks_usec()
		baker._process(0.0)
		spent += Time.get_ticks_usec() - began
		OS.delay_msec(FRAME)
		waited += FRAME
	return spent


func test_a_bake_on_its_thread_is_the_bake_and_no_frame_bakes() -> void:
	var rules: MatchRules = load(MATCH_DATA)
	var baker := SinkingBaker.new()
	add_child_autofree(baker)
	var threaded := MatchConfig.from_rules(rules, SEED)
	var baked: Array[MatchConfig] = []
	baker.baked.connect(func(config: MatchConfig) -> void: baked.append(config))
	var began := Time.get_ticks_usec()
	baker.bake(threaded)
	assert_false(baker.done(threaded), "under way")
	var progress := 0.0
	var spent := 0
	while baked.is_empty() and Time.get_ticks_usec() - began < PATIENCE * 1000:
		var frame := Time.get_ticks_usec()
		baker._process(0.0)
		spent += Time.get_ticks_usec() - frame
		assert_gte(baker.progress(), progress, "the progress never goes back")
		progress = baker.progress()
		OS.delay_msec(FRAME)
	var took := Time.get_ticks_usec() - began
	assert_eq(baked, [threaded] as Array[MatchConfig], "baked, and said so")
	assert_null(baker.baking(), "and done with it")
	assert_true(baker.done(threaded), "made")
	assert_lt(spent, took / 4, "its frames a small share of the bake's time: none baked")
	var straight := MatchConfig.from_rules(rules, SEED)
	assert_eq(threaded.sinking().timeline.digest(), straight.sinking().timeline.digest())


func test_a_config_that_takes_the_sinking_under_way_is_told_once_it_is_made() -> void:
	var rules: MatchRules = load(MATCH_DATA)
	var baker := SinkingBaker.new()
	add_child_autofree(baker)
	var baked: Array[MatchConfig] = []
	baker.baked.connect(func(config: MatchConfig) -> void: baked.append(config))
	var upcoming := MatchConfig.from_rules(rules, SEED)
	baker.bake(upcoming)
	var played := MatchConfig.from_rules(rules, SEED)
	assert_true(played.share_sinking(upcoming), "Play takes the next match's sinking")
	assert_false(baker.done(played), "under way on the thread")
	baker.bake(played)
	_frames_until_baked(baker, baked)
	assert_eq(baked, [played] as Array[MatchConfig], "the match played is told")
	assert_true(baker.done(played), "made")
	var straight := MatchConfig.from_rules(rules, SEED)
	assert_eq(played.sinking().timeline.digest(), straight.sinking().timeline.digest())


func test_a_bake_stopped_and_taken_up_again_is_the_bake() -> void:
	var rules: MatchRules = load(MATCH_DATA)
	var baker := SinkingBaker.new()
	add_child_autofree(baker)
	var baked: Array[MatchConfig] = []
	baker.baked.connect(func(config: MatchConfig) -> void: baked.append(config))
	var stopped := MatchConfig.from_rules(rules, SEED)
	var other := MatchConfig.from_rules(rules, SEED + 1)
	baker.bake(stopped)
	OS.delay_msec(50)
	baker.stop()
	assert_null(baker.baking(), "stopped at once")
	baker.bake(other)
	_frames_until_baked(baker, baked)
	assert_eq(baked, [other] as Array[MatchConfig], "the stopped one is never told of")
	baker.bake(stopped)
	_frames_until_baked(baker, baked)
	assert_eq(baked, [other, stopped] as Array[MatchConfig], "taken up again, and made")
	var straight := MatchConfig.from_rules(rules, SEED)
	assert_eq(stopped.sinking().timeline.digest(), straight.sinking().timeline.digest())


func test_the_hold_shows_only_past_its_grace() -> void:
	var hold := BakeHold.new()
	add_child_autofree(hold)
	hold.begin(3.0)
	assert_false(hold.visible, "nothing at first")
	hold.advance(BakeHold.GRACE_SECONDS * 0.5, 0.2)
	assert_false(hold.visible, "a bake done within its grace never shows it")
	hold.advance(BakeHold.GRACE_SECONDS, 0.3)
	assert_true(hold.visible, "a slow one does")
	hold.advance(0.1, 0.1)
	hold.begin(3.0)
	assert_false(hold.visible, "a new hold starts hidden")
