extends GutTest
## A shove coming is drawn on the body that throws it (Brawler): its edge, outline
## and forearms heat up — a wind-up's warmth, rising through a charge to full — its
## sparks stream only while it charges, and its coat keeps the seat's colour all
## through. Read off a real held shove, tick by tick, as the view reads the snapshots.

const SEAT := 1


func test_a_charge_fills_from_the_threshold_to_full() -> void:
	var rules := SimFixtures.rules()
	var threshold := Ticks.from_seconds(rules.charge_threshold)
	var full := Ticks.from_seconds(rules.charge_full)
	assert_eq(BrawlerCharge.filled(0.0, threshold, full), 0.0, "a wind-up is no charge")
	assert_eq(BrawlerCharge.filled(threshold, threshold, full), 0.0)
	assert_eq(BrawlerCharge.filled(full, threshold, full), 1.0)
	assert_eq(BrawlerCharge.filled(full + 4.0, threshold, full), 1.0)
	var last := 0.0
	for tick in range(threshold + 1, full + 1):
		var filled := BrawlerCharge.filled(tick, threshold, full)
		assert_gt(filled, last, "fuller every tick held")
		last = filled


func test_a_held_shove_heats_the_body_to_a_peak_at_a_full_charge() -> void:
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	var body := Brawler.new()
	add_child_autofree(body)
	body.setup(SEAT, sim.config.rules, false)
	var clothes := _clothes(body)
	var coat: Color = clothes.get_shader_parameter("coat")
	var sparks: BrawlerCharge = body.find_child("Charge", true, false)
	var then := _entry(sim)
	body.show_state(then, then, 1.0)
	assert_eq(_heat(body), 0.0, "standing, no heat")
	assert_false(sparks.visible)
	var seen := {}
	var last := 0.0
	var full := Ticks.from_seconds(sim.config.rules.charge_full)
	for _tick in full + 6:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
		var now := _entry(sim)
		body.show_state(then, now, 1.0)
		then = now
		var heat := _heat(body)
		match now["action"]:
			PlayerState.Action.WINDUP:
				assert_eq(heat, Brawler.WINDUP_HEAT, "a wind-up glows warm")
				assert_false(sparks.visible, "no sparks before a charge")
			PlayerState.Action.CHARGE:
				assert_true(sparks.visible, "a charge streams sparks")
				assert_gte(heat, last, "and only heats up as it fills")
				assert_gt(heat, Brawler.WINDUP_HEAT - 0.0001)
		seen[now["action"]] = true
		last = heat
		assert_eq(clothes.get_shader_parameter("coat"), coat, "the coat keeps the seat's colour")
	assert_true(seen.has(PlayerState.Action.CHARGE), "the hold became a charge")
	assert_eq(last, 1.0, "full: the peak")
	var edge: Color = _outline(body).get_shader_parameter("ink")
	assert_true(edge.is_equal_approx(ArtPalette.CHARGE), "the outline burns: %s" % edge)
	assert_gt(_outline(body).get_shader_parameter("beat"), 0.99, "throbbing")
	for _tick in Ticks.from_seconds(sim.config.rules.shove_active) + 2:
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	var now := _entry(sim)
	for _frame in 30:
		body.show_state(now, now, 1.0)
		await get_tree().process_frame
	assert_eq(now["action"], PlayerState.Action.RECOVERY)
	assert_eq(_heat(body), 0.0, "cooled once the shove has landed")
	assert_false(sparks.visible)


func test_your_own_arms_heat_up_but_throw_no_sparks() -> void:
	var body := Brawler.new()
	add_child_autofree(body)
	body.setup(SEAT, SimFixtures.rules(), false)
	body.show_as_own_arms(BrawlerAnimation.CLIPS, FirstPersonArms.POSES, FirstPersonArms.ELBOWS)
	await get_tree().process_frame
	assert_null(body.find_child("Charge", true, false), "nothing streams up past the crosshair")


func _entry(sim: MatchSim) -> Dictionary:
	return sim.snapshot()["seats"][0]


func _clothes(body: Brawler) -> ShaderMaterial:
	var mannequin: MeshInstance3D = body.find_child("Mannequin", true, false)
	return mannequin.get_surface_override_material(0)


func _outline(body: Brawler) -> ShaderMaterial:
	return _clothes(body).next_pass


## The heat [param body] shows: its shader's default, 0, until first set.
func _heat(body: Brawler) -> float:
	var heat: Variant = _clothes(body).get_shader_parameter("heat")
	return 0.0 if heat == null else heat
