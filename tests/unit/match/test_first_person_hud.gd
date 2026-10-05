extends GutTest
## What the first-person HUD says and where it points (art pass III): the height
## readout names the side of the sea the feet are on, and a windup's wedge stands on
## a side or the bottom edge toward the shove — never the top, never over the rest of
## the HUD — and slides and fades there as the shove comes round.

const SCREEN := Vector2(1152.0, 648.0)
## The most a wedge may move for a degree of bearing: an eighth of its half length.
const STEP := FirstPersonHud.WEDGE_HALF / 8.0
## Half the default field of view across, in degrees: past it a seat is off the screen.
const HALF_VIEW := 45
## The windows a wedge is checked on, and 1152×720: what the UI sees of a 16:10 one.
const SIZES: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1440.0, 900.0), Vector2(1920.0, 1080.0), Vector2(1152.0, 720.0)
]


func test_the_height_reads_above_or_under_the_sea() -> void:
	assert_eq(FirstPersonHud.height_words(2.94), "2.9 m above the sea")
	assert_eq(FirstPersonHud.height_words(-0.2), "0.2 m under the sea", "not -0.2 m above")
	assert_eq(FirstPersonHud.height_words(-1.26), "1.3 m under the sea")
	assert_eq(FirstPersonHud.height_words(-0.04), "At the waterline", "not -0.0 m")
	assert_eq(FirstPersonHud.height_words(0.0), "At the waterline")


func test_a_windup_wedge_stands_beside_or_below_toward_the_shove() -> void:
	var beside := FirstPersonHud.wedge_on_side(SCREEN, deg_to_rad(60.0))
	assert_eq(beside, Vector2(1152.0, 324.0), "just past the view: the side's edge, mid-height")
	assert_eq(FirstPersonHud.wedge_on_side(SCREEN, deg_to_rad(-90.0)), Vector2(0.0, 324.0))
	assert_eq(FirstPersonHud.wedge_behind(SCREEN, PI), Vector2(576.0, 648.0), "dead astern")
	assert_eq(FirstPersonHud.behind_share(deg_to_rad(60.0)), 0.0, "beside is not behind")
	assert_eq(FirstPersonHud.behind_share(PI), 1.0)
	var arrow := FirstPersonHud.wedge_arrow(deg_to_rad(50.0))
	assert_almost_eq(arrow, Vector2.RIGHT, Vector2.ONE * 0.001, "not up into the corner")
	assert_almost_eq(FirstPersonHud.wedge_arrow(PI), Vector2.DOWN, Vector2.ONE * 0.001)


## Every bearing past the view, a degree at a time, on SIZES: each part of the
## wedge that shows stands on the left, right or bottom edge, clear of the dials, the
## seats-left and clock band, the readouts' plate and the crosshair, and moves and
## fades by small steps — nothing jumps across a corner or flips side in plain view.
func test_a_windup_wedge_keeps_off_the_hud_and_moves_smoothly() -> void:
	for size: Vector2 in SIZES:
		var hud: Array[Rect2] = [
			Rect2(
				size.x - FirstPersonHud.DIALS.x, 0.0, FirstPersonHud.DIALS.x, FirstPersonHud.DIALS.y
			),
			Rect2(0.0, 0.0, size.x, FirstPersonHud.CHEVRON_TOP),
			FirstPersonHud.plate_rect(size),
			Rect2(size * 0.5 - Vector2(24.0, 24.0), Vector2(48.0, 48.0)),
		]
		var last := {}
		for degrees in range(HALF_VIEW + 1, 360 - HALF_VIEW):
			var bearing := deg_to_rad(degrees if degrees <= 180 else degrees - 360)
			var behind := FirstPersonHud.behind_share(bearing)
			var parts := {
				"side": [FirstPersonHud.wedge_on_side(size, bearing), 1.0 - behind],
				"bottom": [FirstPersonHud.wedge_behind(size, bearing), behind],
			}
			var arrow := FirstPersonHud.wedge_arrow(bearing)
			assert_true(arrow.y >= 0.0, "%d°: the arrow never points up" % degrees)
			if absf(arrow.x) > 0.001:
				assert_eq(signf(arrow.x), signf(bearing), "%d°: toward the shove's side" % degrees)
			for part: String in parts:
				var root: Vector2 = parts[part][0]
				var strength: float = parts[part][1]
				if strength <= 0.0:
					continue
				var on_side := root.x == 0.0 or root.x == size.x
				assert_true(
					on_side or root.y == size.y, "%d° %s on an edge: %s" % [degrees, part, root]
				)
				assert_true(root.y > 0.0, "%d° %s: never the top edge" % [degrees, part])
				var inward := FirstPersonHud.wedge_inward(size, root)
				var box := FirstPersonHud.wedge_box(root, inward)
				for rect: Rect2 in hud:
					assert_false(
						box.intersects(rect), "%s %d° %s over %s" % [size, degrees, part, rect]
					)
				if last.has(part) and last[part][1] > 0.0:
					var moved: float = root.distance_to(last[part][0])
					assert_lt(moved, STEP, "%s %d° %s jumps %.0f px" % [size, degrees, part, moved])
					assert_lt(absf(strength - last[part][1]), 0.05, "and fades smoothly")
			last = parts


