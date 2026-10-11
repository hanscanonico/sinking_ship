extends GutTest
## The sinking's effects are presentation (D12): FxPlanner reads the snapshots, the
## events they carry and the ship's pose as SinkSchedule answers it (D7), and
## nothing it does reaches the sim (D5).

const RunMatch := preload("res://tools/run_match.gd")

const WASH := FxCue.Kind.WASH
const SPRAY := FxCue.Kind.SPRAY
const FLOTSAM := FxCue.Kind.FLOTSAM
const STRIKE := FxCue.Kind.STRIKE
const MIST := FxCue.Kind.MIST
const FROTH := FxCue.Kind.FROTH
const SPURT := FxCue.Kind.SPURT
const JET := FxCue.Kind.JET
const BOIL := FxCue.Kind.BOIL
const RENT := FxCue.Kind.RENT
const WELL := FxCue.Kind.WELL
## A whole sinking is scanned this many ticks a step: what the planner shows as a
## deck or a room goes under is the same at any pace.
const SCAN_STRIDE := 10
## A floor is watched this many seconds from the strike: long enough for the room over
## it to fill deep.
const BREACH_SCAN := 240.0
## The golden match seen through its countdown and its first thickening of smoke.
const SEEN_TICKS := 15 * Ticks.RATE
## What only the sim may name: the live match, its loop and its seats. Enum reads
## are allowed; SinkSchedule and Surfaces are the authorities the planner asks.
const LIVE := (
	"\\b(MatchSim|MatchRunner|SimDriver|InputSource|BotView)\\b"
	+ "|\\bMatchState\\b(?!\\.Phase\\b)"
	+ "|\\bPlayerState\\b(?!\\.(Body|Action|Cause)\\b)"
)


## The default match of [param seed_value] on SH6's script — the fixture whose lurches,
## collapse, trim and plunge the effects of a sinking are shown against (§5b.4).
func _sim(seed_value: int = 1701) -> MatchSim:
	var config := RunMatch.default_config(seed_value)
	config.scenario = load(SimFixtures.STEAMER_SCRIPT)
	return MatchSim.create(config)


## The default match of [param seed_value] struck by the first hit its sinking stream
## draws, as given — [param wider] times as wide — the strike's effects for that gash,
## whatever the must-sink rule would make of it.
func _struck(seed_value: int, wider: float = 1.0) -> MatchSim:
	var config := RunMatch.default_config(seed_value)
	var given: SinkScenario = config.scenario.duplicate()
	given.explicit_hit = IcebergHit.draw(given.hit, SeedStreams.derive(seed_value, "sink"))
	given.explicit_hit.width *= wider
	config.scenario = given
	return MatchSim.create(config)


func _planner(sim: MatchSim) -> FxPlanner:
	return FxPlanner.new(sim.config, sim.surfaces, sim.schedule)


## [param sim]'s snapshot moved to [param tick], carrying [param events]: its seats
## and cargo shared with every other, as the planner only reads them.
func _at(sim: MatchSim, tick: int, events: Array[SimEvent] = []) -> Dictionary:
	var snapshot := sim.snapshot().duplicate()
	snapshot["tick"] = tick
	snapshot["phase"] = MatchState.Phase.LIVE
	var entries: Array[Dictionary] = []
	for event: SimEvent in events:
		entries.append(event.to_dict())
	snapshot["events"] = entries
	return snapshot


## Every cue of the planner stepping [param sim]'s snapshots from tick [param from]
## to [param to], [param stride] ticks a step, with nothing happening but the
## sinking.
func _sink(planner: FxPlanner, sim: MatchSim, from: int, to: int, stride: int = 1) -> Array[FxCue]:
	var seen: Array[FxCue] = []
	var previous := _at(sim, from)
	for tick in range(from + stride, to + 1, stride):
		var current := _at(sim, tick)
		seen.append_array(planner.plan(previous, current))
		previous = current
	return seen


## How much white water [param sprays] throw up: how high each climbs, over how
## long a stretch, a metre at least.
func _thrown(sprays: Array[FxCue]) -> float:
	var thrown := 0.0
	for spray: FxCue in sprays:
		thrown += spray.rise * maxf(spray.position.distance_to(spray.end), 1.0)
	return thrown


func _of(cues: Array[FxCue], kind: FxCue.Kind) -> Array[FxCue]:
	return cues.filter(func(cue: FxCue) -> bool: return cue.kind == kind)


## Whether ship point [param point] stands over any deck of [param layout].
func _over_a_deck(layout: ShipLayout, point: Vector3) -> bool:
	for platform: ShipPlatform in layout.platforms:
		if platform.area.has_point(Vector2(point.x, point.z)):
			return true
	return false


func test_white_water_runs_where_the_sea_crosses_a_deck() -> void:
	var sim := _sim()
	var calm := _of(_sink(_planner(sim), sim, 0, Ticks.from_seconds(5.0)), WASH)
	assert_eq(calm.size(), 0, "no deck meets the sea in the calm")

	var from := Ticks.from_seconds(100.0)
	var washes := _of(_sink(_planner(sim), sim, from, from + 1), WASH)
	assert_gt(washes.size(), 0, "the sea is climbing the decks by 1:40")
	var pose := sim.schedule.pose_at(from + 1)
	for wash: FxCue in washes:
		assert_true(wash.on_sea)
		assert_almost_eq(pose.world_height(wash.position), 0.0, 0.001, "one end on the sea")
		assert_almost_eq(pose.world_height(wash.end), 0.0, 0.001, "the other too")
		assert_between(wash.strength, FxPlanner.WASH_LEAST, 1.0)
		var up_deck := pose.world_height(wash.position + wash.toward)
		assert_gt(up_deck, 0.0, "the way the sea climbs is up the deck")


