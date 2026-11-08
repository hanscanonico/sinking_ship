extends GutTest
## A bot's way over the floor to its next portal (BotFloorWay, #491), on the Titanic's G deck
## aft of O: the passage there holds the foot of the stair down from F deck and, beside it,
## the head of the stair on down to her after hold, and its door aft lies behind both. And
## on her forecastle, round her deck gear (#497): to its target there, and to the step up
## onto her head.

const TITANIC := "res://data/ships/titanic.tres"
const G_DECK := -11.0
## In the passage, just off the foot of the stair down from F deck.
const STAIR_FOOT := Vector3(-110.6, G_DECK, 0.3)
## In the passage to the two-berth room, past its door aft.
const PAST_THE_DOOR := Vector3(-117.5, G_DECK, 1.2)
## In the passage, aft of both stairs, a body's width in front of that door.
const BEFORE_THE_DOOR := Vector3(-115.0, G_DECK, 1.2)

const FORECASTLE := 4.3125
## On her forecastle, a body's width in from the head of the ladder up from her forward well
## to port, and by the head of the starboard ladder.
const PORT_LADDER_HEAD := Vector3(92.4, FORECASTLE, -4.86)
const STARBOARD_LADDER_HEAD := Vector3(95.0, FORECASTLE, 6.0)
## The fore side of her foremast, standing on her centreline forward of the windlass.
const FOREMAST_FORE_SIDE := 95.875
## On her forecastle abaft No. 1 hatch's port corner, beside the steam winch; inside the
## hatch's coaming; and on her head, up the step forward.
const BY_NO_1_HATCH := Vector3(103.2, FORECASTLE, -1.8)
const IN_NO_1_HATCH := Vector3(105.5, FORECASTLE, 0.0)
const ON_HER_HEAD := Vector3(113.0, 4.9375, 5.0)
## D deck's third-class open space forward of B: just off the foot of the ladder down from the
## third-class ladderway on C deck, which rises aft from x 96.375 to 92.6875 over z -7.0 to
## -4.625; and past the open space's 8 m join aft, x 91.875, behind the ladder.
const D_DECK := -1.25
const LADDER_FOOT := Vector3(97.2, D_DECK, -5.9)
const BEHIND_THE_LADDER := Vector3(90.5, D_DECK, -6.75)
## B deck's second-class entrance aft, by the head of the stair down to C deck: its railing
## along the stair's starboard side runs at z -1.625 from the head aft. Beside it, short of a
## body's width aft of the head, a body stands at each of these, and a walk straight at the
## head from there runs across that railing; the last is where a bot setting out for G deck's
## two-berth third-class room in #491's sample (row 2) stands once the wall beside it has
## pushed it clear. Off the stair's foot, on C deck.
const B_DECK := 2.75
const BESIDE_THE_STAIR_HEAD: Array[Vector3] = [
	Vector3(-90.3, B_DECK, -0.6),
	Vector3(-90.2, B_DECK, -0.2),
	Vector3(-90.0, B_DECK, 0.3),
	Vector3(-90.3, B_DECK, 0.2),
]
const OFF_THE_STAIR_FOOT := Vector3(-86.6, 0.0, -2.1)
## How far round its feet a walk's step is looked at for what stands on her deck: a way round
## is walked straight as far as a body LEAN of its radius round gets, and between the points
## a straight walk is looked at, a step may graze what that body would slide along.
const FEET := 0.05

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


## Off the foot of the ladder it came down, a bot's route goes on through a join 8 m wide
## behind that ladder, whose point (WalkGraph.toward) stays a body's width ahead along the
## bot's own line: a walk straight at it holds for that body's width, and the ladder's foot
## lies just past it. It goes round the ladder by the floor, every step on her D deck's floor,
## to the join. On main it looked only as far as the point, walked on up the ladder it had no
## way along, turned back off its foot, and paced there for good (#501 rows 20 and 21).
func test_a_bot_goes_round_the_ladder_it_came_down_to_a_wide_join_behind_it() -> void:
	var leg := _portal(LADDER_FOOT, BEHIND_THE_LADDER)
	assert_not_null(leg, "the join aft")
	assert_gt(leg.half_width, 2.0, "a wide one")
	var surfaces := _graph.surfaces()
	var step := SimFixtures.rules().step_height
	var way := BotFloorWay.new(_graph, SimFixtures.rules(), 1)
	var at := LADDER_FOOT
	var through := false
	for _look in 160:
		var surface := surfaces.under(at, step)
		var aim := way.toward(at, surface, leg, _graph.toward(leg, at, surface))
		var flat := Vector2(aim.x - at.x, aim.z - at.z)
		at += Vector3(flat.x, 0.0, flat.y).limit_length(0.25)
		var under := surfaces.under(at, step)
		assert_ne(under, Surfaces.NONE, "on a floor at %s" % at)
		assert_false(surfaces.is_ramp(under), "on no stair at %s" % at)
		if under == Surfaces.NONE or surfaces.is_ramp(under):
			break
		through = Vector2(at.x - leg.entry.x, at.z - leg.entry.z).dot(leg.along) > 0.0
		if through:
			break
	assert_true(through, "through the join, at %s" % at)


