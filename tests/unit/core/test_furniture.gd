extends GutTest
## Furniture among her props (PropKind, Hazards): a dining table and a chair are crates
## of kinds of their own — lifted by the water only at a draft of their own and riding
## that deep, afloat aboard rather than lost, giving way to a body walking into them, a
## chair harmless and with no lid — and no shove sends a prop faster than itself.

const SHOVE := InputFrame.SHOVE


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## The sea from the flat deck's edge rising [param metres] over it in [param seconds],
## then held.
func _rising(metres: float, seconds: float) -> SinkScenario:
	var edge := SimFixtures.deck().freeboard
	return SimFixtures.scenario([[0.0, edge, 0.0, 0.0], [seconds, edge + metres, 0.0, 0.0]])


## The water over [param point] as [param sim]'s last step had it.
func _water(sim: MatchSim, point: Vector3) -> float:
	return sim.schedule.pose_at(sim.state.tick - 1).water_height(point)


## The flat deck carrying [param props], with a roof [param roof] metres over the deck
## from x -2 to 2 across her beam — none when it is not given: test data.
func _laid(props: Array[ShipProp], roof := -1.0) -> ShipLayout:
	var layout := SimFixtures.crated(props)
	if roof >= 0.0:
		layout.platforms = layout.platforms.duplicate()
		var over := ShipPlatform.new()
		over.name = &"roof"
		over.area = Rect2(-2.0, -4.0, 4.0, 8.0)
		over.height = roof
		layout.platforms.append(over)
	return layout


## A match on [param layout] under [param sinking], its one seat standing dry on the roof
## (_laid) [param roof] metres up, so the match goes on however deep the deck floods.
func _kept_dry(sinking: SinkScenario, layout: ShipLayout, roof: float) -> MatchSim:
	var sim := SimFixtures.sim(1, sinking, layout)
	SimFixtures.place(sim, 0, Vector3(1.5, roof, 3.5))
	return sim


## How fast prop [param prop] of [param sim] slides at its fastest over [param ticks]
## ticks from seat 0 pressing Shove for one of them and letting go.
func _shoved(sim: MatchSim, prop: int, ticks: int) -> float:
	var fastest := 0.0
	for tick in ticks:
		var buttons := SHOVE if tick == 0 else 0
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, buttons)})
		var vel := sim.state.props[prop].vel
		fastest = maxf(fastest, Vector2(vel.x, vel.z).length())
	return fastest


func test_a_table_stands_in_the_water_until_it_floats() -> void:
	var at := Vector3(-8.0, 0.0, 0.0)
	var props: Array[ShipProp] = [SimFixtures.table(at)]
	var sim := _kept_dry(_rising(1.2, 12.0), _laid(props, 2.5), 2.5)
	var table := sim.state.props[0]
	var draft := PropKind.named(&"dining_table").draft
	assert_gt(draft, _rules().wade_depth, "a table rides deeper than cargo is lifted at")
	SimFixtures.step(sim, {}, Ticks.from_seconds(5.0))
	assert_between(_water(sim, at), _rules().wade_depth, draft, "deep enough to lift cargo")
	assert_eq(table.body, PropState.Body.GROUNDED, "the table still stands")
	assert_eq(table.pos.y, 0.0)
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(2.5))
	assert_eq(table.body, PropState.Body.FLOATING, "lifted once its draft is under water")
	assert_eq(_of(events, SimEvent.Kind.PROP_AFLOAT).size(), 1)
	assert_almost_eq(table.pos.y, _water(sim, at) - draft, 0.0001, "riding its draft deep")


func test_furniture_afloat_rides_pressed_under_a_roof_where_cargo_is_lost() -> void:
	var props: Array[ShipProp] = [
		SimFixtures.table(Vector3(0.0, 0.0, -1.5)), SimFixtures.crate(Vector3(0.0, 0.0, 1.5))
	]
	var roof := 1.2
	var sim := _kept_dry(_rising(1.1, 6.0), _laid(props, roof), roof)
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(7.0))
	assert_almost_eq(_water(sim, Vector3.ZERO), 1.1, 0.0001)
	var table := sim.state.props[0]
	var crate := sim.state.props[1]
	assert_eq(crate.body, PropState.Body.LOST, "cargo is lost as its lid meets the roof")
	assert_eq(table.body, PropState.Body.FLOATING, "a table is kept afloat")
	var height := PropKind.named(&"dining_table").height
	assert_almost_eq(table.pos.y, roof - height, 0.0001, "pressed under the roof")
	var lost := _of(events, SimEvent.Kind.PROP_LOST)
	assert_eq(lost.size(), 1)
	assert_eq(lost[0].prop, 1)


