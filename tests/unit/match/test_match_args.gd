extends GutTest
## The command line's --replay names a saved replay to watch instead of playing
## (R6, #214).


func test_replay_names_the_file_to_watch() -> void:
	var parsed := MatchArgs.parse(PackedStringArray(["--replay=user://replays/one.replay"]))
	assert_eq(parsed.replay_path, "user://replays/one.replay")
	assert_eq(MatchArgs.parse(PackedStringArray(["--seed=3"])).replay_path, "", "none without it")
