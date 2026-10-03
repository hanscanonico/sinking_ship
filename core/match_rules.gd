class_name MatchRules
extends Resource
## How a match is set up (data/match/*.tres): seats, the bot fill, the countdown,
## and which rules, ship and sinking scenario it plays.

@export var seats: int
## The seat counts the menu offers.
@export var min_seats: int
@export var max_seats: int
## Seats 0…humans-1 are played locally; the rest are bots of bot_tier.
@export var humans: int
## A BotProfile under data/bots/, by file name.
@export var bot_tier: StringName
## Seconds the sim stays frozen before the brawl starts.
@export var countdown: float
@export var rules: BrawlRules
@export var ship: ShipLayout
@export var sinking: SinkScenario


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if seats < 1:
		found.append("match: at least one seat")
	if min_seats < 1 or max_seats < min_seats:
		found.append("match: min_seats must be at least 1 and at most max_seats")
	elif seats < min_seats or seats > max_seats:
		found.append("match: seats must be within min_seats…max_seats")
	if humans < 0 or humans > seats:
		found.append("match: humans must be within 0…seats")
	if countdown < 0.0:
		found.append("match: countdown must not be negative")
	if rules == null or ship == null or sinking == null:
		found.append("match: rules, ship and sinking are all required")
	return found
