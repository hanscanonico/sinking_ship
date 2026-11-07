extends GutTest
## The walk graph's portals are only where a body could get through (WayThrough, #501). On
## the Titanic a flight stacked under another in one well is no way, and a doorway onto a
## stair hole's railing lets a body out, pushed on by the railing, and none in. A doorway
## opening onto a stair's high end lets none through either way: the layout's fault, it keeps
## its portal, so that no room is sealed off. Her other ships lose no portal.

const TITANIC := "res://data/ships/titanic.tres"
const B_DECK := 2.75
const E_DECK := -5.9375
const F_DECK := -8.5625
const G_DECK := -11.0
## Between bulkheads L and K, inside the engineers' stair box: E deck's ladder down to F
## stands over F deck's stair down to G there, both the box's width.
const IN_THE_STAIR_BOX := Vector2(-45.6, -9.78)
## In the passage on F deck aft of K, by the box's door, and in the paint store on G deck.
const BY_THE_BOX := Vector3(-43.8, F_DECK, -10.4)
const IN_THE_PAINT_STORE := Vector3(-40.0, G_DECK, -12.5)
## The doorway from the second-class entrance on E deck into the passage aft of M, under
## the high end of the stair up to D deck; a point in the entrance forward of its lift, clear
## of its stairs.
const UNDER_THE_STAIR_HEAD := Vector3(-72.0625, E_DECK, -2.875)
const IN_THE_ENTRANCE := Vector3(-67.0, E_DECK, 0.0)
## The after second-class entrance's doorway to port on B deck, along the railed side of the
## hole of its stair down to C deck; and its doorway to starboard.
const ONTO_THE_RAILED_HOLE := Vector3(-90.375, B_DECK, -2.875)
const THE_WAY_TO_STARBOARD := Vector3(-90.375, B_DECK, 3.0)

var _layout: ShipLayout
var _surfaces: Surfaces
var _graph: WalkGraph
## Her held dry and level.
var _dry: ShipPose


func before_all() -> void:
	_layout = load(TITANIC)
	_surfaces = Surfaces.new(_layout)
	_graph = WalkGraph.new(_layout, _surfaces, SimFixtures.rules())
	_dry = HeldPose.flooded(_layout, -_layout.freeboard, {})


func _ramp_over(point: Vector2, base: float) -> int:
	for index in _layout.ramps.size():
		var ramp := _layout.ramps[index]
		if ramp.area.has_point(point) and is_equal_approx(ramp.base(), base):
			return index
	return WalkGraph.NONE


func _zone(at: Vector3) -> int:
	return _graph.zone_at(at, _surfaces.under(at, SimFixtures.rules().step_height))


func _doorways_at(at: Vector3) -> int:
	var found := 0
	for portal: WalkGraph.Portal in _graph.portals():
		if portal.ramp == WalkGraph.NONE and portal.entry.distance_to(at) < 0.6:
			found += 1
	return found


func test_a_flight_stacked_under_another_in_one_well_is_no_way() -> void:
	var under := _ramp_over(IN_THE_STAIR_BOX, G_DECK)
	var over := _ramp_over(IN_THE_STAIR_BOX, F_DECK)
	assert_ne(under, WalkGraph.NONE, "F deck's stair down to G stands in the box")
	assert_ne(over, WalkGraph.NONE, "E deck's ladder down to F stands over it")
	var rules := SimFixtures.rules()
	assert_false(WayThrough.flight(_surfaces, rules, _layout, under), "the stair is no way")
	assert_true(WayThrough.flight(_surfaces, rules, _layout, over), "the ladder over it is")
	var along := {}
	for portal: WalkGraph.Portal in _graph.portals():
		along[portal.ramp] = true
	assert_false(along.has(under), "no portal runs along the stair under the ladder")
	assert_true(along.has(over), "the ladder over it is still a way")
	var on := _surfaces.under(BY_THE_BOX, rules.step_height)
	var legs := _graph.route(BY_THE_BOX, on, _zone(IN_THE_PAINT_STORE), _dry)
	assert_false(legs.is_empty(), "the paint store is reached another way")
	for leg: WalkGraph.Portal in legs:
		assert_ne(leg.ramp, under, "and never down the stair under the ladder")


