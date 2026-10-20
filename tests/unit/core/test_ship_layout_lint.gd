extends GutTest
## §5's layout lint, run over every layout under data/ships/ and every ship's baked
## authoring scene: it holds the shape of a ship, not any one ship's numbers.

const SHIPS := "res://data/ships"
const AUTHORING := "res://authoring"
## §5: doors are openings about 1.1 m wide; none narrower than a metre.
const MIN_DOOR := 1.0
## A wall is a box blocker this thin, or thinner (§5: walls are 0.2 m).
const WALL := 0.2
## How far apart the headroom rule looks over a room's floor.
const HEADROOM_STEP := 0.25


## Every layout under data/ships/, by path, and every ship drawn under authoring/ as a
## scene, as her scene bakes (SH17), by the scene's path.
func _layouts() -> Dictionary:
	var layouts := {}
	for file: String in DirAccess.get_files_at(SHIPS):
		if file.ends_with(".tres"):
			layouts["%s/%s" % [SHIPS, file]] = load("%s/%s" % [SHIPS, file])
	for ship: String in DirAccess.get_directories_at(AUTHORING):
		var scene := "%s/%s/%s.tscn" % [AUTHORING, ship, ship]
		if ResourceLoader.exists(scene):
			layouts[scene] = ShipSceneBake.of_scene(scene).layout
	return layouts


## How many ramps join each open deck of [param layout] — the platforms of one
## height that touch — by the deck's zone in [param graph].
func _routes(layout: ShipLayout, surfaces: Surfaces, graph: WalkGraph) -> PackedInt32Array:
	var routes := PackedInt32Array()
	routes.resize(graph.zone_count())
	for ramp in layout.ramps.size():
		for platform: int in surfaces.joins(surfaces.ramp_surface(ramp)):
			if platform != Surfaces.NONE:
				routes[graph.deck_of(platform)] += 1
	return routes


func _graph(layout: ShipLayout, surfaces: Surfaces) -> WalkGraph:
	return WalkGraph.new(layout, surfaces, SimFixtures.rules())


## The thin box blockers of [param layout]: its walls, and the lintels over doors.
func _walls(layout: ShipLayout) -> Array[ShipBlocker]:
	var walls: Array[ShipBlocker] = []
	for blocker: ShipBlocker in layout.blockers:
		var size := blocker.area.size
		if blocker.shape == ShipBlocker.Shape.BOX and minf(size.x, size.y) <= WALL + 0.001:
			walls.append(blocker)
	return walls


## Every point of [param layout]'s rooms' floors without the headroom its room needs
## (BrawlRules.headroom), described: every room's floor has headroom to stand, or headroom
## between the rules' crawl_height and standing and is marked a crawl space — and a
## room marked one has somewhere too low to stand. It looks every HEADROOM_STEP over the
## floor of each room, on its platforms, where a body's middle can be: a body's radius
## in from the middle of its walls.
func _headroom_problems(layout: ShipLayout) -> PackedStringArray:
	var rules := SimFixtures.rules()
	var step := rules.step_height
	var surfaces := Surfaces.new(layout)
	var found := PackedStringArray()
	for room: ShipRoom in layout.rooms:
		var inner := room.area.grow(-(rules.body_radius + WALL * 0.5))
		var crawled := false
		var x := inner.position.x
		while x <= inner.end.x:
			var z := inner.position.y
			while z <= inner.end.y:
				var feet := Vector3(x, room.floor_height, z)
				var under := surfaces.under(feet, step)
				z += HEADROOM_STEP
				if under == Surfaces.NONE or under >= surfaces.platform_count():
					continue
				feet.y = surfaces.height_at(under, feet)
				var headroom := rules.headroom(surfaces, feet)
				if headroom < rules.crawl_height:
					found.append(
						"%s: %.2f m over %s, too low to crawl" % [room.name, headroom, feet]
					)
				elif headroom < rules.body_height and not room.crawl_space:
					found.append(
						"%s: %.2f m over %s, not a crawl space" % [room.name, headroom, feet]
					)
				crawled = crawled or headroom < rules.body_height
			x += HEADROOM_STEP
		if room.crawl_space and not crawled:
			found.append("%s: a crawl space with headroom to stand everywhere" % room.name)
	return found


