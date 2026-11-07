extends GutTest
## Her level hull and her girder natively (NativeLevelHull, NativeGirder) against the
## GDScript they stand in for, bit for bit: LevelHull's heights, areas, growths and
## volumes for her real ships and the pieces a break cuts; HullGirder.measure's worst
## share, where it is and every station's moment, level and turned, the sea all the way up
## her, her cells dry, part full, full and over full; and the Titanic's bake run both
## ways, state for state. Where the extension is not loaded there is nothing to hold it
## to; CI sets SINKING_NATIVE_REQUIRED, so a missing library there fails.

const SHIPS: Array[StringName] = [&"steamer", &"small_titanic", &"titanic"]
const ANGLES: Array[float] = [0.0, 1e-9, -3e-4, 0.02, -0.31, 0.9]
const SEAS: Array[float] = [-100.0, -8.0, -3.0, 0.0, 2.5, 7.0, 15.0, 100.0]
const SEED := 4
## The steps of the Titanic's first bake run both ways.
const BAKE_STEPS := 400


func after_each() -> void:
	LevelHull.native_off = false
	HullGirder.native_off = false


func test_her_level_hulls_are_alike() -> void:
	if not _loaded():
		return
	for ship: StringName in SHIPS:
		var structure := Fleet.layout(ship).structure
		var ends := PieceStructure.span_of(structure)
		var middle := (ends.x + ends.y) * 0.5
		var hulls: Array[ShipStructure] = [
			structure,
			PieceStructure.cut(structure, ends.x, middle),
			PieceStructure.cut(structure, middle, ends.y),
		]
		for at in hulls.size():
			var native := LevelHull.new(hulls[at].sections)
			LevelHull.native_off = true
			var script := LevelHull.new(hulls[at].sections)
			LevelHull.native_off = false
			var what := "%s's hull %d" % [ship, at]
			assert_gt(script._heights.size(), 2, what + " has heights")
			assert_true(_alike(native._heights, script._heights), what + ": the same heights")
			assert_true(_alike(native._areas, script._areas), what + ": the same areas")
			assert_true(_alike(native._growth, script._growth), what + ": the same growths")
			assert_true(_alike(native._volumes, script._volumes), what + ": the same volumes")


func test_her_bending_is_alike() -> void:
	if not _loaded():
		return
	var sea := SeaPhysics.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var measured := 0
	for ship: StringName in SHIPS:
		var structure := Fleet.layout(ship).structure
		if structure.strength == null:
			continue
		var motion := ShipMotion.new(structure, sea, 0.0)
		var native := HullGirder.new(structure, sea, motion)
		HullGirder.native_off = true
		var script := HullGirder.new(structure, sea, motion)
		HullGirder.native_off = false
		assert_not_null(native._native, "the native one asks the extension")
		assert_null(script._native, "the other works in GDScript")
		var differences: Array[String] = []
		for angle: float in ANGLES:
			for rotation: PackedFloat64Array in [
				Attitude.pitched(Attitude.level(), angle),
				Attitude.squared(Attitude.rolled(Attitude.pitched(Attitude.level(), angle), angle)),
			]:
				for height: float in SEAS:
					for fill in 6:
						measured += 1
						var state := FloodState.new()
						state.rotation = rotation
						state.sea = height
						state.water = _water(structure, rng, fill)
						var other := state.copy()
						native.measure(state)
						script.measure(other)
						if (
							not _same(state.bending, other.bending)
							or not _same(state.bending_x, other.bending_x)
							or not _alike(native._moments, script._moments)
						):
							differences.append(
								"%s at %s, sea %s, fill %d" % [ship, rotation, height, fill]
							)
		assert_eq(differences, [] as Array[String], "%s's bending is alike" % ship)
	gut.p("%d measured" % measured)


func test_her_bake_runs_alike() -> void:
	if not _loaded():
		return
	var native := _bake(&"titanic", false)
	var script := _bake(&"titanic", true)
	assert_eq(native.steps(), BAKE_STEPS, "the bake runs on")
	assert_eq(native.steps(), script.steps(), "as many steps")
	assert_true(_alike(native.times(), script.times()), "at the same times")
	assert_true(_alike(native.seas(), script.seas()), "the same seas")
	assert_true(_alike(native.rotations(), script.rotations()), "the same attitudes")
	assert_true(_alike(native.waters(), script.waters()), "the same water")


## Each cell's water, by [param fill]: dry, a hair, part full at random, full, over full,
## and all of those mixed.
func _water(structure: ShipStructure, rng: RandomNumberGenerator, fill: int) -> PackedFloat64Array:
	var water := PackedFloat64Array()
	for cell: FloodCell in structure.cells:
		var full := cell.volume()
		var kind := fill if fill < 5 else rng.randi_range(0, 4)
		match kind:
			0:
				water.append(0.0 if rng.randf() < 0.5 else -1e-6)
			1:
				water.append(1e-12)
			2:
				water.append(full * rng.randf())
			3:
				water.append(full)
			_:
				water.append(full * (1.0 + rng.randf()))
	return water


## [param ship]'s first bake run BAKE_STEPS steps, her level hull and girder in GDScript
## when [param script].
func _bake(ship: StringName, script: bool) -> SinkBake:
	var structure := Fleet.layout(ship).structure
	var scenario := Fleet.scenario(ship)
	var sea := SeaPhysics.load_default()
	var choosing := MustSink.Choosing.new(
		structure, scenario, SeedStreams.derive(SEED, "sink"), sea
	)
	choosing.work(1)
	var damage: HitDamage = choosing._drawn.damage
	LevelHull.native_off = script
	HullGirder.native_off = script
	var stepper := SinkStepper.new(structure, damage, sea)
	var bake := SinkBake.new(stepper, sea, scenario.bake_cap, HullBreak.of(structure, damage, sea))
	bake.run(BAKE_STEPS)
	LevelHull.native_off = false
	HullGirder.native_off = false
	return bake


## Whether [param a] and [param b] are one float to the bit, or both not a number.
static func _same(a: float, b: float) -> bool:
	if is_nan(a) or is_nan(b):
		return is_nan(a) and is_nan(b)
	return var_to_bytes(a) == var_to_bytes(b)


static func _alike(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	if a.size() != b.size():
		return false
	for at in a.size():
		if not _same(a[at], b[at]):
			return false
	return true


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeLevelHull") and ClassDB.class_exists(&"NativeGirder"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the game's extension is not loaded (make native)")
	else:
		pass_test("the game's extension is not loaded: nothing to hold it to")
	return false
