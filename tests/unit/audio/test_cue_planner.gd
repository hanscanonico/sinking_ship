extends GutTest
## The match's sounds are presentation (D12): CuePlanner hears the snapshots, the
## events they carry and the ship's pose, and nothing it does reaches the sim (D5).

const RunMatch := preload("res://tools/run_match.gd")

const FOOTSTEP := AudioCue.Kind.FOOTSTEP
const GRUNT := AudioCue.Kind.GRUNT
const WHOOSH := AudioCue.Kind.WHOOSH
const LANDING := AudioCue.Kind.LANDING
const SPLASH := AudioCue.Kind.SPLASH
const STROKE := AudioCue.Kind.STROKE
const IMPACT := AudioCue.Kind.IMPACT
const GROAN := AudioCue.Kind.GROAN
const GROUNDED := PlayerState.Body.GROUNDED
const AIRBORNE := PlayerState.Body.AIRBORNE
const SWIMMING := PlayerState.Body.SWIMMING
## The golden match heard through its countdown and first shoves; the splash of
## a real fall in is test_going_into_the_sea_splashes_once's.
const HEARD_TICKS := 15 * Ticks.RATE
## What only the sim may name: the live match, its loop and its seats. Enum reads
## are allowed; SinkSchedule and Surfaces are the authorities the planner asks.
const LIVE := (
	"\\b(MatchSim|MatchRunner|SimDriver|InputSource|BotView)\\b"
	+ "|\\bMatchState\\b(?!\\.Phase\\b)"
	+ "|\\bPlayerState\\b(?!\\.(Body|Action|Cause)\\b)"
)


func _planner(sim: MatchSim, listener: int = 0) -> CuePlanner:
	var planner := CuePlanner.new(sim.config, sim.surfaces, sim.schedule, 0)
	planner.listener_seat = listener
	return planner


## Seat 0 crossing the deck along the bow at [param speed] for [param ticks] ticks
## in [param state], from [param tick] on: the snapshots a moving body leaves.
func _cross(
	planner: CuePlanner, sim: MatchSim, speed: float, state: PlayerState.Body, ticks: int, tick: int
) -> Array[AudioCue]:
	var heard: Array[AudioCue] = []
	var previous := _moved(sim, tick, speed, state)
	for step in ticks:
		var current := _moved(sim, tick + step + 1, speed, state)
		heard.append_array(planner.plan(previous, current))
		previous = current
	return heard


func _moved(sim: MatchSim, tick: int, speed: float, state: PlayerState.Body) -> Dictionary:
	var snapshot := sim.snapshot().duplicate(true)
	snapshot["tick"] = tick
	snapshot["phase"] = MatchState.Phase.LIVE
	var entry: Dictionary = snapshot["seats"][0]
	entry["pos"] = Vector3(-10.0 + speed * Ticks.to_seconds(tick), 0.0, 0.0)
	entry["vel"] = Vector3(speed, 0.0, 0.0)
	entry["state"] = state
	return snapshot


func _of(cues: Array[AudioCue], kind: AudioCue.Kind) -> Array[AudioCue]:
	return cues.filter(func(cue: AudioCue) -> bool: return cue.kind == kind)


## Steps [param sim] once per row of [param rows] — each a seat → frame map —
## planning each step.
func _play(planner: CuePlanner, sim: MatchSim, rows: Array) -> Array[AudioCue]:
	var heard: Array[AudioCue] = []
	for frames: Dictionary in rows:
		var previous := sim.snapshot()
		SimFixtures.step(sim, frames)
		heard.append_array(planner.plan(previous, sim.snapshot()))
	return heard


func test_footsteps_follow_speed_and_stop_in_the_air() -> void:
	var sim := SimFixtures.sim(1)
	var seconds := 3.0
	var ticks := Ticks.from_seconds(seconds)
	var running := _of(_cross(_planner(sim), sim, 5.0, GROUNDED, ticks, 0), FOOTSTEP)
	var strolling := _of(_cross(_planner(sim), sim, 1.0, GROUNDED, ticks, 0), FOOTSTEP)
	var standing := _of(_cross(_planner(sim), sim, 0.0, GROUNDED, ticks, 0), FOOTSTEP)
	assert_almost_eq(
		running.size(), int(5.0 * seconds / CuePlanner.RUN_STRIDE), 1, "a stride apart"
	)
	assert_almost_eq(strolling.size(), int(1.0 * seconds / CuePlanner.WALK_STRIDE), 1)
	assert_eq(standing.size(), 0, "no steps standing still")
	assert_gt(running[0].gain, strolling[0].gain, "a run lands harder than a stroll")
	assert_eq(running[0].ground, AudioCue.Ground.WOOD, "the deck is planks")

	var planner := _planner(sim)
	var before := _of(_cross(planner, sim, 5.0, GROUNDED, ticks, 0), FOOTSTEP)
	var airborne := _of(_cross(planner, sim, 5.0, AIRBORNE, ticks, ticks), FOOTSTEP)
	assert_gt(before.size(), 0)
	assert_eq(airborne.size(), 0, "feet off the deck make no steps")


