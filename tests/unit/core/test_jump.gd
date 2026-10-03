extends GutTest
## The jump (SH4b, D8): a press from the ground lifts the feet jump_height and
## gravity brings them down; railings still hold a jumper, a deck overhead stops
## one, and a shove still reaches one level enough to touch.

const JUMP := InputFrame.JUMP
const SHOVE := InputFrame.SHOVE
const BRACE := InputFrame.BRACE
const GROUNDED := PlayerState.Body.GROUNDED
const AIRBORNE := PlayerState.Body.AIRBORNE
## Longer than any jump is in the air.
const FLIGHT_LIMIT := 2 * Ticks.RATE


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func _planar(vector: Vector3) -> Vector2:
	return Vector2(vector.x, vector.z)


## A steamer that never moves, its lower deck dry.
func _steamer_sim(seats: int) -> MatchSim:
	return SimFixtures.sim(seats, SimFixtures.calm(), SimFixtures.steamer())


## The flat deck with a crate 1.2 m high on it, a perch a body on the deck can
## still shove someone standing on: x 1…3, z −1…1.
func _crate_sim(seats: int) -> MatchSim:
	var layout := SimFixtures.deck().duplicate()
	var crate := ShipBlocker.new()
	crate.area = Rect2(1.0, -1.0, 2.0, 2.0)
	crate.top = 1.2
	var blockers: Array[ShipBlocker] = [crate]
	layout.blockers = blockers
	return SimFixtures.sim(seats, null, layout)


## Steps [param sim], [param seat] sending [param frame] every tick and the others
## repeating theirs, until that seat is back on the ground; returns the highest its
## feet went and the ticks it was up, counting the press.
func _fly(sim: MatchSim, seat: int, frame: InputFrame) -> Dictionary:
	var player := sim.state.seats[seat]
	var apex := player.pos.y
	var ticks := 0
	var press := InputFrame.new(seat, 0, frame.move, frame.buttons | JUMP, frame.look_yaw)
	SimFixtures.step(sim, {seat: press})
	while player.body == AIRBORNE and ticks < FLIGHT_LIMIT:
		ticks += 1
		apex = maxf(apex, player.pos.y)
		SimFixtures.step(sim, {seat: frame})
	return {"apex": apex, "ticks": ticks}


func _landings(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


func test_a_jump_rises_to_its_height_and_lands() -> void:
	var rules := _rules()
	# Level, and tilted past the grip angle: the apex is jump_height in ship space
	# either way, measured from the deck the feet left.
	for lean: Vector2 in [Vector2.ZERO, Vector2(12.0, 8.0)]:
		var sim := SimFixtures.sim(1, SimFixtures.tilted(lean.x, lean.y))
		SimFixtures.place(sim, 0, Vector3.ZERO)
		var player := sim.state.seats[0]
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)})
		assert_eq(player.body, AIRBORNE, "lean %s: off the ground on the press" % lean)
		assert_gt(player.vel.y, 0.0, "lean %s: rising" % lean)
		var flight := _fly_on(sim, 0)
		assert_almost_eq(flight["apex"], rules.jump_height, 0.02, "lean %s: its height" % lean)
		assert_eq(player.body, GROUNDED, "lean %s: down again" % lean)
		assert_eq(player.surface, 0)
		assert_eq(player.pos.y, 0.0)
		assert_eq(player.vel.y, 0.0)
		assert_between(flight["ticks"], 15, 21, "lean %s: about 0.6 s in the air" % lean)


## Steps [param seat], already in the air, with an empty frame until it lands.
func _fly_on(sim: MatchSim, seat: int) -> Dictionary:
	var player := sim.state.seats[seat]
	var apex := player.pos.y
	var ticks := 1
	while player.body == AIRBORNE and ticks < FLIGHT_LIMIT:
		SimFixtures.step(sim, {seat: SimFixtures.frame(seat)})
		apex = maxf(apex, player.pos.y)
		ticks += 1
	return {"apex": apex, "ticks": ticks}


func test_holding_jump_does_not_hop_again() -> void:
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var player := sim.state.seats[0]
	var take_offs := 0
	var held := SimFixtures.frame(0, Vector2.ZERO, JUMP)
	for _tick in 3 * Ticks.RATE:
		var before := player.body
		SimFixtures.step(sim, {0: held})
		if before == GROUNDED and player.body == AIRBORNE:
			take_offs += 1
	assert_eq(take_offs, 1, "held for three seconds: one jump")
	assert_eq(player.body, GROUNDED)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	SimFixtures.step(sim, {0: held})
	assert_eq(player.body, AIRBORNE, "let go and pressed again: another")


