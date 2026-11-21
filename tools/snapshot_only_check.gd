class_name SnapshotOnlyCheck
extends RefCounted
## `make art-lint`'s check that art reads snapshots only (D5): no script under
## scenes/art names the live match or a query only rules make.

## What art may not name: the live match and the queries only rules make. Enum
## reads off PlayerState are allowed, a PlayerState itself is not.
const LIVE: PackedStringArray = [
	"MatchSim",
	"MatchState",
	"MatchRunner",
	"MatchHost",
	"MatchClient",
	"PlayedMatch",
	"LoopbackMatch",
	"RemoteMatch",
	"SimDriver",
	"InputSource",
	"BotView",
	"Surfaces",
	"SinkSchedule",
	"ShoveResolver",
]
const LIVE_PLAYER := "\\bPlayerState\\b(?!\\.(Body|Action|Cause)\\b)"


## Every script under [param dir], a line at a time, comments cut: [problems found,
## checks made], a check a script.
static func check(dir: String) -> Array:
	var problems := PackedStringArray()
	var checks := 0
	var live := RegEx.create_from_string("\\b(%s)\\b" % "|".join(LIVE))
	var live_player := RegEx.create_from_string(LIVE_PLAYER)
	for file: String in _scripts_under(dir):
		checks += 1
		var lines := FileAccess.get_file_as_string(dir + file).split("\n")
		for index in lines.size():
			var code := lines[index].get_slice("#", 0)
			var found := live.search(code)
			if found == null:
				found = live_player.search(code)
			if found != null:
				problems.append(
					(
						"art-lint: %s:%d names %s — art reads snapshots only (D5)"
						% [file, index + 1, found.get_string()]
					)
				)
	return [problems, checks]


## Every .gd under [param dir] and its subfolders, as paths relative to it.
static func _scripts_under(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(file)
	for sub: String in DirAccess.get_directories_at(dir):
		for file: String in _scripts_under(dir + sub + "/"):
			found.append(sub + "/" + file)
	return found
