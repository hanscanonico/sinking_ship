extends GutTest
## The walk graph's portals are only where a body could get through (WayThrough, #501). A
## flight stacked under another in one well is no way, nor one a solid stands in — as one
## stood in her ladder down to E deck aft of C to port, which a body now walks both ways
## (#537, #541) — and a doorway onto a stair's foot gives onto the stair, never the deck under
## it. On the Titanic a doorway over a stair's head, across the railing along its side, lets
## no body through: the sim holds a body on the stair by it (#561). A join beside a flight's
## side lets none through either way: it keeps its portal, so that no room is sealed off.
## Every doorway of hers that opened onto a flight's side or high end, or onto a solid's face,
## is laid so a body goes through it, or walled (#514). Her other ships lose no portal.

const TITANIC := "res://data/ships/titanic.tres"
const B_DECK := 2.75
## D deck aft of O, at O's top, and either side of P, at P's (#503).
const D_AFT_O := -2.6875
const D_AFT_P := -2.1875
const E_DECK := -5.9375
const F_DECK := -8.5625
const G_DECK := -11.0
const ORLOP_AFT := -13.4375
const ORLOP_FORWARD := -12.9375
const TANK_TOP := -18.1875
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
	Vector3(-108.625, D_AFT_O, -2.75),
	Vector3(-108.625, D_AFT_O, 3.0625),
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
## into the reciprocating engine room against a thrust block, and on the tank top the
## firemen's passage's by its door against boiler room 6's forward bunker's coal to port.
const AGAINST_SOLIDS: Array[Vector3] = [
	Vector3(-27.7109, E_DECK, -3.156),
	Vector3(13.81, F_DECK, -6.0),
	Vector3(-48.6328, -18.1875, -5.44),
	Vector3(69.3477, TANK_TOP, -2.3125),
]
## The third-class women's lavatory on D deck either side of P's line, two rooms (forward of P
## and aft of it), and its W.C.s standing over that line (#514): their join inside the W.C.s,
## reached only from inside them; and its stretch outside them, to port.
const INSIDE_THE_W_C_S := Vector3(-118.9688, D_AFT_P, 8.48)
const BESIDE_THE_W_C_S := Vector3(-118.9688, D_AFT_P, 5.8)
## The after second-class entrance's doorway to port on B deck, over the head of its stair
## down to C deck and across the railing along the stair's side; and its doorway to
## starboard.
const ONTO_THE_RAILED_HOLE := Vector3(-90.375, B_DECK, -2.875)
const THE_WAY_TO_STARBOARD := Vector3(-90.375, B_DECK, 3.0)
## The T.R.S. on D deck forward of B: its doorway aft, into the passage, whose floor on the
## room's side lies beside the solid under the head of the stair down into it from the
## forecastle's passage on C deck.
const OUT_OF_THE_T_R_S := Vector3(98.875, -1.25, -2.5)
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
## Points on the middles of the ladders down from D deck to E deck aft of C, to port and to
## starboard: in the port one's run stood a solid up to D deck (#537, #541).
const PORT_LADDER := Vector2(80.0, -4.9)
const STARBOARD_LADDER := Vector2(80.0, 6.375)
## In the passage by the cross passage's ladder down to F deck, the four-berth room and the
## men's lavatory.
const BY_THE_LADDER := Vector3(73.5, E_DECK, -4.4)
const IN_THE_FOUR_BERTH_ROOM := Vector3(81.25, E_DECK, -9.6)
const IN_THE_LAVATORY := Vector3(83.5, E_DECK, -8.8)
## Doorways a stair runs under or through, each with a point on its line, one in the zone
## its way out of a room — or in from an open deck — would begin in, and one in the zone it
## would lead into (#551): F deck's passage aft of C to starboard, along its side of the
## railed well of the stair down to the orlop, and the passage west of it, past the well; the
## orlop's cargo hold forward of the firemen's spiral trunk, between the railed wells of its
## two ladders up from the tank top, and the trunk; E deck's passage aft of L, the stair down
## from D deck run on through its doorway aft, and the passage past it; her open E deck under
## the stair up to D deck aft of C, and the passage at its foot; her open F deck under the
## stair up to E deck aft of K, and the passage at its foot.
const STAIRS_THROUGH_DOORWAYS: Array[Array] = [
	[Vector3(78.4375, F_DECK, -4.94), Vector3(79.0, F_DECK, -3.7), Vector3(76.5, F_DECK, -5.0)],
	[
		Vector3(99.3125, ORLOP_FORWARD, 0.4375),
		Vector3(98.5, ORLOP_FORWARD, 0.1875),
		Vector3(100.5, ORLOP_FORWARD, 0.0)
	],
	[Vector3(-65.48, E_DECK, 3.125), Vector3(-65.48, E_DECK, 2.6), Vector3(-65.48, E_DECK, 3.6)],
	[Vector3(78.25, E_DECK, -4.906), Vector3(78.6, E_DECK, -4.9), Vector3(77.6, E_DECK, -4.9)],
	[Vector3(-44.4375, F_DECK, -9.546), Vector3(-45.0, F_DECK, -9.5), Vector3(-44.0, F_DECK, -9.5)],
]
## In F deck's passage aft of C to starboard, along the railing of the stair's well (#551).
const ALONG_THE_WELL := Vector3(79.0, F_DECK, -3.7)
## The middle of the orlop's cargo hold's doorway into the firemen's spiral trunk, between
## the railed wells of the ladders up from the tank top (#551).
const BETWEEN_THE_LADDER_WELLS := Vector3(99.3125, ORLOP_FORWARD, 0.1875)

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


