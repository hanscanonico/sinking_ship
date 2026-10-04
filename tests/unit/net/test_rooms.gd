extends GutTest
## Rooms (SH12): four-letter codes, unique, read in any case and drawn apart from the
## match seeds every player is shown; the host starts the match and bots take the seats
## nobody holds (D10); a player who goes mid-match leaves their seat to a bot and the
## match plays on; a full room refuses a join; and a finished match is let go, its room
## waiting for its host again. Over loopbacks, as RoomClients a menu would drive.

## Long enough for every bot to have walked or shoved, the countdown behind them.
const ACTING_BEATS := 8 * Ticks.RATE


## A walk to starboard on every tick.
class Walking:
	extends InputSource

	func next_frame(tick: int) -> InputFrame:
		return InputFrame.new(0, tick, Vector2i(0, InputFrame.AXIS_MAX))


## Whether [param seat] of [param room]'s match pressed or moved on the tick just
## stepped.
static func _acted(room: Room, seat: int) -> bool:
	var last: Array = room.host.runner.snapshot["seats"][seat]["last_input"]
	return last[0] != 0 or last[1] != 0 or last[3] != 0


## The seats of [param room]'s match that act at least once over [param beats].
static func _acting(fixture: RoomFixtures, room: Room, beats: int) -> Dictionary:
	var acting := {}
	for _beat in beats:
		fixture.beat()
		for seat: int in room.host.runner.sim.config.seats:
			if _acted(room, seat):
				acting[seat] = true
	return acting


func test_room_codes_are_unique_and_case_insensitive() -> void:
	var fixture := RoomFixtures.new()
	var codes := {}
	for index in 10:
		var creator := fixture.connect_client("Creator %d" % index)
		fixture.beat()
		creator.create_room()
		fixture.beat()
		var code := creator.roster.code
		assert_eq(RoomCodec.normalize_code(code), code, "%s is four code letters" % code)
		assert_false(codes.has(code), "%s is no other room's" % code)
		codes[code] = true
	# Drawn again from the same point, the letters meet the first code, taken.
	fixture.letters.seed = RoomFixtures.LETTERS_SEED
	var again := fixture.connect_client("Again")
	fixture.beat()
	again.create_room()
	fixture.beat()
	assert_false(codes.has(again.roster.code), "a code drawn twice is drawn again")
	assert_eq(fixture.server.room_count(), 11)
	var first: String = codes.keys()[0]
	for typed: String in [first.to_lower(), " %s " % first.capitalize()]:
		var joiner := fixture.connect_client("Joiner")
		fixture.beat()
		joiner.join_room(typed)
		fixture.beat()
		assert_eq(joiner.state, RoomClient.State.ROOM, "%s finds the room" % typed)
		assert_eq(joiner.roster.code, first)
	assert_eq(fixture.server.room(first).members.size(), 3)


## A player is shown every match's seed (BEGIN): were codes drawn from the same
## generator, a few seeds seen would tell every code to come. Codes follow the letters
## the server is handed and nothing else; seeds, the seeds.
func test_room_codes_follow_their_own_draws_alone() -> void:
	var told := _codes_and_seeds(RoomFixtures.SEED, RoomFixtures.LETTERS_SEED)
	var other_letters := _codes_and_seeds(RoomFixtures.SEED, RoomFixtures.LETTERS_SEED + 1)
	var other_seeds := _codes_and_seeds(RoomFixtures.SEED + 1, RoomFixtures.LETTERS_SEED)
	assert_eq(other_letters[1], told[1], "the same seed stream, the same match seeds")
	assert_ne(other_letters[0], told[0], "and other letters, other codes")
	assert_eq(other_seeds[0], told[0], "the same letters, the same codes")
	assert_ne(other_seeds[1], told[1], "whatever the match seeds")
	for code: String in told[0]:
		assert_eq(RoomCodec.normalize_code(code), code, "%s is four code letters" % code)


