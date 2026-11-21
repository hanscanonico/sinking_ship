extends GutTest
## The lens is wet as the eye comes up out of the water, dries over DRY_SECONDS, and
## draws nothing under the water nor once dry. Only the same eye surfacing wets it: a cut to
## another seat or camera finds the lens dry.

const SEAT := 3
const OTHER_SEAT := 5
const FREE := -1


func test_the_lens_is_wettest_just_surfaced() -> void:
	assert_eq(LensDrops.wetness(0.0), 1.0)


func test_the_lens_is_dry_after_dry_seconds() -> void:
	assert_eq(LensDrops.wetness(LensDrops.DRY_SECONDS), 0.0)
	assert_eq(LensDrops.wetness(LensDrops.DRY_SECONDS + 1.0), 0.0)


func test_the_lens_dries_steadily() -> void:
	var last := LensDrops.wetness(0.0)
	for step in range(1, 26):
		var now := LensDrops.wetness(LensDrops.DRY_SECONDS * step / 25.0)
		assert_lt(now, last, "drier at step %d" % step)
		last = now


func test_a_lens_never_under_is_dry() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, false)
	assert_false(drops.is_wet())


func test_surfacing_wets_the_lens() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, true)
	assert_false(drops.is_wet(), "under the water the view is Underwater's")
	drops.show_eye(SEAT, false)
	assert_true(drops.is_wet())


func test_staying_up_does_not_wet_it_afresh() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, true)
	drops.show_eye(SEAT, false)
	drops._process(LensDrops.DRY_SECONDS * 0.5)
	drops.show_eye(SEAT, false)
	drops._process(LensDrops.DRY_SECONDS * 0.6)
	assert_false(drops.is_wet(), "dry DRY_SECONDS after the one surfacing")


func test_going_under_hides_the_drops_at_once() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, true)
	drops.show_eye(SEAT, false)
	drops.show_eye(SEAT, true)
	assert_false(drops.is_wet())


func test_a_cut_from_an_eye_under_to_another_dry_one_leaves_the_lens_dry() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, true)
	drops.show_eye(OTHER_SEAT, false)
	assert_false(drops.is_wet())


func test_a_cut_from_an_eye_under_to_the_free_camera_leaves_the_lens_dry() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, true)
	drops.show_eye(FREE, false)
	assert_false(drops.is_wet())


func test_a_cut_dries_drops_already_on_the_lens() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, true)
	drops.show_eye(SEAT, false)
	drops.show_eye(FREE, false)
	assert_false(drops.is_wet(), "the free camera's lens is its own")


func test_the_eye_cut_to_wets_the_lens_as_it_surfaces() -> void:
	var drops := _drops()
	drops.show_eye(SEAT, false)
	drops.show_eye(OTHER_SEAT, true)
	drops.show_eye(OTHER_SEAT, false)
	assert_true(drops.is_wet())


func test_a_held_lens_stays_wet() -> void:
	var drops := _drops()
	drops.hold_wet(2.0)
	assert_true(drops.is_wet())
	drops._process(LensDrops.DRY_SECONDS)
	assert_true(drops.is_wet(), "a capture's lens never dries")


func test_the_drops_sit_under_the_hud() -> void:
	var hud := CanvasLayer.new()
	var drops := _drops()
	assert_eq(drops.layer, 0, "Underwater's layer, drawn over it as a later sibling")
	assert_lt(drops.layer, hud.layer, "under the HUD's layer")
	hud.free()


func _drops() -> LensDrops:
	var drops := LensDrops.new()
	drops.set_process(false)
	add_child_autofree(drops)
	return drops
