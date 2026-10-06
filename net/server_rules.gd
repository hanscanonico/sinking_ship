class_name ServerRules
extends Resource
## What a server lets its clients do (SH12, R9), every one of whom may be hostile:
## how many may connect and how many rooms they may hold, how big and how frequent
## their packets may be, how long they may say nothing, and how much the server holds
## for one that has stopped reading. Times are authored in seconds and counted in the
## server's beats, a tick each (Ticks). The numbers live in data/net/server.tres.

const PATH := "res://data/net/server.tres"
## The characters a display name may hold besides letters and digits.
const NAME_PUNCTUATION := " -_.'"

## The port a server listens on and the address it binds, unless told otherwise; the
## loopback address keeps a dev server off the network.
@export var port: int
@export var bind_address: String
## Frames a second a headless server or client runs at: its socket is looked at once
## a frame, and the match stepped at 30 Hz among them.
@export var headless_fps: int
@export var max_connections: int
@export var max_rooms: int
## Players a room holds, at most the match's seats: bots take the rest.
@export var players_per_room: int
@export var name_length: int
## CREATEs and JOINs one connection may send at once before it is turned away, and
## how long it waits for one more: what bounds the codes it may guess.
@export var room_attempts: int
@export var attempt_refill: float
## STARTs the whole server takes in any one second of beats, and how long one
## connection waits between two: building a match stalls every room. A START past
## either is refused BUSY before anything is built.
@export var starts_per_second: int
@export var start_cooldown: float
## The largest packet a client may send; a larger one ends its connection.
@export var packet_bytes: int
## Packets a client may send in any one second of beats.
@export var packets_per_second: int
## Bytes the server holds for one client that has not yet left: past it, the client
## has stopped reading and is dropped.
@export var outbound_backlog: int
## How long a socket may take over its WebSocket handshake, then over its HELLO.
@export var handshake_timeout: float
@export var hello_timeout: float
## How long a client may stay in no room, and a room wait for its match.
@export var lobby_timeout: float
@export var idle_room_timeout: float
## How long a player in a room may send neither an input nor a pong — counted again
## from its match's start — past which the client is gone however its socket looks,
## and its seat is a bot's. At least two ping_intervals and a second.
@export var silence_timeout: float
## How long a finished match keeps sending its last snapshot before its room goes back
## to waiting.
@export var finished_linger: float
## How long a refused client has to read why before its connection is closed.
@export var refusal_linger: float
@export var ping_interval: float
## How often the server logs each room's tick time, round trips and bandwidth.
@export var log_interval: float
## The sinking's timeline on its way to a room's players (TimelineStream, D11): each
## page out this far in match time before the match first reads it, and beyond that
## no more than this many bytes a beat, so the first minutes are there before the
## countdown ends and a long timeline never floods a connection.
@export var timeline_lead: float
@export var timeline_bytes_per_beat: int


static func load_default() -> ServerRules:
	return load(PATH)


## [param typed] as a display name — trimmed — or "" when it cannot be one: empty,
## longer than name_length, or holding anything but ASCII letters, digits and
## NAME_PUNCTUATION.
func clean_name(typed: String) -> String:
	var cleaned := typed.strip_edges()
	if cleaned.is_empty() or cleaned.length() > name_length:
		return ""
	for letter: String in cleaned:
		var code := letter.unicode_at(0)
		var alphanumeric := (
			(code >= 0x30 and code <= 0x39)
			or (code >= 0x41 and code <= 0x5A)
			or (code >= 0x61 and code <= 0x7A)
		)
		if not alphanumeric and not NAME_PUNCTUATION.contains(letter):
			return ""
	return cleaned


## [param seconds] in server beats.
static func beats(seconds: float) -> int:
	return Ticks.from_seconds(seconds)


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if port < 1 or port > 0xFFFF:
		found.append("server: port must be within 1…65535")
	for field: String in [
		"headless_fps",
		"max_connections",
		"max_rooms",
		"players_per_room",
		"name_length",
		"room_attempts",
		"starts_per_second",
		"packet_bytes",
		"packets_per_second",
		"outbound_backlog",
		"timeline_bytes_per_beat",
	]:
		if int(get(field)) < 1:
			found.append("server: %s must be at least 1" % field)
	for field: String in [
		"handshake_timeout",
		"hello_timeout",
		"lobby_timeout",
		"idle_room_timeout",
		"silence_timeout",
		"attempt_refill",
		"start_cooldown",
		"finished_linger",
		"refusal_linger",
		"ping_interval",
		"log_interval",
		"timeline_lead",
	]:
		if beats(float(get(field))) < 1:
			found.append("server: %s must be at least a tick" % field)
	# A player in a waiting room is heard from only through the pongs it answers, at most
	# a ping_interval apart plus the round trip.
	if silence_timeout < 2.0 * ping_interval + 1.0:
		found.append("server: silence_timeout must be at least 2 × ping_interval + 1 s")
	# A name travels behind one length byte, and a roster lists its players in one.
	if name_length > 0xFF:
		found.append("server: name_length must be at most 255")
	if players_per_room > 0xFE:
		found.append("server: players_per_room must be at most 254")
	return found