## The codes of three rooms made and started one after another, and their matches'
## seeds, on a server drawing seeds from [param seeds_seed] and letters from
## [param letters_seed].
static func _codes_and_seeds(seeds_seed: int, letters_seed: int) -> Array[PackedStringArray]:
	var fixture := RoomFixtures.new(
		RoomFixtures.rules_with({"starts_per_second": 3}), RoomFixtures.flat_rules()
	)
	fixture.seeds.seed = seeds_seed
	fixture.letters.seed = letters_seed
	var codes := PackedStringArray()
	var seeds := PackedStringArray()
	for index in 3:
		var creator := fixture.room_of(1)[0]
		creator.start_match()
		fixture.beat()
		codes.append(creator.roster.code)
		seeds.append(str(fixture.room(creator).host.runner.sim.config.match_seed))
	return [codes, seeds]


func test_empty_seats_are_filled_by_bots() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(2)
	var seats: Array[int] = []
	for player: RoomClient in players:
		player.began.connect(func(_config: MatchConfig, seat: int) -> void: seats.append(seat))
	players[0].start_match()
	fixture.beat()
	assert_eq(seats, [0, 1] as Array[int], "the players take the first seats, in order")
	var room := fixture.room(players[0])
	var count: int = room.host.runner.sim.config.seats
	assert_eq(count, fixture.match_rules.seats, "the match has all its seats")
	for seat in count:
		assert_eq(room.is_bot(seat), seat >= 2, "seat %d" % seat)
	# The players send nothing: only the bots move.
	var acting := _acting(fixture, room, ACTING_BEATS)
	for seat in count:
		assert_eq(acting.has(seat), seat >= 2, "seat %d acts only if a bot holds it" % seat)


func test_disconnect_hands_the_seat_to_a_bot() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(2)
	players[0].start_match()
	fixture.beat(Ticks.RATE)
	var room := fixture.room(players[0])
	var gone_peer := fixture.end_of(players[1]).peer
	var sent_before: int = room.wire.sent_packets[gone_peer]
	fixture.cut(players[1])
	fixture.beat()
	assert_true(room.is_bot(1), "the seat is a bot's")
	assert_false(room.is_bot(0))
	assert_true(players[0].roster.players[1].bot, "the others are told")
	assert_true(fixture.logged("left · seat 1 to a bot"))
	var acting := _acting(fixture, room, ACTING_BEATS)
	assert_true(acting.has(1), "the bot plays the seat")
	assert_false(acting.has(0), "the player still here sent nothing")
	assert_eq(room.wire.sent_packets[gone_peer], sent_before, "nothing more is sent to it")
	assert_eq(room.phase, Room.Phase.PLAYING, "the match plays on")


func test_full_room_refuses_a_join() -> void:
	var fixture := RoomFixtures.new(RoomFixtures.rules_with({"players_per_room": 2}))
	var players := fixture.room_of(2)
	var late := fixture.connect_client("Late")
	var reasons := RoomFixtures.refusals(late)
	fixture.beat()
	late.join_room(players[0].roster.code)
	fixture.beat()
	assert_eq(reasons, [RoomCodec.Refusal.ROOM_FULL] as Array[int])
	assert_eq(late.state, RoomClient.State.LOBBY, "still connected, in no room")
	assert_eq(fixture.room(players[0]).members.size(), 2)
	assert_eq(players[0].roster.players.size(), 2)


func test_only_the_host_starts() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(2)
	var reasons := RoomFixtures.refusals(players[1])
	players[1].start_match()
	fixture.beat()
	assert_eq(reasons, [RoomCodec.Refusal.NOT_HOST] as Array[int])
	assert_eq(fixture.room(players[0]).phase, Room.Phase.WAITING)
	assert_true(players[0].roster.players[0].host, "the creator hosts")


