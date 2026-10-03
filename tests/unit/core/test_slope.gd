extends GutTest


func _planar(vector: Vector3) -> Vector2:
	return Vector2(vector.x, vector.z)


## The ship-plane downhill, as a unit vector, under [param sim]'s pose now.
func _downhill(sim: MatchSim) -> Vector2:
	return _planar(sim.pose().ship_gravity(SimFixtures.rules().gravity)).normalized()


func test_idle_holds_below_grip_angle() -> void:
	var grip := SimFixtures.rules().grip_angle_deg
	# Past the grip angle neither way on its own, and not together either.
	var leans: Array[Vector2] = [Vector2(0.0, grip - 1.0), Vector2(grip - 1.0, 0.0)]
	leans.append(Vector2(grip * 0.6, -grip * 0.6))
	for lean: Vector2 in leans:
		var sim := SimFixtures.sim(1, SimFixtures.tilted(lean.x, lean.y))
		assert_lt(sim.pose().slope_deg(), grip, "trim %s heel %s" % [lean.x, lean.y])
		var start := Vector3(-8.0, 0.0, 0.0)
		SimFixtures.place(sim, 0, start)
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3 * Ticks.RATE)
		var player := sim.state.seats[0]
		assert_eq(player.pos, start, "trim %s heel %s: held" % [lean.x, lean.y])
		assert_eq(player.vel, Vector3.ZERO)


func test_idle_slides_above_grip_angle() -> void:
	var grip := SimFixtures.rules().grip_angle_deg
	# Past it heeled alone, and past it with trim and heel each below it: the combined
	# slope is what counts.
	var leans: Array[Vector2] = [Vector2(0.0, grip + 2.0), Vector2(grip - 3.0, grip - 3.0)]
	for lean: Vector2 in leans:
		var sim := SimFixtures.sim(1, SimFixtures.tilted(lean.x, lean.y))
		assert_gt(sim.pose().slope_deg(), grip, "trim %s heel %s" % [lean.x, lean.y])
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0))
		var previous := 0.0
		for _tick in Ticks.RATE:
			SimFixtures.step(sim, {0: SimFixtures.frame(0)})
			var speed := _planar(sim.state.seats[0].vel).length()
			assert_gt(speed, previous, "trim %s heel %s: speeding up" % [lean.x, lean.y])
			previous = speed
		var player := sim.state.seats[0]
		assert_eq(player.body, PlayerState.Body.GROUNDED, "sliding, not falling")
		assert_gt(player.pos.distance_to(Vector3(-8.0, 0.0, 0.0)), 0.1, "it slid")


func test_staggered_slides_at_any_tilt() -> void:
	var rules := SimFixtures.rules()
	# Seat 0 shoves seat 1 toward the bow, across the slope of a deck heeled by less
	# than the grip angle: an idle body holds there, a staggered one has no grip and
	# its slide bends downhill — starboard under a starboard list, port under port.
	for heel: float in [0.0, 1.0, 5.0, rules.grip_angle_deg - 1.0, -5.0]:
		var sim := SimFixtures.sim(3, SimFixtures.tilted(0.0, heel))
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0), 0.0)
		SimFixtures.place(sim, 1, Vector3(-6.9, 0.0, 0.0), 180.0)
		var idle_at := Vector3(-8.0, 0.0, -2.5)
		SimFixtures.place(sim, 2, idle_at)
		var shove := SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)
		var drift := 0.0
		for _tick in Ticks.RATE:
			SimFixtures.step(sim, {0: shove, 1: SimFixtures.frame(1), 2: SimFixtures.frame(2)})
			if sim.state.seats[1].is_staggered():
				drift = sim.state.seats[1].pos.z
		assert_gt(sim.state.seats[1].pos.x, -6.0, "heel %s: the shove landed" % heel)
		assert_eq(sim.state.seats[2].pos, idle_at, "heel %s: the idle body holds" % heel)
		if heel == 0.0:
			assert_eq(drift, 0.0, "a level deck sends it straight")
		else:
			assert_gt(drift * signf(heel), 0.0, "heel %s: the slide bends downhill" % heel)


func test_slide_runs_downhill_in_ship_space() -> void:
	# Bow down and listing to port together: downhill is neither along nor across.
	var sim := SimFixtures.sim(1, SimFixtures.tilted(10.0, -12.0))
	var start := Vector3(-8.0, 0.0, 1.0)
	SimFixtures.place(sim, 0, start)
	var height_before := sim.pose().world_height(start)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	var player := sim.state.seats[0]
	var moved := _planar(player.pos - start)
	var downhill := _downhill(sim)
	assert_gt(moved.length(), 0.1, "it slid")
	assert_almost_eq(moved.angle_to(downhill), 0.0, 0.001, "straight downhill")
	assert_gt(downhill.x, 0.0, "toward the low bow")
	assert_lt(downhill.y, 0.0, "and the low port side")
	assert_lt(sim.pose().world_height(player.pos), height_before, "and lower in the world")


func test_walking_uphill_outpaces_the_slide() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2, SimFixtures.tilted(rules.grip_angle_deg + 4.0, 0.0))
	var walker_from := Vector3(10.0, 0.0, 2.0)
	var idler_from := Vector3(-10.0, 0.0, -2.0)
	SimFixtures.place(sim, 0, walker_from)
	SimFixtures.place(sim, 1, idler_from)
	var uphill := -_downhill(sim)
	var seconds := 2.0
	var frames := {0: SimFixtures.frame(0, uphill), 1: SimFixtures.frame(1)}
	SimFixtures.step(sim, frames, Ticks.from_seconds(seconds))
	var walked := _planar(sim.state.seats[0].pos - walker_from).dot(uphill)
	var slid := _planar(sim.state.seats[1].pos - idler_from).dot(uphill)
	assert_lt(slid, 0.0, "standing still, the deck takes you down")
	assert_gt(walked, rules.walk_speed * seconds * 0.9, "walking up, you climb near full speed")
	assert_gt(sim.pose().world_height(sim.state.seats[0].pos), sim.pose().world_height(walker_from))


func test_heel_sign_decides_which_rail_you_slide_to() -> void:
	var rules := SimFixtures.rules()
	var area := SimFixtures.deck().platforms[0].area
	var lean := rules.grip_angle_deg + 4.0
	var rail_to := {
		lean: area.end.y - rules.body_radius, -lean: area.position.y + rules.body_radius
	}
	for heel: float in rail_to:
		var sim := SimFixtures.sim(1, SimFixtures.tilted(0.0, heel))
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0))
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 4 * Ticks.RATE)
		var player := sim.state.seats[0]
		assert_eq(player.body, PlayerState.Body.GROUNDED, "heel %s: held by the rail" % heel)
		assert_almost_eq(player.pos.z, rail_to[heel], 0.0001, "heel %s: against its rail" % heel)
		assert_almost_eq(player.pos.x, -8.0, 0.0001, "straight across")
		assert_almost_eq(player.vel.z, 0.0, 0.0001, "no speed left into the rail")
