extends GutTest
## §5's layout lint, run over every layout under data/ships/: it holds the shape of
## a ship, not any one ship's numbers.

const SHIPS := "res://data/ships"


## Every layout under data/ships/, by path.
func _layouts() -> Dictionary:
	var layouts := {}
	for file: String in DirAccess.get_files_at(SHIPS):
		if file.ends_with(".tres"):
			layouts["%s/%s" % [SHIPS, file]] = load("%s/%s" % [SHIPS, file])
	return layouts


## How many ramps join each platform of [param layout].
func _routes(layout: ShipLayout, surfaces: Surfaces) -> PackedInt32Array:
	var routes := PackedInt32Array()
	routes.resize(layout.platforms.size())
	for ramp in layout.ramps.size():
		for platform: int in surfaces.joins(surfaces.ramp_surface(ramp)):
			if platform != Surfaces.NONE:
				routes[platform] += 1
	return routes


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


func test_no_overlapping_same_height_platforms() -> void:
	var layouts := _layouts()
	for path: String in layouts:
		var platforms: Array[ShipPlatform] = (layouts[path] as ShipLayout).platforms
		for first in platforms.size():
			for second in range(first + 1, platforms.size()):
				var a := platforms[first]
				var b := platforms[second]
				var same_height := is_equal_approx(a.height, b.height)
				assert_false(
					same_height and a.area.intersects(b.area),
					"%s: platforms %d and %d overlap" % [path, first, second]
				)


func test_every_elevated_platform_has_a_ramp() -> void:
	var layouts := _layouts()
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var routes := _routes(layout, Surfaces.new(layout))
		var lowest := INF
		for platform: ShipPlatform in layout.platforms:
			lowest = minf(lowest, platform.height)
		for index in layout.platforms.size():
			if layout.platforms[index].height > lowest:
				assert_gt(routes[index], 0, "%s: platform %d has no ramp" % [path, index])


func test_poop_deck_has_two_routes() -> void:
	var layouts := _layouts()
	var poop_decks := 0
	for path: String in layouts:
		var layout: ShipLayout = layouts[path]
		var routes := _routes(layout, Surfaces.new(layout))
		for index in layout.platforms.size():
			if layout.platforms[index].name == &"poop deck":
				poop_decks += 1
				assert_gte(routes[index], 2, "%s: the poop deck needs two routes" % path)
	assert_gt(poop_decks, 0, "the steamer has a poop deck")
