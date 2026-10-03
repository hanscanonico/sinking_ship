extends GutTest

const FRAME := 1.0 / 60.0


func after_each() -> void:
	Input.action_release(&"shove")


func _degrees(offset: Vector3) -> float:
	return rad_to_deg(offset.length())


## Seat 0, played from a LocalInputSource looking at the bow, taps a quick shove at
## seat 1; drawn at 60 frames a second for [param frames] frames, the kick follows
## [param viewed]. Returns each frame's kick in degrees and the frame the shove
## landed on.
func _shove_seen_by(viewed: int, frames: int, kick: ViewKick) -> Array:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), 180.0)
	var source := LocalInputSource.new(0, 0.0, ViewSettings.new())
	var look := InputFrame.quantize_yaw(source.yaw)
	var yaws := {0: source.yaw, 1: PI}
	var degrees: Array[float] = []
	var landed_at := -1
	for frame in frames:
		if frame % 2 == 0:
			var tick := sim.state.tick
			if tick == 0:
				Input.action_press(&"shove")
			else:
				Input.action_release(&"shove")
			var sent := source.next_frame(tick)
			assert_eq(sent.look_yaw, look, "the kick never turns the look a frame sends")
			var events := sim.step([sent, SimFixtures.frame(1, Vector2.ZERO, 0, 180.0)])
			for event: SimEvent in events:
				if event.kind == SimEvent.Kind.SHOVE_LANDED and landed_at == -1:
					landed_at = frame
		kick.follow(sim.snapshot(), viewed, yaws[viewed])
		degrees.append(_degrees(kick.advance(FRAME)))
	assert_eq(source.yaw, 0.0, "nor the look itself")
	assert_ne(landed_at, -1, "the shove landed")
	return [degrees, landed_at]


func test_a_landed_shove_kicks_the_view_and_it_settles() -> void:
	for viewed: int in [0, 1]:
		var seen := _shove_seen_by(viewed, 40, ViewKick.new())
		var degrees: Array[float] = seen[0]
		var landed_at: int = seen[1]
		var most := ViewKick.LAND_DEG if viewed == 0 else ViewKick.TAKE_DEG
		for frame in degrees.size():
			var since := (frame - landed_at) * FRAME
			if frame < landed_at:
				assert_eq(degrees[frame], 0.0, "seat %d: still before the hit" % viewed)
			elif since > ViewKick.KICK_SECONDS:
				assert_eq(
					degrees[frame], 0.0, "seat %d: settled %.0f ms on" % [viewed, since * 1e3]
				)
			assert_lte(degrees[frame], most + 0.0001, "seat %d: small" % viewed)
		var peak: float = degrees.max()
		assert_gt(peak, most * 0.6, "seat %d: it kicks" % viewed)
		assert_eq(degrees.find(peak) - landed_at <= 3, true, "seat %d: at once" % viewed)


func test_taking_a_shove_tips_the_view_the_way_it_is_sent() -> void:
	var at_peak := ViewKick.KICK_RISE
	var sent := {
		"forward": [0.0, Vector3(-1.0, 0.0, 0.0)],
		"back": [PI, Vector3(1.0, 0.0, 0.0)],
		"to the right": [PI * 0.5, Vector3(0.0, 0.0, -1.0)],
		"to the left": [-PI * 0.5, Vector3(0.0, 0.0, 1.0)],
	}
	for way: String in sent:
		var kick := ViewKick.new()
		kick.take(sent[way][0])
		var offset := kick.advance(at_peak)
		var expected: Vector3 = sent[way][1] * deg_to_rad(ViewKick.TAKE_DEG)
		assert_almost_eq(offset, expected, Vector3.ONE * 0.0001, "sent %s" % way)
	var nod := ViewKick.new()
	nod.land()
	assert_lt(nod.advance(at_peak).x, 0.0, "landing one nods the view forward")


func test_view_kick_zero_turns_it_off() -> void:
	var seen := _shove_seen_by(1, 30, ViewKick.new(0.0))
	var degrees: Array[float] = seen[0]
	assert_eq(degrees.max(), 0.0, "no kick")
	var still := ViewKick.new(0.0)
	still.shake()
	assert_eq(still.advance(FRAME), Vector3.ZERO, "and no shake")
	var half := ViewKick.new(0.5)
	half.land()
	assert_almost_eq(
		_degrees(half.advance(ViewKick.KICK_RISE)), ViewKick.LAND_DEG * 0.5, 0.0001, "scaled"
	)


func test_a_lurch_shake_is_small_and_over_within_half_a_second() -> void:
	# SH6's lurch event calls shake(); until then this is its only caller.
	var kick := ViewKick.new()
	kick.shake()
	var moved := false
	var age := 0.0
	while age < 0.5:
		var degrees := _degrees(kick.advance(FRAME))
		age += FRAME
		assert_lte(degrees, ViewKick.SHAKE_DEG * sqrt(3.0), "small")
		moved = moved or degrees > ViewKick.SHAKE_DEG * 0.3
		if age >= ViewKick.SHAKE_SECONDS:
			assert_eq(degrees, 0.0, "over %.0f ms on" % (age * 1e3))
	assert_true(moved, "it shakes")
	assert_lt(ViewKick.SHAKE_SECONDS, 0.5)


func test_switching_seats_never_kicks() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), 180.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3)
	assert_eq(sim.snapshot()["events"].size(), 1, "a shove landed this tick")
	var kick := ViewKick.new()
	kick.follow(sim.snapshot(), 1, PI)
	assert_eq(kick.advance(FRAME), Vector3.ZERO, "joining on the tick is no kick")
	kick.follow(sim.snapshot(), 0, 0.0)
	assert_eq(kick.advance(FRAME), Vector3.ZERO, "nor is switching to the shover")
