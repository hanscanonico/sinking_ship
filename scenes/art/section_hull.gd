class_name SectionHull
extends ShipHull
## The hull of a ship her generator lofted any other way than ShipHull lofts — the
## trawler, the Titanic (ShipLayout.dressed false) — drawn from her data (D6): the shell
## her structure's sections enclose, each cut across her from her keel up either side
## to her sheer, lofted from section to section along each run of one sheer, flat across
## her stern and closed onto her centreline at her stem. ShipArt dresses the rest of her
## as it does any ship. Over the shell: the inside of a bulwark standing over a deck,
## painted as a house's side and capped in teak; her deck plating out to the shell where
## her decks' rectangles stop short of it; a keel bar under her, a rudder and a bronze
## propeller at her stern and an anchor stowed in a hawse either side of her bow, all
## to her scale. The greybox (GreyboxHull) draws the same shell (shell()).

## Points up each side of a section, keel to sheer, once resampled: at least
## SIDE_POINTS, and enough that none stands further than SIDE_SPACING from the next on
## her longest side — every section of hers the same, so each meets the next point for
## point.
const SIDE_POINTS := 18
const SIDE_SPACING := 0.5
## A shell standing this far or more over the deck beside it is a bulwark.
const BULWARK_FROM := 0.1
## A deck's plating stands this far under its planks' top, so the planks show where
## both are.
const PLATE_DROP := 0.01
## Two heights this close are one.
const LEVEL := 1e-3
## How far over her white_above her shell must stand for its side over that to be her
## superstructure's, painted white: a deck (the greybox's room height).
const SUPERSTRUCTURE := ShipSpace.OPEN_ROOM_HEIGHT
## A bulwark's teak capping: how wide, and how far it stands over the shell's top.
const CAP := Vector2(0.14, 0.06)
## The draft the steamer's fittings are drawn for (ShipHull.DRAFT): a ship's rudder,
## propeller and anchors are drawn to her own draft over it, never smaller.
const SCALE_DRAFT := 2.0

var _sections: Array[HullSection] = []
## Per section, its starboard and port sides resampled (shell_sides()).
var _sides: Array[PackedVector2Array] = []
## Her keel's height, and her drawn fittings' scale.
var _keel_y := 0.0
var _scale := 1.0


## The hull ShipArt draws [param space]'s ship with: ShipHull's loft when her sections
## were cut from it (ShipLayout.dressed), her sections' shell otherwise.
static func of(space: ShipSpace, railing_height: float) -> ShipHull:
	if space.layout.dressed:
		return ShipHull.new(space, railing_height)
	return SectionHull.new(space, railing_height)


func _init(space: ShipSpace, railing_height: float) -> void:
	super(space, railing_height)
	_sections = _layout.structure.sections
	_sides = shell_sides(_sections)
	_keel_y = _layout.structure.keel_y
	_scale = maxf(1.0, (_waterline - _keel_y) / SCALE_DRAFT)


func build(mesh: ShipMesh) -> void:
	shell(_layout, mesh, ShipPaints.hull, ShipPaints.wall, ShipPaints.deck, _sides, ShipPaints.wall)
	_caps(mesh)
	_keel_bar(mesh)
	_rudder(mesh)
	_propeller(mesh)
	for side in 2:
		_anchor(mesh, side)


## The hull's half breadth on [param side] (0 port, 1 starboard) at (x, y): the shell
## between the two sections whose middles stand either side of x, 0 past her ends or
## where her shell does not reach y.
func breadth(x: float, y: float, side: int) -> float:
	var count := _sections.size()
	var aft_end := _sections[0].x - _sections[0].length * 0.5
	var last := _sections[count - 1]
	if x < aft_end or x > last.x + last.length * 0.5:
		return 0.0
	var way := side * 2 - 1
	for index in count:
		var section := _sections[index]
		if x > section.x and index < count - 1:
			continue
		var here := _reach(section, y, way)
		if index == 0 and x <= section.x:
			return here
		if x > section.x:
			# Past her last section's middle her shell closes onto her stem.
			return here * (1.0 - (x - section.x) / (last.length * 0.5))
		var before := _sections[index - 1]
		var t := (x - before.x) / (section.x - before.x)
		return lerpf(_reach(before, y, way), here, t)
	return 0.0


static func _reach(section: HullSection, y: float, way: int) -> float:
	var z := section.shell_at(y, way)
	return 0.0 if is_nan(z) else absf(z)


