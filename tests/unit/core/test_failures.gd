extends GutTest
## §5b.4 layer 1: things that give way (SinkFailures, §5b.1) — a shut door leaks at one
## head of water across it and gives way at another, landed on by the bake; a hinged door
## opens with the flow at its leak head and holds against it; a collapse is one-way; a
## funnel falls past a limit of its stays along the world's down, and on a roof too light
## for it collapses the roof; the generator's cell flooding puts her lights out, her
## emergency power first; and her generator, stopped by a list, runs again only once she
## is back within its margin. Box barges broad and deep enough that their tanks' water
## barely moves the sea up them, with the attitude and air stages off where the heads are
## the point (§5b.3).

## Heads across a door within this of its marks once the bake lands on them — the
## timeline's millimetre, and its rounding — in metres.
const LANDED := 3e-3
## The door between the two tanks: from the tanks' floor, 2 m tall and 1 m wide; it
## weeps 0.005 m² at 1 m across it and gives way at 3 m.
const LEAK_HEAD := 1.0
const COLLAPSE_HEAD := 3.0
## The tanks' floor.
const FLOOR := -20.0
## The trim the trimming barge's funnel is stayed to, in degrees: a few compartments
## flooded forward pass it.
const TRIM_LIMIT := 2.0


func _sea() -> SeaPhysics:
	return SeaPhysics.load_default()


## The sea's constants with only water moving: she stays level, her cells' air free.
func _flows() -> SeaPhysics:
	var flows: SeaPhysics = SeaPhysics.load_default().duplicate()
	flows.attitude = false
	flows.air = false
	return flows


## Two tanks side by side in a broad barge, the first holed to the sea at its floor and
## filling toward [param sea_over_floor] over it, the second dry behind a shut door that
## swings open into [param opens_toward] — none for a door that slides.
func _tanks(sea_over_floor: float, opens_toward := &"") -> SinkStepper:
	var barge := BoxBarge.new(1000.0, 1000.0, 40.0, sea_over_floor, 10.0)
	barge.section_length = 250.0
	barge.cell(&"wet", Vector3(0.0, FLOOR, 0.0), Vector3(10.0, 0.0, 10.0))
	barge.cell(&"dry", Vector3(10.0, FLOOR, 0.0), Vector3(20.0, 0.0, 10.0))
	barge.hole(&"wet", Vector3(5.0, FLOOR, 5.0), 0.1, true)
	var door := ShipOpening.new()
	door.name = &"door"
	door.kind = ShipOpening.Kind.DOOR
	door.joins = [&"wet", &"dry"]
	door.centre = Vector3(10.0, FLOOR + 1.0, 5.0)
	door.size = Vector3(0.0, 2.0, 1.0)
	door.starts = ShipOpening.Start.SHUT
	door.leak_head = LEAK_HEAD
	door.collapse_head = COLLAPSE_HEAD
	door.leak_area = 0.005
	door.opens_toward = opens_toward
	barge.openings.append(door)
	var structure := barge.structure()
	# Her keel 20 m under the tanks' floor: the sea stands sea_over_floor over it.
	for section: HullSection in structure.sections:
		var outline := section.outline.duplicate()
		for at in outline.size():
			outline[at] = outline[at] + Vector2(0.0, FLOOR - barge.keel())
		section.outline = outline
	structure.keel_y = FLOOR
	structure.waterline_y = FLOOR + sea_over_floor
	structure.mass[0].centre.y = FLOOR + 5.0
	return SinkStepper.new(structure, HitDamage.new(), _flows())


## The first second, in [param bake] run to its end, an event of [param kind] names
## [param named] — a state's own second, as the bake has it; -1 for none.
func _when(bake: SinkBake, kind: SinkTimeline.Kind, named: StringName) -> float:
	for event: SinkTimeline.Event in bake.events():
		if event.kind == kind and event.name == named:
			return event.seconds
	return -1.0


## The head of water across the door in [param bake]'s state at [param seconds]: the wet
## tank's over the dry one's, each no lower than the door's sill.
func _across_at(bake: SinkBake, seconds: float) -> float:
	var state := bake.times().find(seconds)
	assert_ne(state, -1, "a state stands at %s s" % seconds)
	var heads := bake.heads()
	return maxf(heads[state * 2], FLOOR) - maxf(heads[state * 2 + 1], FLOOR)


