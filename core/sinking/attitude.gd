class_name Attitude
extends RefCounted
## Which way the ship points as a whole (§5b.1): a rotation from ship space to the
## world, nine numbers row by row, never three angles. She pitches about the world's
## athwartships axis and rolls about her own length, so her bow never swings off its
## heading (she never yaws); each turn is a small one, built from a power series and
## squared back up, and every step leaves the rotation square — its columns unit and
## at right angles. Only +, −, ×, ÷ and square roots on 64-bit floats run here — no
## sine or cosine (D4, R21).


## Upright: ship space is the world's.
static func level() -> PackedFloat64Array:
	return PackedFloat64Array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])


## [param rotation] pitched by [param angle] radians about the world's athwartships
## axis (+z): a positive angle lifts her bow.
static func pitched(rotation: PackedFloat64Array, angle: float) -> PackedFloat64Array:
	var turn := _turn(angle)
	var c := turn[0]
	var s := turn[1]
	var made := rotation.duplicate()
	for column in 3:
		var x := rotation[column]
		var y := rotation[3 + column]
		made[column] = c * x - s * y
		made[3 + column] = s * x + c * y
	return made


## [param rotation] rolled by [param angle] radians about her own length (+x): a
## positive angle puts her starboard side down.
static func rolled(rotation: PackedFloat64Array, angle: float) -> PackedFloat64Array:
	var turn := _turn(angle)
	var c := turn[0]
	var s := turn[1]
	var made := rotation.duplicate()
	for row in 3:
		var y := rotation[row * 3 + 1]
		var z := rotation[row * 3 + 2]
		made[row * 3 + 1] = c * y + s * z
		made[row * 3 + 2] = -s * y + c * z
	return made


## [param rotation] squared back up: her length made a unit, her up made a unit at
## right angles to it, her beam the two's cross product.
static func squared(rotation: PackedFloat64Array) -> PackedFloat64Array:
	var ax := rotation[0]
	var ay := rotation[3]
	var az := rotation[6]
	var length := sqrt(ax * ax + ay * ay + az * az)
	ax /= length
	ay /= length
	az /= length
	var bx := rotation[1]
	var by := rotation[4]
	var bz := rotation[7]
	var along := ax * bx + ay * by + az * bz
	bx -= along * ax
	by -= along * ay
	bz -= along * az
	length = sqrt(bx * bx + by * by + bz * bz)
	bx /= length
	by /= length
	bz /= length
	return PackedFloat64Array(
		[
			ax,
			bx,
			ay * bz - az * by,
			ay,
			by,
			az * bx - ax * bz,
			az,
			bz,
			ax * by - ay * bx,
		]
	)


## How far [param rotation] is from square: the most any entry of its transpose
## times itself stands off the identity's.
static func squareness(rotation: PackedFloat64Array) -> float:
	var worst := 0.0
	for i in 3:
		for j in 3:
			var dot := 0.0
			for k in 3:
				dot += rotation[k * 3 + i] * rotation[k * 3 + j]
			worst = maxf(worst, absf(dot - (1.0 if i == j else 0.0)))
	return worst


## The world's up in [param rotation]'s ship axes: x, y, z.
static func up(rotation: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([rotation[3], rotation[4], rotation[5]])


## Where ship point ([param x], [param y], [param z]) stands from her origin along the
## world's horizontal axes under [param rotation]: forward (x), and athwartships (z).
static func ahead(rotation: PackedFloat64Array, x: float, y: float, z: float) -> float:
	return rotation[0] * x + rotation[1] * y + rotation[2] * z


static func abeam(rotation: PackedFloat64Array, x: float, y: float, z: float) -> float:
	return rotation[6] * x + rotation[7] * y + rotation[8] * z


## The sine of [param degrees], within a right angle either way: a power series, so a
## limit in degrees from the data is read without a sine.
static func sine_of_degrees(degrees: float) -> float:
	var x := degrees * PI / 180.0
	var term := x
	var sum := x
	for power in range(3, 16, 2):
		term *= -x * x / (power * (power - 1))
		sum += term
	return sum


## The cosine and sine of a small turn of [param angle] radians: their power series to
## the seventh power, made exactly a unit.
static func _turn(angle: float) -> PackedFloat64Array:
	var square := angle * angle
	var c := 1.0 - square / 2.0 * (1.0 - square / 12.0 * (1.0 - square / 30.0))
	var s := angle * (1.0 - square / 6.0 * (1.0 - square / 20.0 * (1.0 - square / 42.0)))
	var length := sqrt(c * c + s * s)
	return PackedFloat64Array([c / length, s / length])
