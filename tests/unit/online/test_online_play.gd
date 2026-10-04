extends GutTest
## A person in a server's room (SH12): one match scene up at a time, whatever the server
## sends. A BEGIN lets the scene that is up go — its results' keys unhooked — before it
## builds the next, a refusal never covers a match being played, the results lead back
## to the room and its next match, and BEGINs faster than an honest server's build one
## scene. Every way out hangs up and says why, once: the server hands a seat left
## mid-match to a bot, a dropped connection offers its room back, and a tab hidden past
## the server's patience is told so. Whatever takes the pause away takes the settings
## screen opened from it first, and while the pause is up the seat stands still.
## OnlinePlay plays over a loopback here, its match scenes stand-ins that draw nothing —
## but for the one that checks the seat — and its clock is the test's.

## A match on the flat deck sunk deep at once: it ends within seconds, whatever the seed.
const SUNK := [[0.0, 0.0, 0.0, 0.0], [1.0, 10.0, 0.0, 0.0]]
## Where the settings screen saves as it closes, here.
const VIEW_PATH := "user://test_online_view_settings.tres"
const AUDIO_PATH := "user://test_online_audio_settings.tres"


## What OnlinePlay builds in place of a MatchScene.
class FakeMatch:
	extends Node
	signal rematch_requested
	signal menu_requested
	signal pointer_lost

	var mouse_freed := false
	var over := false

	func free_mouse(freed: bool) -> void:
		mouse_freed = freed

	func is_over() -> bool:
		return over

	func apply_view(_settings: ViewSettings) -> void:
		pass


var _online: OnlinePlay
## Every scene _online has built, in order.
var _built: Array[FakeMatch] = []
var _now := 0
## What _online said as it ended: [to_menu, note, rejoin] each time.
var _endings: Array[Array] = []


func before_each() -> void:
	_online = null
	_built.clear()
	_now = 0
	_endings.clear()


