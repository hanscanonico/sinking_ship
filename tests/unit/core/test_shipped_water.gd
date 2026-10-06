extends GutTest
## §5b.4 layer 1: green water (ShippedWater) against closed forms — an open well in a
## still sea takes nothing over its edge until the edge is under; in a seaway it ships
## the weir's depth^1.5 over an edge, level or sloping; its freeing ports hold it where
## what comes over equals what they drain; its loose water heels her as any wide cell's
## does — and the sea state is the scenario's, drawn once from the sinking stream after
## the first hit's draws, again by a client, and never for a still sea.

const SEED := 27
## A barge so broad the water in her well barely moves the sea up her.
const BROAD := 1000.0
## The well: 20 m along her, 10 m across, its deck 0.25 m under the sea and its two
## long edges — its bulwarks' tops — 0.25 m over it (heights a float holds exactly).
const WELL_LENGTH := 20.0
const WELL_BREADTH := 10.0
const WELL_DECK := -0.25
const WELL_EDGE := 0.25
## Freeing ports at the well's deck, both sides together, in m².
const PORTS := 16.0
## Flows within this share of their closed forms.
const SHARE := 1e-9
## Long enough for the barges here to come to rest, in physics seconds.
const SETTLE := 3600.0


## The sea's constants with the attitude and air stages off: water moves, every cell's
## air goes free, and she only heaves.
func _flows() -> SeaPhysics:
	var flows: SeaPhysics = SeaPhysics.load_default().duplicate()
	flows.attitude = false
	flows.air = false
	return flows


## The wave height whose crest stands [param reach] over the still sea.
func _waves_reaching(reach: float) -> float:
	return reach / SeaPhysics.load_default().wave_reach


## A broad barge, the sea at 0 up her, with the open well and — when [param ports] — its
## freeing ports.
func _barge_with_well(ports: bool) -> ShipStructure:
	var barge := BoxBarge.new(BROAD, BROAD, 20.0, 10.0, 0.0)
	barge.section_length = BROAD / 4.0
	var well := barge.cell(
		&"well", Vector3(0.0, WELL_DECK, 0.0), Vector3(WELL_LENGTH, WELL_EDGE, WELL_BREADTH)
	)
	well.kind = FloodCell.Kind.OPEN_WELL
	well.shipping_edges = PackedVector3Array(
		[
			Vector3(0.0, WELL_EDGE, 0.0),
			Vector3(WELL_LENGTH, WELL_EDGE, 0.0),
			Vector3(0.0, WELL_EDGE, WELL_BREADTH),
			Vector3(WELL_LENGTH, WELL_EDGE, WELL_BREADTH),
		]
	)
	if ports:
		var port := ShipOpening.new()
		port.name = &"freeing_ports"
		port.kind = ShipOpening.Kind.FREEING_PORT
		port.joins = [&"well", ShipOpening.SEA]
		port.centre = Vector3(WELL_LENGTH * 0.5, WELL_DECK + 0.05, 0.0)
		port.size = Vector3(2.0, 0.1, 0.0)
		port.area = PORTS
		barge.openings.append(port)
	return barge.structure()


## [param stepper] stepped from its start by [param seconds] a step for [param steps].
func _stepped(stepper: SinkStepper, seconds: float, steps: int) -> FloodState:
	var state := stepper.start()
	for _step in steps:
		state = stepper.step(state, seconds)
	return state


func test_a_still_sea_ships_nothing_until_the_edge_is_under() -> void:
	# No waves: the well's edges stand 0.25 m over the sea and nothing comes over them,
	# however long she floats — as before there was green water.
	var structure := _barge_with_well(false)
	var damage := HitDamage.new()
	var still := _stepped(SinkStepper.new(structure, damage, _flows()), 10.0, 60)
	assert_eq(still.water[0], 0.0, "a still sea: the well stays dry")
	# The same edges under a still sea 0.25 m over them: a weir into the dry well.
	var sea := _flows()
	var shipped := ShippedWater.new(structure, 0.0, sea)
	shipped.begin(Attitude.level(), 0.0)
	assert_eq(shipped.into(0, WELL_DECK), 0.0, "the edge over the sea: nothing")
	shipped.begin(Attitude.level(), 0.5)
	var weir := sea.shipping_discharge * sqrt(2.0 * sea.gravity) * 2.0 * WELL_LENGTH
	var expected := weir * pow(0.25, 1.5)
	assert_almost_eq(
		shipped.into(0, WELL_DECK),
		expected,
		expected * SHARE,
		"the edge 0.25 m under: discharge × 2L × √(2g) × 0.25^1.5"
	)
	# A wave: the same dry edges now ship water.
	damage.wave_height = _waves_reaching(0.5)
	var seaway := _stepped(SinkStepper.new(structure, damage, _flows()), 1.0, 10)
	assert_gt(seaway.water[0], 0.0, "a seaway: green water over the edges")


