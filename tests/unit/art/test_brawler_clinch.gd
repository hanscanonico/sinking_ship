extends GutTest
## At shoving range two bodies' reaching arms land on each other rather than pass
## through (Brawler.keep_apart): a shove thrown into a body at contact range stops
## with its wrists on the chest, two braced guards meet halfway, a body out of reach
## is left as posed, and a body the view looks out of — not drawn, but there — is
## reached for as any other.

const ARMS: Array[StringName] = [&"DEF-hand.L", &"DEF-hand.R"]

var _ship: Node3D
var _rules: BrawlRules


func before_each() -> void:
	_ship = Node3D.new()
	add_child_autofree(_ship)
	_rules = SimFixtures.rules()


func test_a_shove_at_contact_range_lands_on_the_chest_not_through_it() -> void:
	var apart := _rules.body_radius * 2.0
	var shover := _body(0, Vector3.ZERO, 0.0)
	var shoved := _body(1, Vector3(apart, 0.0, 0.0), PI)
	await _pose(shover, PlayerState.Action.ACTIVE)
	var chest := apart - Brawler.CLINCH_CHEST - Brawler.CLINCH_HAND
	assert_gt(_reach(shover, Vector3.RIGHT), chest + 0.03, "as posed, it reaches into the body")
	Brawler.keep_apart([shover, shoved] as Array[Brawler], -1)
	assert_almost_eq(_reach(shover, Vector3.RIGHT), chest, 0.01, "it lands on the chest")


func test_two_guards_at_contact_range_meet_halfway() -> void:
	var apart := _rules.body_radius * 2.0
	var one := _body(4, Vector3.ZERO, 0.0)
	var other := _body(1, Vector3(apart, 0.0, 0.0), PI)
	var bracing: Dictionary = SimFixtures.sim(1).snapshot()["seats"][0]
	bracing["bracing"] = true
	for _frame in 20:
		one.show_state(bracing, bracing, 1.0)
		other.show_state(bracing, bracing, 1.0)
		await get_tree().process_frame
	one.show_state(bracing, bracing, 1.0)
	other.show_state(bracing, bracing, 1.0)
	var fists := _reach(one, Vector3.RIGHT) + _reach(other, Vector3.LEFT, apart)
	assert_gt(fists + Brawler.CLINCH_HAND * 2.0, apart + 0.02, "as posed, the fists cross")
	Brawler.keep_apart([one, other] as Array[Brawler], -1)
	var halfway := apart * 0.5 - Brawler.CLINCH_HAND + 0.005
	assert_lte(_reach(one, Vector3.RIGHT), halfway, "the one's fists stop halfway")
	assert_lte(_reach(other, Vector3.LEFT, apart), halfway, "and the other's")


func test_a_body_out_of_reach_is_left_as_posed() -> void:
	var shover := _body(0, Vector3.ZERO, 0.0)
	var other := _body(1, Vector3(Brawler.CLINCH_RANGE + 0.1, 0.0, 0.0), PI)
	await _pose(shover, PlayerState.Action.ACTIVE)
	var wrist := shover.bone_position(ARMS[0])
	Brawler.keep_apart([shover, other] as Array[Brawler], -1)
	assert_eq(shover.bone_position(ARMS[0]), wrist)


func test_the_body_the_view_looks_out_of_is_reached_for_too() -> void:
	var shover := _body(0, Vector3.ZERO, 0.0)
	var eyes := _body(1, Vector3(_rules.body_radius * 2.0, 0.0, 0.0), PI)
	eyes.visible = false
	await _pose(shover, PlayerState.Action.ACTIVE)
	Brawler.keep_apart([shover, eyes] as Array[Brawler], 1)
	var chest := _rules.body_radius * 2.0 - Brawler.CLINCH_CHEST - Brawler.CLINCH_HAND
	assert_lte(_reach(shover, Vector3.RIGHT), chest + 0.01, "on the chest under the eye, not in it")


func _body(seat: int, at: Vector3, facing: float) -> Brawler:
	var body := Brawler.new()
	_ship.add_child(body)
	body.setup(seat, _rules, false)
	body.position = at
	body.rotation.y = -facing
	return body


## Poses [param body] in [param action] until the pose has settled.
func _pose(body: Brawler, action: PlayerState.Action) -> void:
	var entry: Dictionary = SimFixtures.sim(1).snapshot()["seats"][0]
	entry["action"] = action
	for _frame in 20:
		body.show_state(entry, entry, 1.0)
		await get_tree().process_frame
	body.show_state(entry, entry, 1.0)


## How far [param body]'s wrists reach along [param way] across the deck, from
## [param from] metres along it.
func _reach(body: Brawler, way: Vector3, from: float = 0.0) -> float:
	var furthest := -INF
	for hand: StringName in ARMS:
		furthest = maxf(furthest, body.bone_position(hand).dot(way))
	return furthest + from
