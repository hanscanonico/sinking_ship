extends GutTest
## Below the Titanic's main deck every floor a body walks is a room's (#549). Floor no room
## holds is an open deck to the walk graph, one zone for all of it at its height, and her
## decks under her main deck are rooms from wall to wall: what the plates' wells left beside
## their flights, before a flight's head, past its foot or past a door was such a floor, a
## zone of strips thinner than a body that the graph routed bots into, through doorways as
## narrow as 6 cm, and that a bot standing on one read itself in, with no way out. So below
## her main deck no way of the graph's leads onto floor no room holds, and no stair's end or
## doorway opens onto any: on her and on her sisters.

const SHIPS: Array[String] = [
	"res://data/ships/titanic.tres",
	"res://tests/fixtures/ships/titanic_britannic.tres",
	"res://tests/fixtures/ships/titanic_olympic_1913.tres",
]
## How far past a stair's end or a doorway's gap the floor stepped onto is read.
const PAST := 0.02
## The points read across each, as shares of its width.
const ACROSS: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9]
## The flat deck's lower deck (test data): under the gap in her railing to starboard.
const LOWER := -2.5

var _rules := SimFixtures.rules()
## Each ship's walk graph, built once for both rules.
var _graphs := {}


func before_all() -> void:
	for path: String in SHIPS:
		var layout: ShipLayout = load(path)
		_graphs[path] = WalkGraph.new(layout, Surfaces.new(layout), _rules)


func after_all() -> void:
	_graphs.clear()


func test_below_her_main_deck_every_way_is_room_to_room() -> void:
	for path: String in SHIPS:
		assert_eq(_ways_onto_open_decks(load(path), _graphs[path]), PackedStringArray(), path)


func test_below_her_main_deck_no_stair_or_doorway_opens_onto_floor_no_room_holds() -> void:
	for path: String in SHIPS:
		var graph: WalkGraph = _graphs[path]
		assert_eq(_opened_onto_open_decks(load(path), graph), PackedStringArray(), path)


func test_the_rules_bite() -> void:
	# The flat deck and a deck 2.5 m under it to starboard from z 7, a flight down to it through
	# the gap in her railing, its foot at z 7, and a room on the lower deck from room_from on,
	# test data. From the foot, the deck is the room's. From a quarter past it, the strip
	# before it is no room's: the flight's foot and the room's doorway open onto it, though the
	# graph's ways step over it, the flight's into the room a body's width on. From a metre
	# past it, both of the graph's ways lead onto it too.
	var built := func(room_from: float) -> ShipLayout:
		var layout: ShipLayout = SimFixtures.deck().duplicate()
		var lower := ShipPlatform.new()
		lower.area = Rect2(2.0, 7.0, 2.0, 3.0)
		lower.height = LOWER
		var platforms: Array[ShipPlatform] = [layout.platforms[0], lower]
		layout.platforms = platforms
		var ramp := ShipRamp.new()
		ramp.area = Rect2(2.0, 4.0, 2.0, 3.0)
		ramp.axis = ShipRamp.Axis.Z
		ramp.start_height = 0.0
		ramp.end_height = LOWER
		var ramps: Array[ShipRamp] = [ramp]
		layout.ramps = ramps
		var room := ShipRoom.new()
		room.name = &"store"
		room.area = Rect2(2.0, room_from, 2.0, 10.0 - room_from)
		room.floor_height = LOWER
		var rooms: Array[ShipRoom] = [room]
		layout.rooms = rooms
		return layout
	var found := {}
	for room_from: float in [7.0, 7.25, 8.0]:
		var layout: ShipLayout = built.call(room_from)
		var graph := WalkGraph.new(layout, Surfaces.new(layout), _rules)
		found[room_from] = [
			_ways_onto_open_decks(layout, graph), _opened_onto_open_decks(layout, graph)
		]
	assert_eq(found[7.0], [PackedStringArray(), PackedStringArray()], "the room from the foot")
	assert_eq(found[7.25][0], PackedStringArray(), "the graph's ways a quarter short")
	for room_from: float in [7.25, 8.0]:
		var opened: PackedStringArray = found[room_from][1]
		assert_eq(opened.size(), 2, "%s: the foot and the doorway: %s" % [room_from, opened])
		if opened.size() == 2:
			assert_string_contains(opened[0], "ramp 0's foot")
			assert_string_contains(opened[1], "store's doorway")
	var ways: PackedStringArray = found[8.0][0]
	assert_eq(ways.size(), 2, "the flight and the doorway a metre short: %s" % [ways])
	if ways.size() == 2:
		assert_string_contains(ways[0], "ramp 0 onto the open deck")
		assert_string_contains(ways[1], "a doorway onto the open deck")


