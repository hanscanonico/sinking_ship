extends GutTest
## LinearSystem against the dense elimination it stands in for: the same answer to the
## last bit (D4) on sparse systems shaped like the stepper's solve together, on ones whose
## pivots run out, where a factor is not finite and where a pivot is not a number; and the
## answer on a small system.

const SEED := 31
const SYSTEMS := 40
## The most cells a solve together holds, and the share of a row's entries that are set.
const LARGEST := 60
const FILLED := 0.1


## [param matrix] (rows of [param count]) times x is [param values], as SinkStepper
## solved it before LinearSystem: every row taken from every other, whole.
static func _dense(
	matrix: PackedFloat64Array, values: PackedFloat64Array, count: int
) -> PackedFloat64Array:
	var m := matrix.duplicate()
	var v := values.duplicate()
	for column in count:
		var pivot := column
		for row in range(column + 1, count):
			if absf(m[row * count + column]) > absf(m[pivot * count + column]):
				pivot = row
		if pivot != column:
			for at in count:
				var kept := m[column * count + at]
				m[column * count + at] = m[pivot * count + at]
				m[pivot * count + at] = kept
			var kept_value := v[column]
			v[column] = v[pivot]
			v[pivot] = kept_value
		var lead := m[column * count + column]
		if lead == 0.0:
			continue
		for row in range(column + 1, count):
			var factor := m[row * count + column] / lead
			if factor == 0.0:
				continue
			for at in range(column, count):
				m[row * count + at] -= factor * m[column * count + at]
			v[row] -= factor * v[column]
	var x := PackedFloat64Array()
	x.resize(count)
	for row in range(count - 1, -1, -1):
		var sum := v[row]
		for at in range(row + 1, count):
			sum -= m[row * count + at] * x[at]
		var lead := m[row * count + row]
		x[row] = sum / lead if lead != 0.0 else 0.0
	return x


## A system of [param count] rows like a solve together's slopes: a strong diagonal, a
## few entries either side, every other +0 — or with [param weak] its diagonal often 0,
## so pivots run out and rows swap.
static func _sparse(rng: RandomNumberGenerator, count: int, weak: bool) -> PackedFloat64Array:
	var matrix := PackedFloat64Array()
	matrix.resize(count * count)
	for row in count:
		for column in count:
			if row != column and rng.randf() < FILLED:
				matrix[row * count + column] = rng.randf_range(-50.0, 50.0)
		if not weak or rng.randf() < 0.5:
			matrix[row * count + row] = -rng.randf_range(100.0, 2000.0)
	return matrix


static func _values(rng: RandomNumberGenerator, count: int) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	for row in count:
		values.append(rng.randf_range(-1.0, 1.0) if rng.randf() < 0.8 else 0.0)
	return values


func test_sparse_systems_solve_to_the_dense_answers_bit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for system in SYSTEMS:
		var count := rng.randi_range(1, LARGEST)
		var matrix := _sparse(rng, count, system % 2 == 1)
		var values := _values(rng, count)
		var found := LinearSystem.solved(matrix, values, count)
		var expected := _dense(matrix, values, count)
		assert_eq(var_to_bytes(found), var_to_bytes(expected), "system %d of %d" % [system, count])


func test_a_factor_not_finite_takes_the_whole_row() -> void:
	# Infinite over infinite: the factor is NaN, and so is factor × 0, as in the dense.
	var matrix := PackedFloat64Array([INF, 1.0, 0.0, INF, 0.0, 2.0, 0.0, 1.0, 1.0])
	var values := PackedFloat64Array([1.0, 2.0, 3.0])
	var found := LinearSystem.solved(matrix, values, 3)
	assert_eq(var_to_bytes(found), var_to_bytes(_dense(matrix, values, 3)))


func test_a_pivot_not_a_number_takes_every_row_whole() -> void:
	# A NaN pivot: 0 over it is NaN, so the dense takes even a row with 0 under it whole.
	var matrix := PackedFloat64Array([NAN, 1.0, 1.0, 0.0, 2.0, 0.0, 0.0, 0.0, 3.0])
	var values := PackedFloat64Array([1.0, 2.0, 3.0])
	var found := LinearSystem.solved(matrix, values, 3)
	assert_eq(var_to_bytes(found), var_to_bytes(_dense(matrix, values, 3)))


func test_a_small_system_is_solved() -> void:
	var matrix := PackedFloat64Array([2.0, 1.0, 0.0, 1.0, 3.0, 1.0, 0.0, 1.0, 4.0])
	var values := PackedFloat64Array([3.0, 5.0, 5.0])
	var found := LinearSystem.solved(matrix, values, 3)
	for row in 3:
		assert_almost_eq(found[row], 1.0, 1e-12)
