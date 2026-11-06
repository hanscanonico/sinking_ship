extends GutTest
## A bot's way over the floor to its next portal (BotFloorWay, #491), on the Titanic's G deck
## aft of O: the passage there holds the foot of the stair down from F deck and, beside it,
## the head of the stair on down to her after hold, and its door aft lies behind both. And
## on her forecastle, round No. 1 hatch to the step up onto her head (#497).

const TITANIC := "res://data/ships/titanic.tres"
const G_DECK := -11.0
## In the passage, just off the foot of the stair down from F deck.
const STAIR_FOOT := Vector3(-110.6, G_DECK, 0.3)
## In the passage to the two-berth room, past its door aft.
const PAST_THE_DOOR := Vector3(-117.5, G_DECK, 1.2)
## In the passage, aft of both stairs, a body's width in front of that door.
const BEFORE_THE_DOOR := Vector3(-115.0, G_DECK, 1.2)

const FORECASTLE := 4.3125
## On her forecastle abaft No. 1 hatch's port corner, beside the steam winch; inside the
## hatch's coaming; and on her head, up the step forward.
const BY_NO_1_HATCH := Vector3(103.2, FORECASTLE, -1.8)
const IN_NO_1_HATCH := Vector3(105.5, FORECASTLE, 0.0)
const ON_HER_HEAD := Vector3(113.0, 4.9375, 5.0)

static var _layout: ShipLayout
static var _graph: WalkGraph


func before_all() -> void:
	_layout = load(TITANIC)
	_graph = WalkGraph.new(_layout, Surfaces.new(_layout), SimFixtures.rules())


## The portal from the zone at [param from] into the zone at [param into], or null.
func _portal(from: Vector3, into: Vector3) -> WalkGraph.Portal:
	var surfaces := _graph.surfaces()
	var step := SimFixtures.rules().step_height
	var out_of := _graph.zone_at(from, surfaces.under(from, step))
	var to := _graph.zone_at(into, surfaces.under(into, step))
	for portal: WalkGraph.Portal in _graph.portals():
		if portal.from_zone == out_of and portal.to_zone == to:
			return portal
	return null


## Walks [param leg] from [param from] by [param way] the way a bot follows it, at most
## [param looks] looks, a quarter metre toward each aim: every point it walks through, each
## with the surface under it.
func _walk(way: BotFloorWay, leg: WalkGraph.Portal, from: Vector3, looks: int) -> Array:
	var surfaces := _graph.surfaces()
	var step := SimFixtures.rules().step_height
	var at := from
	var stood: Array = []
	for _look in looks:
		var surface := surfaces.under(at, step)
		var to := _graph.toward(leg, at, surface)
		var aim := way.toward(at, surface, leg, to)
		var flat := Vector2(aim.x - at.x, aim.z - at.z)
		at += Vector3(flat.x, 0.0, flat.y).limit_length(0.25)
		stood.append([at, surfaces.under(at, step)])
		if Vector2(at.x - leg.entry.x, at.z - leg.entry.z).length() < 0.5:
			break
	return stood


## From the foot of the stair it came down, the door aft's point is behind that stair, and a
## walk straight at it runs onto the stair on down; its way round leads along the passage's
## far side of the stair it came down and up to the door, every step on her G deck's floor.
func test_a_bot_goes_round_the_stairs_in_the_passage_to_its_door() -> void:
	var leg := _portal(STAIR_FOOT, PAST_THE_DOOR)
	assert_not_null(leg, "a door from the passage aft")
	var surfaces := _graph.surfaces()
	var way := BotFloorWay.new(_graph, SimFixtures.rules(), 1)
	var stood := _walk(way, leg, STAIR_FOOT, 120)
	var last: Vector3 = stood.back()[0]
	assert_lt(Vector2(last.x - leg.entry.x, last.z - leg.entry.z).length(), 0.5, "at the door")
	var furthest_round := INF
	for step: Array in stood:
		var point: Vector3 = step[0]
		var surface: int = step[1]
		assert_ne(surface, Surfaces.NONE, "on a floor at %s" % point)
		assert_false(surfaces.is_ramp(surface), "on no stair at %s" % point)
		furthest_round = minf(furthest_round, point.z)
	assert_lt(furthest_round, -0.625, "round the far side of the stair from F deck")


## Where a walk straight at the route's point holds, it is the point the bot walks to.
func test_a_bot_walks_straight_where_it_can() -> void:
	var leg := _portal(BEFORE_THE_DOOR, PAST_THE_DOOR)
	assert_not_null(leg, "the same door")
	var surface := _graph.surfaces().under(BEFORE_THE_DOOR, SimFixtures.rules().step_height)
	var to := _graph.toward(leg, BEFORE_THE_DOOR, surface)
	var way := BotFloorWay.new(_graph, SimFixtures.rules(), 1)
	assert_eq(way.toward(BEFORE_THE_DOOR, surface, leg, to), to, "straight at it")
	assert_false(way.holds(leg, BEFORE_THE_DOOR), "with no way round")


## A look from where no body could stand — inside No. 1 hatch's coaming, where a bot's
## reckoning, carried on by a walk the coaming stopped, can put it — finds no way round and
## walks at the route's point; the next, from where it stands, still finds the way round the
## hatch to the step up onto her head. On main the first look's search came to nothing, and a
## failed search ended every one along the leg (#497).
func test_a_look_from_where_no_body_stands_leaves_the_leg_its_ways_round() -> void:
	var leg := _portal(BY_NO_1_HATCH, ON_HER_HEAD)
	assert_not_null(leg, "the step up onto her head")
	var step := SimFixtures.rules().step_height
	var surfaces := _graph.surfaces()
	var way := BotFloorWay.new(_graph, SimFixtures.rules(), 1)
	var inside := surfaces.under(IN_NO_1_HATCH, step)
	var to := _graph.toward(leg, IN_NO_1_HATCH, inside)
	assert_eq(way.toward(IN_NO_1_HATCH, inside, leg, to), to, "walks at the route's point")
	var by := surfaces.under(BY_NO_1_HATCH, step)
	to = _graph.toward(leg, BY_NO_1_HATCH, by)
	assert_ne(way.toward(BY_NO_1_HATCH, by, leg, to), to, "round the hatch")
	assert_true(way.holds(leg, BY_NO_1_HATCH), "on its way round")
