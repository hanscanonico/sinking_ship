class_name RoofedIndoors
extends RefCounted
## Roofed space inside her that no room holds, under her lowest weather deck: the
## strips between her rooms' side walls and her shell, a door's recess in a bulkhead, a
## ladder's well. ShipArt lights and paints it as indoors, not as weather — no sun, no
## sea's lap and tint on its dry walls (#357; the owner's ruling, "below C deck only", her
## lowest weather deck the Titanic's after well deck, on C deck). Over it her covered
## promenades stay weather; her shell's outside, and the sea's, stand outside her
## outline. Placement — lamps, fittings, debris — keeps asking ShipSpace.outdoors alone.
## Read off her data alone (D6).

## How far over a deck's middle weather_floor() reads the air over it.
const WEATHER_PROBE := 1.0
## The side of the squares her platforms are looked up in, in metres.
const CELL := 2.0

var _space: ShipSpace
var _layout: ShipLayout
## Per square of the plane (CELL), her platforms reaching into it, by index.
var _squares := {}
## weather_floor(), worked out once; -INF where the rule holds nowhere.
var _floor := -INF


func _init(space: ShipSpace) -> void:
	_space = space
	_layout = space.layout
	for index in _layout.platforms.size():
		var area := _layout.platforms[index].area
		var first := _square(area.position.x, area.position.y)
		var last := _square(area.end.x, area.end.y)
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var key := Vector2i(x, z)
				if not _squares.has(key):
					_squares[key] = PackedInt32Array()
				_squares[key].append(index)
	_floor = _weather_floor()


## Whether ship point [param point] stands in roofed space inside her under her lowest
## weather deck: below weather_floor(), inside her shell's outline at its x and height,
## with a deck of hers over it there.
func holds(point: Vector3) -> bool:
	if point.y >= _floor:
		return false
	var section := _layout.structure.section_at(point.x)
	if section == null:
		return false
	var side := 1 if point.z >= 0.0 else -1
	var shell := section.shell_at(point.y, side)
	if is_nan(shell) or point.z * side > shell * side:
		return false
	return _under_a_deck(point)


## The height of her lowest weather deck: the lowest of her platforms with no deck of hers
## over its middle and the air over it, WEATHER_PROBE up, in none of her cells — the
## Titanic's after well deck; never a hold's floor under its open hatch, in its hold's
## cell. -INF for a ship with no structure, or no such deck.
func weather_floor() -> float:
	return _floor


## Whether ship point [param point] stands outdoors as ShipArt paints it:
## ShipSpace.outdoors with [param boxes], but for roofed space holds() holds.
func outdoors(point: Vector3, boxes: Array[AABB]) -> bool:
	return _space.outdoors(point, boxes) and not holds(point)


## outdoors() of the probe of each piece of a cut face (ShipMesh.outdoors_over): her
## rooms' answer for the whole face (IndoorGrid.outdoors_over), each piece it calls
## outdoors asked of holds() at its probe, as ShipMesh takes it; empty where her rooms'
## grid cannot answer for the face.
func outdoors_over(
	origin: Vector3,
	u: Vector3,
	v: Vector3,
	u_cuts: PackedFloat32Array,
	v_cuts: PackedFloat32Array,
	normal: Vector3,
	probe: float,
	boxes: Array[AABB]
) -> Array:
	var shows := _space.rooms_grid.outdoors_over(origin, u, v, u_cuts, v_cuts, normal, probe, boxes)
	if shows.is_empty() or is_inf(_floor):
		return shows
	var rows := v_cuts.size() - 1
	for i in u_cuts.size() - 1:
		for j in rows:
			if shows[i * rows + j]:
				var middle := ShipMesh._middle(origin, u, v, u_cuts, v_cuts, i, j)
				shows[i * rows + j] = not holds(middle + normal * probe)
	return shows


## What holds() reads, for the extension (ShipMesh.judge_by): weather_floor(), her
## sections' x and length in turn and their outlines, in order, and her platforms' areas
## and heights.
func shape() -> Array:
	var sections := PackedFloat64Array()
	var outlines: Array[PackedVector2Array] = []
	if _layout.structure != null:
		for section: HullSection in _layout.structure.sections:
			if section != null:
				sections.append_array([section.x, section.length])
				outlines.append(section.outline)
	var areas: Array[Rect2] = []
	var heights := PackedFloat64Array()
	for platform: ShipPlatform in _layout.platforms:
		areas.append(platform.area)
		heights.append(platform.height)
	return [_floor, sections, outlines, areas, heights]


func _weather_floor() -> float:
	if _layout.structure == null:
		return -INF
	var lowest := INF
	for platform: ShipPlatform in _layout.platforms:
		if platform.height >= lowest:
			continue
		var middle := platform.area.get_center()
		var air := Vector3(middle.x, platform.height + WEATHER_PROBE, middle.y)
		if not _under_a_deck(air) and not _in_a_cell(air):
			lowest = platform.height
	return lowest if lowest < INF else -INF


## Whether a platform of hers stands over ship point [param point].
func _under_a_deck(point: Vector3) -> bool:
	for index: int in _squares.get(_square(point.x, point.z), PackedInt32Array()):
		var platform := _layout.platforms[index]
		if platform.height > point.y and platform.contains(point.x, point.z):
			return true
	return false


## Whether ship point [param point] stands in one of her cells' boxes.
func _in_a_cell(point: Vector3) -> bool:
	for cell: FloodCell in _layout.structure.cells:
		if AABB(cell.low, cell.high - cell.low).has_point(point):
			return true
	return false


static func _square(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))
