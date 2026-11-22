extends GutTest
## A deck the sea stands over deep enough to swim in is a floor to a swimmer coming in over
## its edge from the open sea: it floats over the edge and onto the deck. The water still
## rising under it — as it does all through a sinking — it was put its own height under that
## deck instead, the deck it had just come onto read as the ceiling over its head, and swam
## on under the deck: through her side, where the deck's edge is all that stands between the
## sea and the space under it.

const TUG: ShipLayout = preload("res://data/ships/tug.tres")
const TOWARD_PORT := Vector2(0.0, -1.0)
## The flat deck's starboard edge, and the tug's towing deck's.
const EDGE_Z := 4.0
## Where the tug's starboard ladder stands along her (x -10 to -9), her towing deck there a
## slab from z -4 to 4 over her engine room, whose side wall stands inboard at z 2.6 to 2.8.
const LADDER_X := -9.5
## How far over the deck the sea stands as a test begins, and how fast it rises, m/s: the
## tug's own, 57 s into seed 3's fast sinking.
const AWASH := 0.6
const RISING := 0.15


## A sinking of [param layout]'s held level, the sea RISING from AWASH over her main deck,
## the cells named in [param flooded] filled to it: test data, as HeldPose is.
class RisingSea:
	extends SinkSchedule
	var _layout: ShipLayout
	var _flooded: Array[StringName]

	func _init(layout: ShipLayout, flooded: Array[StringName]) -> void:
		super(SimFixtures.calm(), 0.0, RandomNumberGenerator.new())
		_layout = layout
		_flooded = flooded

	func _posed(tick: int) -> ShipPose:
		var sea := AWASH + RISING * tick * Ticks.SECONDS_PER_TICK
		var waters := {}
		for cell: StringName in _flooded:
			waters[cell] = [sea]
		return HeldPose.flooded(_layout, sea, waters)


func _rules() -> BrawlRules:
	return SimFixtures.rules()


## Steps [param sim] 3 s with seat 0 pressing [param press], a swimmer come to the edge at
## EDGE_Z of a deck at height 0 from the sea to starboard of it: at every tick it is in the
## sea beside the deck or on the deck, never under it; and it ends on the deck, its whole
## circle past the edge. [param where] names the case.
func _boards(sim: MatchSim, press: Vector2, where: String) -> void:
	var rules := _rules()
	var swimmer := sim.state.seats[0]
	swimmer.cold = 100.0
	var under := 0
	var lowest := INF
	for tick in 3 * Ticks.RATE:
		var before := swimmer.pos.y
		SimFixtures.step(sim, {0: SimFixtures.frame(0, press)})
		if swimmer.pos.z <= EDGE_Z and swimmer.pos.y < -0.001:
			under += 1
			lowest = minf(lowest, swimmer.pos.y)
		assert_gt(swimmer.pos.y, before - rules.step_height, "%s, tick %d: no drop" % [where, tick])
	assert_eq(under, 0, "%s: never under the deck (lowest %.2f)" % [where, lowest])
	assert_lt(swimmer.pos.z, EDGE_Z - rules.body_radius, where + ": over the edge")
	assert_almost_eq(swimmer.pos.y, 0.0, 0.0001, where + ": on the deck")
	assert_false(swimmer.is_out(), where + ": still in")


func test_a_swimmer_steering_into_an_awash_deck_s_edge_comes_onto_the_deck() -> void:
	# The flat deck as the top of a solid hull, and as a slab over a hold: the sea over it
	# and rising, a swimmer at the surface beside it steers into its edge.
	var layouts := {"a solid hull": SimFixtures.deck(), "a slab": SimFixtures.below_decks()}
	for kind: String in layouts:
		var layout: ShipLayout = layouts[kind]
		var sea := layout.freeboard + AWASH
		var rising := SimFixtures.scenario(
			[[0.0, sea, 0.0, 0.0], [3.0, sea + 3.0 * RISING, 0.0, 0.0]]
		)
		var sim := SimFixtures.sim(1, rising, layout)
		SimFixtures.swim(sim, 0, Vector3(LADDER_X, 0.0, EDGE_Z + 0.8))
		_boards(sim, TOWARD_PORT, kind)


## The tug as she is 57 s into seed 3's fast sinking, level: the sea 0.6 m over her towing
## deck and rising, the deck's own cell full to it, a swimmer alongside at her starboard
## ladder pressing in. Nothing of hers stands between the sea and the space under that
## deck's edge: put under the deck, it swam in to her engine room's wall and was held there.
func test_a_swimmer_at_the_tug_s_awash_towing_deck_comes_aboard() -> void:
	var sim := SimFixtures.sim(2, null, TUG)
	sim.schedule = RisingSea.new(TUG, [&"towing_deck"])
	sim.surfaces.honour(sim.pose())
	SimFixtures.place(sim, 1, Vector3(8.0, 2.4, 0.0))
	SimFixtures.swim(sim, 0, Vector3(LADDER_X, 0.0, EDGE_Z + 0.8))
	var swimmer := sim.state.seats[0]
	assert_almost_eq(swimmer.pos.y, AWASH - _rules().swim_depth, 0.0001, "afloat in the sea")
	_boards(sim, TOWARD_PORT, "the tug's towing deck")
	var deck := SimFixtures.platform_named(TUG, &"towing deck")
	assert_eq(sim.surfaces.under(swimmer.pos, _rules().step_height), deck, "on her towing deck")


## What #792 took out stays out: a swimmer deep under the tug's towing deck, or sunk half
## through it, is thrown to none of its edges — no farther in a tick than it swims — with
## the sea rising over the deck as above.
func test_a_swimmer_under_or_sunk_through_the_awash_deck_is_not_thrown_sideways() -> void:
	var rules := _rules()
	var places := {
		"deep under the deck": Vector3(LADDER_X, -2.0, 3.4),
		"its head through the deck": Vector3(LADDER_X, -1.0, 3.4),
		"sunk half through the deck": Vector3(-10.5, -0.5, 1.0),
	}
	var stride := rules.swim_speed * Ticks.SECONDS_PER_TICK + 0.001
	for place: String in places:
		for press: Vector2 in [Vector2.ZERO, TOWARD_PORT]:
			var sim := SimFixtures.sim(2, null, TUG)
			sim.schedule = RisingSea.new(TUG, [&"towing_deck"])
			sim.surfaces.honour(sim.pose())
			SimFixtures.place(sim, 1, Vector3(8.0, 2.4, 0.0))
			SimFixtures.swim(sim, 0, places[place])
			var swimmer := sim.state.seats[0]
			swimmer.pos.y = places[place].y
			swimmer.cold = 100.0
			var where := "%s, pressing %s" % [place, press]
			for tick in Ticks.RATE:
				var before := swimmer.pos
				SimFixtures.step(sim, {0: SimFixtures.frame(0, press)})
				var moved := Vector2(swimmer.pos.x - before.x, swimmer.pos.z - before.z).length()
				assert_lte(moved, stride, "%s, tick %d: never thrown sideways" % [where, tick])
			assert_lt(absf(swimmer.pos.z), EDGE_Z, where + ": inside her deck's edges still")
