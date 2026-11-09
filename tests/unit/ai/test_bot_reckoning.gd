extends GutTest
## A bot reckons where it stands now from the walks it has sent since its view's tick. By
## its walks summed (by_walks), unless a wall or a railing stands across them
## (BotReckoning._carried): then from the velocity it was seen at. Any railing that would
## hold its body counts, not only one of the floor it was seen on (#553). In boiler room 6
## on the Titanic's tank top, railing 1242 along the east side of the manhole down into the
## double bottom belongs to a 15 cm strip of floor between it and the floor the bot stands
## on: held by it, pressing west, the bot reckoned itself 0.6 m on, down the manhole, and
## #543's sample's row 25 paced there. And on a stair a body is held by the railing along
## its side near its head (#552): a walk through it is no more carried than one through the
## stair's floor's own. By its walks stepped (by_steps), its body is held by each railing
## on the way as the sim holds it (#557): on the Titanic's D deck a bot running at railing
## 805 beside ramp 38's well, pressing round its end onto the stair's head, was reckoned by
## its seen velocity once its walk's line met the railing, on through it onto the stair.

const TITANIC := "res://data/ships/titanic.tres"
const TANK_TOP := -18.1875
## Where row 25's bot was seen, held against railing 1242 on the floor east of the strip.
const BY_THE_MANHOLE := Vector3(58.05, TANK_TOP, -0.85)
const RAILING_1242_X := 57.66
## The steamer's after hatch: its head at x -12.85, its sides at z ±0.55, railed both
## sides along the main deck.
const HATCH_HEAD := -12.85
const HATCH_SIDE := 0.55
const SEEN_TICK := 300

static var _titanic: WalkGraph
static var _steamer: WalkGraph


func before_all() -> void:
	var rules := SimFixtures.rules()
	var layout: ShipLayout = load(TITANIC)
	_titanic = WalkGraph.new(layout, Surfaces.new(layout), rules)
	var steamer := SimFixtures.steamer()
	_steamer = WalkGraph.new(steamer, Surfaces.new(steamer), rules)


func test_a_walk_into_the_railing_of_the_floor_beside_it_is_not_carried() -> void:
	var graph := _titanic
	var surfaces := graph.surfaces()
	var floor := surfaces.under(BY_THE_MANHOLE, SimFixtures.rules().step_height)
	var strip := surfaces.under(
		Vector3(RAILING_1242_X + 0.07, TANK_TOP, -0.85), SimFixtures.rules().step_height
	)
	assert_ne(floor, strip, "seen on the floor east of the railing's strip")
	var me := _seen(BY_THE_MANHOLE, floor)
	for walk: Vector2 in [Vector2.LEFT, Vector2(-1.0, 0.2).normalized()]:
		var reckoning := _reckoning(graph, walk)
		# Stepped as the sim steps its body: into the strip, and pushed back out of the
		# railing once its middle is over the strip, never past it (#557).
		var stepped := reckoning.by_steps(me, SEEN_TICK, BY_THE_MANHOLE)
		assert_gt(stepped.x, RAILING_1242_X, "%s: stepped, held by the railing" % walk)
		assert_eq(stepped.y, TANK_TOP, "%s: stepped, still on the tank top" % walk)
		var walked := reckoning.by_walks(me, SEEN_TICK, BY_THE_MANHOLE)
		assert_eq(walked, BY_THE_MANHOLE, "%s: walked, held by the railing" % walk)
	# Pressing away from the railing, nothing stands across the walk.
	var away := _reckoning(graph, Vector2.RIGHT).by_steps(me, SEEN_TICK, BY_THE_MANHOLE)
	assert_gt(away.x, BY_THE_MANHOLE.x + 0.5, "away from it: carried on")


func test_a_walk_off_a_stairs_side_through_its_railing_is_not_carried() -> void:
	var graph := _steamer
	var surfaces := graph.surfaces()
	var rules := SimFixtures.rules()
	var stair := surfaces.under(Vector3(HATCH_HEAD + 0.05, 0.0, 0.0), rules.step_height)
	assert_true(surfaces.is_ramp(stair), "the hatch")
	var at := Vector3(HATCH_HEAD + 0.25, 0.0, HATCH_SIDE - rules.body_radius)
	at.y = surfaces.height_at(stair, at)
	var me := _seen(at, stair)
	var stepped := _reckoning(graph, Vector2.DOWN).by_steps(me, SEEN_TICK, at)
	assert_eq(stepped, at, "held by the main deck's railing along the stair's side")
	# Down the stair, nothing stands across the walk.
	var down := _reckoning(graph, Vector2.RIGHT).by_steps(me, SEEN_TICK, at)
	assert_gt(down.x, at.x + 0.5, "down the stair: carried on")