## Each of [param sections]' sides, starboard then port, from her keel to her sheer,
## as many points up each (SIDE_POINTS, SIDE_SPACING).
static func shell_sides(sections: Array[HullSection]) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var longest := 0.0
	for section: HullSection in sections:
		for side: float in [1.0, -1.0]:
			var line := _side(section.outline, side)
			lines.append(line)
			longest = maxf(longest, _length(line))
	var count := maxi(SIDE_POINTS, ceili(longest / SIDE_SPACING) + 1)
	var sides: Array[PackedVector2Array] = []
	for line: PackedVector2Array in lines:
		sides.append(_resampled(line, count))
	return sides


static func _length(line: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, line.size()):
		total += line[index].distance_to(line[index - 1])
	return total


## Draws [param layout]'s shell into [param mesh] from her sections' [param sides]
## (shell_sides()): in [param hull] paint — in [param white] over her white_above where
## her shell stands a deck higher still, given one —, the inside of each bulwark in
## [param bulwark], her deck plating in [param plating].
static func shell(
	layout: ShipLayout,
	mesh: ShipMesh,
	hull: ShipMesh.Paint,
	bulwark: ShipMesh.Paint,
	plating: ShipMesh.Paint,
	sides: Array[PackedVector2Array],
	white: ShipMesh.Paint = null
) -> void:
	var sections := layout.structure.sections
	var paints: Array[ShipMesh.Paint] = [hull, white if white != null else hull]
	for side in 2:
		_loft_shell(mesh, paints, layout.white_above, sections, sides, side)
	_close_end(mesh, hull, sections[0], sides[0], sides[1], -1.0)
	for index in sections.size():
		_bulwarks(mesh, bulwark, layout, sections[index], sides[index * 2], sides[index * 2 + 1])
	_plate_decks(mesh, plating, layout)


## One side of [param outline] — [param side] 1 for starboard, -1 for port — in (z, y)
## from her keel up to her sheer: from where the outline starts, or ends, while it
## climbs and stands out.
static func _side(outline: PackedVector2Array, side: float) -> PackedVector2Array:
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


## [param line] as [param count] points evenly along it.
static func _resampled(line: PackedVector2Array, count: int) -> PackedVector2Array:
	if line.size() < 2:
		line = PackedVector2Array([line[0], line[0]])
	var lengths := PackedFloat64Array([0.0])
	for index in range(1, line.size()):
		lengths.append(lengths[index - 1] + line[index].distance_to(line[index - 1]))
	var total := lengths[lengths.size() - 1]
	var points := PackedVector2Array()
	var at := 0
	for step in count:
		var reach := total * step / (count - 1)
		while at < line.size() - 2 and lengths[at + 1] < reach:
			at += 1
		var span := lengths[at + 1] - lengths[at]
		var t := (reach - lengths[at]) / span if span > 0.0 else 0.0
		points.append(line[at].lerp(line[at + 1], clampf(t, 0.0, 1.0)))
	return points


## The shell on [param side] (0 starboard, 1 port) of [param sections], whose sides are
## [param sides]: lofted from the middle of one section to the next while their sheer
## is one height, out to the ends of each such run — where two runs meet, each ends on
## the same curve under the lower sheer (_met()); in [param paints]' first, or its
## second over [param white] (_loft_run()).
static func _loft_shell(
	mesh: ShipMesh,
	paints: Array[ShipMesh.Paint],
	white: float,
	sections: Array[HullSection],
	sides: Array[PackedVector2Array],
	side: int
) -> void:
	var xs := PackedFloat64Array()
	var lines: Array[PackedVector2Array] = []
	for index in sections.size():
		var section := sections[index]
		var line := sides[index * 2 + side]
		var sheer := _sheer_of(line)
		var run_ends := (
			index == 0 or not is_equal_approx(_sheer_of(sides[(index - 1) * 2 + side]), sheer)
		)
		if run_ends:
			_loft_run(mesh, paints, white, xs, lines, side)
			xs = PackedFloat64Array([section.x - section.length * 0.5])
			lines = [line if index == 0 else _met(line, sides[(index - 1) * 2 + side])]
		xs.append(section.x)
		lines.append(line)
		var next_differs := (
			index == sections.size() - 1
			or not is_equal_approx(_sheer_of(sides[(index + 1) * 2 + side]), sheer)
		)
		if next_differs:
			xs.append(section.x + section.length * 0.5)
			if index == sections.size() - 1:
				lines.append(_stem(line))
			else:
				lines.append(_met(line, sides[(index + 1) * 2 + side]))
	_loft_run(mesh, paints, white, xs, lines, side)


