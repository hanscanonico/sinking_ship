extends GutTest

const STEAMER := "res://data/ships/steamer.tres"
const RULES := "res://data/rules/brawl.tres"
const RAILING_HEIGHT := 1.0
## How near upright a face must turn to read as floor (art-lint's FLOOR_FACING).
const FLOOR_FACING := 0.7

var _layout: ShipLayout
var _space: ShipSpace
var _hull: ShipHull


func before_each() -> void:
	_layout = load(STEAMER)
	_space = ShipSpace.new(_layout)
	_hull = ShipHull.new(_space, RAILING_HEIGHT)


func test_the_hull_never_stands_wider_than_the_deck_edge_over_it() -> void:
	var x := -20.0
	while x <= 20.0:
		var shape := _space.envelope(x)
		if shape.x != INF:
			for side in 2:
				var edge := -shape.x if side == 0 else shape.y
				var deck := shape.z if side == 0 else shape.w
				var y := deck
				while y > -6.0:
					assert_true(
						_hull.breadth(x, y, side) <= edge + 0.0001,
						"side %d at x %.2f, y %.2f inside the edge %.2f" % [side, x, y, edge]
					)
					y -= 0.25
		x += 0.37


func test_the_hull_stands_clear_of_every_wall_under_the_sheer() -> void:
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX or blocker.top > 0.0 + 0.001:
			continue
		var area := blocker.area
		for x: float in [area.position.x + 0.05, area.end.x - 0.05]:
			for y: float in [blocker.bottom, blocker.top - 0.1]:
				assert_true(
					_hull.breadth(x, y, 0) >= -area.position.y,
					"port clear of the blocker at x %.2f, y %.2f" % [x, y]
				)
				assert_true(
					_hull.breadth(x, y, 1) >= area.end.y,
					"starboard clear of the blocker at x %.2f, y %.2f" % [x, y]
				)


func test_past_the_forecastle_the_bow_falls_away_to_a_stem() -> void:
	var fore := 20.0
	var deck := 1.8
	assert_almost_eq(_hull.breadth(fore - 0.01, deck, 1), 4.0, 0.001, "full at the deck's end")
	assert_almost_eq(_hull.breadth(fore + 0.3, deck - 0.1, 1), 0.0, 0.001, "none past it up here")
	assert_true(_hull.breadth(fore + 1.0, deck - 3.0, 1) > 0.5, "further out lower down")
	assert_almost_eq(_hull.breadth(fore + 4.0, deck - 3.0, 1), 0.0, 0.001, "closed at the stem")


func test_no_drawn_point_of_the_hull_stands_outboard_of_the_deck_edge_over_it() -> void:
	var span := _span()
	var outboard := 0
	var first := ""
	for point: Vector3 in _drawn_hull():
		var x := clampf(point.x, span.x + 0.01, span.y - 0.01)
		var edge := 0.0
		# Where the decks' outline steps, the point may stand under either side of it.
		for at: float in [x - 0.01, x + 0.01]:
			var shape := _space.envelope(at)
			if shape.x != INF:
				edge = maxf(edge, -shape.x if point.z < 0.0 else shape.y)
		if absf(point.z) > edge + 0.001:
			outboard += 1
			if first.is_empty():
				first = "%s outside the edge %.2f" % [point, edge]
	assert_eq(outboard, 0, "no drawn point outboard of the deck edge; first: %s" % first)


func test_nothing_drawn_past_the_end_railings_turns_up_within_reach() -> void:
	var rules: BrawlRules = load(RULES)
	var span := _span()
	var fore := _space.envelope(span.y - 0.01)
	var aft := _space.envelope(span.x + 0.01)
	var faces := _drawn_hull()
	var floors := 0
	var first := ""
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var middle := (a + b + c) / 3.0
		if middle.x >= span.x and middle.x <= span.y:
			continue
		var past := fore if middle.x > span.y else aft
		var deck := maxf(past.z, past.w)
		if middle.y < deck - rules.step_height or middle.y > deck + rules.body_height:
			continue
		# Godot's front faces wind clockwise: their normal is the cross reversed.
		if -(b - a).cross(c - a).normalized().y > FLOOR_FACING:
			floors += 1
			if first.is_empty():
				first = "%s over a deck at %.2f" % [middle, deck]
	assert_eq(floors, 0, "no face past an end railing turned up as floor; first: %s" % first)


func test_a_deck_edge_on_the_hull_is_left_to_the_hull() -> void:
	for index in _layout.platforms.size():
		var platform := _layout.platforms[index]
		var hidden := _hull.hidden_faces(platform)
		match platform.name:
			&"forecastle":
				var hull_side := ShipMesh.NEG_Z | ShipMesh.POS_Z | ShipMesh.POS_X
				assert_eq(hidden, hull_side, "its sides and its end, not its break over the deck")
			&"boat deck":
				assert_eq(hidden, 0, "the boat deck stands clear of the hull")


## The decks' x range.
func _span() -> Vector2:
	var span := Vector2(INF, -INF)
	for platform: ShipPlatform in _layout.platforms:
		span = Vector2(minf(span.x, platform.area.position.x), maxf(span.y, platform.area.end.x))
	return span


## The corners of every triangle ShipHull draws, three by three.
func _drawn_hull() -> PackedVector3Array:
	var mesh := ShipMesh.new(_space.outdoors, _space.room_lines())
	_hull.build(mesh)
	var node: Node3D = autofree(Node3D.new())
	var paints := {}
	for finish: int in ShipMesh.Finish.values():
		paints[finish] = null
	mesh.commit(node, paints)
	var faces := PackedVector3Array()
	for part: Node in node.get_children():
		faces.append_array((part as MeshInstance3D).mesh.get_faces())
	return faces
