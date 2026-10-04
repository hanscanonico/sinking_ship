class_name OnlinePlay
extends Node
## A person playing on a server (SH12), where an OnlineLink says: it connects, creates
## the room or joins it by its code, and waits in it on the WaitingRoom — whose host
## starts the match with Enter. The match is the offline game's MatchScene, its seat
## played from this player's keys, mouse and pad (LocalInputSource) through the
## server's RemoteMatch; Esc lets the mouse go and takes it back, as nothing online
## pauses. At the results, either key goes back to the room for the next match.
##
## A player at the results is still in the room, so the host's next start pulls them
## into its match: a BEGIN always lets the match scene that is up go before it builds
## the next, and a refusal never covers a match being played. A BEGIN sooner than
## MIN_BUILD_GAP_MSEC after the last scene was built is not one an honest server sends —
## its matches come a whole match apart — and is left unbuilt, so a hostile server
## cannot make this build scenes as fast as it sends.

const MATCH_DATA := "res://data/match/default.tres"
const MATCH_SCENE := preload("res://scenes/match/match.tscn")
const WAITING_ROOM := preload("res://scenes/online/waiting_room.tscn")
## After the whole match scene: the socket sends what this frame's beats sampled, then
## reads what has come for the next.
const PROCESS_PRIORITY := 3
const MIN_BUILD_GAP_MSEC := 1000
## What the player is told of a refusal; the rest are named as the protocol names them.
const REFUSALS := {
	RoomCodec.Refusal.VERSION: "This game is another version than the server's.",
	RoomCodec.Refusal.DATA: "This game's data is not the server's.",
	RoomCodec.Refusal.NAME: "The server does not take that name.",
	RoomCodec.Refusal.SERVER_FULL: "The server is full: try again later.",
	RoomCodec.Refusal.NO_ROOM: "No room has that code.",
	RoomCodec.Refusal.ROOM_FULL: "That room is full.",
	RoomCodec.Refusal.PLAYING: "That room's match has begun.",
	RoomCodec.Refusal.ROOM_CLOSED: "The room has closed.",
	RoomCodec.Refusal.BUSY: "The server is busy: try again in a moment.",
}

var _link: OnlineLink
## The socket this dialled; null when the RoomClient was handed in.
var _socket: WebSocketTransport
var _room: RoomClient
var _waiting: WaitingRoom
## The match played or its results shown, as _build made it; null in between.
var _match: Node
## Makes, adds as a child and starts the scene for a match begun: _build_match, or a
## test's that draws nothing. The scene has MatchScene's rematch_requested and
## menu_requested signals and its free_mouse().
var _build: Callable
## Milliseconds, as Time.get_ticks_msec counts them, and when the last match scene was
## built by them; -1 before the first.
var _clock: Callable
var _built_msec := -1
var _mouse_freed := false


## Plays where [param link] says. A test hands in [param room], a RoomClient on a wire
## of its own, and [param build] and [param clock] for _build and _clock.
func _init(
	link: OnlineLink, room: RoomClient = null, build := Callable(), clock := Callable()
) -> void:
	_link = link
	_room = room
	_build = build if build.is_valid() else _build_match
	_clock = clock if clock.is_valid() else Callable(Time, &"get_ticks_msec")
	process_priority = PROCESS_PRIORITY


func _ready() -> void:
	_waiting = WAITING_ROOM.instantiate()
	add_child(_waiting)
	if not _link.problems.is_empty():
		_waiting.show_status("This link cannot be played:\n\n" + "\n".join(_link.problems))
		return
	if _room == null:
		_socket = WebSocketTransport.new()
		var error := _socket.dial(_link.server_url)
		if error != OK:
			_waiting.show_status("Cannot reach %s: %s" % [_link.server_url, error_string(error)])
			return
		var match_rules: MatchRules = load(MATCH_DATA)
		_room = RoomClient.new(_socket, match_rules, NetRules.load_default(), _link.player_name)
	_room.welcomed.connect(_on_welcomed)
	_room.refused.connect(_on_refused)
	_room.roster_changed.connect(_on_roster_changed)
	_room.began.connect(_on_began)
	_room.closed.connect(_on_closed)
	_waiting.start_requested.connect(_room.start_match)
	_waiting.show_status("Connecting to %s…" % _link.server_url)


