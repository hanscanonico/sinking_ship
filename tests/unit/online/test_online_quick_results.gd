extends GutTest
## A quick game's results as its room counts down to the next (SH12): the server starts
## the next match on its own with everyone in the room, so the results say when — from
## the same roster time the room screen counts from — and, once it has begun, that it
## shows in a moment. A room whose host starts by hand says nothing of the kind. OnlinePlay
## plays over a loopback here, its clock the test's.

## A match on the flat deck sunk deep at once: it ends within seconds, whatever the seed.
const SUNK := [[0.0, 0.0, 0.0, 0.0], [1.0, 10.0, 0.0, 0.0]]


## The results a FakeMatch shows: only the line about the next match.
class FakeResults:
	extends Node
	var next_line := ""

	func say_next(line: String) -> void:
		next_line = line


## What OnlinePlay builds in place of a MatchScene: over from the start, its results up.
class FakeMatch:
	extends Node
	signal rematch_requested
	signal menu_requested
	signal pointer_lost

	var results := FakeResults.new()

	func _init() -> void:
		results.name = "EndOverlay"
		add_child(results)

	func free_mouse(_freed: bool) -> void:
		pass

	func is_over() -> bool:
		return true

	func apply_view(_settings: ViewSettings) -> void:
		pass


var _online: OnlinePlay
## Every scene _online has built, in order.
var _built: Array[FakeMatch] = []
## The beats _beats has run, and the test's clock in msec, which follows them.
var _beaten := 0
var _now := 0


func before_each() -> void:
	_online = null
	_built.clear()
	_beaten = 0
	_now = 0


## A server whose matches end within seconds.
static func _quick_server() -> RoomFixtures:
	return RoomFixtures.new(
		RoomFixtures.rules_with({"finished_linger": 0.5}),
		RoomFixtures.flat_rules(SimFixtures.scenario(SUNK))
	)


func _build_fake(_played: PlayedMatch, _local: LocalInputSource, _names: PackedStringArray) -> Node:
	var fake := FakeMatch.new()
	_online.add_child(fake)
	_built.append(fake)
	return fake


## OnlinePlay for [param client], in a quick game when [param quick], else in a room it
## creates.
func _play(client: RoomClient, quick: bool) -> OnlinePlay:
	var link := OnlineLink.from_menu(
		"ws://127.0.0.1:47923", not quick, "", "Ada", ServerRules.load_default(), quick
	)
	_online = OnlinePlay.new(link, client, _build_fake, func() -> int: return _now)
	add_child_autofree(_online)
	return _online


## [param count] beats, the test's clock keeping up with each and OnlinePlay's frame run
## after each.
func _beats(fixture: RoomFixtures, count: int) -> void:
	for _beat in count:
		fixture.beat()
		_beaten += 1
		_now = _beaten * 1000 / Ticks.RATE
		_online._process(0.0)


## Beats until [param fixture]'s room for [param client] waits again after its match.
func _until_reopened(fixture: RoomFixtures, client: RoomClient) -> void:
	var room := fixture.room(client)
	while room.phase != Room.Phase.WAITING and _beaten < 120 * Ticks.RATE:
		_beats(fixture, 1)
	assert_eq(room.phase, Room.Phase.WAITING, "the match ended and the room reopened")


## Seen played online (2026-11-26): a player reading a quick game's results was told
## nothing of the next match, and the results gave way to it without a warning.
func test_quick_results_count_down_to_the_next_game() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	_play(client, true)
	_beats(fixture, 2 + ServerRules.beats(fixture.rules.quick_wait))
	assert_eq(_built.size(), 1, "the quick game began")
	_until_reopened(fixture, client)
	_beats(fixture, 5 * Ticks.RATE)
	var left := ceili(fixture.rules.quick_wait - 5.0)
	assert_eq(
		_built[0].results.next_line,
		"The next quick game starts in %d s, with everyone in the room." % left
	)


## A room whose host starts by hand starts nothing on its own: its results say nothing
## of a next match.
func test_hosted_results_say_nothing_of_a_next_game() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	_play(client, false)
	_beats(fixture, 2)
	client.start_match()
	_beats(fixture, 2)
	assert_eq(_built.size(), 1, "the match began")
	_until_reopened(fixture, client)
	_beats(fixture, 5 * Ticks.RATE)
	assert_eq(_built[0].results.next_line, "")


## The next quick game begun from its results: they go, and the room shows while her ship
## is dressed, saying the match is coming — not a blank screen till it shows.
func test_the_next_quick_game_begun_from_the_results_says_it_is_coming() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	var online := _play(client, true)
	_beats(fixture, 2 + ServerRules.beats(fixture.rules.quick_wait))
	_until_reopened(fixture, client)
	# The next match is the real one's, its ship dressed on a thread.
	online._dresses = true
	online._build = online._build_match
	var room := fixture.room(client)
	while room.phase == Room.Phase.WAITING and _beaten < 120 * Ticks.RATE:
		_beats(fixture, 1)
	_beats(fixture, 2)
	assert_null(online._match, "the results are gone and her ship is being dressed")
	assert_true(online._room_screen.visible, "the room shows meanwhile")
	var status: Label = online._room_screen.get_node("%Status")
	assert_eq(status.text, "The match begins: it shows in a moment.")
	await wait_until(func() -> bool: return online._match != null, 60.0)
	assert_not_null(online._match, "and then it shows")
