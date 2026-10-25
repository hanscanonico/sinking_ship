class_name SeatRules
extends RefCounted
## The rules as they stand for one seat (#307): those a bonus may change — how high it
## jumps, the slopes it holds on and stands on, the share of a shove's knockback it takes,
## how high it climbs out of the sea and how fast up a ladder — and what the prop in its
## hands costs it (#273). The brawl rules' own for a seat with empty hands; a held prop's
## kind sets its carry costs. Derived from what the seat has, never in the snapshot: the
## props say who holds what (PropState.holder), so a snapshot needs nothing more, and the
## sim, the bots and the HUD each derive it from what they read. One is shared by every
## seat it stands for, so read it, never write it. Every other rule — the brace's hold and
## the floor it flips to among them — is the brawl rules', the same for every seat.

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
## empty hands.
static func of(rules: BrawlRules, held: PropKind) -> SeatRules:
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
	return seat


## The rules for [param seat] as [param snapshot] — of a match on [param layout] under
## [param rules] — has it: by the prop it holds there, asked only of [param holdable]
## (GrabReach.holdable_of) when given.
static func in_snapshot(
	snapshot: Dictionary,
	seat: int,
	layout: ShipLayout,
	rules: BrawlRules,
	holdable := PackedInt32Array()
) -> SeatRules:
	var held := PropState.held_in(snapshot, seat, holdable)
	return of(rules, layout.props[held].prop_kind() if held != -1 else null)
