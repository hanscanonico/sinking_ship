extends GutTest
## LinerBerths on the Titanic: berths hung one after another along every stretch of
## her berths' and quarters' walls long enough, none across a doorway or over a stair,
## under a budget, every third with its washstand — and nothing they draw stands in a
## body's way. Her ShipArt is built once, for every test.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

## Her block of berths' faces on main before LinerBerths drew its own: the old
## lower-deck cabin's single berth set, in the officers' quarters only — the berths
## and the crew's quarters found no hull wall and drew nothing.
const BEFORE := {
	&"officers' quarters": 1806,
	&"third-class berths": 0,
	&"crew quarters": 0,
}
## The most berths she may hang, all her blocks of berths together.
const BUDGET := 200
## The most faces a block of berths may stand in all, its modelled berths
## (RoomDressing.BERTH_MODEL) and their chains too: the third-class berths, the
## worst, draw 7964.
const CEILING := 8500

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace
var _faces: PackedVector3Array


func before_all() -> void:
	_layout = load("res://data/ships/titanic.tres")
	_rules = RunMatch.default_config(1701).rules
	_space = ShipSpace.new(_layout)
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	_faces = FurnishingCheck.furnishings(art)
	art.free()


## Her rooms LinerBerths dresses.
func _berths() -> Array[ShipRoom]:
	var found: Array[ShipRoom] = []
	for room: ShipRoom in _layout.rooms:
		if RoomDressing.kind_of(_space, room) == RoomDressing.Kind.BERTHS:
			found.append(room)
	return found


## How many of the furnishings' faces stand in [param room]: their middle over its
## area, from its floor to its deckhead.
func _faces_in(room: ShipRoom) -> int:
	var count := 0
	for index in range(0, _faces.size(), 3):
		var middle := (_faces[index] + _faces[index + 1] + _faces[index + 2]) / 3.0
		if not room.area.has_point(Vector2(middle.x, middle.z)):
			continue
		var ceiling := _space.ceiling(room, middle.x, middle.z)
		if middle.y >= room.floor_height - 0.01 and middle.y <= ceiling:
			count += 1
	return count


func test_her_blocks_of_berths_are_the_three_she_has() -> void:
	var names := PackedStringArray()
	for room: ShipRoom in _berths():
		names.append(String(room.name))
	names.sort()
	assert_eq(
		names, PackedStringArray(["crew quarters", "officers' quarters", "third-class berths"])
	)


func test_nothing_her_dressing_draws_stands_in_a_body_s_way() -> void:
	assert_gt(_faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, _faces), PackedStringArray())


func test_each_block_of_berths_is_furnished_more_than_before() -> void:
	for room: ShipRoom in _berths():
		assert_gt(_faces_in(room), BEFORE[room.name], String(room.name))


func test_each_block_of_berths_stands_under_its_ceiling_berths_and_all() -> void:
	for room: ShipRoom in _berths():
		assert_lt(_faces_in(room), CEILING, String(room.name))


func test_she_hangs_a_dozen_berths_a_block_and_under_the_budget_in_all() -> void:
	var total := 0
	for room: ShipRoom in _berths():
		var count := LinerBerths.spots(_space, room).size()
		assert_gte(count, 12, String(room.name))
		total += count
	assert_lt(total, BUDGET)


func test_berths_hang_a_pitch_apart_along_a_wall_clear_of_doorways_and_stairs() -> void:
	var berth := RoomDressing.BERTH
	for room: ShipRoom in _berths():
		var last := {}
		for spot: LinerBerths.Spot in LinerBerths.spots(_space, room):
			var wall := spot.wall
			var label := "%s side %d at %.2f" % [room.name, wall.side, spot.from]
			# On its wall's own run, so never across the gap of a doorway.
			assert_gte(spot.from, wall.from + LinerBerths.DOORWAY - 0.001, label)
			assert_lte(spot.from + berth.x, wall.to - LinerBerths.DOORWAY + 0.001, label)
			var area := wall.rect(spot.from, spot.from + berth.x, 0.0, berth.y)
			var floor := room.floor_height
			assert_false(RoomDressing.over_a_ramp(_layout, area, floor - 0.5, floor + 2.4), label)
			if last.has(wall):
				assert_gte(spot.from - last[wall], LinerBerths.PITCH - 0.001, label)
			last[wall] = spot.from


func test_the_third_class_berths_skip_the_stairs_beside_their_walls() -> void:
	# Two stairs up to E deck stand against her side walls, x 73 to 76.4.
	for room: ShipRoom in _berths():
		if room.name != &"third-class berths":
			continue
		for spot: LinerBerths.Spot in LinerBerths.spots(_space, room):
			if spot.wall.side % 2 == 0:
				var a := spot.from
				var b := spot.from + RoomDressing.BERTH.x
				assert_true(b <= 73.0 or a >= 76.4, "berth over a stair at %.2f" % a)