func test_a_jump_does_not_clear_a_railing() -> void:
	var rules := _rules()
	# Running at the starboard rail, clear of its gap, and jumping at every distance
	# from it a run-up can: the feet never top the rail, so it holds every one.
	var edge := SimFixtures.deck().platforms[0].area.end.y
	for ticks_before in range(0, 12):
		var sim := SimFixtures.sim(1)
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, edge - 2.5), 90.0)
		var run := SimFixtures.frame(0, Vector2.DOWN)
		SimFixtures.step(sim, {0: run}, ticks_before)
		var flight := _fly(sim, 0, run)
		var player := sim.state.seats[0]
		assert_lt(flight["apex"], rules.railing_height, "below the rail's top")
		assert_false(player.is_out(), "jumping %d ticks in: still aboard" % ticks_before)
		assert_eq(player.body, GROUNDED, "jumping %d ticks in: back on deck" % ticks_before)
		assert_lt(player.pos.z, edge, "jumping %d ticks in: inside the rail" % ticks_before)


func test_a_jump_reaches_the_hatch_top() -> void:
	var rules := _rules()
	# The steamer's hatch is 0.8 m high, x 4…8 on the main deck: a walk is stopped
	# at its side, and a jump taken a stride short of it lands on top.
	var walked := _steamer_sim(1)
	SimFixtures.place(walked, 0, Vector3(2.0, 0.0, 0.0), 0.0)
	SimFixtures.step(walked, {0: SimFixtures.frame(0, Vector2.RIGHT)}, Ticks.RATE)
	assert_almost_eq(walked.state.seats[0].pos.x, 4.0 - rules.body_radius, 0.001, "held")
	assert_eq(walked.state.seats[0].pos.y, 0.0)

	var sim := _steamer_sim(1)
	SimFixtures.place(sim, 0, Vector3(2.0, 0.0, 0.0), 0.0)
	var run := SimFixtures.frame(0, Vector2.RIGHT)
	var player := sim.state.seats[0]
	while player.pos.x < 3.0:
		SimFixtures.step(sim, {0: run})
	_fly(sim, 0, run)
	assert_eq(player.body, GROUNDED)
	assert_almost_eq(player.pos.y, 0.8, 0.0001, "on the hatch top")
	assert_between(player.pos.x, 4.0, 8.0)
	assert_eq(player.stagger_ticks, 0, "a jump up costs nothing on landing")


func test_a_jump_under_a_low_deck_stops_at_the_ceiling() -> void:
	var rules := _rules()
	# The wheelhouse: the boat deck at 2.5 m under the bridge at 4.7 m, 2.2 m of
	# headroom; a full jump would put the head 0.4 m into the bridge.
	var sim := _steamer_sim(1)
	SimFixtures.place(sim, 0, Vector3(-2.5, 2.5, 0.0))
	var player := sim.state.seats[0]
	var flight := _fly(sim, 0, SimFixtures.frame(0))
	var ceiling := 4.7 - rules.body_height
	assert_almost_eq(flight["apex"], ceiling, 0.0001, "the head stops at the bridge")
	assert_lt(flight["apex"] - 2.5, rules.jump_height, "short of a full jump")
	assert_eq(player.body, GROUNDED)
	assert_eq(player.pos.y, 2.5, "back on the wheelhouse floor")
	assert_eq(player.stagger_ticks, 0)

	# Under the main deck, the lower deck's 2.6 m leaves a full jump its room.
	var below := _steamer_sim(1)
	SimFixtures.place(below, 0, Vector3(-9.0, -2.6, 0.0))
	var low := _fly(below, 0, SimFixtures.frame(0))
	assert_lte(low["apex"], -rules.body_height, "the head never through the main deck")
	assert_almost_eq(below.state.seats[0].pos.y, -2.6, 0.0001)

	# In a doorway the lintel, 2.1 m up, is the ceiling.
	var doorway := _steamer_sim(1)
	SimFixtures.place(doorway, 0, Vector3(-2.5, 2.5, 1.4))
	var door := _fly(doorway, 0, SimFixtures.frame(0))
	assert_almost_eq(door["apex"], 2.5 + 2.1 - rules.body_height, 0.0001, "under the lintel")


