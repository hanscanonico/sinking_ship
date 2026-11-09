extends GutTest
## A wall's top flush with the deck over it (#558). Where the deck leaves it bare, beside a
## passage a metre lower, a body walking the deck steps onto it, as on the steamer, whose
## below-decks wall 13 stands flush with her main deck beside her side passage. That body is
## on the deck: its floor (Surfaces.footing), its headroom (BrawlRules.height_at) and its zone
## (WalkGraph.zone_at) are the deck's, never those of the floor the wall stands on below.
## Before, a bot there reckoned itself below decks and turned back. And a box stands on the
## floor under it whatever a float32 makes of that floor's height.

const DECK := 0.0
const LOWER := -2.6
const PASSAGE := -1.0
## The awning over the deck, lower than a body is tall.
const AWNING := 1.5
## On the wall's bare top, by the passage; and on the deck beside it.
const ON_THE_WALL := Vector3(0.0, DECK, 2.0)
const ON_THE_DECK := Vector3(-0.5, DECK, 2.0)
## A floor at a height no float32 holds, which one rounds down (2.29999995), and a box on it.
const RAISED := 2.3


## Test data, no ship's. A deck at 0 m under an awning, whole forward of z 1 and aft of it
## only to port of the wall (x −0.1); aft, to starboard of the wall, a passage a metre lower;
## a lower deck under them all; and the wall, from the lower deck up to the deck, x −0.1 to
## 0.1 and z −3 to 3, its middle under the deck.
func _layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	layout.min_seats = 1
	layout.max_seats = 1
	var platforms: Array[ShipPlatform] = []
	for row: Array in [
		[&"deck fore", Rect2(-4.0, -3.0, 8.0, 4.0), DECK],
		[&"deck aft", Rect2(-4.0, 1.0, 3.9, 2.0), DECK],
		[&"passage", Rect2(0.1, 1.0, 3.9, 2.0), PASSAGE],
		[&"lower", Rect2(-4.0, -3.0, 8.0, 6.0), LOWER],
		[&"awning", Rect2(-4.0, -3.0, 8.0, 6.0), AWNING],
	]:
		var platform := ShipPlatform.new()
		platform.name = row[0]
		platform.area = row[1]
		platform.height = row[2]
		platforms.append(platform)
	layout.platforms = platforms
	var wall := ShipBlocker.new()
	wall.area = Rect2(-0.1, -3.0, 0.2, 6.0)
	wall.bottom = LOWER
	wall.top = DECK
	var blockers: Array[ShipBlocker] = [wall]
	layout.blockers = blockers
	return layout


func test_a_wall_s_bare_top_flush_with_a_deck_is_walked_as_that_deck() -> void:
	var layout := _layout()
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	var top := surfaces.under(ON_THE_WALL, rules.step_height)
	assert_eq(top, layout.platforms.size(), "on the wall's top")
	var fore := SimFixtures.platform_named(layout, &"deck fore")
	assert_eq(surfaces.footing(top), fore, "the deck over its middle, not the one it stands on")
	assert_eq(
		rules.height_at(surfaces, ON_THE_WALL),
		rules.height_at(surfaces, ON_THE_DECK),
		"a body crawls under the awning there as on the deck beside it"
	)
	assert_eq(rules.height_at(surfaces, ON_THE_DECK), rules.crawl_height, "which is low")
	var graph := WalkGraph.new(layout, surfaces, rules)
	var deck := graph.deck_of(fore)
	assert_eq(graph.deck_of(SimFixtures.platform_named(layout, &"deck aft")), deck, "one deck")
	assert_eq(graph.zone_at(ON_THE_WALL, top), deck, "in the deck's zone")
	assert_ne(deck, graph.deck_of(SimFixtures.platform_named(layout, &"lower")), "not below")


func test_a_box_stands_on_a_floor_a_float32_rounds_under() -> void:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for row: Array in [
		[&"floor", Rect2(-4.0, -4.0, 8.0, 8.0), 0.0],
		[&"raised", Rect2(-2.0, -2.0, 4.0, 4.0), RAISED]
	]:
		var platform := ShipPlatform.new()
		platform.name = row[0]
		platform.area = row[1]
		platform.height = row[2]
		platforms.append(platform)
	layout.platforms = platforms
	var box := ShipBlocker.new()
	box.area = Rect2(-0.5, -0.5, 1.0, 1.0)
	box.bottom = RAISED
	box.top = RAISED + 0.6
	var blockers: Array[ShipBlocker] = [box]
	layout.blockers = blockers
	var surfaces := Surfaces.new(layout)
	assert_lt(float(Vector3(0.0, RAISED, 0.0).y), RAISED, "the float32 rounds it under")
	assert_eq(
		surfaces.footing(layout.platforms.size()),
		SimFixtures.platform_named(layout, &"raised"),
		"on the raised floor, not the one under it"
	)
