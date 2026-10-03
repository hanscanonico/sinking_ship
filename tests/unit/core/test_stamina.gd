extends GutTest

const SEED := 1701


func test_regen_waits_for_the_delay() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var player := sim.state.seats[0]
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.BRACE)}, Ticks.RATE)
	var spent := player.stamina
	assert_lt(spent, rules.stamina_max, "a second of bracing spent some")
	var delay := Ticks.from_seconds(rules.stamina_regen_delay)
	for tick in delay:
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
		assert_eq(player.stamina, spent, "tick %d of the delay: nothing back" % tick)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_almost_eq(
		player.stamina, spent + rules.stamina_regen * Ticks.SECONDS_PER_TICK, 0.0001, "then back"
	)
	var more := Ticks.RATE / 2
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, more)
	assert_almost_eq(
		player.stamina,
		spent + rules.stamina_regen * Ticks.SECONDS_PER_TICK * (more + 1),
		0.001,
		"at stamina_regen per second"
	)


func test_stamina_stays_in_range() -> void:
	var rules := SimFixtures.rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(-1.0, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(1.0, 0.0, 0.0), 180.0)
	var low := INF
	var high := -INF
	var buttons: Array[int] = [0, InputFrame.SHOVE, InputFrame.BRACE]
	# Seeded holds of one to eight seconds — braces, charges, rests — for two minutes.
	var held := [0, 0]
	var until := [0, 0]
	for tick in 120 * Ticks.RATE:
		var row := {}
		for seat in 2:
			if tick >= until[seat]:
				held[seat] = buttons[rng.randi_range(0, buttons.size() - 1)]
				until[seat] = tick + rng.randi_range(Ticks.RATE, 8 * Ticks.RATE)
			row[seat] = SimFixtures.frame(seat, Vector2.ZERO, held[seat])
		SimFixtures.step(sim, row)
		for player: PlayerState in sim.state.seats:
			if player.is_out():
				continue
			low = minf(low, player.stamina)
			high = maxf(high, player.stamina)
	# Both ends were reached, and neither was passed.
	assert_eq(low, 0.0, "it ran dry, and never below")
	assert_eq(high, rules.stamina_max, "it filled up, and never above")