## The join of the third-class women's lavatory's two rooms on P's line runs on inside the
## W.C.s standing over the line, where no body but one inside them gets: walled there, its
## stretch to port of them lets a body through both ways (#514).
func test_the_women_s_lavatory_s_join_inside_its_w_c_s_is_walled() -> void:
	var rules := SimFixtures.rules()
	assert_null(_door_at(INSIDE_THE_W_C_S), "no doorway inside the W.C.s")
	var door := _door_at(BESIDE_THE_W_C_S)
	assert_not_null(door, "the join beside the W.C.s")
	if door == null:
		return
	for out: Vector2 in [door.outward, -door.outward]:
		var off := WayThrough.doorway(_surfaces, rules, door, D_AFT_P, out)
		assert_false(is_nan(off), "a body goes through the join beside the W.C.s, %s" % out)
	assert_eq(_doorways_at(BESIDE_THE_W_C_S), 2, "a portal through it either way")


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


## The after second-class entrance's doorway to port on B deck opens over the head of its
## stair down to C deck, across the railing along the stair's side, which fences the deck
## past the doorway off the hole; the entrance's floor beside the stair's head is narrower
## than a body between the doorway's jamb and the stair. A body walking out stands on the
## stair's head, and the sim holds a body there by the railings along a stair's sides by its
## head (#552): no body walks out through the doorway, nor in, and the graph has no portal
## through it (#561). Its doorway to starboard lets a body through both ways, and her deck past
## the doorway to port is reached round by another.
func test_a_doorway_over_a_railed_stair_s_head_lets_no_body_through() -> void:
	var rules := SimFixtures.rules()
	var door := _door_at(ONTO_THE_RAILED_HOLE)
	assert_not_null(door, "the entrance's doorway to port")
	if door == null:
		return
	var unrailed := WayThrough.doorway(_surfaces, rules, door, B_DECK, door.outward, false)
	assert_false(is_nan(unrailed), "but for the railing a body on the stair's head walks out")
	for out: Vector2 in [door.outward, -door.outward]:
		var off := WayThrough.doorway(_surfaces, rules, door, B_DECK, out)
		assert_true(is_nan(off), "the railing holds a body back the way %s, at %.3f" % [out, off])
	assert_eq(_doorways_at(ONTO_THE_RAILED_HOLE), 0, "no portal through the doorway to port")
	assert_eq(_doorways_at(THE_WAY_TO_STARBOARD), 2, "its doorway to starboard, both ways")
	var in_the_entrance := THE_WAY_TO_STARBOARD + Vector3(-1.0, 0.0, -1.0)
	var on_her_deck := ONTO_THE_RAILED_HOLE + Vector3(0.0, 0.0, -0.8)
	var entrance := _zone(in_the_entrance)
	var deck := _zone(on_her_deck)
	assert_ne(entrance, deck, "the doorway joins the entrance and her deck")
	for walk: Array in [[in_the_entrance, deck], [on_her_deck, entrance]]:
		var from: Vector3 = walk[0]
		var on := _surfaces.under(from, rules.step_height)
		assert_false(_graph.route(from, on, walk[1], _dry).is_empty(), "a way round from %s" % from)


