extends GutTest
## A saved replay is named for when it was recorded, its ship and its seed, so a
## listing sorts by name; a prune keeps the newest so many by that name and never
## touches a file it cannot date (R3, #211).

const WHEN := {
	"year": 2026,
	"month": 10,
	"day": 20,
	"hour": 9,
	"minute": 5,
	"second": 7,
}


func test_a_replay_is_named_for_its_moment_ship_and_seed() -> void:
	assert_eq(ReplayNames.file_name(WHEN, &"steamer", 1701), "2026-10-20_09-05-07_steamer_1701")


func test_a_prune_drops_the_oldest_past_the_kept_count() -> void:
	var paths := PackedStringArray(
		[
			"user://replays/2026-10-20_09-00-00_steamer_1.replay",
			"user://replays/2026-10-19_23-59-59_trawler_2.replay",
			"user://replays/2026-10-20_10-00-00_steamer_3.replay",
			"user://replays/2026-10-18_08-00-00_steamer_4.replay",
		]
	)
	assert_eq(
		ReplayNames.to_prune(paths, 2),
		PackedStringArray(
			[
				"user://replays/2026-10-19_23-59-59_trawler_2.replay",
				"user://replays/2026-10-18_08-00-00_steamer_4.replay",
			]
		),
		"the two oldest, oldest last"
	)
	assert_eq(ReplayNames.to_prune(paths, 4), PackedStringArray(), "nothing past four")
	assert_eq(ReplayNames.to_prune(paths, 9), PackedStringArray(), "nothing past nine")


func test_a_file_without_a_date_is_never_pruned() -> void:
	var paths := PackedStringArray(
		[
			"user://replays/keep_me.replay",
			"user://replays/2026-10-20_09-00-00_steamer_1.replay",
			"user://replays/2026-10-20_08-00-00_steamer_2.replay",
		]
	)
	assert_eq(
		ReplayNames.to_prune(paths, 1),
		PackedStringArray(["user://replays/2026-10-20_08-00-00_steamer_2.replay"])
	)
