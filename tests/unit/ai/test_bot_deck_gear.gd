extends GutTest
## Bots round the Titanic's deck gear (#497), her dry world held still. The step up onto
## her head runs the breadth of her forecastle, and the walk graph's point for it lies on a
## body's own line, not on her centreline where the steam winch and No. 1 hatch stand. On
## main each stalled against the gear.

const TITANIC := "res://data/ships/titanic.tres"
const FORECASTLE := 4.3125
const HEAD := 4.9375
## On her forecastle's port side, abreast of the steam winch.
const BY_THE_WINCH := Vector3(102.0, FORECASTLE, -7.0)
## Her head's fore end, past the cable holders and capstans.
const HEAD_FORE_END := Vector3(127.0, HEAD, 0.0)
## How near the seat it goes for a bot comes: a shove's reach, about.
const THERE := 1.6
## How long a walk is given.
const SECONDS := 40.0

static var _layout: ShipLayout
static var _config: MatchConfig
static var _floors: BotFloors


func before_all() -> void:
	_layout = load(TITANIC)
	_config = SimFixtures.config(2, null, 1, _layout)
	_floors = BotInputSource.floors_of(_config)


## Where a normal bot, lapses off, standing at [param from] gets to going for a seat
## standing at [param at]: the first point within THERE of it, else where it stands at the
## end of SECONDS.
func _bot_walk(from: Vector3, at: Vector3) -> Vector3:
	var sim := MatchSim.create(_config)
	SimFixtures.place(sim, 0, from)
	SimFixtures.place(sim, 1, at)
	HeldPose.hold(sim, HeldPose.flooded(_layout, -_layout.freeboard, {}))
	var profile: BotProfile = BotProfile.for_tier(&"normal").duplicate()
	profile.mistake_rate = 0.0
	var sources: Array[InputSource] = [
		BotInputSource.new(0, profile, _config, _floors), InputSource.new()
	]
	var runner := MatchRunner.new(sim, sources)
	var bot := sim.state.seats[0]
	for _tick in Ticks.from_seconds(SECONDS):
		runner.step()
		if bot.pos.distance_to(at) < THERE:
			break
	return bot.pos


## Where a body steered by the walk graph alone from [param from] gets to on its way to
## [param at] — the graph's point for the next portal, then straight at it once in its zone:
## the first point within a body's radius of it, else where it stands at the end of SECONDS.
func _graph_walk(from: Vector3, at: Vector3) -> Vector3:
	var config := SimFixtures.config(1, null, 1, _layout)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, from)
	HeldPose.hold(sim, HeldPose.flooded(_layout, -_layout.freeboard, {}))
	var graph := _floors.graph(Faces.Up.DECK)
	var goal := graph.zone_at(at, sim.surfaces.under(at, config.rules.step_height))
	var pose := sim.pose()
	var walker := sim.state.seats[0]
	for _tick in Ticks.from_seconds(SECONDS):
		if walker.pos.distance_to(at) < config.rules.body_radius:
			break
		var aim := at
		if (
			graph.zone_at(walker.pos, walker.surface) != goal
			or sim.surfaces.is_ramp(walker.surface)
		):
			var toward := graph.steer(walker.pos, walker.surface, goal, pose)
			if not toward.is_empty():
				aim = toward[0]
		var move := Vector2(aim.x - walker.pos.x, aim.z - walker.pos.z).normalized()
		SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
	return walker.pos


## The step up onto her head is 16.5 m wide: abreast of the steam winch, the walk graph's
## point for it lies straight ahead along the body's own line, not on her centreline, and a
## body walked by the graph alone goes up onto her head and on to its fore end. On main it
## walked into the winch frame at (103.6, 4.31, -1.40).
func test_the_walk_graph_takes_a_body_up_onto_her_head_along_its_own_line() -> void:
	var graph := _floors.graph(Faces.Up.DECK)
	var surfaces := graph.surfaces()
	var step := SimFixtures.rules().step_height
	var surface := surfaces.under(BY_THE_WINCH, step)
	var head := graph.zone_at(HEAD_FORE_END, surfaces.under(HEAD_FORE_END, step))
	var point := graph.steer(
		BY_THE_WINCH, surface, head, HeldPose.flooded(_layout, -_layout.freeboard, {})
	)
	assert_eq(point.size(), 1, "a way up onto her head")
	assert_almost_eq(point[0].z, BY_THE_WINCH.z, 0.001, "along its own line")
	assert_gt(point[0].x, BY_THE_WINCH.x, "ahead of it")
	var got_to := _graph_walk(BY_THE_WINCH, HEAD_FORE_END)
	assert_lt(got_to.distance_to(HEAD_FORE_END), 0.4, "at her head's fore end: at %s" % got_to)


## A normal bot abreast of the steam winch goes for a seat at her head's fore end, and gets
## there. On main it stalled against the winch frame at (103.6, 4.31, -1.40).
func test_a_bot_by_the_steam_winch_goes_up_onto_her_head_for_a_seat() -> void:
	var got_to := _bot_walk(BY_THE_WINCH, HEAD_FORE_END)
	assert_lt(got_to.distance_to(HEAD_FORE_END), THERE, "at the seat: at %s" % got_to)

