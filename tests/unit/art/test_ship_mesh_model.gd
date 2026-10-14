extends GutTest
## ShipMesh.model(): a modelled prop's faces go into the dressed ship's batches as a
## procedural piece's do — by the paint each surface's material names, indoors or out,
## chunked, inked at its rims where the model's ink layer says.


## A fixture model: per paint of [param paints], a metre square facing up, the next
## half a metre over the last, inked 1 at its first corner and 0 at the others — or
## with no ink layer when [param inked] is false.
func _model(paints: Array[String], inked := true) -> ShipModel:
	var mesh := ArrayMesh.new()
	mesh.resource_name = "fixture_boat"
	for index in paints.size():
		var y := index * 0.5
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
			[Vector3(0, y, 0), Vector3(1, y, 0), Vector3(0, y, 1), Vector3(1, y, 1)]
		)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(
			[Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
		)
		if inked:
			arrays[Mesh.ARRAY_COLOR] = PackedColorArray(
				[Color(1, 1, 1), Color(0, 0, 0), Color(0, 0, 0), Color(0, 0, 0)]
			)
		# Godot's front faces wind clockwise seen from the front: these face up.
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.resource_name = paints[index]
		mesh.surface_set_material(index, material)
	return ShipModel.new(mesh)


## [param mesh] committed under a fresh node: its mesh instances by name.
func _drawn(mesh: ShipMesh) -> Dictionary:
	var node := Node3D.new()
	add_child_autofree(node)
	var materials := {}
	for finish: int in ShipMesh.Finish.values():
		materials[finish] = StandardMaterial3D.new()
	mesh.commit(node, materials)
	var found := {}
	for child: Node in node.get_children():
		found[String(child.name)] = child
	return found


## A ship mesh with no rooms to cut its faces, outdoors everywhere unless
## [param outdoors] says otherwise.
func _ship_mesh(outdoors := true) -> ShipMesh:
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	return ShipMesh.new(func(_point: Vector3) -> bool: return outdoors, no_rooms)


func _arrays(instance: MeshInstance3D) -> Array:
	return instance.mesh.surface_get_arrays(0)


func test_each_surface_is_drawn_in_the_paint_its_material_names() -> void:
	var mesh := _ship_mesh()
	mesh.model(_model(["white", "deck"]), Transform3D.IDENTITY)
	var drawn := _drawn(mesh)
	var plain := "%d_out" % ShipMesh.Finish.PLAIN
	var deck := "%d_out" % ShipMesh.Finish.DECK
	var names := drawn.keys()
	names.sort()
	assert_eq_deep(names, [plain, deck])
	for key: String in [plain, deck]:
		var arrays := _arrays(drawn[key])
		assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 6, "two triangles")
	for colour: Color in _arrays(drawn[plain])[Mesh.ARRAY_COLOR]:
		assert_eq(colour, ArtPalette.HOUSE)
	for colour: Color in _arrays(drawn[deck])[Mesh.ARRAY_COLOR]:
		assert_eq(colour, ArtPalette.DECK)


func test_a_surface_s_paint_may_be_swapped_for_another() -> void:
	var mesh := _ship_mesh()
	var cabin := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, Color.RED)
	mesh.model(_model(["white", "blanket"]), Transform3D.IDENTITY, {ShipPaints.blanket: cabin})
	var colours := {}
	var plain: MeshInstance3D = _drawn(mesh)["%d_out" % ShipMesh.Finish.PLAIN]
	for colour: Color in _arrays(plain)[Mesh.ARRAY_COLOR]:
		colours[colour] = true
	assert_eq_deep(colours.keys(), [ArtPalette.HOUSE, Color.RED])


func test_an_outdoor_model_is_drawn_on_the_outdoor_layer_inked_where_its_ink_says() -> void:
	var mesh := _ship_mesh()
	mesh.model(_model(["white"]), Transform3D.IDENTITY)
	var drawn: MeshInstance3D = _drawn(mesh)["%d_out" % ShipMesh.Finish.PLAIN]
	assert_eq(drawn.layers, 1 << (ShipMesh.OUTDOOR_LAYER - 1))
	var arrays := _arrays(drawn)
	var rims := {}
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for index in points.size():
		rims[points[index]] = uv2s[index]
	assert_eq(rims[Vector3(0, 0, 0)], Vector2(1, 1), "the inked corner, outdoors")
	assert_eq(rims[Vector3(1, 0, 1)], Vector2(0, 1), "an uninked corner, outdoors")


func test_an_indoor_model_is_chunked_lit_by_lamps_alone_and_casts_no_shadow() -> void:
	var mesh := _ship_mesh(false)
	# Placed across the chunk line at x = CHUNK.x: the square's triangles centre a third
	# and two thirds along it, one each side of the line.
	var along := ShipMesh.CHUNK.x - 0.5
	mesh.model(_model(["wall"]), Transform3D(Basis.IDENTITY, Vector3(along, 0, 0)))
	var cabin := ShipMesh.Finish.CABIN
	var drawn := _drawn(mesh)
	var names := drawn.keys()
	names.sort()
	assert_eq_deep(names, ["%d_in_0_0_0" % cabin, "%d_in_1_0_0" % cabin])
	for instance: MeshInstance3D in drawn.values():
		assert_eq(instance.layers, 1, "on the layer lamps light")
		assert_eq(instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var arrays := _arrays(instance)
		assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 3, "one triangle each")
		for colour: Color in arrays[Mesh.ARRAY_COLOR]:
			assert_eq(colour, ArtPalette.CABIN, "a wall's paint inside")
		for uv2: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
			assert_eq(uv2.y, 0.0, "indoors")


