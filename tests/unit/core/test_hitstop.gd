extends GutTest

const SHOVE := InputFrame.SHOVE
const BRACE := InputFrame.BRACE


func _rules() -> BrawlRules:
	return SimFixtures.rules()


## The gap between two bodies' centres that leaves 0.3 m of reach between them.
func _apart() -> float:
	return _rules().body_radius * 2.0 + 0.3


## Seat 0 at the origin facing the bow, seat 1 in reach in front of it facing back,
## and any other seats well clear.
func _duel(seats: int = 2) -> MatchSim:
	var sim := SimFixtures.sim(seats)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(_apart(), 0.0, 0.0), 180.0)
	for seat in range(2, seats):
		SimFixtures.place(sim, seat, Vector3(-8.0, 0.0, 2.0 * seat - 6.0), 0.0)
	return sim


## Seat 0 taps a quick shove, [param others] sending their frames all along;
## steps through the tick it lands on, and returns that tick's landings.
func _land(sim: MatchSim, others: Dictionary = {}) -> Array[SimEvent]:
	var press := others.duplicate()
	press[0] = SimFixtures.frame(0, Vector2.ZERO, SHOVE)
	SimFixtures.step(sim, press)
	var after := others.duplicate()
	after[0] = SimFixtures.frame(0)
	SimFixtures.step(sim, after, Ticks.from_seconds(_rules().shove_windup) - 1)
	var landings := _landings(SimFixtures.step(sim, after))
	assert_false(landings.is_empty(), "the shove lands")
	return landings


func _landings(events: Array[SimEvent]) -> Array[SimEvent]:
	return events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.SHOVE_LANDED
	)


func test_hitstop_freezes_both_and_resumes() -> void:
	var rules := _rules()
	var stop := Ticks.from_seconds(rules.hitstop)
	assert_eq(stop, 3, "a quick shove stops for about a tenth of a second")
	var sim := _duel()
	_land(sim)
	var shover := sim.state.seats[0]
	var target := sim.state.seats[1]
	assert_eq([shover.hitstop, target.hitstop], [stop, stop], "both frozen")
	var shover_at := shover.pos
	var target_at := target.pos
	var action_ticks := shover.action_ticks
	var stagger := target.stagger_ticks
	for frozen in stop:
		assert_true(shover.is_frozen() and target.is_frozen(), "frozen tick %d" % frozen)
		# The shover pushes on with the stick, and still nothing moves.
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT), 1: SimFixtures.frame(1)})
		assert_eq(shover.pos, shover_at, "the shover holds still")
		assert_eq(target.pos, target_at, "the target holds still")
		assert_eq(shover.action, PlayerState.Action.ACTIVE)
		assert_eq(shover.action_ticks, action_ticks, "its shove waits")
		assert_eq(target.stagger_ticks, stagger, "its stagger waits")
	assert_false(shover.is_frozen() or target.is_frozen(), "the stop is over")
	assert_almost_eq(target.vel.x, rules.knockback, 0.0001, "the knockback, held back till now")
	assert_almost_eq(shover.vel.x, -rules.recoil, 0.0001, "and the recoil")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_gt(target.pos.x, target_at.x, "the target slides away")
	assert_lt(shover.pos.x, shover_at.x, "the shover rocks back")
	assert_eq(shover.action_ticks, action_ticks + 1, "its shove goes on where it stopped")
	assert_eq(target.stagger_ticks, stagger - 1)


func test_hitstop_does_not_freeze_others() -> void:
	var stop := Ticks.from_seconds(_rules().hitstop)
	var sim := _duel(4)
	var walker := sim.state.seats[2]
	var shover := sim.state.seats[3]
	var walk := SimFixtures.frame(2, Vector2.RIGHT)
	_land(sim, {2: walk, 3: SimFixtures.frame(3)})
	var frames := {2: walk, 3: SimFixtures.frame(3, Vector2.ZERO, SHOVE)}
	for frozen in stop:
		assert_true(sim.state.seats[0].is_frozen() and sim.state.seats[1].is_frozen())
		var walked_from := walker.pos
		SimFixtures.step(sim, frames)
		assert_gt(walker.pos.x, walked_from.x, "frozen tick %d: the walker walks on" % frozen)
		assert_false(walker.is_frozen() or shover.is_frozen())
	assert_eq(shover.action, PlayerState.Action.WINDUP, "a third seat's press is read")
	assert_eq(shover.action_ticks, stop - 1, "and its windup runs on")


