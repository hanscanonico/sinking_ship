extends GutTest
## Bots on a ship that turns over (§5b.3, D10, SH32): their walk graph is rebuilt from
## the floors of the frame the match stands in, and they read the snapshot and the pose
## in it.


func test_the_walk_graph_is_rebuilt_from_the_floors_of_the_moment() -> void:
	var config := SimFixtures.config(4, SimFixtures.tilted(0.0, 90.0), 1, SimFixtures.steamer())
	var floors := BotInputSource.floors_of(config)
	var deck := floors.graph(Faces.Up.DECK)
	var walls := floors.graph(Faces.Up.PORT)
	assert_ne(walls, deck, "her side's floors are another graph")
	assert_eq(floors.graph(Faces.Up.PORT), walls, "built once a frame, not each asking")
	assert_gt(walls.zone_count(), 0, "her port-facing faces make zones")
	# A body on the starboard hull wall of her lower deck is in one of them.
	var feet := Faces.to_frame(Faces.Up.PORT) * Vector3(-8.0, -1.0, 4.7)
	var surface := walls.surfaces().under(feet, config.rules.step_height)
	assert_ne(surface, Surfaces.NONE, "the wall is a floor")
	assert_ne(walls.zone_at(feet, surface), WalkGraph.NONE, "in a zone")


func test_bots_play_on_her_side() -> void:
	# She lies on her starboard side from the first tick: the bots fall onto her faces
	# turned up and go on reading and pressing in that frame.
	var config := SimFixtures.config(4, SimFixtures.tilted(0.0, 90.0), 3, SimFixtures.steamer())
	var runner := MatchRunner.new(
		MatchSim.create(config), BotInputSource.fill(config, load(SimFixtures.NORMAL_BOT))
	)
	var moved := false
	for _tick in 6 * Ticks.RATE:
		runner.step()
		for seat in config.seats:
			moved = moved or runner.sim.state.seats[seat].last_move != Vector2i.ZERO
	assert_eq(runner.sim.state.up, Faces.Up.PORT, "the match stands on her port-facing faces")
	assert_true(moved, "the bots press on")
	var standing := 0
	for player: PlayerState in runner.sim.state.seats:
		if player.body == PlayerState.Body.GROUNDED:
			standing += 1
	assert_gt(standing, 0, "on their feet on her faces")


func test_a_bot_reads_crates_still_aboard_off_her_decks() -> void:
	# A match jumped to a moment she lies on her side has its crates where they were
	# stowed until its first tick breaks them loose (MatchJump, Hazards): the faces she
	# turns up have no crates, and the bot reading that snapshot thinks on.
	var config := SimFixtures.config(4, SimFixtures.tilted(0.0, 90.0), 5, SimFixtures.steamer())
	var tick := config.countdown_ticks + Ticks.RATE
	var snapshot := MatchJump.snapshot(config, tick)
	assert_ne(snapshot["up"], Faces.Up.DECK, "she lies on a face but her decks")
	var aboard := 0
	for crate: PropState in PropState.from_snapshot(snapshot):
		if not crate.is_lost():
			aboard += 1
	assert_gt(aboard, 0, "her crates still aboard")
	var bot := BotInputSource.new(0, load(SimFixtures.NORMAL_BOT), config)
	bot.observe(snapshot, config.schedule().pose_at(tick))
	var frame := bot.next_frame(tick)
	assert_not_null(frame, "it decides")
	assert_eq(frame.seat, 0)


func test_a_bots_frame_has_the_watertight_doors_its_pose_shows() -> void:
	# Upside down, each of the steamer's watertight doors stands in the bots' frame as the
	# pose they read has it (D10), as in the match's own: shut, a walk through its doorway
	# is blocked; given way, or not yet shut, it is open — every surface keeping its
	# number.
	var config := SimFixtures.config(4, SimFixtures.tilted(0.0, 180.0), 1, SimFixtures.steamer())
	var floors := BotInputSource.floors_of(config)
	var sim := MatchSim.create(config)
	var turn := Faces.to_frame(Faces.Up.KEEL)
	var step := config.rules.step_height
	var doors := 0
	for door: ShipOpening in config.ship.structure.openings:
		if not door.shuts_at_hit:
			continue
		doors += 1
		var across := Vector3.ZERO
		across[door.facing()] = 0.5
		var head := Vector3(0.0, door.size.y * 0.5, 0.0)
		var from := turn * (door.centre + head - across)
		var to := turn * (door.centre + head + across)
		var tall := door.size.y * 0.5
		var counts := {}
		# [doors_shut, opened, blocked].
		for row: Array in [[0.0, 0, false], [1.0, 0, true], [1.0, 2, false]]:
			var told := "%s shut %s, opened %s" % [door.name, row[0], row[1]]
			var pose := sim.pose()
			pose.doors_shut[door.name] = row[0]
			pose.opened[door.name] = row[1]
			var framed := floors.framed(pose, Faces.Up.KEEL)
			var bots := floors.graph(Faces.Up.KEEL, framed).surfaces()
			assert_eq(bots.blocked(from, to, tall, step), row[2], "the bots' frame: " + told)
			var match_frame := sim.faces.surfaces(Faces.Up.KEEL, framed)
			assert_eq(match_frame.blocked(from, to, tall, step), row[2], "the match's: " + told)
			counts[bots.count()] = true
		assert_eq(counts.size(), 1, "%s: no surface's number moves with its leaf" % door.name)
	assert_gt(doors, 0, "she has watertight doors")