func test_spray_bursts_where_the_waterline_meets_the_side_and_harder_in_the_plunge() -> void:
	var sim := _sim()
	var span := Ticks.from_seconds(4.0)
	var settling := Ticks.from_seconds(100.0)
	var plunging := Ticks.from_seconds(175.0)
	var slow := _of(_sink(_planner(sim), sim, settling, settling + span), SPRAY)
	var fast := _of(_sink(_planner(sim), sim, plunging, plunging + span), SPRAY)
	assert_gt(slow.size(), 0, "spray where the sea meets the deck's edge")
	assert_gt(_thrown(fast), _thrown(slow) * 2.0, "the plunge throws far more, higher")
	for spray: FxCue in slow:
		assert_true(spray.on_sea)
		assert_gt(spray.toward.y, 0.5, "thrown up")


func test_a_lurch_slaps_spray_up_the_low_side() -> void:
	var sim := _sim()
	var tick := Ticks.from_seconds(70.0)
	var starboard := SimEvent.sinking(tick, SimFixtures.lurch(0.0, 15.0), false)
	var cues := _planner(sim).plan(_at(sim, tick - 1), _at(sim, tick, [starboard]))
	var sheets := _of(cues, SPRAY)
	assert_gt(sheets.size(), 3, "all along the side")
	var length := 0.0
	for sheet: FxCue in sheets:
		assert_gt(sheet.position.z, 0.0, "a starboard lurch puts starboard down")
		assert_false(_over_a_deck(sim.config.ship, sheet.position), "outboard, on the sea")
		assert_false(_over_a_deck(sim.config.ship, sheet.end), "all of it")
		assert_eq(sheet.rise, FxPlanner.LURCH_RISE, "slapped up over the rail")
		length += sheet.position.distance_to(sheet.end)
	assert_gt(length, 30.0, "in sheets, not spots")
	var sifts := _of(cues, FxCue.Kind.SIFT)
	assert_gt(sifts.size(), 0, "dust off the decks overhead")
	for sift: FxCue in sifts:
		assert_gt(sift.end.x * sift.end.z, 0.5, "across the whole of a room")
		assert_gt(sift.radius, 1.5, "down from its ceiling to its floor")
	var slides := _of(cues, FxCue.Kind.SLIDE)
	assert_gt(slides.size(), 0, "loose gear sliding")
	for slide: FxCue in slides:
		assert_eq(slide.toward, Vector3.BACK, "toward the low side")


func test_a_collapse_bursts_and_throws_its_wreckage_overboard() -> void:
	var sim := _sim()
	var tick := Ticks.from_seconds(130.0)
	var gone := SimEvent.sinking(tick, SimFixtures.collapse(0.0, &"bridge"), false)
	var cues := _planner(sim).plan(_at(sim, tick - 1), _at(sim, tick, [gone]))
	for kind: FxCue.Kind in [
		FxCue.Kind.CLOUD,
		FxCue.Kind.SPLINTERS,
		FxCue.Kind.CHUNKS,
		FxCue.Kind.DEBRIS,
		FxCue.Kind.BELCH,
	]:
		assert_eq(_of(cues, kind).size(), 1, "%s from the bridge" % FxCue.Kind.keys()[kind])
	var cloud: FxCue = _of(cues, FxCue.Kind.CLOUD)[0]
	assert_gt(cloud.position.y, 4.7, "billowing up over where the bridge stood")
	var chunks: FxCue = _of(cues, FxCue.Kind.CHUNKS)[0]
	assert_almost_eq(chunks.radius, 4.7 - 2.5, 0.001, "down to the boat deck")
	var thrown := _of(cues, FLOTSAM)
	assert_eq(thrown.size(), 2 * FxPlanner.COLLAPSE_PIECES, "each way")
	for piece: FxCue in thrown:
		assert_eq(piece.end.y, 0.0)
		assert_false(_over_a_deck(sim.config.ship, piece.end), "never comes down on a deck")


func test_a_collapse_sheds_dust_while_it_is_telegraphed_and_again_as_it_lands() -> void:
	var sim := SimFixtures.sim(
		1,
		SimFixtures.with_events(SimFixtures.calm(), [SimFixtures.collapse(4.0, &"bridge")]),
		SimFixtures.steamer()
	)
	var dust := _of(_sink(_planner(sim), sim, 0, Ticks.from_seconds(5.0)), FxCue.Kind.DUST)
	var warned := dust.filter(func(cue: FxCue) -> bool: return cue.tick < Ticks.from_seconds(4.0))
	assert_gt(warned.size(), 3, "a trickle all through the warning")
	var landing := Ticks.from_seconds(4.0 + FxPlanner.FALL_SECONDS)
	var landed := dust.filter(func(cue: FxCue) -> bool: return cue.tick == landing)
	assert_eq(landed.size(), 1, "a cloud where the deck comes down")
	assert_almost_eq(landed[0].position.y, 2.5, 0.001, "on the boat deck")


func test_a_lost_crate_and_a_broken_rail_float_off_outboard() -> void:
	var sim := _sim()
	var tick := Ticks.from_seconds(60.0)
	var lost := SimEvent.crate_lost(tick, 0)
	var broken := SimEvent.railing_broke(tick, 3, -1, -1)
	var cues := _planner(sim).plan(_at(sim, tick - 1), _at(sim, tick, [lost, broken]))
	var thrown := _of(cues, FLOTSAM)
	assert_eq(thrown.size(), 3, "the crate, and the span's two lengths")
	assert_eq(thrown[0].piece, FxCue.Piece.CRATE)
	for piece: FxCue in thrown:
		assert_true(piece.on_sea)
		assert_false(_over_a_deck(sim.config.ship, piece.end), "never comes down on a deck")


