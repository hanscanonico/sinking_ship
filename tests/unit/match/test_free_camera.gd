extends GutTest
## The free camera — an out seat's, a watcher's and a replay's: level along its yaw, up and
## down, its pitch short of straight, inside its box and over the sea, the same whatever
## the frame rate; following the seat watched at its offset until flown or let go; framing
## the whole ship where a watcher's and a replay's opens; and only ever while spectating.

const DECK := Rect2(-30.0, -5.0, 60.0, 10.0)


func _camera() -> FreeCamera:
	var camera := FreeCamera.new()
	camera.set_bounds(DECK)
	camera.position = Vector3(0.0, 10.0, 0.0)
	return camera


func test_it_flies_level_along_where_it_looks() -> void:
	var camera := _camera()
	camera.fly(Vector2(0.0, -1.0), 0.0, 1.0)
	assert_almost_eq(camera.position, Vector3(0.0, 10.0, -FreeCamera.SPEED), Vector3.ONE * 1e-4)
	camera.position = Vector3(0.0, 10.0, 0.0)
	camera.yaw = PI / 2.0
	camera.pitch = deg_to_rad(-60.0)
	camera.fly(Vector2(0.0, -1.0), 0.0, 1.0)
	assert_almost_eq(
		camera.position,
		Vector3(-FreeCamera.SPEED, 10.0, 0.0),
		Vector3.ONE * 1e-4,
		"turned left, it flies left, and looking down never dives"
	)
	var ahead := -camera.transform().basis.z
	assert_lt(ahead.x, 0.0, "it looks the way it flies")
	camera.position = Vector3(0.0, 10.0, 0.0)
	camera.yaw = 0.0
	camera.fly(Vector2(1.0, 0.0), 0.0, 1.0)
	assert_almost_eq(camera.position.x, FreeCamera.SPEED, 1e-4, "right is right")


func test_a_diagonal_is_no_faster() -> void:
	var step := FreeCamera.step(0.0, Vector2(1.0, -1.0), 0.0, 1.0)
	assert_almost_eq(step.length(), FreeCamera.SPEED, 1e-4)


func test_the_jump_and_the_brace_fly_it_up_and_down() -> void:
	var camera := _camera()
	camera.fly(Vector2.ZERO, 1.0, 0.5)
	assert_almost_eq(camera.position.y, 10.0 + FreeCamera.CLIMB_SPEED * 0.5, 1e-4)
	camera.fly(Vector2.ZERO, -1.0, 1.0)
	assert_almost_eq(camera.position.y, 10.0 - FreeCamera.CLIMB_SPEED * 0.5, 1e-4)


func test_two_half_frames_fly_as_far_as_one_whole() -> void:
	var halves := _camera()
	var whole := _camera()
	halves.yaw = 0.7
	whole.yaw = 0.7
	halves.fly(Vector2(0.4, -0.8), 0.5, 0.25)
	halves.fly(Vector2(0.4, -0.8), 0.5, 0.25)
	whole.fly(Vector2(0.4, -0.8), 0.5, 0.5)
	assert_almost_eq(halves.position, whole.position, Vector3.ONE * 1e-4)


func test_its_pitch_stops_short_of_straight_up_and_down() -> void:
	var camera := _camera()
	var limit := deg_to_rad(FreeCamera.PITCH_LIMIT_DEG)
	camera.turn(Vector2(0.0, -10.0), false)
	assert_almost_eq(camera.pitch, limit, 1e-5, "the mouse up looks up, as far as the limit")
	camera.turn(Vector2(0.0, 10.0), false)
	assert_almost_eq(camera.pitch, -limit, 1e-5)
	camera.turn(Vector2(0.0, 0.2), true)
	assert_almost_eq(camera.pitch, -limit + 0.2, 1e-5, "inverted, down looks up")
	camera.turn(Vector2(0.3, 0.0), false)
	assert_almost_eq(camera.yaw, -0.3, 1e-5, "the mouse right turns it right")


func test_it_keeps_round_the_decks_and_over_the_sea() -> void:
	var camera := _camera()
	camera.fly(Vector2(-1.0, 0.0), 0.0, 100.0)
	assert_almost_eq(camera.position.x, DECK.position.x - FreeCamera.MARGIN, 1e-4)
	camera.fly(Vector2(0.0, 1.0), 0.0, 100.0)
	assert_almost_eq(camera.position.z, DECK.end.y + FreeCamera.MARGIN, 1e-4)
	camera.fly(Vector2.ZERO, -1.0, 100.0)
	assert_almost_eq(camera.position.y, FreeCamera.SEA_CLEARANCE, 1e-4, "over the sea")
	camera.fly(Vector2.ZERO, 1.0, 100.0)
	assert_almost_eq(camera.position.y, FreeCamera.CEILING, 1e-4)
	var unbounded := FreeCamera.new()
	unbounded.fly(Vector2.ZERO, -1.0, 100.0)
	assert_almost_eq(unbounded.position.y, FreeCamera.SEA_CLEARANCE, 1e-4, "always over it")


