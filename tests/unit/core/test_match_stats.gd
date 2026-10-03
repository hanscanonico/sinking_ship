extends GutTest
## MatchStats reads the events and nothing else (D5): the results screen's numbers
## must be the same whether a sim is still around or not.

const RunMatch := preload("res://tools/run_match.gd")

const COLD := PlayerState.Cause.COLD


func test_knockout_credit_uses_the_event_field() -> void:
	# Seat 1 landed the last shove on seat 2, but the exit credits seat 0: the
	# credit is the sim's call, carried on the event, never re-derived here.
	var stats := MatchStats.new(3, 0)
	(
		stats
		. add(
			[
				SimEvent.shove_landed(10, 0, 2),
				SimEvent.shove_landed(40, 1, 2),
				SimEvent.seat_out(60, 2, 3, COLD, 0),
			]
		)
	)
	assert_eq(stats.seats[0].knockouts, 1, "credited where the event says")
	assert_eq(stats.seats[1].knockouts, 0, "a later shove is not a credit")

	stats.add([SimEvent.seat_out(90, 1, 2, COLD, -1)])
	assert_eq(stats.seats[0].knockouts, 1, "no credit, no knock-out")
	assert_eq(stats.seats[1].knockouts, 0)
	assert_eq(stats.seats[2].knockouts, 0)

	# End to end: a shove through the railing's gap, credited by the sim.
	var sim := SimFixtures.sim(2)
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	SimFixtures.place(sim, 0, Vector3(gap.x, 0.0, 0.2), 90.0)
	SimFixtures.place(sim, 1, Vector3(gap.x, 0.0, 1.3), -90.0)
	var played := MatchStats.new(2, 0)
	for tick in 300:
		var buttons := InputFrame.SHOVE if tick == 0 else 0
		played.add(SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, buttons)}))
		if sim.is_over():
			break
	assert_true(sim.state.seats[1].is_out(), "the shove put seat 1 in the sea")
	assert_eq(played.seats[0].knockouts, 1)
	assert_eq(played.seats[0].shoves_landed, 1)
	assert_eq(played.seats[1].place, 2)
	assert_eq(played.seats[0].place, 1)


func test_stats_come_from_events_only() -> void:
	# No sim at all: a three-seat match told only as events, the brawl starting
	# on tick 90.
	var told := MatchStats.new(3, 90)
	(
		told
		. add(
			[
				SimEvent.shove_landed(100, 1, 2),
				SimEvent.shove_landed(100, 1, 0),
				SimEvent.shove_landed(130, 1, 2),
				SimEvent.seat_out(150, 2, 3, COLD, 1),
			]
		)
	)
	assert_false(told.ended)
	assert_eq(told.seats[1].dry_ticks, -1, "still dry, match running")
	assert_eq(told.seats[1].place, 0)
	told.add([SimEvent.seat_out(200, 0, 2, COLD, -1), SimEvent.match_ended(200, 1)])
	assert_true(told.ended)
	assert_eq(told.winner, 1)
	assert_eq(
		told.to_dict()["seats"],
		[
			{"seat": 0, "place": 2, "dry_ticks": 110, "shoves_landed": 0, "knockouts": 0},
			{"seat": 1, "place": 1, "dry_ticks": 110, "shoves_landed": 2, "knockouts": 1},
			{"seat": 2, "place": 3, "dry_ticks": 60, "shoves_landed": 0, "knockouts": 0},
		],
		"a shove hitting two bodies on one tick counts once"
	)
	var order: Array[int] = []
	for line: MatchStats.SeatStats in told.standings():
		order.append(line.seat)
	assert_eq(order, [1, 0, 2], "standings run best place first")

	# A played match: the stats fed while it ran equal the stats rebuilt from its
	# events alone, they agree with the final snapshot, and the sim's live fields
	# can change under them without moving a number.
	var runner := RunMatch.bots_only(RunMatch.default_config(1701, 6))
	var live := MatchStats.new(6, runner.sim.config.countdown_ticks)
	var events: Array[SimEvent] = []
	while not runner.is_over():
		var stepped := runner.step()
		live.add(stepped)
		events.append_array(stepped)
	var seats: Array = runner.snapshot["seats"]
	for entry: Dictionary in seats:
		var line := live.seats[entry["seat"]]
		assert_eq(line.place, entry["place"], "seat %d's place" % line.seat)
		if entry["out"]:
			var dry: int = entry["out_tick"] - runner.sim.config.countdown_ticks
			assert_eq(line.dry_ticks, dry, "seat %d's time dry" % line.seat)
	var landed := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.SHOVE_LANDED
	)
	assert_gt(landed.size(), 0, "the golden match has shoves in it")
	for player: PlayerState in runner.sim.state.seats:
		player.place = 99
		player.last_hit_by = 3
		player.out_tick = 0
	var rebuilt := MatchStats.new(6, runner.sim.config.countdown_ticks)
	rebuilt.add(events)
	assert_eq(rebuilt.to_dict(), live.to_dict())
	assert_true(rebuilt.ended)
	assert_eq(live.best_of([0, 1, 2, 3, 4, 5]), _best_by_hand(live))


## The best-placed seat by the rule best_of states, worked out longhand.
func _best_by_hand(stats: MatchStats) -> int:
	var best := 0
	for line: MatchStats.SeatStats in stats.seats:
		var top := stats.seats[best]
		if (
			line.knockouts > top.knockouts
			or (line.knockouts == top.knockouts and line.shoves_landed > top.shoves_landed)
		):
			best = line.seat
	return best
