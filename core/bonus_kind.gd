class_name BonusKind
extends Resource
## What a kind of bonus is (#307), the same for every one of it: its title, for the feed and
## the HUD; its size, which a Grab press reaches it by and its model stays inside; the colour
## it is drawn in, and the icon it is shown by; and what it gives the seat that takes it,
## through a rule there already is — a field a kind leaves unset leaves that rule as the brawl
## rules have it. One file per kind, data/bonuses/NAME.tres, as the prop kinds are. What a seat
## with it plays by is SeatRules'.

## What the feed and the HUD call it.
@export var title: String
## The size every bonus of the kind is, in metres: what a Grab press reaches it by, and
## what its model stays inside.
@export var radius: float
@export var height: float
## The colour a bonus of the kind is drawn in.
@export var mark := Color.WHITE
## The icon a bonus of the kind is shown by, in its colour, by name: a glyph the scenes draw
## (BonusIcons); none, its colour alone.
@export var icon: StringName
@export_group("Gives")
## Whether it gives its taker a spare cold meter (Double life): when the taker's meter runs
## out in the sea it fills again, once, and the bonus is spent.
@export var spare_meter: bool
## How high its taker's jump lifts its feet, in metres (High jump; BrawlRules.jump_height),
## at the stamina a jump costs anyone; 0 leaves the brawl rules'. A railing holds back no
## body whose feet are over its top, so a jump higher than one stands clears it.
@export var jump_height: float
## The combined deck slope its taker holds at standing idle, and the tilt past which a face
## is no floor to it, in degrees (Sure footing; BrawlRules.grip_angle_deg,
## BrawlRules.stand_limit_deg); 0 leaves the brawl rules'. The brace's hold, and the floor
## it flips to past it, stay theirs (brace_holds_to): the same for every seat.
@export var grip_angle_deg: float
@export var stand_limit_deg: float
## The share of a shove's knockback its taker takes, quick or charged, before a brace takes
## its own share off (Steady); 1, the whole of it, as the brawl rules have it. 0…1. Nothing
## but a shove is touched: a crate's knockback, a falling funnel's and a body bowling it
## over are as they are for anyone.
@export var knockback_share := 1.0
## The highest a ledge may stand above the sea for its taker to climb onto it, in metres
## (Strong arms; BrawlRules.climb_reach), 0 leaving the brawl rules' — never lower than
## theirs; and how many times their ladder_speed it goes up a ladder at, 1 as they have it.
## The climb's least time and the cold a climber knocked back in loses stay theirs.
@export var climb_reach: float
@export var ladder_speed_mult := 1.0
@export_group("")
## What each further one of the kind gives its taker, as a share of what the one before it
## gave: a seat takes any number of a kind, and every one moves the rules its kind sets
## further (SeatRules), by less each time, toward the furthest any number of them brings
## them (stacked_most). 0…1: at 0 only the first gives anything; 1, every one the whole of
## it, is only for a kind that sets no rule (Double life: each a spare meter of its own),
## as rules moved so would have no furthest.
@export var stack_share := 0.5


## How many times what one of the kind gives [param count] of it give together: the first
## the whole of it, each further one stack_share of the one before.
func stacked(count: int) -> float:
	var total := 0.0
	var gain := 1.0
	for _copy in count:
		total += gain
		gain *= stack_share
	return total


## How many times what one of the kind gives any number of it come to at most (stacked):
## the furthest its rules ever go. INF at a stack_share of 1.
func stacked_most() -> float:
	return 1.0 / (1.0 - stack_share) if stack_share < 1.0 else INF


## What one more of the kind gives a seat with [param held] of it, as a share of what the
## first gave: what a bot weighs the next one by.
func next_share(held: int) -> float:
	var gain := 1.0
	for _copy in held:
		gain *= stack_share
	return gain


## Whether the kind moves a rule of its taker's (SeatRules): a jump, a slope, a shove's
## share, a climb reach or a ladder's pace.
func sets_a_rule() -> bool:
	return (
		jump_height > 0.0
		or grip_angle_deg > 0.0
		or stand_limit_deg > 0.0
		or knockback_share != 1.0
		or climb_reach > 0.0
		or ladder_speed_mult != 1.0
	)


## Every reason this kind cannot be played — beside [param rules], the match's brawl rules,
## when they are given, for a seat holding one of it, and for one holding any number
## (SeatRules.at_most, SeatRules.problems); empty when it can.
func problems(rules: BrawlRules = null) -> PackedStringArray:
	var found := PackedStringArray()
	if title.strip_edges().is_empty():
		found.append("bonus kind: a title")
	if radius <= 0.0 or height <= 0.0:
		found.append("bonus kind: a size is a radius and a height, both positive")
	if knockback_share < 0.0 or knockback_share > 1.0:
		found.append("bonus kind: a shove share within 0…1")
	if jump_height < 0.0 or climb_reach < 0.0 or ladder_speed_mult <= 0.0:
		found.append("bonus kind: a jump and a climb reach of 0 or more, a ladder pace above 0")
	if grip_angle_deg < 0.0 or stand_limit_deg < 0.0:
		found.append("bonus kind: a grip angle and a stand limit of 0 or more")
	if stack_share < 0.0 or stack_share > 1.0:
		found.append("bonus kind: a stack share within 0…1")
		return found
	if stack_share == 1.0 and sets_a_rule():
		found.append("bonus kind: a stack share under 1 for a kind that sets a rule")
		return found
	if rules == null:
		return found
	if stand_limit_deg >= rules.brace_holds_to:
		found.append("bonus kind: a stand limit under the brace's hold")
	var held: Array[BonusKind] = [self]
	for seat: SeatRules in [SeatRules.of(rules, null, held), SeatRules.at_most(rules, held)]:
		for problem: String in seat.problems(rules):
			if not found.has(problem):
				found.append(problem)
	return found
