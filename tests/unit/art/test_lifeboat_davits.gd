extends GutTest
## Lifeboats hang on their davits beside a deck's true open edges only (ShipFittings):
## never at the seam where a deck cut round an opening meets another piece of itself,
## which on the barque, the ferry and the tug planted davits in the middle of a deck and
## hung boats over it, where bodies walk through them. The steamer keeps hers, over the
## open edges of her boat deck.

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


## [param ship]'s fittings, built as ShipArt builds them, without a ship to hang the boats
## under.
func _fitted(ship: StringName) -> ShipFittings:
	var space := ShipSpace.new(Fleet.layout(ship))
	var hull := SectionHull.of(space, _rules.railing_height)
	var fittings := ShipFittings.new(space, hull, _rules.body_radius)
	fittings.build(ShipMesh.new(func(_point: Vector3) -> bool: return true, space.room_lines()))
	return fittings


func test_no_boat_hangs_over_a_deck_of_its_own_height() -> void:
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		for keel: Vector3 in _fitted(StringName(ship)).lifeboats:
			var deck := keel.y - ShipFittings.LIFEBOAT_LIFT
			for platform: ShipPlatform in layout.platforms:
				var over := platform.contains(keel.x, keel.z)
				var named := "%s's boat at %s over %s" % [ship, keel, platform.name]
				assert_false(over and platform.height >= deck - 0.01, named)


func test_no_boat_hangs_over_a_deck_nearer_than_its_headroom() -> void:
	# The Titanic's raised roofs stand 1.2 m over her boat deck (#360): no boat hangs
	# beside their edges, over the deck they are raised on.
	for ship: String in Fleet.names():
		var space := ShipSpace.new(Fleet.layout(StringName(ship)))
		for keel: Vector3 in _fitted(StringName(ship)).lifeboats:
			var deck := keel.y - ShipFittings.LIFEBOAT_LIFT
			var beneath := space.deck_under(Vector2(keel.x, keel.z), deck - 0.01)
			var room := deck - beneath
			var named := "%s's boat at %s, %.2f m over the deck beneath" % [ship, keel, room]
			assert_true(is_nan(beneath) or room >= ShipFittings.LIFEBOAT_HEADROOM, named)


func test_the_steamer_keeps_her_boats_over_her_boat_deck_s_open_edges() -> void:
	var boats := _fitted(&"steamer").lifeboats
	var sides := {-1.0: 0, 1.0: 0}
	for keel: Vector3 in boats:
		sides[signf(keel.z)] += 1
	assert_gt(sides[-1.0], 0, "to port")
	assert_gt(sides[1.0], 0, "to starboard")
