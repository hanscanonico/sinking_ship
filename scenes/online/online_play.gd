class_name OnlinePlay
extends Node
## A person playing on a server (SH12), where the Online screen's OnlineLink says: it
## connects, creates the room, joins it by its code or asks for a quick game, and shows
## the room (RoomScreen), whose host starts the match — a quick game's starting on its own.
## The match is the offline game's MatchScene, its seat
## played from this player's keys, mouse and pad (LocalInputSource) through the server's
## RemoteMatch — or, for a player who chose to watch in the room, no seat at all: the
## match only watched, as a local Watch is (GLOSSARY: Watch). Esc opens the online
## pause over it (OnlinePause) — the match goes on
## under it, as nothing online pauses, the seat standing still while the pause has the
## keys, the pad and the mouse — whose Leave match hangs up for the Online screen, the
## server handing the seat to a bot. In a browser, whose first Esc only takes the mouse back, the
## mouse let go opens it too. The pause goes whenever the match under it does — at its
## end, at the next BEGIN, at any way out — and the settings screen opened from it goes
## with it, before whatever shows next takes the focus. At the results, Back to the room
## waits there for the host's next start, and Leave hangs up for the Online screen.
##
## A player at the results is still in the room, so the host's next start pulls them
## into its match: a BEGIN always lets the match scene that is up go before it builds
## the next, and neither a refusal nor the room is ever shown over a match being played.
## Its scene is made as the match begins and shown once her ship is dressed on a thread
## (ShipDressing), the room showing and the socket polled meanwhile: dressed in a frame,
## she would stall it for seconds, and a frame that long answers none of the server's pings.
## A BEGIN outside a room is not one an honest server sends, and builds nothing.
## A BEGIN sooner than MIN_BUILD_GAP_MSEC after the last scene was built is not one an
## honest server sends — its matches come a whole match apart — and is left unbuilt, so
## a hostile server cannot make this build scenes as fast as it sends.
##
## Every way out — a refusal outside a room, the room closed, the connection never made
## or lost, the player leaving — hangs up and says so once, with [signal ended]; Game
## frees this then. A browser tab that is hidden stops running, and the server lets a
## player it has not heard from for its silence_timeout go: a frame that long after the
## last is remembered, and the end of the connection that follows within AWAY_GRACE_MSEC
## told as that — one later is not the hidden tab's.

## The room is shown: the Online screen gives way to it.
signal entered_room
## A match scene is up, or the room is shown again after one.
signal playing_changed(playing: bool)
## Over, for the Online screen: [param was_in_room] when this player had been in a room,
## saying [param note] — "" for nothing — and offering to rejoin [param rejoin], a room's
## code, when it is not "".
signal ended(was_in_room: bool, note: String, rejoin: String)

const MATCH_DATA := "res://data/match/default.tres"
const MATCH_SCENE := preload("res://scenes/match/match.tscn")
const ROOM_SCREEN := preload("res://scenes/online/room_screen.tscn")
const ONLINE_PAUSE := preload("res://scenes/online/online_pause.tscn")
## After the whole match scene: the socket sends what this frame's beats sampled, then
## reads what has come for the next.
const PROCESS_PRIORITY := 3
const MIN_BUILD_GAP_MSEC := 1000
## How soon after a frame as long as a hidden tab's a server that let this player go has
## said so: the connection still open after that has outlived the hiding.
const AWAY_GRACE_MSEC := 3000
## What the player is told of each refusal, in a sentence.
const REFUSALS := {
	RoomCodec.Refusal.VERSION: "This game is another version than the server's: update it.",
	RoomCodec.Refusal.DATA: "This game's match data is not the server's: update it.",
	RoomCodec.Refusal.MALFORMED: "The server could not read what this game sent it.",
	RoomCodec.Refusal.NAME: "The server does not take that name: choose another.",
	RoomCodec.Refusal.TIMEOUT: "The server stopped hearing from this game and let it go.",
	RoomCodec.Refusal.ATTEMPTS: "Too many tries at room codes: wait a minute and try again.",
	RoomCodec.Refusal.FLOOD: "This game sent the server too much at once and was let go.",
	RoomCodec.Refusal.NOT_READING: "This game fell behind the server and was let go.",
	RoomCodec.Refusal.TIMELINE: "The server's sinking did not check out: this game left it.",
	RoomCodec.Refusal.SERVER_FULL: "The server is full: try again later.",
	RoomCodec.Refusal.NO_ROOM: "No room has that code: check it with the room's host.",
	RoomCodec.Refusal.ROOM_FULL: "That room is full.",
	RoomCodec.Refusal.PLAYING: "That room's match is on: try again once it ends.",
	RoomCodec.Refusal.NOT_HOST: "Only the room's host can start the match.",
	RoomCodec.Refusal.IN_ROOM: "This game is in a room already.",
	RoomCodec.Refusal.ROOM_CLOSED: "The room has closed.",
	RoomCodec.Refusal.BUSY: "The server is busy: try again in a moment.",
	RoomCodec.Refusal.NO_PLAYERS: "Everyone here watches: someone has to play.",
}
const NO_CONNECTION := "Could not reach the server: try again later."
const LOST := "The connection to the server was lost."
const AWAY := "This game was hidden too long, and the server let it go."