func test_a_body_going_in_splashes_harder_the_harder_it_falls() -> void:
	var sim := _sim()
	var tick := Ticks.from_seconds(60.0)
	var stepping := _at(sim, tick - 1)
	var falling := _at(sim, tick - 1).duplicate(true)
	falling["seats"][2]["vel"] = Vector3(0.0, -FxPlanner.SPLASH_FALL, 0.0)
	var into: Array[SimEvent] = [SimEvent.entered_water(tick, 2)]
	# In the sea alongside, under the open sky.
	var now := _at(sim, tick, into).duplicate(true)
	now["seats"][2]["pos"] = Vector3(
		0.0, sim.schedule.pose_at(tick).water_height(Vector3(0.0, 0.0, 7.0)), 7.0
	)
	var soft: FxCue = _of(_planner(sim).plan(stepping, now), FxCue.Kind.SPLASH)[0]
	var hard: FxCue = _of(_planner(sim).plan(falling, now), FxCue.Kind.SPLASH)[0]
	assert_eq(soft.seat, 2)
	assert_true(soft.on_sea)
	assert_eq(soft.strength, FxPlanner.SPLASH_LEAST, "stepping in")
	assert_eq(hard.strength, 1.0, "falling in")
	assert_gt(hard.rise, soft.rise, "and higher")


func test_a_splash_below_decks_stays_under_the_deck_over_it() -> void:
	var sim := _sim()
	var corridor := sim.config.ship.rooms[2]
	assert_eq(corridor.name, &"cabin corridor")
	var middle := corridor.area.get_center()
	# A moment the sea stands in the corridor well under the main deck over it.
	var tick := 0
	var sea := INF
	while tick < sim.schedule.end_tick():
		tick += 5
		sea = sim.schedule.pose_at(tick).water_height(Vector3(middle.x, 0.0, middle.y))
		if sea > -1.0 and sea < -0.3:
			break
	assert_lt(sea, -0.3, "the corridor floods")
	var falling := _at(sim, tick - 1).duplicate(true)
	falling["seats"][2]["vel"] = Vector3(0.0, -FxPlanner.SPLASH_FALL, 0.0)
	var into: Array[SimEvent] = [SimEvent.entered_water(tick, 2)]
	var now := _at(sim, tick, into).duplicate(true)
	now["seats"][2]["pos"] = Vector3(middle.x, sea, middle.y)
	var splash: FxCue = _of(_planner(sim).plan(falling, now), FxCue.Kind.SPLASH)[0]
	var over := sim.surfaces.ceiling(Vector3(middle.x, sea, middle.y), 0.0)
	assert_lt(over - sea, FxPlanner.SPLASH_RISE.y, "a deck lower than a splash climbs")
	assert_lte(splash.rise, over - sea, "it climbs no higher than the deck over it")
	assert_gt(splash.rise, 0.0)


func test_the_funnel_smokes_thicker_and_belches_as_the_plunge_begins() -> void:
	var sim := _sim()
	var planner := _planner(sim)
	var cues := _sink(planner, sim, 0, sim.schedule.end_tick(), SCAN_STRIDE)
	var smoke := _of(cues, FxCue.Kind.SMOKE)
	assert_gt(smoke.size(), 5, "in steps")
	for index in range(1, smoke.size()):
		assert_gte(smoke[index].strength, smoke[index - 1].strength, "never thinner")
	assert_eq(smoke[0].strength, 0.0, "none extra before the sinking")
	var fired_at := sim.schedule.end_tick()
	for scheduled: SinkSchedule.Scheduled in sim.schedule.fired(sim.schedule.end_tick()):
		if scheduled.event.kind == SinkEvent.Kind.PLUNGE:
			fired_at = scheduled.at
	for puff: FxCue in smoke:
		if puff.tick < fired_at:
			assert_eq(puff.toward, Vector3.UP, "straight up before the plunge")
	assert_lt(smoke[-1].toward.y, 0.9, "bent over by the plunge")
	var plunge := Ticks.from_seconds(160.0)
	var event := SinkEvent.new()
	event.kind = SinkEvent.Kind.PLUNGE
	var began: Array[SimEvent] = [SimEvent.sinking(plunge, event, false)]
	var cough := _planner(sim).plan(_at(sim, plunge - 1), _at(sim, plunge, began))
	assert_eq(_of(cough, FxCue.Kind.BELCH).size(), 1)
	assert_gt(_of(cues, FxCue.Kind.BELCH).size(), 0, "and as its top comes down to the sea")


func test_steam_vents_as_the_sea_reaches_the_engine_room_and_drowns_its_engine() -> void:
	var sim := _sim()
	var cues := _sink(_planner(sim), sim, 0, sim.schedule.end_tick(), SCAN_STRIDE)
	var steam := _of(cues, FxCue.Kind.STEAM)
	assert_gt(steam.size(), 2)
	var first := steam[0]
	var pose := sim.schedule.pose_at(first.tick)
	var engine_room := sim.config.ship.rooms[1]
	assert_eq(engine_room.name, &"engine room")
	var corners := 0
	for corner: Vector2 in [
		engine_room.area.position,
		Vector2(engine_room.area.end.x, engine_room.area.position.y),
		engine_room.area.end,
		Vector2(engine_room.area.position.x, engine_room.area.end.y)
	]:
		if pose.world_height(Vector3(corner.x, engine_room.floor_height, corner.y)) < 0.0:
			corners += 1
	assert_gt(corners, 0, "the first steam as the sea first reaches the engine room's floor")
	for plume: FxCue in steam:
		assert_gt(plume.seconds, 0.0)


