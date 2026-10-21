extends GutTest
## The replay store writes a ReplayFile under its directory, lists what it holds newest
## first, reads one back whole, and deletes one (R1, #209).

const RunMatch := preload("res://tools/run_match.gd")
const DIR := "user://replays_test"

var _store := ReplayStore.new(DIR)


func before_each() -> void:
	for path in _store.list():
		_store.delete(path)


func after_all() -> void:
	for path in _store.list():
		_store.delete(path)
	DirAccess.remove_absolute(DIR)


func _file(seed_value: int) -> ReplayFile:
	var chosen := MatchChoices.new()
	chosen.seed_text = str(seed_value)
	return ReplayFile.record(
		chosen, InputLog.new(RunMatch.default_config(seed_value)), 1_760_000_000
	)


func test_a_saved_replay_is_listed_newest_first_read_back_and_deleted() -> void:
	var older := _store.save(_file(1), "2026-10-20_09-00-00_steamer_1")
	var newer := _store.save(_file(2), "2026-10-20_10-00-00_steamer_2")
	assert_eq(_store.list(), PackedStringArray([newer, older]), "newest first")
	var back := _store.load_file(older)
	assert_not_null(back)
	assert_eq([back.match_seed, back.ship], [1, &"steamer"], "read back whole")
	assert_true(_store.delete(older))
	assert_eq(_store.list(), PackedStringArray([newer]), "deleted")
	assert_null(_store.load_file(older), "gone")
	assert_null(_store.load_file(DIR.path_join("never.replay")), "never there")
