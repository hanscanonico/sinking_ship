extends GutTest
## The Titanic's forward cargo hatches shut where her plates draw them shut (#399): the covers
## on D deck of Nos. 1 and 2 and the bunker hatch (tools/titanic_plates/d.py), each a shut
## cover between the cells it parts, weeping under 0.3 m of water and giving way under 1 m
## (est.), an air pipe through it; and No. 1's trunk enclosed through C deck under her
## forecastle (c.py), no way from D deck's space into it. No. 1 trunked from G deck up to its
## cover (g.py, f.py, e.py draw its sides on each deck): a cell of its own, open down into its
## hold through G deck (orlop.py: "open down to the holds under them"), shut off from the
## 'tween round it. None of the open hatchways her generator laid there is left.

const SHIP := "res://data/ships/titanic.tres"
const COVERS: Dictionary[StringName, Array] = {
	&"cover_no_1_hatch_port": [&"no_1_hatch_trunk", &"hold_1_d"],
	&"cover_no_1_hatch_starboard": [&"no_1_hatch_trunk", &"hold_1_d"],
	&"cover_no_2_hatch": [&"hold_2_tween", &"d_deck_forward"],
	# (No. 3's 'tween runs aft under her flat D deck: the space under her stepped D deck over it.)
	&"cover_bunker_hatch": [&"hold_3_upper", &"d_deck_forward"],
}
## Each trunk, the hold under it.
const TRUNKS: Dictionary[StringName, StringName] = {&"no_1_hatch_trunk": &"hold_1"}
const G_DECK := -11.0
## The open hatchways her generator once laid there (est.): 2 m square up through D deck, and
## No. 1's 4 m square up through G deck into its 'tween.
const HATCHWAYS: Array[StringName] = [
	&"stair_hold_1_tween", &"stair_hold_2_tween", &"stair_hold_1_d", &"stair_hold_1"
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
	for opening: ShipOpening in _structure.openings:
		var into_trunk := opening.joins.has(&"hold_1_d") and opening.joins.has(&"forecastle")
		assert_false(into_trunk, "%s, a way into No. 1's enclosed trunk" % opening.name)


func test_each_forward_hatch_is_trunked_from_its_hold_up_to_its_cover() -> void:
	for trunk_name: StringName in TRUNKS:
		var index := _structure.cell_named(trunk_name)
		assert_ne(index, -1, "%s laid" % trunk_name)
		if index == -1:
			continue
		assert_almost_eq(_structure.cells[index].low.y, G_DECK, 1e-4, "%s on G deck" % trunk_name)
		var hold: StringName = TRUNKS[trunk_name]
		var hatchways := 0
		var covers: Array[StringName] = []
		for opening: ShipOpening in _structure.openings:
			if not opening.joins.has(trunk_name):
				continue
			var cover := String(opening.name).trim_prefix("pipe_")
			if opening.joins.has(hold):
				hatchways += 1
				assert_eq(
					opening.starts, ShipOpening.Start.OPEN, "%s open to its hold" % trunk_name
				)
				assert_almost_eq(opening.centre.y, G_DECK, 1e-4, "%s's foot in G deck" % trunk_name)
			elif COVERS.has(StringName(cover)):
				covers.append(opening.name)
			else:
				fail_test(
					"%s: %s, a way out but to its hold or its cover" % [trunk_name, opening.name]
				)
		assert_eq(hatchways, 1, "%s: one hatchway down into its hold" % trunk_name)
		for cover_name: StringName in COVERS:
			if (COVERS[cover_name] as Array)[0] == trunk_name:
				assert_has(covers, cover_name, "%s shut by %s" % [trunk_name, cover_name])
