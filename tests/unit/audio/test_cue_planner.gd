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
