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
## by the engine room's aft doorway, and halfway down it, looking at that doorway past
## six cabins' doors; and on the far side of the aft port cabin's wall from the
## corridor, in the cabin forward of it, whose doorway does not face it.
const IN_ENGINE_ROOM := Vector3(0.5, -1.0, 0.0)
const BY_ENGINE_DOOR := Vector3(-4.0, -1.0, 0.0)
const DOWN_THE_CORRIDOR := Vector3(-6.5, -1.0, 0.0)
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


func test_the_cheapest_preset_never_darkens_a_room_in_sight() -> void:
	var sight := _sight(GraphicsQuality.Preset.LOW)
	for eye: Vector3 in [IN_ENGINE_ROOM, BY_ENGINE_DOOR, DOWN_THE_CORRIDOR]:
		sight.choose(eye)
		for room in _layout.rooms.size():
			if ShipLamp.relevant(eye, _box(room), true) and sight.sees(eye, room):
				assert_true(sight.lights(room), "room %d, in sight from %s" % [room, eye])
	sight.choose(DOWN_THE_CORRIDOR)
	assert_true(sight.lights(ENGINE_ROOM), "down the corridor, past the cabins' lamps")


func test_the_cheapest_preset_lights_rooms_out_of_sight_only_within_its_limit() -> void:
	var sight := _sight(GraphicsQuality.Preset.LOW)
	sight.choose(BESIDE_AFT_CABIN)
	assert_false(sight.lights(AFT_PORT_CABIN), "behind a wall, the limit spent in sight")
	assert_true(sight.lights(4), "the cabin the eye stands in")
	var in_sight := 0
	var lit := 0
	var dressing := RoomDressing.new(_space, INF)
	for room in _layout.rooms.size():
		var lamps := dressing.lights(_layout.rooms[room]).size()
		if sight.lights(room):
			lit += lamps
			if sight.sees(BESIDE_AFT_CABIN, room):
				in_sight += lamps
	assert_lte(lit, maxi(in_sight, GraphicsQuality.of(GraphicsQuality.Preset.LOW).lamps))


func test_every_preset_lights_the_room_down_the_corridor_before_it_is_entered() -> void:
	for preset: int in GraphicsQuality.Preset.values():
		var sight := _sight(preset)
		for eye: Vector3 in [DOWN_THE_CORRIDOR, BY_ENGINE_DOOR]:
			sight.choose(eye)
			var name := GraphicsQuality.title(preset)
			assert_true(sight.lights(CORRIDOR), "%s from %s" % [name, eye])
			assert_true(sight.lights(ENGINE_ROOM), "%s from %s: no pop at its door" % [name, eye])


func test_the_default_preset_lights_every_lamp_the_tuned_look_does() -> void:
	var tuned := _sight()
	var default := _sight(GraphicsQuality.DESKTOP_PRESET)
	for eye: Vector3 in [IN_ENGINE_ROOM, BY_ENGINE_DOOR, DOWN_THE_CORRIDOR, BESIDE_AFT_CABIN]:
		tuned.choose(eye)
		default.choose(eye)
		for room in _layout.rooms.size():
			assert_eq(default.lights(room), tuned.lights(room), "room %d from %s" % [room, eye])


func _box(room: int) -> AABB:
	var area := _layout.rooms[room].area
	return AABB(
		Vector3(area.position.x, _layout.rooms[room].floor_height, area.position.y),
		Vector3(area.size.x, 2.6, area.size.y)
	)
