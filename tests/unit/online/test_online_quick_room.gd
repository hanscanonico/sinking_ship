extends GutTest
## A quick game's room as its player comes back to it and goes on to the next match
## (SH12): back from the results it counts down from when the room reopened, however
## long they were read, and while the next match's ship is dressed it says the match is
## coming — not that one is on that it waits out. OnlinePlay plays over a loopback here,
## its clock the test's.

## A match on the flat deck sunk deep at once: it ends within seconds, whatever the seed.
const SUNK := [[0.0, 0.0, 0.0, 0.0], [1.0, 10.0, 0.0, 0.0]]


## What OnlinePlay builds in place of a MatchScene.
class FakeMatch:
	extends Node
	signal rematch_requested
	signal menu_requested
	signal pointer_lost

	func free_mouse(_freed: bool) -> void:
		pass

	func is_over() -> bool:
		return false

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


## OnlinePlay for [param client] in a quick game, its match scenes stand-ins unless
## [param real].
func _play_quick(client: RoomClient, real: bool = false) -> OnlinePlay:
	var link := OnlineLink.from_menu(
		"ws://127.0.0.1:47923", false, "", "Ada", ServerRules.load_default(), true
	)
	var build := Callable() if real else _build_fake
	_online = OnlinePlay.new(link, client, build, func() -> int: return _now)
	add_child_autofree(_online)
	return _online


## [param count] beats, the test's clock keeping up with each.
func _beats(fixture: RoomFixtures, count: int) -> void:
	for _beat in count:
		fixture.beat()
		_beaten += 1
		_now = _beaten * 1000 / Ticks.RATE


## Back from the results of a quick game the room counts down to its next start from
## when it reopened, not afresh: seen played online (2026-11-26), the room's countdown
## was off by however long the results were read.
func test_back_in_a_quick_room_it_counts_down_from_its_reopening() -> void:
	var fixture := _quick_server()
	var client := fixture.connect_client("Ada")
	_play_quick(client)
	var status: Label = _online._room_screen.get_node("%Status")
	_beats(fixture, 2 + ServerRules.beats(fixture.rules.quick_wait))
	assert_eq(_built.size(), 1, "the quick game began")
	var room := fixture.room(client)
	while room.phase != Room.Phase.WAITING and _beaten < 120 * Ticks.RATE:
		_beats(fixture, 1)
	assert_eq(room.phase, Room.Phase.WAITING, "the match ended and the room reopened")
	_beats(fixture, 10 * Ticks.RATE)
	_built[0].rematch_requested.emit()
	assert_true(_online._room_screen.visible, "the room is shown")
	var left := ceili(fixture.rules.quick_wait - 10.0)
	assert_eq(
		status.text,
		"Quick game: it starts in %d s with everyone aboard. Bots take the rest." % left
	)


## While the match begun has its ship dressed the room shows, and says the match is
## coming rather than that one is on that it waits out (seen played online, 2026-11-26:
## the room read as busy, then the match came with no warning).
func test_a_quick_game_begun_says_it_is_coming() -> void:
	var fixture := _quick_server()
	var online := _play_quick(fixture.connect_client("Ada"), true)
	_beats(fixture, 2 + ServerRules.beats(fixture.rules.quick_wait))
	assert_null(online._match, "her ship is being dressed")
	assert_true(online._room_screen.visible, "the room shows meanwhile")
	var status: Label = online._room_screen.get_node("%Status")
	assert_eq(status.text, "The match begins: it shows in a moment.")
	assert_true((online._room_screen.get_node("%Start") as Button).disabled)
	await wait_until(func() -> bool: return online._match != null, 60.0)
	assert_not_null(online._match, "and then it shows")
