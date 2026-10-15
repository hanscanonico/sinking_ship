extends GutTest
## LinerBoiler and EngineRoom's lamps: the steamer's stokehold and the trawler's
## engine room lit where they always were, and the Titanic's boiler rooms 2–5 lit over
## their firing aisles, no lamp hung inside a boiler.

const RunMatch := preload("res://tools/run_match.gd")

const BOILER_ROOMS: Array[StringName] = [
	&"boiler room 2", &"boiler room 3", &"boiler room 4", &"boiler room 5"
]
## How far in plan a pendant hangs from a boiler, at least (EngineRoom.LAMP_CLEAR).
const CLEAR := 0.3

var _titanic: ShipLayout
var _space: ShipSpace


func before_all() -> void:
	_titanic = load("res://data/ships/titanic.tres")
	_space = ShipSpace.new(_titanic)


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _titanic.rooms:
		if room.name == room_name:
			return room
	return null


## [param ship_name]'s room [param room_name] and the lights RoomDressing hangs in it.
func _lights(ship_name: String, room_name: StringName) -> Array[RoomDressing.Light]:
	var layout: ShipLayout = load("res://data/ships/%s.tres" % ship_name)
	var space := ShipSpace.new(layout)
	for room: ShipRoom in layout.rooms:
		if room.name == room_name:
			return RoomDressing.new(space).lights(room)
	var none: Array[RoomDressing.Light] = []
	return none


## [param lights] are [param pinned], each [kind, where], in order.
func _assert_lit(lights: Array[RoomDressing.Light], pinned: Array[Array], what: String) -> void:
	assert_eq(lights.size(), pinned.size(), what)
	for index in mini(lights.size(), pinned.size()):
		assert_eq(lights[index].kind, pinned[index][0], "%s %d" % [what, index])
		var off := lights[index].at.distance_to(pinned[index][1] as Vector3)
		assert_lt(off, 0.001, "%s %d at %s" % [what, index, lights[index].at])


func test_the_steamer_s_stokehold_is_lit_where_it_was() -> void:
	var pinned: Array[Array] = [
		[ShipLamp.Kind.PENDANT, Vector3(1.875, -0.06, -2.15)],
		[ShipLamp.Kind.PENDANT, Vector3(1.875, -0.06, 2.15)],
		[ShipLamp.Kind.FIRE, Vector3(3.9, -3.78, -1.85)],
		[ShipLamp.Kind.FIRE, Vector3(3.9, -3.78, 1.85)],
	]
	_assert_lit(_lights("steamer", &"stokehold"), pinned, "stokehold")


func test_the_trawler_s_engine_room_is_lit_where_it_was() -> void:
	var pinned: Array[Array] = [
		[ShipLamp.Kind.PENDANT, Vector3(-10.25, -0.06, 0.0)],
		[ShipLamp.Kind.PENDANT, Vector3(-5.4, -0.06, 0.0)],
		[ShipLamp.Kind.FIRE, Vector3(-3.1, -1.58, -1.625)],
		[ShipLamp.Kind.FIRE, Vector3(-3.1, -1.58, 1.625)],
	]
	_assert_lit(_lights("trawler", &"engine room"), pinned, "engine room")

