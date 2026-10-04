extends SceneTree
## One player of `make online-e2e` (SH12): the game as `make run` boots it, headless,
## driven through its own screens as a person would — the main menu's Play online, the
## Online screen's name, server and Create, or a room code typed letter by letter and
## Join; the room's Start for its host once enough players are aboard; the match played
## with keys pressed and let go at random (seeded) where hands would; Back to the room at
## the results, then Leave room. Each step it reaches is printed as `e2e: NAME …`; it
## quits 0 back on the Online screen, 1 on any step not reached in time.
##
## Told by the environment, since the game reads every user argument as its own:
##   ONLINE_E2E_NAME      the display name, typed on the Online screen
##   ONLINE_E2E_SERVER    the server, ws://127.0.0.1:PORT
##   ONLINE_E2E_JOIN      the code to join, as typed; empty to create the room
##   ONLINE_E2E_PLAYERS   how many players the host waits for before Start
##   ONLINE_E2E_SEED      the seed of the hands' presses
## The Online screen remembers into a file of this player's own under user://, removed
## as it quits, so a person's saved name is never touched.

const GAME := "res://scenes/game/game.tscn"
## How long any one step may take, in seconds; a match is about two and a half minutes.
const STEP_SECONDS := 60.0
const MATCH_SECONDS := 300.0
## What the hands may hold, and how often they change their minds, in seconds.
const HANDS: Array[StringName] = [
	&"move_up", &"move_left", &"move_right", &"look_left", &"look_right", &"shove", &"jump"
]
const HANDS_SECONDS := 0.4

var _name := OS.get_environment("ONLINE_E2E_NAME")
var _server := OS.get_environment("ONLINE_E2E_SERVER")
var _join := OS.get_environment("ONLINE_E2E_JOIN")
var _players := maxi(OS.get_environment("ONLINE_E2E_PLAYERS").to_int(), 1)
var _settings := "user://online_e2e_%s.json" % _name.to_lower()
var _hands := RandomNumberGenerator.new()
var _game: Game


func _initialize() -> void:
	_hands.seed = OS.get_environment("ONLINE_E2E_SEED").to_int()
	_game = load(GAME).instantiate()
	(_game.get_node("OnlineMenu") as OnlineMenu).settings_path = _settings
	root.add_child(_game)
	_drive.call_deferred()


func _drive() -> void:
	var room := await _enter_room()
	if room == null or not await _play_match(room):
		return
	(room.get_node("%Leave") as Button).pressed.emit()
	var online: OnlineMenu = _game.get_node("OnlineMenu")
	if await _until(func() -> bool: return online.visible, "the Online screen again"):
		_say("left the room")
		_finish(0)


## Play online, a name, the server, then Create — or the code typed and Join: the room
## once it shows, null when it never does.
func _enter_room() -> RoomScreen:
	var menu: MainMenu = _game.get_node("MainMenu")
	var online: OnlineMenu = _game.get_node("OnlineMenu")
	if not await _until(func() -> bool: return menu.visible, "the main menu"):
		return null
	(menu.get_node("%Online") as Button).pressed.emit()
	if not await _until(func() -> bool: return online.visible, "the Online screen"):
		return null
	(online.get_node("%Name") as LineEdit).text = _name
	(online.get_node("%Server") as LineEdit).text = _server
	if _join.is_empty():
		(online.get_node("%Create") as Button).pressed.emit()
	else:
		(online.get_node("%Code") as CodePicker).first_slot().grab_focus()
		_type(_join)
		(online.get_node("%Join") as Button).pressed.emit()
	var room := await _room()
	if room != null:
		_say("in room %s" % (room.get_node("%Code") as Label).text)
	return room


## The host's Start once enough are aboard, the match played to its results, and Back to
## the room until it waits again: whether all of it was reached.
func _play_match(room: RoomScreen) -> bool:
	if _join.is_empty():
		var aboard := "Aboard · %d of" % _players
		var label: Label = room.get_node("%Aboard")
		if not await _until(func() -> bool: return label.text.begins_with(aboard), aboard):
			return false
		(room.get_node("%Start") as Button).pressed.emit()
	var scene := await _match()
	if scene == null:
		return false
	_say("playing")
	var results: EndOverlay = scene.get_node("EndOverlay")
	var from := Time.get_ticks_msec()
	while not results.visible:
		if Time.get_ticks_msec() - from > MATCH_SECONDS * 1000.0:
			_fail("the results")
			return false
		_move_hands()
		await create_timer(HANDS_SECONDS).timeout
	for action: StringName in HANDS:
		Input.action_release(action)
	var back: Button = results.get_node("%Rematch")
	if not await _until(func() -> bool: return not back.disabled, "the results' buttons"):
		return false
	_say("at the results: %s · %s" % [(results.get_node("%Title") as Label).text, back.text])
	back.pressed.emit()
	var status: Label = room.get_node("%Status")
	var waiting := func() -> bool:
		return room.visible and not status.text.begins_with("A match is on")
	if not await _until(waiting, "the room waiting again"):
		return false
	_say("back in room %s" % (room.get_node("%Code") as Label).text)
	return true


## The room screen, once the room shows.
func _room() -> RoomScreen:
	var found: Array[RoomScreen] = []
	var shown := func() -> bool:
		for node: Node in _game.find_children("*", "CanvasLayer", true, false):
			if node is RoomScreen and (node as CanvasLayer).visible:
				found.append(node)
				return true
		return false
	if not await _until(shown, "the room"):
		return null
	return found[0]


## The match scene, once one is up.
func _match() -> MatchScene:
	var found: Array[MatchScene] = []
	var up := func() -> bool:
		for node: Node in _game.find_children("*", "Node3D", true, false):
			if node is MatchScene and not node.is_queued_for_deletion():
				found.append(node)
				return true
		return false
	if not await _until(up, "the match"):
		return null
	return found[0]


## Types [param text] at the focus, key by key.
func _type(text: String) -> void:
	for letter: String in text:
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = OS.find_keycode_from_string(letter.to_upper())
		key.unicode = letter.unicode_at(0)
		root.push_input(key)


func _move_hands() -> void:
	for action: StringName in HANDS:
		if _hands.randf() < 0.5:
			Input.action_press(action)
		else:
			Input.action_release(action)


## Waits until [param reached] holds, frame by frame; fails the run when it has not
## within STEP_SECONDS — MATCH_SECONDS for the match — naming [param what].
func _until(reached: Callable, what: String) -> bool:
	var limit := MATCH_SECONDS if what == "the match" else STEP_SECONDS
	var from := Time.get_ticks_msec()
	while not reached.call():
		if Time.get_ticks_msec() - from > limit * 1000.0:
			_fail(what)
			return false
		await process_frame
	return true


func _fail(what: String) -> void:
	printerr("e2e: %s never reached %s" % [_name, what])
	_finish(1)


func _say(line: String) -> void:
	print("e2e: %s %s" % [_name, line])


func _finish(status: int) -> void:
	if FileAccess.file_exists(_settings):
		DirAccess.remove_absolute(_settings)
	quit(status)