## Seat 0 walking for [param ticks] ticks with [param depth] metres of the sea over
## its feet, outboard of every deck where only the sea is.
func _wade(sim: MatchSim, depth: float, ticks: int) -> Array[AudioCue]:
	var planner := _planner(sim)
	var heard: Array[AudioCue] = []
	var speed := sim.config.rules.wade_speed
	var previous := _waded(sim, 0, speed, depth)
	for tick in range(1, ticks + 1):
		var current := _waded(sim, tick, speed, depth)
		heard.append_array(planner.plan(previous, current))
		previous = current
	return _of(heard, FOOTSTEP)


func _waded(sim: MatchSim, tick: int, speed: float, depth: float) -> Dictionary:
	var snapshot := _moved(sim, tick, speed, GROUNDED)
	var entry: Dictionary = snapshot["seats"][0]
	var pose := sim.schedule.pose_at(tick)
	var feet: Vector3 = entry["pos"] + Vector3(0.0, 0.0, 60.0)
	var above := pose.world_height(feet) - pose.water_level(feet)
	feet.y -= (above + depth) / pose.transform.basis.y.y
	entry["pos"] = feet
	return snapshot


func test_a_wading_step_is_louder_and_further_apart_the_deeper_the_water() -> void:
	var sim := SimFixtures.sim(1)
	var ticks := Ticks.from_seconds(4.0)
	var shallow := _wade(sim, 0.02, ticks)
	var deep := _wade(sim, 0.25, ticks)
	assert_gt(shallow.size(), 0)
	assert_eq(shallow[0].ground, AudioCue.Ground.WET, "a film of water splashes")
	assert_eq(deep[0].ground, AudioCue.Ground.WET)
	assert_gt(deep[0].gain, shallow[0].gain * 1.2, "the same walker, louder knee deep")
	assert_lt(deep.size(), shallow.size(), "and further apart")
	var deepest := _wade(sim, sim.config.rules.wade_depth, ticks)
	assert_almost_eq(deepest[0].gain / _wade(sim, 0.0, ticks)[0].gain, CuePlanner.WADE_LOUD, 0.001)


func test_a_swimmer_strokes_instead_of_stepping() -> void:
	var sim := SimFixtures.sim(1)
	var ticks := Ticks.from_seconds(3.0)
	var speed := sim.config.rules.swim_speed
	var swimming := _cross(_planner(sim), sim, speed, SWIMMING, ticks, 0)
	assert_eq(_of(swimming, FOOTSTEP).size(), 0, "no feet on a deck")
	var strokes := _of(swimming, STROKE)
	assert_almost_eq(strokes.size(), int(speed * 3.0 / CuePlanner.SWIM_STROKE), 1, "a stroke apart")
	assert_false(strokes[0].positional, "your own strokes are in your head")
	var floating := _cross(_planner(sim), sim, 0.0, SWIMMING, ticks, 0)
	assert_eq(_of(floating, STROKE).size(), 0, "no strokes floating still")


func test_a_body_frozen_in_a_hit_stop_makes_no_steps() -> void:
	var sim := SimFixtures.sim(1)
	var planner := _planner(sim)
	var heard: Array[AudioCue] = []
	var previous := _moved(sim, 0, 5.0, GROUNDED)
	for tick in range(1, 2 * Ticks.RATE):
		var current := _moved(sim, tick, 5.0, GROUNDED)
		current["seats"][0]["hitstop"] = 3
		heard.append_array(planner.plan(previous, current))
		previous = current
	assert_eq(_of(heard, FOOTSTEP).size(), 0, "a hit landing holds the feet still")


