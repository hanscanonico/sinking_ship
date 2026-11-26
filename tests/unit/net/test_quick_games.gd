extends GutTest
## Quick games (QUICK): no code needed — everyone asking waits in one room, which starts
## on its own once its wait is over or it is full, bots on the empty seats. Over loopbacks,
## as RoomClients a menu would drive.


## A quick game (QUICK): everyone asking is put in one room, no code needed, which starts
## on its own once its wait is over — the players seated in the order they asked, bots on
## the rest — and whoever asks once it is on finds a new one waiting.
func test_a_quick_game_seats_everyone_waiting_together() -> void:
	var fixture := RoomFixtures.new()
	var players: Array[RoomClient] = []
	for index in 3:
		players.append(fixture.connect_client("Quick %d" % index))
	fixture.beat()
	var seats: Array[int] = []
	for player: RoomClient in players:
		player.began.connect(func(_config: MatchConfig, seat: int) -> void: seats.append(seat))
		player.quick_game()
	fixture.beat()
	var code := players[0].roster.code
	var wait := ServerRules.beats(fixture.rules.quick_wait)
	for player: RoomClient in players:
		assert_eq(player.state, RoomClient.State.ROOM)
		assert_eq(player.roster.code, code, "one room for everyone waiting")
		assert_true(player.roster.quick, "and it is a quick game")
		assert_between(player.roster.starts_in, 1, wait, "counting down to its start")
	assert_eq(fixture.server.room_count(), 1)
	fixture.beat(wait - 1)
	var room := fixture.room(players[0])
	assert_eq(room.phase, Room.Phase.WAITING, "it waits out its wait")
	fixture.beat()
	assert_eq(room.phase, Room.Phase.PLAYING, "then starts with nobody pressing Start")
	assert_eq(seats, [0, 1, 2] as Array[int], "the players take the first seats, in order")
	for seat: int in room.host.runner.sim.config.seats:
		assert_eq(room.is_bot(seat), seat >= 3, "seat %d" % seat)
	var late := fixture.connect_client("Late")
	fixture.beat()
	late.quick_game()
	fixture.beat()
	assert_eq(late.state, RoomClient.State.ROOM)
	assert_ne(late.roster.code, code, "a quick game on is not joined: a new one waits")
	assert_true(late.roster.quick)


## A quick game that fills starts at once, its wait cut short.
func test_a_full_quick_game_starts_at_once() -> void:
	var fixture := RoomFixtures.new(RoomFixtures.rules_with({"players_per_room": 2}))
	var players: Array[RoomClient] = [fixture.connect_client("Ada"), fixture.connect_client("Bea")]
	fixture.beat()
	for player: RoomClient in players:
		player.quick_game()
	fixture.beat()
	assert_eq(fixture.room(players[0]).phase, Room.Phase.PLAYING, "full, it starts")
	assert_eq(players[1].roster.code, players[0].roster.code)
	assert_true(fixture.logged("is a quick game"))


## A quick game where everyone watches has nobody to play: it waits again rather than
## start, and starts once someone plays.
func test_a_quick_game_of_watchers_waits_for_a_player() -> void:
	var fixture := RoomFixtures.new()
	var watcher := fixture.connect_client("Ada")
	fixture.beat()
	watcher.quick_game()
	fixture.beat()
	watcher.watch(true)
	var wait := ServerRules.beats(fixture.rules.quick_wait)
	fixture.beat(wait)
	var room := fixture.room(watcher)
	assert_eq(room.phase, Room.Phase.WAITING, "nobody plays: nothing starts")
	assert_between(watcher.roster.starts_in, wait - 1, wait, "it waits again, and says so")
	watcher.watch(false)
	fixture.beat(wait)
	assert_eq(room.phase, Room.Phase.PLAYING)
