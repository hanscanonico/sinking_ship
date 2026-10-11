extends GutTest
## Hands face the way their move pushes (BrawlerPose's palms): a shove's open hands
## push palms first toward whoever it shoves, on a brawler seen across the deck and on
## your own arms, and your own raised fists — a wind-up's, a charge's, a brace's —
## turn their backs to the eye, thumbs inside, never their palms as if swapped.

const SIDES: Array[StringName] = [&"L", &"R"]
const RAISED: Array[BrawlerAnimation.Move] = [
	BrawlerAnimation.Move.WINDUP, BrawlerAnimation.Move.CHARGE, BrawlerAnimation.Move.BRACE
]
## How long a move's pose settles before it is checked.
const SETTLE := 0.4
## The least a palm pushing ahead lines up with the way ahead (the cosine): within
## 60 degrees of it — the fingers point up as well as ahead, so the palm tips down.
const PALM_FIRST := 0.5

var _entry: Dictionary


func before_each() -> void:
	_entry = SimFixtures.sim(1).snapshot()["seats"][0]


func test_a_shove_pushes_palms_first_at_whoever_it_shoves() -> void:
	var body := Brawler.new()
	add_child_autofree(body)
	body.setup(1, SimFixtures.rules(), false)
	var entry := _as(BrawlerAnimation.Move.SHOVE)
	await _settle(func() -> void: body.show_state(entry, entry, 1.0), body)
	# Facing 0, a brawler shoves along +x (as Brawler.keep_apart reaches).
	for side: StringName in SIDES:
		var facing := _palm(body, side).dot(Vector3.RIGHT)
		assert_gt(facing, PALM_FIRST, "the %s palm pushes ahead: %.2f" % [side, facing])


func test_your_own_shove_pushes_palms_first_away_from_the_eye() -> void:
	var eye := _eye()
	var arms: FirstPersonArms = eye.get_child(0)
	var entry := _as(BrawlerAnimation.Move.SHOVE)
	await _settle(func() -> void: arms.show_seat(4, entry, entry, 1.0), arms)
	var body: Brawler = arms.get_node("Body")
	for side: StringName in SIDES:
		var facing := _palm(body, side).dot(_ahead(eye))
		assert_gt(facing, PALM_FIRST, "the %s palm pushes ahead: %.2f" % [side, facing])


func test_your_own_raised_fists_show_their_backs_thumbs_inside() -> void:
	var eye := _eye()
	var arms: FirstPersonArms = eye.get_child(0)
	for move: BrawlerAnimation.Move in RAISED:
		var entry := _as(move)
		await _settle(func() -> void: arms.show_seat(4, entry, entry, 1.0), arms)
		var body: Brawler = arms.get_node("Body")
		var named: String = BrawlerAnimation.Move.keys()[move]
		for side: StringName in SIDES:
			var facing := _palm(body, side).dot(_ahead(eye))
			assert_gt(facing, 0.0, "%s: the %s palm faces away: %.2f" % [named, side, facing])
			var thumb := eye.to_local(body.bone_position(StringName("DEF-thumb.03." + side)))
			var pinky := eye.to_local(body.bone_position(StringName("DEF-f_pinky.01." + side)))
			assert_lt(absf(thumb.x), absf(pinky.x), "%s: the %s thumb is inside" % [named, side])


## An eye with your own arms under it, set up but not yet shown.
func _eye() -> Node3D:
	var eye := Node3D.new()
	add_child_autofree(eye)
	var arms := FirstPersonArms.new()
	eye.add_child(arms)
	arms.setup(SimFixtures.rules())
	return eye


## The way [param eye] looks: a camera's -z.
func _ahead(eye: Node3D) -> Vector3:
	return -eye.global_transform.basis.z


## Shows a pose with [param show] frame by frame until it has settled, as
## [param node] counts the time.
func _settle(show: Callable, node: Node) -> void:
	var watched := 0.0
	while watched < SETTLE:
		show.call()
		await get_tree().process_frame
		watched += node.get_process_delta_time()
	show.call()


## The way [param body]'s [param side] palm faces, in the world: square to the
## hand's knuckles and to the way it points, on the palm's side.
func _palm(body: Brawler, side: StringName) -> Vector3:
	var hand := body.bone_position(StringName("DEF-hand." + side))
	var middle := body.bone_position(StringName("DEF-f_middle.01." + side))
	var across := (
		body.bone_position(StringName("DEF-f_index.01." + side))
		- body.bone_position(StringName("DEF-f_pinky.01." + side))
	)
	var palm := (middle - hand).cross(across)
	return (palm if side == &"L" else -palm).normalized()


## The seat's snapshot entry as it stands still in [param move].
func _as(move: BrawlerAnimation.Move) -> Dictionary:
	var entry := _entry.duplicate()
	match move:
		BrawlerAnimation.Move.WINDUP:
			entry["action"] = PlayerState.Action.WINDUP
		BrawlerAnimation.Move.CHARGE:
			entry["action"] = PlayerState.Action.CHARGE
		BrawlerAnimation.Move.SHOVE:
			entry["action"] = PlayerState.Action.ACTIVE
		BrawlerAnimation.Move.BRACE:
			entry["bracing"] = true
	return entry