func test_door_leaks_then_collapses_at_its_heads() -> void:
	# The wet tank fills toward 5 m: the door weeps once 1 m stands across it and gives
	# way at 3 m — the bake landing a step on each.
	var stepper := _tanks(5.0)
	var bake := SinkBake.new(stepper, _flows(), 7200.0)
	bake.run(1 << 62)
	var leaks := _when(bake, SinkTimeline.Kind.LEAKING, &"door")
	var gives := _when(bake, SinkTimeline.Kind.GAVE_WAY, &"door")
	assert_gt(leaks, 0.0, "it leaks")
	assert_gt(gives, leaks, "then gives way")
	assert_almost_eq(_across_at(bake, leaks), LEAK_HEAD, LANDED, "at its leak head")
	assert_almost_eq(_across_at(bake, gives), COLLAPSE_HEAD, LANDED, "at its collapse head")
	var heads := bake.heads()
	var times := bake.times()
	var weeping := 0.0
	for state in times.size():
		if times[state] <= leaks:
			assert_lte(heads[state * 2 + 1], FLOOR + 1e-9, "the dry tank dry till it leaks")
		elif times[state] <= gives:
			weeping = heads[state * 2 + 1] - FLOOR
	assert_gt(weeping, 0.0, "a leak passes water")
	assert_lt(weeping, 0.5, "but little")


func test_hinged_door_opens_with_the_flow_and_holds_against_it() -> void:
	# Two metres stand across the same door, between its two heads: swinging open into
	# the dry tank, the flow opens it at its leak head; swinging into the wet one, the
	# flow presses it shut — it weeps, and holds.
	var with_flow := SinkBake.new(_tanks(2.0, &"dry"), _flows(), 7200.0)
	with_flow.run(1 << 62)
	var opened := _when(with_flow, SinkTimeline.Kind.GAVE_WAY, &"door")
	assert_gt(opened, 0.0, "pushed the way it opens, it opens")
	assert_almost_eq(_across_at(with_flow, opened), LEAK_HEAD, LANDED, "at its leak head")
	var against := SinkBake.new(_tanks(2.0, &"wet"), _flows(), 7200.0)
	against.run(1 << 62)
	assert_gt(_when(against, SinkTimeline.Kind.LEAKING, &"door"), 0.0, "pushed shut, it weeps")
	assert_eq(_when(against, SinkTimeline.Kind.GAVE_WAY, &"door"), -1.0, "and holds")


func test_a_collapse_is_one_way() -> void:
	# Once given way the door stays open: the tanks come level through it, nothing stands
	# across it any more, and it is still open — and it gives way once.
	var stepper := _tanks(5.0)
	var state := stepper.start()
	var door := stepper.opening_names().find(&"door")
	var given := false
	var level := false
	while state.seconds < 7200.0 and not level:
		state = stepper.advance(state)
		if given:
			assert_eq(
				state.opened[door], SinkFailures.GAVE_WAY, "still open at %s s" % state.seconds
			)
		given = state.opened[door] == SinkFailures.GAVE_WAY
		level = given and absf(state.heads[0] - state.heads[1]) < 1e-3
	assert_true(level, "the tanks came level through it")
	var bake := SinkBake.new(_tanks(5.0), _flows(), 7200.0)
	bake.run(1 << 62)
	var times := 0
	for event: SinkTimeline.Event in bake.timeline().events:
		times += 1 if event.kind == SinkTimeline.Kind.GAVE_WAY else 0
	assert_eq(times, 1, "it gives way once")


## A barge 40 m long holed in a room across her forward of amidships, a
## funnel on her deck [param funnel_x] along her stayed to [param trim_deg] of trim, and
## — over her deck, forward of the funnel — a roof too light for it.
func _trimming_barge(funnel_x: float, trim_deg: float) -> ShipStructure:
	var barge := BoxBarge.new(40.0, 10.0, 8.0, 3.0, 3.5)
	barge.section_length = 1.0
	barge.cell(&"bow_room", Vector3(10.0, -3.0, -5.0), Vector3(20.0, 5.0, 5.0))
	barge.hole(&"bow_room", Vector3(15.0, -3.0, 0.0), 0.5, true)
	barge.vent(&"bow_room", Vector3(15.0, 5.0, 0.0), 0.5)
	var funnel := ShipFitting.new()
	funnel.kind = ShipFitting.Kind.FUNNEL
	funnel.name = &"funnel"
	funnel.base = Vector3(funnel_x, 5.0, 0.0)
	funnel.height = 5.0
	funnel.radius = 0.5
	funnel.list_limit_deg = 60.0
	funnel.trim_limit_deg = trim_deg
	funnel.fall_time = 1.0
	var crushes: Array[StringName] = [&"roof"]
	funnel.crushes = crushes
	barge.fittings.append(funnel)
	return barge.structure()


