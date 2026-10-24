extends GutTest
## Where her solid props stand, on a grid (PropStands): asked about a point, it answers
## with every prop whose circle's box reaches it — exactly those, in index order, however
## the props are spread over its cells, moved between them, taken off or off the grid.

const COUNT := 120
const AREA := Rect2(-20.0, -6.0, 40.0, 12.0)


## [param count] crates of every size the grid meets, spread over AREA by [param rng].
func _layout(rng: RandomNumberGenerator, count: int) -> ShipLayout:
	var props: Array[ShipProp] = []
	for index in count:
		var crate := SimFixtures.crate(Vector3.ZERO)
		crate.radius = rng.randf_range(0.2, 0.6)
		crate.pos = Vector3(
			rng.randf_range(AREA.position.x, AREA.end.x),
			0.0,
			rng.randf_range(AREA.position.y, AREA.end.y)
		)
		props.append(crate)
	return SimFixtures.crated(props)


## Every prop of [param stands] standing whose circle's box reaches within [param reach]
## of [param x], [param z], but [param except_prop], one by one.
func _reaching(
	stands: PropStands, x: float, z: float, reach: float, except_prop := -1
) -> PackedInt32Array:
	var found := PackedInt32Array()
	for prop in stands.count():
		if prop == except_prop or stands.gone[prop] == 1:
			continue
		var at := stands.feet[prop]
		var within := stands.radii[prop] + reach
		if absf(at.x - x) <= within and absf(at.z - z) <= within:
			found.append(prop)
	return found


func test_near_answers_exactly_the_props_reaching_a_point_in_index_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 273
	var layout := _layout(rng, COUNT)
	var stands := PropStands.new(layout, AREA)
	stands.stand_all(PropState.from_layout(layout))
	for query in 400:
		var x := rng.randf_range(AREA.position.x - 3.0, AREA.end.x + 3.0)
		var z := rng.randf_range(AREA.position.y - 3.0, AREA.end.y + 3.0)
		var reach := rng.randf_range(0.0, 1.5)
		var except := rng.randi_range(-1, COUNT - 1)
		var expected := _reaching(stands, x, z, reach, except)
		var found := stands.near(x, z, reach, except)
		if found != expected:
			fail_test("at (%s, %s) within %s: %s, not %s" % [x, z, reach, found, expected])
			return
	pass_test("every answer was exact")


func test_a_prop_moved_taken_or_off_the_grid_is_found_where_it_stands() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 294
	var layout := _layout(rng, 3)
	var stands := PropStands.new(layout, AREA)
	var crates := PropState.from_layout(layout)
	stands.stand_all(crates)
	var moved := crates[1]
	var from := moved.pos
	moved.pos = Vector3(from.x + PropStands.CELL * 3.0, 0.0, from.z)
	stands.stand(moved)
	assert_false(1 in stands.near(from.x, from.z, 0.0), "gone from where it stood")
	assert_true(1 in stands.near(moved.pos.x, moved.pos.z, 0.0), "found where it went")
	moved.pos = Vector3(AREA.end.x + 25.0, 0.0, AREA.end.y + 9.0)
	stands.stand(moved)
	assert_eq(stands.near(moved.pos.x, moved.pos.z, 0.0), PackedInt32Array([1]), "off the grid")
	moved.body = PropState.Body.HELD
	stands.stand(moved)
	assert_eq(stands.gone[1], 1, "held, it stands nowhere")
	assert_false(1 in stands.near(moved.pos.x, moved.pos.z, 1.0))
	var one: Array[PropState] = [crates[0]]
	stands.stand_all(one)
	assert_eq(stands.gone, PackedByteArray([0, 1, 1]), "only those told of stand")
	stands.clear()
	assert_eq(stands.gone, PackedByteArray([1, 1, 1]))
