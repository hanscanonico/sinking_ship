extends GutTest
## Where a prop is drawn (PropPlacing, #273): a crate at its underside, a ring flat where
## it lies and before its holder's chest when held — its holder found by id in a snapshot
## that lists only some seats (SH22) — and a piece of furniture facing as it is laid,
## turning as it is carried off, and bobbing only as the water lifts it.


## The flat deck carrying one ring.
func _ringed() -> ShipLayout:
	return SimFixtures.crated([SimFixtures.lifebuoy(Vector3.ZERO)])


func _entry(state: PropState.Body, pos: Vector3, holder := -1) -> Dictionary:
	return {"prop": 0, "state": state, "pos": pos, "holder": holder}


func test_a_crate_stands_at_its_underside_and_a_loose_ring_lies_flat() -> void:
	var at := Vector3(1.0, 0.0, 2.0)
	var crated := SimFixtures.crated([SimFixtures.crate(at)])
	var crate := PropPlacing.of(_entry(PropState.Body.GROUNDED, at), crated, 1.0, [])
	assert_eq(crate, Transform3D(Basis.IDENTITY, at))
	var layout := _ringed()
	var ring := PropPlacing.of(_entry(PropState.Body.GROUNDED, at), layout, 1.0, [])
	assert_almost_eq(ring.basis.z, Vector3.UP, Vector3.ONE * 0.001, "its face up")
	assert_almost_eq(ring.origin.y, 0.0, 0.001, "its back on the deck")


func test_a_held_ring_is_drawn_before_its_holder_found_by_seat() -> void:
	var layout := _ringed()
	var feet := Vector3(3.0, 0.0, -1.0)
	# Only seat 5 is listed, first: a snapshot of only some seats.
	var seats := [{"seat": 5, "pos": feet, "facing": PI * 0.5}]
	var held := _entry(PropState.Body.HELD, feet, 5)
	var ring := PropPlacing.of(held, layout, 1.0, seats)
	var ahead := Vector3(0.0, 0.0, 1.0) * PropPlacing.HELD_AHEAD
	var chest := feet + Vector3.UP * PropPlacing.HELD_HEIGHT + ahead
	assert_almost_eq(ring.origin, chest, Vector3.ONE * 0.001, "at its chest, ahead")
	assert_almost_eq(ring.basis.z, Vector3(0.0, 0.0, 1.0), Vector3.ONE * 0.001, "facing its look")
	var unlisted := PropPlacing.of(held, layout, 1.0, [])
	var rides := feet + Vector3.UP * PropPlacing.HELD_HEIGHT
	assert_almost_eq(unlisted.origin, rides, Vector3.ONE * 0.001, "its holder unlisted")


func test_furniture_faces_as_it_is_laid_and_turns_as_it_is_carried_off() -> void:
	var at := Vector3(2.0, 0.0, 1.0)
	var layout := SimFixtures.crated([SimFixtures.chair(at, -90.0)])
	var laid := PropPlacing.of(_entry(PropState.Body.GROUNDED, at), layout, 1.0, [])
	assert_eq(laid.origin, at, "at its underside")
	assert_almost_eq(laid.basis.z, Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001, "facing -z")
	assert_almost_eq(laid.basis.y, Vector3.UP, Vector3.ONE * 0.001, "upright")
	var carried := at + Vector3(1.5, 0.0, 0.0)
	var drawn := PropPlacing.of(_entry(PropState.Body.GROUNDED, carried), layout, 1.0, [])
	var turned := laid.basis.z.angle_to(drawn.basis.z)
	assert_almost_eq(turned, 1.5 * PropPlacing.DRIFT_TURN, 0.001, "turned for each metre")
	assert_almost_eq(drawn.basis.y, Vector3.UP, Vector3.ONE * 0.001, "still upright")


func test_furniture_bobs_and_rocks_only_as_the_water_lifts_it() -> void:
	var at := Vector3(-1.0, 0.0, 0.0)
	var layout := SimFixtures.crated([SimFixtures.table(at)])
	var afloat_on_floor := _entry(PropState.Body.FLOATING, at)
	for tick: float in [0.0, 17.0, 40.0]:
		var still := PropPlacing.of(afloat_on_floor, layout, 1.0, [], tick)
		assert_eq(still.origin, at, "not yet lifted, it stays put")
		assert_almost_eq(still.basis.y, Vector3.UP, Vector3.ONE * 0.001)
	var lifted := at + Vector3.UP * (PropPlacing.LIFTED * 2.0)
	var highest := -INF
	var lowest := INF
	var steepest := 0.0
	for tick in range(0, Ticks.from_seconds(PropPlacing.BOB_SECONDS), 3):
		var drawn := PropPlacing.of(_entry(PropState.Body.FLOATING, lifted), layout, 1.0, [], tick)
		highest = maxf(highest, drawn.origin.y - lifted.y)
		lowest = minf(lowest, drawn.origin.y - lifted.y)
		steepest = maxf(steepest, rad_to_deg(drawn.basis.y.angle_to(Vector3.UP)))
	assert_almost_eq(highest, PropPlacing.BOB, 0.005, "bobbing up to BOB")
	assert_lte(highest, PropPlacing.BOB + 0.0001)
	assert_almost_eq(lowest, -PropPlacing.BOB, 0.005, "and down")
	assert_gt(steepest, 0.5, "rocking")
	assert_lte(steepest, PropPlacing.ROCK_DEG[&"dining_table"] + 0.001, "no more than its rock")
