extends GutTest
## The iceberg is presentation (D12): IcebergPlanner stands it off her struck side ahead
## of her from the match's start, grinds its spur aft along the gash as HOLED strikes,
## and lets it fall astern and away, every pose a pure function of (hit, ship, seed,
## tick) (D5). Built from hand-made hits on the shipped ships: no bake.

const SHIPS: Array[String] = [
	"res://data/ships/trawler.tres", SimFixtures.STEAMER, "res://data/ships/titanic.tres"
]
const HIT_TICK := 1100
const SEED := 1701
## The cameras' far plane (match.tscn): past it nothing is drawn.
const CAMERA_FAR := 800.0


## A hit on [param side] of [param layout], over the middle third of her hit zone,
## [param depth] metres under her waterline at its aft end and deeper forward: over
## her bilge on every ship.
func _hit(layout: ShipLayout, side: int, depth: float = 0.8) -> IcebergHit:
	var zone := layout.structure.hit_zone_x
	var hit := IcebergHit.new()
	hit.moment = Ticks.to_seconds(HIT_TICK)
	hit.side = side
	hit.start_x = lerpf(zone.x, zone.y, 0.4)
	hit.length = (zone.y - zone.x) * 0.3
	hit.depth_start = depth
	hit.depth_end = depth + 0.6
	hit.width = 0.05
	hit.bite = 0.5
	return hit


func _planner(layout: ShipLayout, side: int, seed_value: int = SEED) -> IcebergPlanner:
	return IcebergPlanner.new(_hit(layout, side), HIT_TICK, layout, seed_value)


## How far out from her middle she stands at [param x].
func _beam(layout: ShipLayout, x: float) -> float:
	return IcebergPlanner._beam_at(layout.structure, x)


## Every corner of [param planner]'s berg over the sea, posed at [param tick], in the
## sea's frame.
func _over_sea(planner: IcebergPlanner, tick: float) -> PackedVector3Array:
	var pose := planner.pose_at(tick)
	var over := PackedVector3Array()
	for corner in planner.shape():
		if corner.y >= 0.0:
			over.append(pose * corner)
	return over


func test_it_looms_ahead_off_the_struck_side_and_closes_in() -> void:
	var layout := SimFixtures.steamer()
	var hit := _hit(layout, 1)
	for side in [1, -1]:
		var planner := _planner(layout, side)
		var fore := planner.spur_at(HIT_TICK)
		var last := INF
		for tick in range(0, HIT_TICK, 50):
			var spur := planner.spur_at(tick)
			assert_gt(spur.x, hit.end_x(), "ahead of the gash's fore end")
			assert_gt(spur.z * side, fore.z * side, "off her struck side")
			assert_gt(planner.pose_at(tick).origin.z * side, 0.0, "the berg itself on that side")
			var off := spur.distance_to(fore)
			assert_lt(off, last, "closing in")
			last = off
		var first := planner.spur_at(0).distance_to(fore)
		assert_almost_eq(first, IcebergPlanner.LOOM_LEAST, 0.01, "in sight at the start")
		assert_lt(planner.pose_at(0).origin.length(), CAMERA_FAR, "short of the far plane")


func test_its_spur_scrapes_the_gash_fore_to_aft_through_the_strike() -> void:
	var layout := SimFixtures.steamer()
	for side in [1, -1]:
		var hit := _hit(layout, side)
		var planner := _planner(layout, side)
		assert_eq(planner.hit_tick, HIT_TICK, "as HOLED strikes")
		assert_eq(
			planner.scrape_end - planner.hit_tick,
			Ticks.from_seconds(GashPlanner.GASH_SECONDS),
			"for as long as the gash shows"
		)
		assert_almost_eq(planner.spur_at(HIT_TICK).x, hit.end_x(), 0.01, "from its fore end")
		assert_almost_eq(planner.spur_at(planner.scrape_end).x, hit.start_x, 0.01, "to its aft")
		var last := INF
		for tick in range(HIT_TICK, planner.scrape_end + 1, GashPlanner.GASH_TICKS):
			var spur := planner.spur_at(tick)
			assert_between(spur.x, hit.start_x - 0.01, hit.end_x() + 0.01, "along the gash")
			assert_lte(spur.x, last, "running aft")
			last = spur.x
			var depth := hit.depth_at(spur.x)
			assert_almost_eq(spur.y, -depth, 0.01, "at the gash's depth")
			var shell := layout.structure.section_at(spur.x).shell_at(
				spur.y + layout.structure.waterline_y, side
			)
			assert_almost_eq(spur.z, shell, 0.25, "on her shell, as sampled every 2 m")
			var blade := planner.pose_at(tick) * planner.spur(spur.y)
			assert_almost_eq(blade.distance_to(spur), 0.0, 0.01, "the berg's spur is there")


