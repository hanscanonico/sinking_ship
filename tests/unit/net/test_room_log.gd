extends GutTest
## What the server's log says of a room: the lines an operator reads to know who plays,
## who hosts, and who the bots stand in for (seen in an online crew test, 2026-11-26).


func test_a_match_every_seat_of_which_a_player_takes_has_no_bots() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(fixture.match_rules.seats)
	players[0].start_match()
	fixture.beat()
	assert_true(fixture.logged("match begins"))
	assert_false(fixture.logged("bots on the rest"), "no seat is left for a bot")


func test_a_match_with_seats_to_spare_says_bots_take_them() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(2)
	players[0].start_match()
	fixture.beat()
	assert_true(fixture.logged("Player 1 seat 1 · bots on the rest"))


func test_the_host_leaving_names_who_hosts_now() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(3)
	players[0].leave_room()
	fixture.beat()
	assert_true(fixture.logged("Player 0 left"))
	assert_true(fixture.logged("Player 1 hosts now"), "the new host named")
	assert_true(players[1].roster.you_host(), "as the room says")


func test_a_player_leaving_leaves_the_host_unnamed() -> void:
	var fixture := RoomFixtures.new()
	var players := fixture.room_of(3)
	players[2].leave_room()
	fixture.beat()
	assert_true(fixture.logged("Player 2 left"))
	assert_false(fixture.logged("hosts now"), "the host is the same")
