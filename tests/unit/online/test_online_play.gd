extends GutTest
## A person in a server's room (SH12): one match scene up at a time, whatever the server
## sends. A BEGIN lets the scene that is up go — its results' keys unhooked — before it
## builds the next, a refusal never covers a match being played, the results lead back
## to the room and its next match, and BEGINs faster than an honest server's build one
## scene. OnlinePlay plays over a loopback here, its match scenes stand-ins that draw
## nothing, and its clock is the test's.

## A match on the flat deck sunk deep at once: it ends within seconds, whatever the seed.
const SUNK := [[0.0, 0.0, 0.0, 0.0], [1.0, 10.0, 0.0, 0.0]]


## What OnlinePlay builds in place of a MatchScene.
class FakeMatch:
	extends Node
	signal rematch_requested
	signal menu_requested

	func free_mouse(_freed: bool) -> void:
		pass


var _online: OnlinePlay
## Every scene _online has built, in order.
var _built: Array[FakeMatch] = []
var _now := 0


func before_each() -> void:
	_online = null
	_built.clear()
	_now = 0


## OnlinePlay for [param client], creating a room or joining [param code]'s.
func _play(client: RoomClient, code: String = "") -> OnlinePlay:
	var flags := PackedStringArray(["--connect=ws://127.0.0.1:47923", "--name=Ada"])
	flags.append("--room=" + code if not code.is_empty() else "--create")
	var link := OnlineLink.from_args(MatchArgs.parse(flags), ServerRules.load_default())
	assert_eq(link.problems, PackedStringArray())
	_online = OnlinePlay.new(link, client, _build_fake, func() -> int: return _now)
	add_child_autofree(_online)
	return _online


func _build_fake(_played: PlayedMatch, _local: LocalInputSource, _names: PackedStringArray) -> Node:
	var fake := FakeMatch.new()
	_online.add_child(fake)
	_built.append(fake)
	return fake


## A server whose matches end within seconds and whose host may start again at once.
static func _quick_server() -> RoomFixtures:
	return RoomFixtures.new(
		RoomFixtures.rules_with({"finished_linger": 0.5, "start_cooldown": 1.0}),
		RoomFixtures.flat_rules(SimFixtures.scenario(SUNK))
	)


## Beats until [param room]'s match is over, the room waits for its host again and
## the host may start once more, the test's clock keeping up.
func _finish(fixture: RoomFixtures, room: Room) -> void:
	var beats := 0
	while room.phase != Room.Phase.WAITING and beats < 120 * Ticks.RATE:
		fixture.beat()
		beats += 1
	assert_eq(room.phase, Room.Phase.WAITING, "the match ended and the room reopened")
	var cooldown := ServerRules.beats(fixture.rules.start_cooldown)
	fixture.beat(cooldown)
	_now += (beats + cooldown) * 1000 / Ticks.RATE


## Whether [param node] is let go: unhooked from the room, and freed at the frame's end.
func _assert_let_go(node: FakeMatch, what: String) -> void:
	assert_true(node.is_queued_for_deletion(), "%s is freed" % what)
	for unhooked: StringName in [&"rematch_requested", &"menu_requested"]:
		assert_true(node.get_signal_connection_list(unhooked).is_empty(), "%s is unhooked" % what)


## The honest way to a second BEGIN on a live scene: the host starts the next match
## while a member still reads the last one's results.
func test_the_next_match_lets_the_last_one_go() -> void:
	var fixture := _quick_server()
	var host := fixture.room_of(1)[0]
	var online := _play(fixture.connect_client("Ada"), host.roster.code)
	fixture.beat(2)
	host.start_match()
	fixture.beat()
	assert_eq(_built.size(), 1, "the match is built")
	_finish(fixture, fixture.room(host))
	host.start_match()
	fixture.beat()
	assert_eq(_built.size(), 2, "the next is built over the results")
	_assert_let_go(_built[0], "the last match")
	assert_eq(online._match, _built[1])
	_built[0].rematch_requested.emit()
	_built[0].menu_requested.emit()
	assert_false(_built[1].is_queued_for_deletion(), "the old results' keys reach nothing")
	assert_false(online._waiting.visible)


## The host's Enter twice within a round trip: the second START is refused PLAYING
## after the BEGIN has come, and the match stays in view.
func test_a_refusal_never_covers_a_match() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	var online := _play(client)
	fixture.beat(2)
	var refused := RoomFixtures.refusals(client)
	client.start_match()
	client.start_match()
	fixture.beat()
	assert_eq(refused, [RoomCodec.Refusal.PLAYING] as Array[int])
	assert_eq(_built.size(), 1)
	assert_eq(online._match, _built[0])
	assert_false(online._waiting.visible, "the match is not covered")


## R at the results: back in the room, still a member, and in its next match when the
## host starts it.
func test_the_results_lead_back_to_the_room_and_its_next_match() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	var online := _play(client)
	fixture.beat(2)
	client.start_match()
	fixture.beat()
	var room := fixture.room(client)
	_finish(fixture, room)
	_built[0].rematch_requested.emit()
	_assert_let_go(_built[0], "the match")
	assert_null(online._match)
	assert_true(online._waiting.visible, "the room is shown")
	assert_eq(room.members.size(), 1, "and the player is in it")
	client.start_match()
	fixture.beat()
	assert_eq(_built.size(), 2, "the next match is built")
	assert_eq(online._match, _built[1])
	assert_false(online._waiting.visible)


## A hostile server sending BEGIN after BEGIN: one scene built for those within
## MIN_BUILD_GAP_MSEC, and however far apart they come, only the last one in the tree.
func test_a_begin_storm_builds_one_scene_at_a_time() -> void:
	var rules := RoomFixtures.flat_rules()
	var codec := RoomCodec.new(RoomServer.data_hash(rules, NetRules.load_default()))
	var clock := NetClock.new()
	var server := LoopbackTransport.new(1, clock, NetConditions.new(), SeedStreams.derive(1, 1))
	var end := LoopbackTransport.new(2, clock, NetConditions.new(), SeedStreams.derive(1, 2))
	LoopbackTransport.link(server, end)
	var client := RoomClient.new(end, rules, NetRules.load_default(), "Ada")
	var online := _play(client, "ABCD")
	client.poll()
	server.send(2, codec.encode_bare(WireCodec.Kind.WELCOME))
	var begin := codec.encode_begin(1701, rules.seats, 0)
	for _storm in 20:
		server.send(2, begin)
	client.poll()
	assert_eq(_built.size(), 1, "one scene for a burst")
	for _storm in 5:
		_now += OnlinePlay.MIN_BUILD_GAP_MSEC
		server.send(2, begin)
		client.poll()
	assert_eq(_built.size(), 6, "one for each BEGIN spaced as an honest server's")
	for index in 5:
		_assert_let_go(_built[index], "scene %d" % index)
	await wait_process_frames(1)
	assert_eq(online.get_child_count(), 2, "the waiting room and the last scene alone")
	assert_eq(online._match, _built[5])
	LoopbackTransport.unlink(server, end)