## The doorway of hers whose middle stands at [param at], or null.
func _door_at(at: Vector3) -> ShipRoom.Door:
	var rules := SimFixtures.rules()
	for room: ShipRoom in _layout.rooms:
		for door: ShipRoom.Door in room.doors(_surfaces, rules.crawl_height, rules.step_height):
			if door.middle().distance_to(Vector2(at.x, at.z)) < 0.1:
				return door
	return null


func test_a_doorway_no_body_gets_through_keeps_its_portal_at_its_middle() -> void:
	var rules := SimFixtures.rules()
	var door := _door_at(UNDER_THE_STAIR_HEAD)
	assert_not_null(door, "the doorway under the stair's high end")
	if door != null:
		for out: Vector2 in [door.outward, -door.outward]:
			var off := WayThrough.doorway(_surfaces, rules, door, E_DECK, out)
			assert_true(is_nan(off), "no body gets through it")
		var offs := WayThrough.crossings(_surfaces, rules, door, E_DECK, false)
		assert_eq(Array(offs), [0.0, 0.0], "its middle, both ways")
	assert_gt(_doorways_at(UNDER_THE_STAIR_HEAD), 0, "so the passage aft of M is not sealed")
	var from := _surfaces.under(IN_THE_ENTRANCE, rules.step_height)
	var passage := _zone(UNDER_THE_STAIR_HEAD + Vector3(0.0, 0.0, -0.8))
	assert_false(_graph.route(IN_THE_ENTRANCE, from, passage, _dry).is_empty(), "a way in")


func test_a_doorway_onto_a_railed_stair_hole_lets_a_body_out_and_none_in() -> void:
	var entrance := _zone(THE_WAY_TO_STARBOARD + Vector3(-1.0, 0.0, -1.0))
	var deck := _zone(ONTO_THE_RAILED_HOLE + Vector3(0.0, 0.0, -0.8))
	assert_ne(entrance, deck, "the doorway joins the entrance and her deck")
	for portal: WalkGraph.Portal in _graph.portals():
		if portal.ramp == WalkGraph.NONE and portal.entry.distance_to(ONTO_THE_RAILED_HOLE) < 0.6:
			assert_eq(portal.from_zone, entrance, "only out of the entrance, pushed on")
	assert_eq(_doorways_at(ONTO_THE_RAILED_HOLE), 1, "one portal through the doorway to port")
	assert_eq(_doorways_at(THE_WAY_TO_STARBOARD), 2, "its doorway to starboard, both ways")


func test_her_other_ships_lose_no_portal() -> void:
	var rules := SimFixtures.rules()
	for ship: String in ["steamer", "trawler", "tug", "barque", "ferry", "freighter"]:
		var layout: ShipLayout = load("res://data/ships/%s.tres" % ship)
		var surfaces := Surfaces.new(layout)
		for index in layout.ramps.size():
			assert_true(
				WayThrough.flight(surfaces, rules, layout, index),
				"%s's ramp %d is walked" % [ship, index]
			)
		for room: ShipRoom in layout.rooms:
			for door: ShipRoom.Door in room.doors(surfaces, rules.crawl_height, rules.step_height):
				# Only a doorway the graph puts a portal through: onto a floor (WalkGraph's lead).
				var beyond := door.middle() + door.outward * rules.body_radius * 2.0
				var outside := Vector3(beyond.x, room.floor_height, beyond.y)
				var onto := surfaces.under(outside, rules.step_height)
				if door.width() < rules.body_radius * 2.0 or onto == Surfaces.NONE:
					continue
				if surfaces.is_ramp(onto):
					continue
				for out: Vector2 in [door.outward, -door.outward]:
					var off := WayThrough.doorway(surfaces, rules, door, room.floor_height, out)
					assert_false(
						is_nan(off), "%s's %s has a doorway a body goes through" % [ship, room.name]
					)