func test_windup_emits_one_whoosh_per_shove() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(-5.0, 0.0, 0.0))
	SimFixtures.place(sim, 1, Vector3(5.0, 0.0, 0.0), 180.0)
	var rules := sim.config.rules
	var shove_ticks := Ticks.from_seconds(
		rules.shove_windup + rules.shove_active + rules.shove_recovery
	)
	var rows: Array = []
	for _shove in 2:
		rows.append({0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
		for _tick in shove_ticks + 2:
			rows.append({0: SimFixtures.frame(0)})
	var planner := _planner(sim, 1)
	var heard := _play(planner, sim, rows)
	var whooshes := _of(heard, WHOOSH)
	assert_eq(whooshes.size(), 2, "one whoosh per shove")
	assert_eq(_of(heard, GRUNT).size(), 2, "one grunt per windup")
	assert_true(whooshes[0].positional, "another seat's shove sounds from where it is")
	assert_eq(whooshes[0].seat, 0)
	assert_lt(_of(heard, GRUNT)[0].tick, whooshes[0].tick, "the grunt leads the whoosh")

	var mine := SimFixtures.sim(1)
	var own := _of(_play(_planner(mine, 0), mine, rows.slice(0, shove_ticks)), WHOOSH)
	assert_eq(own.size(), 1)
	assert_false(own[0].positional, "your own shove is in your head")


func test_a_full_charge_whooshes_and_lands_heavy() -> void:
	var full := Ticks.from_seconds(SimFixtures.rules().charge_full)
	for held: int in [1, full + 5]:
		var sim := SimFixtures.sim(2)
		SimFixtures.place(sim, 0, Vector3(-0.55, 0.0, 0.0))
		SimFixtures.place(sim, 1, Vector3(0.55, 0.0, 0.0), 180.0)
		var rows: Array = []
		for _tick in held:
			rows.append({0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
		for _tick in Ticks.RATE:
			rows.append({0: SimFixtures.frame(0)})
		var heard := _play(_planner(sim, 1), sim, rows)
		var whooshes := _of(heard, WHOOSH)
		var impacts := _of(heard, IMPACT)
		assert_eq(whooshes.size(), 1, "held %d ticks: one whoosh" % held)
		assert_eq(impacts.size(), 1, "held %d ticks: one impact" % held)
		var charged := held > full
		assert_eq(whooshes[0].heavy, charged, "held %d ticks: the whoosh" % held)
		assert_eq(impacts[0].heavy, charged, "held %d ticks: the impact" % held)
		assert_eq(impacts[0].seat, 1, "the impact sounds from the one hit")


func test_going_into_the_sea_splashes_once() -> void:
	var sim := SimFixtures.sim(2)
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	SimFixtures.place(sim, 0, Vector3(gap.x, 0.0, 0.2), 90.0)
	SimFixtures.place(sim, 1, Vector3(gap.x, 0.0, 1.3), -90.0)
	var rows: Array = []
	# Tapped, not held: a held shove becomes a charge that waits for its release (SH4).
	# Then long enough for the cold to take the one in the sea.
	for tick in 120 + Ticks.from_seconds(sim.config.rules.cold_meter):
		var buttons := InputFrame.SHOVE if tick % 20 == 0 and tick < 120 else 0
		rows.append({0: SimFixtures.frame(0, Vector2.ZERO, buttons, 90.0)})
	var planner := _planner(sim)
	var heard: Array[AudioCue] = []
	var went_in := -1
	for frames: Dictionary in rows:
		var previous := sim.snapshot()
		for event: SimEvent in SimFixtures.step(sim, frames):
			if event.kind == SimEvent.Kind.ENTERED_WATER and went_in == -1:
				went_in = event.tick
		heard.append_array(planner.plan(previous, sim.snapshot()))
	assert_ne(went_in, -1, "shoved overboard")
	assert_true(sim.snapshot()["seats"][1]["out"], "and the cold took it")
	var splashes := _of(heard, SPLASH)
	assert_eq(splashes.size(), 1, "one splash going in, and none going out by the cold")
	assert_eq(splashes[0].seat, 1)
	assert_true(splashes[0].positional)
	assert_false(splashes[0].heavy)
	assert_eq(splashes[0].tick, went_in, "on the tick it went in")
	assert_eq(_of(heard, AudioCue.Kind.WIN_STING).size(), 1, "and the last one in is you")

	# A climber shoved back in goes in heavy.
	var thrown := sim.snapshot().duplicate(true)
	thrown["events"] = [SimEvent.knocked_back_in(thrown["tick"], 1, 0).to_dict()]
	var back := _of(_planner(sim).plan(sim.snapshot(), thrown), SPLASH)
	assert_eq(back.size(), 1)
	assert_true(back[0].heavy, "a climber knocked back in splashes heavy")


func test_landing_thud_scales_with_stagger() -> void:
	var sim := SimFixtures.sim(1)
	var previous := sim.snapshot()
	var gains: Array[float] = []
	for stagger: int in [0, 3, 6, CuePlanner.LANDING_LOUD_TICKS, 30]:
		var current := sim.snapshot().duplicate(true)
		current["events"] = [SimEvent.landed(current["tick"], 0, 0, stagger).to_dict()]
		var thuds := _of(_planner(sim, 1).plan(previous, current), LANDING)
		assert_eq(thuds.size(), 1, "one thud per landing")
		gains.append(thuds[0].gain)
	assert_almost_eq(gains[0], CuePlanner.LANDING_SOFT, 0.0001, "a step down still thuds")
	for index in range(1, gains.size()):
		assert_gt(gains[index], gains[index - 1] - 0.0001, "a longer drop lands harder")
	assert_gt(gains[2], gains[0])
	assert_almost_eq(gains[3], 1.0, 0.0001, "full at LANDING_LOUD_TICKS")
	assert_almost_eq(gains[4], 1.0, 0.0001, "and never past it")


func test_a_jump_makes_an_effort_and_a_landing() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3(-5.0, 0.0, 0.0))
	SimFixtures.place(sim, 1, Vector3(5.0, 0.0, 0.0))
	# Held the whole second: one jump, so one effort and one thud.
	var rows: Array = []
	for _tick in Ticks.RATE:
		rows.append({0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
	var heard := _play(_planner(sim, 1), sim, rows)
	var efforts := _of(heard, GRUNT)
	var thuds := _of(heard, LANDING)
	assert_eq(efforts.size(), 1, "one effort as it leaves the deck")
	assert_eq(efforts[0].tick, 1, "on the tick it jumped")
	assert_almost_eq(efforts[0].gain, CuePlanner.JUMP_EFFORT, 0.0001, "softer than a shove's")
	assert_true(efforts[0].positional, "another seat's jump sounds from where it is")
	assert_eq(thuds.size(), 1, "one thud as it comes down")
	assert_gt(thuds[0].tick, efforts[0].tick)
	assert_almost_eq(thuds[0].gain, CuePlanner.LANDING_SOFT, 0.0001, "a jump lands soft")
	assert_eq(_of(heard, AudioCue.Kind.FALL).size(), 0, "a jump is not a fall")


func test_the_hull_groans_from_below_the_lower_deck() -> void:
	var trimming := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [1.0, 0.0, 6.0, 0.0]])
	var steamer := SimFixtures.steamer()
	var sim := SimFixtures.sim(1, trimming, steamer)
	var before := sim.snapshot().duplicate(true)
	before["tick"] = 0
	var after := before.duplicate(true)
	after["tick"] = Ticks.RATE
	after["phase"] = MatchState.Phase.LIVE
	var groans := _of(_planner(sim).plan(before, after), GROAN)
	assert_eq(groans.size(), 1, "six degrees of trim groans")
	var lowest := INF
	for platform: ShipPlatform in steamer.platforms:
		lowest = minf(lowest, platform.height)
	assert_lt(groans[0].position.y, lowest, "from under the lowest deck")


func test_the_iceberg_booms_from_its_gash_and_the_hull_groans_under_it() -> void:
	# Seed 38's first draw strikes her starboard side from x -12.2 to -5.9 m: given.
	var config := RunMatch.default_config(38)
	config.scenario = config.scenario.duplicate()
	config.scenario.explicit_hit = IcebergHit.draw(
		config.scenario.hit, SeedStreams.derive(38, "sink")
	)
	var sim := MatchSim.create(config)
	var damage := sim.schedule.damage()
	var struck := sim.schedule.hit_tick()
	var before := sim.snapshot().duplicate(true)
	before["tick"] = struck
	before["phase"] = MatchState.Phase.LIVE
	var after := before.duplicate(true)
	after["tick"] = struck + 1
	var planner := _planner(sim)
	assert_eq(_of(planner.plan(before, after), AudioCue.Kind.HOLED).size(), 0, "unannounced")
	after["events"] = [SimEvent.holed(struck).to_dict()]
	var heard := planner.plan(before, after)
	var booms := _of(heard, AudioCue.Kind.HOLED)
	assert_eq(booms.size(), 1, "one boom")
	assert_true(booms[0].positional)
	assert_between(booms[0].position.x, damage.from_x, damage.to_x, "from the gash")
	assert_gt(booms[0].position.z, 0.0, "on her struck side")
	var groans := _of(heard, GROAN)
	assert_eq(groans.size(), 1, "the hull groans with it")
	assert_almost_eq(groans[0].position.x, booms[0].position.x, 0.001, "under the gash")
	var lowest := INF
	for platform: ShipPlatform in sim.config.ship.platforms:
		lowest = minf(lowest, platform.height)
	assert_lt(groans[0].position.y, lowest, "from under her lowest deck")


func test_cues_come_from_snapshots_and_events_only() -> void:
	var config := RunMatch.default_config(1701)
	var runner := RunMatch.bots_only(config)
	var planner := CuePlanner.new(config, runner.sim.surfaces, runner.sim.schedule, 0)
	planner.listener_seat = 0
	var snapshots: Array[Dictionary] = [runner.snapshot.duplicate(true)]
	var heard := PackedStringArray()
	var kinds := {}
	var untouched := true
	while not runner.is_over() and runner.tick() < HEARD_TICKS:
		var previous := runner.snapshot
		runner.step()
		var current := runner.snapshot
		var before := current.hash()
		for cue: AudioCue in planner.plan(previous, current):
			heard.append(cue.describe())
			kinds[cue.kind] = true
		untouched = untouched and current.hash() == before
		snapshots.append(current.duplicate(true))
	assert_true(untouched, "planning never writes to a snapshot")
	for kind: AudioCue.Kind in [FOOTSTEP, GRUNT, WHOOSH, AudioCue.Kind.CREAK]:
		assert_true(kinds.has(kind), "the match is heard: %s" % AudioCue.Kind.keys()[kind])

	# Nothing heard reaches the sim: the match digests as it does unheard.
	var unheard := RunMatch.bots_only(config)
	unheard.run(HEARD_TICKS)
	assert_eq(runner.digest.hex(), unheard.digest.hex())

	# The cues are a function of the snapshots: copies, with no sim behind them,
	# are heard the same by a fresh planner.
	var again := CuePlanner.new(config, runner.sim.surfaces, runner.sim.schedule, 0)
	again.listener_seat = 0
	var reheard := PackedStringArray()
	for index in range(1, snapshots.size()):
		for cue: AudioCue in again.plan(snapshots[index - 1], snapshots[index]):
			reheard.append(cue.describe())
	assert_eq(reheard, heard)

	var live := RegEx.create_from_string(LIVE)
	var source := FileAccess.get_file_as_string("res://scenes/audio/cue_planner.gd").split("\n")
	for index in source.size():
		var found := live.search(source[index].get_slice("#", 0))
		assert_null(found, "cue_planner.gd:%d names the live match" % (index + 1))


func test_a_lurch_warning_sounds_the_horn_once() -> void:
	# The horn is the telegraph: a second ahead of the swing, once per lurch.
	var sim := SimFixtures.sim(
		1, SimFixtures.with_events(SimFixtures.calm(), [SimFixtures.lurch(2.0, 15.0)])
	)
	var rows := []
	rows.resize(3 * Ticks.RATE)
	rows.fill({})
	var horns := _of(_play(_planner(sim), sim, rows), AudioCue.Kind.HORN)
	assert_eq(horns.size(), 1)
	assert_eq(horns[0].tick, Ticks.from_seconds(1.0), "a second before the swing")


func test_a_collapse_is_heard_before_it_happens() -> void:
	var layout := SimFixtures.steamer()
	var sim := SimFixtures.sim(
		1,
		SimFixtures.with_events(SimFixtures.calm(), [SimFixtures.collapse(4.0, &"bridge")]),
		layout
	)
	SimFixtures.place(sim, 0, Vector3(-17.0, 1.2, 0.0))
	var rows := []
	rows.resize(5 * Ticks.RATE)
	rows.fill({})
	var giving := _of(_play(_planner(sim), sim, rows), AudioCue.Kind.COLLAPSE)
	assert_eq(giving.size(), 2, "as it is telegraphed, and as it goes")
	assert_eq(giving[0].tick, Ticks.from_seconds(1.0))
	assert_eq(giving[1].tick, Ticks.from_seconds(4.0))
	assert_lt(giving[0].gain, giving[1].gain, "the warning quieter than the crash")
	for cue: AudioCue in giving:
		assert_true(cue.positional)
		assert_eq(cue.position, Vector3(-2.5, 4.7, 0.0), "from the bridge")


## A match on the flat deck carrying one crate at [param at], seat 0 well clear.
func _crated(at: Vector3) -> MatchSim:
	var crates: Array[ShipProp] = [SimFixtures.crate(at)]
	var sim := SimFixtures.sim(1, null, SimFixtures.crated(crates))
	SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, -2.0))
	return sim


func test_a_sliding_crate_scrapes_as_it_goes_and_a_still_one_is_silent() -> void:
	var sim := _crated(Vector3.ZERO)
	var planner := _planner(sim)
	var speed := 2.0
	var ticks := 2 * Ticks.RATE
	var scrapes: Array[AudioCue] = []
	var previous := sim.snapshot()
	for tick in ticks:
		var current := sim.snapshot().duplicate(true)
		current["tick"] = tick + 1
		current["props"][0]["pos"] = Vector3(speed * Ticks.to_seconds(tick + 1), 0.0, 0.0)
		current["props"][0]["vel"] = Vector3(speed, 0.0, 0.0)
		scrapes.append_array(_of(planner.plan(previous, current), AudioCue.Kind.SCRAPE))
		previous = current
	var expected := speed * Ticks.to_seconds(ticks) / CuePlanner.SCRAPE_STRIDE
	assert_almost_eq(float(scrapes.size()), expected, 1.0, "a scrape every stride it slides")
	for cue: AudioCue in scrapes:
		assert_true(cue.positional, "from the crate")
		assert_eq(cue.seat, -1)
	var still := _of(_play(_planner(sim), sim, [{}, {}, {}, {}]), AudioCue.Kind.SCRAPE)
	assert_true(still.is_empty(), "a crate at rest is silent")


func test_a_crate_thuds_as_it_comes_down_and_as_it_is_stopped_short() -> void:
	var sim := _crated(Vector3.ZERO)
	var then := sim.snapshot().duplicate(true)
	then["props"][0]["state"] = PropState.Body.AIRBORNE
	then["props"][0]["vel"] = Vector3(0.0, -5.0, 0.0)
	var now := sim.snapshot().duplicate(true)
	now["tick"] = 1
	assert_eq(_of(_planner(sim).plan(then, now), AudioCue.Kind.THUD).size(), 1, "down")
	for case: Array in [[3.0, 0.0, 1], [3.0, 2.9, 0], [0.0, 3.0, 0]]:
		then = sim.snapshot().duplicate(true)
		then["props"][0]["vel"] = Vector3(case[0], 0.0, 0.0)
		now["props"][0]["vel"] = Vector3(case[1], 0.0, 0.0)
		var thuds := _of(_planner(sim).plan(then, now), AudioCue.Kind.THUD)
		assert_eq(thuds.size(), case[2], "from %s m/s to %s m/s" % [case[0], case[1]])


## A crate sent into the starboard rail: the span breaks with a crack from its
## middle, and the crate splashes as the sea takes it.
func test_a_breaking_span_cracks_and_a_lost_crate_splashes() -> void:
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var sim := _crated(Vector3(-6.5, 0.0, 0.0))
	sim.state.props[0].vel = Vector3(0.0, 0.0, 6.0)
	var rows := []
	rows.resize(3 * Ticks.RATE)
	rows.fill({})
	var heard := _play(_planner(sim), sim, rows)
	var cracks := _of(heard, AudioCue.Kind.CRACK)
	assert_eq(cracks.size(), 1, "the span cracks once")
	assert_eq(cracks[0].position, Vector3(-6.5, 0.5, edge), "from its middle, halfway up")
	assert_true(cracks[0].positional)
	var splashes := _of(heard, AudioCue.Kind.SPLASH)
	assert_eq(splashes.size(), 1, "the crate splashes into the sea")
	assert_eq(splashes[0].seat, -1)


func test_a_crate_hit_thuds_on_the_brawler() -> void:
	var sim := _crated(Vector3(-12.0, 0.0, -3.0))
	SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, -1.5))
	sim.state.props[0].vel = Vector3(0.0, 0.0, 4.0)
	var rows := []
	rows.resize(Ticks.RATE)
	rows.fill({})
	var thuds := _of(_play(_planner(sim, -1), sim, rows), AudioCue.Kind.THUD)
	var on_the_brawler := thuds.filter(func(cue: AudioCue) -> bool: return cue.seat == 0)
	assert_eq(on_the_brawler.size(), 1, "one thud on the brawler it hits")
	assert_true(on_the_brawler[0].heavy)