## The first platform standing at the main deck's height — the origin's (D6).
func _main_deck(layout: ShipLayout) -> int:
	for index in layout.platforms.size():
		if is_zero_approx(layout.platforms[index].height):
			return index
	return Surfaces.NONE


func test_layouts_are_found() -> void:
	var layouts := _layouts()
	assert_true(layouts.has(SimFixtures.FLAT_DECK))
	assert_true(layouts.has(SimFixtures.STEAMER))


func test_ramps_join_platforms_at_their_heights() -> void:
	var layouts := _layouts()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		for ramp in layout.ramps.size():
			var joined := surfaces.joins(surfaces.ramp_surface(ramp))
			var heights := [layout.ramps[ramp].start_height, layout.ramps[ramp].end_height]
			for end in 2:
				assert_ne(
					joined[end],
					Surfaces.NONE,
					"%s: ramp %d end %d joins nothing" % [path, ramp, end]
				)
				if joined[end] != Surfaces.NONE:
					assert_eq(layout.platforms[joined[end]].height, heights[end])
			assert_ne(joined[0], joined[1], "%s: ramp %d joins two platforms" % [path, ramp])


func test_spawns_stand_on_platforms() -> void:
	var layouts := _layouts()
	var step := SimFixtures.rules().step_height
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		for spawn: Vector3 in layout.spawns:
			var surface := surfaces.under(spawn, step)
			assert_ne(surface, Surfaces.NONE, "%s: spawn %s stands on nothing" % [path, spawn])
			if surface == Surfaces.NONE:
				continue
			assert_false(surfaces.is_ramp(surface), "%s: spawn %s is on a ramp" % [path, spawn])
			assert_almost_eq(
				surfaces.height_at(surface, spawn), spawn.y, 0.0001, "%s: spawn %s" % [path, spawn]
			)


## A body set down at a seat stands clear: no blocker, crate or edge — a table, a
## bench, a wall — holds it back where it starts.
func test_spawns_stand_clear_of_every_blocker() -> void:
	var layouts := _layouts()
	var rules := SimFixtures.rules()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		for spawn: Vector3 in layout.spawns:
			var contacts := surfaces.obstacle_contacts(
				spawn, rules.body_radius, rules.body_height, rules.step_height
			)
			assert_true(contacts.is_empty(), "%s: spawn %s is held back" % [path, spawn])


func test_no_overlapping_same_height_platforms() -> void:
	var layouts := _layouts()
	for path: String in layouts:
		var platforms: Array[ShipPlatform] = (layouts[path] as ShipLayout).platforms
		for first in platforms.size():
			for second in range(first + 1, platforms.size()):
				var a := platforms[first]
				var b := platforms[second]
				var same_height := is_equal_approx(a.height, b.height)
				# Rectangles are single precision: two that abut may meet by a hair.
				assert_false(
					same_height and a.area.grow(-0.001).intersects(b.area),
					"%s: platforms %d and %d overlap" % [path, first, second]
				)


func test_every_elevated_platform_has_a_ramp() -> void:
	# A deck may be several platforms that touch (the main deck round its stair
	# openings): the deck needs a ramp, not each of its rectangles.
	var layouts := _layouts()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		var graph := _graph(layout, surfaces)
		var routes := _routes(layout, surfaces, graph)
		var lowest := INF
		for platform: ShipPlatform in layout.platforms:
			lowest = minf(lowest, platform.height)
		for index in layout.platforms.size():
			if layout.platforms[index].height > lowest:
				assert_gt(
					routes[graph.deck_of(index)], 0, "%s: platform %d has no ramp" % [path, index]
				)


