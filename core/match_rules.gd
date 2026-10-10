class_name MatchRules
extends Resource
## How a match is set up (data/match/*.tres): seats, the bot fill, the countdown,
## and which rules, ship and sinking scenario it plays — the menu's default; the seat
## counts a match takes are its ship's (ShipLayout).

@export var seats: int
## Seats 0…humans-1 are played locally; the rest are bots of bot_tier.
@export var humans: int
## A BotProfile under data/bots/, by file name.
@export var bot_tier: StringName
## Seconds the sim stays frozen before the brawl starts.
@export var countdown: float
@export var rules: BrawlRules
@export var ship: ShipLayout
@export var sinking: SinkScenario
## The scenario clock a fast match plays at (Q20): physics seconds per match second,
## the same sinking played that many times quicker.
@export var fast_clock: float = 2.0


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if seats < 1:
		found.append("match: at least one seat")
	if humans < 0 or humans > seats:
		found.append("match: humans must be within 0…seats")
	if countdown < 0.0:
		found.append("match: countdown must not be negative")
	if fast_clock <= 1.0:
		found.append("match: fast_clock must be over 1")
	if rules == null or ship == null or sinking == null:
		found.append("match: rules, ship and sinking are all required")
	elif seats < ship.min_seats or seats > ship.max_seats:
		found.append("match: seats must be within the ship's min_seats…max_seats")
	return found
