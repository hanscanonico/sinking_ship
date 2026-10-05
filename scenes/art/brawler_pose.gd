class_name BrawlerPose
extends RefCounted
## A held pose laid over a brawler's clip, for the moves a clip cannot sell on its
## own (Brawler): the clip has just been advanced, and the pose crossfades in on
## top of it and back out to it. Presentation only — it reads nothing but the pose
## Brawler hands it.
##
## A pose is a Dictionary from bone name to Vector3, in the mannequin's model frame
## at rest (+z ahead, +x its left, +y up):
## - a trunk bone (hips, spine, neck, head): its turn from rest, Euler degrees;
## - an arm bone: the way it points, in the chest's frame, so a turned chest
##   carries the arms;
## - a foot: where the ankle stands on the deck, off its place at rest; the leg
##   reaches it, the knee bending ahead, and the foot lies flat;
## - REACH_L, REACH_R: where a wrist is, from the chest, in the chest's frame; the
##   arm reaches it, the elbow bending down and a little out;
## - HIPS_AT: where the hips are, off their place at rest.

const HIPS_AT := &"hips_at"
const REACH_L := &"reach.L"
const REACH_R := &"reach.R"
## The mannequin faces +z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const CHEST := &"DEF-spine.003"
const CHEST_SLOT := 3
## Every bone a pose may name, parents before children.
const BONES: Array[StringName] = [
	&"DEF-hips",
	&"DEF-spine.001",
	&"DEF-spine.002",
	&"DEF-spine.003",
	&"DEF-neck",
	&"DEF-head",
	&"DEF-upper_arm.L",
	&"DEF-forearm.L",
	&"DEF-hand.L",
	&"DEF-upper_arm.R",
	&"DEF-forearm.R",
	&"DEF-hand.R",
	&"DEF-thigh.L",
	&"DEF-shin.L",
	&"DEF-foot.L",
	&"DEF-thigh.R",
	&"DEF-shin.R",
	&"DEF-foot.R",
]
const ARMS: Array[StringName] = [
	&"DEF-upper_arm.L",
	&"DEF-forearm.L",
	&"DEF-hand.L",
	&"DEF-upper_arm.R",
	&"DEF-forearm.R",
	&"DEF-hand.R",
]
## Per limb, the slot in BONES of its upper bone (the lower bone and the hand or
## foot follow it), the key a pose reaches it with, and the way its middle joint
## bends unless told otherwise (an elbow down and a little out; a knee ahead).
const LIMBS: Array[int] = [6, 9, 12, 15]
const REACHES: Array[StringName] = [REACH_L, REACH_R, &"DEF-foot.L", &"DEF-foot.R"]
const ELBOWS: Array[Vector3] = [Vector3(0.35, -1.0, -0.3), Vector3(-0.35, -1.0, -0.3)]
const ARM_LIMBS := 2

## The most strokes one move's pose may step through.
const MAX_STROKES := 4

enum Kind { CLIP, TURN, AIM, LIMB }

var _skeleton: Skeleton3D
var _bones := PackedInt32Array()
var _parents := PackedInt32Array()
var _hips: int
var _root: int
## Each slot's bone at rest: its turn in the model, and the way it points.
var _rest_turn: Array[Quaternion] = []
var _rest_aim := PackedVector3Array()
var _rest_hips: Vector3
## The way each elbow bends as an arm reaches, in the chest's frame.
var _elbows: Array[Vector3]
## Per limb: the wrist or ankle at rest, and the upper and lower bones' lengths.
var _rest_end := PackedVector3Array()
var _upper := PackedFloat32Array()
var _lower := PackedFloat32Array()
## The chest as drawn now, turned off its rest and placed, which arms reach from.
var _chest_turn := Quaternion.IDENTITY
var _chest_at := Vector3.ZERO
## Every pose by its id, compiled: a Kind and a value per slot, and where the hips go.
var _kinds := {}
var _values := {}
var _hips_at := {}
var _strokes := {}
## What a crossfade back to the clip alone reads: every slot left to the clip.
var _clip_only := PackedByteArray()
var _no_values := PackedVector3Array()
## The pose shown now (-1 for the clip alone), and the moment its crossfade began.
var _pose := -1
var _seconds := 0.0
var _fade := 1.0
var _from: Array[Quaternion] = []
var _from_hips := Vector3.ZERO
var _shown: Array[Quaternion] = []
var _shown_hips := Vector3.ZERO


