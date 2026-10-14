extends GutTest
## The sailor every brawler wears (assets/characters/sailor): its own rig, standing
## where the clothes shader paints it, and a body cheap enough to draw a full match
## of: eight seats at once, each its body and its coat's skirt.

## Skinned triangles: the body as modelled, one seat as drawn with the longest
## skirt, and a full match's eight seats drawn at once.
const BODY_TRIANGLES := 2400
const SEAT_TRIANGLES := 2550
const SEATS := 8
const MATCH_TRIANGLES := SEAT_TRIANGLES * SEATS
## The crown the clothes shader paints the face under, in model units.
const CROWN := 1.83
const NEAR := 0.01


func _model() -> Node3D:
	var model: Node3D = Brawler.MODEL.instantiate()
	add_child_autofree(model)
	return model


func test_the_body_keeps_to_its_triangle_budget() -> void:
	var skeleton: Skeleton3D = _model().get_node("Rig/Skeleton3D")
	var body: MeshInstance3D = skeleton.get_node(Brawler.BODY)
	assert_eq(body.mesh.get_surface_count(), 1, "one surface")
	assert_lte(_triangles(body.mesh), BODY_TRIANGLES)


func test_a_full_match_of_seats_keeps_to_its_triangle_budget() -> void:
	var total := 0
	for seat in SEATS:
		var brawler := Brawler.new()
		add_child_autofree(brawler)
		brawler.setup(seat, SimFixtures.rules(), false)
		var body: MeshInstance3D = brawler.find_child("Sailor", true, false)
		var drawn := _triangles(body.mesh)
		assert_lte(drawn, SEAT_TRIANGLES, "seat %d" % seat)
		total += drawn
	assert_lte(total, MATCH_TRIANGLES)


func test_it_stands_from_the_soles_to_the_crown() -> void:
	var skeleton: Skeleton3D = _model().get_node("Rig/Skeleton3D")
	var box := (skeleton.get_node(Brawler.BODY) as MeshInstance3D).get_aabb()
	assert_almost_eq(box.position.y, 0.0, NEAR, "the soles on the deck")
	assert_almost_eq(box.end.y, CROWN, NEAR, "the crown")


func test_every_bone_a_pose_names_is_the_rigs_own() -> void:
	var skeleton: Skeleton3D = _model().get_node("Rig/Skeleton3D")
	var named: Array[StringName] = BrawlerPose.BONES.duplicate()
	named.append_array(Brawler.STEADY_ROWS.keys())
	named.append_array([Brawler.HEAD_BONE, BrawlerCharge.CHEST, FirstPersonArms.CHEST_BONE])
	named.append_array(BrawlerCharge.SHOULDERS)
	for bone: StringName in named:
		assert_ne(skeleton.find_bone(bone), -1, "the rig has %s" % bone)
	for bone in skeleton.get_bone_count():
		assert_false(skeleton.get_bone_name(bone).begins_with("DEF-"), "no borrowed bone names")


func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return count