func test_an_exhausted_seat_cannot_jump() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var player := sim.state.seats[0]
	player.stamina = rules.stamina_max * 0.5
	player.exhausted = true
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)})
	assert_eq(player.body, GROUNDED, "exhausted: no jump")

	var short := SimFixtures.sim(1)
	SimFixtures.place(short, 0, Vector3.ZERO)
	short.state.seats[0].stamina = rules.jump_cost * 0.5
	SimFixtures.step(short, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)})
	assert_eq(short.state.seats[0].body, GROUNDED, "short of jump_cost: no jump")


func test_a_jump_costs_stamina() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var player := sim.state.seats[0]
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)})
	assert_almost_eq(player.stamina, rules.stamina_max - rules.jump_cost, 0.0001)
	assert_gt(player.stamina_wait, 0, "spending restarts the wait")
	assert_false(player.exhausted)
	# Jump after jump, each pressed as the last lands, until one is refused: about
	# stamina_max / jump_cost of them, and a few more the regen buys back.
	var jumps := 1
	while player.body == AIRBORNE and jumps < 30:
		_fly_on(sim, 0)
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)})
		if player.body == AIRBORNE:
			jumps += 1
	var from_full := int(rules.stamina_max / rules.jump_cost)
	assert_between(jumps, from_full, from_full + 3, "hop after hop runs out")
	assert_eq(player.body, GROUNDED, "the last press is refused")
	assert_lt(player.stamina, rules.jump_cost)


func test_no_jump_while_bracing_charging_or_staggered() -> void:
	var rules := _rules()
	var press := SimFixtures.frame(0, Vector2.ZERO, JUMP)
	# Bracing: rooted until the brace is let go.
	var braced := SimFixtures.sim(1)
	SimFixtures.place(braced, 0, Vector3.ZERO)
	SimFixtures.step(braced, {0: SimFixtures.frame(0, Vector2.ZERO, BRACE)}, 3)
	assert_true(braced.state.seats[0].bracing)
	SimFixtures.step(braced, {0: SimFixtures.frame(0, Vector2.ZERO, BRACE | JUMP)})
	assert_eq(braced.state.seats[0].body, GROUNDED, "bracing: no jump")
	SimFixtures.step(braced, {0: SimFixtures.frame(0)})
	SimFixtures.step(braced, {0: press})
	assert_eq(braced.state.seats[0].body, AIRBORNE, "the brace let go: a jump")

	# Charging, winding up, or in the shove's recovery.
	var charging := SimFixtures.sim(1)
	SimFixtures.place(charging, 0, Vector3.ZERO)
	var charge := SimFixtures.frame(0, Vector2.ZERO, SHOVE)
	SimFixtures.step(charging, {0: charge}, Ticks.from_seconds(rules.charge_threshold) + 1)
	assert_eq(charging.state.seats[0].action, PlayerState.Action.CHARGE)
	SimFixtures.step(charging, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE | JUMP)})
	assert_eq(charging.state.seats[0].body, GROUNDED, "charging: no jump")

	var together := SimFixtures.sim(1)
	SimFixtures.place(together, 0, Vector3.ZERO)
	SimFixtures.step(together, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE | JUMP)})
	assert_eq(together.state.seats[0].action, PlayerState.Action.WINDUP, "the shove wins")
	assert_eq(together.state.seats[0].body, GROUNDED, "winding up: no jump")

	var whiffed := SimFixtures.sim(1)
	SimFixtures.place(whiffed, 0, Vector3.ZERO)
	SimFixtures.step(whiffed, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)})
	while whiffed.state.seats[0].action != PlayerState.Action.RECOVERY:
		SimFixtures.step(whiffed, {0: SimFixtures.frame(0)})
	SimFixtures.step(whiffed, {0: press})
	assert_eq(whiffed.state.seats[0].body, GROUNDED, "a whiff's recovery: no jump")

	# Staggered: the press is not read at all.
	var staggered := SimFixtures.sim(1)
	SimFixtures.place(staggered, 0, Vector3.ZERO)
	staggered.state.seats[0].stagger_ticks = 5
	SimFixtures.step(staggered, {0: press}, 4)
	assert_eq(staggered.state.seats[0].body, GROUNDED, "staggered: no jump")

	# Frozen in a hit-stop: a press held through it counts as it ends.
	var frozen := SimFixtures.sim(1)
	SimFixtures.place(frozen, 0, Vector3.ZERO)
	frozen.state.seats[0].hitstop = 3
	SimFixtures.step(frozen, {0: press}, 3)
	assert_eq(frozen.state.seats[0].body, GROUNDED, "frozen: no jump")
	SimFixtures.step(frozen, {0: press})
	assert_eq(frozen.state.seats[0].body, AIRBORNE, "pressed in the stop, held after: a jump")

	# In the air: a press does nothing, and is not saved for the landing.
	var falling := SimFixtures.sim(1)
	SimFixtures.place(falling, 0, Vector3.ZERO)
	SimFixtures.step(falling, {0: press})
	SimFixtures.step(falling, {0: SimFixtures.frame(0)})
	var vel_y := falling.state.seats[0].vel.y
	SimFixtures.step(falling, {0: press})
	assert_lt(falling.state.seats[0].vel.y, vel_y, "no second jump in the air")
	_fly_on(falling, 0)
	assert_eq(falling.state.seats[0].body, GROUNDED, "and lands, held or not")