## A sinking whose poses a test may set tick by tick: every other tick is the bake's.
class Posed:
	extends SinkSchedule
	var poses := {}

	func pose_at(tick: int) -> ShipPose:
		return poses[tick] if poses.has(tick) else super.pose_at(tick)


## Seed 38's match, its sinking a Posed one with her poses at ticks 1…3 dry as she lies
## before the hit; the dry pose comes back.
func _posed_sim() -> MatchSim:
	var config := RunMatch.default_config(38)
	config.scenario = config.scenario.duplicate()
	config.scenario.explicit_hit = IcebergHit.draw(
		config.scenario.hit, SeedStreams.derive(38, "sink")
	)
	var posed: Posed = config.schedule_as(Posed)
	var dry := SimFixtures.copy_of(posed.pose_at(0))
	for tick in [1, 2, 3]:
		posed.poses[tick] = dry
	return MatchSim.create(config)


## A copy of [param pose] with cell [param cell]'s water at world height [param level].
func _with_level(pose: ShipPose, cell: int, level: float) -> ShipPose:
	var made := SimFixtures.copy_of(pose)
	var levels := PackedFloat64Array(pose.levels)
	levels[cell] = level
	made.levels = levels
	return made


## The cues of each step through [param poses], ticks to the poses at them in the
## order they come, from the dry one at tick 1 on.
func _through(sim: MatchSim, poses: Dictionary) -> Array:
	var posed := sim.schedule as Posed
	var planner := _planner(sim, -1)
	var heard: Array = []
	var before := sim.snapshot().duplicate(true)
	before["tick"] = 1
	for tick: int in poses:
		posed.poses[tick] = poses[tick]
		var after := before.duplicate(true)
		after["tick"] = tick
		heard.append(planner.plan(before, after))
		before = after
	return heard