## The settings screen the pause opens: Game's.
var settings: SettingsMenu

var _link: OnlineLink
## The socket this dialled; null when the RoomClient was handed in.
var _socket: WebSocketTransport
var _room: RoomClient
var _room_screen: RoomScreen
var _pause: OnlinePause
## The match played or its results shown, as _build made it; null in between.
var _match: Node
## Makes, adds as a child and starts the scene for a match begun: _build_match, or a
## test's that draws nothing. The scene has MatchScene's rematch_requested,
## menu_requested and pointer_lost signals, its free_mouse(), is_over() and apply_view().
var _build: Callable
## Whether a match begun waits for its ship to be dressed on a thread before its scene is
## built — _build_match's, which draws her — so no frame stalls for seconds, the room
## showing and the socket polled meanwhile; a test's stand-ins are built at once.
var _dresses: bool
## The match begun whose ship is being dressed, and what its scene is to be built of —
## its PlayedMatch, LocalInputSource and seat names; null and empty while none waits.
var _dressing: ShipDressing
var _begun: Array = []
## The frame the match began waiting on its dressing in, and its scene, made then and
## standing aside till its ship is dressed; null while none waits.
var _begun_frame := 0
var _made: MatchScene
## Milliseconds, as Time.get_ticks_msec counts them, and when the last match scene was
## built and the last frame ran by them; -1 before the first.
var _clock: Callable
var _built_msec := -1
## When the room's roster last came, by _clock: a quick game counts down from then, however
## long its results kept this player from the room.
var _roster_msec := -1
var _frame_msec := -1
## When a frame came longer than the server's silence_timeout after the one before it,
## while the server knew this player; -1 before any did.
var _away_msec := -1
var _silence_msec: int
## Whether the match up is only watched: its BEGIN gave this player no seat.
var _watching := false
## The players of the match up already gone from it, by name (the room's are its own):
## each one going is said once in its feed.
var _gone: Dictionary[String, bool] = {}
## The code of the room last shown: Rejoin's, should the connection drop.
var _code := ""
var _welcomed := false
var _ended := false


## Plays where [param link] says. A test hands in [param room], a RoomClient on a wire
## of its own, and [param build] and [param clock] for _build and _clock.
func _init(
	link: OnlineLink, room: RoomClient = null, build := Callable(), clock := Callable()
) -> void:
	_link = link
	_room = room
	_build = build if build.is_valid() else _build_match
	_dresses = not build.is_valid()
	_clock = clock if clock.is_valid() else Callable(Time, &"get_ticks_msec")
	_silence_msec = roundi(ServerRules.load_default().silence_timeout * 1000.0)
	process_priority = PROCESS_PRIORITY


func _ready() -> void:
	var match_rules: MatchRules = load(MATCH_DATA)
	_room_screen = ROOM_SCREEN.instantiate()
	_room_screen.clock = _clock
	_room_screen.seats = match_rules.seats
	_room_screen.server_url = _link.server_url
	add_child(_room_screen)
	_pause = ONLINE_PAUSE.instantiate()
	add_child(_pause)
	_room_screen.leave_requested.connect(_end.bind("", ""))
	_pause.resume_requested.connect(_resume)
	_pause.settings_requested.connect(func() -> void: settings.open())
	_pause.leave_requested.connect(_end.bind("", ""))
	if not _link.problems.is_empty():
		_room = null
		_end.call_deferred(_link.problems[0], "")
		return
	if _room == null:
		_socket = WebSocketTransport.new()
		if _socket.dial(_link.server_url) != OK:
			_end.call_deferred(NO_CONNECTION, "")
			return
		_room = RoomClient.new(_socket, match_rules, NetRules.load_default(), _link.player_name)
	_room.welcomed.connect(_on_welcomed)
	_room.refused.connect(_on_refused)
	_room.roster_changed.connect(_on_roster_changed)
	_room.began.connect(_on_began)
	_room.closed.connect(_on_closed)
	_room_screen.start_requested.connect(_room.start_match)
	_room_screen.watch_requested.connect(_room.watch)


