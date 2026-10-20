extends GutTest
## The trawler's old voids made places (#148): a gash along each of her cells that was
## nobody's — her fish hold's wings, her bilges, her fore stores and the engine room's
## cell abaft its room — opens a room in it, over its floor, for someone there to see
## the sea come in. Her engine room's wings stay voids: at the heights gashes run her
## shell leaves no body room beside the engine room's lining.

var _layout: ShipLayout
var _sinking: SinkScenario


func before_all() -> void:
	_layout = Fleet.layout(&"trawler")
	_sinking = Fleet.scenario(&"trawler")


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


func test_a_gash_along_each_old_void_opens_a_place_people_can_be() -> void:
	var gashes := {
		&"hold_wing_p": _hit(-1, 0.0, 4.0, 0.4, 0.3),
		&"hold_wing_s": _hit(1, 0.0, 4.0, 0.4, 0.3),
		&"hold_bilge": _hit(1, 0.0, 4.0, 1.3, 1.5),
		&"engine_bilge": _hit(-1, -9.0, -5.0, 1.3, 1.5),
		&"fore_stores": _hit(1, 8.0, 10.0, 0.5, 0.5),
		# Abaft the engine room's after wall, into her steering gear.
		&"engine_room": _hit(1, -13.5, -11.5, 0.5, 1.0),
	}
	for cell: StringName in gashes:
		var into := _into(_mapped(gashes[cell]), cell)
		assert_not_null(into, "the gash opens the %s" % cell)
		if into != null:
			assert_true(_layout.opens_place(into), "into a place people can be in the %s" % cell)


func test_a_shallow_bite_into_an_engine_room_wing_opens_no_place() -> void:
	var shallow := _mapped(_hit(1, -8.0, -5.0, 0.6, 0.3))
	var wing := _into(shallow, &"engine_wing_s")
	assert_not_null(wing, "it opens the wing")
	assert_eq(shallow.openings.size(), 1, "and only the wing")
	assert_false(_layout.opens_place(wing), "too narrow for a body: nobody's")
	var deep := _mapped(_hit(1, -8.0, -5.0, 0.6, 1.5))
	var room := _into(deep, &"engine_room")
	assert_not_null(room, "a deeper bite holes the engine room behind it")
	if room != null:
		assert_true(_layout.opens_place(room), "where people can be")
