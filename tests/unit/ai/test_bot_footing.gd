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
	var layout := _welled()
	var surfaces := Surfaces.new(layout)
	var pose := _calm(layout)
	assert_false(surfaces.flooded(0, pose), "the deck is dry")
	assert_true(surfaces.flooded(1, pose), "the well is under")
	assert_almost_eq(
		_footing(layout, surfaces).flooded_share(pose), 4.0 / 204.0, 1e-6, "the well's area"
	)


## The share is worked out once per pose and shared by every footing on the graph: the
## cached answer is the loop's, and a new pose is worked out afresh, never the last one's.
func test_the_share_flooded_is_worked_out_again_for_a_new_pose() -> void:
	var layout := _welled()
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	var margin: float = load(SimFixtures.NORMAL_BOT).edge_margin_m
	var graph := WalkGraph.new(layout, surfaces, rules)
	var one := BotFooting.new(surfaces, graph, rules, margin)
	var other := BotFooting.new(surfaces, graph, rules, margin)
	var calm := _calm(layout)
	assert_almost_eq(one.flooded_share(calm), _share(graph, surfaces, calm), 1e-9, "the loop's")
	assert_almost_eq(other.flooded_share(calm), 4.0 / 204.0, 1e-9, "shared, the well's area")
	var sunk := SinkSchedule.new(SimFixtures.calm(), -1.0, SeedStreams.derive(1, "sink")).pose_at(0)
	assert_true(surfaces.flooded(0, sunk), "the deck is under")
	assert_almost_eq(_share(graph, surfaces, sunk), 1.0, 1e-9, "all of her, by the loop")
	assert_almost_eq(one.flooded_share(sunk), 1.0, 1e-9, "worked out again, not the calm's")
	assert_almost_eq(other.flooded_share(calm), 4.0 / 204.0, 1e-9, "and again on going back")


## A deck 20 × 10 m at the main deck and a well 2 × 2 m 4 m under it.
func _welled() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for row: Array in [[Rect2(-10.0, -5.0, 20.0, 10.0), 0.0], [Rect2(-1.0, -1.0, 2.0, 2.0), -4.0]]:
		var platform := ShipPlatform.new()
		platform.area = row[0]
		platform.height = row[1]
		platforms.append(platform)
	layout.platforms = platforms
	return layout


## The share of her deck area under water under [param pose], platform by platform,
## with nothing cached: what WalkGraph.flooded_share must answer.
func _share(graph: WalkGraph, surfaces: Surfaces, pose: ShipPose) -> float:
	var flooded := 0.0
	var whole := 0.0
	for platform in surfaces.platform_count():
		var area := graph.platform_area(platform)
		whole += area
		flooded += area if surfaces.flooded(platform, pose) else 0.0
	return flooded / whole if whole > 0.0 else 0.0


func test_a_railing_on_the_next_piece_of_deck_stops_the_walk_to_the_edge() -> void:
	# A deck in two pieces side by side, the railing along the outer one's edge: a walk
	# from the inner one out to the side meets that railing, not a drop (#148 lays her
	# decks in pieces round hatches).
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for area: Rect2 in [Rect2(-10.0, -3.0, 20.0, 3.0), Rect2(-10.0, 0.0, 20.0, 2.0)]:
		var deck := ShipPlatform.new()
		deck.area = area
		platforms.append(deck)
	layout.platforms = platforms
	var railing := ShipRailing.new()
	railing.platform = 1
	railing.from = Vector2(-10.0, 2.0)
	railing.to = Vector2(10.0, 2.0)
	var railings: Array[ShipRailing] = [railing]
	layout.railings = railings
	var surfaces := Surfaces.new(layout)
	var footing := _footing(layout, surfaces)
	var pose := _calm(layout)
	var inner := Vector3(0.0, 0.0, -1.0)
	assert_eq(footing.edge_toward(inner, 0, Vector2.DOWN, 4.0, pose, false), INF, "railed")
	assert_lt(footing.edge_toward(inner, 0, Vector2.DOWN, 4.0, pose, true), INF, "over it")


## A bot with Sure footing still gets uphill of its target before it shoves, on a deck
## listing past the brawl rules' grip angle and under its own (#341): its shove carries the
## target downhill by the target's grip — the brawl rules', short of a bonus — not by its own.
func test_a_sure_footed_bot_gets_uphill_of_its_target_past_the_brawl_rules_grip() -> void:
	var layout := SimFixtures.deck()
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	var heel := (rules.grip_angle_deg + SimFixtures.sure_footing().grip_angle_deg) * 0.5
	var schedule := SinkSchedule.new(
		SimFixtures.tilted(0.0, heel), layout.freeboard, SeedStreams.derive(1, "sink")
	)
	var pose := schedule.pose_at(0)
	assert_almost_eq(pose.slope_deg(), heel, 0.5, "listing between the two grip angles")
	var below := Vector3(0.0, 0.0, 2.0)
	var target := Vector3(0.0, 0.0, 0.0)
	for sure: bool in [false, true]:
		var footing := _footing(layout, surfaces)
		var bonuses: Array[BonusKind] = []
		if sure:
			bonuses.append(SimFixtures.sure_footing())
		footing.seat_rules = SeatRules.of(rules, null, bonuses)
		assert_eq(footing.slides(pose), not sure, "Sure footing %s: the deck pulls it" % sure)
		var at := footing.approach(below, target, pose)
		assert_lt(at.z, target.z, "Sure footing %s: round to its uphill side first" % sure)


## A bot standing in water grips the deck less, as a body does (#620): on a deck listing
## under the grip angle it finds the deck pulling it where the sea stands 0.1 m deep over
## its floor, and holding it where the floor is dry.
func test_a_bot_standing_in_water_finds_the_deck_pulling_it() -> void:
	var layout := SimFixtures.low_deck(0.4)
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	var heel := rules.grip_angle_deg - 2.0
	var sinking := SimFixtures.scenario([[0.0, layout.freeboard, 0.0, heel]])
	var schedule := SinkSchedule.new(sinking, layout.freeboard, SeedStreams.derive(1, "sink"))
	var pose := schedule.pose_at(0)
	var footing := _footing(layout, surfaces)
	var wet := Vector3.INF
	var dry := Vector3.INF
	for step in range(-25, 26):
		var feet := Vector3(0.0, 0.0, step * 0.1)
		var depth := pose.water_height(feet)
		if absf(depth - 0.1) < 0.05 and surfaces.wet(feet, pose):
			wet = feet
		elif not surfaces.wet(feet, pose):
			dry = feet
	assert_ne(wet, Vector3.INF, "the sea stands about 0.1 m deep somewhere on her deck")
	assert_ne(dry, Vector3.INF, "and somewhere it is dry")
	assert_false(footing.slides(pose), "before it stands anywhere, by the dry grip")
	footing.stand(wet, surfaces.under(wet, rules.step_height), pose)
	assert_true(footing.slides(pose), "0.1 m deep, the deck pulls it")
	footing.stand(dry, surfaces.under(dry, rules.step_height), pose)
	assert_false(footing.slides(pose), "dry, it holds")
