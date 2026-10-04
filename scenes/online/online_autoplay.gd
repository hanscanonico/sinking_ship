class_name OnlineAutoplay
extends Node
## `--connect=ws://HOST:PORT --create|--room=CODE --name=NAME --autoplay`: a player on
## a server with nobody at the keys (SH12), what `make serve-local` runs. It goes
## through RoomClient as the Online screen does: says hello, creates a room or joins one
## by its code, and — the room's creator — starts the match once --start-at players are
## in. A bot plays its seat from the client, sampled as a player's hands would be, and
## a SimDriver steps the match as the scene's does. It prints what happens to it, and
## quits as the match ends or the connection does.

const MATCH_DATA := "res://data/match/default.tres"

var _args: MatchArgs
var _socket := WebSocketTransport.new()
var _room: RoomClient
var _driver: SimDriver
var _seat := -1
var _started := false
var _done := false


func _init(args: MatchArgs) -> void:
	_args = args


func _ready() -> void:
	if not _args.create_room and _args.room_code.is_empty():
		_quit("online: --connect needs --create or --room=CODE", 1)
		return
	Engine.max_fps = ServerRules.load_default().headless_fps
	var error := _socket.dial(_args.connect_url)
	if error != OK:
		_quit("online: cannot connect to %s — %s" % [_args.connect_url, error_string(error)], 1)
		return
	var match_rules: MatchRules = load(MATCH_DATA)
	_room = RoomClient.new(_socket, match_rules, NetRules.load_default(), _args.player_name)
	_room.welcomed.connect(_on_welcomed)
	_room.refused.connect(_on_refused)
	_room.roster_changed.connect(_on_roster_changed)
	_room.began.connect(_on_began)
	_room.closed.connect(_on_closed)
	_say("connecting to %s" % _args.connect_url)


func _process(_delta: float) -> void:
	if _room == null:
		return
	_socket.poll()
	_room.poll()


func _on_welcomed() -> void:
	if _args.create_room:
		_room.create_room()
	else:
		_room.join_room(_args.room_code)


func _on_refused(reason: int) -> void:
	_quit("refused: %s" % RoomCodec.Refusal.keys()[reason], 1)


func _on_roster_changed(roster: RoomRoster) -> void:
	if roster == null:
		return
	var names := PackedStringArray()
	for player: RoomRoster.Player in roster.players:
		names.append(
			player.name + (" (host)" if player.host else "") + (" (bot)" if player.bot else "")
		)
	_say(
		"in room %s%s: %s" % [roster.code, " · playing" if roster.playing else "", ", ".join(names)]
	)
	if (
		roster.you_host()
		and not roster.playing
		and not _started
		and roster.players.size() >= _args.start_at
	):
		_started = true
		_room.start_match()


func _on_began(config: MatchConfig, seat: int) -> void:
	_seat = seat
	_say(
		(
			"match begins · seed %d · %d seats · playing seat %d"
			% [config.match_seed, config.seats, seat]
		)
	)
	var bot := BotInputSource.new(seat, BotProfile.for_tier(config.bot_tier), config)
	_driver = SimDriver.new()
	add_child(_driver)
	_driver.stepped.connect(_on_stepped)
	_driver.start(_room.play(bot))


## After each beat: what it sent goes out now, not a frame later.
func _on_stepped(events: Array[SimEvent]) -> void:
	_socket.poll()
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.SEAT_OUT:
			_say(
				(
					"%s seat %d out · place %d"
					% [MatchTranscript.clock(event.tick), event.seat, event.place]
				)
			)
	if _done or not _driver.client.is_over():
		return
	_done = true
	var view := _driver.client.view()
	var mine: Dictionary = view["seats"][_seat]
	_room.hang_up()
	_socket.poll()
	_quit(
		(
			"match over at %s · seat %d placed %d of %d"
			% [MatchTranscript.clock(view["tick"]), _seat, mine["place"], view["seats"].size()]
		),
		0
	)


func _on_closed(reason: int) -> void:
	if _done:
		return
	var why: String = "lost" if reason < 0 else RoomCodec.Refusal.keys()[reason]
	_quit("connection closed: %s" % why, 1)


func _quit(line: String, status: int) -> void:
	_done = true
	if status == 0:
		_say(line)
	else:
		printerr("%s %s" % [_args.player_name, line])
	get_tree().quit(status)


func _say(line: String) -> void:
	print("%s %s %s" % [Time.get_time_string_from_system(), _args.player_name, line])