## A portal's room end is the piece a body walking in through the doorway first stands in.
## Into the T.R.S. through its doorway aft, where a body goes out, a body's straight walk in
## runs along the solid under the stair's head, where no body stands: the solid pushes it
## aside onto the floor by the doorway, and that floor is the way's end. The doorway keeps a
## portal either way (#561).
func test_a_way_in_pushed_aside_by_a_stair_s_solid_ends_beside_it() -> void:
	assert_eq(_doorways_at(OUT_OF_THE_T_R_S), 2, "a portal through the T.R.S.'s doorway either way")


## A way through a doorway begins where a body stands in the zone it leads out of. Where a
## stair runs under or through a doorway, a body walking through it there stands on the stair
## — down in its well under the floor, or on its foot — and a body on a stair is in the zone
## of the end it is nearer in height, never the room whose floor the stair cuts: the graph has
## no portal there, and a body on that floor goes round by another (#551).
func test_no_doorway_s_way_through_begins_on_a_stair_out_of_another_zone() -> void:
	for row: Array in STAIRS_THROUGH_DOORWAYS:
		var from := _zone(row[1])
		var to := _zone(row[2])
		assert_ne(from, to, "the doorway at %s joins two zones" % row[0])
		for portal: WalkGraph.Portal in _graph.portals():
			var through := portal.from_zone == from and portal.to_zone == to
			if portal.ramp == WalkGraph.NONE and through:
				assert_gt(
					portal.entry.distance_to(row[0]),
					0.3,
					"no way from %s to %s through the doorway at %s" % [row[1], row[2], row[0]]
				)


## The orlop's cargo hold opens into the firemen's spiral trunk across the wells of its two
## ladders up from the tank top, whose heads are in the trunk; between their railings the
## hold's floor is half a metre wide, narrower than a body. A body on a ladder, under the
## hold's floor in its well, first stands clear past the doorway's line: it never stood on
## the hold's side, and no body walks out of the hold through the doorway (#551).
func test_no_body_walks_out_of_the_orlop_hold_between_its_ladder_wells() -> void:
	var rules := SimFixtures.rules()
	var door := _door_at(BETWEEN_THE_LADDER_WELLS)
	assert_not_null(door, "the hold's doorway into the trunk")
	if door == null:
		return
	assert_eq(door.outward, Vector2(1.0, 0.0), "out of the hold, aft")
	var off := WayThrough.doorway(_surfaces, rules, door, ORLOP_FORWARD, door.outward)
	assert_true(is_nan(off), "no body walks out through it, at %.3f" % off)


func test_a_body_along_a_stair_s_well_on_f_deck_aft_of_c_walks_round_it_to_port() -> void:
	# From the passage to starboard of the well of the stair down to the orlop, its railing
	# along the passage's side, into the passage west of it: along the passage aft of C to
	# port, never across the well.
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 1, Vector3.ZERO)
	HeldPose.hold(sim, _dry)
	SimFixtures.place(sim, 0, ALONG_THE_WELL)
	var to := STAIRS_THROUGH_DOORWAYS[0][2] as Vector3
	assert_true(_walks(sim, _zone(to), 10.0), "into the passage west of the well")


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