func test_funnel_falls_along_world_down() -> void:
	# Holed forward she goes down by the head: once her trim passes its stays' 2° the
	# funnel falls — toward her bow, the way the world's down runs along her deck then:
	# no other way in her deck's plane drops faster.
	var structure := _trimming_barge(-4.0, TRIM_LIMIT)
	var sea := _sea()
	var bake := SinkBake.new(SinkStepper.new(structure, HitDamage.new(), sea), sea, 3600.0)
	bake.run(1 << 62)
	var falling: SinkTimeline.Event
	for event: SinkTimeline.Event in bake.events():
		if event.kind == SinkTimeline.Kind.FUNNEL_FALLING:
			falling = event
	assert_not_null(falling, "the funnel falls")
	var state := bake.times().find(falling.seconds)
	var rotation := bake.rotations().slice(state * 9, state * 9 + 9)
	var trim := BoxBarge.trim_deg(rotation)
	assert_almost_eq(trim, TRIM_LIMIT, 0.05, "as her trim passes its stays' limit")
	assert_gt(falling.along.x, 0.99, "toward her bow")
	assert_almost_eq(falling.along.length(), 1.0, 1e-5, "a way, in her deck's plane")
	# How fast a way in her deck's plane drops along the world's up: the fall's the most.
	var drop := func(way: Vector2) -> float: return rotation[3] * way.x + rotation[5] * way.y
	for turn: float in [-0.2, 0.2]:
		var other := falling.along.rotated(turn)
		assert_lt(drop.call(falling.along), drop.call(other), "no way drops faster")
	assert_lt(falling.warned, falling.seconds - sea.fall_warning + 1e-6, "creaking first")


func test_funnel_on_the_wheelhouse_collapses_its_roof() -> void:
	# The same fall placed on her decks: the roof forward of the funnel, under its strip,
	# is telegraphed from its creak and collapses on the tick it lands; a funnel standing
	# aft of nothing in its way crushes nothing.
	var layout := ShipLayout.new()
	var platforms: Array[ShipPlatform] = [
		_platform(&"deck", Rect2(-20.0, -5.0, 40.0, 10.0), 5.0),
		_platform(&"roof", Rect2(-2.0, -2.0, 4.0, 4.0), 7.5),
	]
	layout.platforms = platforms
	var outcomes := {}
	for funnel_x: float in [-4.0, 4.0]:
		var structure := _trimming_barge(funnel_x, TRIM_LIMIT)
		layout.structure = structure
		var schedule := _schedule(structure, layout)
		var fall: FunnelFall = schedule.pose_at(1 << 30).falls[0]
		var landed := schedule.pose_at(fall.lands_at)
		var before := schedule.pose_at(fall.lands_at - 1)
		outcomes[funnel_x] = landed.collapsed.duplicate()
		if funnel_x < 0.0:
			assert_true(&"roof" in before.collapsing, "the roof telegraphed as it falls")
			assert_false(&"roof" in before.collapsed, "still standing a tick before")
	assert_eq(outcomes[-4.0], [&"roof"], "the roof in its way collapses as it lands")
	assert_eq(outcomes[4.0], [], "nothing in its way, nothing collapses")


func _platform(platform_name: StringName, area: Rect2, height: float) -> ShipPlatform:
	var platform := ShipPlatform.new()
	platform.name = platform_name
	platform.area = area
	platform.height = height
	return platform