func test_bubbles_come_up_as_decks_flood() -> void:
	# The air a flooding room blows out is drawn on its water (InnerWater), never
	# thrown about the room as grains.
	var sim := _sim()
	var cues := _sink(_planner(sim), sim, 0, sim.schedule.end_tick(), SCAN_STRIDE)
	assert_gt(_of(cues, FxCue.Kind.BUBBLES).size(), 3, "over each deck going under")
	for vent: FxCue in _of(cues, FxCue.Kind.VENT):
		assert_almost_eq(vent.toward.length(), 1.0, 0.001)
	var floated := _of(cues, FLOTSAM)
	for piece: FxCue in floated:
		assert_false(_over_a_deck(sim.config.ship, piece.end), "never comes down on a deck")


func test_wreckage_off_a_flooding_deck_comes_up_beside_the_hull() -> void:
	var sim := _sim()
	var cues := _sink(_planner(sim), sim, 0, sim.schedule.end_tick(), SCAN_STRIDE)
	var risen := _of(cues, FLOTSAM).filter(func(cue: FxCue) -> bool: return cue.position == cue.end)
	assert_gt(risen.size(), 0, "loose gear floats off as decks flood")
	for piece: FxCue in risen:
		assert_false(_over_a_deck(sim.config.ship, piece.position), "outboard, never over a rail")
		var pose := sim.schedule.pose_at(piece.tick)
		assert_almost_eq(pose.world_height(piece.position), 0.0, 0.001, "on the sea")


func test_the_plunge_breaks_over_the_sides_blasts_air_out_and_sends_gear_sliding() -> void:
	var sim := _sim()
	var planner := _planner(sim)
	var plunge := Ticks.from_seconds(160.0)
	var event := SinkEvent.new()
	event.kind = SinkEvent.Kind.PLUNGE
	var began: Array[SimEvent] = [SimEvent.sinking(plunge, event, false)]
	var first := planner.plan(_at(sim, plunge - 1), _at(sim, plunge, began))
	var slides := _of(first, FxCue.Kind.SLIDE)
	assert_gt(slides.size(), 0, "gear sliding down the decks still out of the sea")
	var pose := sim.schedule.pose_at(plunge)
	for slide: FxCue in slides:
		var down := slide.position + slide.toward
		assert_lt(pose.world_height(down), pose.world_height(slide.position), "downhill")
	var going := _sink(planner, sim, plunge, plunge + 4 * Ticks.RATE)
	assert_gt(_of(going, FxCue.Kind.VENT).size(), 3, "air blasting out, one opening after another")
	var breaking := _of(going, SPRAY).filter(
		func(cue: FxCue) -> bool: return cue.position.distance_to(cue.end) > 1.0
	)
	assert_gt(breaking.size(), 0, "the sea breaking over the sides as they go under")
	for sheet: FxCue in breaking:
		assert_eq(sheet.rise, FxPlanner.PLUNGE_RISE, "flung up over heads")
		assert_false(_over_a_deck(sim.config.ship, sheet.position), "outboard")
		assert_false(_over_a_deck(sim.config.ship, sheet.end), "all of it")


func test_the_plunge_rains_spray_slides_gear_and_boils_up_wreckage_astern() -> void:
	var sim := _sim()
	var plunge := -1
	for scheduled: SinkSchedule.Scheduled in sim.schedule.fired(sim.schedule.end_tick()):
		if scheduled.event.kind == SinkEvent.Kind.PLUNGE:
			plunge = scheduled.at
	assert_gt(plunge, 0, "the golden match plunges")
	var span := Ticks.from_seconds(6.0)
	var cues := _sink(_planner(sim), sim, plunge - Ticks.RATE, plunge + span)
	var rain := _of(cues, FxCue.Kind.RAIN)
	assert_eq(rain.size(), span + 1, "spray rains over the ship all through the plunge")
	assert_eq(rain[0].tick, plunge, "from its start")
	assert_lt(rain[0].strength, rain[-1].strength, "gathering")
	assert_between(rain[0].strength, 0.0, 1.0)
	var slid := {}
	for slide: FxCue in _of(cues, FxCue.Kind.SLIDE):
		slid[slide.tick] = true
	assert_eq(slid.size(), span / FxPlanner.SLIDE_TICKS, "gear goes on sliding down the decks")
	var boils := _of(cues, FxCue.Kind.BUBBLES).filter(
		func(cue: FxCue) -> bool: return cue.radius == FxPlanner.ASTERN_BOIL.x
	)
	assert_eq(boils.size(), span / FxPlanner.ASTERN_TICKS + 1, "air boiling up off the stern")
	var risen: Array[FxCue] = []
	for boil: FxCue in boils:
		for piece: FxCue in _of(cues, FLOTSAM):
			if piece.position == boil.position and piece.end == boil.position:
				risen.append(piece)
	assert_eq(risen.size(), boils.size(), "each bringing a piece of wreckage up")
	var stern := INF
	var middle := 0.0
	for platform: ShipPlatform in sim.config.ship.platforms:
		stern = minf(stern, platform.area.position.x)
	for platform: ShipPlatform in sim.config.ship.platforms:
		middle = maxf(middle, platform.area.end.x)
	middle = (stern + middle) * 0.5
	for piece: FxCue in boils + risen:
		var pose := sim.schedule.pose_at(piece.tick)
		assert_true(piece.on_sea)
		assert_almost_eq(pose.world_height(piece.position), 0.0, 0.001, "on the sea")
		assert_false(_over_a_deck(sim.config.ship, piece.position), "never over a deck")
		assert_lt(piece.position.x, middle, "aft, where the stern still stands out of it")


