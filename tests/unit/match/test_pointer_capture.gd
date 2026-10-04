extends GutTest
## The local player's hold on the mouse: a browser grants it only in answer to a click,
## so there it is asked for at a click alone — never frame after frame, each refused with
## an error — and "Click to play" shows until it is held. Natively it is taken and let go
## as the look needs it, as ever.


## Input's mouse mode, as a stand-in: what was asked for, and how often.
class FakeMouse:
	extends RefCounted
	var asked := 0
	var mouse_mode := Input.MOUSE_MODE_VISIBLE:
		set(value):
			asked += 1
			mouse_mode = value


func _capture(click_to_capture: bool) -> Array:
	var mouse := FakeMouse.new()
	var capture := PointerCapture.new()
	capture.click_to_capture = click_to_capture
	capture.device = mouse
	add_child_autofree(capture)
	return [capture, mouse]


func _click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _hint(capture: PointerCapture) -> Label:
	return capture.get_child(0) as Label


func test_a_browser_asks_for_the_mouse_at_a_click_alone() -> void:
	var made := _capture(true)
	var capture: PointerCapture = made[0]
	var mouse: FakeMouse = made[1]
	for _frame in 30:
		capture.want(true)
	assert_eq(mouse.asked, 0, "never asked frame after frame")
	assert_true(_hint(capture).visible, "Click to play")
	assert_eq(_hint(capture).text, "Click to play")
	capture._unhandled_input(_click())
	assert_eq(mouse.asked, 1, "asked at the click")
	assert_eq(mouse.mouse_mode, Input.MOUSE_MODE_CAPTURED)
	capture.want(true)
	assert_false(_hint(capture).visible, "held")
	capture._unhandled_input(_click())
	assert_eq(mouse.asked, 1, "not asked again while held")
	capture.want(false)
	assert_eq(mouse.mouse_mode, Input.MOUSE_MODE_VISIBLE, "let go as the look stops")
	capture._unhandled_input(_click())
	assert_eq(mouse.mouse_mode, Input.MOUSE_MODE_VISIBLE, "a click then takes nothing")


func test_natively_the_mouse_is_taken_as_the_look_needs_it() -> void:
	var made := _capture(false)
	var capture: PointerCapture = made[0]
	var mouse: FakeMouse = made[1]
	capture.want(true)
	assert_eq(mouse.mouse_mode, Input.MOUSE_MODE_CAPTURED)
	assert_false(_hint(capture).visible, "no hint natively")
	capture.want(true)
	assert_eq(mouse.asked, 1, "asked once, as it changes")
	capture.want(false)
	assert_eq(mouse.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	assert_eq(mouse.asked, 2)


## Until a browser's click takes the mouse, the keys, the pad and the mouse are not the
## match's; natively there is no such wait.
func test_a_browser_waits_for_its_click() -> void:
	var made := _capture(true)
	var capture: PointerCapture = made[0]
	capture.want(true)
	assert_true(capture.waiting(), "Click to play")
	capture._unhandled_input(_click())
	capture.want(true)
	assert_false(capture.waiting(), "taken")
	capture.want(false)
	assert_false(capture.waiting(), "not wanted")
	var native: PointerCapture = _capture(false)[0]
	native.want(true)
	assert_false(native.waiting())


## A browser's first Esc lets the mouse go without a key reaching the game: told once,
## so the online pause opens at that one Esc. The game's own letting go is not told.
func test_a_browser_letting_go_of_the_mouse_is_told() -> void:
	var made := _capture(true)
	var capture: PointerCapture = made[0]
	var mouse: FakeMouse = made[1]
	watch_signals(capture)
	capture.want(true)
	capture._unhandled_input(_click())
	capture.want(true)
	mouse.mouse_mode = Input.MOUSE_MODE_VISIBLE
	capture.want(true)
	capture.want(true)
	assert_signal_emit_count(capture, "lost", 1, "once, as the browser lets go")
	capture._unhandled_input(_click())
	capture.want(true)
	capture.want(false)
	capture.want(true)
	assert_signal_emit_count(capture, "lost", 1, "not as the game lets go")
	var native_made := _capture(false)
	var native: PointerCapture = native_made[0]
	watch_signals(native)
	native.want(true)
	(native_made[1] as FakeMouse).mouse_mode = Input.MOUSE_MODE_VISIBLE
	native.want(true)
	assert_signal_emit_count(native, "lost", 0, "natively the mouse is taken back")
