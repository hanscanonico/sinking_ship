extends GutTest
## Her breakable railings packed as a match draws them (RailingBatches): each span's faces
## the very ones the unpacked art draws under its node, in a few shared meshes — indoors
## in its chunk's instance where they lie inside its box, outdoors on the outdoor layer —
## hidden as it breaks by its indices alone, and drawn again as it mends.

const RunMatch := preload("res://tools/run_match.gd")
const ShipFaces := preload("res://tools/ship_faces.gd")

var _layout: ShipLayout
var _rules: BrawlRules
var _loose: ShipArt
var _packed: ShipArt


func before_all() -> void:
	var config := RunMatch.default_config(1701, 0, &"small_titanic")
	_layout = config.ship
	_rules = config.rules
	_loose = _built(false)
	_packed = _built(true)


func after_all() -> void:
	_loose.free()
	_packed.free()


## Her art with every railing breakable, packed or not.
func _built(pack: bool) -> ShipArt:
	var art := ShipArt.new()
	art.rules = _rules
	art.pack = pack
	var none: Array[StringName] = []
	var every := PackedInt32Array(range(_layout.railings.size()))
	art.build(_layout, _rules.railing_height, _rules.body_radius, none, every)
	return art


## Per railing span, how many times each of its triangles is drawn, by its corners —
## those shown alone when [param shown].
func _triangles(art: ShipArt, shown := false) -> Dictionary:
	var spans := PackedInt32Array()
	var faces := ShipFaces.of(art, shown, spans)
	var found := {}
	for triangle in spans.size():
		if spans[triangle] < 0:
			continue
		var key := var_to_str(faces.slice(triangle * 3, triangle * 3 + 3))
		var own: Dictionary = found.get(spans[triangle], {})
		own[key] = own.get(key, 0) + 1
		found[spans[triangle]] = own
	return found


## Per railing span, how many times each of its triangles is drawn, by its corners as
## its arrays hold them: under its node ("Railing<n>"), or as RailingBatches has it.
func _drawn(art: ShipArt) -> Dictionary:
	var named := RegEx.create_from_string("^Railing(\\d+)$")
	var batched := art.railings()
	var found := {}
	for node: Node in art.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var spans := batched.spans_of(instance) if batched != null else PackedInt32Array()
		var named_as := named.search(instance.get_parent().name)
		var span := named_as.get_string(1).to_int() if named_as != null else -1
		if spans.is_empty() and span == -1:
			continue
		var triangle := 0
		var mesh := instance.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for first in range(0, indices.size(), 3):
				var of := spans[triangle] if not spans.is_empty() else span
				triangle += 1
				if of < 0:
					continue
				var corners := PackedVector3Array(
					[points[indices[first]], points[indices[first + 1]], points[indices[first + 2]]]
				)
				var own: Dictionary = found.get(of, {})
				own[var_to_str(corners)] = own.get(var_to_str(corners), 0) + 1
				found[of] = own
	return found


func test_every_span_draws_the_faces_it_drew_under_its_node() -> void:
	var loose := _drawn(_loose)
	var packed := _drawn(_packed)
	assert_gt(loose.size(), 10, "she has railings drawn")
	assert_eq(packed.keys().size(), loose.keys().size())
	for span: int in loose:
		assert_eq(packed.get(span, {}), loose[span], "span %d" % span)


func test_no_span_on_a_deck_that_stays_put_has_a_node_of_its_own() -> void:
	var batched := _packed.railings()
	var held := 0
	for span in _layout.railings.size():
		assert_null(_packed.find_child("Railing%d" % span, true, false), "span %d" % span)
		if batched.holds(span):
			held += 1
	assert_gt(held, 10)
	var loose := _loose.find_children("*", "MeshInstance3D", true, false).size()
	var packed := _packed.find_children("*", "MeshInstance3D", true, false).size()
	assert_lt(packed, loose - held / 2, "far fewer instances")


