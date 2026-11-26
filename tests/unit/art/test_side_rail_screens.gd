extends GutTest
## A flight's side rail hung a little under a deck's edge (tools/flight_rails.py,
## SCREEN_REACH) hangs from that deck, a screen up to it, not a box floating in the air:
## the steamer's inner stair's two, a hand's breadth tall under the main deck's edge,
## read as two loose boxes in her engine room (2026-11-26).

const RunMatch := preload("res://tools/run_match.gd")
const STEAMER := "res://data/ships/steamer.tres"
const INNER_STAIR := "Blocker_side_inner_stair_"
const MAIN_DECK := 0.0


func test_the_inner_stair_s_side_rails_reach_up_to_the_main_deck() -> void:
	var rails := _inner_stair_rails(load(STEAMER))
	assert_eq(rails.size(), 2, "one hung each side of the inner stair")
	for rail: ShipBlocker in rails:
		var id := rail.resource_scene_unique_id
		assert_almost_eq(rail.top, MAIN_DECK, 0.0001, "%s up to the deck" % id)
		assert_gt(rail.bottom, -1.0, "%s still hung a body's height over the gallery" % id)


func test_they_are_drawn_up_to_the_deck_s_underside() -> void:
	var layout: ShipLayout = load(STEAMER)
	var rules: BrawlRules = RunMatch.default_config(1701).rules
	var art: ShipArt = autofree(ShipArt.new())
	art.build(layout, rules.railing_height, rules.body_radius)
	var corners := PackedVector3Array()
	for node: Node in art.find_children("*", "MeshInstance3D", true, false):
		var place := _to_art(art, node as Node3D)
		for corner: Vector3 in (node as MeshInstance3D).mesh.get_faces():
			corners.append(place * corner)
	for rail: ShipBlocker in _inner_stair_rails(layout):
		var plan := rail.area.grow(0.002)
		var highest := -INF
		for corner: Vector3 in corners:
			var inside := plan.has_point(Vector2(corner.x, corner.z))
			if inside and corner.y > rail.bottom - 0.01 and corner.y < MAIN_DECK:
				highest = maxf(highest, corner.y)
		var id := rail.resource_scene_unique_id
		assert_almost_eq(highest, MAIN_DECK - ShipArt.PLANK, 0.01, "%s drawn" % id)


static func _inner_stair_rails(layout: ShipLayout) -> Array[ShipBlocker]:
	var found: Array[ShipBlocker] = []
	for blocker: ShipBlocker in layout.blockers:
		if blocker.resource_scene_unique_id.begins_with(INNER_STAIR):
			found.append(blocker)
	return found


static func _to_art(art: Node3D, node: Node3D) -> Transform3D:
	var place := Transform3D.IDENTITY
	var at: Node = node
	while at != art and at != null:
		place = (at as Node3D).transform * place
		at = at.get_parent()
	return place
