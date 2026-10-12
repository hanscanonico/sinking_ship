extends GutTest
## LinerService on the Titanic and the trawler: the rooms of service — her galley,
## gymnasium, purser's office and post office, the trawler's galley — each dressed by
## its name, a galley's pans hung overhead along its walls, and nothing it draws
## standing in a body's way.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

## The faces each room's furnishings had before it was dressed as a room of service —
## a saloon's clock, pictures and curtains, or nothing (main 71002e8, _in()).
const BEFORE := {
	&"galley": 174,
	&"gymnasium": 486,
	&"purser's office": 0,
	&"post office": 0,
}
const TRAWLER_GALLEY_BEFORE := 440

var _rules: BrawlRules
var _titanic: ShipLayout
var _faces: PackedVector3Array
var _trawler: ShipLayout
var _trawler_faces: PackedVector3Array


func before_all() -> void:
	_rules = RunMatch.default_config(1701).rules
	_titanic = load("res://data/ships/titanic.tres")
	_faces = _furnishings(_titanic)
	_trawler = load("res://data/ships/trawler.tres")
	_trawler_faces = _furnishings(_trawler)


## Every face of the furnishings [param layout]'s ShipArt draws (FurnishingCheck).
func _furnishings(layout: ShipLayout) -> PackedVector3Array:
	var art := ShipArt.new()
	art.build(layout, _rules.railing_height, _rules.body_radius)
	var faces := FurnishingCheck.furnishings(art)
	art.free()
	return faces


## The room of [param layout] named [param room_name].
func _room(layout: ShipLayout, room_name: StringName) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		if room.name == room_name:
			return room
	return null


## The middles of those of [param faces] standing in [param room] of [param space]:
## over its floor and under its ceiling.
func _in(space: ShipSpace, faces: PackedVector3Array, room: ShipRoom) -> PackedVector3Array:
	var index := space.layout.rooms.find(room)
	var found := PackedVector3Array()
	for at in range(0, faces.size(), 3):
		var middle := (faces[at] + faces[at + 1] + faces[at + 2]) / 3.0
		if RoomDressing.room_at(space, middle) == index:
			found.append(middle)
	return found


func test_nothing_the_titanic_s_dressing_draws_stands_in_a_body_s_way() -> void:
	assert_gt(_faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_titanic, _rules, _faces), PackedStringArray())


func test_nothing_the_trawler_s_dressing_draws_stands_in_a_body_s_way() -> void:
	assert_gt(_trawler_faces.size(), 0)
	var found := FurnishingCheck.intrusions(_trawler, _rules, _trawler_faces)
	assert_eq(found, PackedStringArray())


func test_each_of_her_rooms_of_service_is_dressed_more_than_it_was() -> void:
	var space := ShipSpace.new(_titanic)
	for room_name: StringName in BEFORE:
		var count := _in(space, _faces, _room(_titanic, room_name)).size()
		assert_gt(count, BEFORE[room_name], String(room_name))


func test_the_trawler_s_galley_is_dressed_more_than_it_was() -> void:
	var space := ShipSpace.new(_trawler)
	var count := _in(space, _trawler_faces, _room(_trawler, &"galley")).size()
	assert_gt(count, TRAWLER_GALLEY_BEFORE)


func test_a_galley_hangs_pans_overhead_along_each_full_wall() -> void:
	var galleys: Array[Array] = [[_titanic, _faces], [_trawler, _trawler_faces]]
	for galley: Array in galleys:
		var layout: ShipLayout = galley[0]
		var space := ShipSpace.new(layout)
		var room := _room(layout, &"galley")
		var middles := _in(space, galley[1], room)
		for wall: RoomDressing.Wall in RoomDressing.walls(space, room):
			if wall.length() < LinerService.RACK_BAY * 2.0:
				continue
			var hung := 0
			for middle: Vector3 in middles:
				var out := (middle - wall.at(wall.middle(), 0.0)).dot(wall.normal)
				var along := middle.x if wall.side % 2 == 0 else middle.z
				var overhead := middle.y > room.floor_height + RoomDressing.HEADROOM
				var on_the_rack := absf(out - LinerService.RACK_OUT) < 0.05
				if overhead and on_the_rack and along > wall.from and along < wall.to:
					hung += 1
			assert_gt(hung, 0, "%s: side %d" % [layout.resource_path, wall.side])


func test_away_from_its_walls_a_room_of_service_is_dressed_only_overhead_or_underfoot() -> void:
	var ships: Array[Array] = [[_titanic, _faces], [_trawler, _trawler_faces]]
	for ship: Array in ships:
		var layout: ShipLayout = ship[0]
		var space := ShipSpace.new(layout)
		for room: ShipRoom in layout.rooms:
			if RoomDressing.kind_of(space, room) != RoomDressing.Kind.SERVICE:
				continue
			var middle_of := room.area.grow(-0.25)
			var stray := 0
			for middle: Vector3 in _in(space, ship[1], room):
				if not middle_of.has_point(Vector2(middle.x, middle.z)):
					continue
				var height := middle.y - room.floor_height
				if height > 0.01 and height < RoomDressing.HEADROOM - ShipMesh.SLIVER:
					stray += 1
			assert_eq(stray, 0, String(room.name))