func test_poop_deck_has_two_routes() -> void:
	var layouts := _layouts()
	var poop_decks := 0
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		var graph := _graph(layout, surfaces)
		var routes := _routes(layout, surfaces, graph)
		for index in layout.platforms.size():
			if layout.platforms[index].name == &"poop deck":
				poop_decks += 1
				assert_gte(
					routes[graph.deck_of(index)], 2, "%s: the poop deck needs two routes" % path
				)
	assert_gt(poop_decks, 0, "the steamer has a poop deck")


## The perches of [param layout] under [param scenario]'s sinking with fewer than two
## routes, by name. A perch is a platform that, at some second of the sinking, is the
## highest one standing and dry.
func _lone_perches(layout: ShipLayout, scenario: SinkScenario) -> Array[StringName]:
	var surfaces := Surfaces.new(layout)
	var graph := _graph(layout, surfaces)
	var routes := _routes(layout, surfaces, graph)
	var schedule := SinkSchedule.new(
		scenario, layout.freeboard, SeedStreams.derive(1, "sink"), layout.structure
	)
	var lone: Array[StringName] = []
	for tick in range(0, schedule.end_tick(), Ticks.RATE):
		var pose := schedule.pose_at(tick)
		surfaces.honour(pose)
		var perch := surfaces.highest_platform(pose)
		if perch == Surfaces.NONE or surfaces.flooded(perch, pose):
			continue
		var perch_name := layout.platforms[perch].name
		if routes[graph.deck_of(perch)] < 2 and not perch_name in lone:
			lone.append(perch_name)
	return lone


func test_no_single_route_perch() -> void:
	# Q6, from SH26: nothing times a perch's fall any more, so every perch the sinking
	# leaves highest has two ways up — the steamer's bridge, its two stairs
	# side by side down its forward face; from SH27, by the stern, her forecastle, its
	# two stairs.
	var layout := SimFixtures.steamer()
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	scenario.explicit_hit = load("res://tests/fixtures/sinking/hits/fast.tres")
	assert_eq(_lone_perches(layout, scenario), [] as Array[StringName])
	var one_way: ShipLayout = layout.duplicate()
	var ramps: Array[ShipRamp] = []
	for ramp: ShipRamp in layout.ramps:
		if not (is_equal_approx(ramp.start_height, 4.7) and ramp.area.position.y > 0.0):
			ramps.append(ramp)
	assert_eq(ramps.size(), layout.ramps.size() - 1, "the bridge has its starboard stair")
	one_way.ramps = ramps
	assert_eq(
		_lone_perches(one_way, scenario),
		[&"bridge"] as Array[StringName],
		"without it, the rule bites"
	)


func test_every_room_has_a_door() -> void:
	# Or a stair up out of it: the steamer's stokehold is left by the stairs to its
	# galleries (#74). A door is any gap a body gets through, crawling if it must.
	var rules := SimFixtures.rules()
	var layouts := _layouts()
	var rooms := 0
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		for room: ShipRoom in layout.rooms:
			rooms += 1
			var wide := 0
			for door: ShipRoom.Door in room.doors(surfaces, rules.crawl_height, rules.step_height):
				if door.width() >= rules.body_radius * 2.0:
					wide += 1
			for ramp: ShipRamp in layout.ramps:
				var low := 0 if ramp.start_height < ramp.end_height else 1
				if room.holds(ramp.end_point(low), rules.step_height):
					wide += 1
			assert_gt(wide, 0, "%s: %s has no door" % [path, room.name])
	assert_gt(rooms, 0, "the steamer has rooms")


func test_doors_are_at_least_a_metre_wide() -> void:
	var rules := SimFixtures.rules()
	var layouts := _layouts()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		for room: ShipRoom in layout.rooms:
			for door: ShipRoom.Door in room.doors(surfaces, rules.crawl_height, rules.step_height):
				assert_gte(
					door.width(),
					MIN_DOOR,
					(
						"%s: %s has a gap of %.2f m at %s"
						% [path, room.name, door.width(), door.middle()]
					)
				)


