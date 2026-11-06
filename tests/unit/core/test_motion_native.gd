extends GutTest
## Her lift and her water's load natively (#411, NativeMotion) against the GDScript they
## stand in for, bit for bit: ShipMotion.lift_under — with every section's share —,
## highest and _loaded, on her real ships' hulls and cells, level and turned every way
## to the edge of a right angle and past it, the sea set on every height her outlines
## turn at and a hair either side; her cells' water dry, a hair, part full, full and over
## full; and a bake of hers run both ways, state for state. Where the extension is not
## loaded there is nothing to hold it to; CI sets SINKING_NATIVE_REQUIRED, so a missing
## library there fails.

const SHIPS: Array[StringName] = [&"steamer", &"small_titanic", &"titanic"]
## The angles she is pitched and rolled by, in radians: none, a hair, a little, a lot,
## a right angle and over.
const ANGLES: Array[float] = [0.0, 1e-9, -3e-4, 0.02, -0.31, 0.9, PI * 0.5, -2.2, PI]
## Pitches and rolls that leave her cells' boxes all but edge on along the world's up:
## a spread or two too narrow to count, yet not none (TiltedBox's NARROW_THREE, NARROW_TWO).
const SLIVERS: Array[Vector2] = [
	Vector2(1e-5, 3e-7),
	Vector2(-2e-4, 1e-6),
	Vector2(3e-3, -2e-5),
	Vector2(1e-3, 0.0),
	Vector2(0.0, -2e-3),
	Vector2(4e-6, 4e-6),
]
const HAIR := 1e-9
const SEED := 4
## The steps of the steamer's first bake run both ways.
const BAKE_STEPS := 1500


func test_her_lift_and_highest_are_alike() -> void:
	if not _loaded():
		return
	var sea := SeaPhysics.load_default()
	var asked := 0
	for ship: StringName in SHIPS:
		var structure := Fleet.layout(ship).structure
		var pair := _pair(structure, sea)
		var differences: Array[String] = []
		for rotation: PackedFloat64Array in _rotations():
			for height: float in _seas(structure, rotation):
				asked += 1
				var native_shares := PackedFloat64Array()
				native_shares.resize(structure.sections.size())
				var script_shares := native_shares.duplicate()
				var native := (pair[0] as ShipMotion).lift_under(rotation, height, native_shares)
				var script := (pair[1] as ShipMotion).lift_under(rotation, height, script_shares)
				if not _alike(native, script) or not _alike(native_shares, script_shares):
					differences.append("%s lift at %s, sea %s" % [ship, rotation, height])
				var high := (pair[0] as ShipMotion).highest(rotation, height)
				if not _same(high, (pair[1] as ShipMotion).highest(rotation, height)):
					differences.append("%s highest at %s, sea %s" % [ship, rotation, height])
				# Unasked for, the shares are its own: the same answer.
				var bare := (pair[0] as ShipMotion).lift_under(rotation, height + HAIR)
				if not _alike(bare, (pair[1] as ShipMotion).lift_under(rotation, height + HAIR)):
					differences.append("%s bare lift at %s, sea %s" % [ship, rotation, height])
			if differences.size() > 10:
				break
		assert_eq(differences, [] as Array[String], "%s's lift is alike" % ship)
	gut.p("%d lifts asked" % asked)


func test_her_water_loads_alike() -> void:
	if not _loaded():
		return
	var sea := SeaPhysics.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = 411
	for ship: StringName in SHIPS:
		var structure := Fleet.layout(ship).structure
		var pair := _pair(structure, sea)
		var native_boxes := _boxes(structure, sea)
		var script_boxes := _boxes(structure, sea)
		var differences: Array[String] = []
		var sideways := 0
		for box: TiltedBox in native_boxes:
			sideways += 1 if box.sideways() != 1.0 else 0
		for rotation: PackedFloat64Array in _rotations():
			for fill in 6:
				var water := _water(native_boxes, rng, fill)
				var native := (pair[0] as ShipMotion)._loaded(rotation, water, native_boxes)
				var script := (pair[1] as ShipMotion)._loaded(rotation, water, script_boxes)
				if not _alike(native, script):
					differences.append(
						(
							"%s load at %s, fill %d: %s, not %s"
							% [ship, rotation, fill, native, script]
						)
					)
				# The GDScript leaves a full box turned as it stood: turned on, it still loads alike.
				var up := Attitude.up(Attitude.rolled(rotation, 0.4))
				for box: TiltedBox in script_boxes:
					box.turn(up[0], up[1], up[2])
			if differences.size() > 10:
				break
		assert_eq(differences, [] as Array[String], "%s's water loads alike" % ship)
		gut.p("%s: %d cells, %d counted sideways" % [ship, native_boxes.size(), sideways])


