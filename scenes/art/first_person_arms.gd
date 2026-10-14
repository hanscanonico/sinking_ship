class_name FirstPersonArms
extends Node3D
## Your own arms in first person (D14): the viewed seat's own arms, its coat's
## sleeves, cuffs and hands modelled finer than a crew body (Brawler.ARMS), on a crew
## brawler hung from the camera by its chest — held upright under the eye whatever the
## clip does with the body — so only sleeves and hands come into view, low and to the
## sides of the crosshair and clear of the readouts at the bottom left. It is posed as
## the crew is, by Brawler.show_state from the seat's two snapshot entries (D5), and
## drives nothing (D12), but with poses of its own (POSES), framed for the eye: fists
## low at the bottom edge at rest or on the move, knuckles and cuffs showing, drawn up
## close in a wind-up and closer in a charge, palms thrust out ahead in a shove, a
## raised guard in a brace (every raised hand turning its back to the eye, thumb
## inside), knocked aside in a stagger — the left arm flung down and back out of
## view, the right fist flung out toward the screen's edge — open hands spread with
## their fingers splayed through a jump and a fall, a breaststroke in the sea — both
## hands thrust out together under the crosshair, then pulled apart and down to the
## bottom edge — and one hand reaching high and the other gripping low as a climb
## hauls the body up. A hit-stop never squashes the arms nor holds them, so a
## stagger's recoil comes the moment the shove lands.

