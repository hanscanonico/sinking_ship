class_name GreyboxHull
extends Node3D
## The greybox's hull, drawn from her data (D6, SH30): the shell her structure's
## sections enclose — each cut across her from her keel up either side to her sheer —
## lofted from section to section along each run of one sheer, flat across her stern
## and closed onto her centreline at her stem,
## in the dressed hull's paint (ship.gdshader's HULL: red oxide under the boot line, a
## pale riband under the sheer, the sea's lap along her waterline); the inside of a
## bulwark standing over a deck as a house's side; her deck plating out to the shell
## where her decks' rectangles stop short of it; and a dark mark at each freeing port
## and porthole of hers. ShipGreybox draws it under a ship with a structure, in place
## of its hull blocks. Drawn only — the sim never reads a mesh — and nothing at or
## above [member cut_above] is.

## Points up each side of a section, keel to sheer, once resampled.
const SIDE_POINTS := 18
## A shell standing this far or more over the deck beside it is a bulwark.
const BULWARK_FROM := 0.1
## A deck's plating stands this far under its planks' top, so the planks show where
## both are.
const PLATE_DROP := 0.01
## Two heights this close are one.
const LEVEL := 1e-3
## How thick a freeing port's or a porthole's mark is, across the shell.
const MARK := 0.08
const PORT_COLOUR := ArtPalette.STEEL
const GLASS_COLOUR := ArtPalette.MIRROR

## Ship-local height: nothing of her at or above it is drawn — the observer's cut-away.
var cut_above := INF

var _mesh: ShipMesh
var _hull := ShipMesh.Paint.new(ShipMesh.Finish.HULL, ArtPalette.HULL)
var _bulwark := ShipMesh.Paint.new(ShipMesh.Finish.HOUSE, ArtPalette.HOUSE)
var _plating := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.DECK)


## Draws [param layout]'s hull from her structure.
func build(layout: ShipLayout) -> void:
	for child: Node in get_children():
		child.queue_free()
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	_mesh = ShipMesh.new(func(_point: Vector3) -> bool: return true, no_rooms)
	_mesh.cut_above = cut_above
	var sections := layout.structure.sections
	var sides: Array[PackedVector2Array] = []
	for section: HullSection in sections:
		for side: float in [1.0, -1.0]:
			sides.append(_resampled(_shell(section.outline, side)))
	for side in 2:
		_loft_shell(sections, sides, side)
	_close_end(sections[0], sides[0], sides[1], -1.0)
	for index in sections.size():
		_bulwarks(layout, sections[index], sides[index * 2], sides[index * 2 + 1])
	_plate_decks(layout)
	_mesh.commit(self, _materials(layout))
	_mark_openings(layout.structure)


## One side of [param outline] — [param side] 1 for starboard, -1 for port — in (z, y)
## from her keel up to her sheer: from where the outline starts, or ends, while it
## climbs and stands out.
static func _shell(outline: PackedVector2Array, side: float) -> PackedVector2Array:
	var count := outline.size()
	var points := PackedVector2Array()
	for step in count:
		var point := outline[step if side > 0.0 else (count - step) % count]
		if not points.is_empty():
			var last := points[points.size() - 1]
			if point.y < last.y - LEVEL or point.x * side < last.x * side - LEVEL:
				break
		points.append(point)
	if absf(points[0].x) > LEVEL:
		points.insert(0, Vector2(0.0, points[0].y))
	return points


## [param line] as SIDE_POINTS points evenly along it.
static func _resampled(line: PackedVector2Array) -> PackedVector2Array:
	if line.size() < 2:
		line = PackedVector2Array([line[0], line[0]])
	var lengths := PackedFloat64Array([0.0])
	for index in range(1, line.size()):
		lengths.append(lengths[index - 1] + line[index].distance_to(line[index - 1]))
	var total := lengths[lengths.size() - 1]
	var points := PackedVector2Array()
	var at := 0
	for step in SIDE_POINTS:
		var reach := total * step / (SIDE_POINTS - 1)
		while at < line.size() - 2 and lengths[at + 1] < reach:
			at += 1
		var span := lengths[at + 1] - lengths[at]
		var t := (reach - lengths[at]) / span if span > 0.0 else 0.0
		points.append(line[at].lerp(line[at + 1], clampf(t, 0.0, 1.0)))
	return points


## The shell on [param side] (0 starboard, 1 port) of [param sections], whose sides are
## [param sides]: lofted from the middle of one section to the next while their sheer
## is one height, out to the ends of each such run.
func _loft_shell(sections: Array[HullSection], sides: Array[PackedVector2Array], side: int) -> void:
	var xs := PackedFloat64Array()
	var lines: Array[PackedVector2Array] = []
	for index in sections.size():
		var section := sections[index]
		var line := sides[index * 2 + side]
		var sheer := line[line.size() - 1].y
		var run_ends := (
			index == 0 or not is_equal_approx(_sheer_of(sides[(index - 1) * 2 + side]), sheer)
		)
		if run_ends:
			_loft(xs, lines, side)
			xs = PackedFloat64Array([section.x - section.length * 0.5])
			lines = [line]
		xs.append(section.x)
		lines.append(line)
		var next_differs := (
			index == sections.size() - 1
			or not is_equal_approx(_sheer_of(sides[(index + 1) * 2 + side]), sheer)
		)
		if next_differs:
			xs.append(section.x + section.length * 0.5)
			lines.append(line if index < sections.size() - 1 else _stem(line))
	_loft(xs, lines, side)


