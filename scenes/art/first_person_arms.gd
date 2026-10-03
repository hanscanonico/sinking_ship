class_name FirstPersonArms
extends Node3D
## Your own arms in first person (D14): a crew brawler in the viewed seat's colour,
## hung from the camera by its chest — held under the eye whatever the clip does
## with the body — with its head shrunk away, so only what reaches out in front
## comes into view: the hands of a shove, a wind-up, a charge or a brace, low and to
## the sides of the crosshair, never nearer the eye than the arms reach. It is posed
## as the crew is, by Brawler.show_state from the seat's two snapshot entries (D5),
## and drives nothing (D12). Bracing, which the crew shows as a crouch with the hands
## at the knees, shows here as the raised guard, a jump's spring as the fall it turns
## into, and a hit-stop as the pose held unsquashed.

## The bone the brawler hangs from, and where it is held in camera space.
const CHEST_BONE := &"DEF-spine.003"
const CHEST := Vector3(0.0, -0.3, 0.05)
## The brawler is drawn facing +x; the camera looks down its own -z.
const TURN := PI * 0.5
const BRACE_CLIP := &"Punch_Enter"

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
		_body.show_as_own_arms(clips)
		_body.rotation.y = TURN
	_body.show_state(then, now, alpha)
	_body.collapse_bone(Brawler.HEAD_BONE)
	_body.position += CHEST - to_local(_body.bone_position(CHEST_BONE))