func test_no_sealed_room() -> void:
	# Every room, and every platform, can be walked to from the main deck: through
	# doorways and up and down ramps, on a level ship.
	var rules := SimFixtures.rules()
	var layouts := _layouts()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		var graph := _graph(layout, surfaces)
		# Level, every cell of hers dry: a deck under her waterline is dry inside her
		# (the trawler's lower deck, rev 4).
		var level := (
			HeldPose.flooded(layout, -layout.freeboard, {})
			if layout.structure != null
			else (
				SinkSchedule
				. new(SimFixtures.calm(), layout.freeboard, SeedStreams.derive(1, "sink"))
				. pose_at(0)
			)
		)
		var main_deck := _main_deck(layout)
		assert_ne(main_deck, Surfaces.NONE, "%s: a main deck" % path)
		if main_deck == Surfaces.NONE:
			continue
		var middle := layout.platforms[main_deck].area.get_center()
		var start := Vector3(middle.x, 0.0, middle.y)
		var start_surface := surfaces.under(start, rules.step_height)
		var start_zone := graph.zone_at(start, start_surface)
		var reached := PackedByteArray()
		reached.resize(graph.zone_count())
		for zone in graph.zone_count():
			var route := graph.route(start, start_surface, zone, level)
			reached[zone] = 1 if zone == start_zone or not route.is_empty() else 0
		for room in layout.rooms.size():
			assert_eq(reached[room], 1, "%s: %s is sealed" % [path, layout.rooms[room].name])
		for index in layout.platforms.size():
			var platform := layout.platforms[index]
			var walkable := reached[graph.deck_of(index)] == 1
			for room in layout.rooms.size():
				var on_it := layout.rooms[room]
				if is_equal_approx(on_it.floor_height, platform.height):
					walkable = (
						walkable or (reached[room] == 1 and on_it.area.intersects(platform.area))
					)
			assert_true(walkable, "%s: platform %d cannot be walked to" % [path, index])


func test_every_floor_in_a_room_has_headroom_to_stand_or_is_a_crawl_space() -> void:
	var layouts := _layouts()
	for path: String in layouts:
		assert_eq(_headroom_problems(layouts[path]), PackedStringArray(), path)


func test_the_headroom_rule_bites() -> void:
	# The flat deck with a roof over x 0…4 and a room under it — test data. A metre's
	# headroom is a crawl space's, 0.6 m nobody's; a room in the open is no crawl space.
	var roofed := func(roof_height: float, crawl_space: bool) -> ShipLayout:
		var layout: ShipLayout = SimFixtures.deck().duplicate()
		layout.platforms = layout.platforms.duplicate()
		var roof := ShipPlatform.new()
		roof.area = Rect2(0.0, -4.0, 4.0, 8.0)
		roof.height = roof_height
		layout.platforms.append(roof)
		var room := ShipRoom.new()
		room.name = &"under the roof"
		room.area = roof.area
		room.crawl_space = crawl_space
		var rooms: Array[ShipRoom] = [room]
		layout.rooms = rooms
		return layout
	assert_eq(_headroom_problems(roofed.call(1.0, true)), PackedStringArray(), "a crawl space")
	var unmarked := _headroom_problems(roofed.call(1.0, false))
	assert_false(unmarked.is_empty(), "unmarked, it is too low")
	assert_string_contains(unmarked[0], "not a crawl space")
	var low := _headroom_problems(roofed.call(0.6, true))
	assert_false(low.is_empty(), "under crawl_height, it takes nobody")
	assert_string_contains(low[0], "too low to crawl")
	assert_eq(
		_headroom_problems(roofed.call(3.0, true)),
		PackedStringArray(["under the roof: a crawl space with headroom to stand everywhere"])
	)