func _process(_delta: float) -> void:
	if _room == null or _ended:
		return
	var now: int = _clock.call()
	if _welcomed and _frame_msec >= 0 and now - _frame_msec >= _silence_msec:
		_away_msec = now
	_frame_msec = now
	if _match != null and _pause.visible and _match.call(&"is_over"):
		_resume()
	if _socket != null:
		_socket.poll()
	_room.poll()
	# A frame on from the BEGIN at the soonest, which made the scene: the two never share
	# a frame.
	if _dressing != null and Engine.get_process_frames() > _begun_frame and _dressing.done():
		_show_match()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _open_pause():
		get_viewport().set_input_as_handled()


## Hangs up without a word: the player has left for somewhere else.
func hang_up() -> void:
	if _ended:
		return
	_ended = true
	_leave_match()
	_room_screen.hide()
	_close_pause()
	if _room == null:
		return
	_room.welcomed.disconnect(_on_welcomed)
	_room.refused.disconnect(_on_refused)
	_room.roster_changed.disconnect(_on_roster_changed)
	_room.began.disconnect(_on_began)
	_room.closed.disconnect(_on_closed)
	_room.hang_up()
	if _socket != null:
		_socket.poll()


## Takes up the settings screen's view mid-match.
func apply_view(view: ViewSettings) -> void:
	if _match != null:
		_match.call(&"apply_view", view)


## The panel the backdrop's ship stands beside while the room shows.
func room_panel() -> Control:
	return _room_screen.panel()


func _on_welcomed() -> void:
	_welcomed = true
	if _link.create:
		_room.create_room()
	elif _link.quick:
		_room.quick_game()
	else:
		_room.join_room(_link.room)


func _on_refused(reason: int) -> void:
	# What is refused while a match is on — a second START sent before its BEGIN came,
	# say — changes nothing of it.
	if _match != null:
		return
	if _room.roster != null:
		_show_room(refusal(reason))
	else:
		_end(refusal(reason), "")


func _on_roster_changed(roster: RoomRoster) -> void:
	_roster_msec = _clock.call()
	if _match != null:
		_say_who_left(roster)
		return
	if roster == null:
		_end(refusal(RoomCodec.Refusal.ROOM_CLOSED), "")
		return
	var entering := not _room_screen.visible
	_code = roster.code
	_show_room()
	if entering:
		entered_room.emit()


func _on_began(config: MatchConfig, seat: int) -> void:
	if _room.roster == null:
		return
	var now: int = _clock.call()
	if _built_msec >= 0 and now - _built_msec < MIN_BUILD_GAP_MSEC:
		return
	_built_msec = now
	_leave_match()
	_watching = seat < 0
	_gone.clear()
	_say_who_left(_room.roster, false)
	var local: LocalInputSource = null
	if not _watching:
		local = LocalInputSource.new(seat, 0.0, ViewSettings.local())
	var played := _room.play(local)
	_begun = [played, local, _seat_names(config.seats, seat)]
	# The boxes her water is drawn in are made beside her dressing (#634).
	ShipPieces.warm_water(played.client.sim)
	if not _dresses:
		_show_match()
		return
	# Her ship is dressed on a thread, and the scene made now, standing aside till then.
	_dressing = ShipDressing.new(config).start()
	_begun_frame = Engine.get_process_frames()
	_made = MATCH_SCENE.instantiate()
	add_child(_made)
	_made.stand_aside()


## Says in the match's feed which of [param roster]'s players have gone from its match
## since — a bot playing on in their seat, unless it was out already — once each, never
## this player nor one who only watched; only counts them when not [param saying], as
## the match begins.
func _say_who_left(roster: RoomRoster, saying := true) -> void:
	if roster == null or not roster.playing:
		return
	var feed := _match.get_node_or_null(^"KnockoutFeed") if _match != null else null
	var seats: Array = []
	if _match != null and _match.has_method(&"current"):
		seats = (_match.call(&"current") as Dictionary).get("seats", [])
	var you: RoomRoster.Player = null
	if roster.you >= 0 and roster.you < roster.players.size():
		you = roster.players[roster.you]
	var seated := roster.seated()
	for seat in seated.size():
		var player := seated[seat]
		if not player.bot or player == you or _gone.has(player.name):
			continue
		_gone[player.name] = true
		if not saying or feed == null or not feed.has_method(&"say"):
			continue
		var out: bool = seat < seats.size() and seats[seat]["out"]
		var line := Language.t("%s left") if out else Language.t("%s left: a bot plays on")
		feed.call(&"say", line % player.name)


## The match begun is shown: its scene built and started (_build), over the room.
func _show_match() -> void:
	_match = _build.callv(_begun)
	_begun = []
	_match.connect(&"rematch_requested", _back_to_room)
	_match.connect(&"menu_requested", _leave_room)
	_match.connect(&"pointer_lost", _open_pause)
	_room_screen.hide()
	_close_pause()
	playing_changed.emit(true)


