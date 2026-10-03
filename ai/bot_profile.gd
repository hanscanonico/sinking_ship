class_name BotProfile
extends Resource
## A bot's difficulty (D10) — this and nothing else. The numbers live in
## data/bots/*.tres.

const DIRECTORY := "res://data/bots"

## How many ticks old the snapshot a bot acts on is.
@export var reaction_ticks: int
## Ticks between re-choosing a target.
@export var think_period: int
## Each choice of heading is off by up to this many degrees either way.
@export var aim_error_deg: float
## How far a bot keeps from the waterline and the deck's open edges, in metres.
@export var edge_margin_m: float
## The fastest a bot turns its look, so that none turns faster than a person.
@export var turn_rate_deg: float
## The chance, rolled each think, that a bot braces against a facing windup.
@export var brace_read: float
## The chance, rolled each think, that a bot answers a bracing target with a charge.
@export var charge_read: float


static func for_tier(tier: StringName) -> BotProfile:
	return load("%s/%s.tres" % [DIRECTORY, tier]) as BotProfile


## Every tier there is a profile for, by file name, sorted.
static func tiers() -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.get_extension() == "tres":
			found.append(file.get_basename())
	found.sort()
	return found


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if reaction_ticks < 0:
		found.append("bot: reaction_ticks must not be negative")
	if think_period < 1:
		found.append("bot: think_period must be at least 1")
	if aim_error_deg < 0.0:
		found.append("bot: aim_error_deg must not be negative")
	if edge_margin_m < 0.0:
		found.append("bot: edge_margin_m must not be negative")
	if turn_rate_deg <= 0.0:
		found.append("bot: turn_rate_deg must be positive")
	for field: String in ["brace_read", "charge_read"]:
		if float(get(field)) < 0.0 or float(get(field)) > 1.0:
			found.append("bot: %s must be within 0…1" % field)
	return found
