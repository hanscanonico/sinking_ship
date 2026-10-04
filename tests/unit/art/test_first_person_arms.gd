extends GutTest
## Your own arms, in every pose they take and through a jump and a fall, stay clear
## of the crosshair and of the readouts at the bottom left (FirstPersonArms'
## keep-clear zones) through the first-person camera's lens: at the default field of
## view and the narrowest, on the windows the game is checked on. The HUD's canvas
## scales with the window (canvas_items, expand), so the zones scale with it.

const SEAT := 4
const WINDOWS: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1440.0, 900.0), Vector2(1920.0, 1080.0)
]
## The moves drawn by their clip alone, beside those FirstPersonArms poses.
const CLIP_MOVES: Array[BrawlerAnimation.Move] = [
	BrawlerAnimation.Move.FALL, BrawlerAnimation.Move.JUMP
]
## Along each arm, elbow to fingertips: the bones whose heads mark it.
const JOINTS := {
	&"L": [&"DEF-forearm.L", &"DEF-hand.L", &"DEF-f_middle.01.L", &"DEF-f_middle.03.L"],
	&"R": [&"DEF-forearm.R", &"DEF-hand.R", &"DEF-f_middle.01.R", &"DEF-f_middle.03.R"],
}
const THUMBS: Array[StringName] = [&"DEF-thumb.03.L", &"DEF-thumb.03.R"]
const HANDS: Array[StringName] = [&"DEF-hand.L", &"DEF-hand.R"]
const WINDUP := BrawlerAnimation.Move.WINDUP
const BRACE := BrawlerAnimation.Move.BRACE
const STAGGER := BrawlerAnimation.Move.STAGGER
## How far, in pixels, a stagger flings each hand from its wind-up and brace places.
const FLUNG := 180.0
## How far the sleeve (round the forearm) and the hand stand out from their bones
## with the outline, in metres, and how many points are checked along each bone.
const SLEEVE := 0.055
const HAND := 0.04
const SAMPLES := 6
## How long a move's pose settles before it is checked, and how long it is watched:
## a whole swim, both strokes, and then some.
const SETTLE := 0.4
const WATCH := 1.6

var _eye: Node3D
var _arms: FirstPersonArms
var _entry: Dictionary
var _lenses: Array[Projection] = []
var _sizes: Array[Vector2] = []
var _labels := PackedStringArray()


func before_each() -> void:
	_eye = Node3D.new()
	add_child_autofree(_eye)
	_arms = FirstPersonArms.new()
	_eye.add_child(_arms)
	_arms.setup(SimFixtures.rules())
	_entry = SimFixtures.sim(1).snapshot()["seats"][0]
	_lenses.clear()
	_sizes.clear()
	_labels.clear()
	for fov: float in [ViewSettings.new().fov_deg, ViewSettings.FOV_MIN]:
		for size: Vector2 in WINDOWS:
			# As FirstPersonCamera frames it: the field of view across the width.
			_lenses.append(
				Projection.create_perspective(
					fov, size.aspect(), FirstPersonCamera.NEAR, 100.0, true
				)
			)
			_sizes.append(size)
			_labels.append("fov %d %dx%d" % [fov, size.x, size.y])


func test_the_arms_stay_clear_of_the_crosshair_and_the_readouts_in_every_pose() -> void:
	var problems := {}
	var moves: Array = FirstPersonArms.POSES.keys()
	moves.append_array(CLIP_MOVES)
	for move: BrawlerAnimation.Move in moves:
		var entry := _as(move)
		var watched := 0.0
		while watched < SETTLE + WATCH:
			_arms.show_seat(SEAT, entry, entry, 1.0)
			if watched >= SETTLE:
				_check(move, problems)
			await get_tree().process_frame
			watched += _arms.get_process_delta_time()
	assert_eq(problems.size(), 0, "\n".join(PackedStringArray(problems.values())))


## Your own stagger reads at a glance apart from a wind-up and a brace, both of which
## hold the fists up in the middle — from the very hit-stop the shove lands with, out
## of a brace: knocked aside, each hand is flung FLUNG pixels or more out of where
## either holds it, and one stays in view, at the default field of view.
func test_a_stagger_flings_the_hands_out_of_the_windup_and_the_brace() -> void:
	var lens := _lenses[0]
	var size := _sizes[0]
	var held := {}
	for move: BrawlerAnimation.Move in [WINDUP, BRACE, STAGGER]:
		var entry := _as(move)
		if move == STAGGER:
			entry["hitstop"] = Ticks.from_seconds(SimFixtures.rules().hitstop)
		var watched := 0.0
		while watched < SETTLE:
			_arms.show_seat(SEAT, entry, entry, 1.0)
			await get_tree().process_frame
			watched += _arms.get_process_delta_time()
		var body: Brawler = _arms.get_node("Body")
		var hands := PackedVector2Array()
		for hand: StringName in HANDS:
			hands.append(_pixel(lens, size, _eye.to_local(body.bone_position(hand))))
		held[move] = hands
	var seen := 0
	for hand in HANDS.size():
		for move: BrawlerAnimation.Move in [WINDUP, BRACE]:
			var apart: float = held[STAGGER][hand].distance_to(held[move][hand])
			var named: String = BrawlerAnimation.Move.keys()[move]
			assert_gt(apart, FLUNG, "%s %.0f px from its %s place" % [HANDS[hand], apart, named])
		if Rect2(Vector2.ZERO, size).has_point(held[STAGGER][hand]):
			seen += 1
	assert_gt(seen, 0, "a hand flung out stays in view: %s" % held[STAGGER])


