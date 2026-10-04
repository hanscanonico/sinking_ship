extends GutTest
## Your own arms, in every pose they take, stay clear of the crosshair and of the
## readouts at the bottom left (FirstPersonArms' keep-clear zones) through the
## first-person camera's lens: at the default field of view and the narrowest, on a
## 16:9 and a 16:10 window.

const SEAT := 4
const WIDTH := FirstPersonArms.KEEP_CLEAR_WIDTH
const VIEWS: Array[Vector2] = [
	Vector2(WIDTH, WIDTH * 9.0 / 16.0), Vector2(WIDTH, WIDTH * 10.0 / 16.0)
]
## Along each arm, elbow to fingertips: the bones whose heads mark it.
const JOINTS := {
	&"L": [&"DEF-forearm.L", &"DEF-hand.L", &"DEF-f_middle.01.L", &"DEF-f_middle.03.L"],
	&"R": [&"DEF-forearm.R", &"DEF-hand.R", &"DEF-f_middle.01.R", &"DEF-f_middle.03.R"],
}
const THUMBS: Array[StringName] = [&"DEF-thumb.03.L", &"DEF-thumb.03.R"]
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
		for size: Vector2 in VIEWS:
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
	for move: BrawlerAnimation.Move in FirstPersonArms.POSES:
		var entry := _as(move)
		var watched := 0.0
		while watched < SETTLE + WATCH:
			_arms.show_seat(SEAT, entry, entry, 1.0)
			if watched >= SETTLE:
				_check(move, problems)
			await get_tree().process_frame
			watched += _arms.get_process_delta_time()
	assert_eq(problems.size(), 0, "\n".join(PackedStringArray(problems.values())))


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
		var crosshair := Rect2(
			size * 0.5 - FirstPersonArms.CROSSHAIR_CLEAR, FirstPersonArms.CROSSHAIR_CLEAR * 2.0
		)
		var readouts := FirstPersonArms.READOUTS_CLEAR
		readouts.position.y += size.y
		for offset: Vector3 in [
			Vector3.ZERO, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN
		]:
			var at := _pixel(_lenses[view], size, point + offset * radius)
			for zone: Rect2 in [crosshair, readouts]:
				var key := "%s %s %s" % [BrawlerAnimation.Move.keys()[move], bone, _labels[view]]
				if zone.has_point(at) and not problems.has(key):
					problems[key] = "%s at %s" % [key, at.round()]


## Where [param point], in the eye's space, is drawn on a window of [param size]
## through [param lens].
func _pixel(lens: Projection, size: Vector2, point: Vector3) -> Vector2:
	var clip := lens * Vector4(point.x, point.y, point.z, 1.0)
	var ndc := Vector2(clip.x, clip.y) / clip.w
	return Vector2((ndc.x * 0.5 + 0.5) * size.x, (0.5 - ndc.y * 0.5) * size.y)
