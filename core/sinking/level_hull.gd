class_name LevelHull
extends RefCounted
## Her hull held level (§5b.1, SH26: heave only): the volume under a level sea at any
## height, and the height at which she displaces a given volume. Built once from her
## sections: each section's breadth runs straight between the heights of its outline's
## corners, so the hull's volume is exact and quadratic between those heights, and
## inverting it takes one square root — no search, no Vector3, no sine (D4, R21).

## Every corner height of every section, ascending; per stretch between two of them,
## the hull's breadth times length at its foot and how fast that grows per metre up;
## and the volume under each height.
var _heights := PackedFloat64Array()
var _areas := PackedFloat64Array()
var _growth := PackedFloat64Array()
var _volumes := PackedFloat64Array()


func _init(sections: Array[HullSection]) -> void:
	var lines: Array[PackedFloat64Array] = []
	for section: HullSection in sections:
		lines.append(_breadth_lines(section))
	var heights := {}
	for line: PackedFloat64Array in lines:
		for index in range(0, line.size(), 3):
			heights[line[index]] = true
	for height: float in heights.keys():
		_heights.append(height)
	_heights.sort()
	var at := PackedInt32Array()
	at.resize(sections.size())
	_volumes.append(0.0)
	for index in _heights.size() - 1:
		var foot := _heights[index]
		var area := 0.0
		var growth := 0.0
		for section in sections.size():
			var line := lines[section]
			# Each section's stretches run up the global heights in step with them.
			while at[section] + 3 < line.size() and line[at[section] + 3] <= foot:
				at[section] += 3
			var from := at[section]
			if from + 3 >= line.size() or line[from] > foot:
				continue
			var length := sections[section].length
			area += (line[from + 1] + line[from + 2] * (foot - line[from])) * length
			growth += line[from + 2] * length
		_areas.append(area)
		_growth.append(growth)
		var rise := _heights[index + 1] - foot
		_volumes.append(_volumes[index] + area * rise + growth * rise * rise * 0.5)


## The volume under a level sea [param height] up her hull, in m³.
func volume(height: float) -> float:
	if height <= _heights[0]:
		return 0.0
	if height >= _heights[_heights.size() - 1]:
		return _volumes[_volumes.size() - 1]
	var index := _stretch(height)
	var rise := height - _heights[index]
	return _volumes[index] + _areas[index] * rise + _growth[index] * rise * rise * 0.5


## The height of a level sea under which she displaces [param displaced] m³; INF when
## that is more than her whole hull holds.
func height_of(displaced: float) -> float:
	if displaced <= 0.0:
		return _heights[0]
	if displaced > _volumes[_volumes.size() - 1]:
		return INF
	var low := 0
	var high := _volumes.size() - 1
	while high - low > 1:
		var middle := (low + high) >> 1
		if _volumes[middle] <= displaced:
			low = middle
		else:
			high = middle
	var rest := displaced - _volumes[low]
	var area := _areas[low]
	# The root of growth/2 · rise² + area · rise = rest, in the form that keeps its
	# precision where the area is small.
	var root := sqrt(area * area + 2.0 * _growth[low] * rest)
	return _heights[low] + (2.0 * rest / (area + root) if area + root > 0.0 else 0.0)


## The area of her waterplane under a level sea at [param height], in m².
func waterplane(height: float) -> float:
	if height <= _heights[0] or height >= _heights[_heights.size() - 1]:
		return 0.0
	var index := _stretch(height)
	return _areas[index] + _growth[index] * (height - _heights[index])


## Everything her hull holds, in m³.
func whole() -> float:
	return _volumes[_volumes.size() - 1]


## The height of her keel and of the top of everything enclosed.
func bottom() -> float:
	return _heights[0]


func top() -> float:
	return _heights[_heights.size() - 1]


## The stretch between two corner heights that [param height] stands in.
func _stretch(height: float) -> int:
	var low := 0
	var high := _heights.size() - 1
	while high - low > 1:
		var middle := (low + high) >> 1
		if _heights[middle] <= height:
			low = middle
		else:
			high = middle
	return low


## [param section]'s breadth as straight lines between its outline's corner heights:
## per stretch, its foot, the breadth there and how fast it grows per metre up — read
## a quarter and three quarters of the way up the stretch, never at a corner — and a
## last height closing the last stretch.
static func _breadth_lines(section: HullSection) -> PackedFloat64Array:
	var corners := {}
	for point: Vector2 in section.outline:
		corners[float(point.y)] = true
	var heights := PackedFloat64Array()
	for height: float in corners.keys():
		heights.append(height)
	heights.sort()
	var line := PackedFloat64Array()
	for index in heights.size() - 1:
		var foot := heights[index]
		var rise := heights[index + 1] - foot
		var low := _breadth(section, foot + rise * 0.25)
		var high := _breadth(section, foot + rise * 0.75)
		var growth := (high - low) / (rise * 0.5)
		line.append_array(PackedFloat64Array([foot, low - growth * rise * 0.25, growth]))
	line.append_array(PackedFloat64Array([heights[heights.size() - 1], 0.0, 0.0]))
	return line


## How much of the line at [param height] across [param section] lies inside its
## outline, in metres.
static func _breadth(section: HullSection, height: float) -> float:
	var crossings := PackedFloat64Array()
	var outline := section.outline
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if (float(a.y) - height) * (float(b.y) - height) < 0.0:
			crossings.append(a.x + (float(b.x) - a.x) * (height - a.y) / (float(b.y) - a.y))
	crossings.sort()
	var breadth := 0.0
	for pair in crossings.size() / 2:
		breadth += crossings[pair * 2 + 1] - crossings[pair * 2]
	return breadth
