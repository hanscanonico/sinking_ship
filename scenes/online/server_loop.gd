class_name ServerLoop
extends Node
## `--server`: RoomServer's rooms over a WebSocketTransport, headless (SH12). The
## socket is read every frame and the rooms stepped a beat at a time at 30 Hz,
## every line of the server's log printed with the time of day. Room codes are drawn
## from the system's CSPRNG (SecureDraws) whatever the flags, match seeds too unless
## --seed asks for a run that repeats; the server quits once --matches matches have
## finished.

## A hitch is caught up this many beats at most: past it the matches run late rather
## than fast-forward.
const MAX_BEATS_PER_FRAME := 5
const MATCH_DATA := "res://data/match/default.tres"

var _args: MatchArgs
var _socket := WebSocketTransport.new()
var _rooms: RoomServer
var _accumulator := 0.0
var _finished := 0


func _init(args: MatchArgs) -> void:
	_args = args


func _ready() -> void:
	var rules := ServerRules.load_default()
	var net_rules := NetRules.load_default()
	var match_rules: MatchRules = load(MATCH_DATA)
	var problems := RoomServer.problems(rules, net_rules, match_rules)
	if not problems.is_empty():
		printerr("\n".join(problems))
		get_tree().quit(1)
		return
	Engine.max_fps = rules.headless_fps
	var port := _args.port if _args.port > 0 else rules.port
	var address := _args.bind_address if not _args.bind_address.is_empty() else rules.bind_address
	var error := _socket.listen(port, address, rules)
	if error != OK:
		printerr("server: cannot listen on %s:%d — %s" % [address, port, error_string(error)])
		get_tree().quit(1)
		return
	var secure := SecureDraws.new()
	var seeds: Draws = secure
	if _args.seed_value >= 0:
		var seeded := RandomNumberGenerator.new()
		seeded.seed = _args.seed_value
		seeds = SeededDraws.new(seeded)
	_rooms = RoomServer.new(_socket, rules, net_rules, match_rules, seeds, secure)
	_rooms.logged.connect(_say)
	_rooms.match_finished.connect(_on_match_finished)
	if _args.seed_value >= 0:
		_say("warning: --seed makes every match's seed predictable: never on a public server")
	_say(
		(
			"listening on ws://%s:%d · protocol %d · data %s"
			% [
				address,
				port,
				WireCodec.PROTOCOL_VERSION,
				RoomServer.data_hash(match_rules, net_rules).left(WireCodec.HASH_BYTES * 2),
			]
		)
	)


func _process(delta: float) -> void:
	if _rooms == null:
		return
	_socket.poll()
	_rooms.take_in()
	_accumulator += delta
	var beats := 0
	while _accumulator >= Ticks.SECONDS_PER_TICK and beats < MAX_BEATS_PER_FRAME:
		_accumulator -= Ticks.SECONDS_PER_TICK
		beats += 1
		_rooms.step()
		_socket.poll()
	if beats == MAX_BEATS_PER_FRAME:
		_accumulator = minf(_accumulator, Ticks.SECONDS_PER_TICK)
	if _args.matches > 0 and _finished >= _args.matches:
		_say("served %d match(es): quitting" % _finished)
		_rooms = null
		_socket.shut()
		_socket.poll()
		get_tree().quit()


func _on_match_finished(_code: String) -> void:
	_finished += 1


func _say(line: String) -> void:
	print("%s %s" % [Time.get_time_string_from_system(), line])