func test_hitstop_survives_snapshot_continuation() -> void:
	var rules := _rules()
	# Seat 0 lands a quick shove on seat 1; seat 2, behind seat 1, lands one on it
	# while it is frozen; seat 3 braces against seat 4's quick shove, a short stop.
	var sim := SimFixtures.sim(5)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(_apart(), 0.0, 0.0), 180.0)
	SimFixtures.place(sim, 2, Vector3(2.0 * _apart(), 0.0, 0.0), 180.0)
	SimFixtures.place(sim, 3, Vector3(-8.0, 0.0, 2.0), 0.0)
	SimFixtures.place(sim, 4, Vector3(-8.0 + _apart(), 0.0, 2.0), 180.0)
	var script := func(tick: int) -> Array[InputFrame]:
		return [
			SimFixtures.frame(0, Vector2.ZERO, SHOVE if tick == 0 else 0, 0.0),
			SimFixtures.frame(1, Vector2.ZERO, 0, 180.0),
			SimFixtures.frame(2, Vector2.ZERO, SHOVE if tick == 1 else 0, 180.0),
			SimFixtures.frame(3, Vector2.ZERO, BRACE, 0.0),
			SimFixtures.frame(4, Vector2.ZERO, SHOVE if tick == 0 else 0, 180.0),
		]
	var played: Array[Dictionary] = [sim.snapshot()]
	for tick in Ticks.RATE:
		sim.step(script.call(tick))
		played.append(sim.snapshot())
	var frozen_starts := 0
	var stops := {}
	for start in range(played.size() - 1):
		var frozen := false
		for entry: Dictionary in played[start]["seats"]:
			if entry["hitstop"] > 0:
				frozen = true
				stops[entry["hitstop"]] = true
		if not frozen:
			continue
		frozen_starts += 1
		var resumed := MatchSim.from_snapshot(played[start], sim.config)
		for offset in range(1, mini(Ticks.RATE, played.size() - 1 - start) + 1):
			resumed.step(script.call(start + offset - 1))
			if resumed.snapshot() != played[start + offset]:
				fail_test("continuation from tick %d diverged at tick %d" % [start, offset])
				return
	assert_gt(frozen_starts, 0, "resumed from inside a stop")
	assert_true(stops.has(Ticks.from_seconds(rules.hitstop_braced)), "a braced stop was resumed")
	# Both fields are in the digest, not only the snapshot.
	var entry: Dictionary = played[4]["seats"][1]
	assert_gt(entry["hitstop"], 0)
	var changed := played[4].duplicate(true)
	changed["seats"][1]["hitstop"] = entry["hitstop"] + 1
	assert_ne(SnapshotDigest.quantized(changed), SnapshotDigest.quantized(played[4]))
	changed = played[4].duplicate(true)
	changed["seats"][1]["held_vel"] = (entry["held_vel"] as Vector3) + Vector3(0.1, 0.0, 0.0)
	assert_ne(SnapshotDigest.quantized(changed), SnapshotDigest.quantized(played[4]))


func test_a_frozen_seat_still_turns_its_look() -> void:
	var sim := _duel()
	_land(sim)
	var shover := sim.state.seats[0]
	var aimed := shover.shove_facing
	for look_deg: float in [90.0, -135.0]:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, 0, look_deg)})
		assert_true(shover.is_frozen())
		var look := InputFrame.yaw_angle(InputFrame.quantize_yaw(deg_to_rad(look_deg)))
		assert_eq(shover.facing, look, "frozen, the look turns it to %s°" % look_deg)
		assert_eq(shover.pos, Vector3.ZERO, "where it stands")
	assert_eq(shover.shove_facing, aimed, "the shove keeps its aim")


