extends GutTest
## A deck the scenario collapses, as the dressed ship draws it (DeckWreck): whole
## until it falls, then broken on the floor beneath, within a step of it, inside the
## room it fell into and clear of its walls' fittings, the walls' tops torn but under
## the height the rules no longer have.

const RunMatch := preload("res://tools/run_match.gd")
const BRIDGE := &"bridge"

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace
var _bridge: ShipPlatform


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_space = ShipSpace.new(_layout)
	for platform: ShipPlatform in _layout.platforms:
		if platform.name == BRIDGE:
			_bridge = platform


func _art(fallen: float) -> ShipArt:
	var art: ShipArt = autofree(ShipArt.new())
	var falls: Array[StringName] = [BRIDGE]
	art.build(_layout, _rules.railing_height, _rules.body_radius, falls)
	art.show_sinking([], {BRIDGE: fallen}, PackedInt32Array(), false)
	return art


## Every corner of the faces shown under [param node], in the ship's space; lamps left
## out when [param lamps] is false.
func _shown(art: ShipArt, node: Node3D, lamps := false) -> PackedVector3Array:
	var points := PackedVector3Array()
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not _visible_up_to(mesh, art):
			continue
		var place := Transform3D.IDENTITY
		var at: Node = mesh
		var in_lamp := false
		while at != art:
			in_lamp = in_lamp or at is ShipLamp
			place = (at as Node3D).transform * place
			at = at.get_parent()
		if in_lamp and not lamps:
			continue
		for corner: Vector3 in mesh.mesh.get_faces():
			points.append(place * corner)
	return points


## Whether [param node] and every node over it up to [param top] is visible: what
## is_visible_in_tree() says, out of the tree.
func _visible_up_to(node: Node, top: Node) -> bool:
	var at := node
	while at != top:
		if not (at as Node3D).visible:
			return false
		at = at.get_parent()
	return true


func _deck(art: ShipArt) -> Node3D:
	return art.get_node("Deck%d" % _layout.platforms.find(_bridge))


func test_a_fallen_deck_lies_within_a_step_of_the_floor_beneath() -> void:
	var art := _art(1.0)
	var floor := _space.floor_beneath(_bridge)
	var points := _shown(art, _deck(art))
	assert_gt(points.size(), 0)
	var lowest := INF
	var highest := -INF
	for point: Vector3 in points:
		lowest = minf(lowest, point.y)
		highest = maxf(highest, point.y)
	assert_true(lowest >= floor - 0.005, "nothing through the floor: %.3f" % lowest)
	assert_true(
		highest <= floor + _rules.step_height + 0.005, "within a step: %.3f" % (highest - floor)
	)


func test_a_fallen_deck_lies_inside_its_room_clear_of_the_wheel_wall() -> void:
	var art := _art(1.0)
	var room := RoomDressing.room_at(
		_space, Vector3(-2.5, _space.floor_beneath(_bridge) + 1.0, 0.0)
	)
	var inside := _layout.rooms[room].area.grow(-0.1)
	# The wheel wall's fittings stand a binnacle's depth (0.1) off its face.
	var clear := inside.grow_individual(0.0, 0.0, -0.1, 0.0)
	for point: Vector3 in _shown(art, _deck(art)):
		assert_true(clear.has_point(Vector2(point.x, point.z)), "%s inside, clear" % point)
		if not clear.has_point(Vector2(point.x, point.z)):
			return


func test_whole_the_deck_still_shows_its_top_all_over_its_area() -> void:
	var art := _art(0.0)
	var points := _shown(art, _deck(art))
	var tops := PackedVector3Array()
	for index in range(0, points.size(), 3):
		var a := points[index]
		var b := points[index + 1]
		var c := points[index + 2]
		if is_equal_approx(a.y, _bridge.height) and is_equal_approx(b.y, _bridge.height):
			if is_equal_approx(c.y, _bridge.height):
				tops.append_array([a, b, c])
	var area := _bridge.area.grow(-0.05)
	for i in 7:
		for j in 7:
			var at := area.position + area.size * Vector2(i / 6.0, j / 6.0)
			var from := Vector3(at.x, _bridge.height + 1.0, at.y)
			var hit := false
			for index in range(0, tops.size(), 3):
				var found: Variant = Geometry3D.ray_intersects_triangle(
					from, Vector3.DOWN, tops[index], tops[index + 1], tops[index + 2]
				)
				hit = hit or found != null
			assert_true(hit, "the whole deck's top over %s" % at)


func test_the_torn_wall_tops_stay_under_the_fallen_deck_s_height() -> void:
	var art := _art(1.0)
	var torn := art.find_child("Torn", true, false) as Node3D
	assert_not_null(torn)
	var points := _shown(art, torn)
	assert_gt(points.size(), 0)
	for point: Vector3 in points:
		assert_true(point.y < _bridge.height - 0.02, "torn end at %s under the deck" % point)
		if point.y >= _bridge.height - 0.02:
			return


func test_whole_the_deck_shows_no_wreckage() -> void:
	var art := _art(0.0)
	assert_false((art.find_child("Torn", true, false) as Node3D).visible, "no torn ends yet")
	for node: Node in _deck(art).find_children("Splinters", "Node3D", true, false):
		assert_false((node as Node3D).visible, "no splinters while the deck stands")
	assert_false((_deck(art).find_child("Debris", true, false) as Node3D).visible, "no planks")


func test_the_wreckage_shows_once_the_deck_has_gone() -> void:
	var art := _art(1.0)
	assert_true((art.find_child("Torn", true, false) as Node3D).visible, "torn ends")
	assert_true((_deck(art).find_child("Debris", true, false) as Node3D).visible, "loose planks")
	assert_false((_deck(art).find_child("Rim", true, false) as Node3D).visible, "the rim gone")