## [param line] closed onto her centreline: the stem her forward end comes to, where her
## sections stop as a cut across her.
static func _stem(line: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array()
	for point: Vector2 in line:
		closed.append(Vector2(0.0, point.y))
	return closed


static func _sheer_of(line: PackedVector2Array) -> float:
	return line[line.size() - 1].y


## Quads between the stations at [param xs], each the side [param lines] at its x,
## shaded smooth across them; their bands under each station's sheer.
func _loft(xs: PackedFloat64Array, lines: Array[PackedVector2Array], side: int) -> void:
	var count := xs.size()
	if count < 2:
		return
	var grid: Array[PackedVector3Array] = []
	for station in count:
		var row := PackedVector3Array()
		for point: Vector2 in lines[station]:
			row.append(Vector3(xs[station], point.y, point.x))
		grid.append(row)
	var outward := Vector3(0.0, -0.3, 1.0 if side == 0 else -1.0)
	for station in count - 1:
		for j in SIDE_POINTS - 1:
			var corners := PackedVector3Array(
				[
					grid[station][j],
					grid[station + 1][j],
					grid[station + 1][j + 1],
					grid[station][j + 1],
				]
			)
			var normals := PackedVector3Array()
			var heads := PackedFloat32Array()
			for corner in 4:
				var at := station + (1 if corner in [1, 2] else 0)
				var up := j + (1 if corner >= 2 else 0)
				normals.append(_normal(grid, at, up, outward))
				heads.append(_sheer_of(lines[at]))
			_mesh.smooth_quad(corners, normals, _hull, heads)


## The shell's normal at [param grid]'s station [param at], point [param up], turned
## the way [param outward] points.
static func _normal(grid: Array[PackedVector3Array], at: int, up: int, outward: Vector3) -> Vector3:
	var along := grid[mini(at + 1, grid.size() - 1)][up] - grid[maxi(at - 1, 0)][up]
	var row := grid[at]
	var climb := row[mini(up + 1, row.size() - 1)] - row[maxi(up - 1, 0)]
	var normal := along.cross(climb)
	if normal.length_squared() < 1e-12:
		return outward.normalized()
	normal = normal.normalized()
	return normal if normal.dot(outward) >= 0.0 else -normal


## The flat end of her hull at [param section]'s far end that way — [param way] -1 aft,
## 1 forward — between its [param starboard] and [param port] sides.
func _close_end(
	section: HullSection, starboard: PackedVector2Array, port: PackedVector2Array, way: float
) -> void:
	var x := section.x + way * section.length * 0.5
	var ring := PackedVector2Array(starboard)
	for index in range(port.size() - 1, 0, -1):
		ring.append(port[index])
	var triangles := Geometry2D.triangulate_polygon(ring)
	var normal := Vector3(way, 0.0, 0.0)
	for index in range(0, triangles.size(), 3):
		var corners := PackedVector3Array()
		for corner in 3:
			var point := ring[triangles[index + corner]]
			corners.append(Vector3(x, point.y, point.x))
		_mesh.triangle(corners, PackedFloat32Array([0.0, 0.0, 0.0]), normal, _hull)


## The inside of each bulwark along [param section]'s stretch: the shell of its sides
## [param starboard] and [param port] over the deck beside it, where it stands higher.
func _bulwarks(
	layout: ShipLayout,
	section: HullSection,
	starboard: PackedVector2Array,
	port: PackedVector2Array
) -> void:
	var x0 := section.x - section.length * 0.5
	var x1 := section.x + section.length * 0.5
	for line: PackedVector2Array in [starboard, port]:
		var top := line[line.size() - 1]
		var deck := _deck_beside(layout, section.x, top)
		if deck == -INF or top.y - deck < BULWARK_FROM:
			continue
		var inward := Vector3(0.0, 0.0, -signf(top.x))
		var a := Vector3(x0, deck, top.x)
		var b := Vector3(x1, deck, top.x)
		var rise := Vector3.UP * (top.y - deck)
		_mesh.quad(a, b, b + rise, a + rise, inward, _bulwark, 0, deck, top.y)


## The highest deck at [param x] reaching out to the shell's top [param top] (z, y), no
## higher than it; -INF where none does.
static func _deck_beside(layout: ShipLayout, x: float, top: Vector2) -> float:
	var deck := -INF
	for platform: ShipPlatform in layout.platforms:
		if platform.height <= top.y + LEVEL and platform.contains(x, top.x):
			deck = maxf(deck, platform.height)
	return deck


## Her deck plating: each section's level top at a deck's height, out to her shell —
## lofted along each run of sections plated at that height on that side.
func _plate_decks(layout: ShipLayout) -> void:
	var sections := layout.structure.sections
	# Per section, its plated tops: [height, from z, to z].
	var tops: Array[Array] = []
	for section: HullSection in sections:
		tops.append(_plated(layout, section))
	for index in sections.size():
		var section := sections[index]
		for top: PackedFloat64Array in tops[index]:
			var before := _matching(tops[index - 1], top) if index > 0 else PackedFloat64Array()
			var after := (
				_matching(tops[index + 1], top)
				if index < sections.size() - 1
				else PackedFloat64Array()
			)
			var y := top[0] - PLATE_DROP
			var aft := before if not before.is_empty() else top
			var fore := after if not after.is_empty() else top
			var x0 := section.x - section.length * 0.5
			var x1 := section.x + section.length * 0.5
			# Halfway to each neighbour plated alike, its own width out to its stretch's
			# end where none is: the plating meets in the middle of each pair — and closes
			# to her stem, as her shell does, past her last section's middle.
			var mid_aft := _between(aft, top)
			var mid_fore := (
				_between(top, fore)
				if index < sections.size() - 1
				else PackedFloat64Array([top[0], 0.0, 0.0])
			)
			_plate(x0, mid_aft, section.x, top, y)
			_plate(section.x, top, x1, mid_fore, y)


## A section's level tops at a deck's height — a deck, not a well open to the sky:
## [height, from z, to z] each.
static func _plated(layout: ShipLayout, section: HullSection) -> Array[PackedFloat64Array]:
	var found: Array[PackedFloat64Array] = []
	var outline := section.outline
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if absf(a.y - b.y) > LEVEL or absf(a.x - b.x) <= LEVEL:
			continue
		for platform: ShipPlatform in layout.platforms:
			if absf(platform.height - a.y) <= LEVEL:
				found.append(PackedFloat64Array([a.y, minf(a.x, b.x), maxf(a.x, b.x)]))
				break
	return found


## The top among [param tops] at [param top]'s height that overlaps it across her.
static func _matching(tops: Array, top: PackedFloat64Array) -> PackedFloat64Array:
	for other: PackedFloat64Array in tops:
		if absf(other[0] - top[0]) <= LEVEL and other[1] < top[2] and other[2] > top[1]:
			return other
	return PackedFloat64Array()


static func _between(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[0], (a[1] + b[1]) * 0.5, (a[2] + b[2]) * 0.5])


