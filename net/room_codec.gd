class_name RoomCodec
extends RefCounted
## The room protocol (SH12), in packets opened as every other (WireCodec): a client
## says HELLO with its display name, then CREATEs a room, JOINs one by its code,
## STARTs the match as the room's host, or LEAVEs; the server answers WELCOME, or
## REFUSED with a reason, sends the room's ROSTER whenever it changes and, as a match
## begins, BEGIN with its seed, its seat count and the client's seat. PING and PONG
## time the round trip. Every packet is read as hostile, the server's too: decode()
## answers null for anything that is not exactly one message of this protocol and
## match, text travels as printable ASCII only, and every seat or place a message names
## is one it has.

const CODE_LENGTH := 4
## A room code's letters: I and O left out, so none reads as 1 or 0.
const CODE_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"
const FIRST_PRINTABLE := 0x20
const LAST_PRINTABLE := 0x7E
## A player not in the roster, in a ROSTER's byte for whose it is.
const NOBODY := 0xFF
const HOST_FLAG := 1
const BOT_FLAG := 2

## Why the server refused a client something. VERSION to NOT_READING end the
## connection (ends_connection); the rest leave the client where it was, but for one
## that comes before WELCOME: SERVER_FULL, a server holding all the connections it may.
## BUSY: the server makes no more rooms or matches just now; CREATE or START again
## later.
enum Refusal {
	VERSION,
	DATA,
	MALFORMED,
	NAME,
	TIMEOUT,
	ATTEMPTS,
	FLOOD,
	NOT_READING,
	SERVER_FULL,
	NO_ROOM,
	ROOM_FULL,
	PLAYING,
	NOT_HOST,
	IN_ROOM,
	ROOM_CLOSED,
	BUSY,
}


## One message, decoded: its kind and what that kind carries.
class Message:
	extends RefCounted
	var kind: WireCodec.Kind
	## HELLO's display name; JOIN's code as typed.
	var text := ""
	## REFUSED's reason, BEGIN's seed, PING's and PONG's stamp.
	var value := 0
	## BEGIN's seat count, and the seat it gives the client.
	var seats := 0
	var seat := -1
	var roster: RoomRoster

	func _init(message_kind: WireCodec.Kind) -> void:
		kind = message_kind


var wire: WireCodec


## The room protocol of the server whose RoomServer.data_hash() is
## [param data_hash] — the same for every match of its data, whatever the seed.
func _init(data_hash: String) -> void:
	wire = WireCodec.new(data_hash)


## Whether a refusal for [param reason] ends the connection: the server closes it,
## and the client lets it go.
static func ends_connection(reason: int) -> bool:
	return reason < Refusal.SERVER_FULL


## [param typed] as a room code — upper case, so a code is the same however it is
## typed — or "" when it cannot be one.
static func normalize_code(typed: String) -> String:
	var code := typed.strip_edges().to_upper()
	if code.length() != CODE_LENGTH:
		return ""
	for letter: String in code:
		if not CODE_LETTERS.contains(letter):
			return ""
	return code


## A packet of [param kind] that carries nothing more: WELCOME, CREATE, LEAVE or
## START.
func encode_bare(kind: WireCodec.Kind) -> PackedByteArray:
	return wire.header(kind).data_array


func encode_hello(display_name: String) -> PackedByteArray:
	var out := wire.header(WireCodec.Kind.HELLO)
	_put_text(out, display_name)
	return out.data_array


func encode_join(code: String) -> PackedByteArray:
	var out := wire.header(WireCodec.Kind.JOIN)
	_put_text(out, code)
	return out.data_array


func encode_refused(reason: Refusal) -> PackedByteArray:
	var out := wire.header(WireCodec.Kind.REFUSED)
	out.put_u8(reason)
	return out.data_array


## PING or PONG, as [param kind] says, carrying [param stamp].
func encode_stamp(kind: WireCodec.Kind, stamp: int) -> PackedByteArray:
	var out := wire.header(kind)
	out.put_u32(stamp & 0xFFFFFFFF)
	return out.data_array


func encode_begin(match_seed: int, seats: int, seat: int) -> PackedByteArray:
	var out := wire.header(WireCodec.Kind.BEGIN)
	out.put_u32(match_seed & 0xFFFFFFFF)
	out.put_u8(seats)
	out.put_u8(seat)
	return out.data_array


func encode_roster(roster: RoomRoster) -> PackedByteArray:
	var out := wire.header(WireCodec.Kind.ROSTER)
	_put_text(out, roster.code)
	out.put_u8(1 if roster.playing else 0)
	out.put_u8(roster.you if roster.you >= 0 else NOBODY)
	out.put_u8(roster.players.size())
	for player: RoomRoster.Player in roster.players:
		_put_text(out, player.name)
		out.put_u8((HOST_FLAG if player.host else 0) | (BOT_FLAG if player.bot else 0))
	return out.data_array


## The message [param bytes] holds; null when it is not exactly one message of this
## protocol and match. INPUT and SNAPSHOT come back by kind alone: WireCodec reads
## what they carry.
func decode(bytes: PackedByteArray) -> Message:
	var read := wire.kind_of(bytes)
	if read < 0:
		return null
	var kind := read as WireCodec.Kind
	var message := Message.new(kind)
	var reader := wire.open(bytes, kind)
	match kind:
		WireCodec.Kind.INPUT, WireCodec.Kind.SNAPSHOT:
			return message
		WireCodec.Kind.HELLO, WireCodec.Kind.JOIN:
			message.text = _text(reader)
		WireCodec.Kind.REFUSED:
			message.value = reader.byte()
			if message.value >= Refusal.size():
				return null
		WireCodec.Kind.PING, WireCodec.Kind.PONG:
			message.value = reader.u32()
		WireCodec.Kind.BEGIN:
			message.value = reader.u32()
			message.seats = reader.byte()
			message.seat = reader.byte()
			if message.seat >= message.seats:
				return null
		WireCodec.Kind.ROSTER:
			message.roster = _roster(reader)
	return message if reader.finished() else null


## [param text] as UTF-8 behind its length: anything but printable ASCII goes as
## typed, for the other end to refuse rather than for this one to mangle.
static func _put_text(out: StreamPeerBuffer, text: String) -> void:
	var bytes := text.to_utf8_buffer()
	out.put_u8(mini(bytes.size(), 0xFF))
	out.put_data(bytes.slice(0, 0xFF))


## A length-prefixed run of printable ASCII; anything else breaks the packet.
static func _text(reader: WireCodec.Reader) -> String:
	var ascii := reader.bytes(reader.byte())
	for code: int in ascii:
		if code < FIRST_PRINTABLE or code > LAST_PRINTABLE:
			reader.ok = false
			return ""
	return ascii.get_string_from_ascii()


## A roster, its code one a room may have and its [member RoomRoster.you] one of its
## players or nobody; anything else breaks the packet.
static func _roster(reader: WireCodec.Reader) -> RoomRoster:
	var roster := RoomRoster.new()
	roster.code = _text(reader)
	roster.playing = reader.byte() != 0
	var you := reader.byte()
	roster.you = -1 if you == NOBODY else you
	for index in reader.byte():
		var player_name := _text(reader)
		var flags := reader.byte()
		roster.players.append(
			RoomRoster.Player.new(player_name, flags & HOST_FLAG != 0, flags & BOT_FLAG != 0)
		)
	if normalize_code(roster.code) != roster.code or roster.you >= roster.players.size():
		reader.ok = false
	return roster
