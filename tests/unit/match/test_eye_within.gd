extends GutTest
## A free eye inside or against a body does not see it drawn (MatchView.eye_within).


func test_an_eye_at_a_body_s_head_is_within_it() -> void:
	assert_true(MatchView.eye_within(Vector3(0, 1.6, 0), Vector3.ZERO, Vector3.UP, 1.7, 0.75))


func test_an_eye_against_its_side_is_within_it() -> void:
	assert_true(MatchView.eye_within(Vector3(0.6, 1.0, 0), Vector3.ZERO, Vector3.UP, 1.7, 0.75))


func test_an_eye_a_stride_off_is_not() -> void:
	assert_false(MatchView.eye_within(Vector3(1.0, 1.6, 0), Vector3.ZERO, Vector3.UP, 1.7, 0.75))


func test_an_eye_over_its_head_is_not() -> void:
	assert_false(MatchView.eye_within(Vector3(0, 2.6, 0), Vector3.ZERO, Vector3.UP, 1.7, 0.75))


func test_a_body_stands_up_its_own_deck() -> void:
	# On a listing piece the body's upright leans: the eye beside its tilted head is in it.
	var up := Vector3(0.5, 1.0, 0).normalized()
	var head := up * 1.6
	assert_true(MatchView.eye_within(head, Vector3.ZERO, up, 1.7, 0.75))
	assert_false(MatchView.eye_within(Vector3(-0.5, 1.6, 0), Vector3.ZERO, up, 1.7, 0.75))


func test_the_seat_watched_stays_hidden_from_an_eye_on_a_steep_deck() -> void:
	# The eyes stand along the world's up, the body along its deck's: trimmed 37°, the
	# ghost's first eye is a metre off the upright of the seat it starts in, past the
	# clearance, yet that seat stays hidden till the eye has walked clear of it.
	var up := Vector3(sin(deg_to_rad(37.0)), cos(deg_to_rad(37.0)), 0)
	var eye := Vector3(0, 1.6, 0)
	assert_false(MatchView.hides(eye, Vector3.ZERO, up, 1.7, 0.4, false), "anyone else shows")
	assert_true(MatchView.hides(eye, Vector3.ZERO, up, 1.7, 0.4, true), "the seat left hides")
	var clear := Vector3(-2.0, 1.6, 0)
	assert_false(MatchView.hides(clear, Vector3.ZERO, up, 1.7, 0.4, true), "walked clear")