func _on_closed(reason: int) -> void:
	var note := LOST if _welcomed else NO_CONNECTION
	var away: bool = _away_msec >= 0 and _clock.call() - _away_msec < AWAY_GRACE_MSEC
	if away and (reason < 0 or reason == RoomCodec.Refusal.TIMEOUT):
		note = AWAY
	elif reason >= 0:
		note = refusal(reason)
	var dropped := reason < 0 or reason == RoomCodec.Refusal.TIMEOUT
	_end(note, _code if dropped and _room_lives_on() else "")


## Whether the room this player was dropped from is still there to rejoin: the server
## closes a room as its last player goes, a seat whose client has gone being a bot's —
## so only while another player whose client is still in holds it open (#807).
func _room_lives_on() -> bool:
	var roster := _room.roster
	if roster == null:
		return false
	for index in roster.players.size():
		if index != roster.you and not roster.players[index].bot:
			return true
	return false


## From the results to the room, waiting for its host again.
func _back_to_room() -> void:
	_leave_match()
	if _room.roster == null:
		_end(refusal(RoomCodec.Refusal.ROOM_CLOSED), "")
		return
	playing_changed.emit(false)
	# The match the roster may still show as on is the one just seen end (finished_linger).
	_show_room("", true)


## The room as its roster last came, with [param note] under it; [param ended] as
## RoomScreen.show_room has it. A BEGIN come — this player's next match being made —
## has the room say so, not that a match is on.
func _show_room(note: String = "", ended: bool = false) -> void:
	var begun := _room.state == RoomClient.State.PLAYING
	_room_screen.show_room(_room.roster, note, ended, _roster_msec, begun)


## From the results out of the room, for the Online screen.
func _leave_room() -> void:
	_end("", "")


## Opens the online pause over the match being played, letting the mouse go: false when
## there is none, it is over, or the pause is open already.
func _open_pause() -> bool:
	if _match == null or _pause.visible or _match.call(&"is_over"):
		return false
	_match.call(&"free_mouse", true)
	var prompts: InputPrompts = null
	if _watching and _match.has_method(&"prompts"):
		prompts = _match.call(&"prompts")
	_pause.open(prompts)
	return true


func _resume() -> void:
	_close_pause()
	if _match != null:
		_match.call(&"free_mouse", false)


## Puts the pause away, and the settings screen opened from it — the pause first, so
## the focus is not handed back to it.
func _close_pause() -> void:
	if not _pause.visible:
		return
	_pause.hide()
	if settings != null and settings.visible:
		settings.close()


## Hangs up and says why, for the Online screen: [param note] and [param rejoin] — once,
## whatever comes after.
func _end(note: String, rejoin: String) -> void:
	if _ended:
		return
	hang_up()
	ended.emit(not _code.is_empty(), note, rejoin)


## Lets the match scene go, freed at the frame's end: unhooked and stopped first, so
## nothing of it — its results' keys, its hold on the mouse — reaches the room or the
## next match meanwhile. A match still waiting on its ship's dressing is let go too.
func _leave_match() -> void:
	if _dressing != null:
		_dressing.drop()
		_dressing = null
	if _made != null:
		_made.queue_free()
		_made = null
	_begun = []
	if _match == null:
		return
	_match.disconnect(&"rematch_requested", _back_to_room)
	_match.disconnect(&"menu_requested", _leave_room)
	_match.disconnect(&"pointer_lost", _open_pause)
	_match.process_mode = Node.PROCESS_MODE_DISABLED
	_match.queue_free()
	_match = null


## The scene made as the match began (_on_began), its ship dressed, started — or a new
## one, when none was made.
func _build_match(played: PlayedMatch, local: LocalInputSource, names: PackedStringArray) -> Node:
	var scene := _made
	_made = null
	if scene == null:
		scene = MATCH_SCENE.instantiate()
		add_child(scene)
	scene.dressing = _dressing
	_dressing = null
	scene.start_online(played, local, names)
	return scene


## Every seat's name as the room listed its players who play — seat order, a watcher
## never a seat — this player's as "You", and the seats nobody holds as their bots.
func _seat_names(seats: int, seat: int) -> PackedStringArray:
	var names := PackedStringArray()
	var players: Array[RoomRoster.Player] = []
	if _room.roster != null:
		players = _room.roster.seated()
	for each in seats:
		if each == seat:
			names.append(Language.t("You"))
		elif each < players.size():
			names.append(players[each].name)
		else:
			names.append(Language.t("Bot %d") % each)
	return names


## What the player is told of a refusal for [param reason].
static func refusal(reason: int) -> String:
	return REFUSALS.get(reason, "The server refused this game.")
