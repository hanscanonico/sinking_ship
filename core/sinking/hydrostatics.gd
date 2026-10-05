class_name Hydrostatics
extends RefCounted
## How a hull floats when nothing moves (§5b.1): a section or a box cut by the sea's
## plane at any attitude — the volume under it, its centre and its waterplane — the
## height of the sea at which she displaces a given volume, and the attitude at which
## her lift stands straight over her weight. The sea is a plane in ship space, so a
## hull on her side or upside down is cut as one upright. A section stands for its
## whole length at its middle (the strip method). Only +, −, ×, ÷ and square roots
## on 64-bit floats run here — no Vector3, no sine or cosine (D4, R21).

## How near a solved height comes to the volume asked of it, in m³; how near a rest
## brings her lift over her weight, in metres; and the most steps either takes.
const VOLUME_TOLERANCE := 1e-9
const LEVER_TOLERANCE := 1e-9
const SOLVE_STEPS := 60
## The slope a rest's slopes are nudged by to learn how her lever turns with them,
## and the extra list her stability is measured at.
const NUDGE := 1e-6
const HEEL := 0.01
## Below this a length or an area is nothing.
const EPSILON := 1e-12


## The sea in ship space: a ship point p is under it where up · p < [member height],
## up being the world's up in the ship's axes, a unit vector.
class Sea:
	var up_x: float
	var up_y: float
	var up_z: float
	var height: float

	## The world's up along ([param x], [param y], [param z]) in the ship's axes —
	## any length — and the sea [param at] up it from her origin.
	func _init(x: float, y: float, z: float, at: float) -> void:
		var length := sqrt(x * x + y * y + z * z)
		up_x = x / length
		up_y = y / length
		up_z = z / length
		height = at

	## How far under the sea ship point (x, y, z) stands; negative above it.
	func depth(x: float, y: float, z: float) -> float:
		return height - (up_x * x + up_y * y + up_z * z)

	## Her trim: the slope her length makes with the sea, positive bow down.
	func trim() -> float:
		return -up_x / up_y

	## Her list: the slope her beam makes with the sea, positive starboard down.
	func list() -> float:
		return -up_z / up_y

	## The same attitude with the sea [param at] up from her origin.
	func at_height(at: float) -> Sea:
		return Sea.new(up_x, up_y, up_z, at)


## What lies under the sea: its volume and centre, and the waterplane — its area,
## which the volume grows by per metre the sea rises, and its centre. Ship space.
class Cut:
	var volume := 0.0
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var waterplane := 0.0
	var plane_x := 0.0
	var plane_y := 0.0
	var plane_z := 0.0

	## Takes [param other] in with this: volumes and areas added, centres weighed.
	func add(other: Cut) -> void:
		var volume_sum := volume + other.volume
		if volume_sum > Hydrostatics.EPSILON:
			x = (x * volume + other.x * other.volume) / volume_sum
			y = (y * volume + other.y * other.volume) / volume_sum
			z = (z * volume + other.z * other.volume) / volume_sum
		volume = volume_sum
		var area_sum := waterplane + other.waterplane
		if area_sum > Hydrostatics.EPSILON:
			plane_x = (plane_x * waterplane + other.plane_x * other.waterplane) / area_sum
			plane_y = (plane_y * waterplane + other.plane_y * other.waterplane) / area_sum
			plane_z = (plane_z * waterplane + other.plane_z * other.waterplane) / area_sum
		waterplane = area_sum


## The level sea standing at height [param at] in ship space.
static func level(at: float) -> Sea:
	return Sea.new(0.0, 1.0, 0.0, at)


## The sea over a ship trimmed by [param trim] and listed by [param list] — each a
## slope, positive bow down and starboard down — standing [param at] up from her origin.
static func inclined(trim: float, list: float, at: float) -> Sea:
	return Sea.new(-trim, 1.0, -list, at)


