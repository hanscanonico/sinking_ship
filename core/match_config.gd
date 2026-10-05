class_name MatchConfig
extends RefCounted
## The typed statement of one match (D13) — the only way a match starts: its seed,
## its seat count, the rules, ship and sinking scenario it plays, who fills the
## seats, and a hash of that data so a replay refuses to run against changed
## numbers. The UI builds one only through from_menu; the headless tools and the
## tests build theirs from data.

var match_seed: int
var seats: int
var rules: BrawlRules
var ship: ShipLayout
var scenario: SinkScenario
var countdown_ticks: int
## Seats 0…humans-1 are played locally; the rest are bots of bot_tier.
var humans: int
## A BotProfile under data/bots/, by file name.
var bot_tier: StringName


func _init(
	seed_value: int,
	seat_count: int,
	brawl_rules: BrawlRules,
	layout: ShipLayout,
	sinking: SinkScenario,
	countdown: int = 0
) -> void:
	match_seed = seed_value
	seats = seat_count
	rules = brawl_rules
	ship = layout
	scenario = sinking
	countdown_ticks = countdown


## A match from data. [param seat_count] overrides the data's seat count when
## positive.
static func from_rules(
	match_rules: MatchRules, seed_value: int, seat_count: int = 0
) -> MatchConfig:
	var config := MatchConfig.new(
		seed_value,
		seat_count if seat_count > 0 else match_rules.seats,
		match_rules.rules,
		match_rules.ship,
		match_rules.sinking,
		Ticks.from_seconds(match_rules.countdown)
	)
	config.humans = match_rules.humans
	config.bot_tier = match_rules.bot_tier
	return config


## A match from the menu's choices — the only route from the UI into a match.
## A blank [param seed_text] is drawn from [param seeds] here, once, outside the
## sim, and the config records it, so typing it back in replays the match. Null
## when a choice is one [param match_rules] does not offer: a seat count outside
## min_seats…max_seats, or a seed that is not a whole number.
static func from_menu(
	match_rules: MatchRules,
	seat_count: int,
	tier: StringName,
	seed_text: String,
	seeds: RandomNumberGenerator
) -> MatchConfig:
	if seat_count < match_rules.min_seats or seat_count > match_rules.max_seats:
		return null
	var typed := seed_text.strip_edges()
	if not typed.is_empty() and not (typed.is_valid_int() and typed.to_int() >= 0):
		return null
	var config := from_rules(
		match_rules, seeds.randi() if typed.is_empty() else typed.to_int(), seat_count
	)
	config.bot_tier = tier
	return config


## Every reason this match cannot start; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if seats < 1:
		found.append("match: at least one seat")
	if countdown_ticks < 0:
		found.append("match: countdown must not be negative")
	found.append_array(rules.problems())
	found.append_array(ship.problems(seats))
	found.append_array(scenario.problems())
	if scenario.hit != null and ship.structure == null:
		found.append("match: the sinking's iceberg hit needs a ship with a structure")
	return found


## A hash of every number the match loaded: the rules, ship and scenario, and the
## countdown.
func data_hash() -> String:
	return _describe([rules, ship, scenario, countdown_ticks]).sha256_text()


static func _describe(value: Variant) -> String:
	if value is Resource:
		var resource: Resource = value
		var fields := PackedStringArray()
		for property: Dictionary in resource.get_property_list():
			if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var field: String = property["name"]
				fields.append("%s=%s" % [field, _describe(resource.get(field))])
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items := PackedStringArray()
		for item: Variant in value:
			items.append(_describe(item))
		return "[%s]" % ",".join(items)
	return var_to_str(value)