func test_a_shove_misses_feet_above_its_reach_and_hits_a_low_jumper() -> void:
	var rules := _rules()
	# A shove reaches a body whose feet are within body_height of its shover's, up
	# or down (ShoveResolver.lands). From the deck a jump never leaves that: the
	# jumper is hit. From a 1.2 m crate it does: the jumper rises out of reach.
	for perch: float in [0.0, 1.2]:
		var sim := _crate_sim(2) if perch > 0.0 else SimFixtures.sim(2)
		SimFixtures.place(sim, 0, Vector3(0.3, 0.0, 0.0), 0.0)
		SimFixtures.place(sim, 1, Vector3(1.5, perch, 0.0), 180.0)
		var shover := sim.state.seats[0]
		var jumper := sim.state.seats[1]
		SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, JUMP)})
		SimFixtures.step(
			sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE), 1: SimFixtures.frame(1)}
		)
		var hits: Array[SimEvent] = []
		var reached: Array[float] = []
		for _tick in 10:
			var events := SimFixtures.step(sim, {0: SimFixtures.frame(0)})
			hits.append_array(_landings(events, SimEvent.Kind.SHOVE_LANDED))
			if shover.action == PlayerState.Action.ACTIVE:
				reached.append(jumper.pos.y - shover.pos.y)
		assert_false(reached.is_empty(), "perch %s: the shove was thrown" % perch)
		if perch > 0.0:
			assert_true(hits.is_empty(), "jumping off the crate: out of reach")
			assert_gte(reached.min(), rules.body_height, "the feet were above it all window")
		else:
			assert_eq(hits.size(), 1, "jumping off the deck: hit in the air")
			assert_lt(reached.max(), rules.body_height)

	# Standing on the crate, not jumping, the same shove lands.
	var standing := _crate_sim(2)
	SimFixtures.place(standing, 0, Vector3(0.3, 0.0, 0.0), 0.0)
	SimFixtures.place(standing, 1, Vector3(1.5, 1.2, 0.0), 180.0)
	SimFixtures.step(standing, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)})
	var landed := _landings(
		SimFixtures.step(standing, {0: SimFixtures.frame(0)}, 6), SimEvent.Kind.SHOVE_LANDED
	)
	assert_eq(landed.size(), 1, "a body on the crate is in reach")


func test_a_jumper_shoved_in_the_air_flies_with_full_knockback() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(-0.6, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(0.6, 0.0, 0.0), 180.0)
	var jumper := sim.state.seats[1]
	# The jumper steers back toward the shover all the while: a staggered body has
	# no say in the air.
	var back := SimFixtures.frame(1, Vector2.LEFT)
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.LEFT, JUMP)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE), 1: back})
	var hit := false
	while not hit:
		var events := SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: back})
		hit = not _landings(events, SimEvent.Kind.SHOVE_LANDED).is_empty()
	assert_eq(jumper.body, AIRBORNE, "hit in the air")
	assert_almost_eq(SimFixtures.sent(jumper).x, rules.knockback, 0.0001, "the full knockback")
	while jumper.is_frozen():
		SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: back})
	var flown := 0
	while jumper.body == AIRBORNE:
		assert_almost_eq(_planar(jumper.vel).x, rules.knockback, 0.0001, "no friction in the air")
		SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: back})
		flown += 1
	assert_gt(flown, 3, "it flew a while")
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: back})
	assert_lt(_planar(jumper.vel).length(), rules.knockback, "the deck's friction takes over")


