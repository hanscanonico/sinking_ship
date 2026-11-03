extends GutTest
## The Titanic's forward cargo hatches shut where her plates draw them shut (#399): the covers
## on D deck of Nos. 1 and 2 and the bunker hatch (tools/titanic_plates/d.py) and No. 1's
## trunk enclosed through C deck under her forecastle (c.py), each a shut cover between the
## cells it parts, weeping under 0.3 m of water and giving way under 1 m (est.), an air pipe
## through it, where her generator laid open hatchways.

const SHIP := "res://data/ships/titanic.tres"
const COVERS: Dictionary[StringName, Array] = {
	&"cover_no_1_hatch_port": [&"hold_1_tween", &"hold_1_d"],
	&"cover_no_1_hatch_starboard": [&"hold_1_tween", &"hold_1_d"],
	&"cover_no_2_hatch": [&"hold_2_tween", &"d_deck_forward"],
	&"cover_bunker_hatch": [&"hold_3_tween", &"d_deck_forward"],
	&"cover_no_1_hatch_trunk": [&"hold_1_d", &"forecastle"],
}
## The open hatchways her generator once laid there, 2 m square (est.).
const HATCHWAYS: Array[StringName] = [
	&"stair_hold_1_tween", &"stair_hold_2_tween", &"stair_hold_1_d"
]
const LEAK_HEAD := 0.3
const COLLAPSE_HEAD := 1.0
const LEAK_AREA := 0.05
const AIR_PIPE := 0.008

var _structure: ShipStructure


func before_all() -> void:
	_structure = (load(SHIP) as ShipLayout).structure


func _named(opening_name: StringName) -> ShipOpening:
	for opening: ShipOpening in _structure.openings:
		if opening.name == opening_name:
			return opening
	return null


func test_each_forward_hatch_is_a_shut_cover_that_gives_way_at_a_metre() -> void:
	for cover_name: StringName in COVERS:
		var cover := _named(cover_name)
		assert_not_null(cover, "%s laid" % cover_name)
		if cover == null:
			continue
		assert_eq(cover.joins, COVERS[cover_name] as Array[StringName], "%s's cells" % cover_name)
		assert_eq(cover.kind, ShipOpening.Kind.HATCH, "%s a hatch" % cover_name)
		assert_eq(cover.starts, ShipOpening.Start.SHUT, "%s shut" % cover_name)
		assert_almost_eq(cover.leak_head, LEAK_HEAD, 1e-6, "%s weeps at 0.3 m" % cover_name)
		assert_almost_eq(
			cover.collapse_head, COLLAPSE_HEAD, 1e-6, "%s gives way at 1 m" % cover_name
		)
		assert_almost_eq(cover.leak_area, LEAK_AREA, 1e-6, "%s weeps 0.05 m²" % cover_name)
		var pipe := _named(StringName("pipe_%s" % cover_name))
		assert_not_null(pipe, "%s's air pipe" % cover_name)
		if pipe != null:
			assert_eq(pipe.joins, cover.joins, "%s's air pipe between its cells" % cover_name)
			assert_almost_eq(pipe.flow_area(), AIR_PIPE, 1e-6, "%s's 100 mm pipe" % cover_name)


func test_no_open_hatchway_stands_where_her_plates_draw_a_cover() -> void:
	for hatchway: StringName in HATCHWAYS:
		assert_null(_named(hatchway), "%s, open where her plates draw a cover" % hatchway)
