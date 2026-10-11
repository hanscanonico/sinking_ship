extends GutTest
## A survival match told as `make match` tells it (#62): seed 1, eight bots, struck by the
## fast explicit hit and played on the fast clock — what
##   make match SEED=1 HIT=fast FAST=1 GOAL=survival
## prints. Its transcript is recorded per platform, as the golden match is (R6):
##   tests/golden/survival_1_8.<os>-<arch>.txt

const RunMatch := preload("res://tools/run_match.gd")
const ARGS: Array[String] = ["--seed=1", "--hit=fast", "--fast", "--goal=survival"]
## `make match`'s STOP (MatchArgs).
const MAX_TICKS := 900 * Ticks.RATE

static var _told := ""


func _survival() -> String:
	if _told.is_empty():
		var chosen := RunMatch.choices(MatchArgs.parse(PackedStringArray(ARGS)))
		var config := chosen.config(load(RunMatch.DEFAULT_MATCH))
		_told = RunMatch.transcript(RunMatch.served(config), MAX_TICKS)
	return _told


func test_the_survival_transcript_says_its_goal_and_who_was_in_at_the_plunge() -> void:
	var lines := _survival().split("\n")
	assert_eq(lines[0], "goal survival", "it says its goal first")
	var plunge := Array(lines).filter(func(line: String) -> bool: return "at the plunge" in line)
	assert_eq(plunge.size(), 1, "and how many seats were in at the plunge")
	var outs := Array(lines).filter(
		func(line: String) -> bool: return " seat " in line and " out · " in line
	)
	assert_eq(outs.size(), 8, "every seat goes out with its place")


func test_the_survival_transcript_for_this_platform() -> void:
	var platform := "%s-%s" % [OS.get_name().to_lower(), Engine.get_architecture_name()]
	var path := "res://tests/golden/survival_1_8.%s.txt" % platform
	if not FileAccess.file_exists(path):
		pending("no survival transcript recorded for %s" % platform)
		return
	assert_eq(_survival(), FileAccess.get_file_as_string(path))