## [param section] under [param sea]: its outline cut by the sea's line at its x,
## times its length.
static func cut_section(section: HullSection, sea: Sea) -> Cut:
	var cut := Cut.new()
	var outline := section.outline
	var count := outline.size()
	# In the section's plane the sea is the line up_z·z + up_y·y = level.
	var level_here := sea.height - sea.up_x * section.x
	var zs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	var crossings := PackedFloat64Array()
	var across := sqrt(sea.up_y * sea.up_y + sea.up_z * sea.up_z)
	for index in count:
		var z0: float = outline[index].x
		var y0: float = outline[index].y
		var z1: float = outline[(index + 1) % count].x
		var y1: float = outline[(index + 1) % count].y
		var f0 := sea.up_z * z0 + sea.up_y * y0 - level_here
		var f1 := sea.up_z * z1 + sea.up_y * y1 - level_here
		if f0 <= 0.0:
			zs.append(z0)
			ys.append(y0)
		if (f0 <= 0.0) != (f1 <= 0.0):
			var t := f0 / (f0 - f1)
			var z := z0 + (z1 - z0) * t
			var y := y0 + (y1 - y0) * t
			zs.append(z)
			ys.append(y)
			if across > EPSILON:
				crossings.append((sea.up_z * y - sea.up_y * z) / across)
	var twice := 0.0
	var moment_z := 0.0
	var moment_y := 0.0
	for index in zs.size():
		var next := (index + 1) % zs.size()
		var cross := zs[index] * ys[next] - zs[next] * ys[index]
		twice += cross
		moment_z += (zs[index] + zs[next]) * cross
		moment_y += (ys[index] + ys[next]) * cross
	if twice > EPSILON:
		cut.volume = twice * 0.5 * section.length
		cut.x = section.x
		cut.z = moment_z / (3.0 * twice)
		cut.y = moment_y / (3.0 * twice)
	_waterline(cut, section, sea, crossings, level_here, across)
	return cut


## Into [param cut], [param section]'s strip of waterplane: the stretches of the sea's
## line inside its outline, paired off from [param crossings] — where its edges cross
## the line, measured along it — as the sea at [param level_here] stands
## [param across] up the section's plane.
static func _waterline(
	cut: Cut,
	section: HullSection,
	sea: Sea,
	crossings: PackedFloat64Array,
	level_here: float,
	across: float
) -> void:
	if crossings.size() < 2:
		return
	crossings.sort()
	var chord := 0.0
	var middle := 0.0
	for pair in crossings.size() / 2:
		var from := crossings[pair * 2]
		var to := crossings[pair * 2 + 1]
		chord += to - from
		middle += (to - from) * (from + to) * 0.5
	if chord <= EPSILON:
		return
	middle /= chord
	# The line's nearest point to the section's origin, then along it.
	var base := level_here / (across * across)
	cut.waterplane = chord * section.length / across
	cut.plane_x = section.x
	cut.plane_z = sea.up_z * base - sea.up_y * middle / across
	cut.plane_y = sea.up_y * base + sea.up_z * middle / across


## Every section of [param sections] under [param sea], together.
static func cut_hull(sections: Array[HullSection], sea: Sea) -> Cut:
	var cut := Cut.new()
	for section: HullSection in sections:
		cut.add(cut_section(section, sea))
	return cut


