extends GutTest

const MAX := InputFrame.AXIS_MAX


func test_move_is_clamped_to_unit_length() -> void:
	for direction: Vector2 in [Vector2(3.0, 4.0), Vector2(1.0, 1.0), Vector2(-9.0, 0.5)]:
		var move := InputFrame.quantize(direction)
		assert_true(move.length_squared() <= MAX * MAX, "%s stays within %d" % [move, MAX])
		assert_almost_eq(Vector2(move).angle(), direction.angle(), 0.02)

	var wild := InputFrame.new(0, 0, Vector2i(500, -500), 0, Vector2i(-300, 0))
	var valid := wild.validated(0, 0)
	assert_true(valid.move.length_squared() <= MAX * MAX)
	assert_true(valid.aim.length_squared() <= MAX * MAX)

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

	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	SimFixtures.step(sim, {0: shove})
	assert_eq(sim.state.seats[0].action, PlayerState.Action.WINDUP, "release and press again")


func test_from_screen_respects_camera_yaw() -> void:
	for stick: Vector2 in [Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.6, 0.8)]:
		var from_one_side := InputFrame.from_screen(stick, 0.0)
		var from_the_other := InputFrame.from_screen(stick, PI)
		assert_ne(from_one_side, Vector2i.ZERO)
		assert_eq(from_the_other, -from_one_side, "stick %s" % stick)
	# Yaw 0 looks across the beam from starboard: right is the bow, up is to port.
	assert_eq(InputFrame.from_screen(Vector2.RIGHT, 0.0), Vector2i(MAX, 0))
	assert_eq(InputFrame.from_screen(Vector2.UP, 0.0), Vector2i(0, -MAX))
