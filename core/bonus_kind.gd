class_name BonusKind
extends Resource
## What a kind of bonus is (#307), the same for every one of it: its title, for the feed and
## the HUD; its size, which a Grab press reaches it by and its model stays inside; the
## colour it is drawn in; and what it gives the seat that takes it, through a rule there
## already is — a field a kind leaves unset leaves that rule as the brawl rules have it. One
## file per kind, data/bonuses/NAME.tres, as the prop kinds are. What a seat with it plays
## by is SeatRules'.

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


## Every reason this kind cannot be played — beside [param rules], the match's brawl rules,
## when they are given (_problems_beside); empty when it can.
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
	if rules != null:
		found.append_array(_problems_beside(rules))
	return found


## Every reason this kind cannot be played beside [param rules], by what its taker plays by
## (SeatRules): of the slopes it sets — their own are theirs to answer for
## (BrawlRules.problems) — a grip angle past the stand limit its taker would have, a stand
## limit not under the brace's hold, which stays theirs for every seat, or a grip angle the
## deck would not pull a body past against their slide_friction (BrawlRules.pulls_at); a
## climb reach lower than theirs; or a speed it gives — its jump's take-off from a level
## deck (Movement.take_off), its pace up a ladder — as fast as the fastest the rules move
## anything (BrawlRules.fastest_speed), which the online prediction bounds everything that
## moves by (ContactWatch).
func _problems_beside(rules: BrawlRules) -> PackedStringArray:
	var found := PackedStringArray()
	var taker := SeatRules.of(rules, null, self)
	var sets_slopes := grip_angle_deg > 0.0 or stand_limit_deg > 0.0
	if sets_slopes and taker.grip_angle_deg > taker.stand_limit_deg:
		found.append("bonus kind: a grip angle at most the stand limit its taker would have")
	if stand_limit_deg >= rules.brace_holds_to:
		found.append("bonus kind: a stand limit under the brace's hold")
	if grip_angle_deg > 0.0 and not rules.pulls_at(grip_angle_deg):
		found.append("bonus kind: a grip angle the deck pulls past against slide_friction")
	if taker.climb_reach < rules.climb_reach:
		found.append("bonus kind: a climb reach no lower than the brawl rules'")
	var fastest := rules.fastest_speed()
	var take_off := Movement.take_off(rules.gravity, taker.jump_height)
	if take_off >= fastest or taker.ladder_speed >= fastest:
		found.append("bonus kind: no speed it gives as fast as the fastest the rules move anything")
	return found
