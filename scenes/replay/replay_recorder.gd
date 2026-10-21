class_name ReplayRecorder
extends RefCounted
## Records a local match as a ReplayFile and saves it, keeping the newest so many on
## disk (R3, #211): the one place the clock is read for a replay — the core classes
## take the time as a number.

var _store: ReplayStore
var _rules: ReplayRules


func _init(store: ReplayStore = null, rules: ReplayRules = null) -> void:
	_store = store if store != null else ReplayStore.new()
	_rules = rules if rules != null else ReplayRules.load_default()


## The replay of [param runner]'s match so far — the host's loop, which has every
## seat's frames — made of [param chosen], recorded now.
func record(chosen: MatchChoices, runner: MatchRunner) -> ReplayFile:
	var file := ReplayFile.record(chosen, runner.input_log, int(Time.get_unix_time_from_system()))
	file.winner = runner.sim.state.winner()
	file.ended = runner.sim.is_over()
	return file


## Writes [param file] under its name (ReplayNames) and prunes the store to the newest
## keep_newest; the path written, or "" when it could not be.
func save(file: ReplayFile) -> String:
	var name := ReplayNames.file_name(
		Time.get_datetime_dict_from_system(), file.ship, file.match_seed
	)
	var path := _store.save(file, name)
	if path.is_empty():
		push_warning("replay: could not write %s" % name)
		return ""
	for old in ReplayNames.to_prune(_store.list(), _rules.keep_newest):
		_store.delete(old)
	return path
