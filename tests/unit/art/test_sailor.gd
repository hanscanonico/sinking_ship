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
## Each coat's own arms (FirstPersonArms), as modelled: sleeves, cuffs and hands
## finer than a body drawn eight times over can afford, drawn once, under the eye,
## and at most ARMS_BUDGET.
const ARMS_TRIANGLES := {
	Brawler.Coat.JERSEY: 3324,
	Brawler.Coat.JACKET: 3692,
	Brawler.Coat.GREATCOAT: 3580,
}
const ARMS_BUDGET := 4000
const SEATS := 8
const MATCH_TRIANGLES := 3450 * SEATS
## The crown the clothes shader paints the face under, in model units.
const CROWN := 1.83
const NEAR := 0.01
## Where every hat (assets/characters/sailor/gen_hats.py) sits, in the head bone's
## space: its band starts this far up the head, and the narrowest band — the bare
## head's hair, the topper's — is this far across from the middle, in model units.
const HAT_BAND := 0.165
const HAT_HALF_WIDTH := 0.092
## Each hat as modelled, in triangles: rigid on the head bone, never skinned, and at
## most HAT_BUDGET apiece, so a full match's eight hats cost under 2,400.
const HAT_TRIANGLES := {
	Brawler.Hat.CAP: 268,
	Brawler.Hat.SOUWESTER: 272,
	Brawler.Hat.BOATER: 252,
	Brawler.Hat.BARE: 144,
	Brawler.Hat.BOBBLE: 292,
	Brawler.Hat.TOP: 272,
	Brawler.Hat.PEAKED: 276,
}
const HAT_BUDGET := 300
## The clothes shader, which colours a piece by its part code, and the script that
## numbers the parts the outfits and hats are written in.
const CLOTHES_SHADER := "res://scenes/art/brawler.gdshader"
const PART_NUMBERS := "res://assets/characters/sailor/gen_sailor.py"
## How far off a whole number a part code may read: the importer packs UVs into 16
## bits.
const PART_SLACK := 0.01


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
			var arms := brawler.find_child(String(Brawler.ARMS[other]), true, false)
			assert_null(arms, "seat %d drops the %s" % [seat, Brawler.ARMS[other]])
		total += _triangles(body.mesh)
	assert_lte(total, MATCH_TRIANGLES)


func test_each_coats_own_arms_keep_to_their_triangle_budget() -> void:
	for coat: Brawler.Coat in ARMS_TRIANGLES:
		var arms := Brawler.own_arms(coat)
		var named := String(Brawler.ARMS[coat])
		assert_eq(arms.mesh.get_surface_count(), 1, "one surface")
		assert_eq(_triangles(arms.mesh), ARMS_TRIANGLES[coat], named)
		assert_lte(_triangles(arms.mesh), ARMS_BUDGET, named)
		arms.free()


func test_a_seats_own_arms_are_its_coats_in_its_colour() -> void:
	for seat in SEATS:
		var brawler := Brawler.new()
		add_child_autofree(brawler)
		brawler.setup(seat, SimFixtures.rules(), false)
		brawler.show_as_own_arms(
			BrawlerAnimation.CLIPS, FirstPersonArms.POSES, FirstPersonArms.ELBOWS
		)
		var coat := Brawler.COATS[seat % Brawler.COATS.size()]
		var arms := Brawler.own_arms(coat)
		var drawn := brawler.find_children("*", "MeshInstance3D", true, false).filter(
			func(node: MeshInstance3D) -> bool: return node.visible and node.skin != null
		)
		assert_eq(drawn.size(), 1, "seat %d draws its arms alone" % seat)
		var body: MeshInstance3D = drawn[0]
		assert_eq(body.mesh, arms.mesh, "seat %d's arms are its %s's" % [seat, Brawler.ARMS[coat]])
		var clothes := body.get_surface_override_material(0) as ShaderMaterial
		assert_eq(clothes.get_shader_parameter("coat"), ArtPalette.seat_colour(seat))
		arms.free()


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


func test_each_hat_keeps_to_its_triangle_budget() -> void:
	assert_eq(HAT_TRIANGLES.size(), Brawler.Hat.size(), "every hat pinned")
	for hat: Brawler.Hat in HAT_TRIANGLES:
		var mesh := Brawler.hat_mesh(hat)
		assert_eq(mesh.get_surface_count(), 1, "one surface")
		assert_lte(_triangles(mesh), HAT_TRIANGLES[hat], String(Brawler.HAT_MESHES[hat]))
		assert_lte(HAT_TRIANGLES[hat], HAT_BUDGET, String(Brawler.HAT_MESHES[hat]))


func test_each_seat_wears_its_hat_in_its_clothes() -> void:
	for seat in SEATS:
		var brawler := Brawler.new()
		add_child_autofree(brawler)
		brawler.setup(seat, SimFixtures.rules(), false)
		var body: MeshInstance3D = brawler.find_child(Brawler.BODY, true, false)
		var hat: MeshInstance3D = brawler.find_child("Hat", true, false)
		assert_eq(hat.mesh, Brawler.hat_mesh(Brawler.HATS[seat]), "seat %d's hat" % seat)
		assert_eq(hat.material_override, body.get_surface_override_material(0), "its clothes")


func test_the_shader_numbers_the_parts_as_the_generator_does() -> void:
	var shader := RegEx.create_from_string("const int PART_(\\w+) = (\\d+);")
	var numbered := {}
	for found: RegExMatch in shader.search_all(FileAccess.get_file_as_string(CLOTHES_SHADER)):
		numbered[found.get_string(1)] = found.get_string(2).to_int()
	var parts := RegEx.create_from_string("(?m)^(BODY(?:, \\w+)*) = range\\(\\d+\\)$")
	var written := parts.search(FileAccess.get_file_as_string(PART_NUMBERS))
	assert_not_null(written, "gen_sailor.py numbers its parts")
	if written == null:
		return
	var expected := {}
	for part: String in written.get_string(1).split(", "):
		expected[part] = expected.size()
	assert_eq(numbered, expected, "brawler.gdshader's PART_ as gen_sailor.py numbers them")
	for hat: Brawler.Hat in Brawler.Hat.values():
		var unknown := 0
		var depth: PackedVector2Array = Brawler.hat_mesh(hat).surface_get_arrays(0)[
			Mesh.ARRAY_TEX_UV2
		]
		for point: Vector2 in depth:
			var part := roundi(point.y)
			if (
				absf(point.y - part) > PART_SLACK
				or part <= numbered["BODY"]
				or part >= numbered.size()
			):
				unknown += 1
		assert_eq(unknown, 0, "%s: a piece of clothing the shader knows" % Brawler.HAT_MESHES[hat])


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