func test_jumping_on_a_steep_deck_does_not_escape_the_slide() -> void:
	var rules := _rules()
	# Past the grip angle an idle body slides; one that jumps from beside it is pulled
	# downhill all the way through the air with no friction, so it comes down
	# farther downhill and faster than the one that stayed.
	var sim := SimFixtures.sim(2, SimFixtures.tilted(rules.grip_angle_deg + 8.0, 0.0))
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, -2.0))
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 2.0))
	var downhill := _planar(sim.pose().ship_gravity(rules.gravity)).normalized()
	var jumper := sim.state.seats[1]
	var slider := sim.state.seats[0]
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, JUMP)})
	while jumper.body == AIRBORNE:
		SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)})
	var slid := _planar(slider.pos - Vector3(0.0, 0.0, -2.0)).dot(downhill)
	var flew := _planar(jumper.pos - Vector3(0.0, 0.0, 2.0)).dot(downhill)
	assert_gt(slid, 0.0, "the idle body slid")
	assert_gt(flew, slid, "the jumper came down farther downhill")
	assert_gt(_planar(jumper.vel).dot(downhill), _planar(slider.vel).dot(downhill), "and faster")


func test_a_jump_landing_does_not_stagger() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var events: Array[SimEvent] = []
	events.append_array(SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, JUMP)}))
	while sim.state.seats[0].body == AIRBORNE:
		events.append_array(SimFixtures.step(sim, {0: SimFixtures.frame(0)}))
	var landed := _landings(events, SimEvent.Kind.LANDED)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0].stagger_ticks, 0, "a jump in place lands clean")
	assert_eq(sim.state.seats[0].stagger_ticks, 0)

	# Off the hatch, a jump costs what stepping off would: the drop below its take-off.
	var off := _steamer_sim(1)
	SimFixtures.place(off, 0, Vector3(5.0, 0.8, 0.0), 0.0)
	var run := SimFixtures.frame(0, Vector2.RIGHT)
	while off.state.seats[0].pos.x < 7.2:
		SimFixtures.step(off, {0: run})
	var down: Array[SimEvent] = []
	down.append_array(SimFixtures.step(off, {0: SimFixtures.frame(0, Vector2.RIGHT, JUMP)}))
	while off.state.seats[0].body == AIRBORNE:
		down.append_array(SimFixtures.step(off, {0: run}))
	var thud := _landings(down, SimEvent.Kind.LANDED)
	assert_eq(thud.size(), 1)
	assert_eq(off.state.seats[0].pos.y, 0.0, "down on the main deck")
	assert_eq(thud[0].stagger_ticks, Ticks.from_seconds(0.8 * rules.fall_stagger_per_m))


func test_air_control_is_limited() -> void:
	var rules := _rules()
	# From a standstill, pushing forward the whole jump steers it a little — never
	# the walk a body on the deck reaches in the same time.
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, -2.0))
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 2.0))
	var forward := Vector2.RIGHT
	var jumper := sim.state.seats[0]
	var walker := sim.state.seats[1]
	var press := {0: SimFixtures.frame(0, forward, JUMP), 1: SimFixtures.frame(1, forward)}
	SimFixtures.step(sim, press)
	var airborne := 1
	while jumper.body == AIRBORNE:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, forward), 1: SimFixtures.frame(1, forward)})
		airborne += 1
	# Steered every tick it was up, the take-off's and the landing's too.
	var steered := _planar(jumper.vel).x
	var most := rules.ground_accel * rules.air_control * Ticks.to_seconds(airborne)
	assert_gt(steered, 0.0, "the air steers")
	assert_lte(steered, most + 0.0001, "at air_control of ground_accel")
	assert_lt(steered, rules.walk_speed * 0.5, "far from a walk")
	assert_almost_eq(_planar(walker.vel).x, rules.walk_speed, 0.0001, "the walker is at full pace")

	# Running and letting go in the air: the speed is kept, not braked.
	var runner := SimFixtures.sim(1)
	SimFixtures.place(runner, 0, Vector3(-8.0, 0.0, 0.0))
	SimFixtures.step(runner, {0: SimFixtures.frame(0, forward)}, Ticks.RATE)
	SimFixtures.step(runner, {0: SimFixtures.frame(0, forward, JUMP)})
	var running := runner.state.seats[0]
	while running.body == AIRBORNE:
		SimFixtures.step(runner, {0: SimFixtures.frame(0)})
		if running.body == AIRBORNE:
			assert_almost_eq(_planar(running.vel).x, rules.walk_speed, 0.0001, "kept")


