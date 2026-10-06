extends GutTest
## A match's sinking made a slice a frame (R20): the baker spreads a config's bakes over
## frames to the very sinking a straight bake makes, and the held countdown shows only
## once a bake has outrun its grace, its bar never going back.

const MATCH_DATA := "res://data/match/default.tres"
const SEED := 1701


func test_a_bake_spread_over_frames_is_the_bake() -> void:
	var rules: MatchRules = load(MATCH_DATA)
	var baker := SinkingBaker.new()
	add_child_autofree(baker)
	var sliced := MatchConfig.from_rules(rules, SEED)
	var baked: Array[MatchConfig] = []
	baker.baked.connect(func(config: MatchConfig) -> void: baked.append(config))
	baker.bake(sliced, 2.0)
	var frames := 0
	var progress := 0.0
	while baked.is_empty() and frames < 100000:
		baker._process(0.0)
		assert_gte(baker.progress(), progress, "the progress never goes back")
		progress = baker.progress()
		frames += 1
	assert_eq(baked, [sliced] as Array[MatchConfig], "baked, and said so")
	assert_gt(frames, 10, "over many frames")
	assert_null(baker.baking(), "and done with it")
	var straight := MatchConfig.from_rules(rules, SEED)
	assert_eq(sliced.sinking().timeline.digest(), straight.sinking().timeline.digest())


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
