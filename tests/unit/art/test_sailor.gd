extends GutTest
## The sailor every brawler wears (assets/characters/sailor): its own rig, standing
## where the clothes shader paints it, and an outfit per coat cheap enough to draw a
## full match of: eight seats at once, each the one outfit it wears.

## Skinned triangles: each outfit as modelled — the body (2,320 of it, 800 of
## those the fingers and thumbs), its cloth and its skirt — and a full match's eight
## seats drawn at once, at most the greatcoat's apiece: up from 2,550 a seat when the
## clothes were painted on, for collars, cuffs, lapels, pockets, buttons and a skirt
## with a lining, and still under a quarter of the UAL mannequin's 13,744.
const OUTFIT_TRIANGLES := {
	Brawler.Coat.JERSEY: 2850,
	Brawler.Coat.JACKET: 3100,
	Brawler.Coat.GREATCOAT: 3450,
}
const SEATS := 8
const MATCH_TRIANGLES := 3450 * SEATS
## The crown the clothes shader paints the face under, in model units.
const CROWN := 1.83
const NEAR := 0.01
## Where every BrawlerHat sits, in the head bone's space: its band starts this far up
## the head, and the narrowest band — the bare head's hair, the topper's — is this
## far across from the middle, in model units.
const HAT_BAND := 0.165
const HAT_HALF_WIDTH := 0.092


func _model() -> Node3D:
	var model: Node3D = Brawler.MODEL.instantiate()
	add_child_autofree(model)
	return model


func test_each_outfit_keeps_to_its_triangle_budget() -> void:
	var skeleton: Skeleton3D = _model().get_node("Rig/Skeleton3D")
	for coat: Brawler.Coat in OUTFIT_TRIANGLES:
		var body: MeshInstance3D = skeleton.get_node(Brawler.OUTFITS[coat])
		assert_eq(body.mesh.get_surface_count(), 1, "one surface")
		assert_lte(_triangles(body.mesh), OUTFIT_TRIANGLES[coat], String(Brawler.OUTFITS[coat]))


func test_a_full_match_of_seats_keeps_to_its_triangle_budget() -> void:
	var total := 0
	for seat in SEATS:
		var brawler := Brawler.new()
		add_child_autofree(brawler)
		brawler.setup(seat, SimFixtures.rules(), false)
		var bodies := brawler.find_children("*", "MeshInstance3D", true, false)
		var body: MeshInstance3D = brawler.find_child(Brawler.BODY, true, false)
		var coat := Brawler.COATS[seat % Brawler.COATS.size()]
		assert_eq(bodies.count(body), 1, "seat %d draws its outfit" % seat)
		assert_eq(body.mesh, _outfit(coat).mesh, "seat %d wears its coat" % seat)
		for other: Brawler.Coat in OUTFIT_TRIANGLES:
			var dropped := brawler.find_child(String(Brawler.OUTFITS[other]), true, false)
			assert_null(dropped, "seat %d drops the %s" % [seat, Brawler.OUTFITS[other]])
		total += _triangles(body.mesh)
	assert_lte(total, MATCH_TRIANGLES)


func test_every_outfit_stands_from_the_soles_to_the_crown() -> void:
	for coat: Brawler.Coat in OUTFIT_TRIANGLES:
		var box := _outfit(coat).get_aabb()
		assert_almost_eq(box.position.y, 0.0, NEAR, "the soles on the deck")
		assert_almost_eq(box.end.y, CROWN, NEAR, "the crown")


func test_the_head_fits_under_every_hat() -> void:
	var skeleton: Skeleton3D = _model().get_node("Rig/Skeleton3D")
	var head := skeleton.get_bone_global_rest(skeleton.find_bone(Brawler.HEAD_BONE)).origin
	for coat: Brawler.Coat in OUTFIT_TRIANGLES:
		var widest := 0.0
		for point: Vector3 in _outfit(coat).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if point.y >= head.y + HAT_BAND:
				widest = maxf(widest, absf(point.x - head.x))
		assert_gt(widest, 0.0, "the head reaches the hat band")
		assert_lte(widest, HAT_HALF_WIDTH, "the head under the hat band, across")


func test_the_coat_takes_the_seats_colour() -> void:
	for seat in SEATS:
		var brawler := Brawler.new()
		add_child_autofree(brawler)
		brawler.setup(seat, SimFixtures.rules(), false)
		var body: MeshInstance3D = brawler.find_child(Brawler.BODY, true, false)
		var clothes := body.get_surface_override_material(0) as ShaderMaterial
		assert_eq(clothes.get_shader_parameter("coat"), ArtPalette.seat_colour(seat))


func test_every_bone_a_pose_names_is_the_rigs_own() -> void:
	var skeleton: Skeleton3D = _model().get_node("Rig/Skeleton3D")
	var named: Array[StringName] = BrawlerPose.BONES.duplicate()
	named.append_array([Brawler.HEAD_BONE, BrawlerCharge.CHEST, FirstPersonArms.CHEST_BONE])
	named.append_array(BrawlerCharge.SHOULDERS)
	for bone: StringName in named:
		assert_ne(skeleton.find_bone(bone), -1, "the rig has %s" % bone)
	for bone in skeleton.get_bone_count():
		assert_false(skeleton.get_bone_name(bone).begins_with("DEF-"), "no borrowed bone names")


## The sailor dressed in [param coat]'s outfit, as modelled.
func _outfit(coat: Brawler.Coat) -> MeshInstance3D:
	var skeleton: Skeleton3D = _model().get_node("Rig/Skeleton3D")
	return skeleton.get_node(Brawler.OUTFITS[coat])


func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return count