func test_it_starts_behind_and_over_the_seat_looking_at_it() -> void:
	var camera := _camera()
	var head := Vector3(2.0, 3.0, 1.0)
	camera.start(head, Vector3(1.0, -0.3, 0.0))
	assert_almost_eq(camera.position.x, head.x - FreeCamera.START_BACK, 1e-4, "behind")
	assert_almost_eq(camera.position.y, head.y + FreeCamera.START_RISE, 1e-4, "over")
	var ahead := -camera.transform().basis.z
	var to := (head - camera.position).normalized()
	assert_almost_eq(ahead, to, Vector3.ONE * 1e-4, "looking at it")


func test_only_a_spectating_seat_flies_it() -> void:
	var camera := FreeCamera.new()
	camera.toggle(false)
	assert_false(camera.active, "a living seat never enters it")
	camera.toggle(true)
	assert_true(camera.active)
	camera.toggle(true)
	assert_false(camera.active, "the key goes back to the eyes")
	camera.toggle(true)
	camera.keep(true)
	assert_true(camera.active)
	camera.keep(false)
	assert_false(camera.active, "the match over, back to the eyes")
	camera.toggle(true)
	camera.leave()
	assert_false(camera.active, "cycling to a seat leaves it")


func test_following_trails_the_seat_at_the_offset_it_locked_on_at() -> void:
	var camera := _camera()
	camera.toggle(true)
	var seat := Vector3(2.0, 3.0, 1.0)
	camera.toggle_follow(seat)
	assert_true(camera.following)
	var offset := camera.position - seat
	seat += Vector3(4.0, 0.0, -2.0)
	camera.trail(seat, 0.05)
	var closed := camera.position.distance_to(Vector3(0.0, 10.0, 0.0))
	assert_almost_eq(
		closed, Vector3(4.0, 0.0, -2.0).length() * FreeCamera.FOLLOW_RATE * 0.05, 1e-4, "smoothly"
	)
	camera.trail(seat, 1.0)
	assert_almost_eq(camera.position, seat + offset, Vector3.ONE * 1e-4, "and on, at its offset")
	camera.trail(seat + Vector3(1e4, 0.0, 0.0), 1.0)
	assert_almost_eq(camera.position.x, DECK.end.x + FreeCamera.MARGIN, 1e-4, "inside its box")


func test_the_key_again_or_flying_it_lets_go_but_turning_does_not() -> void:
	var camera := _camera()
	camera.toggle_follow(Vector3.ZERO)
	assert_false(camera.following, "only the free camera follows")
	camera.toggle(true)
	camera.toggle_follow(Vector3.ZERO)
	camera.toggle_follow(Vector3.ZERO)
	assert_false(camera.following, "the key again lets go")
	camera.toggle_follow(Vector3.ZERO)
	camera.turn(Vector2(0.3, 0.1), false)
	camera.fly(Vector2.ZERO, 0.0, 1.0)
	assert_true(camera.following, "turning it, or holding nothing, keeps on")
	camera.fly(Vector2(0.0, -1.0), 0.0, 0.1)
	assert_false(camera.following, "flown by hand, it lets go")
	camera.toggle_follow(Vector3.ZERO)
	camera.fly(Vector2.ZERO, 1.0, 0.1)
	assert_false(camera.following, "climbing too")
	var before := camera.position
	camera.trail(Vector3(5.0, 0.0, 0.0), 1.0)
	assert_eq(camera.position, before, "let go, it stays where it is")


func test_following_it_stays_on_through_a_switch_of_seat() -> void:
	var camera := _camera()
	camera.toggle(true)
	camera.toggle_follow(Vector3.ZERO)
	camera.leave()
	assert_true(camera.active, "it goes on to trail the next seat")
	camera.toggle(true)
	assert_false(camera.active, "back to the eyes")
	assert_false(camera.following, "and the follow let go with it")
	camera.toggle(true)
	camera.toggle_follow(Vector3.ZERO)
	camera.keep(false)
	assert_false(camera.following, "the match over, nothing to follow")


func test_it_frames_the_whole_ship_from_her_starboard_side() -> void:
	for deck: Rect2 in [DECK, Rect2(-150.0, -15.0, 300.0, 30.0)]:
		var camera := FreeCamera.new()
		camera.set_bounds(deck)
		camera.frame_ship(deck)
		var middle := Vector3(deck.get_center().x, 0.0, deck.get_center().y)
		var ahead := -camera.transform().basis.z
		var to := (middle - camera.position).normalized()
		assert_almost_eq(ahead, to, Vector3.ONE * 1e-4, "looking at the middle of her decks")
		assert_gt(camera.position.z, deck.end.y, "from her starboard side")
		var long_hull := deck.size.x > FreeCamera.FRAME_DISTANCE * ObserverCamera.LONG_HULL
		var off := deck.size.x * ObserverCamera.LONG_HULL_DISTANCE
		assert_almost_eq(
			camera.position.distance_to(middle),
			off if long_hull else FreeCamera.FRAME_DISTANCE,
			1e-3,
			"far enough off to frame her whole"
		)
		var at := camera.position
		camera.fly(Vector2.ZERO, 0.0, 1.0)
		assert_almost_eq(camera.position, at, Vector3.ONE * 1e-4, "its box holds it there")
