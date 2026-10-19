extends GutTest
## Crawling (#148, part 2): a body crawls wherever the headroom over its floor is less
## than body_height and at least crawl_height — no button, nothing new in its frames
## (D3) — at crawl_speed, crawl_height tall, and never jumps; a floor with less headroom
## than crawl_height takes no body.


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func test_the_rules_hold_a_crawl_under_a_standing_body() -> void:
	assert_eq(_rules().problems(), PackedStringArray(), "the shipped numbers hold")
	assert_lt(_rules().crawl_height, _rules().body_height)
	assert_lt(_rules().crawl_speed, _rules().walk_speed)
	var tall: BrawlRules = _rules().duplicate()
	tall.crawl_height = tall.body_height
	assert_eq(
		tall.problems(), PackedStringArray(["brawl rules: crawl_height must be below body_height"])
	)
	var flat: BrawlRules = _rules().duplicate()
	flat.crawl_height = 0.0
	assert_eq(flat.problems(), PackedStringArray(["brawl rules: crawl_height must be positive"]))
	var still: BrawlRules = _rules().duplicate()
	still.crawl_speed = 0.0
	assert_eq(still.problems(), PackedStringArray(["brawl rules: crawl_speed must be positive"]))
	var quick: BrawlRules = _rules().duplicate()
	quick.crawl_speed = quick.walk_speed + 1.0
	assert_eq(
		quick.problems(), PackedStringArray(["brawl rules: crawl_speed must not exceed walk_speed"])
	)


func _planar_speed(player: PlayerState) -> float:
	return Vector2(player.vel.x, player.vel.z).length()


## The flat deck with a roof [param height] over it from x 0 to 4, across her beam:
## test data, no ship has a space this low yet.
func _roofed_sim(seats: int, height: float) -> MatchSim:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	layout.platforms = layout.platforms.duplicate()
	var roof := ShipPlatform.new()
	roof.name = &"roof"
	roof.area = Rect2(0.0, -4.0, 4.0, 8.0)
	roof.height = height
	layout.platforms.append(roof)
	return SimFixtures.sim(seats, null, layout)


func test_a_body_walking_under_a_low_ceiling_crawls_and_stands_again_past_it() -> void:
	var rules := _rules()
	var sim := _roofed_sim(1, 1.0)
	SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, 0.0))
	var walker := sim.state.seats[0]
	var toward_bow := {0: SimFixtures.frame(0, Vector2.RIGHT)}
	var crawled := 0
	for _tick in 10 * Ticks.RATE:
		if walker.pos.x >= 8.0:
			break
		SimFixtures.step(sim, toward_bow)
		assert_eq(walker.body, PlayerState.Body.GROUNDED, "on the deck at x %.2f" % walker.pos.x)
		assert_eq(walker.pos.y, 0.0)
		var height := rules.height_at(sim.surfaces, walker.pos)
		if walker.pos.x > 1.0 and walker.pos.x < 4.0:
			crawled += 1
			assert_eq(height, rules.crawl_height, "crawling under the roof")
			assert_almost_eq(_planar_speed(walker), rules.crawl_speed, 0.0001, "at a crawl")
		elif walker.pos.x < -0.5 or walker.pos.x > 4.5:
			assert_eq(height, rules.body_height, "standing in the open")
		if walker.pos.x > 5.0:
			assert_almost_eq(_planar_speed(walker), rules.walk_speed, 0.0001, "walking again")
	assert_gt(crawled, 0, "it went under")
	assert_gte(walker.pos.x, 8.0, "and out the far side")


func test_no_body_goes_under_a_ceiling_lower_than_crawl_height() -> void:
	var rules := _rules()
	var sim := _roofed_sim(1, 0.6)
	SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, 0.0))
	var walker := sim.state.seats[0]
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}, 3 * Ticks.RATE)
	assert_almost_eq(walker.pos.x, -rules.body_radius, 0.0001, "held at the roof's edge")
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_eq(rules.height_at(sim.surfaces, walker.pos), rules.body_height, "standing outside it")


