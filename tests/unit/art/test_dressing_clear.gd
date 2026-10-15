extends GutTest
## Nothing the whole of the Titanic's dressing draws stands in a body's way
## (FurnishingCheck): the ShipArt every room's dressing — LinerBath, LinerBerths,
## LinerBoiler, LinerCorridor, LinerDining, LinerPublic, LinerService, LinerSquash and
## the rest — draws into together, checked here once for every one of them. The check
## alone is minutes of a CI runner; the trawler's is test_liner_service's.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")


func test_nothing_the_titanic_s_dressing_draws_stands_in_a_body_s_way() -> void:
	var rules := RunMatch.default_config(1701).rules
	var titanic: ShipLayout = load("res://data/ships/titanic.tres")
	var art := ShipArt.new()
	art.build(titanic, rules.railing_height, rules.body_radius)
	var faces := FurnishingCheck.furnishings(art)
	art.free()
	assert_gt(faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(titanic, rules, faces), PackedStringArray())
