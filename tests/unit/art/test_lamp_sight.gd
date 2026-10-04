extends GutTest
## Which room lamps light a frame (LampSight): on the steamer, with a lamp node per
## light RoomDressing hangs in each room, never in the scene tree.

const STEAMER := "res://data/ships/steamer.tres"
## Rooms of the steamer by index: the engine room (doorways forward and aft, four
## lamps), the cabin corridor aft of it, a cabin off the corridor, the forward hold,
## and a deckhouse cabin a deck up.
const ENGINE_ROOM := 1
const CORRIDOR := 2
const AFT_PORT_CABIN := 3
const FORWARD_HOLD := 0
const DECKHOUSE_CABIN := 11
## Eyes on the lower deck, 1.6 m over its floor: in the engine room; in the corridor
## by the engine room's aft doorway; and on the far side of the aft port cabin's wall
## from the corridor, in the cabin forward of it, whose doorway does not face it.
const IN_ENGINE_ROOM := Vector3(0.5, -1.0, 0.0)
const BY_ENGINE_DOOR := Vector3(-4.0, -1.0, 0.0)
const BESIDE_AFT_CABIN := Vector3(-7.5, -1.0, -3.0)

var _layout: ShipLayout
var _space: ShipSpace


func before_all() -> void:
	_layout = load(STEAMER)
	_space = ShipSpace.new(_layout)


## A sight of the steamer's lamps, as tuned (HIGH) unless [param preset] says.
func _sight(preset := GraphicsQuality.Preset.HIGH) -> LampSight:
	var sight := LampSight.new(_space)
	sight.show_graphics(GraphicsQuality.of(preset))
	var dressing := RoomDressing.new(_space, INF)
	for index in _layout.rooms.size():
		var room := _layout.rooms[index]
		var box := AABB(
			Vector3(room.area.position.x, room.floor_height, room.area.position.y),
			Vector3(room.area.size.x, 2.6, room.area.size.y)
		)
		for _light: RoomDressing.Light in dressing.lights(room):
			sight.add(autofree(ShipLamp.new()), index, box)
	return sight


func test_a_room_s_doorways_are_the_gaps_in_its_full_walls() -> void:
	var sides := LampSight.doorway_sides(_space, _layout.rooms[ENGINE_ROOM])
	assert_eq(sides, PackedInt32Array([1, 3]), "fore and aft, none to either side")
	sides = LampSight.doorway_sides(_space, _layout.rooms[AFT_PORT_CABIN])
	assert_eq(sides, PackedInt32Array([2]), "onto the corridor alone")


func test_the_eye_sees_into_its_own_room_and_through_a_doorway_only() -> void:
	var sight := _sight()
	assert_true(sight.sees(IN_ENGINE_ROOM, ENGINE_ROOM))
	assert_true(sight.sees(BY_ENGINE_DOOR, ENGINE_ROOM), "through its aft doorway")
	assert_false(sight.sees(BESIDE_AFT_CABIN, AFT_PORT_CABIN), "only a wall faces it")
	assert_true(sight.sees(BY_ENGINE_DOOR, AFT_PORT_CABIN), "from the corridor")


func test_as_tuned_every_room_near_the_eye_on_its_storey_lights() -> void:
	var sight := _sight()
	sight.choose(BESIDE_AFT_CABIN)
	assert_true(sight.lights(AFT_PORT_CABIN), "near enough, wall or not")
	assert_true(sight.lights(CORRIDOR))
	assert_false(sight.lights(DECKHOUSE_CABIN), "a deck up")
	for room in _layout.rooms.size():
		var near := ShipLamp.relevant(BESIDE_AFT_CABIN, _box(room), true)
		assert_eq(sight.lights(room), near, "room %d as ShipLamp.relevant says" % room)


func test_a_cheaper_preset_lights_only_the_rooms_in_sight() -> void:
	var sight := _sight(GraphicsQuality.Preset.MEDIUM)
	sight.choose(BESIDE_AFT_CABIN)
	assert_false(sight.lights(AFT_PORT_CABIN), "behind a wall")
	assert_true(sight.lights(4), "the cabin the eye stands in")


func test_the_nearest_rooms_light_first_and_a_room_lights_whole() -> void:
	var sight := _sight(GraphicsQuality.Preset.LOW)
	sight.choose(BY_ENGINE_DOOR)
	assert_true(sight.lights(CORRIDOR), "the eye's own room")
	assert_false(sight.lights(ENGINE_ROOM), "its four lamps would pass the limit")
	var lit := 0
	for room in _layout.rooms.size():
		if sight.lights(room):
			lit += RoomDressing.new(_space, INF).lights(_layout.rooms[room]).size()
	assert_lte(lit, GraphicsQuality.of(GraphicsQuality.Preset.LOW).lamps)

	sight.choose(IN_ENGINE_ROOM)
	assert_true(sight.lights(ENGINE_ROOM), "the eye's own room, however many lamps")


func test_the_default_preset_lights_the_room_through_the_doorway_before_it_is_entered() -> void:
	var sight := _sight(GraphicsQuality.DESKTOP_PRESET)
	sight.choose(BY_ENGINE_DOOR)
	assert_true(sight.lights(CORRIDOR))
	assert_true(sight.lights(ENGINE_ROOM), "already lit as the eye walks in: no pop")


func _box(room: int) -> AABB:
	var area := _layout.rooms[room].area
	return AABB(
		Vector3(area.position.x, _layout.rooms[room].floor_height, area.position.y),
		Vector3(area.size.x, 2.6, area.size.y)
	)
