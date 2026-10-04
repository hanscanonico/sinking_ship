class_name BrawlerAnimation
extends RefCounted
## Which clip a brawler plays, read off one seat's snapshot entry (D5). It picks a
## pose for a state the sim already decided and never feeds anything back (D12).

enum Move {
	IDLE,
	WALK,
	RUN,
	WINDUP,
	SHOVE,
	RECOVER,
	STAGGER,
	FALL,
	BRACE,
	CHARGE,
	SWIM,
	CLIMB,
	JUMP,
}

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
	Move.JUMP: &"Jump_Start",
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
	Move.JUMP: 0.05,
}
## The poses laid over a clip (BrawlerPose), by move: a telegraph has to read in a
## single frame from the front and the side, which no clip of the library does. A
## wind-up coils — the shoulders turned away, both hands drawn back to the far hip,
## the weight on the back foot, the head still on the target; a charge sets low and
## wide, leaning in with the elbows back and the hands cocked, held; the shove
## uncoils into a lunge, both arms straight out and the back leg driving; a brace
## digs in low and wide behind raised forearms; a stagger throws the head and arms
## back; a swimmer's crawl is stood up so the head and shoulders ride above the sea
## its feet hang under; a climb reaches up the ladder hand over hand, looking up.
const POSES := {
	Move.WINDUP:
	{
		BrawlerPose.HIPS_AT: Vector3(0.0, -0.1, -0.12),
		&"DEF-hips": Vector3(-4.0, -22.0, 0.0),
		&"DEF-spine.001": Vector3(-8.0, -34.0, 0.0),
		&"DEF-spine.003": Vector3(-12.0, -48.0, 0.0),
		&"DEF-neck": Vector3(-2.0, -24.0, 0.0),
		&"DEF-head": Vector3(10.0, -6.0, 0.0),
		BrawlerPose.REACH_L: Vector3(-0.1, -0.24, 0.12),
		BrawlerPose.REACH_R: Vector3(-0.26, -0.26, -0.06),
		&"DEF-hand.L": Vector3(-0.6, 0.6, 0.5),
		&"DEF-hand.R": Vector3(-0.3, 0.6, 0.7),
		&"DEF-foot.L": Vector3(0.06, 0.0, 0.24),
		&"DEF-foot.R": Vector3(-0.06, 0.0, -0.32),
	},
	Move.CHARGE:
	{
		BrawlerPose.HIPS_AT: Vector3(0.0, -0.22, 0.0),
		&"DEF-hips": Vector3(12.0, -8.0, 0.0),
		&"DEF-spine.001": Vector3(20.0, -10.0, 0.0),
		&"DEF-spine.003": Vector3(28.0, -12.0, 0.0),
		&"DEF-neck": Vector3(14.0, -6.0, 0.0),
		&"DEF-head": Vector3(-4.0, 0.0, 0.0),
		BrawlerPose.REACH_L: Vector3(0.2, -0.08, 0.08),
		BrawlerPose.REACH_R: Vector3(-0.2, -0.08, 0.08),
		&"DEF-hand.L": Vector3(0.0, 0.7, 0.7),
		&"DEF-hand.R": Vector3(0.0, 0.7, 0.7),
		&"DEF-foot.L": Vector3(0.14, 0.0, 0.26),
		&"DEF-foot.R": Vector3(-0.14, 0.0, -0.26),
	},
	Move.SHOVE:
	{
		BrawlerPose.HIPS_AT: Vector3(0.0, -0.14, 0.22),
		&"DEF-hips": Vector3(14.0, 8.0, 0.0),
		&"DEF-spine.001": Vector3(22.0, 10.0, 0.0),
		&"DEF-spine.003": Vector3(30.0, 12.0, 0.0),
		&"DEF-neck": Vector3(14.0, 6.0, 0.0),
		&"DEF-head": Vector3(4.0, 4.0, 0.0),
		&"DEF-upper_arm.L": Vector3(0.14, 0.42, 1.0),
		&"DEF-forearm.L": Vector3(0.04, 0.45, 1.0),
		&"DEF-hand.L": Vector3(0.0, 1.0, 0.3),
		&"DEF-upper_arm.R": Vector3(-0.14, 0.42, 1.0),
		&"DEF-forearm.R": Vector3(-0.04, 0.45, 1.0),
		&"DEF-hand.R": Vector3(0.0, 1.0, 0.3),
		&"DEF-foot.L": Vector3(0.05, 0.0, 0.42),
		&"DEF-foot.R": Vector3(-0.05, 0.0, -0.5),
	},
	Move.BRACE:
	{
		BrawlerPose.HIPS_AT: Vector3(0.0, -0.17, -0.02),
		&"DEF-hips": Vector3(8.0, 0.0, 0.0),
		&"DEF-spine.001": Vector3(12.0, 0.0, 0.0),
		&"DEF-spine.003": Vector3(16.0, 0.0, 0.0),
		&"DEF-neck": Vector3(5.0, 0.0, 0.0),
		&"DEF-head": Vector3(18.0, 0.0, 0.0),
		&"DEF-upper_arm.L": Vector3(0.45, -0.35, 0.8),
		&"DEF-forearm.L": Vector3(-0.45, 0.85, 0.25),
		&"DEF-upper_arm.R": Vector3(-0.45, -0.35, 0.8),
		&"DEF-forearm.R": Vector3(0.45, 0.85, 0.25),
		&"DEF-foot.L": Vector3(0.13, 0.0, 0.12),
		&"DEF-foot.R": Vector3(-0.13, 0.0, -0.1),
	},
	Move.STAGGER:
	{
		BrawlerPose.HIPS_AT: Vector3(0.0, -0.05, -0.08),
		&"DEF-hips": Vector3(-10.0, 0.0, 0.0),
		&"DEF-spine.001": Vector3(-18.0, 0.0, 5.0),
		&"DEF-spine.003": Vector3(-30.0, 6.0, 10.0),
		&"DEF-neck": Vector3(-15.0, 0.0, 0.0),
		&"DEF-head": Vector3(-26.0, 8.0, 8.0),
		&"DEF-upper_arm.L": Vector3(0.9, 0.05, 0.35),
		&"DEF-forearm.L": Vector3(0.6, 0.5, 0.6),
		&"DEF-upper_arm.R": Vector3(-0.9, 0.05, 0.35),
		&"DEF-forearm.R": Vector3(-0.6, 0.5, 0.6),
		&"DEF-foot.L": Vector3(0.06, 0.0, 0.12),
		&"DEF-foot.R": Vector3(-0.06, 0.0, -0.3),
	},
	Move.SWIM:
	{
		BrawlerPose.HIPS_AT: Vector3(0.0, 0.2, -0.05),
		&"DEF-hips": Vector3(40.0, 0.0, 0.0),
		&"DEF-spine.001": Vector3(42.0, 0.0, 0.0),
		&"DEF-spine.003": Vector3(40.0, 0.0, 0.0),
		&"DEF-neck": Vector3(10.0, 0.0, 0.0),
		&"DEF-head": Vector3(-5.0, 0.0, 0.0),
	},
	Move.CLIMB:
	{
		&"DEF-spine.003": Vector3(12.0, 0.0, 0.0),
		&"DEF-head": Vector3(-20.0, 0.0, 0.0),
		BrawlerPose.REACH_L: Vector3(0.14, 0.5, 0.3),
		BrawlerPose.REACH_R: Vector3(-0.14, 0.32, 0.32),
		&"DEF-hand.L": Vector3(0.0, 0.4, 1.0),
		&"DEF-hand.R": Vector3(0.0, 0.4, 1.0),
	},
}
## Ship-plane speeds, m/s, above which the feet walk and then run.
const WALK_FROM := 0.4
const RUN_FROM := 2.5
## The ground speed each locomotion clip's stride covers at its authored rate,
## from how far a planted foot travels back through one cycle.
const WALK_CLIP_SPEED := 1.1
const RUN_CLIP_SPEED := 4.5
## A hit-stop squashes the model this much shorter, wider by half of it, held for
## the stop and springing back over SQUASH_SECONDS after.
const SQUASH := 0.14
const SQUASH_SECONDS := 0.18


