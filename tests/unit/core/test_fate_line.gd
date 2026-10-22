extends GutTest
## The results' fate line (MatchTranscript.fate_line): the ship's name, how her sinking
## ends and how much of it the match played — all read off the baked sinking (D7).

const SEED := 1701

static var _schedule: SinkSchedule


## The steamer's sinking on SEED, as her match bakes it: once for the whole script.
func _steamer() -> SinkSchedule:
	if _schedule == null:
		var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
		_schedule = SimFixtures.config(8, scenario, SEED, SimFixtures.steamer()).schedule()
	return _schedule


func test_the_line_names_the_ship_her_end_and_the_share_played() -> void:
	var labels: Array[OutcomeClassifier.Outcome] = [
		OutcomeClassifier.Outcome.BY_THE_HEAD, OutcomeClassifier.Outcome.FAST
	]
	assert_eq(
		MatchTranscript.fate_told("Steamer", labels, 0.54),
		"Steamer · down by the head · 54% of her sinking played"
	)
	assert_string_ends_with(
		MatchTranscript.fate_told("Steamer", labels, 1.3), " · 100% of her sinking played"
	)


func test_her_end_is_told_by_the_label_that_says_it() -> void:
	var cases := {
		OutcomeClassifier.Outcome.BY_THE_STERN: "down by the stern",
		OutcomeClassifier.Outcome.ONTO_HER_SIDE: "over on her side",
		OutcomeClassifier.Outcome.AFLOAT: "stays afloat",
		OutcomeClassifier.Outcome.AGROUND: "aground",
		OutcomeClassifier.Outcome.AFLOAT_UPSIDE_DOWN: "afloat upside down",
	}
	for label: OutcomeClassifier.Outcome in cases:
		var labels: Array[OutcomeClassifier.Outcome] = [label, OutcomeClassifier.Outcome.FAST]
		assert_eq(MatchTranscript.founders(labels), cases[label])


func test_a_hull_parting_is_told_before_the_way_she_goes() -> void:
	var labels: Array[OutcomeClassifier.Outcome] = [
		OutcomeClassifier.Outcome.BY_THE_HEAD, OutcomeClassifier.Outcome.BROKE_IN_TWO
	]
	assert_eq(MatchTranscript.founders(labels), "breaks in two")
	labels = [OutcomeClassifier.Outcome.BY_THE_STERN, OutcomeClassifier.Outcome.BROKE_IN_THREE]
	assert_eq(MatchTranscript.founders(labels), "breaks in three")


func test_the_line_reads_the_baked_sinking() -> void:
	var schedule := _steamer()
	var told := OutcomeClassifier.labels(schedule.timeline())
	var hit := schedule.hit_tick()
	assert_eq(
		MatchTranscript.fate_line("Steamer", schedule, hit),
		MatchTranscript.fate_told("Steamer", told, 0.0),
		"none of it played at the hit"
	)
	var gone := schedule.gone_tick() if schedule.timeline().is_gone() else schedule.end_tick()
	assert_string_ends_with(
		MatchTranscript.fate_line("Steamer", schedule, gone), " · 100% of her sinking played"
	)
	var midway := (hit + gone) / 2
	assert_almost_eq(MatchTranscript.share_played(schedule, midway), 0.5, 0.001)
	assert_eq(
		MatchTranscript.fate_line("Steamer", schedule, midway),
		MatchTranscript.fate_told("Steamer", told, 0.5),
		"half of it played halfway from the hit to her going"
	)
	# The share is the match's time, not the physics': her paced clock (Q20) has run
	# well past half her physics by then, drawing her end out.
	var physics := schedule.physics_at(midway) / schedule.timeline().gone_at
	assert_gt(physics, 0.6, "the physics runs ahead of the match")
	assert_eq(
		MatchTranscript.fate_line("Steamer", schedule, midway),
		MatchTranscript.fate_line("Steamer", schedule, midway),
		"the same line every time it is asked"
	)


func test_a_match_without_a_sinking_tells_no_fate() -> void:
	var calm := SimFixtures.config(2).schedule()
	assert_null(calm.timeline())
	assert_eq(MatchTranscript.fate_line("Deck", calm, 900), "")
	assert_eq(MatchTranscript.share_played(calm, 900), 0.0)