func test_the_iceberg_strikes_its_gash_with_white_water_mist_and_foam() -> void:
	# Seed 38 strikes her starboard side from x -12.2 to -5.9 m, just over the sea at its
	# after end and 1.5 m under it at its forward end.
	var sim := _struck(38)
	var planner := _planner(sim)
	var damage := sim.schedule.damage()
	var struck := sim.schedule.hit_tick()
	var structure := sim.config.ship.structure
	var waterline := structure.waterline_y
	var quiet := _sink(planner, sim, struck - Ticks.RATE, struck + Ticks.RATE)
	for kind: FxCue.Kind in [SPURT, STRIKE, MIST, FROTH]:
		assert_eq(_of(quiet, kind).size(), 0, "nothing shows a strike nobody announced")
	var cues := _strike(planner, sim)
	var sheets := _of(cues, STRIKE)
	assert_gt(sheets.size(), 1, "sheets along the gash")
	assert_eq(_of(cues, SPRAY).size(), 0, "thrown from the strike's own emitters")
	var aft: FxCue = sheets[0]
	var fore: FxCue = sheets[0]
	for sheet: FxCue in sheets:
		for end: Vector3 in [sheet.position, sheet.end]:
			assert_between(end.x, damage.from_x - 0.01, damage.to_x + 0.01, "along the gash")
			var shell := structure.section_at(end.x).shell_at(maxf(end.y, waterline), 1)
			assert_gt(end.z, shell, "out of her starboard side, over the sea")
			assert_gte(end.y, waterline - 0.001, "never under it")
		assert_gt(sheet.toward.y, 0.5, "thrown up")
		assert_gt(sheet.toward.z, 0.0, "and out")
		if sheet.position.y < waterline + 0.001:
			assert_true(sheet.on_sea, "from the sea where the gash runs under it")
		aft = sheet if sheet.position.x < aft.position.x else aft
		fore = sheet if sheet.position.x > fore.position.x else fore
	assert_gt(aft.rise, fore.rise, "higher where the gash runs shallow")
	var mists := _of(cues, MIST)
	assert_gt(mists.size(), 0, "mist billows up off it")
	var froths := _of(cues, FROTH)
	assert_gt(froths.size(), 0, "foam spreads on the sea along it")
	var covered := 0.0
	for line: FxCue in mists + froths:
		assert_true(line.on_sea)
		for end: Vector3 in [line.position, line.end]:
			assert_between(end.x, damage.from_x - 0.01, damage.to_x + 0.01, "along the gash")
			assert_almost_eq(end.y, waterline, 0.001, "at her waterline")
			assert_gt(end.z, structure.section_at(end.x).shell_at(waterline, 1), "outboard")
		if line.kind == FROTH:
			covered += absf(line.end.x - line.position.x)
			assert_eq(line.seconds, GashPlanner.GASH_SECONDS, "for the gash's seconds")
			assert_eq(line.toward, Vector3.BACK, "drifting off her starboard side")
	assert_almost_eq(covered, damage.trace[-1].x - damage.trace[0].x, 0.01, "all of it")
	var boils := _of(cues, FxCue.Kind.BUBBLES)
	assert_gt(boils.size(), 0, "the sea boils over the deep stretch")
	for boil: FxCue in boils:
		assert_true(boil.on_sea)
		assert_gt(boil.position.x, (damage.from_x + damage.to_x) * 0.5, "over its deep end")

	var after := _sink(planner, sim, struck + 1, struck + Ticks.from_seconds(10.0))
	for kind: FxCue.Kind in [STRIKE, MIST, FROTH, WASH]:
		assert_eq(_of(after, kind).size(), 0, "the strike is not struck again, nor churned")
	var bursts := _of(after, SPURT)
	var seconds := Ticks.from_seconds(GashPlanner.GASH_SECONDS)
	assert_eq(bursts.size(), seconds / GashPlanner.GASH_TICKS, "a burst every GASH_TICKS")
	var first_second := bursts.filter(
		func(burst: FxCue) -> bool: return burst.tick <= struck + 1 + Ticks.RATE
	)
	assert_gt(_thrown(sheets), _thrown(first_second) * 3.0, "the strike throws by far the most")
	var moved := 0
	for index in bursts.size():
		var burst: FxCue = bursts[index]
		assert_between(burst.position.x, damage.from_x - 0.01, damage.to_x + 0.01)
		assert_lte(burst.tick, struck + 1 + seconds)
		if index > 0:
			assert_lt(burst.strength, bursts[index - 1].strength + 0.3, "dying down")
			if absf(burst.position.x - bursts[index - 1].position.x) > 0.5:
				moved += 1
	assert_gt(bursts[0].rise, bursts[-1].rise * 3.0, "and dying away")
	assert_gt(moved, bursts.size() * 3 / 4, "somewhere new each time")


func test_the_mist_off_a_deep_gash_climbs_over_her_rail() -> void:
	# Seed 37 strikes her starboard side from x -10.0 to -0.6 m, 0.75 to 0.86 m under
	# the sea all along: no sheet of it throws its white water up past her deck.
	var sim := _struck(37)
	var cues := _strike(_planner(sim), sim)
	var rail := sim.config.ship.freeboard + sim.config.rules.railing_height
	for sheet: FxCue in _of(cues, STRIKE):
		assert_true(sheet.on_sea, "the whole gash runs under the sea")
	var mists := _of(cues, MIST)
	assert_gt(mists.size(), 1)
	for mist: FxCue in mists:
		assert_gt(mist.rise, rail, "seen over her rail, from her deck and her far end")
		assert_gt(mist.toward.y, 0.7, "up her side")
		assert_gt(mist.toward.z, 0.0, "leaning off it")


