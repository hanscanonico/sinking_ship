extends GutTest
## The observer camera's wheel: a notch brings it in by the orbit's step, as near as the
## orbit comes and back out no farther than it opened; and a rig framing the whole ship
## closes on its target as it comes in, so the seat it follows stays in view.

## A hull long enough (over LONG_HULL times the rig's 24 m) to be framed whole.
const LONG_DECK := Rect2(-60.0, -5.0, 120.0, 10.0)
const SHORT_DECK := Rect2(-20.0, -5.0, 40.0, 10.0)
const TARGET := Vector3(40.0, 2.0, 3.0)


func _rig(deck: Rect2) -> ObserverCamera:
	var rig := ObserverCamera.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	rig.add_child(camera)
	add_child_autofree(rig)
	rig.reset(TARGET, deck)
	return rig


func _distance(rig: ObserverCamera) -> float:
	return (rig.get_node("Camera3D") as Camera3D).position.z


func test_a_notch_brings_it_in_by_the_orbit_s_step() -> void:
	var rig := _rig(SHORT_DECK)
	var opened := _distance(rig)
	rig.zoom(1.0)
	assert_almost_eq(_distance(rig), opened * OrbitCamera.ZOOM_STEP, 1e-4, "in")
	rig.zoom(-1.0)
	assert_almost_eq(_distance(rig), opened, 1e-4, "and back out")


func test_it_comes_no_nearer_than_the_orbit_and_goes_no_farther_than_it_opened() -> void:
	var rig := _rig(SHORT_DECK)
	var opened := _distance(rig)
	rig.zoom(-3.0)
	assert_eq(_distance(rig), opened, "no farther than it opened")
	rig.zoom(100.0)
	assert_eq(_distance(rig), OrbitCamera.DISTANCE_LIMITS.x, "no nearer than the orbit")


func test_framing_the_whole_ship_it_closes_on_its_target_as_it_comes_in() -> void:
	var rig := _rig(LONG_DECK)
	var middle := Vector3(0.0, 0.0, 0.0)
	assert_eq(rig.position, middle, "opened on her middle")
	rig.zoom(5.0)
	rig.follow(TARGET, 1.0)
	var opened := LONG_DECK.size.x * ObserverCamera.LONG_HULL_DISTANCE
	var share := inverse_lerp(OrbitCamera.DISTANCE_LIMITS.x, opened, _distance(rig))
	assert_almost_eq(rig.position, TARGET.lerp(middle, share), Vector3.ONE * 1e-4, "between")
	rig.zoom(100.0)
	rig.follow(TARGET, 1.0)
	assert_almost_eq(rig.position, TARGET, Vector3.ONE * 1e-4, "all the way in, on the target")
	rig.zoom(-100.0)
	rig.follow(TARGET, 1.0)
	assert_almost_eq(rig.position, middle, Vector3.ONE * 1e-4, "back out, on her middle again")


func test_a_rig_following_its_target_still_follows_it_zoomed_in() -> void:
	var rig := _rig(SHORT_DECK)
	rig.zoom(5.0)
	rig.follow(TARGET, 1.0)
	var held := Vector3(SHORT_DECK.end.x, TARGET.y, TARGET.z)
	assert_almost_eq(rig.position, held, Vector3.ONE * 1e-4, "held inside")


func test_only_a_wheel_notch_turned_counts() -> void:
	assert_eq(OrbitCamera.wheel_notches(_button(MOUSE_BUTTON_WHEEL_UP, true)), 1.0, "up: in")
	assert_eq(OrbitCamera.wheel_notches(_button(MOUSE_BUTTON_WHEEL_DOWN, true)), -1.0, "down: out")
	assert_eq(OrbitCamera.wheel_notches(_button(MOUSE_BUTTON_WHEEL_UP, false)), 0.0, "a release")
	assert_eq(OrbitCamera.wheel_notches(_button(MOUSE_BUTTON_LEFT, true)), 0.0, "a click")
	assert_eq(OrbitCamera.wheel_notches(InputEventKey.new()), 0.0, "a key")


func _button(index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	return event