func test_a_wave_ships_the_weirs_depth_to_the_one_and_a_half_over_an_edge() -> void:
	# A crest 0.5 m over the still sea; the edges 0.25 m over it: q = discharge × L ×
	# √(2g) × 0.25^1.5 an edge. Pitched, each edge slopes: along it the crest's depth over
	# it runs straight from u0 to u1, and q = discharge × √(2g) × L (u0^2.5 − u1^2.5) /
	# (2.5 (u0 − u1)), where it stays over the edge. Once the well's own water stands over
	# the edge, the crest comes over that water and it goes back over the edge into the
	# trough: halfway between the edge and the crest, as much each way.
	var sea := _flows()
	var structure := _barge_with_well(false)
	var shipped := ShippedWater.new(structure, _waves_reaching(0.5), sea)
	var rate := sea.shipping_discharge * sqrt(2.0 * sea.gravity)
	shipped.begin(Attitude.level(), 0.0)
	var level_edges := rate * 2.0 * WELL_LENGTH * pow(0.25, 1.5)
	assert_almost_eq(
		shipped.into(0, WELL_DECK), level_edges, level_edges * SHARE, "level edges, a dry well"
	)
	assert_eq(shipped.into(0, 0.375), 0.0, "its water halfway to the crest: no more")
	assert_lt(shipped.into(0, 0.4), 0.0, "over that, it goes back over")
	var pitch := Attitude.pitched(Attitude.level(), deg_to_rad(0.5))
	var up := Attitude.up(pitch)
	shipped.begin(pitch, 0.0)
	var depth_at := func(x: float) -> float: return 0.5 - (up[0] * x + up[1] * WELL_EDGE)
	var u0: float = depth_at.call(0.0)
	var u1: float = depth_at.call(WELL_LENGTH)
	assert_gt(u1, 0.0, "the crest over the whole sloping edge")
	var sloping := 2.0 * rate * WELL_LENGTH * (pow(u0, 2.5) - pow(u1, 2.5)) / (2.5 * (u0 - u1))
	assert_almost_eq(
		shipped.into(0, WELL_DECK), sloping, sloping * 1e-6, "a sloping edge's integral"
	)


func test_freeing_ports_hold_the_well_where_shipping_equals_draining() -> void:
	# The crest 0.25 m over both 20 m edges ships discharge × 40 × √(2g) × 0.25^1.5; the
	# ports, under the sea, drain discharge × 16 × √(2g h), h the well's water over the
	# sea: they balance at h = (40 / 16)² × 0.25³ = 0.0977 m, under the edges — at a
	# second's step or the bake's longest, its head solved for the step as a stiff
	# cell's is.
	var expected := pow(2.0 * WELL_LENGTH / PORTS, 2.0) * pow(0.25, 3.0)
	var damage := HitDamage.new()
	damage.wave_height = _waves_reaching(0.5)
	var stepper := SinkStepper.new(_barge_with_well(true), damage, _flows())
	for seconds: float in [1.0, 10.0]:
		var state := _stepped(stepper, seconds, ceili(600.0 / seconds))
		var standing := state.heads[0] - state.sea
		var what := "at a %s s step" % seconds
		assert_almost_eq(standing, expected, 0.01 * expected, what + ": over the sea, ±1%")
		var later := stepper.step(state, seconds)
		# Within what the held solve leaves in the well's water (SURPLUS_TOLERANCE).
		var still := 2.0 * SinkStepper.SURPLUS_TOLERANCE / (WELL_LENGTH * WELL_BREADTH)
		assert_almost_eq(later.heads[0], state.heads[0], still, what + ": and stays there")
		assert_almost_eq(later.sea_given, later.total(), 1e-6, what + ": on the sea's account")