## Every way of [param graph]'s onto an open deck under [param layout]'s main deck: each
## portal into a zone no room is, whose platforms stand below her main deck.
func _ways_onto_open_decks(layout: ShipLayout, graph: WalkGraph) -> PackedStringArray:
	var height_of := {}
	for platform in layout.platforms.size():
		height_of[graph.deck_of(platform)] = layout.platforms[platform].height
	var found := PackedStringArray()
	for portal: WalkGraph.Portal in graph.portals():
		var zone := portal.to_zone
		if graph.room_of(zone) != WalkGraph.NONE or height_of.get(zone, 0.0) >= 0.0:
			continue
		var way := "a doorway" if portal.ramp == WalkGraph.NONE else "ramp %d" % portal.ramp
		found.append(
			(
				"%s onto the open deck at %.4f, at %s, %.3f m wide"
				% [way, height_of[zone], portal.exit, portal.half_width * 2.0]
			)
		)
	return found


## Every stair's end and every room's doorway below [param layout]'s main deck that opens
## onto floor no room holds: where, a hair past it across its width, a body stands clear of
## every blocker on a floor [param graph] puts in no room.
func _opened_onto_open_decks(layout: ShipLayout, graph: WalkGraph) -> PackedStringArray:
	var surfaces := graph.surfaces()
	var found := PackedStringArray()
	for ramp in layout.ramps.size():
		var data := layout.ramps[ramp]
		for end in 2:
			var height := data.start_height if end == 0 else data.end_height
			if height >= 0.0:
				continue
			var edge := data.end_edge(end)
			var other := data.end_edge(1 - end)
			var out := ((edge[0] + edge[1]) - (other[0] + other[1])).normalized()
			var at := _open_deck_past(surfaces, graph, edge[0], edge[1], out, height)
			if at != Vector3.INF:
				var low := height < (data.end_height if end == 0 else data.start_height)
				found.append(
					(
						"ramp %d's %s opens onto floor no room holds at %s"
						% [ramp, "foot" if low else "head", at]
					)
				)
	for room: ShipRoom in layout.rooms:
		if room.floor_height >= 0.0:
			continue
		for door in room.doors(surfaces, _rules.crawl_height, _rules.step_height):
			var at := _open_deck_past(
				surfaces, graph, door.from, door.to, door.outward, room.floor_height
			)
			if at != Vector3.INF:
				found.append(
					(
						"the %s's doorway at %s opens onto floor no room holds at %s"
						% [room.name, door.middle(), at]
					)
				)
	return found


## The first point a hair past the line [param from]…[param to] at [param height], the way
## [param out], where a body stands — snug, clear of every blocker and railing, as a bot's
## walks are read (BotFloorWay.SNUG) — on a floor of [param graph]'s in no room; Vector3.INF
## where there is none: no floor, a stair, no room for a body, or a room's floor.
func _open_deck_past(
	surfaces: Surfaces, graph: WalkGraph, from: Vector2, to: Vector2, out: Vector2, height: float
) -> Vector3:
	var snug := _rules.body_radius * BotFloorWay.SNUG
	for share: float in ACROSS:
		var point := from.lerp(to, share) + out * PAST
		var probe := Vector3(point.x, height, point.y)
		var surface := surfaces.under(probe, _rules.step_height)
		if surface == Surfaces.NONE or surfaces.is_ramp(surface):
			continue
		var feet := Vector3(point.x, surfaces.height_at(surface, probe), point.y)
		if graph.room_of(graph.zone_at(feet, surface)) != WalkGraph.NONE:
			continue
		var blocked := surfaces.obstacle_contacts(
			feet, snug, _rules.body_height, _rules.step_height, Surfaces.NONE, _rules.crawl_height
		)
		var railed := surfaces.rail_contacts(
			feet, snug, surface, _rules.step_height, _rules.railing_height
		)
		if blocked.is_empty() and railed.is_empty():
			return feet
	return Vector3.INF