func test_a_joined_match_cannot_be_joined() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(1)
	players[0].start_match()
	fixture.beat()
	var late := fixture.connect_client("Late")
	var reasons := RoomFixtures.refusals(late)
	fixture.beat()
	late.join_room(players[0].roster.code)
	fixture.beat()
	assert_eq(reasons, [RoomCodec.Refusal.PLAYING] as Array[int])


## The match reaches the client as the scene would play it: its own seat moves on its
## frames, through the room's share of the wire.
func test_a_client_plays_its_seat_through_the_room() -> void:
	var fixture := RoomFixtures.new(null, RoomFixtures.flat_rules())
	var players := fixture.room_of(1)
	players[0].start_match()
	fixture.beat()
	assert_eq(players[0].state, RoomClient.State.PLAYING, "the match began")
	var played := players[0].play(Walking.new())
	var room := fixture.room(players[0])
	var start: Vector3 = room.host.runner.snapshot["seats"][0]["pos"]
	for _beat in 2 * Ticks.RATE:
		played.step()
		fixture.beat()
	var host_seat: Dictionary = room.host.runner.snapshot["seats"][0]
	assert_eq(host_seat["last_input"][1], InputFrame.AXIS_MAX, "the host applies its frames")
	assert_gt(host_seat["pos"].z - start.z, 1.0, "and moves the seat to starboard")
	var seen: Dictionary = played.client.view()["seats"][0]
	assert_almost_eq(seen["pos"].z, host_seat["pos"].z, 0.5, "the client sees it there")


func test_the_last_player_leaving_closes_the_room() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(2)
	var code := players[0].roster.code
	players[0].start_match()
	fixture.beat()
	players[0].leave_room()
	fixture.beat()
	assert_true(fixture.room(players[1]).is_bot(0), "the leaver's seat goes to a bot")
	assert_true(players[1].roster.players[1].host, "the host's part passes on")
	fixture.cut(players[1])
	fixture.beat()
	assert_null(fixture.server.room(code), "nobody is left to play for")
	assert_true(fixture.logged("room %s closed: everyone left" % code))


func test_an_idle_room_is_closed() -> void:
	var fixture := RoomFixtures.new(RoomFixtures.rules_with({"idle_room_timeout": 1.0}))
	var players := fixture.room_of(1)
	var code := players[0].roster.code
	var reasons := RoomFixtures.refusals(players[0])
	fixture.beat(Ticks.RATE)
	assert_null(fixture.server.room(code))
	assert_eq(reasons, [RoomCodec.Refusal.ROOM_CLOSED] as Array[int])
	assert_eq(players[0].state, RoomClient.State.LOBBY, "back in no room, still connected")
	assert_null(players[0].roster)


## A match on the flat deck sunk deep at once: every deck under and everyone swimming,
## the sea settles it whatever the seed.
func test_a_finished_match_is_let_go() -> void:
	var sunk := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [1.0, 10.0, 0.0, 0.0]])
	var fixture := RoomFixtures.new(
		RoomFixtures.rules_with({"finished_linger": 0.5}), RoomFixtures.flat_rules(sunk)
	)
	var finished: Array[String] = []
	fixture.server.match_finished.connect(func(code: String) -> void: finished.append(code))
	var players := fixture.room_of(1)
	var code := players[0].roster.code
	players[0].start_match()
	fixture.beat()
	var room := fixture.room(players[0])
	var beats := 0
	while room.phase == Room.Phase.PLAYING and beats < 120 * Ticks.RATE:
		fixture.beat()
		beats += 1
	assert_eq(room.phase, Room.Phase.FINISHED, "the match ended")
	assert_true(fixture.logged("room %s | " % code), "its transcript is logged")
	assert_true(fixture.logged("tick ms mean"), "with its tick time")
	fixture.beat(Ticks.RATE)
	assert_eq(finished, [code] as Array[String], "and it is let go")
	assert_eq(room.phase, Room.Phase.WAITING, "the room waits for its host again")
	assert_null(room.host)
	assert_false(players[0].roster.playing, "the player is told")
	assert_eq(players[0].state, RoomClient.State.ROOM)