## Two or three shoves winding up on one side, or behind, stand apart along their
## edge — the same places for the same seats every frame — and still clear of the
## rest of the HUD.
func test_windup_wedges_on_one_edge_stand_apart() -> void:
	for size: Vector2 in SIZES:
		var hud: Array[Rect2] = [
			Rect2(
				size.x - FirstPersonHud.DIALS.x, 0.0, FirstPersonHud.DIALS.x, FirstPersonHud.DIALS.y
			),
			Rect2(0.0, 0.0, size.x, FirstPersonHud.CHEVRON_TOP),
			FirstPersonHud.plate_rect(size),
		]
		for degrees: Array in [[60, 62], [-70, -70, -95], [175, 178], [-150, 170, 180], [80, 130]]:
			var bearings := PackedFloat32Array()
			for degree: int in degrees:
				bearings.append(deg_to_rad(degree))
			var roots := FirstPersonHud.wedges_apart(size, bearings)
			assert_eq(roots, FirstPersonHud.wedges_apart(size, bearings), "the same every frame")
			var shown: Array[Vector2] = []
			for index in bearings.size():
				var behind := FirstPersonHud.behind_share(bearings[index])
				if behind < 1.0:
					shown.append(roots[index * 2])
				if behind > 0.0:
					shown.append(roots[index * 2 + 1])
			for one in shown.size():
				var inward := FirstPersonHud.wedge_inward(size, shown[one])
				for rect: Rect2 in hud:
					var box := FirstPersonHud.wedge_box(shown[one], inward)
					assert_false(box.intersects(rect), "%s %s over %s" % [size, degrees, rect])
				for other in range(one + 1, shown.size()):
					if FirstPersonHud.wedge_inward(size, shown[other]) != inward:
						continue
					assert_gt(
						shown[one].distance_to(shown[other]),
						FirstPersonHud.ARROW_HALF * 2.0 + 4.0,
						"%s %s: two arrows on one edge stand apart" % [size, degrees]
					)


## A body over the eye's shoulder, its head by the camera's plane, puts its chevron
## tens of thousands of pixels off the screen (seed 7 through seat 6's eyes at
## 0:49.3, about here), where the renderer cannot always fill the triangle: it is
## not drawn, and every chevron that is drawn, at every size it takes, can be
## filled.
func test_a_chevron_is_drawn_only_where_it_can_be_filled() -> void:
	var off := Vector2(-58000.0, 39440.0)
	var lost := FirstPersonHud.chevron_points(off, 0.8)
	assert_true(Geometry2D.triangulate_polygon(lost).is_empty(), "out there it cannot be filled")
	assert_false(FirstPersonHud.chevron_shows(off, SCREEN))
	for size: Vector2 in SIZES:
		var reach := Rect2(Vector2.ZERO, size).grow(FirstPersonHud.READOUT_TEXT)
		var bad := 0
		for x in range(int(reach.position.x), int(reach.end.x), 7):
			for y in range(int(reach.position.y), int(reach.end.y), 7):
				var at := Vector2(x, y) + Vector2(0.37, 0.61)
				if not FirstPersonHud.chevron_shows(at, size):
					continue
				for shrink: float in [FirstPersonHud.FAR_SCALE, 0.8, 1.0]:
					var points := FirstPersonHud.chevron_points(at, shrink)
					if Geometry2D.triangulate_polygon(points).is_empty():
						bad += 1
		assert_eq(bad, 0, "%s: every chevron drawn can be filled" % size)


