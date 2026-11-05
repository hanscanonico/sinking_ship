extends GutTest
## The sinking bake's loops natively (#411, NativeSink) against the GDScript they stand
## in for, bit for bit: on her real ships' bakes, every held head solved alone or
## together and every sweep of the openings, worked both ways from the same state; on
## those states made harder — heads set on every sill, lintel, floor and ceiling and a
## hair either side, cells let go or held — every opening's flow, every cell's surplus,
## water and height and every pair's common level; her boxes turned to attitudes that
## drop a spread or two; and linear systems with zeros, infinities and NaNs in them.
## Where the extension is not loaded there is nothing to hold it to; CI sets
## SINKING_NATIVE_REQUIRED, so a missing library there fails.

const SHIPS: Array[StringName] = [&"steamer", &"small_titanic"]
const SEED := 4
## Each ship's window of her first bake checked: the steps taken first, natively alone,
## and the steps checked.
const WINDOWS := {&"steamer": Vector2i(0, 900), &"small_titanic": Vector2i(600, 300)}


## A stepper that works every solve and sweep natively and in GDScript, keeps the
## native answer and notes any difference.
class Checked:
	extends SinkStepper

	## Every how many steps the made-up heads are tried, and a hair: what a head is set
	## off a sill or a floor by, either way.
	const FUZZ_EVERY := 30
	const HAIR := 1e-12

	var differences: Array[String] = []
	var asked := {&"balanced": 0, &"newton": 0, &"sweep": 0, &"made_up": 0}
	var rng := RandomNumberGenerator.new()
	## Off until the window checked: before it, the native answer alone.
	var checking := false
	var _sweeps := 0

	func _balanced(
		cell: int, water: float, heads: PackedFloat64Array, sea: float, since: float, seconds: float
	) -> float:
		if not checking:
			return super._balanced(cell, water, heads, sea, since, seconds)
		var native: SinkNative = _native
		var answer := super._balanced(cell, water, heads, sea, since, seconds)
		_native = null
		var reference := super._balanced(cell, water, heads, sea, since, seconds)
		_native = native
		asked[&"balanced"] += 1
		if not same(answer, reference):
			note("balanced cell %d: %s, not %s" % [cell, answer, reference])
		return answer

	func _newton(
		held: PackedInt32Array,
		state: FloodState,
		heads: PackedFloat64Array,
		sea: float,
		seconds: float
	) -> bool:
		if not checking:
			return super._newton(held, state, heads, sea, seconds)
		var mine := heads.duplicate()
		var native: SinkNative = _native
		var answer := super._newton(held, state, heads, sea, seconds)
		_native = null
		var reference := super._newton(held, state, mine, sea, seconds)
		_native = native
		asked[&"newton"] += 1
		if answer != reference or not alike(heads, mine):
			note("newton of %s closed %s, not %s, or left other heads" % [held, answer, reference])
		return answer

	func _sweep(
		state: FloodState, next: FloodState, heads: PackedFloat64Array, sea: float, seconds: float
	) -> PackedFloat64Array:
		if not checking:
			return super._sweep(state, next, heads, sea, seconds)
		_sweeps += 1
		if _sweeps % FUZZ_EVERY == 0:
			made_up(state, heads, sea, seconds)
		var twin := next.copy()
		var mine := heads.duplicate()
		var native: SinkNative = _native
		var answer := super._sweep(state, next, heads, sea, seconds)
		_native = null
		var reference := super._sweep(state, twin, mine, sea, seconds)
		_native = native
		asked[&"sweep"] += 1
		if (
			not alike(answer, reference)
			or not alike(next.water, twin.water)
			or not alike(next.moved, twin.moved)
			or not same(next.sea_given, twin.sea_given)
		):
			note("sweep of step %d: its heads, water, moved or the sea's account" % state.steps)
		return answer

	## The step begun's flows, surpluses, volumes, heights and common levels at heads set
	## on every edge there is, each cell held or let go.
	func made_up(
		state: FloodState, standing: PackedFloat64Array, sea: float, seconds: float
	) -> void:
		var since := state.seconds
		var solving := _solving
		_solving = 0
		for index in _names.size():
			var sides := PackedInt32Array([_first[index], _second[index]])
			var edges := PackedFloat64Array([_bottom[index], _top[index]])
			for side: int in sides:
				if side != OUTSIDE:
					edges.append_array([_floor[side], _ceiling[side], standing[side]])
			edges.append(sea)
			for _try in 2:
				var heads := standing.duplicate()
				for side: int in sides:
					if side != OUTSIDE:
						heads[side] = edged(edges)
				var flips := PackedInt32Array()
				for side: int in sides:
					if side != OUTSIDE and rng.randf() < 0.3:
						flips.append(side)
						_held[side] = 1 - _held[side]
				var at_sea := edged(edges) if rng.randf() < 0.2 else sea
				var answer: float = _native.sink().transfer(index, heads, _held, at_sea, seconds)
				var reference := _transfer(index, heads, at_sea, since, seconds)
				asked[&"made_up"] += 1
				if not same(answer, reference):
					note(
						(
							"transfer %d at %s: %s, not %s"
							% [index, heads_of(heads, sides), answer, reference]
						)
					)
				for side: int in sides:
					if side == OUTSIDE:
						continue
					var at := edged(edges)
					var water := maxf(state.water[side] * rng.randf_range(0.0, 2.0), 0.0)
					var native_surplus: float = _native.sink().surplus(
						side, at, water, heads, _held, at_sea, seconds
					)
					var surplus := _surplus(side, at, water, heads, at_sea, since, seconds)
					if not same(native_surplus, surplus):
						note(
							"surplus of %d at %s: %s, not %s" % [side, at, native_surplus, surplus]
						)
				if sides[0] != OUTSIDE and sides[1] != OUTSIDE:
					var breaks := PackedFloat64Array(
						[_floor[sides[0]], _ceiling[sides[0]], _floor[sides[1]], _ceiling[sides[1]]]
					)
					var total := (
						(
							_boxes[sides[0]].volume(heads[sides[0]])
							+ _boxes[sides[1]].volume(heads[sides[1]])
						)
						* rng.randf_range(0.0, 1.5)
					)
					var level: float = _native.sink().common_level(
						sides[0], sides[1], breaks, total
					)
					var expected := TiltedBox.common_level(
						_boxes[sides[0]], _boxes[sides[1]], breaks.duplicate(), total
					)
					if not same(level, expected):
						note("common level of %s: %s, not %s" % [sides, level, expected])
				for side: int in flips:
					_held[side] = 1 - _held[side]
		_solving = solving
		for cell in _boxes.size():
			check_box(self, cell, rng)

	## One of [param edges], or a hair off it either way.
	func edged(edges: PackedFloat64Array) -> float:
		var edge := edges[rng.randi_range(0, edges.size() - 1)]
		match rng.randi_range(0, 3):
			0:
				return edge - HAIR
			1:
				return edge + HAIR
		return edge

	func heads_of(heads: PackedFloat64Array, sides: PackedInt32Array) -> String:
		var told := PackedStringArray()
		for side: int in sides:
			told.append(var_to_str(heads[side]) if side != OUTSIDE else "sea")
		return ", ".join(told)

	func note(what: String) -> void:
		if differences.size() < 12:
			differences.append(what)

	## Box [param cell]'s volume and height at its edges, a hair off them, and between.
	static func check_box(
		stepper: SinkStepper, cell: int, rng: RandomNumberGenerator
	) -> Array[String]:
		var found: Array[String] = []
		var box: TiltedBox = stepper._boxes[cell]
		var low := box.bottom()
		var high := box.top()
		var heights := PackedFloat64Array(
			[low, high, low - HAIR, low + HAIR, high - HAIR, high + HAIR, low - 1.0, high + 1.0]
		)
		heights.append(rng.randf_range(low, high))
		heights.append((low + high) * 0.5)
		for height: float in heights:
			var native: float = stepper._native.sink().volume(cell, height)
			var reference := box.volume(height)
			if not same(native, reference):
				found.append(
					"volume of %d at %s: %s, not %s" % [cell, var_to_str(height), native, reference]
				)
		var full := box.capacity()
		var waters := PackedFloat64Array(
			[0.0, -1.0, full, full * 2.0, full * (1.0 - 1e-15), 1e-15, full * 0.5]
		)
		waters.append(rng.randf_range(0.0, full))
		for water: float in waters:
			var native: float = stepper._native.sink().height(cell, water)
			var reference := box.height(water)
			if not same(native, reference):
				found.append(
					(
						"height of %d holding %s: %s, not %s"
						% [cell, var_to_str(water), native, reference]
					)
				)
		if stepper is Checked:
			for what in found:
				(stepper as Checked).note(what)
		return found

	## Whether [param a] and [param b] are one float to the bit, or both not a number.
	static func same(a: float, b: float) -> bool:
		if is_nan(a) or is_nan(b):
			return is_nan(a) and is_nan(b)
		return var_to_bytes(a) == var_to_bytes(b)

	static func alike(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
		if a.size() != b.size():
			return false
		for at in a.size():
			if not same(a[at], b[at]):
				return false
		return true


func test_her_bakes_solve_and_sweep_alike() -> void:
	if not _loaded():
		return
	var asked := {}
	for ship: StringName in SHIPS:
		var structure := Fleet.layout(ship).structure
		var scenario := Fleet.scenario(ship)
		var sea := SeaPhysics.load_default()
		var choosing := MustSink.Choosing.new(
			structure, scenario, SeedStreams.derive(SEED, "sink"), sea
		)
		choosing.work(1)
		var damage: HitDamage = choosing._drawn.damage
		var stepper := Checked.new(structure, damage, sea)
		stepper.rng.seed = 1411
		var bake := SinkBake.new(
			stepper, sea, scenario.bake_cap, HullBreak.of(structure, damage, sea)
		)
		var started := Time.get_ticks_msec()
		bake.run(WINDOWS[ship].x)
		var checked := Time.get_ticks_msec()
		stepper.checking = true
		bake.run(WINDOWS[ship].y)
		gut.p(
			(
				"%s: %s over steps %d to %d (%d ms, then %d ms checked)"
				% [
					ship,
					stepper.asked,
					WINDOWS[ship].x,
					bake.steps(),
					checked - started,
					Time.get_ticks_msec() - checked
				]
			)
		)
		assert_eq(stepper.differences, [] as Array[String], "%s solves and sweeps alike" % ship)
		for kind: StringName in stepper.asked:
			asked[kind] = asked.get(kind, 0) + stepper.asked[kind]
	for kind: StringName in asked:
		assert_gt(asked[kind], 0, "her bakes ask for %s" % kind)


func test_her_boxes_turned_hard_over_hold_alike() -> void:
	if not _loaded():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 411
	var structure := Fleet.layout(&"steamer").structure
	var stepper := SinkStepper.new(structure, HitDamage.new(), SeaPhysics.load_default())
	var ups: Array[PackedFloat64Array] = [
		PackedFloat64Array([0.0, 1.0, 0.0]),
		PackedFloat64Array([-0.0, 1.0, -0.0]),
		PackedFloat64Array([1.0, 0.0, 0.0]),
		PackedFloat64Array([0.0, 0.0, -1.0]),
		PackedFloat64Array([0.0, -1.0, 0.0]),
		PackedFloat64Array([1e-9, 1.0, 1e-12]),
		PackedFloat64Array([1e-5, 0.99999, 3e-4]),
		PackedFloat64Array([0.7071067811865476, 0.7071067811865476, 0.0]),
		PackedFloat64Array([0.5773502691896258, -0.5773502691896258, 0.5773502691896258]),
	]
	for _extra in 8:
		ups.append(
			PackedFloat64Array(
				[rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)]
			)
		)
	var found: Array[String] = []
	for up: PackedFloat64Array in ups:
		stepper._turn(
			PackedFloat64Array([1.0, 0.0, 0.0]) + up + PackedFloat64Array([0.0, 0.0, 1.0])
		)
		for cell in stepper._boxes.size():
			found.append_array(Checked.check_box(stepper, cell, rng))
		for index in stepper._names.size():
			var sides := stepper.opening_sides(index)
			var native: float = stepper._native.sink().volume(
				maxi(sides.x, 0), stepper._bottom[index]
			)
			var reference := stepper._boxes[maxi(sides.x, 0)].volume(stepper._bottom[index])
			if not Checked.same(native, reference):
				found.append("volume at opening %d's sill, up %s" % [index, up])
	assert_eq(found.slice(0, 12), [] as Array[String], "her boxes hold alike at every attitude")


