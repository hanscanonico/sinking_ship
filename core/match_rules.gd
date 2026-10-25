class_name MatchRules
extends Resource
## How a match is set up (data/match/*.tres): seats, the bot fill, the countdown,
## and which rules, ship and sinking scenario it plays, and how bonuses come aboard — the
## menu's default; the seat counts a match takes are its ship's (ShipLayout).

## What a seat plays for (#60): to be the last one in — the battle royale, over once one
## seat is left — or to stay in as long as she lasts — survival, over once none is left,
## or one is and her sinking is over (MatchVerdict.place).
enum Goal { LAST_STANDING, SURVIVAL }

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
## The scenario clock a fast match plays at (Q20): her paced clock that many times
## quicker, its limits too — the same sinking played sooner.
@export var fast_clock: float = 2.0
## What the match is played for: the battle royale unless the data says survival.
@export var goal: Goal = Goal.LAST_STANDING
## How bonuses come aboard (#307), the match config's to check (MatchConfig.problems); null
## for matches without bonuses.
@export var bonuses: BonusRules


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
