extends GutTest
## The Titanic's D deck aft of bulkhead N stands where her plates stand it (#399, #503).
## Plate III's D deck line crosses her bulkheads at their measured tops (the generator's
## BULKHEADS: "up to the underside of D deck", BOT), and each stretch of her deck aft of N
## stands at the top of the bulkhead forward of it, on the decks' 1/16 m grain under it:
## aft of N at N's, aft of O at O's, and aft of P at P's. Her deck at P's top runs on
## forward of P through her third-class entrance to the third-class W.C.s' forward face
## (tools/gen_titanic.py's D_STEP_P), where her third-class stairway up rises from it, so
## each bulkhead stands up to the deck aft of it, and P to the deck either side of it. Under
## that stairway's run forward of the step, her deck stands on at P's top: a flight stands
## as a solid wedge on its foot's deck.

## The decks' grain, in metres.
const GRAIN := 1.0 / 16.0
## Her load waterline under C deck, and a foot, in metres (BOT: 30 ft 6 in).
const LOAD_WL := -30.5 * 0.3048
const FT := 0.3048
## Her sheer's step forward of P: the third-class W.C.s' forward face (d.py, px 1420.5).
const STEP_P := -113.3125
## Each bulkhead aft of M her plate reads D deck crossing, its top in feet over her load
## waterline (R32: Plate III, less the 0.9 ft its lines stand over the inquiry's heights).
const TOPS := {"n": 20.9, "o": 21.7, "p": 23.5}
const SLACK := 1e-3

var _layout: ShipLayout


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")


func _bulkhead(letter: String) -> ShipWall:
	for wall: ShipWall in _layout.structure.walls:
		if wall.name == StringName("bulkhead_" + letter):
			return wall
	return null


## Bulkhead [param letter]'s measured top on the decks' grain under it.
func _grain_top(letter: String) -> float:
	return floorf(_bulkhead(letter).top / GRAIN + 1e-6) * GRAIN


## D deck's heights where its platforms' middles stand between x [param aft] and
## [param fore], each once: those under a flight's run when [param under] (her deck under
## the third-class stairway up to C deck, its run over her step forward of P), else the rest.
func _d_deck(aft: float, fore: float, under := false) -> Array:
	var heights := []
	for platform: ShipPlatform in _layout.platforms:
		var middle := platform.area.get_center().x
		if platform.name == &"D deck" and aft < middle and middle < fore:
			if _under_a_flight(platform) == under and not heights.has(platform.height):
				heights.append(platform.height)
	return heights


## Whether a flight's run stands over the middle of [param platform].
func _under_a_flight(platform: ShipPlatform) -> bool:
	for ramp: ShipRamp in _layout.ramps:
		if ramp.area.has_point(platform.area.get_center()):
			return true
	return false


## The floors of her rooms on D deck whose middles stand between x [param aft] and
## [param fore], each once: those between C deck and E deck.
func _room_floors(aft: float, fore: float) -> Array:
	var floors := []
	for room: ShipRoom in _layout.rooms:
		var middle := room.area.get_center().x
		if room.floor_height < -1.0 and room.floor_height > -4.0 and aft < middle and middle < fore:
			if not floors.has(room.floor_height):
				floors.append(room.floor_height)
	return floors


func test_her_bulkheads_aft_stand_at_the_plates_tops() -> void:
	for letter: String in TOPS:
		var wall := _bulkhead(letter)
		assert_not_null(wall, "bulkhead %s is hers" % letter)
		assert_almost_eq(
			wall.top,
			LOAD_WL + TOPS[letter] * FT,
			SLACK,
			"bulkhead %s's top is the plate's" % letter
		)


func test_d_deck_aft_of_each_bulkhead_stands_at_its_top() -> void:
	var n := _bulkhead("n").at
	var o := _bulkhead("o").at
	var p := _bulkhead("p").at
	var stern := -140.0
	assert_eq(_d_deck(o, n), [_grain_top("n")], "between N and O, at N's top")
	assert_eq(_d_deck(STEP_P, o), [_grain_top("o")], "from O to the step forward of P, at O's top")
	assert_eq(_d_deck(p, STEP_P), [_grain_top("p")], "from that step to P, at P's top")
	assert_eq(
		_d_deck(STEP_P, o, true),
		[_grain_top("p")],
		"and on under the third-class stairway's run over the step, the flight's foot's deck"
	)
	assert_eq(_d_deck(stern, p), [_grain_top("p")], "aft of P, at P's top")
	assert_eq(_room_floors(o, n), [_grain_top("n")], "her rooms between N and O stand on it")
	assert_eq(_room_floors(STEP_P, o), [_grain_top("o")], "and between O and the step")
	assert_eq(_room_floors(stern, STEP_P), [_grain_top("p")], "and aft of the step")


func test_each_bulkhead_stands_up_to_the_deck_aft_of_it() -> void:
	# Within the grain: no deck over a bulkhead's top, and none a grain under it.
	for letter: String in TOPS:
		var top := _bulkhead(letter).top
		var deck := _grain_top(letter)
		assert_true(deck <= top and top - deck < GRAIN, "bulkhead %s meets D deck" % letter)
	assert_almost_eq(_grain_top("n"), -2.9375, SLACK, "aft of N, 0.25 m over her flat D deck")
	assert_almost_eq(_grain_top("o"), -2.6875, SLACK, "aft of O, 0.25 m over that")
	assert_almost_eq(_grain_top("p"), -2.1875, SLACK, "aft of P, 0.5 m over that")