func test_nothing_of_it_over_the_sea_cuts_into_her() -> void:
	for path in SHIPS:
		var layout: ShipLayout = load(path)
		var span := IcebergPlanner._span(layout.structure)
		for side in [1, -1]:
			var planner := _planner(layout, side)
			for tick in range(0, planner.scrape_end + 600, 20):
				for corner in _over_sea(planner, tick):
					if corner.x < span.x or corner.x > span.y:
						continue
					assert_gt(
						corner.z * side,
						_beam(layout, corner.x),
						"%s: clear of her side at tick %d" % [path.get_file(), tick]
					)


func test_it_drifts_astern_and_away_and_stays_in_sight() -> void:
	var layout := SimFixtures.steamer()
	for side in [1, -1]:
		var hit := _hit(layout, side)
		var planner := _planner(layout, side)
		var last := planner.spur_at(planner.scrape_end)
		for seconds in [1, 5, 20, 60, 300]:
			var spur := planner.spur_at(planner.scrape_end + Ticks.from_seconds(seconds))
			assert_lt(spur.x, last.x, "falling astern")
			assert_lt(spur.x, hit.start_x, "astern of the gash")
			assert_gt(spur.z * side, last.z * side, "and away from her")
			last = spur
		var hours := planner.pose_at(planner.scrape_end + Ticks.from_seconds(7200.0))
		assert_lt(hours.origin.length(), CAMERA_FAR * 0.75, "still in sight hours on")
		assert_gt(hours.origin.length(), IcebergPlanner.DRIFT_LEAST * 0.5, "well astern")


func test_it_goes_off_at_the_speed_it_scraped_at() -> void:
	for path in SHIPS:
		var layout: ShipLayout = load(path)
		var planner := _planner(layout, 1)
		var end := planner.scrape_end
		var scraping := planner.spur_at(end - 1).distance_to(planner.spur_at(end))
		var going := planner.spur_at(end).distance_to(planner.spur_at(end + 1))
		assert_almost_eq(going, scraping, scraping * 0.05, "%s: no jolt" % path.get_file())


func test_its_pose_is_a_pure_function_of_the_tick() -> void:
	var layout := SimFixtures.steamer()
	var ticks := [0, 500, 1099.5, 1100, 1180.25, 1310, 5000, 90000]
	var forward := _planner(layout, 1)
	var backward := _planner(layout, 1)
	var seen: Array[Transform3D] = []
	for tick: float in ticks:
		seen.append(forward.pose_at(tick))
	for index in range(ticks.size() - 1, -1, -1):
		assert_eq(backward.pose_at(ticks[index]), seen[index], "the same whenever it is asked")
	assert_eq(forward.pose_at(500), seen[1], "and asked again")
	assert_eq(forward.shape(), backward.shape(), "the same berg for the same seed")
	assert_eq(forward.shades(), backward.shades(), "the same ice")
	var other := _planner(layout, 1, SEED + 1)
	assert_ne(other.shape(), forward.shape(), "its own berg for every match")
	var between := forward.spur_at(1180.5)
	assert_between(between.x, forward.spur_at(1181).x, forward.spur_at(1180).x, "drawn between")


func test_it_towers_over_each_ships_deck_and_is_sized_to_her() -> void:
	var heights := PackedFloat32Array()
	for path in SHIPS:
		var layout: ShipLayout = load(path)
		var planner := _planner(layout, 1)
		var top := -INF
		for platform: ShipPlatform in layout.platforms:
			top = maxf(top, platform.height)
		var deck := top - layout.structure.waterline_y
		assert_gt(planner.height, deck * 1.3, "%s: towering over her decks" % path.get_file())
		assert_gt(planner.depth, planner.height, "mostly under the sea")
		heights.append(planner.height)
		var lowest := INF
		for corner in planner.shape():
			lowest = minf(lowest, corner.y)
		assert_almost_eq(lowest, -planner.depth * 1.05, 0.01, "down to its foot")
	assert_lt(heights[0], heights[1], "a trawler's berg under a steamer's")
	assert_lt(heights[1], heights[2], "a steamer's under the Titanic's")


func test_it_stands_on_shallow_ground_without_going_through_it() -> void:
	var layout := SimFixtures.steamer()
	var planner := IcebergPlanner.new(
		_hit(layout, 1), HIT_TICK, layout, SEED, PackedVector3Array(), 12.0
	)
	assert_lte(planner.depth, 12.0 * IcebergPlanner.SEA_SHARE, "over the bottom")


func test_it_scrapes_the_gash_traced_on_her_shell() -> void:
	var layout := SimFixtures.steamer()
	var trace := PackedVector3Array([Vector3(-6.0, -4.6, 4.2), Vector3(4.0, -4.9, 4.1)])
	var planner := IcebergPlanner.new(_hit(layout, 1), HIT_TICK, layout, SEED, trace)
	var middle := planner.spur_at(HIT_TICK + (planner.scrape_end - HIT_TICK) * 0.5)
	assert_almost_eq(middle.x, -1.0, 0.01, "halfway along it halfway through")
	assert_almost_eq(middle.z, 4.15, 0.01, "on the trace")
	assert_almost_eq(middle.y, -4.75 + 3.4, 0.01, "at its height over the sea")
