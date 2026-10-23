extends GutTest
## Where a prop is drawn (PropPlacing, #273): a crate at its underside, a ring flat where
## it lies and before its holder's chest when held — its holder found by id in a snapshot
## that lists only some seats (SH22).


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
