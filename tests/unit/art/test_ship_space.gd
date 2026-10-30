extends GutTest

const STEAMER := "res://data/ships/steamer.tres"

var _space: ShipSpace


func before_each() -> void:
	_space = ShipSpace.new(load(STEAMER))


func _room(name: StringName) -> ShipRoom:
	for room: ShipRoom in _space.layout.rooms:
		if room.name == name:
			return room
	return null


func test_a_point_inside_a_room_under_its_deck_is_indoors() -> void:
	var engine := _room(&"engine room")
	var middle := engine.area.get_center()
	assert_false(_space.outdoors(Vector3(middle.x, engine.floor_height + 1.0, middle.y)))


func test_a_point_on_the_open_deck_over_a_room_is_outdoors() -> void:
	# Over the steamer's engine room's space, its stokehold reaching to her hold (#74).
	var engine := _room(&"stokehold")
	assert_true(_space.outdoors(Vector3(engine.area.end.x - 0.5, 0.5, 0.0)))


func test_a_piece_crossing_into_a_room_is_indoors_by_the_share_inside() -> void:
	var saloon := _room(&"saloon")
	var at := saloon.floor_height + 0.5
	var edge := saloon.area.end.x
	var square := Rect2(edge - 0.5, -0.5, 1.0, 1.0)
	assert_false(_space.outdoors(Vector3(edge - 0.25, at, 0.0)), "the saloon")
	assert_true(_space.outdoors(Vector3(edge + 0.25, at, 0.0)), "the open deck beside it")
	assert_almost_eq(_space.indoors(square, at), 0.5, 0.001, "half across its side")
	assert_eq(_space.indoors(Rect2(edge - 1.5, -0.5, 1.0, 1.0), at), 1.0, "wholly in")
	assert_eq(_space.indoors(Rect2(edge + 0.5, -0.5, 1.0, 1.0), at), 0.0, "wholly out")
	assert_eq(_space.indoors(square, saloon.floor_height + 4.0), 0.0, "over its roof")


func test_a_deck_s_air_stands_in_the_rooms_on_it_never_in_the_room_under_it() -> void:
	# Half a metre over her main deck along her port side, from her deckhouse's after end
	# to her forecastle: the deckhouse's rooms and the saloon hold it; the hold under the
	# deck, whose ceiling the deck is, does not.
	var rooms := _space.layout.rooms
	var found := _space.rooms_at(Rect2(-7.5, -3.0, 21.0, 0.5), 0.5)
	assert_has(found, rooms.find(_room(&"saloon")), "the saloon on the deck")
	assert_has(found, rooms.find(_room(&"deckhouse hall")), "and the deckhouse's hall")
	assert_does_not_have(found, rooms.find(_room(&"forward hold")), "never the hold under it")
	for index: int in found:
		assert_eq(rooms[index].floor_height, 0.0, "%s stands on the deck" % rooms[index].name)


func test_a_room_s_ceiling_is_the_lowest_deck_over_it() -> void:
	var hold := _room(&"forward hold")
	assert_almost_eq(_space.ceiling(hold, 6.0, -2.0), 0.0, 0.001)
	assert_almost_eq(_space.ceiling(hold, 14.0, -2.0), 1.8, 0.001)


func test_under_a_hatch_a_room_s_ceiling_is_the_deck_the_hatch_is_in() -> void:
	# The steamer's scuttles (#148): under one, no deck of the room's stands over it, but
	# its ceiling is the deck the hatch is in — not open air over its floor, nor the deck
	# over that one.
	var steering := _room(&"steering gear")
	assert_almost_eq(_space.ceiling(steering, -16.0, 0.65), 1.2, 0.001, "the poop's")
	var bosuns := _room(&"bosun's store")
	assert_almost_eq(_space.ceiling(bosuns, 16.0, 2.0), 1.8, 0.001, "the forecastle's")
	var lower_hold := _room(&"lower hold")
	assert_almost_eq(_space.ceiling(lower_hold, 6.0, 2.0), -2.6, 0.001, "the hold's floor")
	assert_almost_eq(_space.ceiling(lower_hold, 6.0, 0.0), -2.6, 0.001, "beside it, the same")


