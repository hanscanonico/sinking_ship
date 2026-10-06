class_name RoomFixtures
extends RefCounted
## A RoomServer and its clients in one process (SH12), over loopbacks that do not lie:
## RoomClients as a menu would drive them, and raw ends for packets made by hand. A
## beat is every client polling, the server stepping, and every client polling again —
## but for a client hushed, gone without a word. Match seeds and room codes come from
## generators of their own, each seeded.

const SERVER_PEER := 1
const MATCH_DATA := "res://data/match/default.tres"
const SEED := 1701
const LETTERS_SEED := 1702

var clock := NetClock.new()
var rules: ServerRules
var match_rules: MatchRules
## What the server draws match seeds from, and room codes' letters.
var seeds := RandomNumberGenerator.new()
var letters := RandomNumberGenerator.new()
var server_end: LoopbackTransport
var server: RoomServer
## The server's codec: what a raw end speaks.
var codec: RoomCodec
## Every line the server logged.
var said := PackedStringArray()

var _clients: Array[RoomClient] = []
var _ends := {}
var _next_peer := SERVER_PEER + 1


## A server held to [param server_rules] — the shipped ones when null — serving
## [param served]' matches — the default match's when null — over a server end of
## [param server_end_kind], a LoopbackTransport or one of its kind, drawing room codes
## from [param codes] and match seeds from [param match_seeds] — [member letters] and
## [member seeds] when null.
func _init(
	server_rules: ServerRules = null,
	served: MatchRules = null,
	server_end_kind: GDScript = null,
	codes: Draws = null,
	match_seeds: Draws = null
) -> void:
	rules = server_rules if server_rules != null else ServerRules.load_default()
	match_rules = served if served != null else load(MATCH_DATA)
	seeds.seed = SEED
	letters.seed = LETTERS_SEED
	var kind: GDScript = server_end_kind if server_end_kind != null else LoopbackTransport
	server_end = kind.new(SERVER_PEER, clock, NetConditions.new(), SeedStreams.derive(SEED, 0))
	server = RoomServer.new(
		server_end,
		rules,
		NetRules.load_default(),
		match_rules,
		match_seeds if match_seeds != null else SeededDraws.new(seeds),
		codes if codes != null else SeededDraws.new(letters)
	)
	server.logged.connect(_hear)
	codec = RoomCodec.new(RoomServer.data_hash(match_rules, NetRules.load_default()))


## The default match's rules on the flat deck: its ship's fewest seats, no countdown,
## and [param sinking] — the flat deck's own scenario, afloat, when null.
static func flat_rules(sinking: SinkScenario = null) -> MatchRules:
	var flat: MatchRules = load(MATCH_DATA).duplicate()
	flat.seats = flat.ship.min_seats
	flat.countdown = 0.0
	flat.ship = SimFixtures.deck()
	flat.sinking = sinking if sinking != null else load(SimFixtures.FLAT_SINKING)
	return flat


## A server's rules as shipped, but for what [param changes] sets.
static func rules_with(changes: Dictionary) -> ServerRules:
	var changed: ServerRules = ServerRules.load_default().duplicate()
	for field: String in changes:
		changed.set(field, changes[field])
	return changed


## A new end connected to the server, for packets made by hand.
func raw_end() -> LoopbackTransport:
	var end := LoopbackTransport.new(
		_next_peer, clock, NetConditions.new(), SeedStreams.derive(SEED, _next_peer)
	)
	_next_peer += 1
	LoopbackTransport.link(server_end, end)
	return end


## A client known as [param display_name] connected to the server — of
## [param data]'s matches played to [param net], the server's when null. It says hello
## on the next beat.
func connect_client(
	display_name: String, data: MatchRules = null, net: NetRules = null
) -> RoomClient:
	var end := raw_end()
	var client := RoomClient.new(
		end,
		data if data != null else match_rules,
		net if net != null else NetRules.load_default(),
		display_name
	)
	_clients.append(client)
	_ends[client] = end
	return client


## The end [param client] talks through.
func end_of(client: RoomClient) -> LoopbackTransport:
	return _ends[client]


## Parts [param client] from the server, as a process killed mid-match would be.
func cut(client: RoomClient) -> void:
	LoopbackTransport.unlink(server_end, end_of(client))


## Silences [param client] for good, its connection left open: a machine gone without
## closing its socket. It is polled no more, so it answers nothing.
func hush(client: RoomClient) -> void:
	_clients.erase(client)


## [param count] beats.
func beat(count: int = 1) -> void:
	for _beat in count:
		clock.advance(Ticks.SECONDS_PER_TICK)
		for client: RoomClient in _clients:
			client.poll()
		server.step()
		for client: RoomClient in _clients:
			client.poll()


## [param count] clients welcomed in one room, the first its creator and host.
func room_of(count: int) -> Array[RoomClient]:
	var players: Array[RoomClient] = []
	for index in count:
		players.append(connect_client("Player %d" % index))
	beat()
	players[0].create_room()
	beat()
	for index in range(1, count):
		players[index].join_room(players[0].roster.code)
	beat()
	return players


## The reasons [param client] is refused for from now on, as they come.
static func refusals(client: RoomClient) -> Array[int]:
	var reasons: Array[int] = []
	client.refused.connect(func(reason: int) -> void: reasons.append(reason))
	return reasons


## The server's room [param client] is in.
func room(client: RoomClient) -> Room:
	return server.room(client.roster.code)


## Whether the server logged a line holding [param text].
func logged(text: String) -> bool:
	for line: String in said:
		if line.contains(text):
			return true
	return false


## The reason of the REFUSED [param end] has been sent, or -1 when none came.
func refusal(end: LoopbackTransport) -> int:
	var reason := -1
	for packet: Transport.Packet in end.receive():
		var message := codec.decode(packet.bytes)
		if message != null and message.kind == WireCodec.Kind.REFUSED:
			reason = message.value
	return reason


## A HELLO from [param end], said and answered.
func hello(end: LoopbackTransport, display_name: String = "Raw") -> void:
	end.send(SERVER_PEER, codec.encode_hello(display_name))
	beat()
	end.receive()


func _hear(line: String) -> void:
	said.append(line)
