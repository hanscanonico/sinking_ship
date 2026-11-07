extends GutTest
## The walk graph's portals are only where a body could get through (WayThrough, #501). A
## flight stacked under another in one well is no way, and on the Titanic a doorway onto a
## stair hole's railing lets a body out, pushed on by the railing, and none in. A join beside
## a flight's side lets none through either way: it keeps its portal, so that no room is
## sealed off. Every doorway of hers that opened onto a flight's side or high end, or onto a
## solid's face, is laid so a body goes through it, or walled (#514). Her other ships lose no
## portal.

const TITANIC := "res://data/ships/titanic.tres"
const B_DECK := 2.75
const D_AFT := -2.9375
const E_DECK := -5.9375
const F_DECK := -8.5625
const G_DECK := -11.0
const ORLOP_AFT := -13.4375
const ORLOP_FORWARD := -12.9375
const DOUBLE_BOTTOM := -19.8125
## The stacked well's decks (_stacked_well), and its flights: one up from the hold to the
## tween deck, one on up from it to the top deck, in one footprint; and another way down.
const TWEEN := 2.5
const TOP := 5.0
const UNDER := 0
const OVER_IT := 1
const ANOTHER_WAY := 2
## The join between the orlop's cargo hold forward of B and its starboard after piece, along
## the well of the hold ladder up from No. 2 hold's tank top; a point in each clear of it. (G
## deck's join along the side of F deck's stair down aft of C, which was this, is walled,
## #531.)
const BESIDE_THE_STAIR := Vector3(94.09, ORLOP_FORWARD, 3.0)
const IN_THE_PASSAGE := Vector3(94.0, ORLOP_FORWARD, 5.0)
const IN_THE_OTHER_PASSAGE := Vector3(92.5, ORLOP_FORWARD, -2.0)
## Doorways that opened onto a flight's side or high end (#514): the second-class entrance's
## on E deck from the passage aft of M, once under its stair up's head; the third-class
## matron's room's and surgery's on D deck; the four-berth room's and the men's lavatory's
## two aft of B, and the women's lavatory's, on E deck; the linen room's and an eight-berth
## room's aft of C on F deck; the two-berth room's aft of C on G deck; the mouths of F deck's
## passages aft of N and aft of O; the musicians' quarters' and the firemen's W.C.s' on E
## deck; F deck's third-class ladderway's; the refrigerated hold's into No. 5 hatch's piece;
## the double bottom's forward of No. 1 hold.
const OFF_THE_FLIGHTS: Array[Vector3] = [
	Vector3(-72.625, E_DECK, -2.875),
	Vector3(-108.625, D_AFT, -2.75),
	Vector3(-108.625, D_AFT, 3.0625),
	Vector3(95.6875, E_DECK, 7.8713),
	Vector3(89.4375, E_DECK, 4.6875),
	Vector3(89.4375, E_DECK, 7.3125),
	Vector3(84.125, E_DECK, 4.6875),
	Vector3(74.125, F_DECK, -4.375),
	Vector3(78.4375, F_DECK, -9.79),
	Vector3(72.1875, G_DECK, -6.25),
	Vector3(-88.5, F_DECK, -4.6875),
	Vector3(-114.375, F_DECK, 2.875),
	Vector3(-65.0, E_DECK, -10.875),
	Vector3(100.8125, E_DECK, 3.375),
	Vector3(92.25, F_DECK, 6.625),
	Vector3(-94.0275, ORLOP_AFT, -2.75),
	Vector3(110.0, DOUBLE_BOTTOM, 0.0),
]
## Rooms' edges a solid stands flush against, once read as doorways onto it through a hair's
## gap (#514): the storekeepers' quarters' on E deck against the reciprocating engine casing,
## a third-class dining saloon's on F deck against a boiler casing, the turbine engine room's
## into the reciprocating engine room against a thrust block.
const AGAINST_SOLIDS: Array[Vector3] = [
	Vector3(-27.7109, E_DECK, -3.156),
	Vector3(13.81, F_DECK, -6.0),
	Vector3(-48.6328, -18.1875, -5.44),
]
## The after second-class entrance's doorway to port on B deck, along the railed side of the
## hole of its stair down to C deck; and its doorway to starboard.
const ONTO_THE_RAILED_HOLE := Vector3(-90.375, B_DECK, -2.875)
const THE_WAY_TO_STARBOARD := Vector3(-90.375, B_DECK, 3.0)
## E deck aft of bulkhead C, to port: the doorway between the passage aft of the ladder down
## to F deck and the passage along it, which the ladder hole's railing once ran across, the
## passage widened into its well; and off the port after ladderway's lane, the four-berth
## room's doorway and the men's lavatory's, which D deck's ladder down, run on forward over
## their landing, once stood in (#514).
const AFT_OF_C: Array[Vector3] = [
	Vector3(72.1875, E_DECK, -5.75),
	Vector3(81.25, E_DECK, -7.75),
	Vector3(82.25, E_DECK, -7.15625),
]
## In the passage by the cross passage's ladder down to F deck, the four-berth room and the
## men's lavatory.
const BY_THE_LADDER := Vector3(73.5, E_DECK, -4.4)
const IN_THE_FOUR_BERTH_ROOM := Vector3(81.25, E_DECK, -9.6)
const IN_THE_LAVATORY := Vector3(83.5, E_DECK, -8.8)

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