func test_a_bigger_gash_strikes_harder_higher_and_thicker() -> void:
	# Seed 30's gash, half as wide again, lets the sea in through over 3.6 m², seed 22's
	# through 0.005 m².
	var big_sim := _struck(30, 1.5)
	var small_sim := _struck(22)
	var big := _strike(_planner(big_sim), big_sim)
	var small := _strike(_planner(small_sim), small_sim)
	assert_gt(big_sim.schedule.damage().area(), small_sim.schedule.damage().area() * 100.0)
	assert_lt(GashPlanner.size(small_sim.schedule.damage().area()), 0.05, "a scrape")
	assert_eq(GashPlanner.size(big_sim.schedule.damage().area()), 1.0, "the worst there is")
	assert_gt(_of(big, STRIKE).size(), _of(small, STRIKE).size() * 3, "far more white water")
	assert_gt(_highest(_of(big, STRIKE)), _highest(_of(small, STRIKE)) * 1.8, "far higher")
	assert_gt(_of(big, STRIKE)[0].strength, _of(small, STRIKE)[0].strength * 1.5, "harder")
	assert_gt(_of(big, MIST).size(), _of(small, MIST).size(), "more mist")
	assert_gt(_highest(_of(big, MIST)), _highest(_of(small, MIST)) * 1.2, "billowing higher")
	assert_gt(_of(big, FROTH)[0].strength, _of(small, FROTH)[0].strength, "thicker foam")
	var sizes := PackedFloat32Array()
	for area: float in [0.001, 0.005, 0.03, 0.5, 3.0, 10.0]:
		sizes.append(GashPlanner.size(area))
	for index in range(1, sizes.size()):
		assert_gte(sizes[index], sizes[index - 1], "never smaller for a bigger gash")


func test_the_sea_jets_in_through_a_gash_into_a_room_people_walk_in() -> void:
	var sim := _holed_by(&"trawler", _deep_bite())
	var structure := sim.config.ship.structure
	var gash := _gash_into(sim, &"engine_room")
	var room := structure.cells[structure.cell_named(&"engine_room")]
	var planner := _planner(sim)
	var struck := sim.schedule.hit_tick()
	var before := _sink(planner, sim, struck - Ticks.RATE, struck)
	assert_eq(_of(before, JET).size(), 0, "nothing gets in before she is struck")
	var cues := _strike(planner, sim)
	var jets := _of(cues, JET)
	assert_gt(jets.size(), 0, "the sea jets in as she is holed")
	assert_eq(_of(cues, BOIL).size(), 0, "into a dry room: no boil yet")
	for jet: FxCue in jets:
		for end: Vector3 in [jet.position, jet.end]:
			var half := gash.size.x * 0.5 + 0.01
			assert_between(end.x, gash.centre.x - half, gash.centre.x + half, "along the gash")
			assert_lt(end.z, gash.centre.z, "inboard of the room's side")
			assert_gt(end.z, room.low.z, "and inside the room")
			assert_between(end.y, room.low.y, room.high.y, "at the gash's height in it")
		assert_lt(jet.toward.z, -0.8, "thrown in across the room, from her starboard side")
		assert_gt(jet.strength, 0.5, "hard: the sea stands far over the dry room's floor")
		assert_gt(jet.rise, 0.5, "thrown well into the room")
	var void_gash := _gash_into(sim, &"engine_wing_s")
	for jet: FxCue in jets:
		assert_true(jet.position.z < void_gash.centre.z, "none into the wing void, nobody's room")


func test_the_jet_dies_into_a_boil_over_the_gash_as_the_room_fills_and_stops_level() -> void:
	# The room fills over the gash's slit in some 20 s; she goes down by 3 min.
	var sim := _holed_by(&"trawler", _deep_bite())
	var structure := sim.config.ship.structure
	var room := structure.cell_named(&"engine_room")
	var gash := _gash_into(sim, &"engine_room")
	var struck := sim.schedule.hit_tick()
	var gone := sim.schedule.gone_tick()
	var to := gone + Ticks.from_seconds(10.0)
	var cues := _sink(_planner(sim), sim, struck, to, SCAN_STRIDE)
	var inrush := _of(cues, JET) + _of(cues, BOIL)
	assert_gt(_of(cues, JET).size(), 2, "it jets in")
	assert_gt(_of(cues, BOIL).size(), 2, "and boils once the room's water tops the gash")
	var bottom := gash.centre - Vector3(0.0, gash.size.y * 0.5, 0.0)
	var top := gash.centre + Vector3(0.0, gash.size.y * 0.5, 0.0)
	var heads := PackedFloat64Array()
	var boiled := false
	var sea := SeaPhysics.load_default()
	var atmosphere := sea.air_pressure / (sea.sea_density * sea.gravity)
	for cue: FxCue in inrush:
		var pose := sim.schedule.pose_at(cue.tick)
		var level := pose.levels[room]
		assert_lt(cue.tick, gone, "none once she has gone")
		if cue.kind == JET:
			assert_lt(level, pose.world_height(top), "a jet while the room's water is under it")
			assert_false(boiled, "and never again once it boils")
		else:
			boiled = true
			assert_gt(level, pose.world_height(top), "a boil once the water tops it")
			assert_almost_eq(pose.world_height(cue.position), level, 0.01, "on the room's water")
			assert_almost_eq(pose.world_height(cue.end), level, 0.01)
		assert_lt(cue.position.z, gash.centre.z, "inboard of the gash")
		# Under the squeeze of any air trapped over the room's water.
		var pushing := level
		if pose.pockets[room] > 0.0:
			pushing += maxf(pose.pockets[room] - atmosphere, 0.0)
		heads.append(-maxf(pushing, pose.world_height(bottom)))
	# How hard it comes in goes as the head of sea over the room's water does: weaker as
	# the room fills, harder as she settles and takes the gash deeper.
	var stronger := 0
	for one in inrush.size():
		for other in inrush.size():
			if heads[one] < heads[other] - 0.05 and inrush[one].strength > inrush[other].strength:
				stronger += 1
	assert_eq(stronger, 0, "never harder for less head")
	var weakest := 1.0
	for cue: FxCue in inrush:
		weakest = minf(weakest, cue.strength)
	assert_lt(weakest, 0.3, "dying away as her room fills level with the sea")
	# The same snapshots and poses show the same breach to a fresh planner.
	var again := _sink(_planner(sim), sim, struck, to, SCAN_STRIDE)
	assert_eq(_described(_of(again, JET) + _of(again, BOIL)), _described(inrush))