## Where a walk straight at the route's point holds, it is the point the bot walks to.
func test_a_bot_walks_straight_where_it_can() -> void:
	var leg := _portal(BEFORE_THE_DOOR, PAST_THE_DOOR)
	assert_not_null(leg, "the same door")
	var surface := _graph.surfaces().under(BEFORE_THE_DOOR, SimFixtures.rules().step_height)
	var to := _graph.toward(leg, BEFORE_THE_DOOR, surface)
	var way := BotFloorWay.new(_graph, SimFixtures.rules(), 1)
	assert_eq(way.toward(BEFORE_THE_DOOR, surface, leg, to), to, "straight at it")
	assert_false(way.holds(leg, BEFORE_THE_DOOR), "with no way round")


## Walks [param way] at [param to], a point in the zone [param from] stands in, the way a
## bot walks at its target there, at most [param looks] looks, a quarter metre toward each
## aim: every point it walks through.
func _walk_at(way: BotFloorWay, from: Vector3, to: Vector3, looks: int) -> Array[Vector3]:
	var surfaces := _graph.surfaces()
	var step := SimFixtures.rules().step_height
	var at := from
	var stood: Array[Vector3] = []
	for _look in looks:
		var aim := way.toward(at, surfaces.under(at, step), null, to)
		var flat := Vector2(aim.x - at.x, aim.z - at.z)
		at += Vector3(flat.x, 0.0, flat.y).limit_length(0.25)
		stood.append(at)
		if Vector2(at.x - to.x, at.z - to.z).length() < 0.5:
			break
	return stood


## On her forecastle, from the head of the ladder up out of her forward well to port, a seat by
## the starboard ladder's head stands behind the steam windlass, whose gear case and cylinders
## leave no way through and whose after end the forecastle's rail runs close by: the way round
## to it goes forward of the windlass and round her foremast's fore side, never a step into
## what stands on her deck (#497).
func test_a_bot_goes_round_the_windlass_to_its_target_on_her_forecastle() -> void:
	var surfaces := _graph.surfaces()
	var rules := SimFixtures.rules()
	var way := BotFloorWay.new(_graph, rules, 1)
	var stood := _walk_at(way, PORT_LADDER_HEAD, STARBOARD_LADDER_HEAD, 120)
	var last: Vector3 = stood.back()
	assert_lt(
		Vector2(last.x - STARBOARD_LADDER_HEAD.x, last.z - STARBOARD_LADDER_HEAD.z).length(),
		0.5,
		"at it"
	)
	var furthest_fore := -INF
	for point: Vector3 in stood:
		var surface := surfaces.under(point, rules.step_height)
		assert_ne(surface, Surfaces.NONE, "on a floor at %s" % point)
		var feet := Vector3(point.x, surfaces.height_at(surface, point), point.z)
		var held := surfaces.obstacle_contacts(
			feet, FEET, rules.body_height, rules.step_height, Surfaces.NONE, rules.crawl_height
		)
		assert_true(held.is_empty(), "never in her gear at %s" % point)
		furthest_fore = maxf(furthest_fore, point.x)
	assert_gt(furthest_fore, FOREMAST_FORE_SIDE, "round her foremast's fore side")


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


## Beside the head of B deck's stair aft, a walk straight at the head runs across the railing
## along the stair's side: the bot walks at a point of a way round by the floor instead, and
## not across a railing. On main a walk was looked along a step of 0.4 m at a time, and one
## step stood on the floor short of the railing, the next on the stair past it, where none of
## the floor's railings holds a body: the walk held, and the bot walked into the railing
## (#550).
func test_a_bot_beside_a_stair_s_head_never_walks_across_its_railing() -> void:
	var surfaces := _graph.surfaces()
	var step := SimFixtures.rules().step_height
	for from: Vector3 in BESIDE_THE_STAIR_HEAD:
		var leg := _portal(from, OFF_THE_STAIR_FOOT)
		assert_not_null(leg, "the stair down from %s" % from)
		var way := BotFloorWay.new(_graph, SimFixtures.rules(), 1)
		var on := surfaces.under(from, step)
		var aim := way.toward(from, on, leg, leg.entry)
		var under := surfaces.under(aim, step)
		var across := surfaces.railed(from, aim, on) or surfaces.railed(from, aim, under)
		assert_false(across, "from %s: across a railing to %s" % [from, aim])
		assert_true(way.holds(leg, from), "from %s: on a way round" % from)
