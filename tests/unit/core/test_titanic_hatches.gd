extends GutTest
## The Titanic's forward cargo hatches shut where her plates draw them shut (#399): the covers
## on D deck of Nos. 1 and 2 and the bunker hatch (tools/titanic_plates/d.py), each a shut
## cover between the cells it parts, an air pipe through it: loose hatch boards (#503), which
## the water under them floats off at about their thickness (est. 3 in) toward the space over
## them, while pressed from above they weep at that head and hold to 1 m (est.); and No. 1's trunk enclosed through C deck under her
## forecastle (c.py), no way from D deck's space into it. No. 1 trunked from G deck up to its
## cover (g.py, f.py, e.py draw its sides on each deck): a cell of its own, open down into its
## hold through G deck (orlop.py: "open down to the holds under them"), shut off from the
## 'tween round it but for its casing's seams, which weep (#513). None of the open hatchways
## her generator laid there is left. And the 'tweens her trunks part keep their ports: the
## Britannic's open where the 'tween's are.

const SHIP := "res://data/ships/titanic.tres"
## The most a casing's face weeps through its seams, in m² (tools/titanic_leakage.py).
const SEAMS := 0.05
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
## The Britannic, and the mine that sank her with her lower decks' ports open.
const BRITANNIC := "res://tests/fixtures/ships/titanic_britannic.tres"
const PORTS_OPEN := "res://tests/fixtures/sinking/hits/titanic_britannic_mine_ports.tres"
## A piece her trunks part a 'tween into, by the 'tween's name (gen_titanic.py's part_round).
const PIECE := "_(port|starboard|aft|fore)_tween$"
## Her hatch boards' thickness, in metres (3 in, est.): the head that lifts them off.
const LIFT_HEAD := 0.0762
const COLLAPSE_HEAD := 1.0
const LEAK_AREA := 0.05
## The test tanks' floor, and the head across a cover in them: over its lift, under its
## collapse.
const TANK_FLOOR := -20.0
const SMALL_HEAD := 0.5
const AIR_PIPE := 0.008

var _structure: ShipStructure


func before_all() -> void:
	_structure = (load(SHIP) as ShipLayout).structure


func _named(opening_name: StringName) -> ShipOpening:
	for opening: ShipOpening in _structure.openings:
		if opening.name == opening_name:
			return opening
	return null


func test_each_forward_hatch_is_a_shut_cover_of_loose_boards() -> void:
	for cover_name: StringName in COVERS:
		var cover := _named(cover_name)
		assert_not_null(cover, "%s laid" % cover_name)
		if cover == null:
			continue
		assert_eq(cover.joins, COVERS[cover_name] as Array[StringName], "%s's cells" % cover_name)
		assert_eq(cover.kind, ShipOpening.Kind.HATCH, "%s a hatch" % cover_name)
		assert_eq(cover.starts, ShipOpening.Start.SHUT, "%s shut" % cover_name)
		assert_almost_eq(cover.leak_head, LIFT_HEAD, 1e-6, "%s lifts at 3 in" % cover_name)
		assert_eq(cover.opens_toward, cover.joins[1], "%s floats off upward" % cover_name)
		var under := _structure.cell_named(cover.joins[0])
		var over := _structure.cell_named(cover.joins[1])
		if under != -1 and over != -1:
			assert_almost_eq(
				_structure.cells[over].low.y,
				_structure.cells[under].high.y,
				0.01,
				"%s: %s the space over %s" % [cover_name, cover.joins[1], cover.joins[0]]
			)
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
			elif opening.kind == ShipOpening.Kind.LEAK:
				# Its casing's seams weep into the 'tween beside it (#513): a leak, never a way.
				assert_lt(
					opening.flow_area(), SEAMS, "%s: %s only weeps" % [trunk_name, opening.name]
				)
			else:
				fail_test(
					"%s: %s, a way out but to its hold or its cover" % [trunk_name, opening.name]
				)
		assert_eq(hatchways, 1, "%s: one hatchway down into its hold" % trunk_name)
		for cover_name: StringName in COVERS:
			if (COVERS[cover_name] as Array)[0] == trunk_name:
				assert_has(covers, cover_name, "%s shut by %s" % [trunk_name, cover_name])


