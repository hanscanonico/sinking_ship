extends GutTest
## Lanes on the Titanic a bot stalled in (#501, #505). A body walks past the foot of A deck's
## after ladders on B deck's open after end, which ran on aft from the plate's ladders to fill
## her deck from A deck's step to her after rail. On G deck it walks from the passage aft of
## K between the brine tank room and the paint store out onto the passage along the casing,
## whose mouth the engine oil tank's nudge closed. On D deck it walks along the third-class
## passage aft of P either side of its trunk, which left the cabins aft of it no way in that
## a body takes. And a bot finds its way round to a target
## past C deck's doorway into the second-class entrance aft, whose clear width leaves a
## body's middle a lane no square's middle of the way round's search falls in.

const TITANIC := "res://data/ships/titanic.tres"
const B_DECK := 2.75
## D deck aft of P, at P's top (#503).
const D_AFT := -2.1875
const G_DECK := -11.0
## B deck's open after end, starboard and port of her middle, walked along her after rail.
const PAST_THE_LADDER_FEET: Array[Vector3] = [
	Vector3(-90.0, B_DECK, 5.3), Vector3(-90.1, B_DECK, 5.3), Vector3(-90.0, B_DECK, -5.3)
]
## How far along her after rail the walk gets: past the ladder's foot, z ±6.06 … ±7.06.
const BEYOND_THE_FOOT := 7.4
## G deck: the passage aft of K, and the passage along the casing past its mouth.
const IN_THE_PASSAGE := Vector3(-43.0, G_DECK, -12.4)
const ALONG_THE_CASING := -9.5
## D deck aft of P: the passage's lanes starboard and port of the trunk, from its after
## side, and how far forward past its forward side, x -122.47, the walk gets.
const ABAFT_THE_TRUNK: Array[Vector3] = [
	Vector3(-126.75, D_AFT, -0.99), Vector3(-126.75, D_AFT, 0.99)
]
const FORWARD_OF_THE_TRUNK := -122.3
## C deck: by the doorway into the second-class entrance aft, and a target beyond it.
const BY_THE_DOORWAY := Vector3(-90.4, 0.0, -7.93)
const PAST_THE_DOORWAY := Vector3(-89.0, 0.0, -7.375)
## A body this thin touches only what a body walks into (test_bot_floor_way).
const FEET := 0.05

var _layout: ShipLayout
var _rules := SimFixtures.rules()


func before_all() -> void:
	_layout = load(TITANIC)


## Where a body placed at [param from] on her, held dry and level, stands after walking along
## [param move] for [param seconds].
func _walked(from: Vector3, move: Vector2, seconds: float) -> Vector3:
	var sim := SimFixtures.sim(2, null, _layout)
	SimFixtures.place(sim, 0, from)
	SimFixtures.place(sim, 1, Vector3.ZERO)
	HeldPose.hold(sim, HeldPose.flooded(_layout, -_layout.freeboard, {}))
	for _tick in Ticks.from_seconds(seconds):
		SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
	return sim.state.seats[0].pos


func test_a_body_walks_past_the_foot_of_a_deck_s_after_ladders() -> void:
	for from: Vector3 in PAST_THE_LADDER_FEET:
		var out := signf(from.z)
		var at := _walked(from, Vector2(0.0, out), 1.5)
		assert_gt(at.z * out, BEYOND_THE_FOOT, "from %s along her after rail" % from)
		assert_almost_eq(at.y, B_DECK, 0.01, "on B deck")


func test_a_body_walks_out_of_the_passage_aft_of_k_onto_the_casing_s() -> void:
	var at := _walked(IN_THE_PASSAGE, Vector2(0.0, 1.0), 1.5)
	assert_gt(at.z, ALONG_THE_CASING, "through the passage's mouth")


func test_a_body_walks_past_the_trunk_in_d_deck_s_passage_aft_of_p() -> void:
	for from: Vector3 in ABAFT_THE_TRUNK:
		var at := _walked(from, Vector2(1.0, 0.0), 1.5)
		assert_gt(at.x, FORWARD_OF_THE_TRUNK, "from %s along its lane" % from)


func test_a_bot_finds_its_way_round_past_a_doorway_a_body_just_fits() -> void:
	var graph := WalkGraph.new(_layout, Surfaces.new(_layout), _rules)
	var surfaces := graph.surfaces()
	var way := BotFloorWay.new(graph, _rules, 1)
	var at := BY_THE_DOORWAY
	for _look in 80:
		var aim := way.toward(at, surfaces.under(at, _rules.step_height), null, PAST_THE_DOORWAY)
		var flat := Vector2(aim.x - at.x, aim.z - at.z)
		at += Vector3(flat.x, 0.0, flat.y).limit_length(0.25)
		var surface := surfaces.under(at, _rules.step_height)
		assert_ne(surface, Surfaces.NONE, "on a floor at %s" % at)
		var feet := Vector3(at.x, surfaces.height_at(surface, at), at.z)
		var held := surfaces.obstacle_contacts(
			feet, FEET, _rules.body_height, _rules.step_height, Surfaces.NONE, _rules.crawl_height
		)
		assert_true(held.is_empty(), "never into a wall at %s" % at)
		if Vector2(at.x - PAST_THE_DOORWAY.x, at.z - PAST_THE_DOORWAY.z).length() < 0.5:
			break
	assert_lt(Vector2(at.x - PAST_THE_DOORWAY.x, at.z - PAST_THE_DOORWAY.z).length(), 0.5, "at it")