## [param line] moved out or in to meet [param other] — the side of the section past
## the joint, its sheer another — half way: under both sheers each lies on the curve
## half way between them, so the two runs meet there with no slit; over the lower
## sheer, and under the higher keel, it keeps the offset it has at either.
static func _met(line: PackedVector2Array, other: PackedVector2Array) -> PackedVector2Array:
	var low := maxf(line[0].y, other[0].y)
	var high := minf(_sheer_of(line), _sheer_of(other))
	var met := PackedVector2Array()
	for point: Vector2 in line:
		var y := clampf(point.y, low, high)
		var shift := (_out_at(other, y) - _out_at(line, y)) * 0.5
		met.append(Vector2(point.x + shift, point.y))
	return met


## How far across [param line] (z, y; climbing) stands at height [param y].
static func _out_at(line: PackedVector2Array, y: float) -> float:
	if y <= line[0].y:
		return line[0].x
	for index in range(1, line.size()):
		var a := line[index - 1]
		var b := line[index]
		if y <= b.y:
			return a.x if b.y - a.y < LEVEL else lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return line[line.size() - 1].x


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
## shaded smooth across them; their bands under each station's sheer. In
## [param paints]' first, or its second over [param white] where their sheer stands a
## deck (SUPERSTRUCTURE) over it: her superstructure's side.
static func _loft_run(
	mesh: ShipMesh,
	paints: Array[ShipMesh.Paint],
	white: float,
	xs: PackedFloat64Array,
	lines: Array[PackedVector2Array],
	side: int
) -> void:
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
	var superstructure := _sheer_of(lines[0]) >= white + SUPERSTRUCTURE
	for station in count - 1:
		for j in lines[0].size() - 1:
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
			var middle := (corners[0].y + corners[1].y + corners[2].y + corners[3].y) * 0.25
			var over := superstructure and middle > white
			# A house's side, its foot a deck under the line: no kick shows along it.
			var foot := white - SUPERSTRUCTURE if over else NAN
			mesh.smooth_quad(corners, normals, paints[1 if over else 0], heads, foot)


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
static func _close_end(
	mesh: ShipMesh,
	paint: ShipMesh.Paint,
	section: HullSection,
	starboard: PackedVector2Array,
	port: PackedVector2Array,
	way: float
) -> void:
	var x := section.x + way * section.length * 0.5
	var ring := PackedVector2Array(starboard)
	for index in range(port.size() - 1, 0, -1):
		ring.append(port[index])
	var triangles := Geometry2D.triangulate_polygon(ring)
	var normal := Vector3(way, 0.0, 0.0)
	var head := maxf(_sheer_of(starboard), _sheer_of(port))
	for index in range(0, triangles.size(), 3):
		var corners := PackedVector3Array()
		for corner in 3:
			var point := ring[triangles[index + corner]]
			corners.append(Vector3(x, point.y, point.x))
		mesh.triangle(corners, PackedFloat32Array([0.0, 0.0, 0.0]), normal, paint, NAN, head)


## The inside of each bulwark along [param section]'s stretch: the shell of its sides
## [param starboard] and [param port] over the deck beside it, where it stands higher.
static func _bulwarks(
	mesh: ShipMesh,
	paint: ShipMesh.Paint,
	layout: ShipLayout,
	section: HullSection,
	starboard: PackedVector2Array,
	port: PackedVector2Array
) -> void:
	var x0 := section.x - section.length * 0.5
	var x1 := section.x + section.length * 0.5
	for line: PackedVector2Array in [starboard, port]:
		var top := line[line.size() - 1]
		var deck := deck_beside(layout, section.x, top)
		if deck == -INF or top.y - deck < BULWARK_FROM:
			continue
		var inward := Vector3(0.0, 0.0, -signf(top.x))
		var a := Vector3(x0, deck, top.x)
		var b := Vector3(x1, deck, top.x)
		var rise := Vector3.UP * (top.y - deck)
		mesh.quad(a, b, b + rise, a + rise, inward, paint, 0, deck, top.y)