## How many cues of [param kind] [param heard] holds, every step's.
func _count(heard: Array, kind: AudioCue.Kind) -> int:
	var count := 0
	for cues: Array[AudioCue] in heard:
		count += _of(cues, kind).size()
	return count


func _floor_centre(cell: FloodCell) -> Vector3:
	return Vector3((cell.low.x + cell.high.x) * 0.5, cell.low.y, (cell.low.z + cell.high.z) * 0.5)


## The lowest world height under [param pose] of the box about [param centre] reaching
## [param half] each way.
func _lowest(pose: ShipPose, centre: Vector3, half: Vector3) -> float:
	var lowest := INF
	for corner in 8:
		var at := (
			centre
			+ Vector3(
				half.x if corner & 1 else -half.x,
				half.y if corner & 2 else -half.y,
				half.z if corner & 4 else -half.z
			)
		)
		lowest = minf(lowest, pose.world_height(at))
	return lowest


## The lowest corner of cell [param cell]'s floor under [param pose].
func _floor_low(pose: ShipPose, cell: FloodCell) -> float:
	var half := (cell.high - cell.low) * 0.5
	return _lowest(pose, _floor_centre(cell), Vector3(half.x, 0.0, half.z))


## Seconds of ticks after [param tick]: where a test's water may stand again.
func _after(tick: int, seconds: float) -> int:
	return tick + Ticks.from_seconds(seconds)


