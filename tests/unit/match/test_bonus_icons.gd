extends GutTest
## Every kind of bonus has an icon of its own (#307): a glyph its data names
## (BonusKind.icon), drawn in its kind's colour on a dark disc — its badge (BonusIcons) — on
## the HUD, in the grab prompt, and floating over every bonus aboard (BonusGreybox), turned to
## face the eye.

const BONUS_RULES := "res://data/rules/bonuses.tres"


## Each shipped kind names a glyph of its own, and it loads.
func test_every_kind_has_an_icon_of_its_own() -> void:
	var rules: BonusRules = load(BONUS_RULES)
	var icons: Array[StringName] = []
	for kind: BonusKind in rules.kinds:
		assert_false(kind.icon.is_empty(), "%s: an icon" % kind.title)
		assert_false(kind.icon in icons, "%s: one no other kind has" % kind.title)
		icons.append(kind.icon)
		assert_not_null(BonusIcons.glyph(kind), "%s: its glyph loads" % kind.title)
	assert_eq(icons, [&"heart", &"jump", &"anchor", &"arm", &"foot"])
	assert_null(BonusIcons.glyph(SimFixtures.plain_kind()), "a kind with none: its colour alone")


## A badge's texture: the disc dark in its middle, ringed in its kind's colour at its edge,
## clear past it, the glyph in that colour on it — one per kind, made once.
func test_a_badge_is_its_glyph_in_its_colour_on_a_ringed_disc() -> void:
	var kind := SimFixtures.double_life()
	var texture := BonusIcons.texture(kind)
	assert_same(BonusIcons.texture(kind), texture, "made once")
	var image := texture.get_image()
	var side := BonusIcons.TEXTURE_SIDE
	assert_eq(image.get_size(), Vector2i(side, side))
	var corner := image.get_pixel(0, 0)
	assert_eq(corner.a, 0.0, "clear past the disc")
	var middle := side / 2
	assert_lt(_apart(image.get_pixel(middle, 1), kind.mark), 0.02, "the ring")
	# The heart's middle, under the disc's: its glyph in its colour.
	assert_lt(_apart(image.get_pixel(middle, middle), kind.mark), 0.05, "the glyph")
	var disc := image.get_pixel(middle, side / 4 - 2)
	assert_lt(_apart(disc, BonusIcons.DISC), 0.05, "the disc")


## Over every bonus aboard floats its kind's badge, turned to face the eye, over its top.
func test_a_badge_floats_over_every_bonus_aboard() -> void:
	var layout := SimFixtures.below_decks(2)
	var bonuses := SimFixtures.bonus_rules()
	var drawn: BonusGreybox = add_child_autofree(BonusGreybox.new())
	drawn.setup(layout, bonuses)
	var sim := SimFixtures.bonus_sim(bonuses, 1, layout)
	SimFixtures.bring_aboard(sim, 1)
	drawn.show_bonuses(sim.snapshot())
	var shape := drawn.get_node("Bonus0") as MeshInstance3D
	var badge := shape.get_node("Badge") as Sprite3D
	var kind := SimFixtures.double_life()
	assert_same(badge.texture, BonusIcons.texture(kind), "its kind's badge")
	assert_eq(badge.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "facing the eye")
	assert_gt(badge.position.y, kind.height * 0.5, "over its top")
	assert_almost_eq(
		badge.pixel_size * BonusIcons.TEXTURE_SIDE, BonusGreybox.BADGE_SIZE, 1e-6, "its size"
	)


## How far apart [param one] and [param other] are in RGB.
func _apart(one: Color, other: Color) -> float:
	return Vector3(one.r - other.r, one.g - other.g, one.b - other.b).length()
