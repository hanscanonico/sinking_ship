class_name KeyBindings
extends RefCounted
## The keys of play the player chose over the project's: at most one key or mouse
## button for each of the move's four ways, jump, shove, brace and pause, and for
## the switch of view and the free camera once out — one set, so a key of play
## never also answers to watching (#257). An action left unchosen keeps the
## project's keys. A chosen one heads the action's keys in place of the project's
## first of its kind — a key for a key, a mouse button for a mouse button — so the
## arrows still move and a click still shoves; an alternate another action is given
## goes from this one. The pad's bindings are never touched. The switches of view
## also switch seats in replays, which hear their own keys and Esc first, so a bind
## that would leave either on one of those is refused (IN_REPLAYS).
## The settings screen saves them at PATH; Game applies them to the input map as it
## boots, and InputFrame reads actions, never keys, so the sim sees none of it (D3).
##
## The file is one players pass round, and so read as plain JSON — never as a
## resource, which can carry a script — of at most MAX_BYTES, each entry kept only
## when it is one the settings screen could have saved (OnlineSettings).

const PATH := "user://key_bindings.json"
const MAX_BYTES := 4096
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
	&"spectate_previous",
	&"spectate_next",
	&"spectate_free",
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
	&"spectate_previous": "Previous view",
	&"spectate_next": "Next view",
	&"spectate_free": "Free camera",
}

## The actions that also act in replays, where a replay's own keys and Esc are heard
## before them: none of them may hold one of those.
const IN_REPLAYS: Array[StringName] = [&"spectate_previous", &"spectate_next"]
## The project's actions whose keys a replay hears before the switches of view.
const REPLAY_PREFIX := "input/replay_"
const REPLAY_CLOSE: StringName = &"ui_cancel"
## The mouse buttons a replay's orbit drags and pans with (OrbitCamera.drag), whose
## presses a replay hears before the switches of view too.
const REPLAY_DRAGS: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]

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

## The keys a replay hears before the switches of view, read once.
static var _replay_keys: Array[InputEvent] = []

## The player's key or mouse button for each action they rebound.
var chosen: Dictionary[StringName, InputEvent] = {}


## The saved bindings, or none when none are saved.
static func local() -> KeyBindings:
	var shared: KeyBindings = _shared.get_ref() if _shared != null else null
	if shared == null:
		shared = read(PATH)
		_shared = weakref(shared)
	return shared


## The bindings saved at [param path] — anything in them that is not a key or mouse
## button for an action that may be rebound, or that puts a switch of view on a
## replay's key, left out — or none when there are none.
static func read(path: String) -> KeyBindings:
	var bindings := KeyBindings.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return bindings
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return bindings
	var saved: Dictionary = json.data
	for action: StringName in ACTIONS:
		var event := _from_json(saved.get(String(action)))
		if event != null and not (action in IN_REPLAYS and _holds(replay_keys(), event)):
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


## The keys and mouse buttons [param action] answers to: the player's one first, in
## place of the project's first of its kind (else its first), then the project's
## others that no other action was given.
func keys_of(action: StringName) -> Array[InputEvent]:
	var keys: Array[InputEvent] = []
	var others := defaults_of(action)
	if chosen.has(action):
		var mine: InputEvent = chosen[action]
		keys.append(mine)
		if not others.is_empty():
			others.remove_at(_first_of_kind(others, mine))
	for key: InputEvent in others:
		if not _given_elsewhere(action, key) and not _holds(keys, key):
			keys.append(key)
	return keys


## The key or mouse button shown for [param action] — the hints' — the first it
## answers to.
func shown(action: StringName) -> InputEvent:
	var keys := keys_of(action)
	return keys[0] if not keys.is_empty() else null


## Binds [param event] to [param action]. An action shown with it takes
## [param action]'s old key in exchange; one that only had it as an alternate lets
## it go. False when [param event] cannot be a binding, [param action] may not be
## rebound, or it would leave a switch of view on a replay's key (clashes_in_replays).
func bind(action: StringName, event: InputEvent) -> bool:
	var bound := as_binding(event)
	if bound == null or action not in ACTIONS or clashes_in_replays(action, bound):
		return false
	_put(action, bound)
	return true


