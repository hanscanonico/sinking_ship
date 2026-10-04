extends GutTest

const MODEL := preload("res://assets/characters/quaternius_ual/AnimationLibrary_Godot_Standard.glb")
const CHEST := &"DEF-spine.003"
## Model units: a centimetre on the mannequin is about 0.011.
const NEAR := 0.011


func _skeleton() -> Skeleton3D:
	var model: Node3D = MODEL.instantiate()
	add_child_autofree(model)
	return model.get_node("Rig/Skeleton3D")


## [param skeleton] in [param pose] at once, over its rest.
func _posed(skeleton: Skeleton3D, pose: Dictionary) -> void:
	skeleton.reset_bone_poses()
	var poses := BrawlerPose.new(skeleton, {0: pose})
	poses.take(BrawlerPose.id(0, 0), 0.0)
	poses.apply(1.0)


func _origin(skeleton: Skeleton3D, bone: StringName) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func test_every_pose_names_only_what_a_pose_can_move() -> void:
	var known: Array[StringName] = BrawlerPose.BONES.duplicate()
	known.append_array([BrawlerPose.HIPS_AT, BrawlerPose.REACH_L, BrawlerPose.REACH_R])
	for table: Dictionary in [BrawlerAnimation.POSES, FirstPersonArms.POSES]:
		for move: int in table:
			var strokes: Array = table[move] if table[move] is Array else [table[move]]
			assert_lte(strokes.size(), BrawlerPose.MAX_STROKES)
			for pose: Dictionary in strokes:
				for key: StringName in pose:
					assert_has(known, key, "move %d names %s" % [move, key])


func test_a_reach_puts_the_wrist_where_the_chest_sends_it() -> void:
	var skeleton := _skeleton()
	var wrist := Vector3(-0.15, 0.3, 0.45)
	_posed(skeleton, {CHEST: Vector3(-20.0, 30.0, 0.0), BrawlerPose.REACH_R: wrist})
	var chest := skeleton.get_bone_global_pose(skeleton.find_bone(CHEST))
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(CHEST)).basis
	var turn := chest.basis.get_rotation_quaternion() * rest.get_rotation_quaternion().inverse()
	var reached := turn.inverse() * (_origin(skeleton, &"DEF-hand.R") - chest.origin)
	assert_almost_eq(reached, wrist, Vector3.ONE * NEAR)


func test_a_foot_stands_where_the_pose_steps_it_with_the_hips_lowered() -> void:
	var skeleton := _skeleton()
	var rest_ankle := skeleton.get_bone_global_rest(skeleton.find_bone(&"DEF-foot.L")).origin
	var step := Vector3(0.05, 0.0, 0.25)
	_posed(skeleton, {BrawlerPose.HIPS_AT: Vector3(0.0, -0.1, 0.0), &"DEF-foot.L": step})
	assert_almost_eq(_origin(skeleton, &"DEF-foot.L"), rest_ankle + step, Vector3.ONE * NEAR)
