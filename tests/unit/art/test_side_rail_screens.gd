extends GutTest
## A flight's side rail hung a little under a deck's edge (tools/flight_rails.py) is drawn
## up to the deck's underside, a screen from its edge, not a box floating in the air: the
## steamer's inner stair's two, a hand's breadth tall, read as two loose boxes (2026-11-26).

const RunMatch := preload("res://tools/run_match.gd")
const STEAMER :="res://data/ships/steamer.tres"
const INNER_STAIR := "Blocker_side_inner_stair_"


func test_the_underside_over_a_rail_is_the_deck_s_within_reach_and_none_past_it() -> void:
	var layout: ShipLayout = load(STEAMER)
	var space := ShipSpace.new(layout)
	var rails := _inner_stair_rails(layout)
	assert_eq(rails.size(), 2, "one hung each side of the inner stair")
	for rail: ShipBlocker in rails:
		var under := space.underside_over(rail.area, rail.top, ShipArt.SIDE_RAIL_SCREEN)
		assert_almost_eq(under, 0.0 - ShipArt.PLANK, 0.001, "the main deck's underside")
		assert_true(is_nan(space.underside_over(rail.area, rail.top, 0.1)), "none within 0.1 m")


func test_the_inner_stair_s_side_rails_are_drawn_up_to_the_main_deck() -> void:
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
			if plan.has_point(Vector2(corner.x, corner.z)) and corner.y > rail.bottom - 0.01:
				if corner.y < 0.0:
					highest = maxf(highest, corner.y)
		assert_almost_eq(
			highest, 0.0 - ShipArt.PLANK, 0.01, "%s up to the deck" % rail.resource_scene_unique_id
		)


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