## Whether binding [param event] to [param action] — the swap it makes included —
## would leave an action IN_REPLAYS on a key a replay hears first, a replay's own or
## Esc, where it could never switch the seat.
func clashes_in_replays(action: StringName, event: InputEvent) -> bool:
	var bound := as_binding(event)
	if bound == null or action not in ACTIONS:
		return false
	var trial := KeyBindings.new()
	trial.chosen.assign(chosen)
	trial._put(action, bound)
	for switch: StringName in IN_REPLAYS:
		for key: InputEvent in trial.keys_of(switch):
			if _holds(replay_keys(), key):
				return true
	return false


## The keys a replay hears before the switches of view: every replay action's, as
## project.godot binds them, Esc's and the buttons its orbit drags with.
static func replay_keys() -> Array[InputEvent]:
	if _replay_keys.is_empty():
		for property: Dictionary in ProjectSettings.get_property_list():
			var setting: String = property["name"]
			if setting.begins_with(REPLAY_PREFIX):
				_replay_keys.append_array(defaults_of(StringName(setting.trim_prefix("input/"))))
		_replay_keys.append_array(defaults_of(REPLAY_CLOSE))
		for button: MouseButton in REPLAY_DRAGS:
			var drag := InputEventMouseButton.new()
			drag.button_index = button
			_replay_keys.append(drag)
	return _replay_keys


## Back to the project's keys for every action.
func reset() -> void:
	chosen.clear()


func save(path: String = PATH) -> Error:
	var saved := {}
	for action: StringName in chosen:
		saved[String(action)] = _to_json(chosen[action])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(saved))
	return file.get_error()


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


## [param bound] on [param action], the action shown with it given
## [param action]'s old key.
func _put(action: StringName, bound: InputEvent) -> void:
	var old := shown(action)
	for other: StringName in ACTIONS:
		if other != action and same_input(shown(other), bound):
			if old != null:
				chosen[other] = as_binding(old)
			else:
				chosen.erase(other)
			break
	chosen[action] = bound


func _given_elsewhere(action: StringName, key: InputEvent) -> bool:
	for other: StringName in chosen:
		if other != action and same_input(chosen[other], key):
			return true
	return false


static func _first_of_kind(events: Array[InputEvent], event: InputEvent) -> int:
	for index in events.size():
		if (events[index] is InputEventKey) == (event is InputEventKey):
			return index
	return 0


static func _holds(keys: Array[InputEvent], key: InputEvent) -> bool:
	for held: InputEvent in keys:
		if same_input(held, key):
			return true
	return false


## A binding as the file holds it: the key by where it sits, by what it types when
## it has no place, or the mouse button.
static func _to_json(event: InputEvent) -> Dictionary:
	if event is InputEventMouseButton:
		return {"mouse": (event as InputEventMouseButton).button_index}
	var key := event as InputEventKey
	if key.physical_keycode != KEY_NONE:
		return {"key": key.physical_keycode}
	return {"keycode": key.keycode}


## The binding [param saved] holds, or null when it holds none.
static func _from_json(saved: Variant) -> InputEvent:
	if not saved is Dictionary or (saved as Dictionary).size() != 1:
		return null
	var entry: Dictionary = saved
	var kind: Variant = entry.keys()[0]
	var code: Variant = entry[kind]
	if not (code is float or code is int) or code != floorf(code):
		return null
	if code <= 0 or code > KEY_CODE_MASK:
		return null
	var event: InputEvent = null
	if kind == "mouse":
		var button := InputEventMouseButton.new()
		button.button_index = int(code) as MouseButton
		event = button
	elif kind == "key" or kind == "keycode":
		var key := InputEventKey.new()
		if kind == "key":
			key.physical_keycode = int(code) as Key
		else:
			key.keycode = int(code) as Key
		event = key
	return as_binding(event)


static func _is_key_or_mouse(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


static func _key_of(key: InputEventKey) -> Key:
	return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