func test_linear_systems_solve_alike() -> void:
	if not _loaded():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1912
	var native: Object = ClassDB.instantiate(&"NativeSink")
	var odd := PackedFloat64Array([0.0, 1.0, -1.0, 1e-300, -1e300, 5e-324, INF, -INF, NAN, 1e-7])
	var found: Array[String] = []
	for system in 400:
		var count := rng.randi_range(1, 7)
		var matrix := PackedFloat64Array()
		var values := PackedFloat64Array()
		for at in count * count:
			matrix.append(_entry(rng, odd, system))
		for at in count:
			values.append(_entry(rng, odd, system))
		var answer: PackedFloat64Array = native.solved(matrix, values, count)
		var reference := LinearSystem.solved(matrix, values, count)
		if not Checked.alike(answer, reference):
			found.append("%s = %s: %s, not %s" % [matrix, values, answer, reference])
	assert_eq(found.slice(0, 6), [] as Array[String], "the systems solve alike")


## A matrix entry: mostly ordinary, sparse in the first systems, odd in some.
func _entry(rng: RandomNumberGenerator, odd: PackedFloat64Array, system: int) -> float:
	var roll := rng.randf()
	if roll < 0.3:
		return 0.0
	if system % 4 == 0 and roll < 0.45:
		return odd[rng.randi_range(0, odd.size() - 1)]
	return rng.randf_range(-10.0, 10.0) * pow(10.0, rng.randi_range(-4, 4))


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeSink"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