func test_meters_are_frozen_during_the_stop() -> void:
	var rules := _rules()
	var stop := Ticks.from_seconds(rules.hitstop_braced)
	# Seat 1 braces facing the shove, so it spends stamina the whole time; seat 0,
	# low on stamina and done waiting, would be regaining it.
	var sim := _duel()
	var brace := SimFixtures.frame(1, Vector2.ZERO, BRACE)
	var landings := _land(sim, {1: brace})
	assert_eq(landings.size(), 1)
	var shover := sim.state.seats[0]
	var target := sim.state.seats[1]
	assert_true(target.bracing, "the brace took it")
	assert_eq(target.hitstop, stop)
	shover.stamina = rules.stamina_max * 0.5
	shover.stamina_wait = 0
	var meters := func() -> Array:
		return [shover.stamina, shover.stamina_wait, target.stamina, target.stamina_wait]
	var held: Array = meters.call()
	assert_gt(target.stamina_wait, 0, "the brace has been spending")
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: brace}, stop)
	assert_eq(meters.call(), held, "no drain, no regen, no wait counted")
	assert_true(target.bracing, "and the brace holds")
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: brace})
	assert_gt(shover.stamina, held[0], "the shover's stamina comes back")
	assert_lt(target.stamina, held[2], "the brace spends again")


func test_a_press_during_the_stop_counts_as_it_ends() -> void:
	var stop := Ticks.from_seconds(_rules().hitstop_braced)
	# Seat 1, braced, is not staggered: only the stop stands between its press and
	# a windup. Held through the stop, the press is read the tick the stop is over.
	var sim := _duel()
	var brace := SimFixtures.frame(1, Vector2.ZERO, BRACE)
	_land(sim, {1: brace})
	var target := sim.state.seats[1]
	assert_false(target.is_staggered())
	var press := SimFixtures.frame(1, Vector2.ZERO, SHOVE)
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: press}, stop)
	assert_eq(target.action, PlayerState.Action.IDLE, "nothing moves on inside the stop")
	assert_false(target.is_frozen())
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: press})
	assert_eq(target.action, PlayerState.Action.WINDUP, "pressed in the stop, held after: read")
	assert_eq(target.action_ticks, 0, "on the first tick after it")

	# Pressed and let go inside the stop, it never happened.
	var tapped := _duel()
	_land(tapped, {1: brace})
	var tapper := tapped.state.seats[1]
	SimFixtures.step(tapped, {0: SimFixtures.frame(0), 1: press})
	SimFixtures.step(tapped, {0: SimFixtures.frame(0), 1: brace}, stop)
	assert_eq(tapper.action, PlayerState.Action.IDLE, "a tap inside the stop: nothing")
	assert_true(tapper.bracing, "and the brace it never let go of holds")


