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