func test_a_doorway_no_body_gets_through_has_no_portal_and_a_way_round() -> void:
	var rules := SimFixtures.rules()
	var door := _door_at(BESIDE_THE_STAIR)
	assert_not_null(door, "the join beside the stair's side")
	if door != null:
		for out: Vector2 in [door.outward, -door.outward]:
			var off := WayThrough.doorway(_surfaces, rules, door, BESIDE_THE_STAIR.y, out)
			assert_true(is_nan(off), "no body gets through it")
		var offs := WayThrough.crossings(_surfaces, rules, door, BESIDE_THE_STAIR.y)
		assert_true(is_nan(offs[0]) and is_nan(offs[1]), "no way either way")
	assert_eq(_doorways_at(BESIDE_THE_STAIR), 0, "no portal through it")
	var from := _surfaces.under(IN_THE_PASSAGE, rules.step_height)
	var other := _zone(IN_THE_OTHER_PASSAGE)
	assert_false(_graph.route(IN_THE_PASSAGE, from, other, _dry).is_empty(), "a way round")


func test_doorways_once_onto_a_flight_let_a_body_through_both_ways() -> void:
	var rules := SimFixtures.rules()
	for at: Vector3 in OFF_THE_FLIGHTS:
		var door := _door_at(at)
		assert_not_null(door, "a doorway at %s" % at)
		if door == null:
			continue
		for out: Vector2 in [door.outward, -door.outward]:
			var off := WayThrough.doorway(_surfaces, rules, door, at.y, out)
			assert_false(is_nan(off), "a body goes through the doorway at %s, %s" % [at, out])


func test_a_room_s_edge_a_solid_stands_flush_against_is_walled() -> void:
	for at: Vector3 in AGAINST_SOLIDS:
		assert_null(_door_at(at), "no doorway onto the solid at %s" % at)


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


## Whether the body in [param sim]'s seat 0, steered along the graph's way to [param goal],
## stands in it off any stair within [param seconds].
func _walks(sim: MatchSim, goal: int, seconds: float) -> bool:
	for _tick in Ticks.from_seconds(seconds):
		var walker := sim.state.seats[0]
		if (
			_graph.zone_at(walker.pos, walker.surface) == goal
			and not sim.surfaces.is_ramp(walker.surface)
		):
			return true
		var toward := _graph.steer(walker.pos, walker.surface, goal, _dry)
		var move := Vector2.ZERO
		if not toward.is_empty():
			move = Vector2(toward[0].x - walker.pos.x, toward[0].z - walker.pos.z).normalized()
		SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
	return false