## The highest deck at [param x] reaching out to the shell's top [param top] (z, y), no
## higher than it; -INF where none does.
static func deck_beside(layout: ShipLayout, x: float, top: Vector2) -> float:
	var deck := -INF
	for platform: ShipPlatform in layout.platforms:
		if platform.height <= top.y + LEVEL and platform.contains(x, top.x):
			deck = maxf(deck, platform.height)
	return deck


## Her deck plating: each section's level top at a deck's height, out to her shell —
## lofted along each run of sections plated at that height on that side.
static func _plate_decks(mesh: ShipMesh, paint: ShipMesh.Paint, layout: ShipLayout) -> void:
	var sections := layout.structure.sections
	var decks := PackedFloat64Array()
	for platform: ShipPlatform in layout.platforms:
		decks.append(platform.height)
	decks.sort()
	# Per section, its plated tops: [height, from z, to z].
	var tops: Array[Array] = []
	for section: HullSection in sections:
		tops.append(_plated(decks, section))
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
			_plate(mesh, paint, x0, mid_aft, section.x, top, y)
			_plate(mesh, paint, section.x, top, x1, mid_fore, y)


## A section's level tops at one of [param decks]' heights (sorted) — a deck, not a well
## open to the sky: [height, from z, to z] each.
static func _plated(decks: PackedFloat64Array, section: HullSection) -> Array[PackedFloat64Array]:
	var found: Array[PackedFloat64Array] = []
	var outline := section.outline
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if absf(a.y - b.y) > LEVEL or absf(a.x - b.x) <= LEVEL:
			continue
		var at := decks.bsearch(a.y - LEVEL)
		if at < decks.size() and absf(decks[at] - a.y) <= LEVEL:
			found.append(PackedFloat64Array([a.y, minf(a.x, b.x), maxf(a.x, b.x)]))
	return found


## The top among [param tops] at [param top]'s height that overlaps it across her.
static func _matching(tops: Array, top: PackedFloat64Array) -> PackedFloat64Array:
	for other: PackedFloat64Array in tops:
		if absf(other[0] - top[0]) <= LEVEL and other[1] < top[2] and other[2] > top[1]:
			return other
	return PackedFloat64Array()


static func _between(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[0], (a[1] + b[1]) * 0.5, (a[2] + b[2]) * 0.5])


