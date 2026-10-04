extends GutTest
## The local seat while a menu over an online match has the keys, the pad and the mouse:
## the arrows, the D-pad and the stick move a menu and the seat alike, Space and pad A
## press a button and jump, a click presses one and shoves — so while held the seat
## stands still, its look kept, and once let go no button still down from the menu acts
## until it has been let go.

const ACTIONS: Array[StringName] = [&"move_down", &"jump", &"shove", &"brace"]


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _source() -> LocalInputSource:
	return LocalInputSource.new(2, 1.0, ViewSettings.new())


func test_a_held_seat_stands_still_and_keeps_its_look() -> void:
	var source := _source()
	Input.action_press(&"move_down")
	Input.action_press(&"jump")
	var free := source.next_frame(10)
	assert_ne(free.move, Vector2i.ZERO, "down walks, unheld")
	assert_eq(free.buttons, InputFrame.JUMP, "and A jumps")
	source.held = true
	for tick in range(11, 14):
		var held := source.next_frame(tick)
		assert_eq(held.move, Vector2i.ZERO, "down moves the menu alone")
		assert_eq(held.buttons, 0, "A presses the menu's button alone")
		assert_eq(held.look_yaw, InputFrame.quantize_yaw(1.0), "the look kept")
		assert_eq(held.seat, 2)
		assert_eq(held.tick, tick)


## The A that pressed Resume does not jump as the pause goes, nor the click that took
## the mouse in a browser shove; each acts again once let go and pressed anew. The stick
## is not a button: it walks at once.
func test_the_press_that_ends_the_hold_does_not_act() -> void:
	var source := _source()
	source.held = true
	Input.action_press(&"jump")
	Input.action_press(&"shove")
	assert_eq(source.next_frame(1).buttons, 0)
	source.held = false
	Input.action_press(&"move_down")
	var first := source.next_frame(2)
	assert_eq(first.buttons, 0, "neither the press that resumed nor the click acts")
	assert_ne(first.move, Vector2i.ZERO, "the stick walks")
	assert_eq(source.next_frame(3).buttons, 0, "nor while still held down")
	Input.action_release(&"jump")
	assert_eq(source.next_frame(4).buttons, 0, "the click still held")
	Input.action_press(&"jump")
	Input.action_press(&"brace")
	assert_eq(source.next_frame(5).buttons, InputFrame.JUMP | InputFrame.BRACE, "pressed anew")
	Input.action_release(&"shove")
	assert_eq(source.next_frame(6).buttons, InputFrame.JUMP | InputFrame.BRACE)
	Input.action_press(&"shove")
	var every := InputFrame.SHOVE | InputFrame.BRACE | InputFrame.JUMP
	assert_eq(source.next_frame(7).buttons, every, "the click pressed anew")


## A button pressed and let go under the menu is owed no release once it goes.
func test_a_button_let_go_under_the_menu_is_not_held_back() -> void:
	var source := _source()
	source.held = true
	Input.action_press(&"jump")
	source.next_frame(1)
	Input.action_release(&"jump")
	source.held = false
	Input.action_press(&"jump")
	assert_eq(source.next_frame(2).buttons, InputFrame.JUMP)
