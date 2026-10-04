extends GutTest
## The sinking's effects are presentation (D12): FxPlanner reads the snapshots, the
## events they carry and the ship's pose as SinkSchedule answers it (D7), and
## nothing it does reaches the sim (D5).

const RunMatch := preload("res://tools/run_match.gd")

const WASH := FxCue.Kind.WASH
const SPRAY := FxCue.Kind.SPRAY
const FLOTSAM := FxCue.Kind.FLOTSAM
## A whole sinking is scanned this many ticks a step: what the planner shows as a
## deck or a room goes under is the same at any pace.
const SCAN_STRIDE := 10
## The golden match seen through its countdown and its first thickening of smoke.
const SEEN_TICKS := 15 * Ticks.RATE
## What only the sim may name: the live match, its loop and its seats. Enum reads
## are allowed; SinkSchedule and Surfaces are the authorities the planner asks.
const LIVE := (
	"\\b(MatchSim|MatchRunner|SimDriver|InputSource|BotView)\\b"
	+ "|\\bMatchState\\b(?!\\.Phase\\b)"
	+ "|\\bPlayerState\\b(?!\\.(Body|Action|Cause)\\b)"
)


## The default match of [param seed_value]: the steamer and its sinking.
func _sim(seed_value: int = 1701) -> MatchSim:
	return MatchSim.create(RunMatch.default_config(seed_value))


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
	now["seats"][2]["pos"] = Vector3(0.0, sim.schedule.pose_at(tick).sea_height(0.0, 7.0), 7.0)
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
	while tick < sim.schedule.cap_tick():
		tick += 5
		sea = sim.schedule.pose_at(tick).sea_height(middle.x, middle.y)
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
	var cues := _sink(planner, sim, 0, sim.schedule.cap_tick(), SCAN_STRIDE)
	var smoke := _of(cues, FxCue.Kind.SMOKE)
	assert_gt(smoke.size(), 5, "in steps")
	for index in range(1, smoke.size()):
		assert_gte(smoke[index].strength, smoke[index - 1].strength, "never thinner")
	assert_eq(smoke[0].strength, 0.0, "none extra before the sinking")
	var fired_at := sim.schedule.cap_tick()
	for scheduled: SinkSchedule.Scheduled in sim.schedule.fired(sim.schedule.cap_tick()):
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
	var cues := _sink(_planner(sim), sim, 0, sim.schedule.cap_tick(), SCAN_STRIDE)
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


func test_bubbles_and_air_come_up_as_decks_and_rooms_flood() -> void:
	var sim := _sim()
	var cues := _sink(_planner(sim), sim, 0, sim.schedule.cap_tick(), SCAN_STRIDE)
	assert_gt(_of(cues, FxCue.Kind.BUBBLES).size(), 3, "over each deck going under")
	var vents := _of(cues, FxCue.Kind.VENT)
	assert_gt(vents.size(), 0, "air out of the rooms as they flood")
	for vent: FxCue in vents:
		assert_almost_eq(vent.toward.length(), 1.0, 0.001)
	var floated := _of(cues, FLOTSAM)
	for piece: FxCue in floated:
		assert_false(_over_a_deck(sim.config.ship, piece.end), "never comes down on a deck")


func test_wreckage_off_a_flooding_deck_comes_up_beside_the_hull() -> void:
	var sim := _sim()
	var cues := _sink(_planner(sim), sim, 0, sim.schedule.cap_tick(), SCAN_STRIDE)
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
		"fx_planner.gd", "fx_cue.gd", "flotsam.gd", "deck_wetness.gd", "deck_debris.gd"
	]:
		var source := FileAccess.get_file_as_string("res://scenes/match/" + file).split("\n")
		for index in source.size():
			var found := live.search(source[index].get_slice("#", 0))
			assert_null(found, "%s:%d names the live match" % [file, index + 1])