func test_the_pieces_of_a_tween_round_a_trunk_open_their_ports_with_it() -> void:
	var structure := (load(BRITANNIC) as ShipLayout).structure
	var hit := load(PORTS_OPEN) as IcebergHit
	var ports: Dictionary[StringName, StringName] = {}
	for opening: ShipOpening in structure.openings:
		if opening.kind == ShipOpening.Kind.PORTHOLE:
			ports[opening.name] = opening.joins[0]
	var piece := RegEx.create_from_string(PIECE)
	var opened: Dictionary[String, bool] = {}
	for port: StringName in hit.left_open:
		assert_true(ports.has(port), "%s, one of the Britannic's ports" % port)
		if ports.has(port):
			opened[piece.sub(String(ports[port]), "_tween")] = true
	for port: StringName in ports:
		var tween := piece.sub(String(ports[port]), "_tween")
		if opened.has(tween):
			assert_has(hit.left_open, port, "%s, open with %s's other ports" % [port, tween])


## Two tanks one over the other in a broad barge, the sea standing [param sea_over_floor] over
## the lower's floor, a cover with [param cover]'s heads between them: the lower holed to
## the sea at its floor when [param from_below], else the upper at its own; the cover
## swinging open into the upper where [param cover] opens toward the space over it.
func _stacked(cover: ShipOpening, sea_over_floor: float, from_below: bool) -> SinkStepper:
	var barge := BoxBarge.new(1000.0, 1000.0, 40.0, sea_over_floor, 10.0)
	barge.section_length = 250.0
	barge.cell(&"under", Vector3(0.0, TANK_FLOOR, 0.0), Vector3(10.0, TANK_FLOOR + 2.0, 10.0))
	barge.cell(&"over", Vector3(0.0, TANK_FLOOR + 2.0, 0.0), Vector3(10.0, TANK_FLOOR + 4.0, 10.0))
	if from_below:
		barge.hole(&"under", Vector3(5.0, TANK_FLOOR, 5.0), 0.1, true)
	else:
		barge.hole(&"over", Vector3(5.0, TANK_FLOOR + 2.0, 0.0), 0.1)
	var made := ShipOpening.new()
	made.name = &"cover"
	made.kind = ShipOpening.Kind.HATCH
	made.joins = [&"under", &"over"]
	made.centre = Vector3(5.0, TANK_FLOOR + 2.0, 5.0)
	made.size = Vector3(3.0, 0.0, 3.0)
	made.starts = ShipOpening.Start.SHUT
	made.leak_head = cover.leak_head
	made.collapse_head = cover.collapse_head
	made.leak_area = cover.leak_area
	made.opens_toward = &"over" if cover.opens_toward == cover.joins[1] else &""
	barge.openings.append(made)
	var structure := barge.structure()
	for section: HullSection in structure.sections:
		var outline := section.outline.duplicate()
		for at in outline.size():
			outline[at] = outline[at] + Vector2(0.0, TANK_FLOOR - barge.keel())
		section.outline = outline
	structure.keel_y = TANK_FLOOR
	structure.waterline_y = TANK_FLOOR + sea_over_floor
	structure.mass[0].centre.y = TANK_FLOOR + 5.0
	return SinkStepper.new(structure, HitDamage.new(), _flows())


func _flows() -> SeaPhysics:
	var flows: SeaPhysics = SeaPhysics.load_default().duplicate()
	flows.attitude = false
	flows.air = false
	return flows


func _event(bake: SinkBake, kind: SinkTimeline.Kind) -> float:
	for event: SinkTimeline.Event in bake.events():
		if event.kind == kind and event.name == &"cover":
			return event.seconds
	return -1.0


func test_a_cover_below_decks_floats_off_from_below_and_holds_from_above() -> void:
	# Half a metre of head on each of her covers' heads, from each side: the water under
	# its boards floats them off; the same water over them only weeps through.
	var cover := _named(&"cover_no_2_hatch")
	assert_not_null(cover, "No. 2's cover laid")
	if cover == null:
		return
	var below := SinkBake.new(_stacked(cover, 2.0 + SMALL_HEAD, true), _flows(), 7200.0)
	below.run(1 << 62)
	assert_gt(_event(below, SinkTimeline.Kind.GAVE_WAY), 0.0, "from below, it floats off")
	var above := SinkBake.new(_stacked(cover, 2.0 + SMALL_HEAD, false), _flows(), 7200.0)
	above.run(1 << 62)
	assert_gt(_event(above, SinkTimeline.Kind.LEAKING), 0.0, "from above, it weeps")
	assert_eq(_event(above, SinkTimeline.Kind.GAVE_WAY), -1.0, "and holds")
