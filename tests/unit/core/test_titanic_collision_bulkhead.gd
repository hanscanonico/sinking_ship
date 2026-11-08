extends GutTest
## Bulkhead A, her collision bulkhead, stands whole on the plates (#565). Under F deck her
## floors stop at it: forward of it the chain locker, the stores in her eyes and the peak tank
## wait for a floor of hers to stand on. On G deck it was cut at their faces and then left open
## where they stood, 3.07 m into the greasers' quarters and 1.57 m into the leading firemen's,
## and on the orlop and the lower orlop into No. 1 hold: doorways onto nothing. A body in any
## of those rooms pressing forward stays aft of A, held by its wall.

const TITANIC := "res://data/ships/titanic.tres"
const TITANIC_SINKING := "res://data/sinking/titanic_open_sea.tres"
## Bulkhead A's after face (gen_titanic.py's BX["A"] on a 1/128 m grid).
const BULKHEAD_A := 115.8125
const ROOMS_ON_A: Array[StringName] = [
	&"greasers' quarters, G deck, aft of A",
	&"leading firemen's quarters",
	&"No. 1 hold, orlop",
	&"No. 1 hold, lower orlop",
]
## How far aft of A a body sets out, and the ways it presses forward.
const AFT := 0.8
const PRESSES: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(1.0, 0.3), Vector2(1.0, -0.3)]
const SECONDS := 2.0

static var _layout: ShipLayout
static var _sim: MatchSim


func before_all() -> void:
	_layout = load(TITANIC)
	var sinking: SinkScenario = load(TITANIC_SINKING).duplicate()
	sinking.hit = null
	sinking.explicit_hit = null
	var config := SimFixtures.config(1, sinking, 1, _layout)
	config.countdown_ticks = 0
	_sim = MatchSim.create(config)


## The room of [param room_name] whose forward side stands on A.
func _room_on_a(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _layout.rooms:
		if room.name == room_name and is_equal_approx(room.area.end.x, BULKHEAD_A):
			return room
	return null


func test_her_rooms_on_a_have_no_doorway_through_it() -> void:
	var rules := SimFixtures.rules()
	for room_name: StringName in ROOMS_ON_A:
		var room := _room_on_a(room_name)
		assert_not_null(room, "%s ends on A" % room_name)
		if room == null:
			continue
		for door in room.doors(_sim.surfaces, rules.crawl_height, rules.step_height):
			assert_false(
				is_equal_approx(door.middle().x, BULKHEAD_A),
				"%s: a doorway on A at %s" % [room_name, door.middle()]
			)


func test_a_body_in_her_rooms_on_a_stays_aft_of_it() -> void:
	var rules := SimFixtures.rules()
	for room_name: StringName in ROOMS_ON_A:
		var room := _room_on_a(room_name)
		if room == null:
			fail_test("%s ends on A" % room_name)
			continue
		var start := Vector3(BULKHEAD_A - AFT, room.floor_height, room.area.get_center().y)
		assert_true(
			_sim.surfaces.blocked(
				start, start + Vector3(AFT * 2.0, 0.0, 0.0), rules.body_height, rules.step_height
			),
			"%s: A's wall stands across the way forward" % room_name
		)
		for press: Vector2 in PRESSES:
			SimFixtures.place(_sim, 0, start, 0.0)
			var body := _sim.state.seats[0]
			var stick := press.normalized()
			var frame := SimFixtures.frame(0, stick, 0, rad_to_deg(stick.angle()))
			var furthest := -INF
			for _tick in Ticks.from_seconds(SECONDS):
				SimFixtures.step(_sim, {0: frame})
				furthest = maxf(furthest, body.pos.x)
			assert_lt(
				furthest,
				BULKHEAD_A - rules.body_radius + 0.01,
				"%s, pressing %s: held aft of A" % [room_name, stick]
			)
			assert_almost_eq(body.pos.y, room.floor_height, 0.01, "%s: on its floor" % room_name)