## The seat's snapshot entry as it stands still in [param move].
func _as(move: BrawlerAnimation.Move) -> Dictionary:
	var entry := _entry.duplicate()
	match move:
		BrawlerAnimation.Move.WALK:
			entry["vel"] = Vector3(1.2, 0.0, 0.0)
		BrawlerAnimation.Move.RUN:
			entry["vel"] = Vector3(4.0, 0.0, 0.0)
		BrawlerAnimation.Move.WINDUP:
			entry["action"] = PlayerState.Action.WINDUP
		BrawlerAnimation.Move.SHOVE:
			entry["action"] = PlayerState.Action.ACTIVE
		BrawlerAnimation.Move.RECOVER:
			entry["action"] = PlayerState.Action.RECOVERY
		BrawlerAnimation.Move.CHARGE:
			entry["action"] = PlayerState.Action.CHARGE
		BrawlerAnimation.Move.BRACE:
			entry["bracing"] = true
		BrawlerAnimation.Move.STAGGER:
			entry["stagger"] = 10
		BrawlerAnimation.Move.SWIM:
			entry["state"] = PlayerState.Body.SWIMMING
		BrawlerAnimation.Move.CLIMB:
			entry["state"] = PlayerState.Body.SWIMMING
			entry["climb"] = 10
		BrawlerAnimation.Move.FALL:
			entry["state"] = PlayerState.Body.AIRBORNE
		BrawlerAnimation.Move.JUMP:
			entry["state"] = PlayerState.Body.AIRBORNE
			entry["jumped"] = true
			entry["vel"] = Vector3(0.0, 3.0, 0.0)
	assert_eq(BrawlerAnimation.move_for(entry, (entry["vel"] as Vector3).length()), move)
	return entry


## Notes in [param problems] each bone of the arms, as drawn now, that comes into a
## keep-clear zone of any view, the first time it does in [param move].
func _check(move: BrawlerAnimation.Move, problems: Dictionary) -> void:
	var body: Brawler = _arms.get_node("Body")
	for side: StringName in JOINTS:
		var bones: Array = JOINTS[side]
		for index in bones.size() - 1:
			var from := _eye.to_local(body.bone_position(bones[index]))
			var to := _eye.to_local(body.bone_position(bones[index + 1]))
			var radius := SLEEVE if index == 0 else HAND
			for step in SAMPLES + 1:
				_check_point(
					move, bones[index], from.lerp(to, float(step) / SAMPLES), radius, problems
				)
	for thumb: StringName in THUMBS:
		_check_point(move, thumb, _eye.to_local(body.bone_position(thumb)), HAND, problems)


func _check_point(
	move: BrawlerAnimation.Move,
	bone: StringName,
	point: Vector3,
	radius: float,
	problems: Dictionary
) -> void:
	if -point.z < FirstPersonCamera.NEAR:
		return
	for view in _lenses.size():
		var size := _sizes[view]
		var scale := _canvas_scale(size)
		var canvas := size / scale
		var crosshair := Rect2(
			canvas * 0.5 - FirstPersonArms.CROSSHAIR_CLEAR, FirstPersonArms.CROSSHAIR_CLEAR * 2.0
		)
		var readouts := FirstPersonArms.READOUTS_CLEAR
		readouts.position.y += canvas.y
		for offset: Vector3 in [
			Vector3.ZERO, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN
		]:
			var at := _pixel(_lenses[view], size, point + offset * radius) / scale
			for zone: Rect2 in [crosshair, readouts]:
				var key := "%s %s %s" % [BrawlerAnimation.Move.keys()[move], bone, _labels[view]]
				if zone.has_point(at) and not problems.has(key):
					problems[key] = "%s at %s" % [key, at.round()]


## How many of a window of [param size]'s pixels one of the HUD's canvas spans: the
## canvas keeps the project's whole base size and expands the other way.
func _canvas_scale(size: Vector2) -> float:
	var base := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	return minf(size.x / base.x, size.y / base.y)


## Where [param point], in the eye's space, is drawn on a window of [param size]
## through [param lens].
func _pixel(lens: Projection, size: Vector2, point: Vector3) -> Vector2:
	var clip := lens * Vector4(point.x, point.y, point.z, 1.0)
	var ndc := Vector2(clip.x, clip.y) / clip.w
	return Vector2((ndc.x * 0.5 + 0.5) * size.x, (0.5 - ndc.y * 0.5) * size.y)
