class_name LinearSystem
extends RefCounted
## A square system of linear equations solved (SinkStepper's solve together): row by row
## in a fixed order, so the same system gives the same answer to the last bit (D4). Only
## +, −, ×, ÷ on 64-bit floats run here (R21).


## The x for which [param matrix] (rows of [param count]) times x is [param values]:
## Gauss's elimination, the largest pivot first. A row is taken from another only where
## the pivot's row is not 0, and only from a row whose own entry under the pivot is not 0:
## taking factor × 0 leaves every number as it was — none is ever -0, the slopes starting
## at +0 and a difference that comes to 0 being +0 — and a factor of 0 takes nothing.
## Where the factor is not finite, or the pivot is not a number (so every factor is
## not, 0 over it too), the whole row is taken as it stands.
static func solved(
	matrix: PackedFloat64Array, values: PackedFloat64Array, count: int
) -> PackedFloat64Array:
	var m := matrix.duplicate()
	var v := values.duplicate()
	var filled := PackedInt32Array()
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
		# Over a pivot not a number, 0 is no factor of 0: every row is taken whole.
		var known := not is_nan(lead)
		var from := column * count
		filled.clear()
		for at in range(column, count):
			if m[from + at] != 0.0:
				filled.append(at)
		for row in range(column + 1, count):
			var to := row * count
			if known and m[to + column] == 0.0:
				continue
			var factor := m[to + column] / lead
			if factor == 0.0:
				continue
			if is_finite(factor):
				for at: int in filled:
					m[to + at] -= factor * m[from + at]
			else:
				for at in range(column, count):
					m[to + at] -= factor * m[from + at]
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