func test_a_body_held_by_a_railing_is_reckoned_where_the_sim_holds_it() -> void:
	# Ramp 38's head on the Titanic's D deck, drawn small: the floor west of the stair's well,
	# railed along the well from its head at z 0 on, and east of the railing the floor a body
	# would stand on past it. The walks a bot has sent since its view's tick are stepped as the
	# sim steps its body, the railing holding it (#557): seen running at the railing a hand
	# short of its end and pressing round it, as row 4's bot was; held by it at rest, pressing
	# round its end; and seen in front of its end, pressing on along it. On main a walk whose
	# line crossed the railing was reckoned by the seen velocity instead, on through it, and one
	# whose middle passed its end was carried round it as if nothing held its body.
	var rules := SimFixtures.rules()
	var layout := _railed_floor()
	var graph := WalkGraph.new(layout, Surfaces.new(layout), rules)
	for seen: Array in [
		[Vector3(-0.57, 0.0, 0.19), Vector3(2.76, 0.0, 0.43), Vector2(1.0, -0.25)],
		[Vector3(-rules.body_radius, 0.0, 0.15), Vector3.ZERO, Vector2(0.85, -0.53)],
		[Vector3(-0.06, 0.0, -0.04), Vector3(3.0, 0.0, 0.3), Vector2(0.3, 1.0)],
	]:
		var walk: Vector2 = seen[2].normalized()
		var me := _seen(seen[0], 0)
		me["vel"] = seen[1]
		var reckoning := _reckoning(graph, walk)
		var stepped := reckoning.by_steps(me, SEEN_TICK, reckoning.reckon(me))
		var body := _stepped_body(layout, seen[0], seen[1], walk)
		var named := "seen at %s going %s, pressing %s" % seen
		assert_almost_eq(stepped.x, body.x, 0.001, "%s: x where the sim holds it" % named)
		assert_almost_eq(stepped.z, body.z, 0.001, "%s: z where the sim holds it" % named)


## Two floors at one height either side of x 0: platform 0 west of it, railed along it from
## z 0 to z 3 beside a stair's well, and platform 1 east of it.
func _railed_floor() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var platforms: Array[ShipPlatform] = []
	for area: Rect2 in [Rect2(-2.0, -2.0, 2.0, 5.0), Rect2(0.0, -2.0, 1.0, 5.0)]:
		var platform := ShipPlatform.new()
		platform.area = area
		platforms.append(platform)
	layout.platforms = platforms
	var railing := ShipRailing.new()
	railing.platform = 0
	railing.from = Vector2(0.0, 0.0)
	railing.to = Vector2(0.0, 3.0)
	var railings: Array[ShipRailing] = [railing]
	layout.railings = railings
	layout.spawns = [Vector3(-1.0, 0.0, 2.0)]
	return layout


## Where the sim takes a body on [param layout] at [param pos] going [param vel] that presses
## [param walk] for as many ticks as a normal bot's view lags.
func _stepped_body(layout: ShipLayout, pos: Vector3, vel: Vector3, walk: Vector2) -> Vector3:
	var config := MatchConfig.new(1, 1, SimFixtures.rules(), layout, SimFixtures.calm())
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, pos)
	sim.state.seats[0].vel = vel
	var lag := BotProfile.for_tier(&"normal").reaction_ticks
	SimFixtures.step(sim, {0: SimFixtures.frame(0, walk)}, lag)
	return sim.state.seats[0].pos


## A bot's reckoning on [param graph]'s floors, a normal bot's, that has pressed
## [param walk] every tick since SEEN_TICK.
func _reckoning(graph: WalkGraph, walk: Vector2) -> BotReckoning:
	var rules := SimFixtures.rules()
	var profile := BotProfile.for_tier(&"normal")
	var reckoning := BotReckoning.new(profile, rules)
	var footing := BotFooting.new(graph.surfaces(), graph, rules, profile.edge_margin_m)
	reckoning.stand_on(footing, graph.surfaces())
	for tick in range(SEEN_TICK, SEEN_TICK + profile.reaction_ticks):
		var look := InputFrame.quantize_yaw(walk.angle())
		reckoning.sent(InputFrame.new(0, tick, InputFrame.quantize(walk), 0, look))
	return reckoning


## How a bot's view shows it: at rest at [param pos] on [param surface], on its feet.
func _seen(pos: Vector3, surface: int) -> Dictionary:
	return {
		"pos": pos,
		"vel": Vector3.ZERO,
		"surface": surface,
		"state": PlayerState.Body.GROUNDED,
		"stagger": 0,
		"hitstop": 0,
	}
