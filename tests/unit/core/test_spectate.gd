extends GutTest
## SpectateOrder is the single picker of whose eyes the view is in (D13): it reads
## who is dry from the snapshot and who is doing best from MatchStats.

const COLD := PlayerState.Cause.COLD
const LOCAL := 0


## A snapshot of [param seats] seats with [param out] already in the sea.
func _snapshot(seats: int, out: Array[int]) -> Dictionary:
	var entries: Array[Dictionary] = []
	for seat in seats:
		entries.append({"seat": seat, "out": out.has(seat)})
	return {"seats": entries}


func test_spectates_the_best_placed_survivor() -> void:
	var stats := MatchStats.new(4, 0)
	var order := SpectateOrder.new(LOCAL, stats)
	assert_eq(order.target(_snapshot(4, [])), LOCAL, "your own eyes while you are dry")

	# Seat 2 put the local seat out, and seat 3 has landed a shove: seat 2 leads.
	(
		stats
		. add(
			[
				SimEvent.shove_landed(10, 3, 1),
				SimEvent.shove_landed(20, 2, LOCAL),
				SimEvent.seat_out(30, LOCAL, 4, COLD, 2),
			]
		)
	)
	assert_eq(order.target(_snapshot(4, [LOCAL])), 2, "the knock-out leads")

	stats.add([SimEvent.seat_out(50, 2, 3, COLD, 3)])
	assert_eq(order.target(_snapshot(4, [LOCAL, 2])), 3, "its eyes close: the next best")

	stats.add([SimEvent.seat_out(70, 3, 2, COLD, -1), SimEvent.match_ended(70, 1)])
	assert_eq(order.target(_snapshot(4, [LOCAL, 2, 3])), 1, "the last one dry")
	assert_eq(order.target(_snapshot(4, [LOCAL, 1, 2, 3])), 1, "held once nobody is dry")


func test_cycle_skips_seats_that_are_out() -> void:
	var stats := MatchStats.new(5, 0)
	var order := SpectateOrder.new(LOCAL, stats)
	var dry := _snapshot(5, [])
	order.cycle(dry, 1)
	assert_eq(order.target(dry), LOCAL, "no cycling away from your own eyes")

	var two_out := _snapshot(5, [LOCAL, 2])
	assert_eq(order.target(two_out), 1, "no stats yet: the lowest dry seat")
	order.cycle(two_out, 1)
	assert_eq(order.target(two_out), 3, "next skips seat 2")
	order.cycle(two_out, 1)
	order.cycle(two_out, 1)
	assert_eq(order.target(two_out), 1, "and wraps round past the local seat")
	order.cycle(two_out, -1)
	assert_eq(order.target(two_out), 4, "previous wraps the other way")

	var four_out := _snapshot(5, [LOCAL, 2, 4])
	assert_eq(order.target(four_out), 1, "the picked seat went out: back to the best")
	order.cycle(four_out, -1)
	assert_eq(order.target(four_out), 3)


func test_a_replay_cycles_every_seat_out_or_not() -> void:
	assert_eq(SpectateOrder.every(0, 1, 5), 1)
	assert_eq(SpectateOrder.every(4, 1, 5), 0, "round past the last")
	assert_eq(SpectateOrder.every(0, -1, 5), 4, "and back round")
	assert_eq(SpectateOrder.every(2, 1, 1), 0, "one seat only")


## A watcher has no seat of its own (-1): it starts in the best-placed dry seat's eyes
## and keeps to them as the standings change, until that seat is out or Q / E moves it.
func test_a_watcher_keeps_to_the_seat_it_is_in() -> void:
	var stats := MatchStats.new(4, 0)
	var order := SpectateOrder.new(-1, stats)
	var dry := _snapshot(4, [])
	assert_eq(order.target(dry), 0, "no stats yet: the lowest dry seat")
	stats.add([SimEvent.shove_landed(10, 2, 1)])
	assert_eq(order.target(dry), 0, "seat 2 leads now, but the view stays put")
	order.cycle(dry, 1)
	assert_eq(order.target(dry), 1, "every seat cycles: none is the watcher's own")
	order.cycle(dry, -1)
	order.cycle(dry, -1)
	assert_eq(order.target(dry), 3, "and round the other way")

	stats.add([SimEvent.seat_out(30, 3, 4, COLD, 2)])
	var three_out := _snapshot(4, [3])
	assert_eq(order.target(three_out), 2, "its seat out: the best-placed survivor")
	stats.add([SimEvent.shove_landed(40, 1, 0), SimEvent.shove_landed(41, 1, 0)])
	assert_eq(order.target(three_out), 2, "and it keeps to that one too")
