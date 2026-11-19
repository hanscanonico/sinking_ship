extends GutTest
## The ghost (GLOSSARY: Ghost, #655): it walks and jumps by a live seat's own rules — tick
## for tick where a seat in the match goes —, railings hold it, water neither slows nor
## drowns it, it starts only where something of her is under it and is done once off her;
## and it is presentation only: a match steps to the same snapshots with one walking.


## A frame moving along [param move] in the ship plane, looking along +x.
func _frame(move: Vector2, buttons := 0) -> InputFrame:
	return InputFrame.new(0, 0, InputFrame.quantize(move), buttons, 0)


func _ghost(sim: MatchSim, at: Vector3) -> GhostWalk:
	var ghost := GhostWalk.new(sim.config, sim.schedule)
	assert_true(ghost.start(sim.snapshot(), at, 0, Vector3.RIGHT), "it stands on her")
	return ghost


## A walk with a jump in it, the ghost given the very frames a live seat is: it is where
## the seat is, every tick, bit for bit.
func test_it_walks_and_jumps_as_a_live_seat_does() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	SimFixtures.place(sim, 1, Vector3(-12.0, 0.0, 0.0))
	var ghost := _ghost(sim, Vector3.ZERO)
	var risen := 0.0
	for tick in 45:
		var frame := _frame(Vector2(1.0, 0.3), InputFrame.JUMP if tick == 5 else 0)
		var snapshot := sim.snapshot()
		assert_true(ghost.walk(snapshot, frame))
		var row: Array[InputFrame] = [frame, null]
		sim.step(row)
		var seat := sim.state.seats[0]
		assert_eq(ghost.body.pos, seat.pos, "tick %d: where the seat is" % tick)
		assert_eq(ghost.body.body, seat.body)
		risen = maxf(risen, ghost.body.pos.y)
	assert_almost_eq(risen, sim.config.rules.jump_height, 0.05, "it jumped a seat's jump")
	assert_eq(ghost.body.body, PlayerState.Body.GROUNDED, "and landed")


## On her deck a metre under the sea it walks as far as on a dry one, and stays on its feet.
func test_water_neither_slows_nor_drowns_it() -> void:
	var dry_sim := SimFixtures.sim(2)
	var dry := _ghost(dry_sim, Vector3.ZERO)
	var sunk_sim := SimFixtures.sim(2, SimFixtures.scenario([[0.0, 4.0, 0.0, 0.0]]))
	assert_gt(sunk_sim.schedule.pose_at(0).water_height(Vector3.ZERO), 0.5, "her deck is under")
	var sunk := _ghost(sunk_sim, Vector3.ZERO)
	for _tick in 30:
		assert_true(dry.walk(dry_sim.snapshot(), _frame(Vector2.RIGHT)))
		assert_true(sunk.walk(sunk_sim.snapshot(), _frame(Vector2.RIGHT)))
	assert_eq(sunk.body.pos, dry.body.pos, "no slower under water")
	assert_eq(sunk.body.body, PlayerState.Body.GROUNDED, "on its feet, never swimming")


## A railing holds it as a wall does — it never vaults one, however it comes — and off the
## end of her deck it is done.
func test_railings_hold_it_and_off_her_it_is_done() -> void:
	var sim := SimFixtures.sim(2)
	var ghost := _ghost(sim, Vector3.ZERO)
	var edge := SimFixtures.deck().platforms[0].area.end.y
	for _tick in 60:
		assert_true(ghost.walk(sim.snapshot(), _frame(Vector2(0.0, 1.0))))
	assert_lt(ghost.body.pos.z, edge, "held inside the railing")
	assert_eq(ghost.body.body, PlayerState.Body.GROUNDED)
	var walked := true
	for _tick in 120:
		walked = ghost.walk(sim.snapshot(), _frame(Vector2.RIGHT))
		if not walked:
			break
	assert_false(walked, "off the end of her deck")
	assert_false(ghost.active, "and the view no longer its")


## It starts on the floor under where it is put, and nowhere off her.
func test_it_starts_only_on_her() -> void:
	var sim := SimFixtures.sim(2)
	var ghost := GhostWalk.new(sim.config, sim.schedule)
	assert_false(ghost.start(sim.snapshot(), Vector3(0.0, 0.0, 30.0), 0, Vector3.RIGHT))
	assert_false(ghost.active, "in the sea off her, no ghost")
	assert_true(ghost.start(sim.snapshot(), Vector3(1.0, 0.8, 0.5), 0, Vector3.RIGHT))
	assert_true(ghost.active)
	assert_eq(ghost.body.pos, Vector3(1.0, 0.0, 0.5), "on her deck under that spot")
	assert_eq(ghost.body.body, PlayerState.Body.GROUNDED)
	assert_almost_eq(ghost.look.yaw, 0.0, 1e-5, "looking where it was asked to")
	assert_eq(ghost.stature(), 1.0, "standing a seat's height")


## Its frames run one tick for every tick's worth of seconds, and its feet are drawn
## between the last two.
func test_its_ticks_are_the_frames_seconds() -> void:
	var sim := SimFixtures.sim(2)
	var ghost := _ghost(sim, Vector3.ZERO)
	var from := ghost.body.pos
	assert_true(ghost.advance(sim.snapshot(), Ticks.SECONDS_PER_TICK * 0.5))
	assert_eq(ghost.body.pos, from, "half a tick walks nothing yet")
	assert_eq(ghost.feet(), from)


## A match steps to the same snapshots, field for field and bit for bit, with a ghost
## walking and jumping on her every tick as without: nothing of it reaches the sim.
func test_a_match_is_the_same_with_a_ghost_walking() -> void:
	var sinking := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [4.0, 4.0, 2.0, 3.0]])
	var alone := SimFixtures.sim(3, sinking)
	var watched := SimFixtures.sim(3, sinking)
	var ghost := _ghost(watched, Vector3(2.0, 0.0, 1.0))
	for tick in 150:
		var row: Array[InputFrame] = [
			_frame(Vector2(1.0, 0.5), InputFrame.JUMP if tick % 20 == 0 else 0),
			_frame(Vector2(-0.5, 1.0), InputFrame.SHOVE if tick % 15 == 0 else 0),
			null,
		]
		alone.step(row)
		ghost.walk(watched.snapshot(), _frame(Vector2(-1.0, 0.2), InputFrame.JUMP))
		watched.step(row)
		var ours := watched.snapshot()
		var theirs := alone.snapshot()
		assert_eq(SnapshotDigest.quantized(ours), SnapshotDigest.quantized(theirs))
		if var_to_bytes(ours) != var_to_bytes(theirs):
			fail_test("tick %d differs bit for bit with a ghost walking" % tick)
			return
