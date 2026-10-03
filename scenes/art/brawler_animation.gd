class_name BrawlerAnimation
extends RefCounted
## Which clip a brawler plays, read off one seat's snapshot entry (D5). It picks a
## pose for a state the sim already decided and never feeds anything back (D12).

## BRACE, CHARGE, SWIM and CLIMB have no state to read until SH4 and SH5 add one;
## their clips are chosen now so those milestones add only the case in move_for().
enum Move { IDLE, WALK, RUN, WINDUP, SHOVE, RECOVER, STAGGER, FALL, BRACE, CHARGE, SWIM, CLIMB }

## Clips of the Universal Animation Library's mannequin, by move.
const CLIPS := {
	Move.IDLE: &"Idle",
	Move.WALK: &"Walk",
	Move.RUN: &"Jog_Fwd",
	Move.WINDUP: &"Punch_Enter",
	Move.SHOVE: &"Push",
	Move.RECOVER: &"Idle",
	Move.STAGGER: &"Hit_Chest",
	Move.FALL: &"Jump",
	Move.BRACE: &"Crouch_Idle",
	Move.CHARGE: &"Punch_Enter",
	Move.SWIM: &"Swim_Fwd",
	Move.CLIMB: &"Crouch_Fwd",
}
## How long the previous clip fades out, by move: a shove snaps into its pose so the
## telegraph lands on its tick, and recovery spends its whole window easing out.
const BLEND := {
	Move.IDLE: 0.2,
	Move.WALK: 0.2,
	Move.RUN: 0.15,
	Move.WINDUP: 0.05,
	Move.SHOVE: 0.05,
	Move.RECOVER: 0.25,
	Move.STAGGER: 0.04,
	Move.FALL: 0.15,
	Move.BRACE: 0.1,
	Move.CHARGE: 0.1,
	Move.SWIM: 0.2,
	Move.CLIMB: 0.15,
}
## Ship-plane speeds, m/s, above which the feet walk and then run.
const WALK_FROM := 0.4
const RUN_FROM := 2.5
## The ground speed each locomotion clip's stride covers at its authored rate,
## from how far a planted foot travels back through one cycle.
const WALK_CLIP_SPEED := 1.1
const RUN_CLIP_SPEED := 4.5


## The move for [param entry], a seat's snapshot entry, moving at [param speed]
## across the deck.
static func move_for(entry: Dictionary, speed: float) -> Move:
	if entry["state"] == PlayerState.Body.AIRBORNE:
		return Move.FALL
	if entry["stagger"] > 0:
		return Move.STAGGER
	match entry["action"]:
		PlayerState.Action.WINDUP:
			return Move.WINDUP
		PlayerState.Action.ACTIVE:
			return Move.SHOVE
		PlayerState.Action.RECOVERY:
			return Move.RECOVER
	if speed >= RUN_FROM:
		return Move.RUN
	if speed >= WALK_FROM:
		return Move.WALK
	return Move.IDLE


## How fast [param move]'s clip plays so a stride matches [param speed].
static func rate(move: Move, speed: float) -> float:
	match move:
		Move.WALK:
			return speed / WALK_CLIP_SPEED
		Move.RUN:
			return speed / RUN_CLIP_SPEED
	return 1.0