func test_its_surfaces_hold_16_bit_indices_and_outdoors_lie_on_the_outdoor_layer() -> void:
	var surfaces := 0
	var outdoors := 0
	for node: Node in _packed.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		for surface in mesh.get_surface_count() if mesh != null else 0:
			if mesh.surface_get_name(surface) != String(RailingBatches.SURFACE):
				continue
			surfaces += 1
			var count := mesh.surface_get_array_index_len(surface)
			var data := RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
			assert_eq((data["index_data"] as PackedByteArray).size(), count * 2, instance.name)
			assert_lte(mesh.surface_get_array_len(surface), RailingBatches.MOST_CORNERS)
		if String(instance.name).begins_with("Railings"):
			outdoors += 1
			assert_eq(instance.layers, 1 << (ShipMesh.OUTDOOR_LAYER - 1), instance.name)
	assert_gt(surfaces, 0)
	assert_gt(outdoors, 0)


func test_a_broken_span_draws_nothing_and_is_drawn_again_as_it_mends() -> void:
	var art := _built(true)
	add_child_autofree(art)
	var batched := art.railings()
	var whole := _triangles(art, true)
	var span: int = whole.keys()[whole.size() / 2]
	art.show_sinking([], {}, PackedInt32Array([span]), false)
	assert_false(batched.drawn(span), "broken")
	var broken := _triangles(art, true)
	assert_false(broken.has(span), "its faces drawn no more")
	for other: int in whole:
		if other != span:
			assert_eq(broken.get(other, {}), whole[other], "span %d still drawn" % other)
	var remains := art.find_child("Railing%dRemains" % span, true, false) as Node3D
	assert_not_null(remains, "its remains drawn")
	if remains != null:
		assert_true(remains.visible)
		assert_eq(remains.get_parent(), art, "on her, where the span stood")
	art.show_sinking([], {}, PackedInt32Array(), false)
	assert_true(batched.drawn(span), "mended")
	assert_eq(_triangles(art, true), whole, "drawn again")
	if remains != null:
		assert_false(remains.visible)


func test_a_broken_span_s_indices_all_name_one_corner() -> void:
	var indices := PackedInt32Array([7, 8, 9, 9, 8, 10])
	var shown := RailingBatches.index_bytes(indices, true)
	var hidden := RailingBatches.index_bytes(indices, false)
	assert_eq(shown.size(), 12)
	assert_eq(hidden.size(), 12)
	for index in indices.size():
		assert_eq(shown.decode_u16(index * 2), indices[index])
		assert_eq(hidden.decode_u16(index * 2), 7)


func test_spans_together_keep_where_each_one_s_triangles_lie() -> void:
	var none: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var batched := RailingBatches.new()
	var white := StandardMaterial3D.new()
	var teak := StandardMaterial3D.new()
	var paints := {ShipMesh.Finish.PLAIN: white, ShipMesh.Finish.DECK: teak}
	for span in 3:
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, none)
		var at := Rect2(span * 2.0, 0.0, 0.5, 0.5)
		mesh.box(at, 0.0, 1.0, ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, Color.WHITE))
		if span != 1:
			mesh.box(at, 1.0, 1.1, ShipMesh.Paint.new(ShipMesh.Finish.DECK, Color.BROWN))
		batched.add(span, mesh, paints)
	var parent := Node3D.new()
	batched.commit(parent)
	assert_eq(parent.get_child_count(), 1, "one instance outdoors")
	var instance := parent.get_child(0) as MeshInstance3D
	assert_eq(instance.mesh.get_surface_count(), 2, "a surface a paint")
	var spans := batched.spans_of(instance)
	var faces := instance.mesh.get_faces()
	assert_eq(spans.size(), faces.size() / 3)
	for triangle in spans.size():
		var span := spans[triangle]
		assert_between(faces[triangle * 3].x, span * 2.0 - 0.01, span * 2.0 + 0.51)
	for span in 3:
		assert_true(batched.holds(span))
		assert_true(batched.drawn(span))
	parent.free()