func test_a_cell_floods_once_as_its_water_first_rises_over_its_floor() -> void:
	var sim := _posed_sim()
	var dry := sim.schedule.pose_at(1)
	var structure := sim.config.ship.structure
	var silent := _through(sim, {2: dry, 3: dry})
	assert_eq(_count(silent, AudioCue.Kind.FLOOD), 0, "a dry tick floods nothing")
	assert_eq(_count(silent, AudioCue.Kind.POUR), 0, "nor pours")
	sim = _posed_sim()
	var cell := 0
	var wet := _with_level(dry, cell, dry.levels[cell] + 0.5)
	var heard := _through(sim, {2: wet, 3: wet})
	var floods := _of(heard[0], AudioCue.Kind.FLOOD)
	assert_eq(floods.size(), 1, "one flood as its water breaks in")
	assert_true(floods[0].positional)
	var centre := _floor_centre(structure.cells[cell])
	assert_almost_eq(floods[0].position, centre, Vector3.ONE * 0.001, "from its floor")
	assert_eq(_of(heard[1], AudioCue.Kind.FLOOD).size(), 0, "and only as it first does")


func test_a_cell_hovering_at_its_floor_floods_again_only_once_it_has_stood_dry() -> void:
	var sim := _posed_sim()
	var dry := sim.schedule.pose_at(1)
	var cell := 0
	var wet := _with_level(dry, cell, dry.levels[cell] + 0.5)
	var back := _after(5, CuePlanner.CELL_REARM)
	var hovering := _through(sim, {2: wet, 3: dry, 4: wet, 5: dry, back - 1: dry, back: wet})
	assert_eq(_of(hovering[0], AudioCue.Kind.FLOOD).size(), 1, "it floods")
	assert_eq(_count(hovering, AudioCue.Kind.FLOOD), 1, "once, while it hovers")
	sim = _posed_sim()
	var again := _after(3, CuePlanner.CELL_REARM)
	var drained := _through(sim, {2: wet, 3: dry, again: dry, again + 1: wet})
	assert_eq(_count(drained, AudioCue.Kind.FLOOD), 2)
	assert_eq(_of(drained[3], AudioCue.Kind.FLOOD).size(), 1, "and again once dry a while")


