extends GutTest
## The match flags — --seed, --seats, --ship, --scenario, --hit, --fast, --goal and
## --bonuses — are parsed as they are given into the args' match choices, which answer for
## them (test_match_choices); every one not given is left unmade, the seed blank, and
## bonuses on.


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
					"--bonuses=0",
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
	assert_false(choices.bonuses, "--bonuses=0: none come aboard")


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
	assert_true(choices.bonuses, "bonuses unless asked otherwise")


## --bonuses=0 turns bonuses off, as make's BONUSES=0 passes it, and --bonuses or
## --bonuses=1 leaves them on — for a player's match and a bot's autoplay alike: bonuses
## are on for both by default.
func test_bonuses_take_a_zero_for_none() -> void:
	var off := MatchArgs.parse(PackedStringArray(["--bonuses=0"]))
	assert_false(off.choices.bonuses, "--bonuses=0: the plain brawl")
	assert_false(off.player_choices().bonuses, "a player's match too")
	for flag: String in ["--bonuses", "--bonuses=1"]:
		assert_true(MatchArgs.parse(PackedStringArray([flag])).choices.bonuses, flag)
	var bot := MatchArgs.parse(PackedStringArray(["--autoplay", "--bonuses=0"]))
	assert_false(bot.player_choices().bonuses, "and a bot's autoplay")
	assert_true(MatchArgs.parse(PackedStringArray(["--autoplay"])).player_choices().bonuses)


func test_fast_takes_a_zero_for_the_paced_clock() -> void:
	var slow := MatchArgs.parse(PackedStringArray(["--fast=0"]))
	assert_false(slow.choices.fast, "--fast=0 is her paced clock")
	assert_true(slow.pace_given)
	var fast := MatchArgs.parse(PackedStringArray(["--fast=1"]))
	assert_true(fast.choices.fast, "--fast=1 as --fast, what make's FAST=1 passes")
	assert_true(fast.pace_given)
	assert_false(MatchArgs.parse(PackedStringArray()).pace_given)


## A player's match sinks at her paced clock unless the command line asks for the fast
## one; so does a bot's autoplay, like every tool, on the clock its transcript is timed on.
func test_a_players_choices_sink_paced_unless_asked_otherwise() -> void:
	var given := MatchArgs.parse(PackedStringArray(["--seed=7"]))
	assert_false(given.player_choices().fast, "a player's default pace is her paced clock")
	assert_eq(given.player_choices().seed_text, "7", "the other choices as given")
	var fast := MatchArgs.parse(PackedStringArray(["--fast"]))
	assert_true(fast.player_choices().fast, "the fast clock asked for")
	var slow := MatchArgs.parse(PackedStringArray(["--fast=0"]))
	assert_false(slow.player_choices().fast, "the paced one asked for")
	var bot := MatchArgs.parse(PackedStringArray(["--autoplay"]))
	assert_false(bot.player_choices().fast, "a bot's autoplay is a tool's: paced")
	var fast_bot := MatchArgs.parse(PackedStringArray(["--autoplay", "--fast"]))
	assert_true(fast_bot.player_choices().fast)


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


func test_a_capture_looks_from_chosen_feet_at_a_chosen_point_in_ship_space() -> void:
	# The eye stands EYE_HEIGHT over the feet; its yaw runs from the bow toward
	# starboard, its pitch up from the horizon (FirstPersonCamera.look_from).
	var eye := FirstPersonCamera.EYE_HEIGHT
	var cases := {
		"10,-4,0 20,-4,0": [0.0, -atan(eye / 10.0)],
		"0,0,0 0,0,5": [90.0, -atan(eye / 5.0)],
		"0,0,0 -3,%f,-3" % (eye + sqrt(18.0)): [-135.0, 45.0],
	}
	for given: String in cases:
		var args := (
			MatchArgs
			. parse(
				PackedStringArray(
					[
						"--capture-from=%s" % given.get_slice(" ", 0),
						"--capture-look=%s" % given.get_slice(" ", 1),
					]
				)
			)
		)
		var feet := given.get_slice(" ", 0).split_floats(",")
		assert_eq(args.capture_from.size(), 5, given)
		for axis in 3:
			assert_almost_eq(args.capture_from[axis], feet[axis], 1e-6, given + ": its feet")
		var want: Array = cases[given]
		assert_almost_eq(args.capture_from[3], want[0], 1e-4, given + ": yaw")
		var pitch: float = want[1] if absf(want[1]) == 45.0 else rad_to_deg(want[1])
		assert_almost_eq(args.capture_from[4], pitch, 1e-4, given + ": pitch")
	var free := MatchArgs.parse(PackedStringArray(["--capture-from=1,2,3,90,-10"]))
	assert_eq(free.capture_from, PackedFloat64Array([1, 2, 3, 90, -10]), "yaw and pitch as given")


func test_a_capture_may_hold_its_lens_wet() -> void:
	assert_true(is_nan(MatchArgs.parse(PackedStringArray()).capture_wet), "its own lens")
	var args := MatchArgs.parse(PackedStringArray(["--capture-wet=0.3"]))
	assert_almost_eq(args.capture_wet, 0.3, 1e-6)
