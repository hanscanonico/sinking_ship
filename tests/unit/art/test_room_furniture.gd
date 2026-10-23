extends GutTest
## The smaller ships' rooms carry tables and benches on their floors, as the liner's do
## (FurnitureDressing): the freighter's officers', crew's and forward cabins, the barque's
## saloon and the trawler's crew mess — before, nothing stood on their floors but their
## walls' dressing. Each is drawn as a table or a bench, no seat starts within a body of
## one, none stands within a body's breadth of a doorway's way in, and none within 1.0 m
## in plan of a pendant, where a body on a table would put its head in the lamp.

## The rooms furnished, by ship: [room, its tables, its benches].
const FURNISHED := {
	&"freighter":
	[
		[&"officers' cabins", 4, 8],
		[&"crew cabins", 2, 4],
		[&"forward cabins", 2, 4],
	],
	&"barque": [[&"saloon", 2, 2]],
	&"trawler": [[&"crew mess", 1, 1]],
}
## How far from a pendant, in plan, furniture stands at least.
const PENDANT_CLEAR := 1.0

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


func test_each_room_has_its_tables_and_benches() -> void:
	for ship: StringName in FURNISHED:
		var layout := Fleet.layout(ship)
		var space := ShipSpace.new(layout)
		for entry: Array in FURNISHED[ship]:
			var room := _room(layout, entry[0])
			var tables := 0
			var benches := 0
			for piece: ShipBlocker in space.furniture(room):
				match FurnitureDressing.piece_of(piece):
					FurnitureDressing.Piece.TABLE:
						tables += 1
					FurnitureDressing.Piece.BENCH:
						benches += 1
			assert_eq(tables, entry[1], "%s's %s: tables" % [ship, entry[0]])
			assert_eq(benches, entry[2], "%s's %s: benches" % [ship, entry[0]])


func test_no_seat_starts_by_the_furniture() -> void:
	for ship: StringName in FURNISHED:
		var layout := Fleet.layout(ship)
		var space := ShipSpace.new(layout)
		for room: ShipRoom in layout.rooms:
			for piece: ShipBlocker in space.furniture(room):
				var round := piece.area.grow(_rules.body_radius)
				for seat: Vector3 in layout.spawns:
					var on := round.has_point(Vector2(seat.x, seat.z))
					on = on and absf(seat.y - room.floor_height) < 0.5
					assert_false(on, "%s's seat at %s by %s" % [ship, seat, piece.area])


func test_no_doorway_or_pendant_is_crowded() -> void:
	for ship: StringName in FURNISHED:
		var layout := Fleet.layout(ship)
		var space := ShipSpace.new(layout)
		var dressing := RoomDressing.new(space)
		for entry: Array in FURNISHED[ship]:
			var room := _room(layout, entry[0])
			var ways: Array[Rect2] = []
			for side in 4:
				for gap: Vector2 in RoomDressing._gaps(room, side, space.wall_runs(room)):
					ways.append(_way_in(room, side, gap))
			for piece: ShipBlocker in space.furniture(room):
				for way: Rect2 in ways:
					var named := (
						"%s's %s: %s in a doorway's way %s" % [ship, room.name, piece.area, way]
					)
					assert_false(piece.area.intersects(way), named)
				for light: RoomDressing.Light in dressing.lights(room):
					var lamp := Vector2(light.at.x, light.at.z)
					var nearest := lamp.clamp(piece.area.position, piece.area.end)
					var named := "%s's %s: %s by its pendant" % [ship, room.name, piece.area]
					assert_true(nearest.distance_to(lamp) >= PENDANT_CLEAR, named)


## The ship-plane strip a body takes into [param room] through the doorway [param gap]
## along its [param side]: a body's breadth either side of it, a body's breadth deep.
func _way_in(room: ShipRoom, side: int, gap: Vector2) -> Rect2:
	var breadth := _rules.body_radius * 2.0
	var area := room.area
	match side:
		0:
			return Rect2(gap.x - breadth, area.position.y, gap.y - gap.x + breadth * 2.0, breadth)
		2:
			var z := area.end.y - breadth
			return Rect2(gap.x - breadth, z, gap.y - gap.x + breadth * 2.0, breadth)
		1:
			var x := area.end.x - breadth
			return Rect2(x, gap.x - breadth, breadth, gap.y - gap.x + breadth * 2.0)
	return Rect2(area.position.x, gap.x - breadth, breadth, gap.y - gap.x + breadth * 2.0)


func _room(layout: ShipLayout, room_name: StringName) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		if room.name == room_name:
			return room
	return null