func test_every_lower_deck_has_two_stairs_up() -> void:
	var layouts := _layouts()
	var lower_decks := 0
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var surfaces := Surfaces.new(layout)
		var graph := _graph(layout, surfaces)
		# Per deck below the main deck, the ramps that climb out of it.
		var stairs := {}
		for index in layout.platforms.size():
			if layout.platforms[index].height < 0.0:
				stairs[graph.deck_of(index)] = 0
		for ramp in layout.ramps.size():
			var joined := surfaces.joins(surfaces.ramp_surface(ramp))
			if Surfaces.NONE in joined:
				continue
			var low := 0 if layout.ramps[ramp].start_height < layout.ramps[ramp].end_height else 1
			var deck := graph.deck_of(joined[low])
			if stairs.has(deck):
				stairs[deck] += 1
		for deck: int in stairs:
			lower_decks += 1
			assert_gte(
				stairs[deck], 2, "%s: the deck of zone %d needs two stairs up" % [path, deck]
			)
	assert_gt(lower_decks, 0, "the steamer has a lower deck")


func test_no_wall_crosses_a_stair_or_an_opening() -> void:
	# Nothing thin and solid stands where a body on a stair would meet it — on the
	# stair, in the opening over it, or in a body's width before either end.
	var rules := SimFixtures.rules()
	var lead := rules.body_radius * 2.0
	var layouts := _layouts()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var walls := _walls(layout)
		for index in layout.ramps.size():
			var ramp := layout.ramps[index]
			var area := ramp.area
			var before: Rect2
			var past: Rect2
			if ramp.axis == ShipRamp.Axis.X:
				before = Rect2(area.position.x - lead, area.position.y, lead, area.size.y)
				past = Rect2(area.end.x, area.position.y, lead, area.size.y)
			else:
				before = Rect2(area.position.x, area.position.y - lead, area.size.x, lead)
				past = Rect2(area.position.x, area.end.y, area.size.x, lead)
			for wall: ShipBlocker in walls:
				for where: Rect2 in [area, before, past]:
					if not where.grow(-0.001).intersects(wall.area):
						continue
					# The heights a body's feet take there: along the stair, or held at
					# the height of the end it stands beyond.
					var overlap := where.intersection(wall.area)
					var heights := [
						ramp.height_at(overlap.position.x, overlap.position.y),
						ramp.height_at(overlap.end.x, overlap.end.y)
					]
					var low: float = heights.min()
					var high: float = heights.max()
					assert_false(
						(
							wall.bottom < high + rules.body_height
							and wall.top > low + rules.step_height
						),
						"%s: the wall at %s crosses ramp %d" % [path, wall.area, index]
					)


## How far the spans a–b and c–d run together along one line; 0 when they do not share it.
func _shared(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var along := (b - a).normalized()
	var across := Vector2(-along.y, along.x)
	if absf((c - a).dot(across)) > 0.01 or absf((d - a).dot(across)) > 0.01:
		return 0.0
	var from := minf((c - a).dot(along), (d - a).dot(along))
	var to := maxf((c - a).dot(along), (d - a).dot(along))
	return maxf(0.0, minf(to, a.distance_to(b)) - maxf(from, 0.0))


func test_no_railing_crosses_a_stair_end() -> void:
	# A stair's end is open onto the deck at its height: no railing on that deck runs
	# across it (the Titanic's forecastle stairs, railed over at their heads).
	var layouts := _layouts()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		for index in layout.ramps.size():
			var ramp := layout.ramps[index]
			for end in 2:
				var edge := ramp.end_edge(end)
				var height := ramp.start_height if end == 0 else ramp.end_height
				for railing: ShipRailing in layout.railings:
					if not is_equal_approx(layout.platforms[railing.platform].height, height):
						continue
					assert_lt(
						_shared(edge[0], edge[1], railing.from, railing.to),
						0.05,
						(
							"%s: the railing %s–%s crosses ramp %d's end %d"
							% [path, railing.from, railing.to, index, end]
						)
					)
