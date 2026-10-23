extends GutTest
## Lifebuoys on her side railings (RailBuoys): the steamer hangs them along both sides, and
## on every ship each hangs on a span that runs fore and aft along her outermost deck there,
## outboard of its line between two of its posts and under its cap rail, no nearer the last
## along that side than BUOY_EVERY nor a boarding ladder than CLEAR_OF_LADDER, and no
## further out past the deck's edge than art-lint's nearest false-floor probe.

const ArtLint := preload("res://tools/art_lint.gd")

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


func _buoys(ship: String) -> Dictionary:
	return RailBuoys.of(ShipSpace.new(Fleet.layout(StringName(ship))), _rules.railing_height)


func test_the_steamer_hangs_buoys_along_both_sides() -> void:
	var sides := {-1.0: 0, 1.0: 0}
	for hung: Array in _buoys("steamer").values():
		sides[signf((hung[1] as Vector3).z)] += 1
	assert_gt(sides[-1.0], 0, "to port")
	assert_gt(sides[1.0], 0, "to starboard")


func test_no_buoy_reaches_out_to_a_false_floor_probe() -> void:
	var reach := RailBuoys.OUT + RoomDressing.LIFEBELT_DEPTH + RoomDressing.LIFEBELT_LINE
	assert_lt(reach, ArtLint.BEYOND[0], "its back, its ring and its grab line")


func test_every_buoy_hangs_on_its_span_between_two_posts() -> void:
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		var space := ShipSpace.new(layout)
		var buoys := _buoys(ship)
		for index: int in buoys:
			var railing := layout.railings[index]
			var middle: Vector3 = buoys[index][0]
			var normal: Vector3 = buoys[index][1]
			var named := "%s's buoy on railing %d" % [ship, index]
			assert_true(is_equal_approx(railing.from.y, railing.to.y), named + ": fore and aft")
			var outline := space.envelope(middle.x)
			var outer := outline.y if normal.z > 0.0 else outline.x
			assert_almost_eq(outer, railing.from.y, 0.001, named + ": along her outermost deck")
			assert_almost_eq(
				middle.z - railing.from.y, normal.z * RailBuoys.OUT, 0.001, named + ": outboard"
			)
			var span := railing.to - railing.from
			var posts := maxi(1, ceili(span.length() / ShipArt.POST_SPACING))
			for post in posts + 1:
				var at := railing.from + span * (float(post) / posts)
				var clear := RoomDressing.LIFEBELT_RADIUS + ShipArt.POST * 0.5
				assert_gt(absf(at.x - middle.x), clear - 0.001, named + ": between two posts")
			var deck := layout.platforms[railing.platform].height
			var cap := deck + _rules.railing_height - ShipArt.RAIL_DEPTH
			assert_lt(middle.y + RoomDressing.LIFEBELT_RADIUS, cap, named + ": under its cap rail")


func test_buoys_hang_apart_and_clear_of_ladders() -> void:
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		var buoys := _buoys(ship)
		for index: int in buoys:
			var middle: Vector3 = buoys[index][0]
			for other: int in buoys:
				var there: Vector3 = buoys[other][0]
				if other == index or signf(there.z) != signf(middle.z):
					continue
				var apart := absf(there.x - middle.x)
				assert_gt(
					apart, RailBuoys.BUOY_EVERY - 0.001, "%s: %d and %d" % [ship, index, other]
				)
			for ladder: ShipLadder in layout.ladders:
				var on_side := is_equal_approx(ladder.from.y, layout.railings[index].from.y)
				var low := minf(ladder.from.x, ladder.to.x) - RailBuoys.CLEAR_OF_LADDER
				var high := maxf(ladder.from.x, ladder.to.x) + RailBuoys.CLEAR_OF_LADDER
				var near := on_side and middle.x > low and middle.x < high
				assert_false(near, "%s's buoy on railing %d by a ladder" % [ship, index])