func test_a_platform_in_a_flooding_cell_floods_with_it_not_again() -> void:
	var sim := _posed_sim()
	var dry := sim.schedule.pose_at(1)
	var structure := sim.config.ship.structure
	var platform := -1
	var cell := -1
	for index in sim.config.ship.platforms.size():
		var deck: ShipPlatform = sim.config.ship.platforms[index]
		var middle := deck.area.get_center()
		cell = dry.cell_at(Vector3(middle.x, deck.height + CellMap.DRY, middle.y))
		if cell != CellMap.NONE:
			platform = index
			break
	assert_ne(platform, -1, "a deck in a cell")
	var deck: ShipPlatform = sim.config.ship.platforms[platform]
	var middle := deck.area.get_center()
	var under := dry.world_height(Vector3(middle.x, dry.cells.floor_of(cell), middle.y))
	var top := dry.world_height(Vector3(middle.x, deck.height, middle.y))
	var deck_wets := maxf(top, under + CellMap.DRY)
	var cell_wets := _floor_low(dry, structure.cells[cell]) + CuePlanner.SHOWS
	# Water between the deck's flooding and the cell's: one of the two before the other.
	var first := _with_level(dry, cell, (deck_wets + cell_wets) * 0.5)
	var wet := _with_level(dry, cell, top + 0.5)
	var cell_first := first.levels[cell] > cell_wets
	assert_ne(sim.surfaces.flooded(platform, first), cell_first, "one comes on first")
	assert_true(sim.surfaces.flooded(platform, wet), "the deck floods with its cell")
	var heard := _through(sim, {2: first, 3: first, 4: wet, 5: dry, 6: wet})
	assert_eq(_of(heard[0], AudioCue.Kind.FLOOD).size(), 1, "the first of them floods")
	assert_eq(_count(heard, AudioCue.Kind.FLOOD), 1, "and not the other, later, nor either again")
	sim = _posed_sim()
	var both := _of(_through(sim, {2: wet})[0], AudioCue.Kind.FLOOD)
	assert_eq(both.size(), 1, "one flood, not one for the cell and one for its deck")
	var centre := _floor_centre(structure.cells[cell])
	assert_almost_eq(both[0].position, centre, Vector3.ONE * 0.001, "from the cell's floor")


## Seed 38's first opening water can pass from a cell, and a pose of [param sim] with
## that cell's water half a metre over its bottom.
func _pouring(sim: MatchSim) -> Array:
	var dry := sim.schedule.pose_at(1)
	var structure := sim.config.ship.structure
	for passage: ShipOpening in sim.schedule.passages():
		if passage.kind in CuePlanner.UNHEARD or passage.shuts_at_hit:
			continue
		var cell := structure.cell_named(passage.joins[0])
		if cell == -1:
			continue
		var bottom := _lowest(dry, passage.centre, passage.size * 0.5)
		return [passage, _with_level(dry, cell, maxf(bottom, 0.0) + 0.5)]
	return [null, dry]


func test_an_opening_pours_as_it_starts_carrying_water() -> void:
	var sim := _posed_sim()
	var found := _pouring(sim)
	var opening: ShipOpening = found[0]
	assert_not_null(opening, "an opening water can pass")
	var heard := _through(sim, {2: found[1], 3: found[1]})
	var here := _of(heard[0], AudioCue.Kind.POUR).filter(
		func(cue: AudioCue) -> bool: return cue.position.is_equal_approx(opening.centre)
	)
	assert_eq(here.size(), 1, "one pour from %s as it starts" % opening.name)
	assert_true(here[0].positional)
	assert_eq(_of(heard[1], AudioCue.Kind.POUR).size(), 0, "none as it goes on pouring")