func test_a_flight_a_solid_stands_in_is_no_way() -> void:
	# A deck at 0, x -6…4, a landing a metre up forward of x 4, and a flight up to it over
	# x 0…4 — test data — with, and without, a block standing across the flight's run over
	# x 1.5…2.5, from the deck up to the landing's height: more than a step over the flight
	# there, so that a body walking up the flight walks into its face, and one walking down it
	# into its other, or off its top onto the flight past it. So stood the solid in the
	# Titanic's ladder down from D deck to E deck aft of C to port, x 82.25…83.0 (#537, #541).
	var rules := SimFixtures.rules()
	for solid: bool in [false, true]:
		var layout := ShipLayout.new()
		layout.freeboard = 6.0
		var platforms: Array[ShipPlatform] = [
			_platform(&"deck", Rect2(-6.0, -4.0, 10.0, 8.0), 0.0),
			_platform(&"landing", Rect2(4.0, -4.0, 2.0, 8.0), 1.0),
		]
		layout.platforms = platforms
		var ramps: Array[ShipRamp] = [_flight(Rect2(0.0, -1.0, 4.0, 2.0), 0.0, 1.0)]
		layout.ramps = ramps
		if solid:
			var block := _wall(Rect2(1.5, -1.2, 1.0, 2.4))
			block.top = 1.0
			var blockers: Array[ShipBlocker] = [block]
			layout.blockers = blockers
		var surfaces := Surfaces.new(layout)
		var held := WayThrough.solid_in(surfaces, rules, layout, 0)
		assert_eq(held == Vector3.INF, not solid, "a solid in it: %s" % solid)
		if solid:
			assert_between(held.x, 1.5 - rules.body_radius, 2.5, "where the block stands")
		assert_eq(WayThrough.flight(surfaces, rules, layout, 0), not solid, "walked: %s" % solid)
		var graph := WalkGraph.new(layout, surfaces, rules)
		assert_eq(_along(graph, 0), not solid, "a way along it: %s" % solid)


## The ramp of hers whose area holds [param point] over E deck, or NONE.
func _ladder(point: Vector2) -> int:
	for index in _layout.ramps.size():
		var ramp := _layout.ramps[index]
		if ramp.area.has_point(point) and is_equal_approx(ramp.base(), E_DECK):
			return index
	return WalkGraph.NONE


## Her ladders down from D deck to E deck aft of C, to port and to starboard, have no solid
## standing in their runs, so the graph has a way along each. In the port one's stood a block
## from x 82.25 to 83.0 up to D deck, the recess of E deck's ladderway passage under its high
## end, made a store (#537, #541).
func test_her_ladders_down_to_e_deck_aft_of_c_are_ways() -> void:
	var rules := SimFixtures.rules()
	for at: Vector2 in [PORT_LADDER, STARBOARD_LADDER]:
		var ladder := _ladder(at)
		assert_ne(ladder, WalkGraph.NONE, "the ladder at %s" % at)
		if ladder == WalkGraph.NONE:
			continue
		var held := WayThrough.solid_in(_surfaces, rules, _layout, ladder)
		assert_eq(held, Vector3.INF, "no solid in the run of the ladder at %s" % at)
		assert_true(WayThrough.flight(_surfaces, rules, _layout, ladder), "walked at %s" % at)
		assert_true(_along(_graph, ladder), "a way along the ladder at %s" % at)


## Whether the body in [param sim]'s seat 0, walking along x toward [param toward] at rest
## from where it stands, stands off any stair on [param deck]'s height past x [param past]
## within [param seconds].
func _walks_along(sim: MatchSim, toward: float, past: float, deck: float, seconds: float) -> bool:
	for _tick in Ticks.from_seconds(seconds):
		var walker := sim.state.seats[0]
		var beyond := walker.pos.x > past if toward > 0.0 else walker.pos.x < past
		if beyond and absf(walker.pos.y - deck) < 0.05 and not sim.surfaces.is_ramp(walker.surface):
			return true
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2(toward, 0.0))})
	return false