## The box from ([param x0], [param y0], [param z0]) to ([param x1], [param y1],
## [param z1]) under [param sea]: each face clipped to the sea, the volume summed in
## tetrahedra from a point on the sea's plane, so the cut face adds nothing to it.
static func cut_box(
	x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, sea: Sea
) -> Cut:
	var faces: Array[PackedFloat64Array] = [
		PackedFloat64Array([x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0]),
		PackedFloat64Array([x1, y0, z0, x1, y1, z0, x1, y1, z1, x1, y0, z1]),
		PackedFloat64Array([x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1]),
		PackedFloat64Array([x0, y1, z0, x0, y1, z1, x1, y1, z1, x1, y1, z0]),
		PackedFloat64Array([x0, y0, z0, x0, y1, z0, x1, y1, z0, x1, y0, z0]),
		PackedFloat64Array([x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1]),
	]
	# The box's middle dropped onto the sea's plane.
	var off := sea.depth((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var apex := PackedFloat64Array(
		[
			(x0 + x1) * 0.5 + sea.up_x * off,
			(y0 + y1) * 0.5 + sea.up_y * off,
			(z0 + z1) * 0.5 + sea.up_z * off,
		]
	)
	var cut := Cut.new()
	var moment := PackedFloat64Array([0.0, 0.0, 0.0])
	var plane_moment := PackedFloat64Array([0.0, 0.0, 0.0])
	var plane_area := 0.0
	for face: PackedFloat64Array in faces:
		var kept := PackedFloat64Array()
		# Where the face leaves the sea, then where it comes back under it.
		var edge := PackedFloat64Array()
		edge.resize(6)
		var crossed := 0
		for corner in 4:
			var at := corner * 3
			var next := (corner + 1) % 4 * 3
			var f0 := -sea.depth(face[at], face[at + 1], face[at + 2])
			var f1 := -sea.depth(face[next], face[next + 1], face[next + 2])
			if f0 <= 0.0:
				kept.append_array(face.slice(at, at + 3))
			if (f0 <= 0.0) != (f1 <= 0.0):
				var t := f0 / (f0 - f1)
				var slot := 0 if f0 <= 0.0 else 3
				for axis in 3:
					edge[slot + axis] = face[at + axis] + (face[next + axis] - face[at + axis]) * t
				kept.append_array(edge.slice(slot, slot + 3))
				crossed += 1
		for corner in range(1, kept.size() / 3 - 1):
			var volume := _tetrahedron(apex, kept, 0, corner * 3, corner * 3 + 3)
			cut.volume += volume
			for axis in 3:
				moment[axis] += (
					volume
					* (
						apex[axis]
						+ kept[axis]
						+ kept[corner * 3 + axis]
						+ kept[corner * 3 + 3 + axis]
					)
					* 0.25
				)
		if crossed == 2:
			# The cut face shares this edge, running the other way along it.
			var area := _facing_area(apex, edge, 3, 0, sea)
			plane_area += area
			for axis in 3:
				plane_moment[axis] += area * (apex[axis] + edge[axis] + edge[3 + axis]) / 3.0
	if cut.volume > EPSILON:
		cut.x = moment[0] / cut.volume
		cut.y = moment[1] / cut.volume
		cut.z = moment[2] / cut.volume
	if absf(plane_area) > EPSILON:
		cut.waterplane = absf(plane_area)
		cut.plane_x = plane_moment[0] / plane_area
		cut.plane_y = plane_moment[1] / plane_area
		cut.plane_z = plane_moment[2] / plane_area
	return cut


## The signed volume of the tetrahedron from [param apex] to the points at
## [param a], [param b] and [param c] of [param points] (x, y, z each).
static func _tetrahedron(
	apex: PackedFloat64Array, points: PackedFloat64Array, a: int, b: int, c: int
) -> float:
	var ax := points[a] - apex[0]
	var ay := points[a + 1] - apex[1]
	var az := points[a + 2] - apex[2]
	var bx := points[b] - apex[0]
	var by := points[b + 1] - apex[1]
	var bz := points[b + 2] - apex[2]
	var cx := points[c] - apex[0]
	var cy := points[c + 1] - apex[1]
	var cz := points[c + 2] - apex[2]
	return (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)) / 6.0


## The area of the triangle from [param apex] to the points at [param a] and
## [param b] of [param points], signed by whether it turns about the sea's up.
static func _facing_area(
	apex: PackedFloat64Array, points: PackedFloat64Array, a: int, b: int, sea: Sea
) -> float:
	var ax := points[a] - apex[0]
	var ay := points[a + 1] - apex[1]
	var az := points[a + 2] - apex[2]
	var bx := points[b] - apex[0]
	var by := points[b + 1] - apex[1]
	var bz := points[b + 2] - apex[2]
	var nx := ay * bz - az * by
	var ny := az * bx - ax * bz
	var nz := ax * by - ay * bx
	return (nx * sea.up_x + ny * sea.up_y + nz * sea.up_z) * 0.5


## The sea at [param sea]'s attitude, at the height where [param sections] displace
## [param volume]: the draught at which her lift is her weight. A volume more than the
## hull holds leaves the sea over all of her.
static func float_at(sections: Array[HullSection], sea: Sea, volume: float) -> Sea:
	var low := INF
	var high := -INF
	for section: HullSection in sections:
		for point: Vector2 in section.outline:
			var up := sea.up_x * section.x + sea.up_y * point.y + sea.up_z * point.x
			low = minf(low, up)
			high = maxf(high, up)
	var at := (low + high) * 0.5
	for _step in SOLVE_STEPS:
		var cut := cut_hull(sections, sea.at_height(at))
		var off := cut.volume - volume
		if absf(off) <= VOLUME_TOLERANCE:
			break
		if off > 0.0:
			high = at
		else:
			low = at
		var next := at - off / cut.waterplane if cut.waterplane > EPSILON else NAN
		at = next if next > low and next < high else (low + high) * 0.5
	return sea.at_height(at)


## How far her lift under [param sea] — [param cut]'s centre — stands from the vertical
## through her weight's [param centre] (x, y, z), resolved along her length and across
## her beam, level: 0, 0 at rest. Across, positive is to starboard, so on a list to
## starboard a positive lever rights her.
static func lever(cut: Cut, centre: PackedFloat64Array, sea: Sea) -> PackedFloat64Array:
	var dx := cut.x - centre[0]
	var dy := cut.y - centre[1]
	var dz := cut.z - centre[2]
	var up := dx * sea.up_x + dy * sea.up_y + dz * sea.up_z
	return PackedFloat64Array(
		[
			(dx - up * sea.up_x) / sqrt(1.0 - sea.up_x * sea.up_x),
			(dz - up * sea.up_z) / sqrt(1.0 - sea.up_z * sea.up_z),
		]
	)


## Where [param sections] rest displacing [param volume] with their weight's
## [param centre] (x, y, z): the trim and list at which her lift stands straight
## over her weight, near upright, and the sea's height there.
static func rest(sections: Array[HullSection], volume: float, centre: PackedFloat64Array) -> Sea:
	var trim := 0.0
	var list := 0.0
	var sea := float_at(sections, inclined(trim, list, 0.0), volume)
	for _step in SOLVE_STEPS:
		var off := lever(cut_hull(sections, sea), centre, sea)
		if absf(off[0]) <= LEVER_TOLERANCE and absf(off[1]) <= LEVER_TOLERANCE:
			break
		var by_trim := _lever_at(sections, volume, centre, trim + NUDGE, list)
		var by_list := _lever_at(sections, volume, centre, trim, list + NUDGE)
		var a := (by_trim[0] - off[0]) / NUDGE
		var b := (by_list[0] - off[0]) / NUDGE
		var c := (by_trim[1] - off[1]) / NUDGE
		var d := (by_list[1] - off[1]) / NUDGE
		var determinant := a * d - b * c
		if absf(determinant) <= EPSILON:
			break
		trim -= (d * off[0] - b * off[1]) / determinant
		list -= (a * off[1] - c * off[0]) / determinant
		sea = float_at(sections, inclined(trim, list, sea.height), volume)
	return sea


static func _lever_at(
	sections: Array[HullSection],
	volume: float,
	centre: PackedFloat64Array,
	trim: float,
	list: float
) -> PackedFloat64Array:
	var sea := float_at(sections, inclined(trim, list, 0.0), volume)
	return lever(cut_hull(sections, sea), centre, sea)


## Her metacentric height (GM) at [param rest], in metres: how far her lift's lever
## grows per unit of list, listed a little further to starboard — positive when a list
## rights itself.
static func metacentric_height(
	sections: Array[HullSection], volume: float, centre: PackedFloat64Array, rest_at: Sea
) -> float:
	var list := rest_at.list() + HEEL
	var sea := float_at(sections, inclined(rest_at.trim(), list, rest_at.height), volume)
	var at_rest := lever(cut_hull(sections, rest_at), centre, rest_at)
	var listed := lever(cut_hull(sections, sea), centre, sea)
	# From upright, a list of slope HEEL has the sine HEEL / √(1 + HEEL²).
	return (listed[1] - at_rest[1]) * sqrt(1.0 + HEEL * HEEL) / HEEL
