extends GutTest
## Lifebuoys on her side railings (RailBuoys, #273), drawn where the match has them
## (PropPlacing): the steamer hangs them along both sides, and on every ship each hung one
## is drawn outboard of its span's line, between two of its posts and under its cap rail,
## and no further out past the deck's edge than art-lint's nearest false-floor probe.

const ArtLint := preload("res://tools/art_lint.gd")

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


## Every hung ring of [param layout], by its prop's index: where it is drawn.
func _hung(layout: ShipLayout) -> Dictionary:
	var drawn := {}
	var props := PropState.from_layout(layout)
	for crate: PropState in props:
		if crate.body == PropState.Body.HUNG:
			var prop := layout.props[crate.prop]
			drawn[crate.prop] = PropPlacing.of(
				crate.to_dict(), prop, layout, _rules.railing_height, []
			)
	return drawn


func test_the_steamer_hangs_rings_along_both_sides() -> void:
	var sides := {-1.0: 0, 1.0: 0}
	for drawn: Transform3D in _hung(Fleet.layout(&"steamer")).values():
		sides[signf(drawn.basis.z.z)] += 1
	assert_gt(sides[-1.0], 0, "to port")
	assert_gt(sides[1.0], 0, "to starboard")


func test_no_ring_reaches_out_to_a_false_floor_probe() -> void:
	var reach := RailBuoys.OUT + RoomDressing.LIFEBELT_DEPTH + RoomDressing.LIFEBELT_LINE
	assert_lt(reach, ArtLint.BEYOND[0], "its back, its ring and its grab line")


func test_every_ring_is_drawn_on_its_span_between_two_posts_under_its_cap() -> void:
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		var drawn := _hung(layout)
		for index: int in drawn:
			var prop := layout.props[index]
			var railing := layout.railings[prop.railing]
			var ring: Transform3D = drawn[index]
			var middle := ring.origin
			var normal := ring.basis.z
			var named := "%s's ring %d on railing %d" % [ship, index, prop.railing]
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
			assert_lt(middle.y + prop.radius, cap, named + ": under its cap rail")
