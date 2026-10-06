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
## Its sinking, baked once from the ship, the scenario and the seed (schedule()): match
## data every MatchSim of this match shares, so a sim resumed from a snapshot never
## bakes it again (D5). The must-sink rule's bake may run a slice at a time first
## (bake_some, R20), or come baked from the host (receive_sinking, D11).
var _schedule: SinkSchedule
var _choosing: MustSink.Choosing
var _received: MustSink.Choice


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
## positive; [param ship_name] names the ship of the Fleet it is played on, struck in
## her open-sea scenario, when it is not the data's — blank for the data's own.
static func from_rules(
	match_rules: MatchRules, seed_value: int, seat_count: int = 0, ship_name := &""
) -> MatchConfig:
	var layout := match_rules.ship
	var sinking := match_rules.sinking
	if not ship_name.is_empty() and ship_name != Fleet.name_of(layout):
		layout = Fleet.layout(ship_name)
		sinking = Fleet.scenario(ship_name)
	var config := MatchConfig.new(
		seed_value,
		seat_count if seat_count > 0 else match_rules.seats,
		match_rules.rules,
		layout,
		sinking,
		Ticks.from_seconds(match_rules.countdown)
	)
	config.humans = match_rules.humans
	config.bot_tier = match_rules.bot_tier
	return config


## A match from the menu's choices — the only route from the UI into a match.
## A blank [param seed_text] is drawn from [param seeds] here, once, outside the
## sim, and the config records it, so typing it back in replays the match. Played on
## [param ship_name] of the Fleet, or the data's ship when blank (from_rules). Null
## when a choice is one the data does not offer: a ship the Fleet has not, a seat count
## outside her min_seats…max_seats, or a seed that is not a whole number.
static func from_menu(
	match_rules: MatchRules,
	seat_count: int,
	tier: StringName,
	seed_text: String,
	seeds: RandomNumberGenerator,
	ship_name := &""
) -> MatchConfig:
	var layout := match_rules.ship if ship_name.is_empty() else Fleet.layout(ship_name)
	if layout == null or seat_count < layout.min_seats or seat_count > layout.max_seats:
		return null
	var typed := seed_text.strip_edges()
	if not typed.is_empty() and not (typed.is_valid_int() and typed.to_int() >= 0):
		return null
	var config := from_rules(
		match_rules, seeds.randi() if typed.is_empty() else typed.to_int(), seat_count, ship_name
	)
	config.bot_tier = tier
	return config


## The match's sinking (SinkSchedule.for_match), built on first asking.
func schedule() -> SinkSchedule:
	if _schedule == null:
		_schedule = SinkSchedule.for_match(self)
	return _schedule


## How its hit was chosen and baked: received from the host, or the must-sink rule run
## to its end — straight through, or on from where bake_some left it; null for a match
## the physics does not sink.
func sinking() -> MustSink.Choice:
	if _received != null:
		return _received
	bake_some(1 << 62)
	return _choosing.choice() if _choosing != null else null


## Runs the must-sink rule's bakes on by up to [param steps] steps (MustSink.Choosing),
## so a scene can spread them across frames; whether they are over — at once for a
## match with nothing to bake.
func bake_some(steps: int) -> bool:
	if _received != null or ship.structure == null or not scenario.is_physical():
		return true
	if _choosing == null:
		var sink_stream := SeedStreams.derive(match_seed, "sink")
		var sea := SeaPhysics.load_default()
		_choosing = MustSink.Choosing.new(ship.structure, scenario, sink_stream, sea)
	return _choosing.work(steps)


## The steps its bakes have taken so far, for a scene's progress.
func bake_steps() -> int:
	return _choosing.steps() if _choosing != null else 0


## Takes [param other]'s sinking, baked or under way, when it is this match's too — the
## same ship, scenario and seed make the same sinking (D7) — and none is under way
## here; whether it took it.
func share_sinking(other: MatchConfig) -> bool:
	if other == null or _choosing != null or _received != null or _schedule != null:
		return false
	if other.ship != ship or other.scenario != scenario or other.match_seed != match_seed:
		return false
	_choosing = other._choosing
	_received = other._received
	return _choosing != null or _received != null


## Plays [param timeline], the host's, with the hit it was baked from drawn again here
## (MustSink.replay) — never baked here (D11); false, and nothing taken, when this end
## cannot draw that hit.
func receive_sinking(timeline: SinkTimeline) -> bool:
	var sink_stream := SeedStreams.derive(match_seed, "sink")
	var chosen := MustSink.replay(ship.structure, scenario, sink_stream, timeline)
	if chosen == null:
		return false
	_received = chosen
	return true


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
