extends GutTest
## RoomOutlets: what each room's air and steam come out of as she floods (FxPlanner).

const SHIPS: Array[String] = ["freighter", "steamer", "trawler", "tug", "small_titanic"]

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


func _outlets(layout: ShipLayout) -> RoomOutlets:
	return RoomOutlets.new(layout, ShipSpace.new(layout), Surfaces.new(layout), _rules)


func test_only_engine_and_boiler_rooms_have_a_machine() -> void:
	# A cabin's berth or a saloon's table is no machine: only the rooms dressed as
	# machinery — engines, boilers, dynamos — vent machinery steam.
	for ship: String in SHIPS:
		var layout: ShipLayout = load("res://data/ships/%s.tres" % ship)
		var space := ShipSpace.new(layout)
		var outlets := _outlets(layout)
		var machinery := 0
		for index in layout.rooms.size():
			var room := layout.rooms[index]
			var kind := RoomDressing.kind_of(space, room)
			var engine := kind == RoomDressing.Kind.ENGINE or kind == RoomDressing.Kind.BOILER
			var has := not is_nan(outlets.machines[index].x)
			if has:
				assert_true(engine, "%s: %s is no machinery room" % [ship, room.name])
			elif engine and space.machinery_in(room):
				fail_test("%s: %s has no machine" % [ship, room.name])
			machinery += 1 if has else 0
		assert_gt(machinery, 0, "%s keeps her engine room's" % ship)


func test_a_machine_stands_in_its_room_at_its_top() -> void:
	var layout: ShipLayout = load("res://data/ships/freighter.tres")
	var space := ShipSpace.new(layout)
	var outlets := _outlets(layout)
	for index in layout.rooms.size():
		var machine := outlets.machines[index]
		if is_nan(machine.x):
			continue
		var room := layout.rooms[index]
		assert_true(room.area.has_point(Vector2(machine.x, machine.z)))
		var tops: Array[float] = []
		for box: ShipBlocker in space.machinery(room):
			tops.append(box.top)
		assert_has(tops, machine.y, "the top of a machine standing on its floor")
