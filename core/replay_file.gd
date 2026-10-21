class_name ReplayFile
extends RefCounted
## A finished match kept to be watched again (R1, #209): the choices it was built
## from (MatchChoices), every frame it was stepped with (InputLog), when it was
## recorded, and a summary for a list. A replay is the sim run again from the log
## (D4), so the file carries nothing of what happened — the same seed and frames make
## it again. playable() refuses a file whose data changed, or whose match started
## mid-way (a jump, which the choices cannot rebuild): never replayed wrong.
##
## The bytes: MAGIC and FORMAT, the recorded-at time, the summary, every script
## variable of the choices by name, then the log's own bytes (InputLog.to_bytes).

const MAGIC := "SSRP"
const FORMAT := 1
const DEFAULT_MATCH := "res://data/match/default.tres"

var choices: MatchChoices
var log: InputLog
## Unix time, as the recorder read it — never read here (no clock in core).
var recorded_at: int = 0
## The summary a list shows.
var ship: StringName = &""
var match_seed: int = 0
var seats: int = 0
var ticks: int = 0
## The seat that won, or -1 for none (unfinished, or a draw).
var winner: int = -1
## Whether the match had ended when it was recorded, or was left early.
var ended := false


## A replay of the match [param chosen] made, stepped with [param input_log], recorded
## at unix time [param at]; its summary read off them under [param match_rules] (the
## default match data's when null).
static func record(
	chosen: MatchChoices, input_log: InputLog, at: int, match_rules: MatchRules = null
) -> ReplayFile:
	var file := ReplayFile.new()
	file.choices = chosen
	file.log = input_log
	file.recorded_at = at
	file.ship = chosen.ship_name(_rules(match_rules))
	file.match_seed = input_log.match_seed
	file.seats = input_log.seats
	file.ticks = input_log.last_tick() - input_log.first_tick + 1
	return file


## The match the choices make under [param match_rules] (the default match data's when
## null); null when they no longer make one.
func config(match_rules: MatchRules = null) -> MatchConfig:
	var rules := _rules(match_rules)
	if not choices.problems(rules).is_empty():
		return null
	return choices.config(rules)


## Whether this file plays the match it recorded: its choices still make a match, with
## the seed, seats and data the log was played under, from its first tick.
func playable(match_rules: MatchRules = null) -> bool:
	if log == null or choices == null or log.first_tick != 0:
		return false
	var made := config(match_rules)
	return made != null and log.matches(made)


## One input source per seat, answering the log's frames.
func replay_sources() -> Array[InputSource]:
	return log.replay_sources()


func to_bytes() -> PackedByteArray:
	var out := ByteCursor.new()
	out.put_bytes(MAGIC.to_ascii_buffer())
	out.put_s32(FORMAT)
	out.put_s64(recorded_at)
	out.put_string(ship)
	out.put_s64(match_seed)
	out.put_s32(seats)
	out.put_s32(ticks)
	out.put_s32(winner)
	out.put_s32(1 if ended else 0)
	var fields := _choice_fields(choices)
	out.put_s32(fields.size())
	for field: String in fields:
		out.put_string(field)
		out.put_var(choices.get(field))
	out.put_bytes(log.to_bytes())
	return out.bytes()


## The file [param bytes] hold, as to_bytes wrote it; null for a buffer cut short,
## garbled, of another layout, or naming a choice there is none of.
static func from_bytes(bytes: PackedByteArray) -> ReplayFile:
	var read := ByteCursor.new(bytes)
	if read.bytes_next() != MAGIC.to_ascii_buffer() or read.s32() != FORMAT:
		return null
	var file := ReplayFile.new()
	file.recorded_at = read.s64()
	file.ship = StringName(read.string())
	file.match_seed = read.s64()
	file.seats = read.s32()
	file.ticks = read.s32()
	file.winner = read.s32()
	file.ended = read.s32() != 0
	var chosen := MatchChoices.new()
	var known := _choice_fields(chosen)
	var count := read.s32()
	if not read.ok or count < 0 or count > known.size():
		return null
	for _index in count:
		var field := read.string()
		var value: Variant = read.variant()
		if not read.ok or not known.has(field) or typeof(value) != typeof(chosen.get(field)):
			return null
		chosen.set(field, value)
	file.choices = chosen
	file.log = InputLog.from_bytes(read.bytes_next())
	if not read.ok or not read.at_end() or file.log == null:
		return null
	return file


static func _choice_fields(chosen: MatchChoices) -> PackedStringArray:
	var fields := PackedStringArray()
	for property: Dictionary in chosen.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property["name"])
	return fields


static func _rules(match_rules: MatchRules) -> MatchRules:
	return match_rules if match_rules != null else load(DEFAULT_MATCH)
