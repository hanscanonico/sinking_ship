class_name MatchChoices
extends RefCounted
## What a player picks before a match (GLOSSARY): ship, seats, bot tier, seed, pace and
## goal, and, from the command line only, scenario and hit. A choice left unmade means
## the match data's, and this is the only place that fills the data's value in. The menu
## and the command line both start here; it answers for itself against the match rules
## — its problems(), and the config() it makes — and resolves the same choices to the
## same config every time: it never draws a seed (D13). Each entry point fills a blank
## seed its own way before asking for a config: the command line with its default, the
## menu with the seed its next match drew ahead (NextMatch).

## The goals by name (MatchRules.Goal), as --goal and the menu's Survival name them.
const GOALS := {
	&"last_standing": MatchRules.Goal.LAST_STANDING, &"survival": MatchRules.Goal.SURVIVAL
}
## The explicit hits a tool can name (--hit=NAME): the test fixtures', each a ship's
## NAME_HIT or any ship's HIT.
const HITS := "res://tests/fixtures/sinking/hits/%s.tres"

## A ship of the Fleet, or a test-only one, by name; empty for the match data's.
var ship: StringName = &""
## The seat count; 0 for the match data's.
var seats: int = 0
## A BotProfile under data/bots/, by file name; empty for the match data's.
var bot_tier: StringName = &""
## The seed as typed: a whole number of 0 or more, or blank for one still to be drawn.
var seed_text: String = ""
## Her sinking on the match data's fast_clock (MatchConfig.quickened).
var fast: bool = false
## What the match is played for, by name (GOALS); empty for the match data's.
var goal: StringName = &""
## One of a ship's scenarios by name (steamer_coast), whose ship it names when [member
## ship] does not, or a test fixture's by its res:// path; empty for her open sea. The
## command line's only.
var scenario: StringName = &""
## An explicit hit to strike her with, past the must-sink rule (§5b.1): its .tres, or its
## name among HITS — hers before any ship's; empty for the must-sink rule's. The command
## line's only.
var hit: String = ""


## A copy of these choices with [param text] for their seed — blank to draw a new one.
func with_seed(text: String) -> MatchChoices:
	var copy := MatchChoices.new()
	copy.ship = ship
	copy.seats = seats
	copy.bot_tier = bot_tier
	copy.seed_text = text
	copy.fast = fast
	copy.goal = goal
	copy.scenario = scenario
	copy.hit = hit
	return copy


## The ship they play on, by name: the one chosen, else the scenario's, else
## [param match_rules]'.
func ship_name(match_rules: MatchRules) -> StringName:
	if not ship.is_empty():
		return ship
	var of_scenario := Fleet.ship_of(scenario)
	return of_scenario if not of_scenario.is_empty() else Fleet.name_of(match_rules.ship)


## These choices with every unmade one but the seed made as [param match_rules] makes
## it: the data's ship (or the scenario's), seats, bot tier and goal — what the menu
## starts from.
func filled(match_rules: MatchRules) -> MatchChoices:
	var full := with_seed(seed_text)
	full.ship = ship_name(match_rules)
	if seats == 0:
		full.seats = match_rules.seats
	if bot_tier.is_empty():
		full.bot_tier = match_rules.bot_tier
	if goal.is_empty():
		full.goal = GOALS.find_key(match_rules.goal)
	return full


## Every reason these choices make no match under [param match_rules]; empty when they
## make one. A blank seed is no problem: it is one still to be drawn.
func problems(match_rules: MatchRules) -> PackedStringArray:
	var found := PackedStringArray()
	var named := ship_name(match_rules)
	var layout := _layout(match_rules, named)
	if layout == null:
		found.append("ship: no ship called %s; the fleet has %s" % [named, _fleet()])
	elif seats != 0 and (seats < layout.min_seats or seats > layout.max_seats):
		found.append(
			(
				"seats: %s takes %d to %d seats, not %d"
				% [named, layout.min_seats, layout.max_seats, seats]
			)
		)
	if (
		not scenario.is_empty()
		and (
			_setting() == null
			or (not String(scenario).begins_with("res://") and Fleet.ship_of(scenario) != named)
		)
	):
		found.append("scenario: %s is no scenario of %s" % [scenario, named])
	if not hit.is_empty() and _hit(named) == null:
		found.append("hit: %s is not an IcebergHit" % hit)
	if not goal.is_empty() and not GOALS.has(goal):
		found.append("goal: %s is no goal; one of %s" % [goal, ", ".join(GOALS.keys())])
	found.append_array(seed_problems())
	return found