func after_each() -> void:
	for action: StringName in [&"move_down", &"jump", &"shove"]:
		Input.action_release(action)
	for path: String in [VIEW_PATH, AUDIO_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## OnlinePlay for [param client], creating a room or joining [param code]'s, its match
## scenes stand-ins unless [param real].
func _play(client: RoomClient, code: String = "", real: bool = false) -> OnlinePlay:
	var flags := PackedStringArray(["--connect=ws://127.0.0.1:47923", "--name=Ada"])
	flags.append("--room=" + code if not code.is_empty() else "--create")
	var link := OnlineLink.from_args(MatchArgs.parse(flags), ServerRules.load_default())
	assert_eq(link.problems, PackedStringArray())
	var build := Callable() if real else _build_fake
	_online = OnlinePlay.new(link, client, build, func() -> int: return _now)
	_online.ended.connect(
		func(to_menu: bool, note: String, rejoin: String) -> void:
			_endings.append([to_menu, note, rejoin])
	)
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
	assert_false(online._room_screen.visible)


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
	assert_false(online._room_screen.visible, "the match is not covered")


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
	assert_true(online._room_screen.visible, "the room is shown")
	assert_eq(room.members.size(), 1, "and the player is in it")
	client.start_match()
	fixture.beat()
	assert_eq(_built.size(), 2, "the next match is built")
	assert_eq(online._match, _built[1])
	assert_false(online._room_screen.visible)


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
	server.send(2, codec.encode_roster(_roster("ABCD")))
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
	assert_eq(online.get_child_count(), 3, "the room, the pause and the last scene alone")
	assert_eq(online._match, _built[5])
	LoopbackTransport.unlink(server, end)


## Ada's room, Bea joined through OnlinePlay, and its match begun: [Ada, Bea].
func _in_a_match(fixture: RoomFixtures) -> Array[RoomClient]:
	var host := fixture.room_of(1)[0]
	var bea := fixture.connect_client("Bea")
	_play(bea, host.roster.code)
	fixture.beat(2)
	host.start_match()
	fixture.beat()
	assert_eq(_built.size(), 1, "the match is built")
	return [host, bea]


func _pressed(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_the_room_shows_once_it_is_entered() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	var online := _play(client)
	watch_signals(online)
	fixture.beat(2)
	assert_signal_emit_count(online, "entered_room", 1)
	assert_true(online._room_screen.visible)
	var bea := fixture.connect_client("Bea")
	fixture.beat()
	bea.join_room(client.roster.code)
	fixture.beat()
	assert_eq(client.roster.players.size(), 2, "Bea is aboard")
	assert_signal_emit_count(online, "entered_room", 1, "once, however the room changes")
	assert_eq(_endings, [] as Array[Array])


## The player is told every reason the server may give in a sentence of words — never
## the protocol's name for it.
func test_every_refusal_is_said_in_words() -> void:
	for reason: int in RoomCodec.Refusal.values():
		var said := OnlinePlay.refusal(reason)
		assert_true(OnlinePlay.REFUSALS.has(reason), RoomCodec.Refusal.keys()[reason])
		assert_false(said.contains(RoomCodec.Refusal.keys()[reason]), said)
		assert_true(said.ends_with("."), "%s is a sentence" % said)


func test_a_refusal_outside_a_room_is_said_on_the_online_screen() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	var online := _play(client, "ZZZZ")
	fixture.beat(2)
	assert_eq(_endings, [[false, OnlinePlay.refusal(RoomCodec.Refusal.NO_ROOM), ""]])
	assert_eq(client.state, RoomClient.State.CLOSED, "hung up")
	assert_false(online._room_screen.visible)


## Never reached, even after a frame as long as a hidden tab's: the server never knew
## this player to let it go.
func test_a_server_never_reached_is_said() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	var online := _play(client)
	online._process(0.0)
	_now += roundi(ServerRules.load_default().silence_timeout * 1000.0)
	online._process(0.0)
	fixture.cut(client)
	client.poll()
	assert_eq(_endings, [[false, OnlinePlay.NO_CONNECTION, ""]])


## Esc in a match opens the pause, which lets the mouse go and stops nothing; Esc again,
## or Resume, takes the mouse back. At the results Esc is theirs.
func test_esc_opens_the_online_pause_and_the_match_goes_on() -> void:
	var fixture := _quick_server()
	var players := _in_a_match(fixture)
	var online := _online
	online._unhandled_input(_pressed(&"pause"))
	assert_true(online._pause.visible, "the pause is open")
	assert_true(_built[0].mouse_freed, "the mouse is let go")
	assert_eq(_built[0].process_mode, Node.PROCESS_MODE_INHERIT, "the match goes on")
	online._pause.resume_requested.emit()
	assert_false(online._pause.visible)
	assert_false(_built[0].mouse_freed, "the mouse is taken back")
	_built[0].over = true
	online._unhandled_input(_pressed(&"pause"))
	assert_false(online._pause.visible, "not over the results")
	assert_eq(players[0].state, RoomClient.State.PLAYING)


## Leave match hangs up for the main menu; the server hands the seat to a bot.
func test_leaving_a_match_hands_the_seat_to_a_bot() -> void:
	var fixture := _quick_server()
	var players := _in_a_match(fixture)
	var online := _online
	online._unhandled_input(_pressed(&"pause"))
	online._pause.leave_requested.emit()
	assert_eq(_endings, [[true, "", ""]], "for the main menu")
	_assert_let_go(_built[0], "the match")
	assert_false(online._pause.visible)
	fixture.beat(2)
	assert_true(fixture.logged("Bea left · seat 1 to a bot"), "the seat is a bot's")
	assert_eq(players[0].state, RoomClient.State.PLAYING, "and the match goes on")


## Leave at the results hangs up for the Online screen.
func test_leave_at_the_results_leaves_the_room() -> void:
	var fixture := _quick_server()
	var players := _in_a_match(fixture)
	var room := fixture.room(players[0])
	_finish(fixture, room)
	_built[0].menu_requested.emit()
	assert_eq(_endings, [[false, "", ""]], "for the Online screen")
	_assert_let_go(_built[0], "the match")
	fixture.beat(2)
	assert_eq(room.members.size(), 1, "Ada alone is left in the room")


func test_a_connection_lost_mid_match_offers_its_room_back() -> void:
	var fixture := _quick_server()
	var players := _in_a_match(fixture)
	var code := players[0].roster.code
	fixture.cut(players[1])
	players[1].poll()
	assert_eq(_endings, [[false, OnlinePlay.LOST, code]])
	_assert_let_go(_built[0], "the match")
	assert_false(_online._room_screen.visible, "no room over nothing")


## A browser tab hidden past the server's silence_timeout runs no frame meanwhile; the
## server lets it go, and the first frame back says so.
func test_a_tab_hidden_too_long_is_told_why_it_was_let_go() -> void:
	var fixture := _quick_server()
	var players := _in_a_match(fixture)
	_online._process(0.0)
	_now += roundi(ServerRules.load_default().silence_timeout * 1000.0)
	_online._process(0.0)
	fixture.cut(players[1])
	players[1].poll()
	assert_eq(_endings, [[false, OnlinePlay.AWAY, players[0].roster.code]])


## The host's Start is asked once per showing; the server's BUSY is said, and Start
## comes back for another try.
func test_a_busy_server_is_said_and_start_comes_back() -> void:
	var fixture := RoomFixtures.new(
		RoomFixtures.rules_with({"finished_linger": 0.5, "start_cooldown": 10.0}),
		RoomFixtures.flat_rules(SimFixtures.scenario(SUNK))
	)
	var client := fixture.connect_client("Ada")
	var online := _play(client)
	fixture.beat(2)
	var start: Button = online._room_screen.get_node("%Start")
	assert_false(start.disabled, "the host may start")
	start.pressed.emit()
	start.pressed.emit()
	assert_true(start.disabled, "once")
	fixture.beat()
	assert_eq(_built.size(), 1)
	var room := fixture.room(client)
	var beats := 0
	while room.phase != Room.Phase.WAITING and beats < 120 * Ticks.RATE:
		fixture.beat()
		beats += 1
	_now += 10000
	_built[0].rematch_requested.emit()
	assert_true(online._room_screen.visible, "back in the room")
	start.pressed.emit()
	fixture.beat()
	assert_eq(_built.size(), 1, "the cooldown is not over")
	assert_eq(
		(online._room_screen.get_node("%Note") as Label).text,
		OnlinePlay.refusal(RoomCodec.Refusal.BUSY)
	)
	assert_false(start.disabled, "Start is back")


## Ada alone, the host of room [param code], as a roster says it to her.
static func _roster(code: String) -> RoomRoster:
	var roster := RoomRoster.new()
	roster.code = code
	roster.you = 0
	roster.players.append(RoomRoster.Player.new("Ada", true, false))
	return roster


## A server of the test's own, on a loopback to the client OnlinePlay joins [param code]
## with, which it has welcomed: [the server's end, the client's end, its codec, the
## client]. The test unlinks the two ends.
func _wired(code: String) -> Array:
	var rules := RoomFixtures.flat_rules()
	var codec := RoomCodec.new(RoomServer.data_hash(rules, NetRules.load_default()))
	var clock := NetClock.new()
	var server := LoopbackTransport.new(1, clock, NetConditions.new(), SeedStreams.derive(1, 1))
	var end := LoopbackTransport.new(2, clock, NetConditions.new(), SeedStreams.derive(1, 2))
	LoopbackTransport.link(server, end)
	var client := RoomClient.new(end, rules, NetRules.load_default(), "Ada")
	_play(client, code)
	client.poll()
	server.send(2, codec.encode_bare(WireCodec.Kind.WELCOME))
	return [server, end, codec, client]


## The settings screen as Game hands it to OnlinePlay, saving where the test cleans up.
func _settings() -> SettingsMenu:
	var settings: SettingsMenu = load("res://scenes/game/settings_menu.tscn").instantiate()
	settings.view_path = VIEW_PATH
	settings.audio_path = AUDIO_PATH
	add_child_autofree(settings)
	_online.settings = settings
	return settings


## Esc, then the pause's Settings: the settings screen over the pause over the match.
func _settings_from_the_pause() -> SettingsMenu:
	var settings := _settings()
	_online._unhandled_input(_pressed(&"pause"))
	(_online._pause.get_node("%Settings") as Button).pressed.emit()
	assert_true(settings.visible, "the settings over the pause")
	return settings


## The settings screen gone with the pause, and nothing hidden left with the focus.
func _assert_settings_gone(settings: SettingsMenu, why: String) -> void:
	assert_false(_online._pause.visible, "the pause is gone: %s" % why)
	assert_false(settings.visible, "and the settings with it: %s" % why)
	var focus := get_viewport().gui_get_focus_owner()
	assert_true(focus == null or focus.is_visible_in_tree(), "nothing hidden has the focus")


## The match ends while the player reads the settings: the pause and the settings go,
## so the results' buttons are not pressed unseen under them.
func test_the_match_end_closes_the_settings_opened_from_the_pause() -> void:
	_in_a_match(_quick_server())
	var settings := _settings_from_the_pause()
	_built[0].over = true
	_online._process(0.0)
	_assert_settings_gone(settings, "the match ended")
	assert_false(_built[0].mouse_freed, "the results have the mouse")


## The host's next start pulls the player into the next match while they read the
## settings: the new match is not played under them.
func test_a_begin_closes_the_settings_opened_from_the_pause() -> void:
	var wired := _wired("ABCD")
	var server: LoopbackTransport = wired[0]
	var codec: RoomCodec = wired[2]
	var client: RoomClient = wired[3]
	server.send(2, codec.encode_roster(_roster("ABCD")))
	server.send(2, codec.encode_begin(1701, RoomFixtures.flat_rules().seats, 0))
	client.poll()
	assert_eq(_built.size(), 1)
	var settings := _settings_from_the_pause()
	_now += OnlinePlay.MIN_BUILD_GAP_MSEC
	server.send(2, codec.encode_begin(1702, RoomFixtures.flat_rules().seats, 0))
	client.poll()
	assert_eq(_built.size(), 2, "the next match is up")
	_assert_settings_gone(settings, "the next match began")
	assert_false(_built[1].mouse_freed, "the next match has the mouse")
	LoopbackTransport.unlink(server, wired[1])


func test_a_lost_connection_closes_the_settings_opened_from_the_pause() -> void:
	var fixture := _quick_server()
	var players := _in_a_match(fixture)
	var settings := _settings_from_the_pause()
	fixture.cut(players[1])
	players[1].poll()
	assert_eq(_endings, [[false, OnlinePlay.LOST, players[0].roster.code]])
	_assert_settings_gone(settings, "the connection was lost")


## A hostile server's BEGIN before any room: no match is built — the Online screen
## would stand over it — until the player is in a room.
func test_a_begin_outside_a_room_builds_nothing() -> void:
	var wired := _wired("ABCD")
	var server: LoopbackTransport = wired[0]
	var codec: RoomCodec = wired[2]
	var client: RoomClient = wired[3]
	var begin := codec.encode_begin(1701, RoomFixtures.flat_rules().seats, 0)
	server.send(2, begin)
	client.poll()
	assert_eq(_built.size(), 0, "nothing built outside a room")
	assert_eq(_endings, [] as Array[Array])
	server.send(2, codec.encode_roster(_roster("ABCD")))
	_now += OnlinePlay.MIN_BUILD_GAP_MSEC
	server.send(2, begin)
	client.poll()
	assert_eq(_built.size(), 1, "in a room, a BEGIN builds its match")
	LoopbackTransport.unlink(server, wired[1])


## A browser's first Esc only takes the mouse back: that opens the pause, as the Esc
## would have — never over the results.
func test_a_browser_letting_go_of_the_mouse_opens_the_pause() -> void:
	_in_a_match(_quick_server())
	_built[0].pointer_lost.emit()
	assert_true(_online._pause.visible, "the pause is open")
	assert_true(_built[0].mouse_freed)
	_built[0].pointer_lost.emit()
	_online._pause.resume_requested.emit()
	assert_false(_online._pause.visible)
	_built[0].over = true
	_built[0].pointer_lost.emit()
	assert_false(_online._pause.visible, "not over the results")


## A frame as long as a hidden tab's, then the connection outliving it: a drop later
## is not the hidden tab's.
func test_a_drop_well_after_a_long_frame_is_not_told_as_hidden() -> void:
	var fixture := _quick_server()
	var players := _in_a_match(fixture)
	_online._process(0.0)
	_now += roundi(ServerRules.load_default().silence_timeout * 1000.0)
	_online._process(0.0)
	_now += OnlinePlay.AWAY_GRACE_MSEC
	_online._process(0.0)
	fixture.cut(players[1])
	players[1].poll()
	assert_eq(_endings, [[false, OnlinePlay.LOST, players[0].roster.code]])


## Input's mouse mode, as a stand-in: a browser's, which a click alone captures.
class FakeMouse:
	extends RefCounted
	var mouse_mode := Input.MOUSE_MODE_VISIBLE


## The real match scene under the online pause: down and A move the pause's focus and
## press its buttons, never the seat; the A that resumes does not jump; the look stays
## where it was. In a browser, nothing is the seat's until the click that takes the
## mouse, and that click is not a shove.
func test_the_seat_stands_still_under_the_online_pause() -> void:
	var fixture := _quick_server()
	var host := fixture.room_of(1)[0]
	var online := _play(fixture.connect_client("Bea"), host.roster.code, true)
	fixture.beat(2)
	host.start_match()
	fixture.beat()
	var scene := online._match as MatchScene
	assert_not_null(scene, "a match scene is up")
	var local: LocalInputSource = scene._local
	local.yaw = 0.5
	online._unhandled_input(_pressed(&"pause"))
	assert_true(online._pause.visible)
	Input.action_press(&"move_down")
	Input.action_press(&"jump")
	var held := local.next_frame(1)
	assert_eq(held.move, Vector2i.ZERO, "down moves the pause's focus alone")
	assert_eq(held.buttons, 0, "A presses the pause's button alone")
	assert_eq(held.look_yaw, InputFrame.quantize_yaw(0.5), "the look kept")
	online._pause.resume_requested.emit()
	var resumed := local.next_frame(2)
	assert_eq(resumed.buttons, 0, "the A that resumed does not jump")
	assert_ne(resumed.move, Vector2i.ZERO, "the seat is the player's again")
	Input.action_release(&"move_down")
	Input.action_release(&"jump")
	var mouse := FakeMouse.new()
	scene._pointer.click_to_capture = true
	scene._pointer.device = mouse
	scene._process(0.0)
	Input.action_press(&"move_down")
	assert_eq(local.next_frame(3).move, Vector2i.ZERO, "nothing is the seat's before the click")
	Input.action_press(&"shove")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene._pointer._unhandled_input(click)
	assert_eq(local.next_frame(4).buttons, 0)
	scene._process(0.0)
	var taken := local.next_frame(5)
	assert_ne(taken.move, Vector2i.ZERO, "the mouse taken, the seat walks")
	assert_eq(taken.buttons, 0, "the click that took the mouse does not shove")
	Input.action_release(&"shove")
	assert_eq(local.next_frame(6).buttons, 0)
	Input.action_press(&"shove")
	assert_eq(local.next_frame(7).buttons, InputFrame.SHOVE, "a click after it does")
	Input.action_release(&"shove")
