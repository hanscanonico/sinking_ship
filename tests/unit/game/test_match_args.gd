extends GutTest
## The match flags — --seed, --seats, --ship, --scenario, --hit, --fast and --goal —
## are parsed as they are given into the args' match choices, which answer for them
## (test_match_choices); every one not given is left unmade, the seed blank.


func test_the_match_flags_are_its_choices() -> void:
	var args := (
		MatchArgs
		. parse(
			PackedStringArray(
				[
					"--seed=abc",
					"--seats=4",
					"--ship=trawler",
					"--scenario=trawler_coast",
					"--hit=light",
					"--fast",
					"--goal=tag",
				]
			)
		)
	)
	var choices := args.choices
	assert_eq(choices.seed_text, "abc", "the seed as typed, for the choices to refuse")
	assert_eq(choices.seats, 4)
	assert_eq(choices.ship, &"trawler")
	assert_eq(choices.scenario, &"trawler_coast")
	assert_eq(choices.hit, "light")
	assert_true(choices.fast)
	assert_eq(choices.goal, &"tag")


func test_unmade_choices_are_left_to_the_data() -> void:
	var choices := MatchArgs.parse(PackedStringArray()).choices
	assert_eq(choices.seed_text, "", "no seed: each entry point fills its own in")
	assert_eq(choices.seats, 0)
	assert_eq(choices.ship, &"")
	assert_eq(choices.bot_tier, &"")
	assert_false(choices.fast, "normal unless asked")
	assert_eq(choices.goal, &"", "the data's goal, not the battle royale's")
	assert_eq(choices.scenario, &"")
	assert_eq(choices.hit, "")


## Every command-line path — make match, the server, the benches — takes its seed as the
## choices read it: a whole number of 0 or more, or refused with a reason, never seed 0.
func test_a_seed_is_read_by_the_choices_or_refused() -> void:
	var given := MatchArgs.parse(PackedStringArray(["--seed=1701"])).choices
	assert_eq(given.seed_number(), 1701)
	assert_eq(given.seed_problems(), PackedStringArray())
	var blank := MatchArgs.parse(PackedStringArray()).choices
	assert_eq(blank.seed_number(), -1, "no seed given: none")
	assert_eq(blank.seed_problems(), PackedStringArray(), "a blank seed is no problem")
	for text: String in ["abc", "-3", "1.5"]:
		var refused := MatchArgs.parse(PackedStringArray(["--seed=" + text])).choices
		assert_eq(refused.seed_number(), -1, "%s plays no seed" % text)
		assert_eq(
			refused.seed_problems(),
			PackedStringArray(["seed: %s is not a whole number of 0 or more" % text])
		)


func test_the_frame_split_is_asked_for_with_the_seconds_it_skips() -> void:
	assert_eq(MatchArgs.parse(PackedStringArray()).frame_split, -1.0, "normal play pays nothing")
	var args := MatchArgs.parse(PackedStringArray(["--frame-split=8"]))
	assert_eq(args.frame_split, 8.0, "frames from the eighth second on are kept")
