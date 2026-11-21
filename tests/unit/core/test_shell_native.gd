extends GutTest
## HullSection.shell_at natively (NativeShell) against the GDScript it stands in for, bit
## for bit: over every section of the steamer and the Titanic, at heights from under her
## keel to over her highest point, at each outline point's own height (where an edge
## starts or ends, or lies flat), a hair either side of it, and where she gives NAN — out
## of her reach, at a NAN height, at an infinite one; and shells_at, the same answers in
## one call. Where the extension is not loaded there is nothing to hold it to; CI sets
## SINKING_NATIVE_REQUIRED, so a missing library there fails.

const SHIPS: Array[StringName] = [&"steamer", &"titanic"]
## Between her keel and her top, this many heights evenly.
const STEPS := 40
const HAIR := 1e-6


func after_each() -> void:
	HullSection.native_off = false


func test_her_shell_is_alike() -> void:
	if not _loaded():
		return
	var native: Object = ClassDB.instantiate(&"NativeShell")
	for ship: StringName in SHIPS:
		var asked := 0
		var nans := 0
		var differences: Array[String] = []
		for section: HullSection in Fleet.layout(ship).structure.sections:
			var heights := _heights(section)
			for side: int in [-1, 1]:
				HullSection.native_off = true
				var script := PackedFloat64Array()
				for y: float in heights:
					script.append(section.shell_at(y, side))
				var batched_script := section.shells_at(heights, side)
				HullSection.native_off = false
				var batched: PackedFloat64Array = native.shells_at(section.outline, heights, side)
				for at in heights.size():
					asked += 1
					var y := heights[at]
					var answers: Array[float] = [
						native.shell_at(section.outline, y, side),
						section.shell_at(y, side),
						batched[at],
						batched_script[at],
					]
					if is_nan(script[at]):
						nans += 1
					for answer: float in answers:
						if not _same(answer, script[at]):
							differences.append(
								"section at x %s, y %s, side %d" % [section.x, y, side]
							)
							break
		assert_eq(differences, [] as Array[String], "%s's shell is alike" % ship)
		assert_gt(nans, 0, "%s: some heights are out of her reach" % ship)
		assert_gt(asked - nans, 0, "%s: some reach her shell" % ship)
		gut.p("%s: %d asked, %d NAN" % [ship, asked, nans])


func test_an_outline_too_small_has_no_shell() -> void:
	if not _loaded():
		return
	var native: Object = ClassDB.instantiate(&"NativeShell")
	for outline: PackedVector2Array in [
		PackedVector2Array(), PackedVector2Array([Vector2(1.0, 0.0)])
	]:
		var section := HullSection.new()
		section.outline = outline
		assert_true(is_nan(native.shell_at(outline, 0.0, 1)), "native: NAN")
		HullSection.native_off = true
		assert_true(is_nan(section.shell_at(0.0, 1)), "GDScript: NAN")
		HullSection.native_off = false
		var none: PackedFloat64Array = native.shells_at(outline, PackedFloat64Array(), 1)
		assert_eq(none.size(), 0, "no heights, no answers")


## Where [param section] is asked: STEPS heights from under her keel to over her top, every
## point's height and a hair either side, and NAN and both infinities.
func _heights(section: HullSection) -> PackedFloat64Array:
	var low := INF
	var high := -INF
	var heights := PackedFloat64Array()
	for point: Vector2 in section.outline:
		low = minf(low, point.y)
		high = maxf(high, point.y)
		heights.append_array([point.y, point.y - HAIR, point.y + HAIR])
	for step in STEPS + 1:
		heights.append(lerpf(low - 1.0, high + 1.0, float(step) / STEPS))
	heights.append_array([NAN, INF, -INF])
	return heights


## Whether [param a] and [param b] are one float to the bit, or both not a number.
static func _same(a: float, b: float) -> bool:
	if is_nan(a) or is_nan(b):
		return is_nan(a) and is_nan(b)
	return var_to_bytes(a) == var_to_bytes(b)


func _loaded() -> bool:
	if NativeVersion.has(&"NativeShell"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the game's extension is not loaded (make native)")
	else:
		pass_test("the game's extension is not loaded: nothing to hold it to")
	return false