## Poses [param skeleton] with [param poses], a Dictionary from a move to its
## pose, or to the strokes of a pose it steps through, its reaching arms' elbows
## bending the ways [param elbows] has, left then right.
func _init(skeleton: Skeleton3D, poses: Dictionary, elbows: Array[Vector3] = ELBOWS) -> void:
	_skeleton = skeleton
	_elbows = elbows
	_hips = skeleton.find_bone(BONES[0])
	_root = skeleton.get_bone_parent(_hips)
	_rest_hips = skeleton.get_bone_global_rest(_hips).origin
	for name: StringName in BONES:
		var bone := skeleton.find_bone(name)
		var rest := skeleton.get_bone_global_rest(bone)
		_bones.append(bone)
		_parents.append(skeleton.get_bone_parent(bone))
		_rest_turn.append(rest.basis.get_rotation_quaternion())
		_rest_aim.append(rest.basis.y.normalized())
		_from.append(Quaternion.IDENTITY)
		_shown.append(Quaternion.IDENTITY)
	_clip_only.resize(BONES.size())
	_no_values.resize(BONES.size())
	for upper: int in LIMBS:
		var root := skeleton.get_bone_global_rest(_bones[upper]).origin
		var middle := skeleton.get_bone_global_rest(_bones[upper + 1]).origin
		var end := skeleton.get_bone_global_rest(_bones[upper + 2]).origin
		_rest_end.append(end)
		_upper.append(root.distance_to(middle))
		_lower.append(middle.distance_to(end))
	for move: int in poses:
		var strokes: Array = poses[move] if poses[move] is Array else [poses[move]]
		_strokes[move] = strokes.size()
		for stroke in strokes.size():
			_compile(id(move, stroke), strokes[stroke])


## The id of [param move]'s pose at [param stroke].
static func id(move: int, stroke: int) -> int:
	return move * MAX_STROKES + stroke


## How many strokes [param move]'s pose has: 0 when it has none.
func strokes(move: int) -> int:
	return _strokes.get(move, 0)


## Crossfades from what is shown now to the pose [param pose] (as id() names it, or
## -1 for the clip alone) over [param seconds]; asking again for the pose already
## shown changes nothing.
func take(pose: int, seconds: float) -> void:
	if pose == _pose:
		return
	_pose = pose
	_seconds = seconds
	_fade = 0.0
	for slot in _bones.size():
		_from[slot] = _shown[slot]
	_from_hips = _shown_hips


## Lays the pose over the clip the skeleton holds now, [param delta] seconds on.
func apply(delta: float) -> void:
	_fade = minf(_fade + delta / maxf(_seconds, 0.001), 1.0)
	var blend := 1.0 - (1.0 - _fade) * (1.0 - _fade)
	var clip_hips := _skeleton.get_bone_pose_position(_hips)
	if _pose < 0 and _fade >= 1.0:
		for slot in _bones.size():
			_shown[slot] = _skeleton.get_bone_pose_rotation(_bones[slot])
		_shown_hips = clip_hips
		return
	var posed := _kinds.has(_pose)
	var kinds: PackedByteArray = _kinds[_pose] if posed else _clip_only
	var values: PackedVector3Array = _values[_pose] if posed else _no_values
	var goal_hips := clip_hips
	if _hips_at.has(_pose):
		var root := _skeleton.get_bone_global_pose(_root)
		goal_hips = root.affine_inverse() * (_rest_hips + (_hips_at[_pose] as Vector3))
	_shown_hips = _from_hips.lerp(goal_hips, blend)
	_skeleton.set_bone_pose_position(_hips, _shown_hips)
	_chest_turn = Quaternion.IDENTITY
	for slot in _bones.size():
		var bone := _bones[slot]
		var goal := _skeleton.get_bone_pose_rotation(bone)
		var kind: int = kinds[slot]
		if kind != Kind.CLIP:
			var turn := _rest_turn[slot]
			match kind:
				Kind.TURN:
					turn = Quaternion.from_euler(values[slot] * (PI / 180.0)) * turn
				Kind.AIM:
					turn = _chest_turn * Quaternion(_rest_aim[slot], values[slot]) * turn
				Kind.LIMB:
					turn = Quaternion(_rest_aim[slot], _limb_aim(slot, values)) * turn
			goal = _turn(_parents[slot]).inverse() * turn
		_shown[slot] = _from[slot].slerp(goal, blend)
		_skeleton.set_bone_pose_rotation(bone, _shown[slot])
		if BONES[slot] == CHEST:
			var chest := _skeleton.get_bone_global_pose(bone)
			_chest_turn = chest.basis.get_rotation_quaternion() * _rest_turn[slot].inverse()
			_chest_at = chest.origin


## Where arm [param arm]'s shoulder (0 left, 1 right) is drawn now, in the
## skeleton's space.
func shoulder(arm: int) -> Vector3:
	return _skeleton.get_bone_global_pose(_bones[LIMBS[arm]]).origin