func test_furniture_falling_into_the_water_comes_down_afloat_where_cargo_is_lost() -> void:
	var props: Array[ShipProp] = [
		SimFixtures.chair(Vector3(-4.0, 0.0, 0.0)), SimFixtures.crate(Vector3(4.0, 0.0, 0.0))
	]
	var sim := _kept_dry(_rising(0.8, 1.0), _laid(props, 2.5), 2.5)
	SimFixtures.step(sim, {}, Ticks.from_seconds(2.0))
	for crate: PropState in sim.state.props:
		crate.body = PropState.Body.AIRBORNE
		crate.pos.y = 3.0
		crate.vel = Vector3.ZERO
		crate.surface = Surfaces.NONE
	SimFixtures.step(sim, {}, Ticks.from_seconds(1.5))
	var chair := sim.state.props[0]
	assert_eq(chair.body, PropState.Body.FLOATING, "the chair comes down afloat")
	var draft := PropKind.named(&"dining_chair").draft
	assert_almost_eq(chair.pos.y, _water(sim, chair.pos) - draft, 0.0001)
	assert_eq(sim.state.props[1].body, PropState.Body.LOST, "the crate goes into the sea")


func test_a_walker_pushes_a_chair_before_it_and_leans_on_cargo() -> void:
	var chair: Array[ShipProp] = [SimFixtures.chair(Vector3(0.0, 0.0, 0.0))]
	var pushing := SimFixtures.sim(1, null, _laid(chair))
	SimFixtures.place(pushing, 0, Vector3(-1.0, 0.0, 0.0))
	SimFixtures.step(pushing, {0: SimFixtures.frame(0, Vector2(1.0, 0.0))}, Ticks.RATE)
	var pushed := pushing.state.props[0]
	assert_gt(pushed.pos.x, 2.0, "the chair goes on before the body")
	assert_gt(pushing.state.seats[0].pos.x, 1.0, "and the body after it")
	assert_almost_eq(pushed.pos.z, 0.0, 0.0001, "straight on")

	var crate: Array[ShipProp] = [SimFixtures.crate(Vector3(0.0, 0.0, 0.0))]
	var leaning := SimFixtures.sim(1, null, _laid(crate))
	SimFixtures.place(leaning, 0, Vector3(-1.0, 0.0, 0.0))
	SimFixtures.step(leaning, {0: SimFixtures.frame(0, Vector2(1.0, 0.0))}, Ticks.RATE)
	assert_eq(leaning.state.props[0].pos, Vector3.ZERO, "a laden crate does not give to a walk")
	var reach := leaning.config.ship.props[0].radius + _rules().body_radius
	assert_almost_eq(leaning.state.seats[0].pos.x, -reach, 0.01, "the body leans on it")


func test_a_shove_sends_a_light_prop_no_faster_than_itself() -> void:
	var chair: Array[ShipProp] = [SimFixtures.chair(Vector3(0.9, 0.0, 0.0))]
	var sim := SimFixtures.sim(1, null, _laid(chair))
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var fastest := _shoved(sim, 0, Ticks.RATE)
	var knockback := _rules().knockback
	var light := _rules().body_mass / sim.config.ship.props[0].mass
	assert_gt(light, 1.0, "lighter than a body: by the masses alone it would fly off faster")
	assert_lte(fastest, knockback + 0.0001, "never faster than the shove")
	assert_gt(fastest, knockback * 0.8, "but sent at about its speed")

	var crate: Array[ShipProp] = [SimFixtures.crate(Vector3(1.0, 0.0, 0.0))]
	var heavy := SimFixtures.sim(1, null, _laid(crate))
	SimFixtures.place(heavy, 0, Vector3.ZERO)
	var sent := _shoved(heavy, 0, Ticks.RATE)
	var weighed := knockback * _rules().body_mass / heavy.config.ship.props[0].mass
	assert_almost_eq(sent, weighed, 0.0001, "a laden crate still by the two masses")


