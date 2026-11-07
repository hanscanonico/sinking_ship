extends GutTest
## The walk graph's portals are only where a body could get through (WayThrough, #501). A
## flight stacked under another in one well is no way, and on the Titanic a doorway onto a
## stair hole's railing lets a body out, pushed on by the railing, and none in. A doorway
## opening onto a stair's high end lets none through either way: the layout's fault, it keeps
## its portal, so that no room is sealed off. Her other ships lose no portal.

const TITANIC := "res://data/ships/titanic.tres"
const B_DECK := 2.75
const E_DECK := -5.9375
## The stacked well's decks (_stacked_well), and its flights: one up from the hold to the
## tween deck, one on up from it to the top deck, in one footprint; and another way down.
const TWEEN := 2.5
const TOP := 5.0
const UNDER := 0
const OVER_IT := 1
const ANOTHER_WAY := 2
## The doorway from the second-class entrance on E deck into the passage aft of M, under
## the high end of the stair up to D deck; a point in the entrance forward of its lift, clear
## of its stairs.
const UNDER_THE_STAIR_HEAD := Vector3(-72.0625, E_DECK, -2.875)
const IN_THE_ENTRANCE := Vector3(-67.0, E_DECK, 0.0)
## The after second-class entrance's doorway to port on B deck, along the railed side of the
## hole of its stair down to C deck; and its doorway to starboard.
const ONTO_THE_RAILED_HOLE := Vector3(-90.375, B_DECK, -2.875)
const THE_WAY_TO_STARBOARD := Vector3(-90.375, B_DECK, 3.0)
## E deck aft of bulkhead C, to port: the doorway between the passage aft of the ladder down
## to F deck and the passage along it, which the ladder hole's railing once ran across, the
## passage widened into its well; and off the passage along D deck's ladder down, the
## four-berth room's doorway and the men's lavatory's, which the ladder's foot, run on over
## their landing, once stood in (#514).
const AFT_OF_C: Array[Vector3] = [
	Vector3(72.1875, E_DECK, -5.75),
	Vector3(81.25, E_DECK, -7.75),
	Vector3(82.25, E_DECK, -7.15625),
]

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


func _zone(at: Vector3) -> int:
	return _graph.zone_at(at, _surfaces.under(at, SimFixtures.rules().step_height))


func _doorways_at(at: Vector3) -> int:
	var found := 0
	for portal: WalkGraph.Portal in _graph.portals():
		if portal.ramp == WalkGraph.NONE and portal.entry.distance_to(at) < 0.6:
			found += 1
	return found


## A hold, a tween deck over it and a landing over that — test data. Two flights stand in
## one well of the tween deck, x -2…4: one up from the hold rising forward to the tween deck
## (UNDER), one on up from the tween deck rising aft to the landing (OVER_IT), its wedge over
## the first's, as the Titanic's engineers' stair box once stacked E deck's ladder down to F
## over F deck's stair on down to G (#514). Aft of the well, x -10…-4, another flight up from
## the hold rises aft to the tween deck (ANOTHER_WAY).
func _stacked_well() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 6.0
	var platforms: Array[ShipPlatform] = []
	for row: Array in [
		[&"hold", Rect2(-12.0, -4.0, 24.0, 8.0), 0.0],
		[&"tween deck aft", Rect2(-12.0, -4.0, 2.0, 8.0), TWEEN],
		[&"tween deck forward", Rect2(4.0, -4.0, 8.0, 8.0), TWEEN],
		[&"tween deck to port", Rect2(-10.0, -4.0, 14.0, 3.0), TWEEN],
		[&"tween deck to starboard", Rect2(-10.0, 1.0, 14.0, 3.0), TWEEN],
		[&"tween deck between", Rect2(-4.0, -1.0, 2.0, 2.0), TWEEN],
		[&"landing", Rect2(-4.0, -1.0, 2.0, 2.0), TOP],
	]:
		var platform := ShipPlatform.new()
		platform.name = row[0]
		platform.area = row[1]
		platform.height = row[2]
		platforms.append(platform)
	layout.platforms = platforms
	var ramps: Array[ShipRamp] = []
	for row: Array in [
		[Rect2(-2.0, -1.0, 6.0, 2.0), 0.0, TWEEN],
		[Rect2(-2.0, -1.0, 6.0, 2.0), TOP, TWEEN],
		[Rect2(-10.0, -1.0, 6.0, 2.0), TWEEN, 0.0],
	]:
		var ramp := ShipRamp.new()
		ramp.area = row[0]
		ramp.axis = ShipRamp.Axis.X
		ramp.start_height = row[1]
		ramp.end_height = row[2]
		ramps.append(ramp)
	layout.ramps = ramps
	return layout


func test_a_flight_stacked_under_another_in_one_well_is_no_way() -> void:
	var layout := _stacked_well()
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	assert_false(WayThrough.flight(surfaces, rules, layout, UNDER), "the flight under is no way")
	assert_true(WayThrough.flight(surfaces, rules, layout, OVER_IT), "the flight over it is")
	assert_true(WayThrough.flight(surfaces, rules, layout, ANOTHER_WAY), "nor is the other one")
	var graph := WalkGraph.new(layout, surfaces, rules)
	var along := {}
	for portal: WalkGraph.Portal in graph.portals():
		along[portal.ramp] = true
	assert_false(along.has(UNDER), "no portal runs along the flight under the other")
	assert_true(along.has(OVER_IT), "the flight over it is still a way")
	var start := Vector3(8.0, TWEEN, 0.0)
	var on := surfaces.under(start, rules.step_height)
	var hold := Vector3(0.0, 0.0, -3.0)
	var goal := graph.zone_at(hold, surfaces.under(hold, rules.step_height))
	var sink := SinkSchedule.new(
		SimFixtures.calm(), layout.freeboard, SeedStreams.derive(1, "sink")
	)
	var legs := graph.route(start, on, goal, sink.pose_at(0))
	assert_false(legs.is_empty(), "the hold is reached another way")
	for leg: WalkGraph.Portal in legs:
		assert_ne(leg.ramp, UNDER, "and never down the flight under the other")


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


func test_e_deck_s_doorways_aft_of_c_let_a_body_through_both_ways() -> void:
	var rules := SimFixtures.rules()
	for at: Vector3 in AFT_OF_C:
		var door := _door_at(at)
		assert_not_null(door, "a doorway at %s" % at)
		if door == null:
			continue
		for out: Vector2 in [door.outward, -door.outward]:
			var off := WayThrough.doorway(_surfaces, rules, door, E_DECK, out)
			assert_false(is_nan(off), "a body goes through the doorway at %s, %s" % [at, out])
		assert_eq(_doorways_at(at), 2, "a portal through it either way")


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