static func _plate(
	mesh: ShipMesh,
	paint: ShipMesh.Paint,
	x0: float,
	from: PackedFloat64Array,
	x1: float,
	to: PackedFloat64Array,
	y: float
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
	mesh.smooth_quad(corners, normals, paint)


## A teak capping along the top of every bulwark, and a toe rail where her shell stops
## at the deck: along each section's stretch at its sheer, inboard of the shell.
func _caps(mesh: ShipMesh) -> void:
	for index in _sections.size():
		var section := _sections[index]
		var x0 := section.x - section.length * 0.5
		var x1 := section.x + section.length * 0.5
		if index == _sections.size() - 1:
			# Short of her stem, where her shell closes onto her centreline.
			x1 = section.x
		for side in 2:
			var top := _sheer_of(_sides[index * 2 + side])
			var line := _sides[index * 2 + side]
			var z := line[line.size() - 1].x
			if absf(z) < CAP.x:
				continue
			var deck := deck_beside(_layout, section.x, Vector2(z, top))
			var high := deck != -INF and top - deck >= BULWARK_FROM
			var rail := CAP if high else Vector2(ShipHull.TOE_RAIL_WIDTH, ShipHull.TOE_RAIL_HEIGHT)
			var inner := z - signf(z) * rail.x
			var area := Rect2(x0, minf(z, inner), x1 - x0, rail.x)
			mesh.box(area, top, top + rail.y, ShipPaints.teak, ShipMesh.TOP | ShipMesh.SIDES)


## A keel bar under her from her sternpost to her stem.
func _keel_bar(mesh: ShipMesh) -> void:
	var from := _post()
	var last := _sections[_sections.size() - 1]
	var to := last.x + last.length * 0.5
	var bar := KEEL_BAR * _scale
	mesh.box(
		Rect2(from, -bar.x * 0.5, to - from, bar.x),
		_keel_y - bar.y,
		_keel_y + LEVEL,
		ShipPaints.hull,
		ShipMesh.ALL_FACES,
		NAN,
		_fore_deck
	)


## Where her sternpost stands: a little forward of her stern, where the rudder hangs
## clear of her transom.
func _post() -> float:
	var first := _sections[0]
	return first.x - first.length * 0.5 + RUDDER_GAP * _scale + RUDDER_CHORD * _scale


## The rudder, hung aft of the sternpost from her keel up toward her waterline.
func _rudder(mesh: ShipMesh) -> void:
	var post := _post()
	var chord := RUDDER_CHORD * _scale
	var gap := RUDDER_GAP * _scale * 0.3
	var thick := RUDDER_THICKNESS * _scale
	var blade := Rect2(post - gap - chord, -thick * 0.5, chord, thick)
	var top := _waterline + COUNTER_LIFT * _scale
	mesh.box(
		blade, _keel_y + 0.1 * _scale, top, ShipPaints.hull, ShipMesh.ALL_FACES, NAN, _fore_deck
	)


## A four-bladed bronze propeller on its shaft, just forward of the rudder.
func _propeller(mesh: ShipMesh) -> void:
	var post := _post()
	var reach := BLADE_REACH * _scale
	var hub_r := HUB * _scale
	var hub := Vector3(post + hub_r * 2.0, _keel_y + reach + hub_r + 0.1 * _scale, 0.0)
	var shaft := Basis.IDENTITY
	var shaft_length := hub_r * 6.0
	mesh.turned_box(
		Transform3D(shaft, hub + Vector3.RIGHT * shaft_length * 0.5),
		Vector3(shaft_length, hub_r, hub_r),
		ShipPaints.brass,
		0
	)
	mesh.turned_box(
		Transform3D(shaft, hub), Vector3(hub_r * 3.0, hub_r * 2.0, hub_r * 2.0), ShipPaints.brass, 0
	)
	for blade in 4:
		var spin := Basis(Vector3.RIGHT, TAU * (blade + 0.5) / 4.0)
		var pitch := Basis(Vector3.UP, BLADE_PITCH)
		var centre := hub + spin * Vector3.UP * (hub_r + reach * 0.5)
		var size := Vector3(0.05 * _scale, reach, BLADE_CHORD * _scale)
		mesh.turned_box(Transform3D(spin * pitch, centre), size, ShipPaints.brass, 0)


## A hawse on her bow's [param side] and a stockless anchor stowed in it, lying against
## her plating, HAWSE_DOWN under her fore deck at her scale.
func _anchor(mesh: ShipMesh, side: int) -> void:
	var last := _sections[_sections.size() - 1]
	var y := _fore_deck - HAWSE_DOWN * _scale
	var x := last.x - last.length * 0.5
	if breadth(x, y, side) < HAWSE_RADIUS * _scale * 2.0 or y < _waterline:
		return
	var out := -1.0 if side == 0 else 1.0
	var at := Vector3(x, y, out * breadth(x, y, side))
	var facing := normal(x, y, side)
	var right := facing.cross(Vector3.UP).normalized()
	var up := right.cross(facing).normalized()
	var ring := PackedVector3Array()
	var radius := HAWSE_RADIUS * _scale
	for index in 16:
		var angle := TAU * index / 16.0
		ring.append(at + facing * 0.01 + (right * cos(angle) + up * sin(angle)) * radius)
	mesh.polygon(ring, facing, ShipPaints.dark, NAN, NAN)
	var foot_y := y - SHANK * _scale
	var foot := Vector3(x, foot_y, out * breadth(x, foot_y, side))
	foot += normal(x, foot_y, side) * ANCHOR_OFF * _scale
	var top := at + facing * ANCHOR_OFF * _scale
	var along := (top - foot).normalized()
	var across := along.cross(facing).normalized()
	var lie := Basis(across, along, facing).orthonormalized()
	var shank := Vector3(0.1, SHANK, 0.1) * _scale
	mesh.turned_box(Transform3D(lie, (top + foot) * 0.5), shank, ShipPaints.dark, 0)
	var arms := Vector3(ARMS, 0.16, 0.12) * _scale
	mesh.turned_box(Transform3D(lie, foot + along * 0.08 * _scale), arms, ShipPaints.dark, 0)
	for end: float in [-1.0, 1.0]:
		var fluke := foot + across * end * ARMS * 0.45 * _scale + along * 0.2 * _scale
		var size := Vector3(0.18, 0.32, 0.1) * _scale
		mesh.turned_box(Transform3D(lie, fluke), size, ShipPaints.dark, 0)
