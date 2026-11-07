extends GutTest
## A room's floor in the pieces a body walks between (WalkPieces, #501). On the Titanic, the
## passage at the foot of E deck's after stairs is cut by three flights side by side: a route
## through it from one side to the other walked a bot into them for good, so each side is a
## zone of its own, each one a route reaches. A piece no route from her main deck reaches is
## put back into its room as it was: the windlass machinery room under her forecastle, its
## starboard side shut off by the machinery from the doorway aft of it, and the steamer's
## aft stores, between the railed wells of her stairs down to the lower aft stores.

const TITANIC := "res://data/ships/titanic.tres"
const E_DECK := -5.9375
const FORECASTLE_DECK := 1.5625
## E deck's after passage: off the foot of the stair up to D deck forward of B, and off the
## head of the stair down to F deck, beside the stair down from D deck aft of B.
const OFF_THE_STAIR_UP := Vector3(103.0, E_DECK, -2.55)
const OFF_THE_STAIR_DOWN := Vector3(101.9375, E_DECK, 3.0)
## The windlass machinery room's forward end, starboard and port of the machinery.
const STARBOARD_OF_THE_WINDLASS := Vector3(122.5, FORECASTLE_DECK, -2.75)
const PORT_OF_THE_WINDLASS := Vector3(122.5, FORECASTLE_DECK, 2.75)
## The steamer's aft stores: between her wells, and by the foot of a stair down into them.
const STEAMER_STORES := -3.1
const BETWEEN_THE_WELLS := Vector3(-17.5, STEAMER_STORES, 0.0)
const BY_THE_STAIR_FOOT := Vector3(-15.2, STEAMER_STORES, -2.0)

var _rules := SimFixtures.rules()


## The graph's zone at [param at] on [param graph]'s ship.
func _zone(graph: WalkGraph, at: Vector3) -> int:
	return graph.zone_at(at, graph.surfaces().under(at, _rules.step_height))


## The room of [param layout] whose floor [param at] stands on.
func _room(layout: ShipLayout, at: Vector3) -> int:
	for room in layout.rooms.size():
		var data := layout.rooms[room]
		if (
			data.area.has_point(Vector2(at.x, at.z))
			and absf(data.floor_height - at.y) <= _rules.step_height
		):
			return room
	return WalkGraph.NONE


## Whether a route from [param graph]'s main deck reaches [param zone], her held dry and level.
func _reached(graph: WalkGraph, layout: ShipLayout, zone: int) -> bool:
	var level := HeldPose.flooded(layout, -layout.freeboard, {})
	for index in layout.platforms.size():
		if is_zero_approx(layout.platforms[index].height):
			var middle := layout.platforms[index].area.get_center()
			var start := Vector3(middle.x, 0.0, middle.y)
			var surface := graph.surfaces().under(start, _rules.step_height)
			return not graph.route(start, surface, zone, level).is_empty()
	return false


func test_a_passage_three_flights_cut_is_two_zones_a_route_reaches() -> void:
	var layout: ShipLayout = load(TITANIC)
	var graph := WalkGraph.new(layout, Surfaces.new(layout), _rules)
	var up := _zone(graph, OFF_THE_STAIR_UP)
	var down := _zone(graph, OFF_THE_STAIR_DOWN)
	assert_ne(up, down, "a zone either side of the flights")
	var room := _room(layout, OFF_THE_STAIR_UP)
	assert_eq(layout.rooms[room].name, "passage, E deck aft")
	assert_eq(graph.room_of(up), room, "both of the passage")
	assert_eq(graph.room_of(down), room)
	assert_true(_reached(graph, layout, up), "a route to the one")
	assert_true(_reached(graph, layout, down), "and to the other")


## Read on its own, the room splits; in the graph, the piece no route reaches is its room's.
func _assert_held_whole(layout: ShipLayout, one: Vector3, other: Vector3) -> void:
	var surfaces := Surfaces.new(layout)
	var room := _room(layout, one)
	assert_eq(_room(layout, other), room, "one room")
	var pieces := WalkPieces.new(layout, surfaces, _rules)
	assert_ne(
		pieces.zone(room, Vector2(one.x, one.z)),
		pieces.zone(room, Vector2(other.x, other.z)),
		"read in pieces"
	)
	var graph := WalkGraph.new(layout, surfaces, _rules)
	assert_eq(_zone(graph, one), _zone(graph, other), "%s held whole" % layout.rooms[room].name)
	assert_true(_reached(graph, layout, _zone(graph, one)), "a route to it")


func test_a_room_whose_side_no_route_reaches_is_held_whole() -> void:
	_assert_held_whole(load(TITANIC), STARBOARD_OF_THE_WINDLASS, PORT_OF_THE_WINDLASS)


func test_a_room_cut_between_railed_wells_is_held_whole() -> void:
	_assert_held_whole(load(SimFixtures.STEAMER), BETWEEN_THE_WELLS, BY_THE_STAIR_FOOT)


## The extension reads a room's squares as the GDScript does, square for square.
func test_a_room_s_squares_are_read_alike_in_the_extension() -> void:
	if not ClassDB.class_exists(&"NativeCrates"):
		if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
			fail_test("the extension is not loaded: make native, then make import")
		else:
			pending("the extension is not built here (make native)")
		return
	var layout: ShipLayout = load(TITANIC)
	var surfaces := Surfaces.new(layout)
	var pieces := WalkPieces.new(layout, surfaces, _rules)
	ContactsNative.off = true
	var twin := Surfaces.new(layout)
	ContactsNative.off = false
	assert_null(twin.native, "its twin answers in GDScript")
	var room := _room(layout, OFF_THE_STAIR_UP)
	var area := layout.rooms[room].area
	var height := layout.rooms[room].floor_height
	for side: float in [WalkPieces.CELL, WalkPieces.FINE]:
		var origin := (area.position / side).floor() * side
		var width := ceili((area.end.x - origin.x) / side)
		var depth := ceili((area.end.y - origin.y) / side)
		var native := pieces._stands_grid(origin, width, depth, side, height, area)
		pieces._surfaces = twin
		var script := pieces._stands_grid(origin, width, depth, side, height, area)
		pieces._surfaces = surfaces
		assert_eq(native, script, "over squares %s across" % side)
		assert_gt(native.count(1), 0, "some a body stands on")
