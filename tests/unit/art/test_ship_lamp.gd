extends GutTest

## A minute of a lamp's clock, sampled finer than it flickers.
const SAMPLES := 1800
const MAIN := ShipPower.Power.MAIN
const EMERGENCY := ShipPower.Power.EMERGENCY
const DARK := ShipPower.Power.DARK


func test_a_lamp_burns_steady_while_its_cell_is_lit() -> void:
	for sample in SAMPLES:
		assert_eq(ShipLamp.glow(MAIN, MAIN, sample / 30.0, sample / 30.0), 1.0)


func test_a_lamp_is_out_once_nothing_lights_its_cell() -> void:
	for sample in SAMPLES:
		var since := ShipLamp.FAILING + sample / 30.0
		assert_eq(ShipLamp.glow(DARK, MAIN, since, sample / 30.0), 0.0)


func test_emergency_power_burns_dimmer() -> void:
	var dim := ShipLamp.glow(EMERGENCY, MAIN, ShipLamp.FAILING, 0.0)
	assert_eq(dim, ShipLamp.EMERGENCY_GLOW)
	assert_between(dim, 0.05, 0.6, "dim, never out")


func test_a_lamp_flickers_as_its_power_drops_then_settles() -> void:
	# For FAILING seconds it flickers between its old light and its new, holding the old
	# less of the time as they pass; coming back up, it comes on at once.
	var early := 0
	var late := 0
	for sample in SAMPLES:
		var clock := sample / 30.0
		if ShipLamp.glow(DARK, MAIN, ShipLamp.FAILING * 0.1, clock) > 0.0:
			early += 1
		if ShipLamp.glow(DARK, MAIN, ShipLamp.FAILING * 0.9, clock) > 0.0:
			late += 1
	assert_gt(early, late * 2, "flickering on less as it fails")
	assert_gt(late, 0, "but flickering")
	assert_eq(ShipLamp.glow(MAIN, DARK, 0.0, 0.0), 1.0, "back up at once")


## Rooms of the steamer, floor to ceiling: three on the lower deck, the saloon over
## the engine room.
const ENGINE_ROOM := AABB(Vector3(-3.0, -2.6, -4.8), Vector3(7.0, 2.6, 9.6))
const FORWARD_HOLD := AABB(Vector3(4.0, -2.6, -3.8), Vector3(11.0, 2.6, 7.6))
const AFT_PORT_CABIN := AABB(Vector3(-13.0, -2.6, -4.8), Vector3(4.6, 2.6, 4.1))
const SALOON := AABB(Vector3(0.0, 0.0, -3.3), Vector3(2.9, 2.5, 6.6))


func test_a_lamp_lights_the_room_the_eye_stands_in() -> void:
	assert_true(ShipLamp.relevant(Vector3(0.5, -1.0, 0.0), ENGINE_ROOM, true))


func test_a_lamp_lights_the_next_room_through_its_doorway() -> void:
	# In the engine room's forward doorway, looking into the hold.
	assert_true(ShipLamp.relevant(Vector3(3.8, -1.0, 0.0), FORWARD_HOLD, true))


func test_a_lamp_far_off_or_a_deck_away_is_out() -> void:
	assert_false(ShipLamp.relevant(Vector3(12.0, -1.0, 0.0), AFT_PORT_CABIN, true))
	assert_false(ShipLamp.relevant(Vector3(1.5, 1.6, 0.0), AFT_PORT_CABIN, true))


func test_a_lamp_lights_nothing_through_the_deck_over_or_under_the_eye() -> void:
	assert_false(ShipLamp.relevant(Vector3(1.0, -1.0, 0.0), SALOON, true))
	assert_false(ShipLamp.relevant(Vector3(1.0, 1.6, 0.0), ENGINE_ROOM, true))


func test_a_wrecked_lamp_stays_out_wherever_the_eye_is() -> void:
	assert_false(ShipLamp.relevant(Vector3(0.5, -1.0, 0.0), ENGINE_ROOM, false))


func test_a_fire_wavers_but_never_dies_while_dry() -> void:
	var lowest := 1.0
	var highest := 0.0
	for sample in SAMPLES:
		var flame := ShipLamp.flame(sample / 30.0)
		lowest = minf(lowest, flame)
		highest = maxf(highest, flame)
	assert_gte(lowest, 1.0 - ShipLamp.FIRE_WAVER)
	assert_lte(highest, 1.0)
	assert_gt(highest - lowest, ShipLamp.FIRE_WAVER * 0.5)


func test_each_lamp_draws_its_model_once_in_its_own_glass() -> void:
	var models := {
		ShipLamp.Kind.PENDANT: ShipLamp.PENDANT_MODEL,
		ShipLamp.Kind.CARGO: ShipLamp.CARGO_MODEL,
		ShipLamp.Kind.FIRE: ShipLamp.FIRE_MODEL,
	}
	for kind: ShipLamp.Kind in models:
		var lamp: ShipLamp = autofree(ShipLamp.new())
		var glass := StandardMaterial3D.new()
		var brass := StandardMaterial3D.new()
		var facing := Vector3.BACK if kind == ShipLamp.Kind.FIRE else Vector3.DOWN
		lamp.setup(0.0, glass, brass, kind, facing)
		var parts := lamp.find_children("*", "MeshInstance3D", false, false)
		assert_eq(parts.size(), 1, "one mesh a lamp, swinging with it")
		var part := parts[0] as MeshInstance3D
		assert_eq(part.mesh, ShipModel.named(models[kind]).mesh, "shared by its kind")
		var glowing := 0
		for surface in part.mesh.get_surface_count():
			var drawn := part.get_active_material(surface)
			var paint := part.mesh.surface_get_material(surface).resource_name
			# On the lamp's own instance, never on the shared mesh, or every lamp of its
			# kind would glow and flicker as one.
			assert_eq(part.get_surface_override_material(surface), drawn, "%s its own" % paint)
			assert_eq(drawn == glass, paint == "sconce_glass", "%s in the lamp's glass" % paint)
			if paint == "brass":
				assert_eq(drawn, brass, "its brass the lamp's")
			glowing += 1 if drawn == glass else 0
		assert_eq(glowing, 1, "its glass glows as the lamp burns")