func test_a_room_roofed_by_a_slab_and_no_deck_has_the_slab_for_its_ceiling() -> void:
	# The trawler's wheelhouse: no deck over it, roofed by a slab under OPEN_ROOM_HEIGHT.
	var space := ShipSpace.new(load("res://data/ships/trawler.tres"))
	var middle := Vector2(-6.0, 0.0)
	var wheelhouse: ShipRoom
	for room: ShipRoom in space.layout.rooms:
		var higher := wheelhouse == null or room.floor_height > wheelhouse.floor_height
		if room.area.has_point(middle) and higher:
			wheelhouse = room
	var slab: ShipBlocker
	for blocker: ShipBlocker in space.layout.blockers:
		var thin := blocker.top - blocker.bottom <= ShipSpace.WALL_MAX
		if thin and not space.is_wall(blocker) and blocker.area.has_point(middle):
			slab = blocker
	assert_not_null(slab, "the wheelhouse's roof")
	assert_almost_eq(space.ceiling(wheelhouse, middle.x, middle.y), slab.bottom, 0.001)
	var over := Vector3(middle.x, slab.top + 0.15, middle.y)
	assert_true(space.outdoors(over), "a step over its roof is out in the weather")


func test_a_deck_meeting_a_slab_edge_to_edge_does_not_rest_on_it() -> void:
	# The Titanic's roof over boiler room 4 beside E deck's landing (#300): in single
	# precision the slab's end, 19.18 + 1.62, lies a hair past the landing's start at 20.8.
	var layout := ShipLayout.new()
	var slab := ShipBlocker.new()
	slab.area = Rect2(19.18, -10.0, 1.62, 11.5)
	slab.bottom = -6.1375
	slab.top = -5.9375
	layout.blockers.append(slab)
	var landing := ShipPlatform.new()
	landing.area = Rect2(20.8, -10.0, 12.1, 16.0)
	landing.height = slab.top
	layout.platforms.append(landing)
	assert_false(ShipSpace.new(layout).deck_on(slab), "the landing, edge to edge with it")
	landing.area = Rect2(20.0, -10.0, 12.9, 16.0)
	assert_true(ShipSpace.new(layout).deck_on(slab), "the landing, laid over its end")


func test_a_point_beside_a_wall_is_walled_toward_it_and_not_away() -> void:
	# A wall 0.2 m thick, 0.1 m forward of the point, standing from 0 to 2.5 m.
	var layout := ShipLayout.new()
	var wall := ShipBlocker.new()
	wall.area = Rect2(0.1, -1.0, 0.2, 2.0)
	wall.bottom = 0.0
	wall.top = 2.5
	layout.blockers.append(wall)
	var space := ShipSpace.new(layout)
	assert_true(space.walled(Vector2.ZERO, Vector2.RIGHT, 1.0, 0.35), "the wall forward")
	assert_false(space.walled(Vector2.ZERO, Vector2.LEFT, 1.0, 0.35), "nothing aft")
	assert_false(space.walled(Vector2.ZERO, Vector2.RIGHT, 1.0, 0.05), "out of reach")
	assert_false(space.walled(Vector2.ZERO, Vector2.RIGHT, 3.0, 0.35), "over its top")
	var post := ShipBlocker.new()
	post.shape = ShipBlocker.Shape.CYLINDER
	post.centre = Vector2(0.0, -0.3)
	post.radius = 0.1
	post.top = 2.5
	assert_true(ShipSpace.over(post, Vector2(0.0, -0.35)), "within a post's round")
	assert_false(ShipSpace.over(post, Vector2(0.1, -0.35)), "past it")


func test_a_doorway_is_a_gap_between_wall_runs() -> void:
	var engine := _room(&"engine room")
	var aft: Array = []
	for run: Array in _space.wall_runs(engine):
		if run[0] == 3:
			aft.append(run)
	assert_eq(aft.size(), 2, "the aft bulkhead in two pieces round its doorway")
	assert_almost_eq(aft[1][1] - aft[0][2], 1.1, 0.01, "a 1.1 m doorway")


func test_a_side_of_a_partition_and_a_steel_wall_takes_the_partition_s_face() -> void:
	# A room 10 by 4 m whose z = 4 side is a partition 0.06 m thick to x 8.03, and from x
	# 7.9 the steel of an outer wall 0.2 m thick: one run, its face the partition's — a
	# sconce hung on it stands on the partition, never 0.07 m proud of it as on the steel.
	var layout := ShipLayout.new()
	for area: Rect2 in [Rect2(-0.03, 3.97, 8.06, 0.06), Rect2(7.9, 3.9, 2.2, 0.2)]:
		var wall := ShipBlocker.new()
		wall.area = area
		wall.bottom = 0.0
		wall.top = 2.5
		layout.blockers.append(wall)
	var deck := ShipPlatform.new()
	deck.area = Rect2(-1.0, -1.0, 12.0, 6.0)
	deck.height = 2.5
	layout.platforms.append(deck)
	var room := ShipRoom.new()
	room.area = Rect2(0.0, 0.0, 10.0, 4.0)
	layout.rooms.append(room)
	var runs: Array = []
	for run: Array in ShipSpace.new(layout).wall_runs(room):
		if run[0] == 2:
			runs.append(run)
	assert_eq(runs.size(), 1, "one run, the side's")
	if runs.size() == 1:
		assert_almost_eq(runs[0][3], 0.03, 0.001, "the partition's face")
		assert_almost_eq(runs[0][1], 0.03, 0.001, "from the corner")
		assert_almost_eq(runs[0][2], 9.97, 0.001, "to the corner")


