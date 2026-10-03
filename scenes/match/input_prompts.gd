class_name InputPrompts
extends Node
## Names the button behind an input-map action on the device last used — the
## keyboard and mouse, or a pad — so a hint says what to press on the one in hand.
## It reads the input map, so a rebinding renames its prompt with it.

const PAD_BUTTONS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "d-pad up",
	JOY_BUTTON_DPAD_DOWN: "d-pad down",
	JOY_BUTTON_DPAD_LEFT: "d-pad left",
	JOY_BUTTON_DPAD_RIGHT: "d-pad right",
}
const PAD_AXES := {
	JOY_AXIS_LEFT_X: "Left stick",
	JOY_AXIS_LEFT_Y: "Left stick",
	JOY_AXIS_RIGHT_X: "Right stick",
	JOY_AXIS_RIGHT_Y: "Right stick",
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}
const MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "Left click",
	MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle click",
}
## A stick pushed less than this is drift, not a player picking the pad up.
const STICK_DRIFT := 0.5

## Whether the pad was the last device used.
var pad := false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		pad = pad or absf((event as InputEventJoypadMotion).axis_value) >= STICK_DRIFT
	elif event is InputEventKey or event is InputEventMouse:
		pad = false


## What to press for [param action] on the device last used.
func word(action: StringName) -> String:
	return word_for(InputMap.action_get_events(action), pad)


## The hint line for play on the device last used.
func controls() -> String:
	return controls_for(pad)


## Move, jump, shove and brace as the input map binds them, on the pad when
## [param on_pad], else on the keyboard and mouse — the four keys of the move by
## the layout's labels, so Z Q S D on AZERTY where QWERTY reads W A S D.
static func controls_for(on_pad: bool) -> String:
	var move := _word_of(&"move_up", on_pad)
	if not on_pad:
		var keys := PackedStringArray()
		for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
			keys.append(_word_of(action, on_pad))
		move = " ".join(keys)
	var hints := PackedStringArray()
	for line: Array in [
		[move, "move"],
		[_word_of(&"jump", on_pad), "jump"],
		[_word_of(&"shove", on_pad), "shove"],
		[_word_of(&"brace", on_pad), "brace"],
	]:
		hints.append("%s — %s" % line)
	return "   ·   ".join(hints)


static func _word_of(action: StringName, on_pad: bool) -> String:
	return word_for(InputMap.action_get_events(action), on_pad)


## The first of [param events] on the pad when [param on_pad], else on the
## keyboard or mouse, as a word; empty when that device has none.
static func word_for(events: Array[InputEvent], on_pad: bool) -> String:
	for event: InputEvent in events:
		if on_pad and event is InputEventJoypadButton:
			var button := (event as InputEventJoypadButton).button_index
			return PAD_BUTTONS.get(button, "Button %d" % button)
		if on_pad and event is InputEventJoypadMotion:
			var axis := (event as InputEventJoypadMotion).axis
			return PAD_AXES.get(axis, "Axis %d" % axis)
		if not on_pad and event is InputEventKey:
			var key := event as InputEventKey
			var keycode := key.keycode
			if key.physical_keycode != KEY_NONE:
				keycode = _on_this_layout(key.physical_keycode)
			return OS.get_keycode_string(keycode).replace("Escape", "Esc")
		if not on_pad and event is InputEventMouseButton:
			var button := (event as InputEventMouseButton).button_index
			return MOUSE_BUTTONS.get(button, "Mouse %d" % button)
	return ""


## The key [param physical] types on the keyboard's layout — Q on QWERTY, A on
## AZERTY — or itself where there is no layout to ask, as when headless.
static func _on_this_layout(physical: Key) -> Key:
	if DisplayServer.get_name() == "headless":
		return physical
	return DisplayServer.keyboard_get_keycode_from_physical(physical)
