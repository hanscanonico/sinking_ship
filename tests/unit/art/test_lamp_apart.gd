extends GutTest
## A lamp whose model its globes draw (LampGlobes) stands apart from her (top level) while
## its light is out, so her moving spends nothing on it (#410) — and a lamp shown or hidden
## as LampSight wants it (ShipLamp.wanted) lights exactly as one that never stood apart:
## the same light, in the same place to the bit, the same colour, energy, range and
## shadow, swinging as she turns. Each pendant and cargo lamp is hung twice, on two ships
## moved alike: one drawn by globes, one drawing its own model, never apart.

const STEP := 1.0 / 60.0
const FRAMES := 240
const LAMPS := 6

var _ships: Array[Node3D] = []
## Per side — 0 by globes, 1 drawing its own — its lamps.
var _lamps: Array = [[], []]


func before_each() -> void:
	_ships.clear()
	_lamps = [[], []]
	var brass := StandardMaterial3D.new()
	for side in 2:
		var ship := Node3D.new()
		add_child_autofree(ship)
		_ships.append(ship)
		var hung: Array[ShipLamp] = []
		for index in LAMPS:
			var lamp := ShipLamp.new()
			lamp.position = Vector3(index * 1.5, 2.0, index * 0.25)
			ship.add_child(lamp)
			var glass := StandardMaterial3D.new()
			glass.emission_enabled = true
			glass.emission = ArtPalette.LAMP_GLASS
			var kind := ShipLamp.Kind.PENDANT if index % 2 == 0 else ShipLamp.Kind.CARGO
			lamp.setup(index * 1.7, glass, brass, kind)
			lamp.set_process(false)
			_lamps[side].append(lamp)
			hung.append(lamp)
		if side == 0:
			var globes := LampGlobes.new()
			ship.add_child(globes)
			globes.take(hung)


func test_a_lamp_shown_or_hidden_lights_as_one_never_apart() -> void:
	var mismatches: Array[String] = []
	var apart := 0
	var lit := 0
	for frame in FRAMES:
		_change(frame)
		for side in 2:
			for lamp: ShipLamp in _lamps[side]:
				lamp.step(STEP)
		for index in LAMPS:
			var by_globes: ShipLamp = _lamps[0][index]
			var own: ShipLamp = _lamps[1][index]
			var shown := [_shown(by_globes), _shown(own)]
			if var_to_bytes(shown[0]) != var_to_bytes(shown[1]):
				mismatches.append("frame %d lamp %d: %s vs %s" % [frame, index, shown[0], shown[1]])
			assert_false(own.apart(), "a lamp drawing its own model never stands apart")
			var out := not by_globes._light.visible
			if by_globes.apart() != out:
				mismatches.append(
					"frame %d lamp %d: apart %s, out %s" % [frame, index, not out, out]
				)
			apart += 1 if by_globes.apart() else 0
			lit += 0 if out else 1
	assert_eq(mismatches.size(), 0, "\n".join(mismatches.slice(0, 5)))
	assert_gt(apart, FRAMES, "lamps stood apart while out")
	assert_gt(lit, FRAMES, "and lit while shown")


func test_a_lamp_out_stands_apart_and_her_moving_never_reaches_it() -> void:
	var lamp: ShipLamp = _lamps[0][0]
	lamp.wanted = false
	for _frame in roundi(1.0 / STEP):
		lamp.step(STEP)
	assert_true(lamp.apart(), "out, it stands apart")
	var hung := lamp.transform
	_ships[0].position += Vector3(5.0, -1.0, 2.0)
	assert_eq(lamp.transform, hung, "its own transform still hangs it under her")
	lamp.wanted = true
	lamp.step(STEP)
	assert_false(lamp.apart(), "shown, it hangs from her again")
	assert_eq(
		lamp._light.global_transform,
		_ships[0].global_transform * lamp.transform * lamp._light.transform,
		"its light where she has it now"
	)


## Turns and moves both ships alike — she lists and lurches, so lamps swing in the dark
## too — and wants each lamp lit or not as LampSight would, by turns.
func _change(frame: int) -> void:
	var turn := 0.3 * sin(frame * 0.13) + frame * 0.001
	for side in 2:
		_ships[side].basis = Basis(Vector3.FORWARD, turn) * Basis(Vector3.RIGHT, turn * 0.4)
		_ships[side].position = Vector3(frame * 0.05, sin(frame * 0.07), 0.0)
		for index in LAMPS:
			var lamp: ShipLamp = _lamps[side][index]
			if frame == 0:
				lamp.wanted = index % 3 != 0
			if frame == 60:
				lamp.wanted = index % 2 == 0
			if frame == 120:
				lamp.wanted = true
			if frame == 150 and index % 2 == 1:
				lamp.power = ShipPower.Power.EMERGENCY
			if frame == 180:
				lamp.wanted = index % 3 == 0


## What [param lamp]'s light shows: whether, where in the world, and how it lights; and
## how the lamp hangs under her.
func _shown(lamp: ShipLamp) -> Array:
	var light: OmniLight3D = lamp._light
	var shown := [lamp.transform, light.visible, light.light_energy, light.light_color]
	shown.append_array([light.omni_range, light.omni_attenuation, light.shadow_enabled])
	shown.append_array([light.light_cull_mask, light.light_specular])
	shown.append(light.global_transform if light.visible else Transform3D())
	return shown