func _process(_delta: float) -> void:
	if _room == null:
		return
	if _socket != null:
		_socket.poll()
	_room.poll()


func _unhandled_input(event: InputEvent) -> void:
	if _match == null or not event.is_action_pressed("pause"):
		return
	_mouse_freed = not _mouse_freed
	_match.call(&"free_mouse", _mouse_freed)
	get_viewport().set_input_as_handled()


func _on_welcomed() -> void:
	if _link.create:
		_room.create_room()
	else:
		_room.join_room(_link.room)


func _on_refused(reason: int) -> void:
	# What is refused while a match is on — a second START sent before its BEGIN came,
	# say — changes nothing of it.
	if _match != null:
		return
	if _room.roster != null:
		_waiting.show_room(_room.roster, _refusal(reason))
	else:
		_waiting.show_status(_refusal(reason))


func _on_roster_changed(roster: RoomRoster) -> void:
	if _match != null:
		return
	if roster == null:
		_waiting.show_status(_refusal(RoomCodec.Refusal.ROOM_CLOSED))
	else:
		_waiting.show_room(roster)


func _on_began(config: MatchConfig, seat: int) -> void:
	var now: int = _clock.call()
	if _built_msec >= 0 and now - _built_msec < MIN_BUILD_GAP_MSEC:
		return
	_built_msec = now
	_leave_match()
	var local := LocalInputSource.new(seat, 0.0, ViewSettings.local())
	_match = _build.call(_room.play(local), local, _seat_names(config.seats, seat))
	_match.connect(&"rematch_requested", _back_to_room)
	_match.connect(&"menu_requested", _back_to_room)
	_mouse_freed = false
	_waiting.hide()


func _on_closed(reason: int) -> void:
	_leave_match()
	if reason < 0:
		_waiting.show_status("The connection to the server is lost.")
	else:
		_waiting.show_status(_refusal(reason))


## From the results to the room, waiting for its host again.
func _back_to_room() -> void:
	_leave_match()
	if _room.roster != null:
		_waiting.show_room(_room.roster)
	else:
		_waiting.show_status(_refusal(RoomCodec.Refusal.ROOM_CLOSED))


## Lets the match scene go, freed at the frame's end: unhooked and stopped first, so
## nothing of it — its results' keys, its hold on the mouse — reaches the room or the
## next match meanwhile.
func _leave_match() -> void:
	if _match == null:
		return
	_match.disconnect(&"rematch_requested", _back_to_room)
	_match.disconnect(&"menu_requested", _back_to_room)
	_match.process_mode = Node.PROCESS_MODE_DISABLED
	_match.queue_free()
	_match = null


func _build_match(played: PlayedMatch, local: LocalInputSource, names: PackedStringArray) -> Node:
	var scene: MatchScene = MATCH_SCENE.instantiate()
	add_child(scene)
	scene.start_online(played, local, names)
	return scene


## Every seat's name as the room listed its players — seat order — this player's as
## "You", and the seats nobody holds as their bots.
func _seat_names(seats: int, seat: int) -> PackedStringArray:
	var names := PackedStringArray()
	var players: Array[RoomRoster.Player] = []
	if _room.roster != null:
		players = _room.roster.players
	for each in seats:
		if each == seat:
			names.append("You")
		elif each < players.size():
			names.append(players[each].name)
		else:
			names.append("Bot %d" % each)
	return names


static func _refusal(reason: int) -> String:
	return REFUSALS.get(reason, "Refused: %s" % RoomCodec.Refusal.keys()[reason])