## The schedule of [param structure]'s sinking from no hit at all — holed as her data
## has her — on [param layout]'s decks.
func _schedule(structure: ShipStructure, layout: ShipLayout) -> SinkSchedule:
	var sea := _sea()
	var choice := MustSink.Choice.new()
	choice.hit = IcebergHit.new()
	choice.damage = HitDamage.new()
	choice.timeline = SinkTimeline.bake(SinkStepper.new(structure, choice.damage, sea), sea, 3600.0)
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var stream := RandomNumberGenerator.new()
	stream.seed = 1
	var schedule := SinkSchedule.new(scenario, 3.0, stream, structure, sea, choice)
	schedule.place_falls(layout, 1.0)
	return schedule


## A barge whose generator room is holed: its generator drowned once 0.5 m stands over
## its foot, its emergency power lighting the room for [param minutes].
func _powered_barge(minutes: float) -> ShipStructure:
	var barge := BoxBarge.new(40.0, 10.0, 8.0, 3.0, 3.0)
	barge.section_length = 2.0
	var room := barge.cell(&"engine_room", Vector3(-5.0, -3.0, -5.0), Vector3(5.0, 1.0, 5.0))
	var rooms: Array[StringName] = [&"engine room"]
	room.rooms = rooms
	barge.hole(&"engine_room", Vector3(0.0, -3.0, 0.0), 0.05, true)
	barge.vent(&"engine_room", Vector3(0.0, 1.0, 0.0), 0.5)
	var generator := ShipFitting.new()
	generator.kind = ShipFitting.Kind.GENERATOR
	generator.name = &"generator"
	generator.cell = &"engine_room"
	generator.base = Vector3(0.0, -3.0, 2.0)
	generator.drowns_at = 0.5
	generator.list_limit_deg = 25.0
	generator.trim_limit_deg = 12.0
	generator.recovers_deg = 3.0
	generator.emergency_minutes = minutes
	var lit: Array[StringName] = [&"engine_room"]
	generator.emergency_cells = lit
	barge.fittings.append(generator)
	return barge.structure()


func test_generator_cell_flooding_puts_the_lights_out() -> void:
	# The room floods from its floor: as 0.5 m stands over the generator's foot it stops
	# and the room goes dark — or, with a minute of emergency power, dim for that minute
	# and dark after it.
	var sea := _sea()
	for minutes: float in [0.0, 1.0]:
		var stepper := SinkStepper.new(_powered_barge(minutes), HitDamage.new(), sea)
		var bake := SinkBake.new(stepper, sea, 3600.0)
		bake.run(1 << 62)
		var stopped := _when(bake, SinkTimeline.Kind.POWER_LOST, &"generator")
		var dark := _when(bake, SinkTimeline.Kind.LIGHTS_OUT, &"")
		assert_gt(stopped, 0.0, "%s min: the generator stops" % minutes)
		var state := bake.times().find(stopped)
		var depth := bake.heads()[state] - (-3.0)
		assert_almost_eq(depth, 0.5, LANDED, "%s min: as 0.5 m stands over its foot" % minutes)
		assert_almost_eq(dark - stopped, minutes * 60.0, 1e-3, "%s min: dark after" % minutes)
		var lits := bake.lits()
		assert_eq(lits[state - 1], ShipPower.Power.MAIN, "%s min: lit till then" % minutes)
		var after := ShipPower.Power.EMERGENCY if minutes > 0.0 else ShipPower.Power.DARK
		assert_eq(lits[state], after, "%s min: then on what is left" % minutes)
		assert_eq(lits[lits.size() - 1], ShipPower.Power.DARK, "%s min: and dark" % minutes)


func test_power_has_hysteresis() -> void:
	# Past 25° of list her generator stops; at 23°, within its limit but not its 3°
	# margin, it stays stopped; at 21° it runs again.
	var structure := _powered_barge(30.0)
	var sea := _sea()
	var power := ShipPower.new(structure, sea)
	var state := FloodState.new()
	# Her room dry, its water far under its floor at any list.
	state.heads = PackedFloat64Array([-100.0])
	power.start(state)
	var powers := PackedInt32Array()
	for list_deg: float in [20.0, 26.0, 23.0, 21.0]:
		var next := state.copy()
		next.rotation = Attitude.rolled(Attitude.level(), deg_to_rad(list_deg))
		power.follow(state, next, 1.0)
		powers.append(next.power)
		state = next
	var main := ShipPower.Power.MAIN
	var emergency := ShipPower.Power.EMERGENCY
	assert_eq(
		powers, PackedInt32Array([main, emergency, emergency, main]), "off past it, on 3° back"
	)