func test_the_rules_refuse_a_jump_over_a_railing() -> void:
	assert_eq(_rules().problems(), PackedStringArray(), "the shipped numbers hold")
	var high: BrawlRules = _rules().duplicate()
	high.jump_height = high.railing_height
	assert_eq(
		high.problems(),
		PackedStringArray(["brawl rules: jump_height must be below railing_height"])
	)
	var floaty: BrawlRules = _rules().duplicate()
	floaty.air_control = 1.5
	assert_eq(floaty.problems(), PackedStringArray(["brawl rules: air_control must be within 0…1"]))
	var dear: BrawlRules = _rules().duplicate()
	dear.jump_cost = dear.stamina_max + 1.0
	assert_eq(
		dear.problems(), PackedStringArray(["brawl rules: jump_cost must not exceed stamina_max"])
	)


func test_a_jump_continues_exactly_from_any_snapshot() -> void:
	# On the steamer: seat 0 jumps under the bridge, its head stopped by it, twice;
	# seat 1 runs out of the saloon and jumps in its doorway, under the lintel, and
	# comes down against the hatch's side; seat 2 jumps in place on the main deck. A
	# sim rebuilt from a snapshot taken rising, at the apex or falling continues as
	# the first did.
	var sim := _steamer_sim(3)
	SimFixtures.place(sim, 0, Vector3(-2.5, 2.5, 0.0))
	SimFixtures.place(sim, 1, Vector3(2.0, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 2, Vector3(-8.0, 0.0, 3.0))
	var script := func(tick: int) -> Array[InputFrame]:
		var jump := JUMP if tick == 0 or tick == Ticks.RATE else 0
		var lead := JUMP if tick == 4 else 0
		return [
			InputFrame.new(0, tick, Vector2i.ZERO, jump, 0),
			InputFrame.new(1, tick, InputFrame.quantize(Vector2.RIGHT), lead, 0),
			InputFrame.new(2, tick, Vector2i.ZERO, JUMP if tick == 2 else 0, 0),
		]
	var played: Array[Dictionary] = [sim.snapshot()]
	for tick in 2 * Ticks.RATE:
		sim.step(script.call(tick))
		played.append(sim.snapshot())
	var covered := {"rising": false, "apex": false, "falling": false}
	for start in range(played.size() - 1):
		var seen := false
		for entry: Dictionary in played[start]["seats"]:
			if not entry["jumped"]:
				continue
			var rising: float = (entry["vel"] as Vector3).y
			var moment := "rising" if rising > 0.0 else "apex" if rising == 0.0 else "falling"
			covered[moment] = true
			seen = true
		if seen and not _continues(played, start, sim.config, script):
			return
	for moment: String in covered:
		assert_true(covered[moment], "resumed from a jump %s" % moment)
	var doorway := 0.0
	for snapshot: Dictionary in played:
		doorway = maxf(doorway, snapshot["seats"][1]["pos"].y)
	assert_almost_eq(doorway, 2.1 - _rules().body_height, 0.0001, "seat 1 met the lintel")


## Rebuilds a sim from [param snapshots] at [param start] and steps it a second on,
## fed [param frames_at]; false, failing the test, when it leaves the recording.
func _continues(
	snapshots: Array[Dictionary], start: int, config: MatchConfig, frames_at: Callable
) -> bool:
	var resumed := MatchSim.from_snapshot(snapshots[start], config)
	for offset in range(1, mini(Ticks.RATE, snapshots.size() - 1 - start) + 1):
		resumed.step(frames_at.call(start + offset - 1))
		if resumed.snapshot() != snapshots[start + offset]:
			fail_test("continuation from tick %d diverged at tick %d" % [start, start + offset - 1])
			return false
	return true