func test_a_body_at_rest_walks_into_e_deck_s_rooms_aft_of_c_and_back_out() -> void:
	# Along the ladderway's lane, past E deck's ladder down to F and D deck's ladder down.
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 1, Vector3.ZERO)
	HeldPose.hold(sim, _dry)
	for walk: Array in [
		[BY_THE_LADDER, IN_THE_FOUR_BERTH_ROOM],
		[BY_THE_LADDER, IN_THE_LAVATORY],
		[IN_THE_FOUR_BERTH_ROOM, BY_THE_LADDER],
	]:
		SimFixtures.place(sim, 0, walk[0])
		assert_true(_walks(sim, _zone(walk[1]), 15.0), "from %s to %s" % walk)


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


## A platform called [param named] over [param area] at [param height].
func _platform(named: StringName, area: Rect2, height: float) -> ShipPlatform:
	var platform := ShipPlatform.new()
	platform.name = named
	platform.area = area
	platform.height = height
	return platform


## A wall over [param area], from the deck at 0 up 2.5 m.
func _wall(area: Rect2) -> ShipBlocker:
	var wall := ShipBlocker.new()
	wall.area = area
	wall.top = 2.5
	return wall


## A flight along x over [param area] from [param start] high to [param end] high.
func _flight(area: Rect2, start: float, end: float) -> ShipRamp:
	var ramp := ShipRamp.new()
	ramp.area = area
	ramp.axis = ShipRamp.Axis.X
	ramp.start_height = start
	ramp.end_height = end
	return ramp


## Whether [param graph] has a way along [param ramp].
func _along(graph: WalkGraph, ramp: int) -> bool:
	for portal: WalkGraph.Portal in graph.portals():
		if portal.ramp == ramp:
			return true
	return false


func _level(layout: ShipLayout) -> ShipPose:
	return (
		SinkSchedule
		. new(SimFixtures.calm(), layout.freeboard, SeedStreams.derive(1, "sink"))
		. pose_at(0)
	)


func test_a_flight_under_a_deck_too_low_to_crawl_under_is_no_way() -> void:
	# A deck at 0, x -6…6, a landing a metre up forward of x 4, and a flight up to it over
	# x 0…4 — test data — under a roof: 0.6 m over the flight's head is too low for anybody,
	# 2 m over it is not.
	var rules := SimFixtures.rules()
	for roof: float in [1.6, 3.0]:
		var layout := ShipLayout.new()
		layout.freeboard = 6.0
		var platforms: Array[ShipPlatform] = [
			_platform(&"deck", Rect2(-6.0, -4.0, 10.0, 8.0), 0.0),
			_platform(&"landing", Rect2(4.0, -4.0, 2.0, 8.0), 1.0),
			_platform(&"roof", Rect2(0.0, -4.0, 4.0, 8.0), roof),
		]
		layout.platforms = platforms
		var ramps: Array[ShipRamp] = [_flight(Rect2(0.0, -1.0, 4.0, 2.0), 0.0, 1.0)]
		layout.ramps = ramps
		var surfaces := Surfaces.new(layout)
		var walked := roof > 2.0
		assert_eq(WayThrough.flight(surfaces, rules, layout, 0), walked, "under %.1f m" % roof)
		var graph := WalkGraph.new(layout, surfaces, rules)
		assert_eq(_along(graph, 0), walked, "a way along it under %.1f m" % roof)


