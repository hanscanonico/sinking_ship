extends GutTest
## The water's rings are drawn round the bodies in water nearest the eye (MatchView.waders).


func test_a_dry_body_leaves_no_ring() -> void:
	var feet := PackedVector3Array([Vector3(1.0, 0.5, 0.0), Vector3(2.0, -0.3, 0.0)])
	var water := PackedFloat32Array([0.0, 0.0])
	var found := MatchView.waders(feet, water, PackedFloat32Array([0.5, 0.5]), Vector3.ZERO, 8)
	assert_eq(found.size(), 1, "only the body under the water")
	assert_eq(found[0], Vector4(2.0, 0.0, 0.0, 0.5), "on the water over its feet")


func test_a_body_with_its_feet_on_the_waterline_is_dry() -> void:
	var feet := PackedVector3Array([Vector3(0.0, -2.0, 0.0)])
	var water := PackedFloat32Array([-2.0])
	var found := MatchView.waders(feet, water, PackedFloat32Array([1.0]), Vector3.ZERO, 8)
	assert_eq(found.size(), 0)


func test_its_ring_stands_on_the_water_it_is_in() -> void:
	var feet := PackedVector3Array([Vector3(3.0, -2.6, 4.0)])
	var water := PackedFloat32Array([-2.25])
	var found := MatchView.waders(feet, water, PackedFloat32Array([0.0]), Vector3.ZERO, 8)
	assert_eq(found[0], Vector4(3.0, -2.25, 4.0, 0.0))


func test_the_nearest_to_the_eye_are_kept_nearest_first() -> void:
	var feet := PackedVector3Array()
	var water := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	for index in 10:
		feet.append(Vector3(10.0 - index, -0.5, 0.0))
		water.append(0.0)
		speeds.append(0.5)
	var found := MatchView.waders(feet, water, speeds, Vector3.ZERO, 8)
	assert_eq(found.size(), 8, "no more than asked for")
	for at in found.size():
		assert_eq(found[at].x, 1.0 + at, "the %dth nearest" % at)


func test_fewer_kept_when_fewer_asked_for() -> void:
	var feet := PackedVector3Array([Vector3(5.0, -1.0, 0.0), Vector3(1.0, -1.0, 0.0)])
	var water := PackedFloat32Array([0.0, 0.0])
	var eye := Vector3(6.0, 1.0, 0.0)
	var found := MatchView.waders(feet, water, PackedFloat32Array([0.0, 0.0]), eye, 1)
	assert_eq(found.size(), 1)
	assert_eq(found[0].x, 5.0, "the one by the eye")


func test_its_speed_is_clamped_to_a_share() -> void:
	var feet := PackedVector3Array([Vector3(1.0, -1.0, 0.0), Vector3(2.0, -1.0, 0.0)])
	var water := PackedFloat32Array([0.0, 0.0])
	var found := MatchView.waders(feet, water, PackedFloat32Array([3.5, -1.0]), Vector3.ZERO, 8)
	assert_eq(found[0].w, 1.0, "no faster than flat out")
	assert_eq(found[1].w, 0.0, "no slower than still")