func test_her_bake_runs_alike() -> void:
	if not _loaded():
		return
	var native := _bake(&"steamer", false)
	var script := _bake(&"steamer", true)
	assert_gt(native.steps(), 100, "the bake runs on")
	assert_eq(native.steps(), script.steps(), "as many steps")
	assert_true(_alike(native.times(), script.times()), "at the same times")
	assert_true(_alike(native.seas(), script.seas()), "the same seas")
	assert_true(_alike(native.rotations(), script.rotations()), "the same attitudes")
	assert_true(_alike(native.heads(), script.heads()), "the same heads")
	assert_true(_alike(native.waters(), script.waters()), "the same water")


## A ShipMotion of [param structure] natively, and one in GDScript.
func _pair(structure: ShipStructure, sea: SeaPhysics) -> Array[ShipMotion]:
	ShipMotion.native_off = false
	var native := ShipMotion.new(structure, sea, 0.0)
	ShipMotion.native_off = true
	var script := ShipMotion.new(structure, sea, 0.0)
	ShipMotion.native_off = false
	assert_not_null(native._native, "the native one asks the extension")
	assert_null(script._native, "the other works in GDScript")
	var made: Array[ShipMotion] = [native, script]
	return made


## Her attitudes: level, pitched, rolled and both, by every angle either way, and
## squared back up after; and all but level (SLIVERS).
func _rotations() -> Array[PackedFloat64Array]:
	var found: Array[PackedFloat64Array] = [Attitude.level()]
	for angle: float in ANGLES:
		found.append(Attitude.pitched(Attitude.level(), angle))
		found.append(Attitude.rolled(Attitude.level(), -angle))
		found.append(
			Attitude.squared(Attitude.rolled(Attitude.pitched(Attitude.level(), angle), angle))
		)
	for sliver: Vector2 in SLIVERS:
		found.append(
			Attitude.squared(
				Attitude.rolled(Attitude.pitched(Attitude.level(), sliver.x), sliver.y)
			)
		)
	return found


## Seas up her under [param rotation]: under her keel, over her highest point, and at
## each height her sections' outlines turn at along the world's up, and a hair either
## side — where a section is first cut and last.
func _seas(structure: ShipStructure, rotation: PackedFloat64Array) -> PackedFloat64Array:
	var found := PackedFloat64Array([-100.0, 100.0])
	for at in range(0, structure.sections.size(), maxi(structure.sections.size() / 6, 1)):
		var section := structure.sections[at]
		for point in range(0, section.outline.size(), maxi(section.outline.size() / 5, 1)):
			var corner := section.outline[point]
			var height := rotation[3] * section.x + rotation[5] * corner.x + rotation[4] * corner.y
			found.append_array([height, height - HAIR, height + HAIR])
	return found


func _boxes(structure: ShipStructure, sea: SeaPhysics) -> Array[TiltedBox]:
	var boxes: Array[TiltedBox] = []
	for cell: FloodCell in structure.cells:
		boxes.append(TiltedBox.of(cell, sea))
	return boxes


## Each box's water, by [param fill]: dry, a hair, part full at random, full, over full,
## and all of those mixed.
func _water(boxes: Array[TiltedBox], rng: RandomNumberGenerator, fill: int) -> PackedFloat64Array:
	var water := PackedFloat64Array()
	for box: TiltedBox in boxes:
		var kind := fill if fill < 5 else rng.randi_range(0, 4)
		match kind:
			0:
				water.append(0.0 if rng.randf() < 0.5 else -1e-6)
			1:
				water.append(1e-12)
			2:
				water.append(box.capacity() * rng.randf())
			3:
				water.append(box.capacity())
			_:
				water.append(box.capacity() * (1.0 + rng.randf()))
	return water


## [param ship]'s first bake run BAKE_STEPS steps, its ShipMotion's lift in GDScript
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
	ShipMotion.native_off = script
	var stepper := SinkStepper.new(structure, damage, sea)
	ShipMotion.native_off = false
	var bake := SinkBake.new(stepper, sea, scenario.bake_cap, HullBreak.of(structure, damage, sea))
	bake.run(BAKE_STEPS)
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
	if ClassDB.class_exists(&"NativeMotion"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the game's extension is not loaded (make native)")
	else:
		pass_test("the game's extension is not loaded: nothing to hold it to")
	return false
