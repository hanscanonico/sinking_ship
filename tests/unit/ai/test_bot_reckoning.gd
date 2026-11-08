extends GutTest
## A bot reckons where it stands now from the walks it has sent since its view's tick,
## unless a wall or a railing stands across them (BotReckoning._carried): then from the
## velocity it was seen at. Any railing that would hold its body counts, not only one of
## the floor it was seen on (#553). In boiler room 6 on the Titanic's tank top, railing 1242
## along the east side of the manhole down into the double bottom belongs to a 15 cm strip
## of floor between it and the floor the bot stands on: held by it, pressing west, the bot
## reckoned itself 0.6 m on, down the manhole, and #543's sample's row 25 paced there. And
## on a stair a body is held by the railing along its side near its head (#552): a walk
## through it is no more carried than one through the stair's floor's own.

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
		var stepped := reckoning.by_steps(me, SEEN_TICK, BY_THE_MANHOLE)
		assert_eq(stepped, BY_THE_MANHOLE, "%s: stepped, held by the railing" % walk)
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
