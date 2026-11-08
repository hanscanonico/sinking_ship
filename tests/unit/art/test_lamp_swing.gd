extends GutTest
## LampSwing steps a dressed ship's lamps in one loop (#410), and every lamp it carries
## hangs, glows and lights to the bit as the same lamp processing as a node of its own
## does, frame by frame: swinging as she turns, coming to rest and woken by a new tick,
## fading as the eye wants it or not, flickering as its power drops, a fire wavering
## and drowned, a lamp wrecked — while none of the lamps it carries processes as a node.
## A fire burning steady only runs its clock on, carried, between its flame's changes.

const FRAMES := 160
## Lamps a side: pendants and cargo lamps drawn by LampGlobes, every fourth a fire.
const LAMPS := 16
## Frames a second, as in the game: a fire's flame changes its mind FIRE_RATE times a
## second, so some eight times over the frames each fire burns.
const FPS := 60

var _ships: Array[Node3D] = []
## Per side — 0 each lamp a node processing on its own, 1 carried by _swing — its lamps.
var _lamps: Array = [[], []]
var _globes: Array[LampGlobes] = []
var _swing: LampSwing
var _frame := 0
var _mismatches: Array[String] = []
var _swung := 0
## Frames a fire was carried by _swing as it stepped, and of those, the frames its flame
## changed its mind and it stepped itself.
var _fires_carried := 0
var _flames_changed := 0
var _was_fps := 0


## The frame's changes, ahead of every lamp: the same to both sides.
class Changes:
	extends Node
	var test

	func _process(_delta: float) -> void:
		test.change()


class Stepper:
	extends Node
	var test

	func _process(delta: float) -> void:
		test.step(delta)


class Checker:
	extends Node
	var test

	func _process(_delta: float) -> void:
		test.check()


func before_each() -> void:
	_ships.clear()
	_lamps = [[], []]
	_globes.clear()
	_mismatches.clear()
	_frame = 0
	_swung = 0
	_fires_carried = 0
	_flames_changed = 0
	_was_fps = Engine.max_fps
	Engine.max_fps = FPS
	_swing = LampSwing.new()
	var brass := StandardMaterial3D.new()
	for side in 2:
		var ship := Node3D.new()
		add_child_autofree(ship)
		_ships.append(ship)
		if side == 1:
			_swing.reset(ship)
		var hung: Array[ShipLamp] = []
		for index in LAMPS:
			var lamp := ShipLamp.new()
			lamp.position = Vector3(index * 1.5, 2.0, 0.0)
			ship.add_child(lamp)
			var glass := StandardMaterial3D.new()
			glass.emission_enabled = true
			glass.emission = ArtPalette.LAMP_GLASS
			var kind := ShipLamp.Kind.PENDANT if index % 2 == 0 else ShipLamp.Kind.CARGO
			if index % 4 == 3:
				kind = ShipLamp.Kind.FIRE
			lamp.setup(index * 1.7, glass, brass, kind, Vector3.FORWARD)
			if side == 1:
				_swing.carry(lamp)
			_lamps[side].append(lamp)
			hung.append(lamp)
		var globes := LampGlobes.new()
		ship.add_child(globes)
		globes.take(hung)
		_globes.append(globes)
	var changes := Changes.new()
	changes.test = self
	changes.process_priority = -1000
	add_child_autofree(changes)
	var stepper := Stepper.new()
	stepper.test = self
	_ships[1].add_child(stepper)
	var checker := Checker.new()
	checker.test = self
	checker.process_priority = 1 << 28
	add_child_autofree(checker)


func after_each() -> void:
	Engine.max_fps = _was_fps


func test_a_carried_lamp_hangs_and_burns_as_one_processing_alone() -> void:
	await wait_process_frames(FRAMES)
	assert_gte(_frame, FRAMES - 2, "every frame checked")
	assert_eq(_mismatches.size(), 0, "\n".join(_mismatches.slice(0, 5)))
	assert_gt(_swung, FRAMES * 4, "carried lamps swung through her turns")
	for lamp: ShipLamp in _lamps[1]:
		assert_false(lamp.is_processing(), "%s does not process as a node" % lamp.name)


func test_a_fire_burning_steady_runs_only_its_clock_on_till_its_flame_changes() -> void:
	await wait_process_frames(FRAMES)
	assert_eq(_mismatches.size(), 0, "\n".join(_mismatches.slice(0, 5)))
	assert_gt(_flames_changed, 8, "carried fires stepped themselves as their flames changed")
	assert_gt(
		_fires_carried - _flames_changed,
		FRAMES,
		"between its flame's changes a fire burning steady did not step itself"
	)


## Turns both ships alike, wakes their lamps on every other frame as a new tick that
## turns her does, but while she holds still, and changes what the lamps show.
func change() -> void:
	var held := _frame >= 60 and _frame < 95
	var turn := 0.0 if held else 0.25 * sin(_frame * 0.21) + _frame * 0.002
	for side in 2:
		_ships[side].basis = Basis(Vector3.FORWARD, turn) * Basis(Vector3.RIGHT, turn * 0.5)
		for index in LAMPS:
			var lamp: ShipLamp = _lamps[side][index]
			if not held and _frame % 2 == 0:
				lamp.wake()
			if _frame == 10:
				lamp.wanted = index % 3 != 0
			if _frame == 30 and index % 2 == 0:
				lamp.power = ShipPower.Power.EMERGENCY
			if _frame == 70:
				lamp.wanted = index % 3 == 0
			if _frame == 100 and index % 4 == 1:
				lamp.power = ShipPower.Power.DARK
			if _frame == 110 and index % 4 == 3:
				lamp.drowned = true
			if _frame == 120 and index == 5:
				lamp.burning = false
			if _frame == 130 and index % 5 == 0:
				lamp.power = ShipPower.Power.MAIN


func step(delta: float) -> void:
	var fires := {}
	for slot in LAMPS:
		if _swing.awake(slot):
			_swung += 1
		if _swing._fast[slot] == LampSwing.Carried.FIRE and _swing.awake(slot):
			fires[slot] = _swing.lamps[slot]._clock
	_swing.step(delta)
	for slot: int in fires:
		_fires_carried += 1
		if _swing.lamps[slot]._clock != fires[slot]:
			_flames_changed += 1


## Every pair of lamps alike to the bit.
func check() -> void:
	for index in LAMPS:
		var alone: ShipLamp = _lamps[0][index]
		var carried: ShipLamp = _lamps[1][index]
		var shown := [_shown(alone, 0), _shown(carried, 1)]
		if var_to_bytes(shown[0]) != var_to_bytes(shown[1]):
			_mismatches.append("frame %d lamp %d: %s vs %s" % [_frame, index, shown[0], shown[1]])
	_frame += 1


## What [param lamp] on [param side] shows: how it hangs, its glass, its light, whether
## it is awake, and how its globe is drawn.
func _shown(lamp: ShipLamp, side: int) -> Array:
	var glass: StandardMaterial3D = lamp._glass
	var light: Light3D = lamp._spot if lamp._spot != null else lamp._light
	var shown := [lamp.transform, lamp.awake(), glass.emission, glass.emission_energy_multiplier]
	shown.append_array([light.light_energy, light.visible, light.light_color, light.transform])
	if lamp.globe() != -1:
		shown.append_array([_globes[side].placed(lamp.globe()), _globes[side].lit(lamp.globe())])
	return shown
