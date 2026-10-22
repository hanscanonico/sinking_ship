extends GutTest
## A session's tally (SessionTally): points by place from the data's table, spread over
## the seats a match has, summed per seat name over a Play and the rematches after it,
## and started afresh by a new Play, the menu or another seat count.

const NAMES := ["You", "Bot 1", "Bot 2", "Bot 3"]


func test_the_points_table_is_data_and_valid() -> void:
	var points := SessionPoints.load_default()
	assert_not_null(points, "data/match/session_points.tres loads")
	assert_eq(points.problems(), PackedStringArray())
	assert_eq(points.by_place, PackedInt32Array([10, 7, 5, 4, 3, 2, 1, 0]))


func test_a_full_match_reads_the_table_straight() -> void:
	var points := SessionPoints.load_default()
	var full: Array[int] = []
	for place in range(1, 9):
		full.append(points.for_place(place, 8))
	assert_eq(full, [10, 7, 5, 4, 3, 2, 1, 0])


## Fewer seats spread their places over the table: 1st always its top, last always its
## bottom, and never more for a worse place.
func test_fewer_seats_spread_over_the_table() -> void:
	var points := SessionPoints.load_default()
	var by_seats := {}
	for seats: int in [1, 2, 4, 6]:
		var row: Array[int] = []
		for place in range(1, seats + 1):
			row.append(points.for_place(place, seats))
		by_seats[seats] = row
	assert_eq(by_seats[1], [10] as Array[int], "alone, the win is the top")
	assert_eq(by_seats[2], [10, 0] as Array[int])
	assert_eq(by_seats[4], [10, 5, 2, 0] as Array[int])
	assert_eq(by_seats[6], [10, 7, 4, 3, 1, 0] as Array[int])
	assert_eq(points.for_place(0, 4), 0, "a seat never placed earns nothing")


func test_a_bad_table_says_so() -> void:
	var points := SessionPoints.new()
	points.by_place = PackedInt32Array([5, 7, 0])
	assert_eq(points.problems().size(), 1, "a worse place worth more")
	points.by_place = PackedInt32Array([3, -1])
	assert_eq(points.problems().size(), 1, "negative points")
	points.by_place = PackedInt32Array()
	assert_eq(points.problems().size(), 1, "no places")


func test_three_matches_add_up_by_name() -> void:
	var tally := SessionTally.new()
	tally.begin(4, false)
	tally.count(_ended([0, 1, 2, 3]), _names(4))
	tally.begin(4, true)
	tally.count(_ended([2, 0, 1, 3]), _names(4))
	tally.begin(4, true)
	tally.count(_ended([0, 2, 3, 1]), _names(4))
	assert_eq(tally.matches, 3)
	# 4 seats: 10, 5, 2, 0 by place.
	assert_eq(
		_rows(tally),
		[["You", 25, 1], ["Bot 2", 17, 2], ["Bot 1", 7, 3], ["Bot 3", 2, 4]],
		"most points first"
	)


func test_level_points_share_a_rank() -> void:
	var tally := SessionTally.new()
	tally.begin(2, false)
	tally.count(_ended([0, 1]), _names(2))
	tally.begin(2, true)
	tally.count(_ended([1, 0]), _names(2))
	assert_eq(_rows(tally), [["You", 10, 1], ["Bot 1", 10, 1]], "in the order first counted")


func test_a_match_not_ended_counts_nothing() -> void:
	var tally := SessionTally.new()
	tally.begin(2, false)
	tally.count(MatchStats.new(2, 0), _names(2))
	assert_eq(tally.matches, 0)


## A new Play — from the menu, which Game resets the tally on as well — starts afresh.
func test_a_new_play_or_the_menu_starts_a_new_session() -> void:
	var tally := SessionTally.new()
	tally.begin(4, false)
	tally.count(_ended([0, 1, 2, 3]), _names(4))
	tally.begin(4, false)
	assert_eq(tally.matches, 0, "a Play is a new session")
	assert_true(tally.standings().is_empty())
	tally.count(_ended([0, 1, 2, 3]), _names(4))
	tally.reset()
	assert_eq(tally.matches, 0, "the menu ends it")
	assert_true(tally.standings().is_empty())


func test_another_seat_count_starts_a_new_session() -> void:
	var tally := SessionTally.new()
	tally.begin(4, false)
	tally.count(_ended([0, 1, 2, 3]), _names(4))
	tally.begin(2, true)
	assert_eq(tally.matches, 0, "a rematch of other seats starts afresh")
	tally.count(_ended([1, 0]), _names(2))
	assert_eq(_rows(tally), [["Bot 1", 10, 1], ["You", 0, 2]])
	tally.count(_ended([0, 1, 2, 3]), _names(4))
	assert_eq(tally.matches, 1, "a match of other seats counted is a new session too")


## Stats of a match ended with [param order]'s seats placed 1st, 2nd, … in turn.
func _ended(order: Array) -> MatchStats:
	var stats := MatchStats.new(order.size(), 0)
	var events: Array[SimEvent] = []
	for at in range(order.size() - 1, 0, -1):
		events.append(SimEvent.seat_out(90 + at, order[at], at + 1, PlayerState.Cause.COLD, -1))
	events.append(SimEvent.match_ended(120, order[0]))
	stats.add(events)
	return stats


func _names(seats: int) -> PackedStringArray:
	return PackedStringArray(NAMES.slice(0, seats))


func _rows(tally: SessionTally) -> Array:
	var rows := []
	for line: SessionTally.Line in tally.standings():
		rows.append([line.name, line.points, line.rank])
	return rows