## A platform's goldens hold its matches to the bit: a crate heavier than a body is sent
## as it always was, the shove's speed times the body's mass over the crate's in that
## order — the weight worked out first rounds apart for some shoves.
func test_a_laden_crate_is_sent_to_the_bit_as_before_furniture() -> void:
	var crate: Array[ShipProp] = [SimFixtures.crate(Vector3(1.0, 0.0, 0.0))]
	var sim := SimFixtures.sim(1, null, _laid(crate))
	var hazards := Hazards.new(sim.config, sim.surfaces)
	var body := _rules().body_mass
	var mass := sim.config.ship.props[0].mass
	var speed := _rules().knockback
	assert_gt(mass, body, "laden")
	var direction := Vector2.RIGHT
	for degrees in 360:
		direction = Vector2.RIGHT.rotated(deg_to_rad(degrees + 0.5))
		if direction * speed * body / mass != direction * speed * (body / mass):
			break
	assert_ne(direction * speed * body / mass, direction * speed * (body / mass), "one apart")
	hazards.shove(sim.state, ShoveResolver.Hit.new(0, 1, direction), 1, speed, 0)
	var vel := sim.state.props[0].vel
	assert_eq(Vector2(vel.x, vel.z), direction * speed * body / mass)


func test_a_chair_running_into_a_body_never_staggers_it_as_a_table_does() -> void:
	for kind: StringName in [&"dining_chair", &"dining_table"]:
		var start := Vector3(-1.8, 0.0, 0.0)
		var props: Array[ShipProp] = [
			SimFixtures.chair(start) if kind == &"dining_chair" else SimFixtures.table(start)
		]
		var sim := SimFixtures.sim(1, null, _laid(props))
		SimFixtures.place(sim, 0, Vector3.ZERO)
		sim.state.props[0].vel = Vector3(6.0, 0.0, 0.0)
		var events := SimFixtures.step(sim, {}, Ticks.RATE / 2)
		var body := sim.state.seats[0]
		if kind == &"dining_chair":
			assert_true(_of(events, SimEvent.Kind.PROP_HIT).is_empty(), "a chair hits nobody")
			assert_eq(body.stagger_ticks, 0, "nor staggers anyone")
			assert_gt(body.pos.x, 0.001, "it nudges the body")
		else:
			assert_eq(_of(events, SimEvent.Kind.PROP_HIT).size(), 1, "a table hits the body")


func test_a_table_has_a_lid_to_stand_on_and_a_chair_none() -> void:
	var props: Array[ShipProp] = [
		SimFixtures.table(Vector3(-3.0, 0.0, 0.0)), SimFixtures.chair(Vector3(3.0, 0.0, 0.0))
	]
	var sim := SimFixtures.sim(1, null, _laid(props))
	SimFixtures.place(sim, 0, Vector3(10.0, 0.0, 0.0))
	SimFixtures.step(sim)
	var step := _rules().step_height
	var lids := sim.surfaces.count()
	var table_top := Vector3(-3.0, props[0].height, 0.0)
	assert_eq(sim.surfaces.under(table_top, step), lids, "a body stands on the table")
	assert_eq(sim.surfaces.landing(table_top + Vector3.UP), lids, "and lands on it")
	var chair_top := Vector3(3.0, props[1].height, 0.0)
	assert_eq(
		sim.surfaces.under(chair_top, step), Surfaces.NONE, "nothing to stand on over a chair"
	)
	assert_eq(sim.surfaces.landing(chair_top + Vector3.UP), 0, "a fall goes on to the deck")
	var held := sim.surfaces.obstacle_contacts(Vector3(2.5, 0.0, 0.0), 0.4, 1.7, step)
	assert_eq(held.size(), 1, "but the chair holds a body back")
	assert_eq(held[0].prop, 1)


func test_a_kind_of_furniture_is_checked() -> void:
	var kind := PropKind.new()
	kind.lid = true
	kind.gives_way = true
	assert_true(
		kind.problems().has("prop kind: only a solid one has a lid, gives way or is harmless")
	)
	kind.solid = true
	kind.radius = 0.5
	kind.height = 0.75
	kind.draft = 0.8
	assert_true(
		kind.problems().has("prop kind: a draft is 0 or more, and no deeper than its height")
	)
	kind.draft = 0.6
	assert_eq(kind.problems(), PackedStringArray())
	for name: StringName in [&"dining_table", &"dining_chair"]:
		assert_eq(PropKind.named(name).problems(), PackedStringArray(), String(name))
