extends GutTest
## The sea leaves out every one of her cells whose water is drawn as its own
## (SeaAndSky.cell_mask): however many there are — the Titanic draws more than the 16
## the sea once took, and every cell drawn makes it 84 (#148) — each box is in the mask
## the sea's shader reads, in order along her so it can stop past a point.

const TITANIC := "res://data/ships/titanic.tres"


func test_every_drawn_cell_of_the_titanic_is_in_the_mask() -> void:
	var layout: ShipLayout = load(TITANIC)
	var drawn: Array[AABB] = []
	for box: AABB in InnerWater.boxes(layout.structure, layout.rooms):
		if box.size != Vector3.ZERO:
			drawn.append(box)
	assert_gt(drawn.size(), 16, "more cells than the sea once took")
	var mask := SeaAndSky.cell_mask(drawn)
	assert_eq(mask.get_width(), drawn.size() * 2, "a low and a high texel a box")
	assert_eq(mask.get_height(), 1)
	var found := {}
	for index in drawn.size():
		var low := mask.get_pixel(index * 2, 0)
		var high := mask.get_pixel(index * 2 + 1, 0)
		var box := AABB(
			Vector3(low.r, low.g, low.b), Vector3(high.r - low.r, high.g - low.g, high.b - low.b)
		)
		found[_key(box)] = true
		if index > 0:
			assert_gte(low.r, mask.get_pixel(index * 2 - 2, 0).r, "in order along her")
	for box: AABB in drawn:
		assert_true(found.has(_key(box)), "box at %s" % box.position)


func test_a_ship_with_no_drawn_cell_masks_nothing() -> void:
	var none: Array[AABB] = [AABB()]
	assert_eq(SeaAndSky.cell_mask(none).get_width(), 1, "one empty texel, never a zero image")
	assert_eq(SeaAndSky.cell_count(none), 0)


func _key(box: AABB) -> String:
	return "%s %s" % [box.position.snappedf(0.001), box.end.snappedf(0.001)]