func test_water_on_a_wide_deck_heels_her_more_than_in_a_narrow_tank() -> void:
	# The same 40 m³, its centre at the same height, a ton on her starboard rail: loose
	# on a deck across her whole 12 m beam it runs to the low side and heels her more
	# than in a tank 2 m wide — its surface's l b³ / 12 the larger by far (R23).
	var heels := PackedFloat64Array()
	for wide: bool in [true, false]:
		var barge := BoxBarge.new(40.0, 12.0, 10.0, 4.0, 3.0)
		barge.section_length = 2.0
		var cell: FloodCell
		if wide:
			cell = barge.cell(&"deck", Vector3(-5.0, 1.0, -6.0), Vector3(5.0, 2.0, 6.0))
			cell.kind = FloodCell.Kind.OPEN_WELL
		else:
			var floor_y := 1.0 + 40.0 / 120.0 * 0.5 - 1.0
			cell = barge.cell(
				&"tank", Vector3(-5.0, floor_y, -1.0), Vector3(5.0, floor_y + 3.0, 1.0)
			)
		var structure := barge.structure()
		var weight := MassItem.new()
		weight.name = &"weight"
		weight.mass = 1000.0
		weight.centre = Vector3(0.0, 2.0, 5.0)
		weight.along = Vector2(-1.0, 1.0)
		structure.mass.append(weight)
		var stepper := SinkStepper.new(structure, HitDamage.new(), SeaPhysics.load_default())
		var state := stepper.start()
		state.water[0] = 40.0
		state.heads[0] = stepper.head(0, 40.0)
		while state.seconds < SETTLE:
			state = stepper.advance(state)
			if absf(state.roll_rate) < SinkBake.STILL_TURN and state.seconds > 60.0:
				break
		heels.append(BoxBarge.heel_deg(state.rotation))
	assert_gt(heels[1], 0.0, "the tank: heeled to the weight's side")
	assert_gt(
		heels[0], heels[1] * 1.3, "the wide deck: further (%.3f° vs %.3f°)" % [heels[0], heels[1]]
	)


func test_the_sea_is_drawn_once_after_the_first_hits_draws() -> void:
	# The trawler's sea: drawn from her scenario's band right after the first hit's draws
	# — gash, doors, openings — and the same however often the rule redraws; a client
	# draws it again from the timeline's origin.
	var structure := (load("res://data/ships/trawler.tres") as ShipLayout).structure
	var scenario: SinkScenario = load("res://data/sinking/trawler_open_sea.tres")
	var sea := SeaPhysics.load_default()
	assert_true(scenario.has_waves(), "her open sea has waves")
	var stream := SeedStreams.derive(SEED, "sink")
	var choice := MustSink.choose(structure, scenario, stream, sea)
	var again := SeedStreams.derive(SEED, "sink")
	var first := IcebergHit.draw(scenario.hit, again)
	HitMapper.map(first, structure, scenario.hit, again)
	var drawn := scenario.draw_wave_height(again)
	assert_eq(choice.damage.wave_height, drawn, "drawn after the first hit's draws")
	assert_between(drawn, scenario.wave_height.x, scenario.wave_height.y, "within her band")
	var origin := choice.timeline.origin
	assert_eq(origin.size(), MustSink.Origin.size(), "her timeline's origin keeps it")
	var client := MustSink.replay(
		structure, scenario, SeedStreams.derive(SEED, "sink"), choice.timeline
	)
	assert_not_null(client, "a client draws her hit again")
	if client != null:
		assert_eq(client.damage.wave_height, drawn, "and her sea")


func test_a_still_sea_draws_nothing() -> void:
	# The steamer's open sea declares no waves: the rule draws nothing for it, her
	# timelines' origins end at the hit's width as they always did, and her bakes — the
	# golden match's among them (test_determinism) — are byte for byte what they were.
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	assert_false(scenario.has_waves(), "a still sea")
	var stream := SeedStreams.derive(SEED, "sink")
	var before := stream.state
	assert_eq(scenario.draw_wave_height(stream), 0.0, "no waves")
	assert_eq(stream.state, before, "and nothing drawn")
	for choice: MustSink.Choice in SimFixtures.match_hits(3):
		assert_eq(choice.damage.wave_height, 0.0, "struck in a still sea")
		assert_eq(choice.timeline.origin.size(), MustSink.Origin.WAVE_HEIGHT, "no wave kept")
