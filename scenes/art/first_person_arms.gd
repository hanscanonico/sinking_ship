class_name FirstPersonArms
extends Node3D
## Your own arms in first person (D14): a crew brawler in the viewed seat's clothes,
## hung from the camera by its chest — held upright under the eye whatever the clip
## does with the body — with its head shrunk away, so only its sleeves and hands come
## into view, low and to the sides of the crosshair and clear of the readouts at
## the bottom left. It is posed as the crew is, by Brawler.show_state from the
## seat's two snapshot entries (D5), and drives nothing (D12), but with poses of its
## own (POSES), framed for the eye: fists low at the bottom edge at rest or on the
## move, drawn up close in a wind-up and closer in a charge, thrust out in a shove,
## a raised guard in a brace, flung up out of view in a stagger, a small
## breaststroke low at the bottom edge in the sea, and one hand reaching high and
## the other gripping low as a climb hauls the body up. A jump's spring shows as
## the fall it turns into, and a hit-stop as the pose held unsquashed.

## What the arms never cover, in pixels of a window as wide as the game first opens
## (the arms scale with a window's width, the HUD's pixels do not): a zone round the
## crosshair, its half size, and the readouts FirstPersonHud stacks at the bottom
## left, from the room's name down to the cold slot, placed off the window's
## bottom-left corner.
const KEEP_CLEAR_WIDTH := 1152.0
const CROSSHAIR_CLEAR := Vector2(96.0, 72.0)
const READOUTS_CLEAR := Rect2(16.0, -174.0, 252.0, 124.0)
## The bone the brawler hangs from, and where it is held in camera space: ahead of
## the eye as well as under it, so the elbows come in below the hands.
const CHEST_BONE := &"DEF-spine.003"
const CHEST := Vector3(0.0, -0.55, -0.2)
## The brawler is drawn facing +x; the camera looks down its own -z.
const TURN := PI * 0.5
## The fists of a shove's wind-up clip, for the guard a brace raises here.
const BRACE_CLIP := &"Punch_Enter"
## The elbows hang straight down, so the sleeves rise steeply from the bottom edge
## rather than slanting in across the readouts.
const ELBOWS: Array[Vector3] = [Vector3(0.1, -1.0, 0.0), Vector3(-0.1, -1.0, 0.0)]
## Every pose holds the chest upright: the arms reach from it.
const UPRIGHT := Vector3.ZERO
## Fists low at the bottom edge: at rest, walking, running and easing out of a shove.
## Wrist spots and finger directions are in the chest's frame, model units: +x the
## body's left (the screen's left), +y up, +z ahead.
const AT_REST := {
	&"DEF-spine.003": UPRIGHT,
	BrawlerPose.REACH_L: Vector3(0.17, 0.26, 0.31),
	BrawlerPose.REACH_R: Vector3(-0.17, 0.26, 0.31),
	&"DEF-hand.L": Vector3(-0.1, 0.6, 1.0),
	&"DEF-hand.R": Vector3(0.1, 0.6, 1.0),
}
const POSES := {
	BrawlerAnimation.Move.IDLE: AT_REST,
	BrawlerAnimation.Move.WALK: AT_REST,
	BrawlerAnimation.Move.RUN: AT_REST,
	BrawlerAnimation.Move.RECOVER: AT_REST,
	BrawlerAnimation.Move.WINDUP:
	{
		&"DEF-spine.003": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.093, 0.37, 0.28),
		BrawlerPose.REACH_R: Vector3(-0.093, 0.37, 0.28),
		&"DEF-hand.L": Vector3(-0.2, 1.0, -0.2),
		&"DEF-hand.R": Vector3(0.2, 1.0, -0.2),
	},
	BrawlerAnimation.Move.CHARGE:
	{
		&"DEF-spine.003": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.075, 0.375, 0.26),
		BrawlerPose.REACH_R: Vector3(-0.075, 0.375, 0.26),
		&"DEF-hand.L": Vector3(-0.3, 1.0, -0.4),
		&"DEF-hand.R": Vector3(0.3, 1.0, -0.4),
	},
	BrawlerAnimation.Move.SHOVE:
	{
		&"DEF-spine.003": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.12, 0.35, 0.4),
		BrawlerPose.REACH_R: Vector3(-0.12, 0.35, 0.4),
		&"DEF-hand.L": Vector3(0.0, 1.0, 0.4),
		&"DEF-hand.R": Vector3(0.0, 1.0, 0.4),
	},
	BrawlerAnimation.Move.BRACE:
	{
		&"DEF-spine.003": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.135, 0.43, 0.28),
		BrawlerPose.REACH_R: Vector3(-0.135, 0.43, 0.28),
		&"DEF-hand.L": Vector3(0.0, 1.0, -0.15),
		&"DEF-hand.R": Vector3(0.0, 1.0, -0.15),
	},
	BrawlerAnimation.Move.STAGGER:
	{
		&"DEF-spine.003": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.3, 0.75, -0.23),
		BrawlerPose.REACH_R: Vector3(-0.3, 0.75, -0.23),
		&"DEF-hand.L": Vector3(0.3, 1.0, -0.3),
		&"DEF-hand.R": Vector3(-0.3, 1.0, -0.3),
	},
	BrawlerAnimation.Move.SWIM:
	[
		{
			&"DEF-spine.003": UPRIGHT,
			BrawlerPose.REACH_L: Vector3(0.082, 0.34, 0.42),
			BrawlerPose.REACH_R: Vector3(-0.082, 0.34, 0.42),
			&"DEF-hand.L": Vector3(0.0, 0.0, 1.0),
			&"DEF-hand.R": Vector3(0.0, 0.0, 1.0),
		},
		{
			&"DEF-spine.003": UPRIGHT,
			BrawlerPose.REACH_L: Vector3(0.138, 0.324, 0.28),
			BrawlerPose.REACH_R: Vector3(-0.138, 0.324, 0.28),
			&"DEF-hand.L": Vector3(0.5, 0.0, 1.0),
			&"DEF-hand.R": Vector3(-0.5, 0.0, 1.0),
		},
	],
	BrawlerAnimation.Move.CLIMB:
	{
		&"DEF-spine.003": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.083, 0.36, 0.25),
		BrawlerPose.REACH_R: Vector3(-0.134, 0.582, 0.22),
		&"DEF-hand.L": Vector3(0.0, 1.0, 0.5),
		&"DEF-hand.R": Vector3(-0.2, 1.0, 0.3),
	},
}

