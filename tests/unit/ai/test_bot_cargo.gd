extends GutTest
## Bots and the ship's loose cargo (SH10): a bot of a tier that dodges cargo steps out
## of a sliding crate's path, as it sees the crate — through its delayed view, like
## everything else (D10) — and the deck it feels under it now.


## What seat [param seat]'s brain, of [param profile] — normal when none is given —
## answers to one view of [param sim] as it stands.
func _first_move(sim: MatchSim, seat: int, profile: BotProfile = null) -> Vector2:
	if profile == null:
		profile = load(SimFixtures.NORMAL_BOT)
	var source := BotInputSource.new(seat, profile, sim.config)
	source.observe(sim.snapshot(), sim.pose())
	return Vector2(source.next_frame(sim.state.tick).move)


## Seat 0 a little to port of a crate's line, seat 1 — its target — far aft on that
## line, so that left alone the bot walks aft; the crate at [param crate_vel].
func _facing_a_crate(crate_vel: Vector3, profile: BotProfile = null) -> Vector2:
	var crates: Array[ShipProp] = [SimFixtures.crate(Vector3(3.0, 0.0, 0.0))]
	var sim := SimFixtures.sim(2, null, SimFixtures.crated(crates))
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, -0.3), 180.0)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	sim.state.props[0].vel = crate_vel
	return _first_move(sim, 0, profile)


func test_a_bot_steps_out_of_a_sliding_crate_s_path() -> void:
	var still := _facing_a_crate(Vector3.ZERO)
	assert_lt(still.x, 0.0, "a still crate is no matter: the bot walks to its target")
	var coming := _facing_a_crate(Vector3(-4.0, 0.0, 0.0))
	assert_lt(coming.y, 0.0, "a crate sliding at it: the bot steps aside, to port")
	assert_almost_eq(coming.x, 0.0, 1.0, "square to the crate's path")
	var going := _facing_a_crate(Vector3(4.0, 0.0, 0.0))
	assert_lt(going.x, 0.0, "a crate sliding away: no matter")


func test_an_easy_bot_does_not_dodge_cargo() -> void:
	var easy := BotProfile.for_tier(&"easy")
	var still := _facing_a_crate(Vector3.ZERO, easy)
	var coming := _facing_a_crate(Vector3(-4.0, 0.0, 0.0), easy)
	assert_eq(coming, still, "a crate sliding at it changes nothing")
	assert_lt(coming.x, 0.0, "it walks on aft at its target, into the crate's path")


func test_a_crate_seen_still_on_a_deck_tilted_past_its_grip_is_coming() -> void:
	# Past the crate's grip, short of a body's: the deck pulls the crate, not the bot.
	var crate := SimFixtures.crate(Vector3.ZERO)
	var tilt := (crate.grip_angle_deg + SimFixtures.rules().grip_angle_deg) * 0.5
	var crates: Array[ShipProp] = [crate]
	var sim := SimFixtures.sim(2, SimFixtures.tilted(tilt, 0.0), SimFixtures.crated(crates))
	var gravity := sim.pose().ship_gravity(1.0)
	var downhill := Vector2(gravity.x, gravity.z).normalized()
	var aside := downhill.orthogonal()
	# The bot a little downhill of the crate and to one side of its line; its target
	# beyond the crate, uphill, so that left alone it walks up past it.
	var bot := downhill + aside * 0.3
	var mark := -downhill * 10.0
	SimFixtures.place(sim, 0, Vector3(bot.x, 0.0, bot.y), rad_to_deg((mark - bot).angle()))
	SimFixtures.place(sim, 1, Vector3(mark.x, 0.0, mark.y))
	var move := _first_move(sim, 0).normalized()
	assert_gt(move.dot(aside), 0.9, "out of the line the crate will slide down, its side")
