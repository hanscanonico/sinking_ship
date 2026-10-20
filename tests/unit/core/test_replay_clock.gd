extends GutTest
## The replay clock steps the timeline as many ticks as the speed and the frames
## add up to, caps a stall, steps nothing paused or at the end, and walks the
## speed ladder the replay data gives it, clamped at both ends (R4, #212).

const LADDER := [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
const FRAME := 1.0 / 60.0


func _clock() -> ReplayClock:
	return ReplayClock.new(PackedFloat32Array(LADDER))


func _ticks_over(clock: ReplayClock, frames: int, delta: float) -> int:
	var ticks := 0
	for _frame in frames:
		ticks += clock.advance(delta, false)
	return ticks


func test_a_second_of_frames_steps_a_second_of_match_at_one_times() -> void:
	assert_eq(_ticks_over(_clock(), 60, FRAME), Ticks.RATE)


func test_the_speed_scales_the_ticks_stepped() -> void:
	var slow := _clock()
	slow.speed_down()
	slow.speed_down()
	assert_eq(slow.speed(), 0.25)
	assert_eq(_ticks_over(slow, 60, FRAME), 7, "a quarter of a second of match, rounded down")
	var fast := _clock()
	for _step in 3:
		fast.speed_up()
	assert_eq(fast.speed(), 8.0)
	assert_eq(fast.advance(FRAME, false), 4, "eight times 1/60 s is four ticks")


func test_a_stall_is_capped_and_never_fast_forwards() -> void:
	var clock := _clock()
	assert_eq(clock.advance(1.0, false), ReplayClock.MAX_STEPS_PER_FRAME, "a second's stall")
	assert_eq(clock.advance(FRAME, false), 1, "the next frame steps one, not the rest")


func test_paused_or_at_the_end_nothing_steps() -> void:
	var clock := _clock()
	clock.paused = true
	assert_eq(_ticks_over(clock, 60, FRAME), 0, "paused")
	assert_eq(clock.alpha(), 0.0, "and nothing is carried")
	clock.paused = false
	assert_eq(clock.advance(1.0, true), 0, "at the end")


func test_alpha_is_how_far_into_the_next_tick() -> void:
	var clock := _clock()
	assert_eq(clock.advance(FRAME, false), 0)
	assert_almost_eq(clock.alpha(), 0.5, 0.001, "half a tick in")
	clock.reset()
	assert_eq(clock.alpha(), 0.0, "dropped by a reset")


func test_the_ladder_clamps_at_both_ends() -> void:
	var clock := _clock()
	for _step in 10:
		clock.speed_up()
	assert_eq(clock.speed(), 8.0)
	for _step in 10:
		clock.speed_down()
	assert_eq(clock.speed(), 0.25)
	assert_eq(ReplayClock.new(PackedFloat32Array()).speed(), 1.0, "no ladder: one times")