var _rules: BrawlRules
var _body: Brawler


func setup(rules: BrawlRules) -> void:
	_rules = rules
	if _body != null:
		_body.queue_free()
		_body = null
	visible = false


## Poses [param seat]'s arms for the display moment [param alpha] of the way from
## [param then] to [param now], its entries in two snapshots; hidden once the seat
## is out. Until it is first called — and so from the observer camera — nothing is
## drawn.
func show_seat(seat: int, then: Dictionary, now: Dictionary, alpha: float) -> void:
	visible = not now["out"]
	if not visible:
		return
	if _body == null or _body.seat != seat:
		if _body != null:
			_body.queue_free()
		_body = Brawler.new()
		_body.name = "Body"
		add_child(_body)
		_body.setup(seat, _rules, false)
		var clips := BrawlerAnimation.CLIPS.duplicate()
		clips[BrawlerAnimation.Move.BRACE] = BRACE_CLIP
		clips[BrawlerAnimation.Move.JUMP] = clips[BrawlerAnimation.Move.FALL]
		_body.show_as_own_arms(clips, POSES, ELBOWS)
		_body.rotation.y = TURN
	_body.show_state(then, now, alpha)
	_body.collapse_bone(Brawler.HEAD_BONE)
	_body.position += CHEST - to_local(_body.bone_position(CHEST_BONE))
