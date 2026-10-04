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