## What the arms never cover, in pixels of the HUD's canvas (which scales with the
## window, as the arms do): a zone round the crosshair, its half size, and the
## readouts FirstPersonHud stacks at the bottom left, from the room's name down to
## the cold slot, placed off the canvas' bottom-left corner.
const CROSSHAIR_CLEAR := Vector2(96.0, 72.0)
const READOUTS_CLEAR := Rect2(16.0, -174.0, 252.0, 124.0)
## The bone the brawler hangs from, and where it is held in camera space: ahead of
## the eye as well as under it, so the elbows come in below the hands.
const CHEST_BONE := &"chest"
const CHEST := Vector3(0.0, -0.55, -0.2)
## The brawler is drawn facing +x; the camera looks down its own -z.
const TURN := PI * 0.5
## The fists of a shove's wind-up clip, for the guard a brace raises here. A
## stagger keeps its own clip's fists, as the crew's does: knocked aside, the guard
## stays closed.
const BRACE_CLIP := &"windup"
## The elbows hang straight down, so the sleeves rise steeply from the bottom edge
## rather than slanting in across the readouts.
const ELBOWS: Array[Vector3] = [Vector3(0.1, -1.0, 0.0), Vector3(-0.1, -1.0, 0.0)]
## Every pose holds the chest upright: the arms reach from it.
const UPRIGHT := Vector3.ZERO
## The ways the palms face, so the eye sees the backs of the raised hands and their
## thumbs inside: a wind-up's and a charge's fists ahead and a little in, a brace's
## further in, so its guard shows its knuckles rather than its fingers' ends edge on;
## a shove's open hands face straight ahead (BrawlerPose.AHEAD).
const FIST_PALM_L := Vector3(-0.4, 0.0, 1.0)
const FIST_PALM_R := Vector3(0.4, 0.0, 1.0)
const BRACE_PALM_L := Vector3(-0.8, 0.0, 1.0)
const BRACE_PALM_R := Vector3(0.8, 0.0, 1.0)
## Fists low at the bottom edge, knuckles and cuffs in view: at rest, walking,
## running and easing out of a shove.
## Wrist spots and finger directions are in the chest's frame, model units: +x the
## body's left (the screen's left), +y up, +z ahead.
const AT_REST := {
	&"chest": UPRIGHT,
	BrawlerPose.REACH_L: Vector3(0.2, 0.29, 0.33),
	BrawlerPose.REACH_R: Vector3(-0.2, 0.29, 0.33),
	&"hand_l": Vector3(-0.1, 0.6, 1.0),
	&"hand_r": Vector3(0.1, 0.6, 1.0),
}
## Open hands thrown up either side, fingers splayed and palms out, catching the
## body's balance: a fall, and a jump's spring into it.
const SPREAD := {
	&"chest": UPRIGHT,
	BrawlerPose.REACH_L: Vector3(0.17, 0.38, 0.37),
	BrawlerPose.REACH_R: Vector3(-0.21, 0.38, 0.36),
	&"hand_l": Vector3(0.3, 1.0, 0.5),
	&"hand_r": Vector3(-0.45, 1.0, 0.5),
	BrawlerPose.PALM_L: Vector3(0.0, -0.4, 1.0),
	BrawlerPose.PALM_R: Vector3(0.0, -0.4, 1.0),
}
const POSES := {
	BrawlerAnimation.Move.IDLE: AT_REST,
	BrawlerAnimation.Move.WALK: AT_REST,
	BrawlerAnimation.Move.RUN: AT_REST,
	BrawlerAnimation.Move.RECOVER: AT_REST,
	BrawlerAnimation.Move.FALL: SPREAD,
	BrawlerAnimation.Move.JUMP: SPREAD,
	BrawlerAnimation.Move.WINDUP:
	{
		&"chest": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.11, 0.37, 0.28),
		BrawlerPose.REACH_R: Vector3(-0.11, 0.37, 0.28),
		&"hand_l": Vector3(-0.2, 1.0, -0.2),
		&"hand_r": Vector3(0.2, 1.0, -0.2),
		BrawlerPose.PALM_L: FIST_PALM_L,
		BrawlerPose.PALM_R: FIST_PALM_R,
	},
	BrawlerAnimation.Move.CHARGE:
	{
		&"chest": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.12, 0.375, 0.26),
		BrawlerPose.REACH_R: Vector3(-0.12, 0.375, 0.26),
		&"hand_l": Vector3(-0.3, 1.0, -0.4),
		&"hand_r": Vector3(0.3, 1.0, -0.4),
		BrawlerPose.PALM_L: FIST_PALM_L,
		BrawlerPose.PALM_R: FIST_PALM_R,
	},
	BrawlerAnimation.Move.SHOVE:
	{
		&"chest": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.135, 0.35, 0.4),
		BrawlerPose.REACH_R: Vector3(-0.135, 0.35, 0.4),
		&"hand_l": Vector3(0.0, 1.0, 0.4),
		&"hand_r": Vector3(0.0, 1.0, 0.4),
		BrawlerPose.PALM_L: BrawlerPose.AHEAD,
		BrawlerPose.PALM_R: BrawlerPose.AHEAD,
	},
	BrawlerAnimation.Move.BRACE:
	{
		&"chest": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.135, 0.38, 0.28),
		BrawlerPose.REACH_R: Vector3(-0.135, 0.38, 0.28),
		&"hand_l": Vector3(0.0, 1.0, -0.15),
		&"hand_r": Vector3(0.0, 1.0, -0.15),
		BrawlerPose.PALM_L: BRACE_PALM_L,
		BrawlerPose.PALM_R: BRACE_PALM_R,
	},
	BrawlerAnimation.Move.STAGGER:
	{
		&"chest": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.3, 0.15, -0.05),
		BrawlerPose.REACH_R: Vector3(-0.3, 0.45, 0.3),
		&"hand_l": Vector3(0.6, -0.2, -0.3),
		&"hand_r": Vector3(-1.0, 0.6, 0.3),
	},
	BrawlerAnimation.Move.SWIM:
	[
		{
			&"chest": UPRIGHT,
			BrawlerPose.REACH_L: Vector3(0.1, 0.42, 0.5),
			BrawlerPose.REACH_R: Vector3(-0.1, 0.42, 0.5),
			&"hand_l": Vector3(0.0, 0.1, 1.0),
			&"hand_r": Vector3(0.0, 0.1, 1.0),
		},
		{
			&"chest": UPRIGHT,
			BrawlerPose.REACH_L: Vector3(0.11, 0.31, 0.34),
			BrawlerPose.REACH_R: Vector3(-0.11, 0.31, 0.34),
			&"hand_l": Vector3(0.2, 0.0, 1.0),
			&"hand_r": Vector3(-0.2, 0.0, 1.0),
		},
	],
	BrawlerAnimation.Move.CLIMB:
	{
		&"chest": UPRIGHT,
		BrawlerPose.REACH_L: Vector3(0.083, 0.36, 0.25),
		BrawlerPose.REACH_R: Vector3(-0.134, 0.582, 0.22),
		&"hand_l": Vector3(0.0, 1.0, 0.5),
		&"hand_r": Vector3(-0.2, 1.0, 0.3),
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
	_body.position += CHEST - to_local(_body.bone_position(CHEST_BONE))
