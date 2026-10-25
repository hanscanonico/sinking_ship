extends GutTest
## The rules as they stand for one seat (SeatRules, #309): the one place the sim, the bots
## and the HUD ask how high a seat jumps, the slopes it holds and stands on, how much of a
## shove it takes, how high and how fast it climbs out of the sea, and what the prop in its
## hands costs it. With empty hands the brawl rules' own; holding a prop, its kind's carry
## costs, the rest as before.


## Brawl rules whose numbers here are none of brawl.tres's, so that a seat's rules can only
## have come from these.
func _rules() -> BrawlRules:
	var rules: BrawlRules = SimFixtures.rules().duplicate()
	rules.jump_height = 0.8
	rules.grip_angle_deg = 12.0
	rules.stand_limit_deg = 30.0
	rules.climb_reach = 0.5
	rules.ladder_speed = 2.0
	return rules


## A kind a hand may hold that slows its holder to [param walk], lets it brace and charge as
## [param brace] and [param charge] say, and keeps it afloat at [param rate] of the open
## water's cold, or not at all for 0.
func _kind(walk: float, brace: bool, charge: bool, rate: float) -> PropKind:
	var kind := PropKind.new()
	kind.holdable = true
	kind.carry_walk = walk
	kind.carry_brace = brace
	kind.carry_charge = charge
	kind.afloat = rate > 0.0
	kind.sea_cold_rate = rate if rate > 0.0 else 0.5
	return kind


## With nothing in its hands a seat plays by the shared rules: walking at any pace, bracing
## and charging, taking a shove's whole knockback and the sea's cold at the open water's rate.
func test_empty_hands_play_by_the_shared_rules() -> void:
	var seat := SeatRules.of(_rules(), null)
	assert_eq(seat.jump_height, 0.8, "the rules' jump")
	assert_eq(seat.grip_angle_deg, 12.0, "the rules' grip angle")
	assert_eq(seat.stand_limit_deg, 30.0, "the rules' stand limit")
	assert_eq(seat.knockback_share, 1.0, "a shove's whole knockback")
	assert_eq(seat.climb_reach, 0.5, "the rules' climb reach")
	assert_eq(seat.ladder_speed, 2.0, "the rules' ladder speed")
	assert_eq(seat.walk_cap, INF, "no cap on its walk")
	assert_true(seat.may_brace, "it may brace")
	assert_true(seat.may_charge, "it may charge")
	assert_eq(seat.sea_cold_rate, 1.0, "the open water's cold")


## Holding a prop costs what its kind says (#273): its walk capped, a brace and a charge
## only where the kind allows them, and the cold slower only for one that keeps its holder
## afloat. Nothing else about the seat changes.
func test_a_held_prop_costs_what_its_kind_says() -> void:
	var rules := _rules()
	var ring := SeatRules.of(rules, _kind(3.0, false, false, 0.25))
	assert_eq(ring.walk_cap, 3.0, "its kind's walk")
	assert_false(ring.may_brace, "no brace")
	assert_false(ring.may_charge, "no charge")
	assert_eq(ring.sea_cold_rate, 0.25, "kept afloat, the cold slower")
	var other := SeatRules.of(rules, _kind(2.5, true, true, 0.0))
	assert_eq(other.walk_cap, 2.5, "its kind's walk")
	assert_true(other.may_brace, "a brace its kind allows")
	assert_true(other.may_charge, "a charge its kind allows")
	assert_eq(other.sea_cold_rate, 1.0, "not kept afloat: its sea_cold_rate counts for nothing")
	for seat: SeatRules in [ring, other]:
		assert_eq(
			[
				seat.jump_height,
				seat.grip_angle_deg,
				seat.stand_limit_deg,
				seat.knockback_share,
				seat.climb_reach,
				seat.ladder_speed,
			],
			[0.8, 12.0, 30.0, 1.0, 0.5, 2.0],
			"the rest as with empty hands"
		)


## The lifebuoy as her data has it: a seat holding one walks at its carry_walk, neither
## braces nor charges, and drains at its sea_cold_rate — the costs the match has charged it
## since #273.
func test_a_seat_holding_her_lifebuoy_pays_its_carry_costs() -> void:
	var lifebuoy := PropKind.named(&"lifebuoy")
	var seat := SeatRules.of(SimFixtures.rules(), lifebuoy)
	assert_eq(seat.walk_cap, lifebuoy.carry_walk)
	assert_false(seat.may_brace)
	assert_false(seat.may_charge)
	assert_eq(seat.sea_cold_rate, lifebuoy.sea_cold_rate)
	assert_lt(seat.sea_cold_rate, 1.0, "slower than the open water")


## A seat's rules as a snapshot shows them, for those that read a snapshot — the bots, the
## HUD: by the prop it holds there, of those a hand may hold.
func test_a_seats_rules_read_from_a_snapshot_follow_what_it_holds() -> void:
	var layout := SimFixtures.crated([SimFixtures.lifebuoy(Vector3(2.0, 0.0, 0.0))])
	var sim := SimFixtures.sim(2, null, layout)
	var rules := sim.config.rules
	var holdable := GrabReach.holdable_of(layout)
	SimFixtures.hand(sim, 1, 0)
	var snapshot := sim.snapshot()
	var bare := SeatRules.in_snapshot(snapshot, 0, layout, rules, holdable)
	var holding := SeatRules.in_snapshot(snapshot, 1, layout, rules, holdable)
	assert_eq(bare.walk_cap, INF, "seat 0's hands are empty")
	assert_true(bare.may_brace)
	assert_eq(holding.walk_cap, PropKind.named(&"lifebuoy").carry_walk, "seat 1 holds the ring")
	assert_false(holding.may_brace)
	assert_eq(holding.sea_cold_rate, PropKind.named(&"lifebuoy").sea_cold_rate)