## A body at rest walks up her ladder from E deck to D deck aft of C to port along its
## middle, from the cross passage aft of its foot onto the third-class open space past its
## head; and from rest on that open space down it into the cross passage (#541).
func test_a_body_walks_up_and_down_her_port_ladder_to_d_deck_aft_of_c() -> void:
	var index := _ladder(PORT_LADDER)
	assert_ne(index, WalkGraph.NONE, "the ladder to port")
	if index == WalkGraph.NONE:
		return
	var ladder := _layout.ramps[index]
	var middle := ladder.area.get_center().y
	var d_deck := maxf(ladder.start_height, ladder.end_height)
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 1, Vector3.ZERO)
	HeldPose.hold(sim, _dry)
	SimFixtures.place(sim, 0, Vector3(ladder.area.position.x - 0.75, E_DECK, middle))
	var head := ladder.area.end.x + 0.5
	assert_true(_walks_along(sim, 1.0, head, d_deck, 15.0), "up onto D deck")
	SimFixtures.place(sim, 0, Vector3(ladder.area.end.x + 0.75, d_deck, middle))
	var foot := ladder.area.position.x - 0.5
	assert_true(_walks_along(sim, -1.0, foot, E_DECK, 15.0), "down into the cross passage")


func test_a_doorway_onto_a_stair_s_foot_gives_onto_the_stair() -> void:
	# A cabin, x -4…0 and z -2…2, walled but for its forward side, on a deck that runs on
	# forward under a steep flight rising forward from the doorway, as wide as the doorway,
	# 2 m up over x 0…2.4 to a landing — test data. A body walking out through the doorway
	# walks up the flight: a body's width out its feet are on it, 0.67 m over the deck under
	# it, inside the flight's solid, where no body stands. The doorway gives onto no zone, and
	# the cabin's way out is up the flight — as from the Titanic's E deck passage aft of C to
	# starboard, at the foot of the ladder down from D deck there (#537).
	var rules := SimFixtures.rules()
	var layout := ShipLayout.new()
	layout.freeboard = 6.0
	var platforms: Array[ShipPlatform] = [
		_platform(&"deck", Rect2(-6.0, -4.0, 8.4, 8.0), 0.0),
		_platform(&"landing", Rect2(2.4, -4.0, 2.0, 8.0), 2.0),
	]
	layout.platforms = platforms
	var blockers: Array[ShipBlocker] = [
		_wall(Rect2(-4.1, -2.1, 4.2, 0.2)),
		_wall(Rect2(-4.1, 1.9, 4.2, 0.2)),
		_wall(Rect2(-4.1, -2.1, 0.2, 4.2)),
	]
	layout.blockers = blockers
	var ramps: Array[ShipRamp] = [_flight(Rect2(0.0, -2.0, 2.4, 4.0), 0.0, 2.0)]
	layout.ramps = ramps
	var cabin := ShipRoom.new()
	cabin.name = &"cabin"
	cabin.area = Rect2(-4.0, -2.0, 4.0, 4.0)
	var rooms: Array[ShipRoom] = [cabin]
	layout.rooms = rooms
	var surfaces := Surfaces.new(layout)
	var graph := WalkGraph.new(layout, surfaces, rules)
	for portal: WalkGraph.Portal in graph.portals():
		var out_of := portal.from_zone == 0 or portal.to_zone == 0
		assert_false(
			out_of and portal.ramp == WalkGraph.NONE,
			"no doorway out of the cabin onto the deck under the flight, at %s" % portal.entry
		)
	var start := Vector3(3.4, 2.0, 0.0)
	var legs := graph.route(start, surfaces.under(start, rules.step_height), 0, _level(layout))
	assert_eq(legs.size(), 1, "the cabin is reached down the flight")
	if not legs.is_empty():
		assert_eq(legs[0].ramp, 0, "along it")


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
