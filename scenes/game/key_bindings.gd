class_name KeyBindings
extends Resource
## The keys of play the player chose over the project's: at most one key or mouse
## button for each of the move's four ways, jump, shove, brace and pause. An action
## left unchosen keeps the project's keys; a chosen one has that one in their place.
## The pad's bindings are never touched. The settings screen saves them at PATH; Game
## applies them to the input map as it boots, and InputFrame reads actions, never
## keys, so the sim sees none of it (D3).

const PATH := "user://key_bindings.tres"
## What may be rebound, in the settings screen's order.
const ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"jump",
	&"shove",
	&"brace",
	&"pause",
]
## Each action's name on the settings screen.
const TITLES := {
	&"move_up": "Forward",
	&"move_down": "Back",
	&"move_left": "Left",
	&"move_right": "Right",
	&"jump": "Jump",
	&"shove": "Shove",
	&"brace": "Brace",
	&"pause": "Pause",
}

## A wheel's turns are not buttons a player holds.
const WHEEL: Array[MouseButton] = [
	MOUSE_BUTTON_WHEEL_UP,
	MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT,
	MOUSE_BUTTON_WHEEL_RIGHT,
]

## The one instance the game applies and the settings screen edits while either
## holds it. Weak, as AudioSettings' is.
static var _shared: WeakRef

## The player's key or mouse button for each action they rebound.
@export var chosen: Dictionary[StringName, InputEvent] = {}


## The saved bindings, or none when none are saved.
static func local() -> KeyBindings:
	var shared: KeyBindings = _shared.get_ref() if _shared != null else null
	if shared == null:
		shared = read(PATH)
		_shared = weakref(shared)
	return shared


## The bindings saved at [param path] — anything in them that is not a key or mouse
## button for an action that may be rebound left out — or none when there are none.
static func read(path: String) -> KeyBindings:
	var bindings := KeyBindings.new()
	if not ResourceLoader.exists(path):
		return bindings
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as KeyBindings
	if saved == null:
		return bindings
	for action: StringName in saved.chosen:
		var event := as_binding(saved.chosen[action])
		if action in ACTIONS and event != null:
			bindings.chosen[action] = event
	return bindings


## The project's keys and mouse buttons for [param action], as project.godot binds
## them, whatever the input map holds now.
static func defaults_of(action: StringName) -> Array[InputEvent]:
	var keys: Array[InputEvent] = []
	var setting: Variant = ProjectSettings.get_setting("input/%s" % action)
	if setting is Dictionary:
		for event: Variant in (setting as Dictionary).get("events", []):
			if event is InputEvent and _is_key_or_mouse(event):
				keys.append(event)
	return keys


## [param event] as a binding — the key by where it sits on the keyboard, or the
## mouse button — or null when it is neither, or a wheel's turn.
static func as_binding(event: Variant) -> InputEvent:
	if event is InputEventKey:
		var key := event as InputEventKey
		var bound := InputEventKey.new()
		if key.physical_keycode != KEY_NONE:
			bound.physical_keycode = key.physical_keycode
		elif key.keycode != KEY_NONE:
			bound.keycode = key.keycode
		else:
			return null
		return bound
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_NONE or button in WHEEL:
			return null
		var bound := InputEventMouseButton.new()
		bound.button_index = button
		return bound
	return null


## Whether [param a] and [param b] are the same key or the same mouse button.
static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _key_of(a as InputEventKey) == _key_of(b as InputEventKey)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (
			(a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
		)
	return false


## The keys and mouse buttons [param action] answers to: the player's one, else
## the project's.
func keys_of(action: StringName) -> Array[InputEvent]:
	if chosen.has(action):
		return [chosen[action]]
	return defaults_of(action)


## The key or mouse button shown for [param action]: the player's, else the
## project's first.
func shown(action: StringName) -> InputEvent:
	var keys := keys_of(action)
	return keys[0] if not keys.is_empty() else null


## Binds [param event] to [param action]; an action that may be rebound and
## answered to it takes [param action]'s old key in exchange. False when
## [param event] cannot be a binding or [param action] may not be rebound.
func bind(action: StringName, event: InputEvent) -> bool:
	var bound := as_binding(event)
	if bound == null or action not in ACTIONS:
		return false
	var old := shown(action)
	for other: StringName in ACTIONS:
		if other == action:
			continue
		for key: InputEvent in keys_of(other):
			if same_input(key, bound):
				if old != null:
					chosen[other] = as_binding(old)
				else:
					chosen.erase(other)
				break
	chosen[action] = bound
	return true


## Back to the project's keys for every action.
func reset() -> void:
	chosen.clear()


func save(path: String = PATH) -> Error:
	return ResourceSaver.save(self, path)


## Puts each action's keys and mouse buttons into the input map in place of what
## it held, its pad bindings kept.
func apply() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if _is_key_or_mouse(event):
				InputMap.action_erase_event(action, event)
		for event: InputEvent in keys_of(action):
			InputMap.action_add_event(action, event)


static func _is_key_or_mouse(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


static func _key_of(key: InputEventKey) -> Key:
	return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
