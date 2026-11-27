extends GutTest
## What the water does to a swimmer's eyes (#861): the frost is its cold's, while it
## swims; the dark and the bar are its breath's, until that is full again.

const SCREEN := Vector2(1152.0, 648.0)


func _entry(state: PlayerState.Body, cold: float, breath: float, out := false) -> Dictionary:
	return {"state": state, "cold": cold, "breath": breath, "out": out}


func test_the_frost_is_the_cold_s_and_only_while_it_swims() -> void:
	var rules := SimFixtures.rules()
	var half := rules.cold_meter * 0.5
	var swimming := _entry(PlayerState.Body.SWIMMING, half, 0.0)
	assert_almost_eq(SwimVeil.cold_gone(swimming, rules), 0.5, 0.0001, "whatever its breath")
	var standing := _entry(PlayerState.Body.GROUNDED, half, rules.breath_meter)
	assert_eq(SwimVeil.cold_gone(standing, rules), 0.0, "on its feet: none")
	assert_eq(SwimVeil.cold_gone({}, rules), 0.0, "nobody's eyes: none")


func test_the_dark_is_the_breath_s_on_its_feet_too() -> void:
	var rules := SimFixtures.rules()
	var full := rules.cold_meter
	var under := _entry(PlayerState.Body.SWIMMING, full, rules.breath_meter * 0.25)
	assert_almost_eq(SwimVeil.breath_left(under, rules), 0.25, 0.0001, "whatever its cold")
	var gasping := _entry(PlayerState.Body.GROUNDED, full, rules.breath_meter * 0.5)
	assert_almost_eq(SwimVeil.breath_left(gasping, rules), 0.5, 0.0001, "getting it back")
	var out := _entry(PlayerState.Body.OUT, 0.0, 0.0, true)
	assert_eq(SwimVeil.breath_left(out, rules), 1.0, "out: nothing to show")
	assert_eq(SwimVeil.breath_left({}, rules), 1.0)


func test_the_veil_shows_each_only_when_it_has_something_to_say() -> void:
	var rules := SimFixtures.rules()
	var veil := SwimVeil.new()
	add_child_autofree(veil)
	assert_eq(veil.size, veil.get_viewport_rect().size, "over the whole screen")
	var frost := veil.get_node("Frost") as CanvasItem
	var dark := veil.get_node("Breathless") as CanvasItem
	var bar := veil.get_node("Breath") as CanvasItem
	veil.show_for(_entry(PlayerState.Body.GROUNDED, rules.cold_meter, rules.breath_meter), rules)
	assert_false(frost.visible or dark.visible or bar.visible, "dry, a full breath: nothing")
	veil.show_for(_entry(PlayerState.Body.SWIMMING, 1.0, rules.breath_meter), rules)
	assert_true(frost.visible, "afloat: the frost")
	assert_false(dark.visible or bar.visible, "and no dark, its head in the air")
	veil.show_for(_entry(PlayerState.Body.SWIMMING, rules.cold_meter, 1.0), rules)
	assert_false(frost.visible, "under, just in: no frost yet")
	assert_true(dark.visible and bar.visible, "the dark, and the breath's bar")
	veil.show_for({}, rules)
	assert_false(frost.visible or dark.visible or bar.visible, "nobody's eyes: nothing")


## The bar stands under the prompt under the crosshair, clear of the plate bottom left,
## and turns as its breath runs low.
func test_the_bar_stands_under_the_crosshair_s_prompt() -> void:
	var bar := SwimVeil.bar_rect(SCREEN)
	assert_almost_eq(bar.get_center().x, SCREEN.x * 0.5, 0.001, "centred")
	assert_gt(bar.position.y, SCREEN.y * 0.5 + FirstPersonHud.PROMPT_BELOW.y, "under the prompt")
	assert_false(bar.intersects(FirstPersonHud.plate_rect(SCREEN)), "clear of the plate")
	assert_eq(SwimVeil.breath_colour(1.0), SwimVeil.AIR)
	assert_eq(SwimVeil.breath_colour(SwimVeil.BREATH_LOW * 0.5), SwimVeil.GASPING)
