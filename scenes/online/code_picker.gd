class_name CodePicker
extends HBoxContainer
## A room code's letters, a slot each, for every hand (SH12). Typed: a letter fills the
## slot with the focus and moves on — past the last slot, to what lead_to() names —
## Backspace clears back, and a paste fills them all. With a pad or the mouse alone: pressing a
## slot takes it up, and up and down (or the wheel) turn its letter until it is pressed
## again or left. Left and right move between slots, and up and down leave the row when
## no slot is taken up. Only RoomCodec's CODE_LETTERS go in, in upper case.

## What an empty slot shows: its box alone.
const EMPTY := ""
const SLOT_SIZE := Vector2(50.0, 54.0)

var _slots: Array[Button] = []
## Where the focus goes once the last slot is typed.
var _after: Control
var _taken_up := ButtonGroup.new()


func _ready() -> void:
	_taken_up.allow_unpress = true
	for index in RoomCodec.CODE_LENGTH:
		var slot := Button.new()
		slot.name = "Slot%d" % index
		slot.theme_type_variation = UiTheme.CODE_SLOT
		slot.custom_minimum_size = SLOT_SIZE
		slot.toggle_mode = true
		slot.button_group = _taken_up
		slot.text = EMPTY
		slot.gui_input.connect(_on_slot_input.bind(index))
		slot.focus_exited.connect(func() -> void: slot.set_pressed_no_signal(false))
		add_child(slot)
		_slots.append(slot)


## The letters filled in, in order: short of CODE_LENGTH while a slot is empty.
func code() -> String:
	var letters := ""
	for slot: Button in _slots:
		if slot.text != EMPTY:
			letters += slot.text
	return letters


## Fills the slots from [param typed]: its code letters, upper-cased, in order — the rest
## of it left out — and empties the slots past them.
func set_code(typed: String) -> void:
	var letters := _letters(typed)
	for index in _slots.size():
		_slots[index].text = letters[index] if index < letters.length() else EMPTY


func first_slot() -> Button:
	return _slots[0]


## Makes [param next] — the Join button — what follows the last slot, whether typed past
## or reached to the right, and what leads back to it.
func lead_to(next: Control) -> void:
	_after = next
	var last := _slots[-1]
	last.focus_neighbor_right = last.get_path_to(next)
	next.focus_neighbor_left = next.get_path_to(last)


func _on_slot_input(event: InputEvent, index: int) -> void:
	var slot := _slots[index]
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_turn(index, 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_turn(index, -1)
			_:
				return
	elif slot.button_pressed and event.is_action_pressed("ui_up", true):
		_turn(index, 1)
	elif slot.button_pressed and event.is_action_pressed("ui_down", true):
		_turn(index, -1)
	elif slot.button_pressed and event.is_action_pressed("ui_cancel"):
		slot.button_pressed = false
	elif slot.button_pressed and event.is_action_pressed("ui_left", true):
		_take_up(index - 1)
	elif slot.button_pressed and event.is_action_pressed("ui_right", true):
		_take_up(index + 1)
	elif event.is_action_pressed("ui_paste"):
		set_code(DisplayServer.clipboard_get())
		_focus(code().length())
	elif event is InputEventKey and event.is_pressed():
		var key := event as InputEventKey
		if key.keycode == KEY_BACKSPACE:
			_erase(index)
		elif not _type(index, String.chr(key.unicode)):
			return
	else:
		return
	slot.accept_event()


## Turns slot [param index]'s letter [param step] places on through CODE_LETTERS, round
## from the last to the first; an empty slot starts at either end.
func _turn(index: int, step: int) -> void:
	var letters := RoomCodec.CODE_LETTERS
	var at := -1 if _slots[index].text == EMPTY else letters.find(_slots[index].text)
	if at < 0:
		at = 0 if step > 0 else letters.length() - 1
	else:
		at = posmod(at + step, letters.length())
	_slots[index].text = letters[at]


## Puts [param typed] in slot [param index] when it is a code letter in either case, and
## moves on; whether it was a letter of the alphabet at all — one that is not a code
## letter, an I or an O, is taken and left out.
func _type(index: int, typed: String) -> bool:
	var upper := typed.to_upper()
	if upper.length() != 1 or upper < "A" or upper > "Z":
		return false
	if RoomCodec.CODE_LETTERS.contains(upper):
		_slots[index].text = upper
		_focus(index + 1)
	return true


## Empties slot [param index], or the one before it when it is empty already.
func _erase(index: int) -> void:
	var at := index if _slots[index].text != EMPTY or index == 0 else index - 1
	_slots[at].text = EMPTY
	_slots[at].grab_focus()


## Moves the focus, and the taking up, to slot [param index] when there is one.
func _take_up(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index].grab_focus()
	_slots[index].button_pressed = true


## The focus to slot [param index], or past the last to what lead_to() named.
func _focus(index: int) -> void:
	if index < _slots.size():
		_slots[index].grab_focus()
	elif _after != null:
		_after.grab_focus()


## [param typed]'s code letters, upper case, at most CODE_LENGTH of them.
static func _letters(typed: String) -> String:
	var letters := ""
	for letter: String in typed.to_upper():
		if RoomCodec.CODE_LETTERS.contains(letter) and letters.length() < RoomCodec.CODE_LENGTH:
			letters += letter
	return letters
