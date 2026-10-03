extends GutTest
## Railings take damage (SH10): a vault over a span costs it vault_damage, and a
## span with no hits left is broken — gone from Surfaces as a failed one is, holding
## nothing. Crates breaking spans are test_props.gd's.

const SHOVE := InputFrame.SHOVE
## Clear of the flat deck's railing gaps on either side.
const RAILED_X := -8.0
## The flat deck's starboard span aft of the gap, which RAILED_X stands by.
const SPAN := 2


func _starboard_edge() -> float:
	return SimFixtures.deck().platforms[0].area.end.y


## Where a body's centre stands when it is pressed against the starboard rail.
func _pinned_z() -> float:
	return _starboard_edge() - SimFixtures.rules().body_radius


## Seat 0 throws one quick shove at seat 1, pinned against the starboard rail at
## RAILED_X, while seat 2 stands well clear; steps until the vault and returns its
## tick's events.
func _vault(sim: MatchSim) -> Array[SimEvent]:
	var rules := SimFixtures.rules()
	var target_z := _pinned_z()
	SimFixtures.place(
		sim, 0, Vector3(RAILED_X, 0.0, target_z - rules.body_radius * 2.0 - 0.3), 90.0
	)
	SimFixtures.place(sim, 1, Vector3(RAILED_X, 0.0, target_z), -90.0)
	SimFixtures.place(sim, 2, Vector3(RAILED_X - 3.0, 0.0, 0.0))
	for tick in Ticks.RATE:
		var buttons := SHOVE if tick == 0 else 0
		var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, buttons, 90.0)})
		if not _of(events, SimEvent.Kind.VAULTED).is_empty():
			return events
	fail_test("seat 1 never vaults")
	return []


## Seat 2 walks to starboard into the span for two seconds.
func _walk_into_the_span(sim: MatchSim) -> PlayerState:
	SimFixtures.step(sim, {2: SimFixtures.frame(2, Vector2.DOWN)}, 2 * Ticks.RATE)
	return sim.state.seats[2]


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


func test_vault_damages_the_span() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(3)
	assert_eq(sim.state.railing_hp.size(), sim.config.ship.railings.size(), "one per span")
	var events := _vault(sim)
	assert_eq(sim.state.railing_hp[SPAN], rules.railing_hp - rules.vault_damage, "one hit off")
	for index in sim.state.railing_hp.size():
		if index != SPAN:
			assert_eq(sim.state.railing_hp[index], rules.railing_hp, "span %d untouched" % index)
	assert_gt(sim.state.railing_hp[SPAN], 0.0, "not broken by one vault")
	assert_true(_of(events, SimEvent.Kind.RAILING_BROKE).is_empty())


func test_broken_span_lets_bodies_fall() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(3)
	sim.state.railing_hp[SPAN] = rules.vault_damage
	var events := _vault(sim)
	var broke := _of(events, SimEvent.Kind.RAILING_BROKE)
	assert_eq(broke.size(), 1, "the last hit breaks it")
	assert_eq([broke[0].railing, broke[0].seat, broke[0].prop], [SPAN, 1, -1], "by seat 1's vault")
	assert_eq(sim.state.railing_hp[SPAN], 0.0)
	assert_eq(sim.state.broken_railings(), PackedInt32Array([SPAN]))
	var at_the_rail := Vector3(RAILED_X - 3.0, 0.0, _pinned_z() + 0.1)
	assert_true(
		sim.surfaces.rail_contacts(at_the_rail, rules.body_radius, 0).is_empty(),
		"Surfaces no longer has the span"
	)
	var walker := _walk_into_the_span(sim)
	assert_gt(walker.pos.z, _starboard_edge(), "walked out where the rail was")
	assert_ne(walker.body, PlayerState.Body.GROUNDED, "and over the edge")
	# Broken stays broken through a snapshot: the rebuilt ship has no span there.
	var resumed := MatchSim.from_snapshot(sim.snapshot(), sim.config)
	assert_true(resumed.surfaces.rail_contacts(at_the_rail, rules.body_radius, 0).is_empty())


func test_unbroken_span_still_holds() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(3)
	_vault(sim)
	assert_gt(sim.state.railing_hp[SPAN], 0.0)
	var walker := _walk_into_the_span(sim)
	assert_eq(walker.body, PlayerState.Body.GROUNDED, "still on deck")
	assert_almost_eq(walker.pos.z, _pinned_z(), 0.0001, "held at the damaged rail")
	assert_eq(
		sim.state.railing_hp[SPAN],
		rules.railing_hp - rules.vault_damage,
		"walking costs it nothing"
	)


## The schedule's failed spans and the match's broken ones are one mask (D7, SH6):
## both gone, and the others standing.
func test_a_failed_span_and_a_broken_one_are_both_gone() -> void:
	var rules := SimFixtures.rules()
	var surfaces := Surfaces.new(SimFixtures.deck())
	var pose := SimFixtures.sim(1).pose()
	pose.broken_railings = PackedInt32Array([0])
	surfaces.honour(pose, PackedInt32Array([SPAN]))
	var radius := rules.body_radius
	# Each a little into its rail.
	var into := _pinned_z() + 0.1
	var port := Vector3(RAILED_X, 0.0, -into)
	var starboard := Vector3(RAILED_X, 0.0, into)
	var aft_of_the_gap := Vector3(10.0, 0.0, into)
	assert_true(surfaces.rail_contacts(port, radius, 0).is_empty(), "the failed span is gone")
	assert_true(surfaces.rail_contacts(starboard, radius, 0).is_empty(), "the broken one too")
	assert_eq(surfaces.rail_contacts(aft_of_the_gap, radius, 0).size(), 1, "the rest stand")
	surfaces.honour(pose)
	assert_eq(
		surfaces.rail_contacts(starboard, radius, 0).size(), 1, "honour holds only what it is told"
	)


## The steamer lays a long side's railing as touching spans no longer than
## tools/gen_steamer.py's RAIL_SECTION, so a break — a crate, or three vaults — opens
## a stretch of a side, never all of it; and touching spans still hold as one rail.
func test_a_steamer_span_is_a_stretch_of_a_side() -> void:
	var layout := SimFixtures.steamer()
	var main_port_aft := 0
	for railing: ShipRailing in layout.railings:
		assert_lte(railing.from.distance_to(railing.to), 3.5, "a span is a stretch")
		var along_port := is_equal_approx(railing.from.y, -5.0) and railing.to.y == railing.from.y
		if along_port and railing.from.x >= -14.0 and railing.to.x <= 3.5:
			main_port_aft += 1
	assert_gt(main_port_aft, 1, "the main deck's 17.5 m aft port side is several spans")
