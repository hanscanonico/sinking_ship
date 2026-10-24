extends GutTest
## `make ship-scene` over a scene already drawn keeps its ids (ShipSceneIds): a redraw of
## unchanged data rewrites the file byte for byte, and a change diffs as only the nodes
## and sub-resources it adds, removes or alters.

const TUG := "res://data/ships/tug.tres"

var _dir := OS.get_temp_dir().path_join("ship_scene_ids_%d" % OS.get_process_id())
var _path := _dir.path_join("tug.tscn")


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	DirAccess.remove_absolute(_dir)


## The tug, a copy of her own that a test may change.
func _tug() -> ShipLayout:
	return ResourceLoader.load(TUG, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ShipLayout


## [param layout] drawn over the scene at the test's path; the text it leaves there.
func _draw(layout: ShipLayout) -> String:
	assert_eq(ShipSceneDraw.save(layout, "tug", _path), OK)
	return FileAccess.get_file_as_string(_path)


## The lines of [param after] that differ from [param before]'s, once the lines the two
## start and end with alike are set aside.
func _changed(before: String, after: String) -> Array[PackedStringArray]:
	var was := before.split("\n")
	var now := after.split("\n")
	var head := 0
	while head < mini(was.size(), now.size()) and was[head] == now[head]:
		head += 1
	var tail := 0
	while (
		tail < mini(was.size(), now.size()) - head
		and was[was.size() - 1 - tail] == now[now.size() - 1 - tail]
	):
		tail += 1
	return [was.slice(head, was.size() - tail), now.slice(head, now.size() - tail)]


## Every sub-resource id [param text] declares.
func _ids(text: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for found: RegExMatch in (
		RegEx.create_from_string('\\[sub_resource [^\\]]* id="([^"]*)"').search_all(text)
	):
		ids.append(found.get_string(1))
	return ids


func test_a_redraw_of_unchanged_data_is_the_same_bytes() -> void:
	var first := _draw(_tug())
	assert_eq(_draw(_tug()), first)


func test_a_redraw_keeps_the_scenes_line_endings() -> void:
	var crlf := _draw(_tug()).replace("\n", "\r\n")
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(crlf)
	file.close()
	assert_eq(_draw(_tug()), crlf)


func test_a_moved_blocker_changes_only_its_own_lines() -> void:
	var before := _draw(_tug())
	var tug := _tug()
	tug.blockers[0].area.position.x += 1.0
	var changed := _changed(before, _draw(tug))
	assert_eq(changed[0].size(), 1, "one line of the old scene differs: %s" % [changed[0]])
	assert_eq(changed[1].size(), 1, "one line of the new scene differs: %s" % [changed[1]])
	assert_true(changed[1][0].begins_with("transform = "), changed[1][0])


func test_an_added_blocker_is_only_its_own_lines() -> void:
	var before := _draw(_tug())
	var tug := _tug()
	var blocker := ShipBlocker.new()
	blocker.area = Rect2(0, -0.5, 1, 1)
	blocker.bottom = 0.0
	blocker.top = 1.0
	tug.blockers.append(blocker)
	var changed := _changed(before, _draw(tug))
	assert_eq(changed[0].size(), 0, "nothing of the old scene is gone: %s" % [changed[0]])
	var headers := Array(changed[1]).filter(
		func(line: String) -> bool: return line.begins_with("[")
	)
	assert_eq(headers.size(), 1, "one section is added: %s" % [changed[1]])
	assert_string_contains(headers[0], 'name="Blocker_%d"' % (tug.blockers.size() - 1))


func test_a_changed_sub_resource_gets_a_new_id_and_the_rest_keep_theirs() -> void:
	var before := _draw(_tug())
	var tug := _tug()
	tug.ramps[0].end_height += 0.5
	var after := _draw(tug)
	var was := _ids(before)
	var now := _ids(after)
	var gone := Array(was).filter(func(id: String) -> bool: return not id in now)
	var added := Array(now).filter(func(id: String) -> bool: return not id in was)
	assert_eq(gone.size(), 1, "one old sub-resource is gone: %s" % [gone])
	assert_eq(added.size(), 1, "one sub-resource is new: %s" % [added])
	assert_true(gone[0].begins_with("PrismMesh_"), gone[0])
	assert_true(added[0].begins_with("PrismMesh_"), added[0])
	assert_eq(now.size(), was.size())


func test_two_sub_resources_of_one_content_keep_the_ids_their_nodes_had() -> void:
	var old := (
		"\n"
		. join(
			[
				"[gd_scene format=3]",
				"",
				'[sub_resource type="PrismMesh" id="PrismMesh_a"]',
				"size = Vector3(1, 1, 1)",
				"",
				'[sub_resource type="PrismMesh" id="PrismMesh_b"]',
				"size = Vector3(1, 1, 1)",
				"",
				'[node name="Ship" type="Node3D" unique_id=1]',
				"",
				'[node name="One" type="MeshInstance3D" parent="." unique_id=2]',
				'mesh = SubResource("PrismMesh_a")',
				"",
				'[node name="Two" type="MeshInstance3D" parent="." unique_id=3]',
				'mesh = SubResource("PrismMesh_b")',
				"",
			]
		)
	)
	var drawn := (
		"\n"
		. join(
			[
				"[gd_scene format=3]",
				"",
				'[sub_resource type="PrismMesh" id="PrismMesh_x"]',
				"size = Vector3(1, 1, 1)",
				"",
				'[sub_resource type="PrismMesh" id="PrismMesh_y"]',
				"size = Vector3(1, 1, 1)",
				"",
				'[node name="Ship" type="Node3D" unique_id=7]',
				"",
				'[node name="Two" type="MeshInstance3D" parent="." unique_id=8]',
				'mesh = SubResource("PrismMesh_x")',
				"",
				'[node name="One" type="MeshInstance3D" parent="." unique_id=9]',
				'mesh = SubResource("PrismMesh_y")',
				"",
			]
		)
	)
	var kept := ShipSceneIds.kept(old, drawn)
	assert_string_contains(kept, '[node name="Two" type="MeshInstance3D" parent="." unique_id=3]')
	assert_string_contains(
		kept,
		'unique_id=3]\nmesh = SubResource("PrismMesh_b")',
	)
	assert_string_contains(kept, 'unique_id=2]\nmesh = SubResource("PrismMesh_a")')
	assert_string_contains(kept, '[node name="Ship" type="Node3D" unique_id=1]')