func test_an_opening_pours_again_only_once_it_has_stood_still_a_while() -> void:
	var sim := _posed_sim()
	var found := _pouring(sim)
	var dry := sim.schedule.pose_at(1)
	var pouring: ShipPose = found[1]
	var back := _after(5, CuePlanner.POUR_REARM)
	var stuttering := _through(
		sim, {2: pouring, 3: dry, 4: pouring, 5: dry, back - 1: dry, back: pouring}
	)
	var started := _of(stuttering[0], AudioCue.Kind.POUR).size()
	assert_gt(started, 0, "it pours")
	assert_eq(_count(stuttering, AudioCue.Kind.POUR), started, "once, while it stutters")
	sim = _posed_sim()
	var again := _after(3, CuePlanner.POUR_REARM)
	var still := _through(sim, {2: pouring, 3: dry, again: dry, again + 1: pouring})
	assert_eq(_of(still[3], AudioCue.Kind.POUR).size(), started, "and again once still a while")


func test_water_coming_on_all_at_once_is_heard_by_a_few() -> void:
	var sim := _posed_sim()
	var dry := sim.schedule.pose_at(1)
	var awash := dry
	for cell in dry.levels.size():
		awash = _with_level(awash, cell, dry.levels[cell] + 0.5 + cell * 0.1)
	assert_gt(dry.levels.size(), CuePlanner.WATER_CUES, "more cells than the water's voices")
	var heard := _through(sim, {2: awash, 3: awash})
	var water: Array[AudioCue] = _of(heard[0], AudioCue.Kind.FLOOD)
	water.append_array(_of(heard[0], AudioCue.Kind.POUR))
	assert_eq(water.size(), CuePlanner.WATER_CUES, "only so many at once")
	var rest := _count([heard[1]], AudioCue.Kind.FLOOD) + _count([heard[1]], AudioCue.Kind.POUR)
	assert_eq(rest, 0, "and the rest go unheard, not on the tick after")


## Where each flood [param ship] can sound comes from, to what it floods as one: a
## cell's floor, a deck in a cell its cell, a deck out of every cell itself.
func _flooding(ship: ShipLayout, dry: ShipPose) -> Dictionary:
	var from := {}
	for cell in ship.structure.cells.size():
		from[_floor_centre(ship.structure.cells[cell])] = "cell %d" % cell
	for deck: ShipPlatform in ship.platforms:
		var middle := deck.area.get_center()
		var at := Vector3(middle.x, deck.height, middle.y)
		var cell := dry.cell_at(at + Vector3.UP * CellMap.DRY)
		from[at] = "cell %d" % cell if cell != CellMap.NONE else "deck %s" % at
	return from


## What [param cue] sounds as one with: a flood its cell or deck (of [param flooding]),
## a pour its opening.
func _source(cue: AudioCue, flooding: Dictionary) -> String:
	if cue.kind == AudioCue.Kind.POUR:
		return "pour %s" % cue.position
	for at: Vector3 in flooding:
		if at.is_equal_approx(cue.position):
			return flooding[at]
	return "flood %s" % cue.position


## Seed 1701's trawler sinking as baked, heard tick by tick: her water hovers at the
## edges, yet no cell — its floor and its decks as one — floods again before it has
## stood dry CELL_REARM, and no opening pours again before it has stood still POUR_REARM.
func test_a_real_sinking_floods_each_cell_and_pours_each_opening_once_a_while() -> void:
	var config := RunMatch.default_config(1701, 0, &"trawler")
	var sim := MatchSim.create(config)
	var planner := _planner(sim, -1)
	var flooding := _flooding(config.ship, sim.schedule.pose_at(0))
	var quiet := {
		AudioCue.Kind.FLOOD: Ticks.from_seconds(CuePlanner.CELL_REARM),
		AudioCue.Kind.POUR: Ticks.from_seconds(CuePlanner.POUR_REARM),
	}
	var heard := {AudioCue.Kind.FLOOD: 0, AudioCue.Kind.POUR: 0}
	var last := {}
	var again: Array[String] = []
	var before := {
		"tick": 0, "seats": [], "props": [], "events": [], "phase": MatchState.Phase.ENDED
	}
	for tick in range(1, sim.schedule.end_tick()):
		var after := before.duplicate()
		after["tick"] = tick
		for cue: AudioCue in planner.plan(before, after):
			if not heard.has(cue.kind):
				continue
			heard[cue.kind] += 1
			var source := _source(cue, flooding)
			if last.has(source) and tick - last[source] <= quiet[cue.kind]:
				again.append("%s at %d and %d" % [source, last[source], tick])
			last[source] = tick
		before = after
	assert_gt(heard[AudioCue.Kind.FLOOD], 0, "she floods")
	assert_gt(heard[AudioCue.Kind.POUR], 0, "and pours")
	assert_eq(again, [] as Array[String], "nothing sounds again before it has stood quiet")
