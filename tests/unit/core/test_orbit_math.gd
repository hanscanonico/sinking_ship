extends GutTest
## The orbit camera's eye stands where its yaw, pitch and distance put it round the
## pivot, never under the sea nor inside her hull's box; a pan moves the pivot in the
## eye's frame within the decks' bounds, the lock follows, and the whole ship is framed
## as the observer camera frames her (R5, #213).

const BOX := AABB(Vector3(-5.0, -2.0, -10.0), Vector3(10.0, 6.0, 20.0))
const DECK := Rect2(-5.0, -10.0, 10.0, 20.0)


func test_the_eye_orbits_the_pivot() -> void:
	assert_eq(OrbitMath.eye_of(Vector3.ZERO, 0.0, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), "ahead")
	assert_almost_eq(
		OrbitMath.eye_of(Vector3.ZERO, PI / 2.0, 0.0, 10.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3.ONE * 0.001
	)
	assert_almost_eq(
		OrbitMath.eye_of(Vector3(1.0, 2.0, 3.0), 0.0, PI / 2.0, 10.0),
		Vector3(1.0, 12.0, 3.0),
		Vector3.ONE * 0.001,
		"straight over"
	)


func test_a_pan_moves_the_pivot_in_the_eye_s_frame_within_the_deck() -> void:
	assert_eq(OrbitMath.pan(Vector3.ZERO, 0.0, Vector2(1.0, 2.0), DECK), Vector3(1.0, 0.0, 2.0))
	assert_almost_eq(
		OrbitMath.pan(Vector3.ZERO, PI / 2.0, Vector2(1.0, 0.0), DECK),
		Vector3(0.0, 0.0, -1.0),
		Vector3.ONE * 0.001,
		"right, seen from the +x side, is -z"
	)
	assert_eq(
		OrbitMath.pan(Vector3(4.0, 1.5, 0.0), 0.0, Vector2(30.0, -40.0), DECK),
		Vector3(5.0, 1.5, -10.0),
		"held at the deck's edge, on its own level"
	)


func test_the_eye_stays_over_the_sea_and_out_of_the_hull() -> void:
	assert_eq(OrbitMath.over_sea(Vector3(1.0, -3.0, 2.0), 1.0), Vector3(1.0, 1.0, 2.0))
	assert_eq(OrbitMath.over_sea(Vector3(1.0, 5.0, 2.0), 1.0), Vector3(1.0, 5.0, 2.0))
	var outside := Vector3(0.0, 20.0, 0.0)
	assert_eq(OrbitMath.out_of(outside, Vector3.ZERO, BOX), outside, "outside stays")
	assert_almost_eq(
		OrbitMath.out_of(Vector3(0.0, 2.0, 3.0), Vector3(0.0, 1.0, 0.0), BOX),
		Vector3(0.0, 4.0, 9.0),
		Vector3.ONE * 0.001,
		"from a pivot inside, out through the top"
	)
	assert_almost_eq(
		OrbitMath.out_of(Vector3(0.0, 1.0, 5.0), Vector3(0.0, 1.0, 30.0), BOX),
		Vector3(0.0, 1.0, 10.0),
		Vector3.ONE * 0.001,
		"from a pivot outside, back to the near face"
	)


func test_the_lock_follows_and_the_whole_ship_is_framed() -> void:
	assert_eq(
		OrbitMath.follow(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 2.0, 0.25), Vector3(5.0, 0.0, 0.0)
	)
	assert_eq(
		OrbitMath.follow(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 2.0, 5.0), Vector3(10.0, 0.0, 0.0)
	)
	assert_eq(
		OrbitMath.whole_ship_distance(Rect2(0.0, 0.0, 40.0, 10.0), 24.0), 24.0, "a short hull"
	)
	assert_eq(OrbitMath.whole_ship_distance(Rect2(0.0, 0.0, 100.0, 10.0), 24.0), 80.0, "a long one")
