extends GutTest
## The breaks in the decks and the deckhouse's narrow cabins, as the dressed ship
## draws them: a break's face plated and painted as a house, never in the hull's
## dark, fitted with a cap rail; every cabin too narrow for furniture still dressed
## on its walls; a funnel passing through one cased in riveted steel.

const RunMatch := preload("res://tools/run_match.gd")
const FurnishingCheck := preload("res://tools/furnishing_check.gd")

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_space = ShipSpace.new(_layout)


func test_the_steamer_s_breaks_are_the_poop_s_and_the_forecastle_s_faces() -> void:
	var found := ShipFittings.breaks(_space)
	var poop := false
	var forecastle := false
	for face: Array in found:
		poop = poop or (is_equal_approx(face[0], -14.0) and is_equal_approx(face[4], 1.2))
		forecastle = (
			forecastle or (is_equal_approx(face[0], 12.0) and is_equal_approx(face[4], 1.8))
		)
		# A house front, with its room behind, is no break.
		assert_false(face[0] in [-7.0, 3.0, -4.0, -1.0], "no break at x %.1f" % face[0])
	assert_true(poop, "the poop's forward face")
	assert_true(forecastle, "the forecastle's after face")


func test_no_break_face_is_painted_in_the_hull_s_dark() -> void:
	var mesh := ShipMesh.new(_space.outdoors, _space.room_lines())
	ShipHull.new(_space, _rules.railing_height).build(mesh)
	var node: Node3D = autofree(Node3D.new())
	var paints := {}
	for finish: int in ShipMesh.Finish.values():
		paints[finish] = ShaderMaterial.new()
	mesh.commit(node, paints)
	var hull_faces := 0
	var house_faces := 0
	for part: Node in node.get_children():
		var finish: int = paints.find_key((part as MeshInstance3D).mesh.surface_get_material(0))
		var faces := (part as MeshInstance3D).mesh.get_faces()
		for index in range(0, faces.size(), 3):
			var middle := (faces[index] + faces[index + 1] + faces[index + 2]) / 3.0
			# The poop's forward face: from the main deck up to the poop, across it.
			if absf(middle.x + 14.0) > 0.02 or middle.y < 0.05 or middle.y > 1.15:
				continue
			if absf(middle.z) > 4.4:
				continue
			hull_faces += 1 if finish == ShipMesh.Finish.HULL else 0
			house_faces += 1 if finish == ShipMesh.Finish.HOUSE else 0
	assert_eq(hull_faces, 0, "none of the poop's face in the hull's paint")
	assert_gt(house_faces, 0, "the poop's face plated as a house")


func test_every_cabin_too_narrow_for_furniture_is_dressed_on_its_walls() -> void:
	var art: ShipArt = autofree(ShipArt.new())
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	var faces := FurnishingCheck.furnishings(art)
	var cuddies := 0
	for room: ShipRoom in _layout.rooms:
		if RoomDressing.kind_of(_space, room) != RoomDressing.Kind.CUDDY:
			continue
		cuddies += 1
		var inside := 0
		for index in range(0, faces.size(), 3):
			var middle := (faces[index] + faces[index + 1] + faces[index + 2]) / 3.0
			if room.area.has_point(Vector2(middle.x, middle.z)):
				inside += 1
		assert_gt(inside, 100, "%s dressed" % room.name)
	assert_eq(cuddies, 4, "the deckhouse's four cabins")


func test_a_funnel_through_a_cabin_is_cased_in_riveted_steel() -> void:
	assert_eq(ShipPaints.funnel.finish_in, ShipMesh.Finish.PLATE)
	assert_ne(ShipPaints.funnel.colour_in, ArtPalette.CABIN)