## Why the seed as typed is no seed — not a whole number of 0 or more —; empty when it
## is one or is blank. What the command line's paths that play the seed alone (the
## server, the benches) refuse it on.
func seed_problems() -> PackedStringArray:
	var typed := seed_text.strip_edges()
	if typed.is_empty() or seed_number() >= 0:
		return PackedStringArray()
	return PackedStringArray(["seed: %s is not a whole number of 0 or more" % typed])


## The seed as a number; -1 when it is blank, or no seed (seed_problems).
func seed_number() -> int:
	var typed := seed_text.strip_edges()
	if not typed.is_valid_int() or typed.to_int() < 0:
		return -1
	return typed.to_int()


## The match these choices make under [param match_rules]: every unmade choice the
## data's. Asking for one while they have problems, or before their seed is filled in,
## is an error, and null.
func config(match_rules: MatchRules) -> MatchConfig:
	var found := problems(match_rules)
	if seed_text.strip_edges().is_empty():
		found.append("seed: blank, still to be drawn")
	if not found.is_empty():
		push_error("match choices: no config while %s" % "; ".join(found))
		return null
	var full := filled(match_rules)
	var layout := _layout(match_rules, full.ship)
	var sinking := match_rules.sinking
	if layout != match_rules.ship:
		sinking = Fleet.scenario(full.ship)
	if not scenario.is_empty():
		sinking = _setting()
	if not hit.is_empty():
		sinking = sinking.duplicate() as SinkScenario
		sinking.explicit_hit = _hit(full.ship)
	if fast:
		sinking = MatchConfig.quickened(sinking, match_rules.fast_clock)
	var made := MatchConfig.new(
		seed_number(),
		full.seats,
		match_rules.rules,
		layout,
		sinking,
		Ticks.from_seconds(match_rules.countdown)
	)
	made.humans = match_rules.humans
	made.bot_tier = full.bot_tier
	made.goal = GOALS[full.goal]
	return made


## The ship called [param named]: [param match_rules]' own when it is hers, else the
## Fleet's; null when there is none.
static func _layout(match_rules: MatchRules, named: StringName) -> ShipLayout:
	return match_rules.ship if named == Fleet.name_of(match_rules.ship) else Fleet.layout(named)


## The scenario's sinking: one of the Fleet's by name, or a test fixture's by its res://
## path — an authored roll (tests/fixtures/sinking/rolling_over.tres) a capture stages
## her on to look at her faces (SH32), never a match's.
func _setting() -> SinkScenario:
	if not String(scenario).begins_with("res://"):
		return Fleet.setting(scenario)
	if not ResourceLoader.exists(scenario):
		return null
	return load(scenario) as SinkScenario


## The hit's IcebergHit: the .tres it gives, or by name one of HITS — [param named]'s
## own, her fleet ship's for a test-only one (titanic_britannic strikes as titanic), then
## any ship's.
func _hit(named: StringName) -> IcebergHit:
	var path := hit
	if not hit.contains("/"):
		for owner: StringName in [named, Fleet.ship_of(named), &""]:
			path = HITS % (hit if owner.is_empty() else "%s_%s" % [owner, hit])
			if ResourceLoader.exists(path):
				break
	if not ResourceLoader.exists(path):
		return null
	return load(path) as IcebergHit


static func _fleet() -> String:
	return ", ".join(Fleet.names())