## The move for [param entry], a seat's snapshot entry, moving at [param speed]
## across the deck.
static func move_for(entry: Dictionary, speed: float) -> Move:
	if entry["state"] == PlayerState.Body.AIRBORNE:
		# A jump springs up off the ground and falls like any fall once it tops out.
		if entry["jumped"] and (entry["vel"] as Vector3).y > 0.0:
			return Move.JUMP
		return Move.FALL
	if entry["state"] == PlayerState.Body.SWIMMING:
		return Move.CLIMB if entry["climb"] > 0 else Move.SWIM
	if entry["stagger"] > 0:
		return Move.STAGGER
	match entry["action"]:
		PlayerState.Action.WINDUP:
			return Move.WINDUP
		PlayerState.Action.ACTIVE:
			return Move.SHOVE
		PlayerState.Action.RECOVERY:
			return Move.RECOVER
		PlayerState.Action.CHARGE:
			return Move.CHARGE
	if entry["bracing"]:
		return Move.BRACE
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


## The model's scale [param since] seconds after its hit-stop ended — 0 while it
## holds — back to one at SQUASH_SECONDS.
static func squash(since: float) -> Vector3:
	var left := clampf(1.0 - since / SQUASH_SECONDS, 0.0, 1.0)
	var depth := SQUASH * left * left
	return Vector3(1.0 + depth * 0.5, 1.0 - depth, 1.0 + depth * 0.5)
