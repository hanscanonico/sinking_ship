extends GutTest
## A replay's row in the list says its ship, seed, seats, length and who won, and why
## it can no longer be played (R6, #214).

const RunMatch := preload("res://tools/run_match.gd")


func _file() -> ReplayFile:
	var chosen := MatchChoices.new()
	chosen.seed_text = "1701"
	var file := ReplayFile.record(chosen, InputLog.new(RunMatch.default_config(1701)), 0)
	file.ticks = 134 * Ticks.RATE
	return file


func test_the_row_reads_off_the_summary() -> void:
	var file := _file()
	file.winner = 3
	file.ended = true
	assert_eq(
		ReplayListing.row(file),
		{
			"ship": "Steamer",
			"seed": "Seed 1701",
			"seats": "8 seats",
			"length": "02:14.0",
			"winner": "Bot 3 won",
			"reason": "",
		}
	)


func test_who_won_is_worded_for_the_local_seat_the_sea_and_a_match_left_early() -> void:
	assert_eq(ReplayListing.winner_text(0, true), "You won")
	assert_eq(ReplayListing.winner_text(-1, true), "The sea won")
	assert_eq(ReplayListing.winner_text(-1, false), "Left unfinished")


func test_a_file_that_cannot_be_played_says_why() -> void:
	var rules: MatchRules = load(RunMatch.DEFAULT_MATCH)
	assert_eq(ReplayListing.reason(_file(), rules), "", "as recorded")
	var changed := _file()
	changed.log.data_hash = "other numbers"
	assert_eq(ReplayListing.reason(changed, rules), ReplayListing.CHANGED)
	var jumped := _file()
	jumped.log = InputLog.new(RunMatch.default_config(1701), 40)
	assert_eq(ReplayListing.reason(jumped, rules), ReplayListing.MIDWAY)
	assert_eq(ReplayListing.reason(null, rules), ReplayListing.UNREADABLE)
	assert_eq(ReplayListing.row(jumped, ReplayListing.MIDWAY)["reason"], ReplayListing.MIDWAY)