func test_a_model_is_placed_turned_and_banded_over_its_own_foot_and_top() -> void:
	var mesh := _ship_mesh()
	# Half a turn about the vertical, standing on y = 2 at x = 10.
	var place := Transform3D(Basis(Vector3.UP, PI), Vector3(10, 2, 0))
	mesh.model(_model(["white", "teak"]), place)
	var arrays := _arrays(_drawn(mesh)["%d_out" % ShipMesh.Finish.PLAIN])
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bounds := AABB(points[0], Vector3.ZERO)
	for index in points.size():
		bounds = bounds.expand(points[index])
		var expected := (
			Vector2(0.0, 0.5) if is_equal_approx(points[index].y, 2.0) else Vector2(0.5, 0.0)
		)
		assert_almost_eq(
			uvs[index], expected, Vector2.ONE * 0.0001, "bands over 2 m and under 2.5 m"
		)
	assert_almost_eq(bounds.position, Vector3(9, 2, -1), Vector3.ONE * 0.0001)
	assert_almost_eq(bounds.end, Vector3(10, 2.5, 0), Vector3.ONE * 0.0001)
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(normal, Vector3.UP, Vector3.ONE * 0.0001)


func test_a_mirrored_model_still_faces_out() -> void:
	var mesh := _ship_mesh()
	mesh.model(_model(["white"]), Transform3D(Basis.from_scale(Vector3(1, 1, -1)), Vector3.ZERO))
	var arrays := _arrays(_drawn(mesh)["%d_out" % ShipMesh.Finish.PLAIN])
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in range(0, order.size(), 3):
		var a := points[order[index]]
		var b := points[order[index + 1]]
		var c := points[order[index + 2]]
		# Godot draws a face's front turning clockwise, so one facing up crosses down.
		assert_lt((b - a).cross(c - a).y, 0.0, "faces up")


func test_a_model_wholly_off_the_stretch_drawn_adds_nothing() -> void:
	var mesh := _ship_mesh()
	mesh.keep = Vector2(-5, 5)
	mesh.model(_model(["white"]), Transform3D(Basis.IDENTITY, Vector3(6, 0, 0)))
	assert_eq(_drawn(mesh).size(), 0, "aft end 1 m past the stretch's fore end")
	mesh.model(_model(["white"]), Transform3D(Basis.IDENTITY, Vector3(5, 0, 0)))
	assert_eq(_drawn(mesh).size(), 1, "straddling its fore end")


func test_a_model_wholly_over_the_cut_away_adds_nothing() -> void:
	var mesh := _ship_mesh()
	mesh.cut_above = 0.25
	mesh.model(_model(["white", "deck"]), Transform3D.IDENTITY)
	var drawn := _drawn(mesh)
	# The deck square, at 0.5 m, is cut.
	assert_eq_deep(drawn.keys(), ["%d_out" % ShipMesh.Finish.PLAIN])


func test_a_material_named_after_no_paint_is_an_error_naming_the_model_and_it() -> void:
	var mesh := _ship_mesh()
	mesh.model(_model(["white", "whte"]), Transform3D.IDENTITY)
	assert_push_error("model fixture_boat: surface 1's material whte names no paint")
	assert_eq(_drawn(mesh).size(), 0, "nothing of it drawn")


func test_a_model_without_its_ink_layer_is_an_error_naming_it() -> void:
	var mesh := _ship_mesh()
	mesh.model(_model(["white"], false), Transform3D.IDENTITY)
	assert_push_error("model fixture_boat: surface 0 has no ink layer")
	assert_eq(_drawn(mesh).size(), 0, "nothing of it drawn")


func test_a_model_without_triangles_is_an_error_naming_it() -> void:
	var mesh := _ship_mesh()
	var empty := ArrayMesh.new()
	empty.resource_name = "fixture_boat"
	mesh.model(ShipModel.new(empty), Transform3D.IDENTITY)
	assert_push_error("model fixture_boat has no triangles")
	assert_eq(_drawn(mesh).size(), 0)


func test_a_model_in_a_fading_mesh_fades_as_one_piece() -> void:
	var mesh := _ship_mesh()
	var pieces: Array[AABB] = []
	mesh.fading = func(piece: AABB) -> bool:
		pieces.append(piece)
		return true
	mesh.model(_model(["white", "deck"]), Transform3D(Basis.IDENTITY, Vector3(2, 1, 0)))
	assert_eq(pieces.size(), 1, "the whole model one piece")
	assert_almost_eq(pieces[0].position, Vector3(2, 1, 0), Vector3.ONE * 0.0001)
	assert_almost_eq(pieces[0].end, Vector3(3, 1.5, 1), Vector3.ONE * 0.0001)
	for instance: MeshInstance3D in _drawn(mesh).values():
		var custom: PackedFloat32Array = _arrays(instance)[Mesh.ARRAY_CUSTOM0]
		for index in range(0, custom.size(), 4):
			assert_eq(custom[index + 3], 1.0, "fades")
			assert_almost_eq(custom[index], 2.5, 0.0001, "about the model's middle")
