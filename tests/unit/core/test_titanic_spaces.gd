extends GutTest
## The Titanic's old voids and empty spaces made places (#148): a gash along each cell of
## her gash band that was nobody's — forward, boiler room 6 and its bunker, Nos. 3, 2 and
## 1 holds deck by deck, the forepeak and its tank; amidships, the bunkers of boiler rooms
## 2 to 5; aft, boiler room 1 and its bunker, the engine, turbine and electric rooms, the
## after holds deck by deck and the after peak; and the double bottoms under them all —
## opens a room in it, over its floor, for someone there to see the sea come in; but not
## No. 2 hold's starboard part beside the firemen's passage, where her bilge leaves nobody
## room.

var _layout: ShipLayout
var _sinking: SinkScenario


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")
	_sinking = Fleet.scenario(&"titanic")


## A hit given by hand on her [param side] side from [param from] to [param to] along
## her, [param depth] under her waterline, 50 mm wide, biting [param bite] inboard.
func _hit(side: int, from: float, to: float, depth: float, bite: float) -> IcebergHit:
	var hit := IcebergHit.new()
	hit.side = side
	hit.start_x = from
	hit.length = to - from
	hit.depth_start = depth
	hit.depth_end = depth
	hit.width = 0.05
	hit.bite = bite
	return hit


func _mapped(hit: IcebergHit) -> HitDamage:
	return HitMapper.map(hit, _layout.structure, _sinking.hit, SeedStreams.derive(1, "sink"))


## [param damage]'s stretch of gash into [param cell], or null.
func _into(damage: HitDamage, cell: StringName) -> ShipOpening:
	for opening: ShipOpening in damage.openings:
		if opening.joins[0] == cell:
			return opening
	return null


func test_a_gash_along_each_old_void_of_her_gash_band_opens_a_place_people_can_be() -> void:
	# Her waterline 10 m over C deck: 9 m under it is her double bottom, 6–7 m her tank top's
	# holds, 4 m their orlop decks, half a metre G deck.
	var gashes := {
		&"db_boiler_room_6": _hit(1, 58.0, 63.0, 9.0, 0.5),
		&"db_hold_3": _hit(1, 75.0, 80.0, 9.0, 0.5),
		&"db_hold_2": _hit(-1, 90.0, 95.0, 9.0, 0.5),
		&"db_hold_1": _hit(1, 103.0, 108.0, 9.0, 0.5),
		&"boiler_room_6": _hit(1, 56.0, 66.0, 6.0, 0.5),
		&"bunker_6": _hit(-1, 68.2, 70.4, 6.0, 0.5),
		&"hold_3_port": _hit(-1, 74.0, 80.0, 7.0, 0.5),
		&"hold_3_starboard": _hit(1, 74.0, 80.0, 7.0, 0.5),
		&"hold_3": _hit(1, 74.0, 80.0, 4.0, 0.5),
		&"hold_2_port": _hit(-1, 90.0, 95.0, 7.0, 0.5),
		&"hold_2": _hit(1, 90.0, 95.0, 4.0, 0.5),
		&"hold_1": _hit(1, 104.0, 108.0, 6.0, 0.5),
		&"hold_1_tween": _hit(-1, 104.0, 108.0, 0.5, 0.5),
		&"db_boiler_room_1": _hit(1, -26.0, -18.0, 9.0, 0.5),
		&"boiler_room_1": _hit(-1, -27.0, -21.0, 6.0, 0.5),
		&"bunker_1": _hit(1, -20.0, -17.0, 6.0, 0.5),
		&"db_engine_room": _hit(-1, -45.0, -32.0, 9.0, 0.5),
		&"engine_room": _hit(1, -45.0, -32.0, 5.0, 0.5),
		&"db_turbine_room": _hit(1, -62.0, -52.0, 9.0, 0.5),
		&"turbine_room": _hit(-1, -62.0, -52.0, 5.0, 0.5),
		&"db_electric_room": _hit(-1, -82.0, -70.0, 9.0, 0.5),
		&"electric_room": _hit(1, -82.0, -70.0, 4.0, 0.5),
		&"electric_room_tween": _hit(-1, -82.0, -70.0, 0.5, 0.5),
		&"db_after_hold_fwd": _hit(1, -98.0, -88.0, 9.0, 0.5),
		&"after_hold_fwd": _hit(-1, -98.0, -88.0, 6.0, 0.5),
		&"after_hold_fwd_orlop": _hit(1, -98.0, -88.0, 2.5, 0.5),
		&"after_hold_fwd_tween": _hit(-1, -98.0, -88.0, 0.5, 0.5),
		&"db_after_hold_aft": _hit(-1, -109.0, -103.0, 9.0, 0.5),
		&"after_hold_aft": _hit(1, -109.0, -103.0, 6.0, 0.5),
		&"after_hold_aft_orlop": _hit(-1, -109.0, -103.0, 2.5, 0.5),
		&"after_hold_aft_tween": _hit(1, -109.0, -103.0, 0.5, 0.5),
		&"after_peak_tween": _hit(1, -120.0, -119.2, 0.5, 0.5),
		&"bunker_2": _hit(-1, -2.0, 1.0, 6.0, 0.5),
		&"bunker_3": _hit(1, 16.5, 18.5, 6.0, 0.5),
		&"bunker_4": _hit(-1, 33.8, 36.0, 6.0, 0.5),
		&"bunker_5": _hit(1, 51.7, 53.6, 6.0, 0.5),
		&"db_boiler_room_2": _hit(1, -14.0, -4.0, 9.0, 0.5),
		&"db_boiler_room_3": _hit(-1, 4.0, 14.0, 9.0, 0.5),
		&"db_boiler_room_4": _hit(1, 22.0, 32.0, 9.0, 0.5),
		&"db_boiler_room_5": _hit(-1, 40.0, 50.0, 9.0, 0.5),
	}
	for cell: StringName in gashes:
		var into := _into(_mapped(gashes[cell]), cell)
		assert_not_null(into, "the gash opens the %s" % cell)
		if into != null:
			assert_true(_layout.opens_place(into), "into a place people can be in the %s" % cell)


