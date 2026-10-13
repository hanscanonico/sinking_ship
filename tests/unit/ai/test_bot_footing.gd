extends GutTest
## What a bot's footing finds round it: water, open edges and the trench between two
## decks, looked for at the edge margin and further out.


## Two decks 20 × 6 m at one height, 0.5 m apart across x = 0…0.5: a trench, with
## floor beyond it.
func _trenched() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for area: Rect2 in [Rect2(-20.0, -3.0, 20.0, 6.0), Rect2(0.5, -3.0, 20.0, 6.0)]:
		var deck := ShipPlatform.new()
		deck.area = area
		platforms.append(deck)
	layout.platforms = platforms
	return layout


func _footing(layout: ShipLayout, surfaces: Surfaces) -> BotFooting:
	var rules := SimFixtures.rules()
	var margin: float = load(SimFixtures.NORMAL_BOT).edge_margin_m
	return BotFooting.new(surfaces, WalkGraph.new(layout, surfaces, rules), rules, margin)


func _calm(layout: ShipLayout) -> ShipPose:
	var schedule := SinkSchedule.new(
		SimFixtures.calm(), layout.freeboard, SeedStreams.derive(1, "sink")
	)
	return schedule.pose_at(0)


func test_the_look_further_out_finds_a_trench_with_floor_beyond_it() -> void:
	var layout := _trenched()
	var surfaces := Surfaces.new(layout)
	var footing := _footing(layout, surfaces)
	var pose := _calm(layout)
	var step := SimFixtures.rules().step_height
	var reach := 1.8
	var by_the_trench := Vector3(-0.4, 0.0, 0.0)
	for index in BotFooting.PROBES:
		var direction := BotFooting.probe(index)
		var probe := by_the_trench + Vector3(direction.x, 0.0, direction.y) * reach
		assert_ne(surfaces.under(probe, step), Surfaces.NONE, "every probe lands on a deck")
	assert_true(
		surfaces.drops(by_the_trench, by_the_trench + Vector3(reach, 0.0, 0.0), step),
		"though the walk across drops into the trench"
	)
	assert_true(footing.danger_within(by_the_trench, pose, reach), "the trench is an edge")
	assert_false(
		footing.danger_within(Vector3(-6.0, 0.0, 0.0), pose, reach), "a whole deck has none"
	)


## A deck 20 × 10 m out of the sea and a well 2 × 2 m sunk under it: a small platform
## flooded floods little of her. The share under water is of her deck area, not of
## her platforms — a stokehold's walks going under are no half of the ship.
func test_the_share_flooded_is_of_her_deck_area() -> void:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for row: Array in [[Rect2(-10.0, -5.0, 20.0, 10.0), 0.0], [Rect2(-1.0, -1.0, 2.0, 2.0), -4.0]]:
		var platform := ShipPlatform.new()
		platform.area = row[0]
		platform.height = row[1]
		platforms.append(platform)
	layout.platforms = platforms
	var surfaces := Surfaces.new(layout)
	var pose := _calm(layout)
	assert_false(surfaces.flooded(0, pose), "the deck is dry")
	assert_true(surfaces.flooded(1, pose), "the well is under")
	assert_almost_eq(
		_footing(layout, surfaces).flooded_share(pose), 4.0 / 204.0, 1e-6, "the well's area"
	)
