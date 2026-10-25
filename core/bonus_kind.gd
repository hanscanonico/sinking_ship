class_name BonusKind
extends Resource
## What a kind of bonus is (#307), the same for every one of it: its title, for the feed and
## the HUD; its size, which a Grab press reaches it by and its model stays inside; the
## colour it is drawn in; and what it gives the seat that takes it, through a rule there
## already is — a field a kind leaves unset leaves that rule as the brawl rules have it. One
## file per kind, data/bonuses/NAME.tres, as the prop kinds are.

## What the feed and the HUD call it.
@export var title: String
## The size every bonus of the kind is, in metres: what a Grab press reaches it by, and
## what its model stays inside.
@export var radius: float
@export var height: float
## The colour a bonus of the kind is drawn in.
@export var mark := Color.WHITE
@export_group("Gives")
## Whether it gives its taker a spare cold meter (Double life): when the taker's meter runs
## out in the sea it fills again, once, and the bonus is spent.
@export var spare_meter: bool


## Every reason this kind cannot be played; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if title.strip_edges().is_empty():
		found.append("bonus kind: a title")
	if radius <= 0.0 or height <= 0.0:
		found.append("bonus kind: a size is a radius and a height, both positive")
	return found
