class_name SeatRules
extends RefCounted
## The rules as they stand for one seat (#307): those a bonus may change — how high it
## jumps, the slopes it holds on and stands on, the share of a shove's knockback it takes,
## how high it climbs out of the sea and how fast up a ladder — and what the prop in its
## hands costs it (#273). The brawl rules' own for a seat with empty hands and no bonus; a
## held prop's kind sets its carry costs, and each bonus it has what its kind gives
## (BonusKind) on top of the others': each brings the rule it changes as far from the brawl
## rules' as its kind sets it, so two of a kind bring it twice as far. Derived from what
## the seat has, never in the snapshot: the props say who holds what (PropState.holder) and
## each seat what bonuses it has (PlayerState.bonuses), so a snapshot needs nothing more,
## and the sim, the bots and the HUD each derive it from what they read.
## One is shared by every seat it stands for, so read it, never write it. Every other rule
## — the brace's hold and the floor it flips to among them — is the brawl rules', the same
## for every seat.

## How high a jump lifts its feet above where it left the ground (BrawlRules.jump_height).
var jump_height: float
## The combined deck slope it holds at standing idle, and the tilt past which a face is no
## floor to it (BrawlRules.grip_angle_deg, BrawlRules.stand_limit_deg).
var grip_angle_deg: float
var stand_limit_deg: float
## The share of a shove's knockback it takes, before a brace takes its own share off; 0…1.
var knockback_share: float
## The highest a ledge may stand above the sea for it to climb onto, and how fast it goes
## up a ladder, in m/s (BrawlRules.climb_reach, BrawlRules.ladder_speed).
var climb_reach: float
var ladder_speed: float
## The fastest it walks for what it holds (PropKind.carry_walk); INF with empty hands.
var walk_cap: float
## Whether what it holds lets it brace, and charge a shove: one it may not charge it
## throws quick, as an exhausted one does.
var may_brace: bool
var may_charge: bool
## The share of the open water's rate its cold meter drains at in the sea: a held prop's
## sea_cold_rate where that keeps it afloat, else 1. In a pocket of trapped air the lower
## of this and pocket_cold_rate drains.
var sea_cold_rate: float


## The rules under [param rules] for a seat holding [param held] — a kind, or null for
## empty hands — with bonuses of [param bonuses] — their kinds, two of a kind listed twice:
## each brings what its kind sets as far again from the brawl rules' own, a ladder's pace
## by its share more of theirs.
static func of(rules: BrawlRules, held: PropKind, bonuses: Array[BonusKind] = []) -> SeatRules:
	var seat := SeatRules.new()
	seat.jump_height = rules.jump_height
	seat.grip_angle_deg = rules.grip_angle_deg
	seat.stand_limit_deg = rules.stand_limit_deg
	seat.knockback_share = 1.0
	seat.climb_reach = rules.climb_reach
	seat.ladder_speed = rules.ladder_speed
	seat.walk_cap = INF
	seat.may_brace = true
	seat.may_charge = true
	seat.sea_cold_rate = 1.0
	if held != null:
		seat.walk_cap = held.carry_walk
		seat.may_brace = held.carry_brace
		seat.may_charge = held.carry_charge
		if held.afloat:
			seat.sea_cold_rate = held.sea_cold_rate
	for bonus: BonusKind in bonuses:
		if bonus.jump_height > 0.0:
			seat.jump_height += bonus.jump_height - rules.jump_height
		if bonus.grip_angle_deg > 0.0:
			seat.grip_angle_deg += bonus.grip_angle_deg - rules.grip_angle_deg
		if bonus.stand_limit_deg > 0.0:
			seat.stand_limit_deg += bonus.stand_limit_deg - rules.stand_limit_deg
		seat.knockback_share -= 1.0 - bonus.knockback_share
		if bonus.climb_reach > 0.0:
			seat.climb_reach += bonus.climb_reach - rules.climb_reach
		seat.ladder_speed += rules.ladder_speed * (bonus.ladder_speed_mult - 1.0)
	return seat


## Every reason a seat on these rules cannot be played beside [param rules], the brawl rules
## its bonuses changed them from (of) — theirs are theirs to answer for
## (BrawlRules.problems): a shove share outside 0…1 or a ladder at no pace; of the slopes,
## a grip angle past the stand limit, a stand limit not under the brace's hold, which stays
## theirs for every seat, or a grip angle the deck would not pull a body past against their
## slide_friction (BrawlRules.pulls_at), each where it differs from theirs; a climb reach
## lower than theirs; or a speed it gives — its jump's take-off from a level deck
## (Movement.take_off), its pace up a ladder — as fast as the fastest the rules move
## anything (BrawlRules.fastest_speed), which the online prediction bounds everything that
## moves by (ContactWatch).
func problems(rules: BrawlRules) -> PackedStringArray:
	var found := PackedStringArray()
	if knockback_share < 0.0 or knockback_share > 1.0:
		found.append("bonus kind: a shove share within 0…1")
	if ladder_speed <= 0.0:
		found.append("bonus kind: a ladder pace above 0")
	var grip_set := grip_angle_deg != rules.grip_angle_deg
	var sets_slopes := grip_set or stand_limit_deg != rules.stand_limit_deg
	if sets_slopes and grip_angle_deg > stand_limit_deg:
		found.append("bonus kind: a grip angle at most the stand limit its taker would have")
	if stand_limit_deg != rules.stand_limit_deg and stand_limit_deg >= rules.brace_holds_to:
		found.append("bonus kind: a stand limit under the brace's hold")
	if grip_set and not rules.pulls_at(grip_angle_deg):
		found.append("bonus kind: a grip angle the deck pulls past against slide_friction")
	if climb_reach < rules.climb_reach:
		found.append("bonus kind: a climb reach no lower than the brawl rules'")
	var fastest := rules.fastest_speed()
	var take_off := Movement.take_off(rules.gravity, jump_height)
	if take_off >= fastest or ladder_speed >= fastest:
		found.append("bonus kind: no speed it gives as fast as the fastest the rules move anything")
	return found


## The rules for [param seat] as [param snapshot] — of a match on [param layout] under
## [param rules], played with [param bonus_rules] (null for none) — has it: by the prop it
## holds there, asked only of [param holdable] (GrabReach.holdable_of) when given, and by
## its bonuses (BonusRules.of_seat).
static func in_snapshot(
	snapshot: Dictionary,
	seat: int,
	layout: ShipLayout,
	rules: BrawlRules,
	bonus_rules: BonusRules,
	holdable := PackedInt32Array()
) -> SeatRules:
	var held := PropState.held_in(snapshot, seat, holdable)
	var bonuses := BonusRules.of_seat(bonus_rules, snapshot, seat)
	return of(rules, layout.props[held].prop_kind() if held != -1 else null, bonuses)