## Plates that would overlap — several bodies lined up in view — stand apart: the
## nearest where it is, each further one lifted clear over the nearer, the same way
## every frame; plates already apart stay put.
func test_overlapping_plates_stand_apart_the_nearest_unmoved() -> void:
	var piled: Array[Rect2] = [
		Rect2(500.0, 200.0, 60.0, 45.0),
		Rect2(510.0, 205.0, 50.0, 40.0),
		Rect2(490.0, 210.0, 70.0, 40.0),
		Rect2(530.0, 190.0, 40.0, 30.0),
	]
	var lifts := FirstPersonHud.plates_apart(piled, 0.0)
	assert_eq(lifts, FirstPersonHud.plates_apart(piled, 0.0), "the same every frame")
	assert_eq(lifts[0], 0.0, "the nearest stays where it is")
	for one in piled.size():
		assert_gte(lifts[one], 0.0, "lifted, never pushed down")
		var box := piled[one]
		box.position.y -= lifts[one]
		for other in range(one + 1, piled.size()):
			var next := piled[other]
			next.position.y -= lifts[other]
			assert_false(box.intersects(next), "plates %d and %d overlap" % [one, other])
	var apart: Array[Rect2] = [Rect2(100.0, 200.0, 60.0, 40.0), Rect2(400.0, 200.0, 60.0, 40.0)]
	assert_eq(FirstPersonHud.plates_apart(apart, 0.0), PackedFloat32Array([0.0, 0.0]))
	var cramped := FirstPersonHud.plates_apart(piled, 220.0)
	assert_eq(cramped[1], -1.0, "no room over the nearest under the top band: it stays put")


## Plates at fractional pixels — what a projected head and a scaled font give —
## settle too: a Rect2 rounds to float32, and a plate lifted to exactly the gap over
## a nearer one could still meet it at the edge and be lifted to the same place for
## ever, hanging the HUD's draw. Two such pairs, then a seeded spread of crowds.
func test_plates_at_fractional_pixels_settle_apart() -> void:
	var pairs: Array = [
		[
			Rect2(540.455383301, 318.057281494, 45.964611053, 34.484596252),
			Rect2(550.888183594, 354.417633057, 31.510826111, 37.908370972)
		],
		[
			Rect2(503.450134277, 499.379119873, 53.647544861, 40.651897430),
			Rect2(546.594360352, 476.208923340, 38.051544189, 48.448776245)
		],
	]
	for pair: Array in pairs:
		var boxes: Array[Rect2] = []
		boxes.assign(pair)
		_assert_apart(boxes, FirstPersonHud.plates_apart(boxes, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for crowd in 300:
		var boxes: Array[Rect2] = []
		for plate in 8:
			var at := Vector2(rng.randf_range(400.0, 600.0), rng.randf_range(100.0, 500.0))
			boxes.append(
				Rect2(at, Vector2(rng.randf_range(30.0, 90.0), rng.randf_range(30.0, 50.0)))
			)
		_assert_apart(boxes, FirstPersonHud.plates_apart(boxes, 0.0))


## Every plate of [param boxes] lifted by [param lifts] clears every other by the
## gap; none here is pushed into the top band, so none is left stacked.
func _assert_apart(boxes: Array[Rect2], lifts: PackedFloat32Array) -> void:
	var overlaps := 0
	var half := FirstPersonHud.PLATE_GAP * 0.5
	for one in boxes.size():
		assert_gte(lifts[one], 0.0, "plate %d has room to rise" % one)
		var box := boxes[one]
		box.position.y -= lifts[one]
		for other in range(one + 1, boxes.size()):
			var next := boxes[other]
			next.position.y -= lifts[other]
			if box.grow(half).intersects(next.grow(half)):
				overlaps += 1
	assert_eq(overlaps, 0, "%s lifted by %s" % [boxes, lifts])


## A plate floats over the brawler's own hat: a top hat or a bobble stands taller
## than the crown, a cap does not.
func test_a_plate_stands_over_the_hat() -> void:
	var rules := SimFixtures.rules()
	for seat in Brawler.HATS.size():
		var top := Brawler.headgear(seat, rules)
		assert_gte(top, rules.body_height, "never under the crown")
		match Brawler.HATS[seat]:
			Brawler.Hat.TOP:
				assert_gt(top, rules.body_height + 0.12, "a top hat stands tall")
			Brawler.Hat.CAP:
				assert_almost_eq(top, rules.body_height, 0.01, "a cap sits on the crown")
