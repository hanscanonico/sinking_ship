class_name BotProfile
extends Resource
## A bot's difficulty (D10) — this and nothing else. The numbers live in
## data/bots/*.tres.

## How many ticks old the snapshot a bot acts on is.
@export var reaction_ticks: int
## Ticks between re-choosing a target.
@export var think_period: int
## Each choice of heading is off by up to this many degrees either way.
@export var aim_error_deg: float
## How far a bot keeps from the waterline and the deck's open edges, in metres.
@export var edge_margin_m: float


static func for_tier(tier: StringName) -> BotProfile:
	return load("res://data/bots/%s.tres" % tier) as BotProfile


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
	return found