func test_a_third_seat_hitting_a_frozen_seat_lands_and_the_longer_stop_wins() -> void:
	var rules := _rules()
	var quick := Ticks.from_seconds(rules.hitstop)
	# Seat 2 stands behind seat 1 and taps one tick after seat 0: its shove lands on
	# seat 1 while seat 0's stop holds it.
	var sim := _duel(3)
	SimFixtures.place(sim, 2, Vector3(2.0 * _apart(), 0.0, 0.0), 180.0)
	var target := sim.state.seats[1]
	var frames := {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE), 2: SimFixtures.frame(2)}
	SimFixtures.step(sim, frames)
	frames = {0: SimFixtures.frame(0), 2: SimFixtures.frame(2, Vector2.ZERO, SHOVE)}
	SimFixtures.step(sim, frames)
	frames[2] = SimFixtures.frame(2)
	SimFixtures.step(sim, frames, Ticks.from_seconds(rules.shove_windup) - 2)
	assert_eq(_landings(SimFixtures.step(sim, frames)).size(), 1, "seat 0's lands")
	assert_eq(target.hitstop, quick)
	var landings := _landings(SimFixtures.step(sim, frames))
	assert_eq(landings.size(), 1, "seat 2's lands on the frozen seat")
	assert_eq([landings[0].seat, landings[0].target], [2, 1])
	assert_eq(target.hitstop, quick, "a fresh stop outlasts the one left")
	assert_eq(sim.state.seats[0].hitstop, quick - 1, "seat 0's own stop runs on")
	assert_eq(target.last_hit_by, 2)
	assert_almost_eq(
		SimFixtures.sent(target).x,
		-rules.knockback * rules.restagger_mult,
		0.0001,
		"the new hit sends it back, a combo on a staggered body"
	)
	SimFixtures.step(sim, frames, quick)
	assert_false(target.is_frozen())
	assert_almost_eq(target.vel.x, -rules.knockback * rules.restagger_mult, 0.0001)

	# A stop with more left than a new hit's keeps it: a full charge, then a tap.
	var full := Ticks.from_seconds(rules.charge_full)
	var windup := Ticks.from_seconds(rules.shove_windup)
	var long := _duel(3)
	SimFixtures.place(long, 2, Vector3(2.0 * _apart(), 0.0, 0.0), 180.0)
	var charged_target := long.state.seats[1]
	var tap_at := full + 1 - windup
	for tick in full + 2:
		var hold := SHOVE if tick < full else 0
		var tap := SHOVE if tick == tap_at else 0
		(
			SimFixtures
			. step(
				long,
				{
					0: SimFixtures.frame(0, Vector2.ZERO, hold),
					2: SimFixtures.frame(2, Vector2.ZERO, tap),
				}
			)
		)
	assert_eq(long.state.seats[2].hitstop, quick, "the tap landed on the frozen seat")
	assert_eq(
		charged_target.hitstop,
		Ticks.from_seconds(rules.hitstop_charged) - 1,
		"the charge's longer stop is kept"
	)


func test_a_charged_hit_stops_longer_than_a_quick_one() -> void:
	var rules := _rules()
	var quick := Ticks.from_seconds(rules.hitstop)
	var charged := Ticks.from_seconds(rules.hitstop_charged)
	var braced := Ticks.from_seconds(rules.hitstop_braced)
	assert_gt(charged, quick)
	assert_lt(braced, quick)
	var sim := _duel()
	_land(sim)
	assert_eq(sim.state.seats[1].hitstop, quick, "a quick shove")

	var full := _duel()
	var hold := {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)}
	SimFixtures.step(full, hold, Ticks.from_seconds(rules.charge_full))
	assert_eq(_landings(SimFixtures.step(full, {0: SimFixtures.frame(0)})).size(), 1)
	assert_eq(
		[full.state.seats[0].hitstop, full.state.seats[1].hitstop],
		[charged, charged],
		"a full charge stops both longer"
	)

	var clang := _duel()
	_land(clang, {1: SimFixtures.frame(1, Vector2.ZERO, BRACE)})
	assert_eq(
		[clang.state.seats[0].hitstop, clang.state.seats[1].hitstop],
		[braced, braced],
		"a braced hit, briefly"
	)


func test_recoil_is_applied_once_when_a_shove_lands_on_two_bodies() -> void:
	var rules := _rules()
	# Two bodies 35° either side of the look: outside autoaim, so the shove goes
	# straight ahead, and inside its cone, so it lands on both.
	var sim := SimFixtures.sim(3)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	for seat_angle: Array in [[1, 35.0], [2, -35.0]]:
		var along := Vector2.from_angle(deg_to_rad(seat_angle[1])) * (_apart() - 0.1)
		SimFixtures.place(sim, seat_angle[0], Vector3(along.x, 0.0, along.y), 180.0)
	var landings := _land(sim)
	assert_eq(landings.size(), 2, "one shove, two bodies")
	var shover := sim.state.seats[0]
	assert_almost_eq(SimFixtures.sent(shover).length(), rules.recoil, 0.0001, "rocked back once")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, shover.hitstop)
	assert_almost_eq(Vector2(shover.vel.x, shover.vel.z).length(), rules.recoil, 0.0001)
