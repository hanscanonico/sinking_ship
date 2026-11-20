extends GutTest
## The Titanic's side stands to A deck over her house under it only as far forward as the
## house's corners, where its rooms stop reaching her side (#582). The 1912 plan rounds them
## in 6.9 m short of the house's front, and Plate III's elevation draws her side open forward
## of that curve: there her bridge deck is open, railed along its edge (#580), her house
## standing in from her side on it. Her sections stood her shell to A deck all along the
## house, closing that open deck in and hiding its railing. So no railing along her bridge
## deck's side stands inside her shell: where one runs, her shell's top is that deck's, on
## her and on her sisters.
##
## Nor along C deck's: where her shell stands over it, under her poop and B deck's after end,
## her plating lines its edge (#580), and its promenades there were railed inside her plating,
## 6 to 35 cm in (#598).

const SHIP := "res://data/ships/titanic.tres"
const SHIPS: Array[String] = [
	SHIP,
	"res://tests/fixtures/ships/titanic_britannic.tres",
	"res://tests/fixtures/ships/titanic_olympic_1913.tres",
]
## A railing this near her shell at its deck runs along her side.
const ALONG_SIDE := 1.0
## A shell standing this near a railing's line, or past it, closes it in.
const SLACK := 0.05
## Under a deck, its height less this: her shell's breadth there.
const UNDER := 0.05
## Her bridge deck's platforms.
const BRIDGE_DECK := &"B deck"
## Her shelter deck's platforms.
const SHELTER_DECK := &"C deck"
## Her decks, as her generator lays them (tools/gen_titanic.py).
const B_DECK := 2.75
const A_DECK := 5.5
## Her house under A deck: its corners, which the 1912 plan rounds in, and its front.
const CORNERS := 64.875
const FRONT := 71.8125

var _rules := SimFixtures.rules()


func test_no_railing_along_her_bridge_decks_side_stands_inside_her_shell() -> void:
	_assert_none_railed_inside(BRIDGE_DECK)


func test_no_railing_along_her_shelter_decks_side_stands_inside_her_shell() -> void:
	_assert_none_railed_inside(SHELTER_DECK)


func _assert_none_railed_inside(deck: StringName) -> void:
	for path: String in SHIPS:
		var layout: ShipLayout = load(path)
		var railings: Array[ShipRailing] = []
		for railing: ShipRailing in layout.railings:
			if layout.platforms[railing.platform].name == deck:
				railings.append(railing)
		assert_gt(railings.size(), 0, path)
		assert_eq(
			_railed_inside(layout.platforms, railings, layout.structure.sections),
			PackedStringArray(),
			path
		)


func test_her_side_stands_to_a_deck_to_her_house_corners_only() -> void:
	var layout: ShipLayout = load(SHIP)
	var sections := layout.structure.sections
	for way: int in [1, -1]:
		var aft := _section_at(sections, CORNERS - 0.3)
		var fore := _section_at(sections, CORNERS + 0.3)
		var side := absf(aft.shell_at(B_DECK - UNDER, way))
		assert_almost_eq(
			absf(aft.shell_at(A_DECK - UNDER, way)), side, 0.2, "aft of her corners: her side"
		)
		for x: float in [CORNERS + 0.3, (CORNERS + FRONT) * 0.5, FRONT - 0.1]:
			var section := _section_at(sections, x)
			var house := absf(section.shell_at((B_DECK + A_DECK) * 0.5, way))
			assert_lt(house, side - 3.0, "forward of her corners at x %.2f: her house" % x)
			assert_gt(house, 9.0, "forward of her corners at x %.2f: her house" % x)
		assert_gt(
			absf(fore.shell_at(B_DECK - UNDER, way)), side - 0.2, "under her bridge deck: her side"
		)


func test_a_railing_inside_her_shell_is_found() -> void:
	var deck := ShipPlatform.new()
	deck.area = Rect2(-5.0, -4.0, 10.0, 8.0)
	deck.height = 0.0
	var section := HullSection.new()
	section.x = 0.0
	section.length = 10.0
	section.outline = PackedVector2Array(
		(
			[Vector2(0.0, -6.0), Vector2(4.2, -6.0), Vector2(4.2, 3.0), Vector2(-4.2, 3.0)]
			+ [Vector2(-4.2, -6.0)]
		)
	)
	var railing := ShipRailing.new()
	railing.platform = 0
	railing.from = Vector2(-5.0, 4.0)
	railing.to = Vector2(5.0, 4.0)
	var platforms: Array[ShipPlatform] = [deck]
	var railings: Array[ShipRailing] = [railing]
	var sections: Array[HullSection] = [section]
	assert_eq(_railed_inside(platforms, railings, sections).size(), 1, "her shell over it")
	section.outline = PackedVector2Array(
		(
			[Vector2(0.0, -6.0), Vector2(4.2, -6.0), Vector2(4.2, 0.0), Vector2(-4.2, 0.0)]
			+ [Vector2(-4.2, -6.0)]
		)
	)
	assert_eq(_railed_inside(platforms, railings, sections).size(), 0, "her shell to its deck")


## Each railing along her side — along her, within ALONG_SIDE of her shell at its deck — that
## her shell stands at or outboard of half way up it, at any section's middle along it.
func _railed_inside(
	platforms: Array[ShipPlatform], railings: Array[ShipRailing], sections: Array[HullSection]
) -> PackedStringArray:
	var found := PackedStringArray()
	var half_up := _rules.railing_height * 0.5
	for index in railings.size():
		var railing := railings[index]
		if absf(railing.from.y - railing.to.y) > 1e-4:
			continue
		var z := railing.from.y
		var way := 1 if z > 0.0 else -1
		var height := platforms[railing.platform].height
		var x0 := minf(railing.from.x, railing.to.x)
		var x1 := maxf(railing.from.x, railing.to.x)
		for section: HullSection in sections:
			if section.x <= x0 or section.x >= x1:
				continue
			var side := absf(section.shell_at(height - UNDER, way))
			if is_nan(side) or side - absf(z) > ALONG_SIDE:
				continue
			var shell := section.shell_at(height + half_up, way)
			if not is_nan(shell) and absf(shell) >= absf(z) - SLACK:
				found.append(
					(
						"railing %d at z %.2f, x %.2f to %.2f, %.2f up: her shell to %.2f at x %.2f"
						% [index, z, x0, x1, height, absf(shell), section.x]
					)
				)
				break
	return found


func _section_at(sections: Array[HullSection], x: float) -> HullSection:
	for section: HullSection in sections:
		if absf(x - section.x) <= section.length * 0.5:
			return section
	return null
