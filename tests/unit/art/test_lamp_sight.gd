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


func test_a_choice_made_again_after_lamps_go_out_is_one_made_afresh() -> void:
	# The choice hands each room's lamps only what changed, and counts the lamps
	# burning only once one has gone out: what it lights owes nothing to what came before.
	var kept := _sight(GraphicsQuality.Preset.LOW)
	var eyes: Array[Vector3] = [BESIDE_AFT_CABIN, BESIDE_AFT_CABIN + Vector3(6.0, 0.0, 0.0)]
	kept.choose(eyes[0])
	kept.choose(eyes[1])
	for index in kept._lamps.size():
		if index % 2 == 0:
			kept._lamps[index].burning = false
	kept.choose(eyes[0])
	var fresh := _sight(GraphicsQuality.Preset.LOW)
	for index in fresh._lamps.size():
		fresh._lamps[index].burning = kept._lamps[index].burning
	fresh.choose(eyes[0])
	for room in _layout.rooms.size():
		assert_eq(kept.lights(room), fresh.lights(room), "room %d lit alike" % room)
	for index in kept._lamps.size():
		assert_eq(kept._lamps[index].wanted, fresh._lamps[index].wanted, "lamp %d alike" % index)


func test_a_walk_lights_what_a_look_at_every_room_lights() -> void:
	# The choice looks only at the rooms filed near the eye's square (#410), and hands
	# only those it or the last looked at: along a walk over every storey, room after
	# room lit as a look at each one of them lights it, and every lamp wanted alike.
	for preset: int in [GraphicsQuality.Preset.LOW, GraphicsQuality.Preset.HIGH]:
		var walked := _sight(preset)
		for step in 61:
			for height: float in [-1.0, 1.6, 4.2]:
				var eye := Vector3(-30.0 + step, height, 2.5 * sin(step * 0.7))
				walked.choose(eye)
				var looked := _every_room_looked_at(walked, eye)
				for room in _layout.rooms.size():
					assert_eq(
						walked.lights(room), looked[room] == 1, "room %d from %s" % [room, eye]
					)
				for index in walked._lamps.size():
					var wanted: bool = looked[walked._rooms[index]] == 1
					assert_eq(walked._lamps[index].wanted, wanted, "lamp %d from %s" % [index, eye])


## The choice in the game's extension (NativeSight, #410) is the GDScript's: along a walk
## over every storey, on the edges of every room's reach and storey, and as lamps go out,
## the same rooms lit, as far off, and every lamp handed alike, natively and with the
## extension's choice off, as on the web. CI sets SINKING_NATIVE_REQUIRED, so a missing
## library there fails.
func test_the_extension_chooses_as_the_gdscript_does() -> void:
	if not ClassDB.class_exists(&"NativeSight"):
		if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
			fail_test("the extension is not loaded: make native, then make import")
		else:
			pending("the extension is not built here (make native)")
		return
	for preset: int in [GraphicsQuality.Preset.LOW, GraphicsQuality.Preset.HIGH]:
		var sights: Array[LampSight] = [_sight(preset), _sight(preset)]
		sights[1].native = null
		assert_not_null(sights[0].native, "chosen natively")
		var eyes := _eyes(sights[0])
		var differences: Array[String] = []
		for at in eyes.size():
			for sight: LampSight in sights:
				if at == eyes.size() / 2:
					for index in range(0, sight._lamps.size(), 3):
						sight._lamps[index].burning = false
				sight.choose(eyes[at])
			var chosen: Array[PackedByteArray] = []
			for sight: LampSight in sights:
				var wanted := []
				for lamp: ShipLamp in sight._lamps:
					wanted.append(lamp.wanted)
				chosen.append(
					var_to_bytes([sight._lit, sight._reach, sight._handed, sight._looked, wanted])
				)
			if chosen[0] != chosen[1] and differences.size() < 4:
				differences.append("preset %d from %s" % [preset, eyes[at]])
		assert_eq(differences, [] as Array[String], "chosen alike from %d eyes" % eyes.size())


## Eyes along a walk over every storey of the steamer, and on the edges of each room
## [param sight] files: just within its reach either way along her and across her, on
## its storey's margin over and under it, and on its corner.
func _eyes(sight: LampSight) -> Array[Vector3]:
	var eyes: Array[Vector3] = []
	for step in 61:
		for height: float in [-1.0, 1.6, 4.2]:
			eyes.append(Vector3(-30.0 + step, height, 2.5 * sin(step * 0.7)))
	var reach := ShipLamp.REACH
	var margin := ShipLamp.STOREY_MARGIN
	for box: AABB in sight._boxes:
		if not box.has_volume():
			continue
		var middle := box.get_center()
		var low := box.position.y + 1.0
		var edges: Array[Vector3] = [
			Vector3(box.end.x + reach, low, middle.z),
			Vector3(box.position.x - reach, low, middle.z),
			Vector3(middle.x, low, box.end.z + reach),
			Vector3(middle.x, low, box.position.z - reach),
			Vector3(middle.x, box.end.y + margin, middle.z),
			Vector3(middle.x, box.position.y - margin, middle.z),
			Vector3(box.end.x, middle.y, box.end.z),
			Vector3(box.position.x - 3.0, middle.y, box.position.z - 4.0),
		]
		eyes.append_array(edges)
	return eyes


## The rooms [param sight] lights from [param eye], each room looked at, as LampSight
## chose before it filed them by square: 1 lit, 0 not.
func _every_room_looked_at(sight: LampSight, eye: Vector3) -> PackedByteArray:
	var rooms := _layout.rooms.size()
	var lit := PackedByteArray()
	lit.resize(rooms)
	var reach := PackedFloat32Array()
	reach.resize(rooms)
	reach.fill(INF)
	var burning := 0
	for room in rooms:
		var box: AABB = sight._boxes[room]
		if not box.has_volume() or not ShipLamp.relevant(eye, box, true):
			continue
		if sight.sees(eye, room):
			lit[room] = 1
			burning += sight._burning[room]
		else:
			var nearest := eye.clamp(box.position, box.end)
			reach[room] = Vector2(eye.x - nearest.x, eye.z - nearest.z).length()
	while true:
		var next := -1
		for room in rooms:
			if lit[room] == 0 and (next == -1 or reach[room] < reach[next]):
				next = room
		if next == -1 or is_inf(reach[next]) or burning + sight._burning[next] > sight.limit:
			break
		lit[next] = 1
		burning += sight._burning[next]
	return lit