func test_a_wide_doorway_whose_middle_gives_onto_a_stair_gives_onto_the_deck_beside_it() -> void:
	# A cabin, x -4…0 and z -4…0, walled but for its forward side, 4 m wide, on a deck — test
	# data. A flight rises forward from 0.4 m off the doorway's middle, a metre wide, to a
	# landing: a body's width out through the doorway's middle is on the flight, either side
	# of it on the deck. A way out onto the deck stands, as wide as it is, either side of the
	# flight, never across it: a body walking out over the flight's foot is on the flight.
	var rules := SimFixtures.rules()
	var layout := ShipLayout.new()
	layout.freeboard = 6.0
	var platforms: Array[ShipPlatform] = [
		_platform(&"deck", Rect2(-6.0, -6.0, 10.4, 12.0), 0.0),
		_platform(&"landing", Rect2(4.4, -3.0, 2.0, 2.0), 1.0),
	]
	layout.platforms = platforms
	var blockers: Array[ShipBlocker] = [
		_wall(Rect2(-4.1, -4.1, 4.2, 0.2)),
		_wall(Rect2(-4.1, -0.1, 4.2, 0.2)),
		_wall(Rect2(-4.1, -4.1, 0.2, 4.2)),
	]
	layout.blockers = blockers
	var ramps: Array[ShipRamp] = [_flight(Rect2(0.4, -2.5, 4.0, 1.0), 0.0, 1.0)]
	layout.ramps = ramps
	var cabin := ShipRoom.new()
	cabin.name = &"cabin"
	cabin.area = Rect2(-4.0, -4.0, 4.0, 4.0)
	var rooms: Array[ShipRoom] = [cabin]
	layout.rooms = rooms
	var surfaces := Surfaces.new(layout)
	var graph := WalkGraph.new(layout, surfaces, rules)
	var deck := graph.deck_of(0)
	var ways := {}
	for portal: WalkGraph.Portal in graph.portals():
		if portal.ramp == WalkGraph.NONE:
			ways[Vector2i(portal.from_zone, portal.to_zone)] = true
	assert_true(ways.has(Vector2i(0, deck)), "out of the cabin onto the deck")
	assert_true(ways.has(Vector2i(deck, 0)), "and back in")
	var sides := {}
	for portal: WalkGraph.Portal in graph.portals():
		if portal.ramp == WalkGraph.NONE and portal.from_zone == 0:
			var near := portal.entry.z + portal.half_width
			var far := portal.entry.z - portal.half_width
			assert_true(
				near < -2.4 or far > -1.6,
				(
					"the way out at z %.2f, %.2f wide, keeps off the flight"
					% [portal.entry.z, portal.half_width * 2.0]
				)
			)
			sides[signf(portal.entry.z + 2.0)] = true
	assert_eq(sides.size(), 2, "a way out either side of the flight")
	var start := Vector3(-3.0, 0.0, 4.0)
	var legs := graph.route(start, surfaces.under(start, rules.step_height), 0, _level(layout))
	assert_false(legs.is_empty(), "so the cabin is not sealed")


func test_a_flight_s_foot_short_of_its_room_s_edge_ends_in_the_room() -> void:
	# A hall, x -4…4, walled all round on a floor at 0 that runs on 0.4 m past its forward
	# wall, and a deck 2 m up aft of it — test data. A flight down from the deck into the hall
	# ends 0.44 m short of the hall's forward edge: a body's width on past its foot is past the
	# hall's wall, on that floor but in no room. The flight is the only way in.
	var rules := SimFixtures.rules()
	var layout := ShipLayout.new()
	layout.freeboard = 6.0
	var platforms: Array[ShipPlatform] = [
		_platform(&"deck", Rect2(-10.0, -4.0, 6.0, 8.0), 2.0),
		_platform(&"floor", Rect2(-4.0, -4.0, 8.4, 8.0), 0.0),
	]
	layout.platforms = platforms
	var blockers: Array[ShipBlocker] = [
		_wall(Rect2(-4.1, -4.1, 8.2, 0.2)),
		_wall(Rect2(-4.1, 3.9, 8.2, 0.2)),
		_wall(Rect2(3.9, -4.1, 0.2, 8.2)),
		_wall(Rect2(-4.1, -4.1, 0.2, 3.1)),
		_wall(Rect2(-4.1, 1.0, 0.2, 3.1)),
	]
	layout.blockers = blockers
	var ramps: Array[ShipRamp] = [_flight(Rect2(-4.0, -1.0, 7.56, 2.0), 2.0, 0.0)]
	layout.ramps = ramps
	var hall := ShipRoom.new()
	hall.name = &"hall"
	hall.area = Rect2(-4.0, -4.0, 8.0, 8.0)
	var rooms: Array[ShipRoom] = [hall]
	layout.rooms = rooms
	var surfaces := Surfaces.new(layout)
	var graph := WalkGraph.new(layout, surfaces, rules)
	var foot := graph.way_off(surfaces.ramp_surface(0), 0)
	assert_not_null(foot, "the flight's foot is in the hall")
	var start := Vector3(-7.0, 2.0, 0.0)
	var legs := graph.route(start, surfaces.under(start, rules.step_height), 0, _level(layout))
	assert_false(legs.is_empty(), "so the hall is reached down it")