func test_a_gash_that_opens_only_a_void_throws_nothing_inside() -> void:
	var sim := _holed_by(&"trawler", _bilge_bite())
	for opening: ShipOpening in sim.schedule.damage().openings:
		assert_does_not_have([&"engine_room", &"fish_hold"], opening.joins[0], "voids only")
	var struck := sim.schedule.hit_tick()
	var cues := _sink(_planner(sim), sim, struck, struck + Ticks.from_seconds(60.0), SCAN_STRIDE)
	for kind: FxCue.Kind in [JET, BOIL, RENT]:
		assert_eq(_of(cues, kind).size(), 0, "nobody's room is breached")


func test_a_gash_over_the_sea_throws_nothing_but_shows_its_rent_inside_and_out() -> void:
	# The steamer struck 1.5 m over her waterline, into her engine room.
	var sim := _holed_by(&"steamer", SimFixtures.explicit_hit(1, -2.0, 3.0, -1.5, 0.1, 0.5))
	var gash := _gash_into(sim, &"engine_room")
	var struck := sim.schedule.hit_tick()
	var planner := _planner(sim)
	var cues := _strike(planner, sim)
	cues.append_array(_sink(planner, sim, struck + 1, struck + Ticks.from_seconds(10.0)))
	assert_eq(_of(cues, JET).size(), 0, "no sea to jet in")
	assert_eq(_of(cues, BOIL).size(), 0)
	var rents := _of(cues, RENT)
	assert_eq(rents.size(), 2, "torn inside and out, once")
	var inside := rents[0] if rents[0].toward.z < 0.0 else rents[1]
	var outside := rents[1] if inside == rents[0] else rents[0]
	assert_lt(inside.toward.z, -0.9, "facing into the room")
	assert_lt(inside.position.z, gash.centre.z, "on its lining")
	assert_gt(outside.toward.z, 0.9, "facing the sea")
	assert_gte(outside.position.z, gash.centre.z, "on her hull")
	for rent: FxCue in rents:
		assert_eq(rent.tick, struck, "from the strike")
		assert_almost_eq(rent.position.x, gash.centre.x - gash.size.x * 0.5, 0.01, "all along it")
		assert_almost_eq(rent.end.x, gash.centre.x + gash.size.x * 0.5, 0.01)
		assert_almost_eq(rent.position.y, gash.centre.y, 0.01, "at its height")
		assert_gte(rent.radius, gash.size.y * 0.5 - 0.001, "as tall as it is")


func test_the_rent_inside_is_told_once_from_the_strike_on() -> void:
	var sim := _holed_by(&"trawler", _deep_bite())
	var gash := _gash_into(sim, &"engine_room")
	var struck := sim.schedule.hit_tick()
	var planner := _planner(sim)
	assert_eq(_of(_sink(planner, sim, struck - Ticks.RATE, struck), RENT).size(), 0)
	var rents := _of(_sink(planner, sim, struck, struck + Ticks.from_seconds(10.0)), RENT)
	assert_eq(rents.size(), 1, "inside the room only: all of the gash is under the sea")
	assert_lt(rents[0].toward.z, -0.9, "facing into the room")
	assert_almost_eq(rents[0].position.x, gash.centre.x - gash.size.x * 0.5, 0.01)
	assert_almost_eq(rents[0].end.x, gash.centre.x + gash.size.x * 0.5, 0.01)
	# A planner first asked after the strike — a match joined late — tells it all the same.
	var late := _of(_sink(_planner(sim), sim, struck + Ticks.RATE, struck + Ticks.RATE * 2), RENT)
	assert_eq(late.size(), 1)
	assert_eq(late[0].position, rents[0].position, "the same rent")
	assert_eq(late[0].end, rents[0].end)