func test_a_crawler_cannot_jump() -> void:
	var rules := _rules()
	var sim := _roofed_sim(2, 1.0)
	SimFixtures.place(sim, 0, Vector3(2.0, 0.0, 0.0))
	SimFixtures.place(sim, 1, Vector3(-3.0, 0.0, 0.0))
	var crawler := sim.state.seats[0]
	var stamina := crawler.stamina
	var events := SimFixtures.step(
		sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)}, Ticks.RATE
	)
	assert_eq(crawler.body, PlayerState.Body.GROUNDED, "still on the deck")
	assert_eq(crawler.pos.y, 0.0)
	assert_eq(crawler.stamina, stamina, "and nothing spent")
	assert_false(crawler.jumped)
	assert_true(events.is_empty(), "no take-off, no landing: %s" % [events])
	# Out from under the roof, the same press jumps.
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	sim.state.seats[1].pos = Vector3(-6.0, 0.0, 0.0)
	SimFixtures.place(sim, 0, Vector3(-3.0, 0.0, 0.0))
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
	assert_eq(crawler.body, PlayerState.Body.AIRBORNE, "standing, it jumps")
	assert_lt(crawler.stamina, stamina, "for jump_cost")
	assert_almost_eq(stamina - crawler.stamina, rules.jump_cost, 0.0001)


func test_a_crawler_in_a_flooding_crawl_space_swims_and_breathes_in_its_pocket() -> void:
	# The steamer's aft port cabin with a roof a metre over its floor, aft of x −10.4 —
	# test data — and its cell flooded 0.8 m deep, 0.2 m under that roof, its air trapped
	# over the water. A crawler under the roof floats, its head under the roof and in the
	# trapped air, and its meter drains at the pocket's rate.
	var rules := _rules()
	var floor_y := -2.6
	var roof_y := floor_y + 1.0
	var water := floor_y + 0.8
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	layout.platforms = layout.platforms.duplicate()
	var roof := ShipPlatform.new()
	roof.name = &"cabin roof"
	roof.area = Rect2(-12.9, -4.7, 2.5, 4.0)
	roof.height = roof_y
	layout.platforms.append(roof)
	var sim := SimFixtures.sim(2, null, layout)
	HeldPose.hold(sim, HeldPose.flooded(layout, 0.5, {&"aft_cabins": [water, 0.5]}))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.place(sim, 0, Vector3(-11.5, floor_y, -2.7))
	var crawler := sim.state.seats[0]
	assert_eq(rules.height_at(sim.surfaces, crawler.pos), rules.crawl_height, "in a crawl space")
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_eq(crawler.body, PlayerState.Body.SWIMMING, "the water took it off its knees")
	assert_gt(crawler.pos.y, floor_y + 0.01, "afloat")
	var head := crawler.pos + Vector3.UP * rules.head_height(rules.crawl_height)
	assert_lt(head.y, roof_y, "its head under the roof")
	assert_gt(head.y, water, "over the water")
	assert_true(sim.pose().in_pocket(head), "in the trapped air")
	var cold := crawler.cold
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_almost_eq(cold - crawler.cold, rules.pocket_cold_rate, 0.0001, "at the pocket's rate")
	assert_lt(crawler.pos.y + rules.crawl_height, roof_y + 0.0001, "never through the roof")


func test_the_roof_parts_a_crawler_from_those_on_it_and_a_shove_beside_it_lands() -> void:
	# Seat 1 stands on the roof just over seat 0, crawling under it: the roof keeps them
	# apart, and seat 1's shove down through it misses. Seat 2, standing clear of the
	# roof's edge, shoves seat 0 as it would anyone: a crawler is shoved as it always was.
	var sim := _roofed_sim(3, 1.0)
	var crawler := sim.state.seats[0]
	SimFixtures.place(sim, 0, Vector3(1.0, 0.0, 0.0), 180.0)
	SimFixtures.place(sim, 1, Vector3(1.0, 1.0, 0.3), -90.0)
	SimFixtures.place(sim, 2, Vector3(-0.5, 0.0, 0.0), 0.0)
	SimFixtures.step(sim)
	assert_eq(crawler.pos, Vector3(1.0, 0.0, 0.0), "not pushed by the body over the roof")
	assert_eq(sim.state.seats[1].pos, Vector3(1.0, 1.0, 0.3), "nor it by the crawler")
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.SHOVE)})
	SimFixtures.step(sim, {1: SimFixtures.frame(1)}, Ticks.RATE)
	assert_false(crawler.is_staggered(), "a shove through the roof misses")
	SimFixtures.step(sim, {2: SimFixtures.frame(2, Vector2.ZERO, InputFrame.SHOVE)})
	SimFixtures.step(sim, {2: SimFixtures.frame(2)}, 5)
	assert_true(crawler.is_staggered(), "a shove from beside the roof lands")
