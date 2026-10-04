extends GutTest
## A correction to the local seat's prediction is drawn away, never jumped (D12).

const SECONDS := 0.1


func test_a_correction_is_drawn_away_within_correction_time() -> void:
	var smoother := CorrectionSmoother.new(SECONDS)
	smoother.absorb(Vector3(1.0, 0.0, 0.0))
	assert_eq(smoother.offset, Vector3(-1.0, 0.0, 0.0), "drawn where it was")
	smoother.advance(SECONDS * 0.5)
	assert_almost_eq(smoother.offset, Vector3(-0.5, 0.0, 0.0), Vector3.ONE * 1e-6, "halfway")
	smoother.advance(SECONDS * 0.5)
	assert_eq(smoother.offset, Vector3.ZERO, "on its prediction again")
	smoother.advance(SECONDS)
	assert_eq(smoother.offset, Vector3.ZERO, "and it stays there")


func test_a_second_correction_starts_from_where_the_body_is_drawn() -> void:
	var smoother := CorrectionSmoother.new(SECONDS)
	smoother.absorb(Vector3(1.0, 0.0, 0.0))
	smoother.advance(SECONDS * 0.5)
	smoother.absorb(Vector3(0.0, 0.0, 1.0))
	assert_almost_eq(smoother.offset, Vector3(-0.5, 0.0, -1.0), Vector3.ONE * 1e-6)
	smoother.advance(SECONDS)
	assert_eq(smoother.offset, Vector3.ZERO, "both gone within correction_time of the second")


func test_no_correction_time_draws_the_prediction() -> void:
	var smoother := CorrectionSmoother.new(0.0)
	smoother.absorb(Vector3(1.0, 0.0, 0.0))
	assert_eq(smoother.offset, Vector3.ZERO)