## Where arm [param arm]'s wrist (0 left, 1 right) is drawn now, in the skeleton's
## space.
func wrist(arm: int) -> Vector3:
	return _skeleton.get_bone_global_pose(_bones[LIMBS[arm] + 2]).origin


## Bends arm [param arm] (0 left, 1 right) over what the clip and the pose drew, so
## its wrist reaches [param to], in the skeleton's space, the elbow bending as a
## pose's reach bends it. The next apply() draws the arm afresh.
func reach_arm(arm: int, to: Vector3) -> void:
	var slot := LIMBS[arm]
	var chest := _turn(_bones[CHEST_SLOT]) * _rest_turn[CHEST_SLOT].inverse()
	var root := shoulder(arm)
	var middle := _bend(arm, root, to, chest * _elbows[arm])
	_aim(slot, middle - root)
	_aim(slot + 1, _end(arm, root, to) - middle)


## Turns the bone in [param slot] to point [param way], in the skeleton's space.
func _aim(slot: int, way: Vector3) -> void:
	var turn := Quaternion(_rest_aim[slot], way.normalized()) * _rest_turn[slot]
	_skeleton.set_bone_pose_rotation(_bones[slot], _turn(_parents[slot]).inverse() * turn)


func _turn(bone: int) -> Quaternion:
	return _skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()


## The way the limb bone in [param slot] points to reach where the pose's
## [param values] put its end: the upper and lower bones bent in the plane through
## the root, the end and the way the middle joint bends; a foot lies flat ahead as
## at rest.
func _limb_aim(slot: int, values: PackedVector3Array) -> Vector3:
	var limb := LIMBS.size() - 1
	while LIMBS[limb] > slot:
		limb -= 1
	var upper_slot := LIMBS[limb]
	if slot == upper_slot + 2:
		return _rest_aim[slot]
	var root := _skeleton.get_bone_global_pose(_bones[upper_slot]).origin
	var end := _rest_end[limb] + values[upper_slot]
	var pole := AHEAD
	if limb < ARM_LIMBS:
		end = _chest_at + _chest_turn * values[upper_slot]
		pole = _chest_turn * _elbows[limb]
	var middle := _bend(limb, root, end, pole)
	if slot == upper_slot:
		return (middle - root).normalized()
	return (_end(limb, root, end) - middle).normalized()


## Where limb [param limb]'s end stands reaching from [param root] toward
## [param end]: no further than the limb is long, nor nearer than it folds.
func _end(limb: int, root: Vector3, end: Vector3) -> Vector3:
	var shortest := absf(_upper[limb] - _lower[limb]) + 0.01
	var length := clampf(root.distance_to(end), shortest, (_upper[limb] + _lower[limb]) * 0.999)
	return root + (end - root).normalized() * length


## Where limb [param limb]'s middle joint stands as it reaches from [param root]
## toward [param end], bending toward [param pole]: the upper and lower bones in the
## plane through the three.
func _bend(limb: int, root: Vector3, end: Vector3, pole: Vector3) -> Vector3:
	var upper := _upper[limb]
	var lower := _lower[limb]
	var reached := _end(limb, root, end)
	var length := root.distance_to(reached)
	var along := (reached - root) / length
	var bend := (pole - along * along.dot(pole)).normalized()
	var cos_root := (upper * upper + length * length - lower * lower) / (2.0 * upper * length)
	var root_angle := acos(clampf(cos_root, -1.0, 1.0))
	return root + (along * cos(root_angle) + bend * sin(root_angle)) * upper


func _compile(key: int, pose: Dictionary) -> void:
	var kinds := PackedByteArray()
	var values := PackedVector3Array()
	kinds.resize(BONES.size())
	values.resize(BONES.size())
	for slot in BONES.size():
		var name := BONES[slot]
		if pose.has(name):
			kinds[slot] = Kind.AIM if name in ARMS else Kind.TURN
			values[slot] = pose[name]
			if kinds[slot] == Kind.AIM:
				values[slot] = values[slot].normalized()
	for limb in LIMBS.size():
		var upper := LIMBS[limb]
		if pose.has(REACHES[limb]):
			kinds[upper] = Kind.LIMB
			kinds[upper + 1] = Kind.LIMB
			if limb >= ARM_LIMBS:
				kinds[upper + 2] = Kind.LIMB
			values[upper] = pose[REACHES[limb]]
	_kinds[key] = kinds
	_values[key] = values
	if pose.has(HIPS_AT):
		_hips_at[key] = pose[HIPS_AT]