func test_a_hull_side_wall_under_a_deck_stopping_short_of_it_reaches_the_deck_over() -> void:
	# A room 10 by 4 m, its hull-side wall 2.5 m tall; the deck at 2.5 m stops a metre
	# short of that wall, so the room's ceiling along it is the deck at 5 m (#147).
	var space := ShipSpace.new(_strip_layout(false))
	var wall := space.layout.blockers[0]
	var stretches := space.short_of_ceiling(wall)
	assert_eq(stretches.size(), 1, "one stretch, the room's length")
	assert_almost_eq(stretches[0], Vector3(0.0, 10.0, 5.0), Vector3.ONE * 0.001)


func test_a_wall_between_two_rooms_is_never_raised() -> void:
	# The same room with another beside it past the wall: a partition, not a hull side.
	var space := ShipSpace.new(_strip_layout(true))
	assert_eq(space.short_of_ceiling(space.layout.blockers[0]), [] as Array[Vector3])


func test_a_wall_up_to_its_ceiling_is_never_raised() -> void:
	var layout := _strip_layout(false)
	layout.platforms[0].area = Rect2(0.0, 0.0, 10.0, 4.0)
	var space := ShipSpace.new(layout)
	assert_eq(space.short_of_ceiling(layout.blockers[0]), [] as Array[Vector3])


func test_the_small_titanic_s_tall_rooms_reach_their_deckhead_along_her_hull_sides() -> void:
	# The galley's port wall stops at C deck, which stops 1.3 m short of it: A deck, over
	# her side there, roofs it. (The Titanic's traced C deck, #368, reaches her side.)
	var space := ShipSpace.new(Fleet.layout(&"small_titanic"))
	var cases := [
		["the galley's", Rect2(-30.1, -13.1, 16.3, 0.2), 5.5],
	]
	for case: Array in cases:
		var wall := _blocker_at(space.layout, case[1])
		var stretches := space.short_of_ceiling(wall)
		assert_eq(stretches.size(), 1, "%s: one stretch" % case[0])
		if stretches.is_empty():
			continue
		assert_almost_eq(stretches[0].z, case[2], 0.001, "%s: up to its deckhead" % case[0])
		var span := stretches[0].y - stretches[0].x
		assert_gt(span, wall.area.size.x - 0.5, "%s: all along it" % case[0])


## A room 10 m along x and 4 m across from z 0, its floor at 0; along its z = 4 side a
## wall 2.5 m tall (blocker 0); a deck at 2.5 m short of the wall, to z = 3, and one at
## 5 m over all of it; with [param neighbour], a second room past the wall.
func _strip_layout(neighbour: bool) -> ShipLayout:
	var layout := ShipLayout.new()
	var wall := ShipBlocker.new()
	wall.area = Rect2(-0.1, 3.9, 10.2, 0.2)
	wall.bottom = 0.0
	wall.top = 2.5
	layout.blockers.append(wall)
	for deck: Array in [[Rect2(0.0, 0.0, 10.0, 3.0), 2.5], [Rect2(-1.0, -1.0, 12.0, 10.0), 5.0]]:
		var platform := ShipPlatform.new()
		platform.area = deck[0]
		platform.height = deck[1]
		layout.platforms.append(platform)
	for area: Rect2 in [Rect2(0.0, 0.0, 10.0, 4.0), Rect2(0.0, 4.0, 10.0, 4.0)]:
		if area.position.y > 0.0 and not neighbour:
			continue
		var room := ShipRoom.new()
		room.area = area
		layout.rooms.append(room)
	return layout


## [param layout]'s blocker standing on [param area].
func _blocker_at(layout: ShipLayout, area: Rect2) -> ShipBlocker:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.area.is_equal_approx(area):
			return blocker
	assert_true(false, "no blocker on %s" % area)
	return null
