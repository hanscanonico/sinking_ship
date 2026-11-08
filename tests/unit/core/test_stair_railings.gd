extends GutTest
## A railing holds back a body on a stair beside it, not only one on its own deck (#552).
## Near a stair's head its side is a step or less under the floor beside it, so nothing
## but that floor's railing stands across a body's way off the stair there; further down,
## the floor's edge is too high to step onto and holds it. On main a railing held only a
## body standing on its own platform, so a body near a stair's head walked out through the
## railing along its side onto the floor beside it: on the Titanic's F deck aft of C, a
## bot running onto ramp 70's head across its line went off its starboard side, through
## the railing there, onto the floor beside the stair's well.

const TITANIC := "res://data/ships/titanic.tres"
const F_DECK := -8.5625
## The steamer's after hatch: a stair 1.1 m wide down from the main deck, its head at x
## -12.85, between railings along both sides of its well; the main deck stands a step over
## it down to x -12.42.
const HATCH_HEAD := -12.85
const HATCH_SIDE := 0.55
const HATCH_FOOT := -9.65
## Ramp 70's head on the Titanic's F deck aft of C, and the railing along its starboard
## side there, which belongs to the floor beside its well.
const RAMP_70_HEAD := Vector3(78.0, F_DECK, -5.0)
const RAMP_70_STARBOARD := -4.5
const RAMP_70_RAIL_END := 79.1875

static var _titanic: ShipLayout


func before_all() -> void:
	_titanic = load(TITANIC)


func test_a_body_walking_off_a_stairs_side_by_its_head_is_held_by_the_floors_railing() -> void:
	var rules := SimFixtures.rules()
	# Two within a step of the deck's height, and one just past it, where the deck's edge
	# held the body already.
	for along: float in [0.05, 0.25, 0.45]:
		for side: float in [1.0, -1.0]:
			var sim := SimFixtures.sim(1, null, SimFixtures.steamer())
			var at := _on_stair(sim, Vector3(HATCH_HEAD + along, 0.0, 0.0))
			var stair := sim.state.seats[0].surface
			assert_true(sim.surfaces.is_ramp(stair), "%s: set down on the stair" % at)
			SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2(0.0, side))}, 2 * Ticks.RATE)
			var player := sim.state.seats[0]
			var named := "%s m down it, walking %s" % [along, "starboard" if side > 0 else "port"]
			assert_eq(player.body, PlayerState.Body.GROUNDED, named)
			assert_eq(player.surface, stair, "%s: still on the stair" % named)
			assert_almost_eq(
				player.pos.z * side, HATCH_SIDE - rules.body_radius, 0.0001, "%s: held" % named
			)
			assert_almost_eq(player.vel.z, 0.0, 0.0001, "%s: no speed into it" % named)


func test_a_body_walks_off_a_railed_stair_at_its_head_and_foot() -> void:
	# Up the hatch from halfway down and off its head onto the main deck, then from the deck
	# just forward of it down and off its foot onto the deck below: on its middle, and
	# hugging its side.
	var rules := SimFixtures.rules()
	for aside: float in [0.0, HATCH_SIDE - rules.body_radius - 0.02]:
		var sim := SimFixtures.sim(1, null, SimFixtures.steamer())
		_on_stair(sim, Vector3((HATCH_HEAD + HATCH_FOOT) * 0.5, 0.0, aside))
		var player := sim.state.seats[0]
		var turned := _walk(sim, Vector2.LEFT)
		assert_eq(player.body, PlayerState.Body.GROUNDED, "%s aside: up" % aside)
		assert_lt(player.pos.x, HATCH_HEAD - rules.body_radius, "%s aside: off its head" % aside)
		assert_almost_eq(player.pos.y, 0.0, 0.0001, "%s aside: on the main deck" % aside)
		assert_almost_eq(turned, 0.0, 0.0001, "%s aside: never turned on it" % aside)
		SimFixtures.place(sim, 0, Vector3(HATCH_HEAD - 0.3, 0.0, aside))
		turned = _walk(sim, Vector2.RIGHT)
		assert_eq(player.body, PlayerState.Body.GROUNDED, "%s aside: down" % aside)
		assert_gt(player.pos.x, HATCH_FOOT + rules.body_radius, "%s aside: off its foot" % aside)
		assert_lt(player.pos.y, -2.5, "%s aside: on the deck below" % aside)
		assert_almost_eq(turned, 0.0, 0.0001, "%s aside: never turned on it" % aside)


## Walks seat 0 of [param sim] [param way] for a second; how far aside it went while on a
## stair.
func _walk(sim: MatchSim, way: Vector2) -> float:
	var player := sim.state.seats[0]
	var aside := player.pos.z
	var turned := 0.0
	for _tick in Ticks.RATE:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, way)})
		if sim.surfaces.is_ramp(player.surface):
			turned = maxf(turned, absf(player.pos.z - aside))
	return turned


func test_a_body_running_across_ramp_70s_head_stays_out_of_the_floor_beside_its_well() -> void:
	# From F deck forward of the head and to port of the stair's line, a run diagonally
	# across the head: it meets the railing along the stair's starboard side, and goes on
	# down the stair beside it.
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1, null, _titanic)
	var start := RAMP_70_HEAD + Vector3(-0.6, 0.0, -0.6)
	SimFixtures.place(sim, 0, start)
	var stair := sim.surfaces.under(RAMP_70_HEAD + Vector3(0.3, 0.0, 0.0), rules.step_height)
	assert_true(sim.surfaces.is_ramp(stair), "ramp 70's head")
	var beside := sim.surfaces.under(Vector3(78.6, F_DECK, -4.0), rules.step_height)
	var player := sim.state.seats[0]
	var along_it := 0
	for tick in Ticks.RATE:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2(1.0, 1.0).normalized())})
		var at := "tick %d at %s" % [tick, player.pos]
		assert_ne(player.surface, beside, "%s: never on the floor beside the well" % at)
		if player.pos.x > RAMP_70_HEAD.x + rules.body_radius and player.pos.x < RAMP_70_RAIL_END:
			var held := RAMP_70_STARBOARD - rules.body_radius + 0.0001
			assert_lt(player.pos.z, held, "%s: on the stair's side of the railing" % at)
			along_it += 1
	assert_gt(along_it, 0, "it went down the stair along the railing")
	assert_lt(player.pos.y, F_DECK - rules.step_height, "below F deck")


## Sets seat 0 of [param sim] down on the steamer's after hatch at [param at]'s x/z, its
## feet on the stair.
func _on_stair(sim: MatchSim, at: Vector3) -> Vector3:
	var head := Vector3(HATCH_HEAD + 0.05, 0.0, 0.0)
	var stair := sim.surfaces.under(head, SimFixtures.rules().step_height)
	var feet := Vector3(at.x, sim.surfaces.height_at(stair, at), at.z)
	SimFixtures.place(sim, 0, feet)
	return feet