func test_water_wells_up_through_the_floor_from_the_void_under_it_until_the_room_is_deep() -> void:
	# The bite floods the trawler's bilge under her engine room, which fills through its
	# floor plates.
	var sim := _holed_by(&"trawler", _bilge_bite())
	var structure := sim.config.ship.structure
	var room := structure.cell_named(&"engine_room")
	var bilge := structure.cell_named(&"engine_bilge")
	var box := structure.cells[room]
	var struck := sim.schedule.hit_tick()
	var to := struck + Ticks.from_seconds(BREACH_SCAN)
	var wells := _of(_sink(_planner(sim), sim, struck, to, SCAN_STRIDE), WELL)
	assert_gt(wells.size(), 3, "it wells up through the floor")
	var places := {}
	for well: FxCue in wells:
		var pose := sim.schedule.pose_at(well.tick)
		var floor := pose.world_height(Vector3(well.position.x, box.low.y, well.position.z))
		assert_gt(pose.levels[bilge], floor, "while the bilge's water stands over the floor")
		var depth := pose.levels[room] - floor
		assert_lt(depth, FxPlanner.WELL_DEEP, "and the room's is shallow")
		assert_between(well.position.x, box.low.x, box.high.x, "over the room's floor")
		assert_between(well.position.z, box.low.z, box.high.z)
		var shows := maxf(pose.levels[room], floor)
		assert_almost_eq(pose.world_height(well.position), shows, 0.01, "on its floor or water")
		assert_between(well.strength, 0.0, 1.0)
		places[Vector2(well.position.x, well.position.z).snappedf(0.5)] = true
	assert_gt(places.size(), 1, "spread over the floor")
	assert_lt(wells[-1].strength, wells[0].strength, "fading as the room deepens")
	var last := sim.schedule.pose_at(wells[-1].tick + SCAN_STRIDE * 2)
	var middle := (box.low + box.high) * 0.5
	var floor_now := last.world_height(Vector3(middle.x, box.low.y, middle.z))
	assert_gt(last.levels[room] - floor_now, FxPlanner.WELL_DEEP * 0.5, "it stops once deep")
	assert_lt(wells[-1].tick, to - Ticks.from_seconds(10.0), "and stays stopped")


## The default match on [param ship_name] struck by explicit [param hit] 20 s in.
func _holed_by(ship_name: StringName, hit: IcebergHit) -> MatchSim:
	var config := RunMatch.default_config(1701, 0, ship_name)
	var given: SinkScenario = config.scenario.duplicate()
	hit.moment = 20.0
	given.explicit_hit = hit
	config.scenario = given
	return MatchSim.create(config)


## A deep bite into the trawler's starboard side by her engine room, 0.8 m under her
## waterline: through her wing void into the room, the whole gash under the sea.
func _deep_bite() -> IcebergHit:
	return SimFixtures.explicit_hit(1, -12.0, -6.0, 0.8, 0.05, 1.5)


## A bite into the trawler's starboard side by her engine room, low: into her wing void
## and her bilge under the room, never the room.
func _bilge_bite() -> IcebergHit:
	return SimFixtures.explicit_hit(1, -12.0, -6.0, 2.4, 0.05, 1.0)


## The GASH opening of [param sim]'s hit into [param cell_name].
func _gash_into(sim: MatchSim, cell_name: StringName) -> ShipOpening:
	for opening: ShipOpening in sim.schedule.damage().openings:
		if opening.joins[0] == cell_name:
			return opening
	assert_true(false, "the gash opens %s" % cell_name)
	return null


func _described(cues: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for cue: FxCue in cues:
		lines.append(cue.describe())
	return lines


## The cues of the step [param planner] takes as [param sim]'s iceberg strikes.
func _strike(planner: FxPlanner, sim: MatchSim) -> Array[FxCue]:
	var struck := sim.schedule.hit_tick()
	return planner.plan(_at(sim, struck), _at(sim, struck + 1, [SimEvent.holed(struck)]))


## The highest any of [param cues] climbs over the sea.
func _highest(cues: Array[FxCue]) -> float:
	var highest := 0.0
	for cue: FxCue in cues:
		highest = maxf(highest, cue.rise)
	return highest


func test_effects_come_from_snapshots_and_the_pose_only() -> void:
	var config := RunMatch.default_config(1701)
	var runner := RunMatch.bots_only(config)
	var planner := FxPlanner.new(config, runner.sim.surfaces, runner.sim.schedule)
	var snapshots: Array[Dictionary] = [runner.snapshot.duplicate(true)]
	var seen := PackedStringArray()
	var untouched := true
	var ticks := SEEN_TICKS
	while not runner.is_over() and runner.tick() < ticks:
		var previous := runner.snapshot
		runner.step()
		var current := runner.snapshot
		var before := current.hash()
		for cue: FxCue in planner.plan(previous, current):
			seen.append(cue.describe())
		untouched = untouched and current.hash() == before
		snapshots.append(current.duplicate(true))
	assert_true(untouched, "planning never writes to a snapshot")
	assert_gt(seen.size(), 0)

	# Nothing shown reaches the sim: the match digests as it does unseen.
	var unseen := RunMatch.bots_only(config)
	unseen.run(ticks)
	assert_eq(runner.digest.hex(), unseen.digest.hex())

	# The effects are a function of the snapshots: copies, with no sim behind them,
	# show the same to a fresh planner.
	var again := FxPlanner.new(config, runner.sim.surfaces, runner.sim.schedule)
	var reseen := PackedStringArray()
	for index in range(1, snapshots.size()):
		for cue: FxCue in again.plan(snapshots[index - 1], snapshots[index]):
			reseen.append(cue.describe())
	assert_eq(reseen, seen)

	var live := RegEx.create_from_string(LIVE)
	for file: String in [
		"fx_planner.gd",
		"gash_planner.gd",
		"fx_cue.gd",
		"flotsam.gd",
		"deck_wetness.gd",
		"deck_debris.gd"
	]:
		var source := FileAccess.get_file_as_string("res://scenes/match/" + file).split("\n")
		for index in source.size():
			var found := live.search(source[index].get_slice("#", 0))
			assert_null(found, "%s:%d names the live match" % [file, index + 1])
