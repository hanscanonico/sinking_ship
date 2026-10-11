extends GutTest
## The pause menu, and the settings opened from it, hold the local seat of a match off
## any server as an online menu does: a button still down as the pause goes — or one
## the engine never heard let go, as Shift is once macOS's Cmd-Shift-4 takes the keys
## and Esc both ends the screenshot and opens the pause — neither braces, burning
## stamina, nor shoves until it is let go.

const MATCH := preload("res://scenes/match/match.tscn")


func after_each() -> void:
	Input.action_release(&"brace")


func test_the_pause_holds_the_seat_until_the_button_is_let_go() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var source := LocalInputSource.new(0, 0.0, ViewSettings.new())
	scene._local = source
	scene.set_paused(true)
	assert_true(source.held, "paused")
	Input.action_press(&"brace")
	scene.set_paused(false)
	assert_false(source.held, "resumed")
	assert_eq(source.next_frame(1).buttons, 0, "Shift down through the pause holds back")
	Input.action_release(&"brace")
	assert_eq(source.next_frame(2).buttons, 0, "let go")
	Input.action_press(&"brace")
	assert_eq(source.next_frame(3).buttons, InputFrame.BRACE, "Shift pressed anew braces")
