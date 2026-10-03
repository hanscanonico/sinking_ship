extends GutTest

const MAX := InputFrame.AXIS_MAX
const STEPS := InputFrame.YAW_STEPS


func test_move_is_clamped_to_unit_length() -> void:
	for direction: Vector2 in [Vector2(3.0, 4.0), Vector2(1.0, 1.0), Vector2(-9.0, 0.5)]:
		var move := InputFrame.quantize(direction)
		assert_true(move.length_squared() <= MAX * MAX, "%s stays within %d" % [move, MAX])
		assert_almost_eq(Vector2(move).angle(), direction.angle(), 0.02)

	var wild := InputFrame.new(0, 0, Vector2i(500, -500))
	var valid := wild.validated(0, 0)
	assert_true(valid.move.length_squared() <= MAX * MAX)

	# The sim clamps a frame it is handed, so an oversized one cannot outrun walking.
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	SimFixtures.step(sim, {0: wild}, 20)
	var speed := Vector2(sim.state.seats[0].vel.x, sim.state.seats[0].vel.z).length()
	assert_almost_eq(speed, SimFixtures.rules().walk_speed, 0.05)


func test_quantization_round_trips() -> void:
	var mismatches := 0
	for x in range(-MAX, MAX + 1):
		for y in range(-MAX, MAX + 1):
			var axes := Vector2i(x, y)
			if axes.length_squared() > MAX * MAX:
				continue
			var frame := InputFrame.new(0, 0, axes)
			if InputFrame.quantize(frame.move_vector()) != axes:
				mismatches += 1
	assert_eq(mismatches, 0)


func test_buttons_are_held_state() -> void:
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var shove := SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)
	var starts := 0
	for _tick in 40:
		var before := sim.state.seats[0].action
		SimFixtures.step(sim, {0: shove})
		if (
			before != PlayerState.Action.WINDUP
			and sim.state.seats[0].action == PlayerState.Action.WINDUP
		):
			starts += 1
	assert_eq(starts, 1, "holding shove is one press")

	# Let go, and the held shove is thrown and recovered from before the next press.
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 20)
	SimFixtures.step(sim, {0: shove})
	assert_eq(sim.state.seats[0].action, PlayerState.Action.WINDUP, "release and press again")


func test_look_yaw_quantizes_one_turn_to_65536_steps() -> void:
	var step := TAU / STEPS
	assert_eq(STEPS, 65536)
	assert_eq(InputFrame.quantize_yaw(0.0), 0)
	assert_eq(InputFrame.quantize_yaw(step), 1)
	assert_eq(InputFrame.quantize_yaw(PI * 0.5), STEPS / 4, "a quarter turn to starboard")
	assert_eq(InputFrame.quantize_yaw(PI), STEPS / 2)
	assert_eq(InputFrame.quantize_yaw(step * 0.49), 0, "rounds to the nearest step")
	var mismatches := 0
	for yaw in STEPS:
		if InputFrame.quantize_yaw(InputFrame.yaw_angle(yaw)) != yaw:
			mismatches += 1
	assert_eq(mismatches, 0, "every step is its own angle")


func test_look_yaw_wraps_into_range() -> void:
	var step := TAU / STEPS
	assert_eq(InputFrame.quantize_yaw(TAU), 0, "a whole turn is no turn")
	assert_eq(InputFrame.quantize_yaw(-step), STEPS - 1)
	assert_eq(InputFrame.quantize_yaw(3.0 * TAU + PI), STEPS / 2)
	assert_eq(InputFrame.quantize_yaw(-PI * 0.5), STEPS * 3 / 4)
	for wild: int in [STEPS, STEPS + 7, -1, -STEPS - 3, 5 * STEPS + 100]:
		var valid := InputFrame.new(0, 0, Vector2i.ZERO, 0, wild).validated(0, 0)
		assert_eq(valid.look_yaw, posmod(wild, STEPS), "look %d" % wild)
	assert_almost_eq(InputFrame.yaw_angle(STEPS - 1), -step, 1e-9, "just short of a turn")
	assert_almost_eq(InputFrame.yaw_angle(STEPS / 2), -PI, 1e-9)


func test_move_is_relative_to_look() -> void:
	var quarter := STEPS / 4
	# Stick up walks where you look; stick right steps to the look's right.
	assert_eq(InputFrame.from_screen(Vector2.UP, 0), Vector2i(MAX, 0), "look at the bow")
	assert_eq(InputFrame.from_screen(Vector2.UP, quarter), Vector2i(0, MAX), "look starboard")
	assert_eq(InputFrame.from_screen(Vector2.RIGHT, 0), Vector2i(0, MAX), "bow: right is starboard")
	assert_eq(InputFrame.from_screen(Vector2.DOWN, quarter), Vector2i(0, -MAX), "back to port")
	for look: int in [0, 1000, quarter, 40000, STEPS - 1]:
		var ahead := Vector2.from_angle(InputFrame.yaw_angle(look))
		var walked := Vector2(InputFrame.from_screen(Vector2.UP, look))
		assert_almost_eq(walked.angle_to(ahead), 0.0, 0.01, "stick up under look %d" % look)
		for stick: Vector2 in [Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.6, 0.8)]:
			var one_way := InputFrame.from_screen(stick, look)
			var turned_round := InputFrame.from_screen(stick, (look + STEPS / 2) % STEPS)
			assert_ne(one_way, Vector2i.ZERO)
			assert_almost_eq(
				Vector2(turned_round).angle_to(-Vector2(one_way)),
				0.0,
				0.02,
				"stick %s under looks %d and %d" % [stick, look, look + STEPS / 2]
			)

	# And the sim walks it there.
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var look := InputFrame.quantize_yaw(deg_to_rad(120.0))
	var walk := InputFrame.new(0, 0, InputFrame.from_screen(Vector2.UP, look), 0, look)
	SimFixtures.step(sim, {0: walk}, 10)
	var moved := Vector2(sim.state.seats[0].pos.x, sim.state.seats[0].pos.z)
	assert_gt(moved.length(), 0.5)
	assert_almost_eq(rad_to_deg(moved.angle()), 120.0, 1.0, "the body went where it looked")


func test_validated_frame_keeps_the_look() -> void:
	for look: int in [0, 1, 12345, STEPS / 2, STEPS - 1]:
		var frame := InputFrame.new(3, 9, Vector2i(10, -20), InputFrame.SHOVE, look)
		var valid := frame.validated(3, 9)
		assert_eq(valid.look_yaw, look)
		assert_eq([valid.move, valid.buttons], [frame.move, frame.buttons])

	# The sim takes the look as the seat's facing and keeps it in the snapshot.
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var look := InputFrame.quantize_yaw(deg_to_rad(-75.0))
	SimFixtures.step(sim, {0: InputFrame.new(0, 0, Vector2i.ZERO, 0, look)})
	var entry: Dictionary = sim.snapshot()["seats"][0]
	assert_eq(entry["facing"], InputFrame.yaw_angle(look))
	assert_eq(entry["last_input"][2], look, "the snapshot's last input carries the look")
	assert_eq(MatchSim.from_snapshot(sim.snapshot(), sim.config).state.seats[0].last_look, look)