func _plate(
	x0: float, from: PackedFloat64Array, x1: float, to: PackedFloat64Array, y: float
) -> void:
	var corners := PackedVector3Array(
		[
			Vector3(x0, y, from[1]),
			Vector3(x1, y, to[1]),
			Vector3(x1, y, to[2]),
			Vector3(x0, y, from[2]),
		]
	)
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	_mesh.smooth_quad(corners, normals, _plating)


## A dark mark through her shell at each freeing port and porthole of [param structure].
func _mark_openings(structure: ShipStructure) -> void:
	for opening: ShipOpening in structure.openings:
		var colour := PORT_COLOUR
		if opening.kind == ShipOpening.Kind.PORTHOLE:
			colour = GLASS_COLOUR
		elif opening.kind != ShipOpening.Kind.FREEING_PORT:
			continue
		if opening.centre.y >= cut_above:
			continue
		var size := opening.size
		size[opening.facing()] = MARK
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		box.material = material
		mark.mesh = box
		mark.position = opening.centre
		add_child(mark)


## The hull's paints: ship.gdshader's, with the dressed ship's colours and her boot line
## (ShipArt), cut away as the observer's view is.
func _materials(layout: ShipLayout) -> Dictionary:
	var materials := {}
	for finish: int in [ShipMesh.Finish.HULL, ShipMesh.Finish.HOUSE, ShipMesh.Finish.PLAIN]:
		var material := ShaderMaterial.new()
		material.shader = ShipArt.CUT_SHADER if is_finite(cut_above) else ShipArt.SHADER
		material.set_shader_parameter("finish", finish)
		material.set_shader_parameter("ink", ArtPalette.INK)
		material.set_shader_parameter("bottom_colour", ArtPalette.HULL_BOTTOM)
		material.set_shader_parameter("riband_colour", ArtPalette.RIBAND)
		material.set_shader_parameter("boot_height", ShipArt.BOOT_ABOVE - layout.freeboard)
		material.set_shader_parameter("trim_colour", ArtPalette.TEAK)
		material.set_shader_parameter("foot_colour", ArtPalette.HOUSE_FOOT)
		if is_finite(cut_above):
			material.set_shader_parameter("cut_above", cut_above)
		materials[finish] = material
	return materials
