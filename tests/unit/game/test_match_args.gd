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
