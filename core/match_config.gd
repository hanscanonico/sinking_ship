class_name MatchConfig
extends RefCounted
## The typed statement of one match (D13) — the only way a match starts: its seed,
## its seat count, the rules, ship and sinking scenario it plays, and a hash of
## that data so a replay refuses to run against changed numbers.

var match_seed: int
var seats: int
var rules: BrawlRules
var ship: ShipLayout
var scenario: SinkScenario
var countdown_ticks: int


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
	return MatchConfig.new(
		seed_value,
		seat_count if seat_count > 0 else match_rules.seats,
		match_rules.rules,
		match_rules.ship,
		match_rules.sinking,
		Ticks.from_seconds(match_rules.countdown)
	)


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