func test_the_small_titanic_s_peaks_are_places_people_can_be() -> void:
	# The plates draw hers as tanks and stores nobody enters: her estimated ones stay on the
	# Small Titanic.
	_layout = Fleet.layout(&"small_titanic")
	_sinking = Fleet.scenario(&"small_titanic")
	var gashes := {
		&"forepeak_tank": _hit(1, 116.0, 119.0, 7.0, 0.5),
		&"forepeak": _hit(-1, 116.0, 120.0, 2.0, 0.5),
		&"after_peak_tank": _hit(-1, -120.0, -119.2, 5.0, 0.5),
	}
	for cell: StringName in gashes:
		var into := _into(_mapped(gashes[cell]), cell)
		assert_not_null(into, "the gash opens the %s" % cell)
		if into != null:
			assert_true(_layout.opens_place(into), "into a place people can be in the %s" % cell)
	_layout = Fleet.layout(&"titanic")
	_sinking = Fleet.scenario(&"titanic")


func test_a_deep_gash_under_no_1_hold_s_narrowing_floor_opens_its_double_bottom() -> void:
	# Forward of its manholes, as far as bulkhead A.
	var into := _into(_mapped(_hit(1, 111.0, 115.5, 9.0, 0.5)), &"db_hold_1")
	assert_not_null(into, "the gash opens No. 1 hold's double bottom")
	if into != null:
		assert_true(_layout.opens_place(into), "where a body crawls")


func test_a_deep_bite_through_no_3_hold_s_starboard_part_holes_the_firemen_s_passage() -> void:
	var deep := _mapped(_hit(1, 82.0, 86.0, 7.0, 4.0))
	var passage := _into(deep, &"firemens_passage")
	assert_not_null(passage, "a bite past the hold's starboard part holes the passage")
	if passage != null:
		assert_true(_layout.opens_place(passage), "where the stokers walk")


func test_no_2_hold_s_starboard_part_is_left_nobody_s() -> void:
	# Beside the passage her bilge closes to under a body's width forward of No. 3 hold.
	var shallow := _mapped(_hit(1, 92.0, 98.0, 7.0, 0.5))
	var part := _into(shallow, &"hold_2_starboard")
	assert_not_null(part, "it opens the hold's starboard part")
	if part != null:
		assert_false(_layout.opens_place(part), "too narrow for a body: nobody's")


func test_no_wall_from_under_a_room_s_floor_stands_up_through_it() -> void:
	# The working passage over the turbine room runs aft past D deck's end: its walls rise
	# to C deck there only, never up through the second-class dining saloon's floor.
	var through: Array[String] = []
	for room: ShipRoom in _layout.rooms:
		var inside := room.area.grow(-0.3)
		for blocker: ShipBlocker in _layout.blockers:
			if (
				blocker.shape == ShipBlocker.Shape.BOX
				and blocker.bottom < room.floor_height - 0.05
				and blocker.top > room.floor_height + 0.5
				and blocker.area.intersects(inside)
			):
				through.append("%s through the %s" % [blocker.area, room.name])
	assert_eq(through, [] as Array[String])
