extends GutTest
## A room as its players wait in it (SH12): every seat of the match on a line — the
## host and "you" marked, the rest the bots' — the host's Start asked once a showing and
## dead for everyone else, and every name a plain Label cut short rather than let push
## the screen about, whatever another player typed or a server sent.

const SEATS := 8

var _screen: RoomScreen


func before_each() -> void:
	_screen = load("res://scenes/online/room_screen.tscn").instantiate()
	_screen.seats = SEATS
	add_child_autofree(_screen)


## A room of [param names], the first its host, seen by the player at [param you].
static func _roster(names: Array[String], you: int, playing: bool = false) -> RoomRoster:
	var roster := RoomRoster.new()
	roster.code = "KXRT"
	roster.you = you
	roster.playing = playing
	for index in names.size():
		roster.players.append(RoomRoster.Player.new(names[index], index == 0, false))
	return roster


## Every seat's line, as the words on it.
func _lines() -> Array[String]:
	var lines: Array[String] = []
	for row: Node in _screen.get_node("%Rows").get_children():
		if row.is_queued_for_deletion():
			continue
		var words := PackedStringArray()
		for label: Node in row.get_children():
			words.append((label as Label).text)
		lines.append(" ".join(words))
	return lines


func test_every_seat_is_shown() -> void:
	_screen.show_room(_roster(["Ada", "Bea"], 1))
	assert_eq((_screen.get_node("%Code") as Label).text, "KXRT")
	var lines := _lines()
	assert_eq(lines.size(), SEATS, "a line a seat")
	assert_eq(lines[0], "1 Ada host")
	assert_eq(lines[1], "2 Bea you")
	for seat in range(2, SEATS):
		assert_eq(lines[seat], "%d A bot takes this seat" % (seat + 1))
	assert_eq((_screen.get_node("%Aboard") as Label).text, "Aboard · 2 of 8")


## The host asks once a showing; the server's answer — BUSY here — shows the room again
## and Start with it.
func test_the_host_starts_once_a_showing() -> void:
	watch_signals(_screen)
	var start: Button = _screen.get_node("%Start")
	_screen.show_room(_roster(["Ada", "Bea"], 0))
	assert_false(start.disabled)
	start.pressed.emit()
	start.pressed.emit()
	assert_signal_emit_count(_screen, "start_requested", 1)
	assert_true(start.disabled, "asked")
	_screen.show_room(_roster(["Ada", "Bea"], 0), "The server is busy: try again in a moment.")
	assert_false(start.disabled, "and back after the answer")
	assert_true((_screen.get_node("%Note") as Label).visible)
	start.pressed.emit()
	assert_signal_emit_count(_screen, "start_requested", 2)


func test_only_the_host_starts() -> void:
	watch_signals(_screen)
	var start: Button = _screen.get_node("%Start")
	_screen.show_room(_roster(["Ada", "Bea"], 1))
	assert_true(start.disabled, "dead for a guest")
	assert_eq((_screen.get_node("%Status") as Label).text, "Waiting for the host to start.")
	start.pressed.emit()
	_screen.show_room(_roster(["Ada", "Bea"], 0, true))
	assert_true(start.disabled, "and while a match is on")
	start.pressed.emit()
	assert_signal_emit_count(_screen, "start_requested", 0)


## A name as long as a hostile server may send moves nothing: the seats' column keeps its
## width, and the name shows as far as it fits.
func test_a_long_name_is_cut_short() -> void:
	_screen.show_room(_roster(["Ada", "Bea"], 1))
	await wait_process_frames(2)
	var panel := _screen.panel()
	var width := panel.size.x
	var long := "W".repeat(255)
	_screen.show_room(_roster(["Ada", long, "[b]x[/b] %s {0}"], 1))
	await wait_process_frames(2)
	assert_eq(panel.size.x, width, "the panel keeps its width")
	var name: Label = _screen.get_node("%Rows").get_child(1).get_child(1)
	assert_eq(name.text, long, "the name as sent")
	assert_true(name.clip_text)
	assert_eq(name.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	for row: Node in _screen.get_node("%Rows").get_children():
		for label: Node in row.get_children():
			assert_eq(label.get_class(), "Label", "plain text, never markup")
	assert_string_contains(_lines()[2], "[b]x[/b] %s {0}", "shown as typed")


## A roster listing more players than the match has seats shows the seats alone.
func test_no_more_lines_than_seats() -> void:
	var names: Array[String] = []
	for index in 40:
		names.append("P%d" % index)
	_screen.show_room(_roster(names, 0))
	assert_eq(_lines().size(), SEATS)


func test_cancel_leaves() -> void:
	watch_signals(_screen)
	_screen.show_room(_roster(["Ada"], 0))
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	get_viewport().push_input(cancel)
	(_screen.get_node("%Leave") as Button).pressed.emit()
	assert_signal_emit_count(_screen, "leave_requested", 2)
