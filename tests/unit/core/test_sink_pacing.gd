extends GutTest
## SinkPacing: the paced clock (Q20) — physics seconds to match seconds by how far she has
## flooded, its phases' shares of the match's length, its limits and the plunge's least.
## Every expected number is worked by hand from the default data: 900 s, phases at 0.3
## and 0.8, shares 25 / 50 / 25, the plunge the last 0.05 for 20 s at least, 0.4×…6×.


## The physics seconds she first holds each fortieth of her water, flooding evenly over
## [param seconds]: the k-th at k/40 of them.
func _even(seconds: float) -> PackedFloat64Array:
	var sunk := PackedFloat64Array()
	for step in range(1, SinkTimeline.SUNK_STEPS + 1):
		sunk.append(seconds * step / SinkTimeline.SUNK_STEPS)
	return sunk


func _pacing() -> SinkPacing:
	return SinkPacing.load_default()


func test_the_data_is_the_decided_pacing() -> void:
	var pacing := _pacing()
	assert_eq(pacing.problems(), PackedStringArray(), "the shared data is sound")
	assert_eq(pacing.length, 900.0, "about 15 minutes")
	assert_eq([pacing.opening_until, pacing.middle_until, pacing.plunge_from], [0.3, 0.8, 0.95])
	assert_eq([pacing.opening_share, pacing.middle_share], [0.25, 0.5])
	assert_eq([pacing.slowest, pacing.fastest, pacing.plunge_least], [0.4, 6.0, 20.0])


func test_an_hour_of_even_flooding_plays_in_fifteen_minutes() -> void:
	# 3600 s, 90 s a fortieth: the opening's 12 run at 4.8×, the middle's 20 at 4×, the
	# end's 8 at 3.2× — inside the limits, so the phases land on 225, 675 and 900 s.
	var clock := _pacing().clock_of(_even(3600.0))
	assert_almost_eq(clock.match_of(1080.0), 225.0, 1e-6, "the opening, a quarter")
	assert_almost_eq(clock.match_of(2880.0), 675.0, 1e-6, "the middle, half")
	assert_almost_eq(clock.match_of(3600.0), 900.0, 1e-6, "gone at 15 minutes")
	assert_almost_eq(clock.match_of(45.0), 45.0 / 4.8, 1e-6, "even inside a fortieth")


func test_a_slow_opening_runs_at_most_six_times_the_physics() -> void:
	# Five hours evenly: the opening asks for 24×, the middle 20× and the end 16×; all
	# held to 6×, so the opening's 5400 s take 900 s and she goes at 3000 s.
	var clock := _pacing().clock_of(_even(18000.0))
	assert_almost_eq(clock.match_of(5400.0), 900.0, 1e-6, "realism over the length")
	assert_almost_eq(clock.match_of(18000.0), 3000.0, 1e-6)


func test_a_rushed_end_runs_at_least_four_tenths_of_the_physics() -> void:
	# Six minutes evenly, 9 s a fortieth: the opening at 0.48×; the middle (0.4×) and the
	# end (0.32×) held to 0.4× — 225 s, then 180 s at 0.4× is 450 s, then 72 s is 180 s.
	var clock := _pacing().clock_of(_even(360.0))
	assert_almost_eq(clock.match_of(108.0), 225.0, 1e-6)
	assert_almost_eq(clock.match_of(288.0), 675.0, 1e-6)
	assert_almost_eq(clock.match_of(360.0), 855.0, 1e-6, "shorter than asked, never slower")


func test_slow_then_fast_is_evened_out() -> void:
	# The real shape: 300 s a fortieth through the opening, 30 s through the middle, 5 s
	# through the end. The opening's 16× is held to 6× (50 s a fortieth, 600 s); the
	# middle runs at 30 / 22.5 (450 s); the end's 0.18× is held to 0.4× (12.5 s each).
	var sunk := PackedFloat64Array()
	var at := 0.0
	for step in range(1, SinkTimeline.SUNK_STEPS + 1):
		at += 300.0 if step <= 12 else (30.0 if step <= 32 else 5.0)
		sunk.append(at)
	var clock := _pacing().clock_of(sunk)
	assert_almost_eq(clock.match_of(3600.0), 600.0, 1e-6, "the opening, much sooner")
	assert_almost_eq(clock.match_of(4200.0), 1050.0, 1e-6, "the middle, its half")
	assert_almost_eq(clock.match_of(4240.0), 1150.0, 1e-6, "the end, slowed as far as it goes")
	assert_almost_eq(clock.match_of(4240.0) - clock.match_of(4230.0), 25.0, 1e-6, "the plunge")


func test_a_short_length_still_gives_the_plunge_twenty_seconds() -> void:
	# 80 s of match over six minutes evenly: the end's fortieths would get 2.5 s each, but
	# the plunge's two take 10 s each — 0.9× — so the plunge lasts 20 s.
	var pacing: SinkPacing = _pacing().duplicate()
	pacing.length = 80.0
	var clock: PacedClock = pacing.clock_of(_even(360.0))
	assert_almost_eq(clock.match_of(360.0) - clock.match_of(342.0), 20.0, 1e-6)


func test_a_sinking_that_stops_keeps_its_last_pace() -> void:
	# She floods evenly to half her water in 1800 s and no further: past that the clock
	# runs on at the middle's 4×.
	var sunk := _even(3600.0)
	for step in range(20, SinkTimeline.SUNK_STEPS):
		sunk[step] = -1.0
	var clock := _pacing().clock_of(sunk)
	assert_almost_eq(clock.match_of(1800.0), 225.0 + 8 * 22.5, 1e-6)
	assert_almost_eq(clock.match_of(2200.0), 405.0 + 100.0, 1e-6, "on at 4×")


func test_no_flooding_is_the_physics_itself() -> void:
	var clock := _pacing().clock_of(PackedFloat64Array())
	assert_eq(clock.match_of(1234.5), 1234.5, "one to one")
	assert_eq(clock.physics_of(77.0), 77.0)


func test_match_time_reads_back_to_physics_time() -> void:
	var clock := _pacing().clock_of(_even(3600.0))
	for seconds: float in [0.0, 13.0, 1080.0, 2000.5, 3599.0, 3600.0, 4000.0]:
		assert_almost_eq(clock.physics_of(clock.match_of(seconds)), seconds, 1e-6)


func test_its_problems() -> void:
	var bad: SinkPacing = _pacing().duplicate()
	bad.middle_until = 0.2
	bad.slowest = 7.0
	bad.length = 0.0
	assert_eq(
		bad.problems(),
		PackedStringArray(
			[
				"pacing: the length must be over 0",
				"pacing: the phases' marks must rise within 0…1",
				"pacing: the limits must run from over 0 up",
			]
		)
	)
