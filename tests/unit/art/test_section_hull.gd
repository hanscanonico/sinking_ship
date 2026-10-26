extends GutTest
## A ship whose sections are not cut from ShipHull's loft — the trawler, the Titanic —
## is dressed all the same (SH23), her hull the shell her sections enclose
## (SectionHull): as broad as they are wherever one is cut, closed at her stem, with a
## keel under her; and a slab roofing a room — the trawler's wheelhouse roof — is drawn.
## The Titanic's shell is her hull's paint to her B deck and white over it where her
## superstructure stands (ShipLayout.white_above), her fo'c'sle hull to its top; and
## where her sheer steps her shell meets itself, no slit between one run and the next.
## Her deck plating is open over every stair coming up through a hole in a deck: the
## Titanic's from D deck onto her forward well deck show their way down, not planks.

const TRAWLER := "res://data/ships/trawler.tres"
const TITANIC := "res://data/ships/titanic.tres"
const RAILING_HEIGHT := 1.0
const BODY_RADIUS := 0.35
## How far the drawn breadth may stand off her sections' reach, in metres.
const NEAR := 0.01
## How far apart two runs of her shell may end at a joint: the chords their own points
## cut across a knuckle of the curve both lie on.
const GAP := 0.25
## A face whose corners stand this close in height is level.
const LEVEL := 1e-3
## How far over a stair's tread a face must stand to lie over it.
const CLEAR := 0.02
## How far past a stair's side or foot the deck cut round it is looked for.
const BESIDE := 0.05

var _layout: ShipLayout
var _hull: SectionHull


func before_each() -> void:
	_layout = load(TRAWLER)
	_hull = SectionHull.new(ShipSpace.new(_layout), RAILING_HEIGHT)


func test_her_breadth_is_her_sections_shell_where_each_is_cut() -> void:
	for section: HullSection in _layout.structure.sections:
		var low := INF
		var high := -INF
		for point: Vector2 in section.outline:
			low = minf(low, point.y)
			high = maxf(high, point.y)
		for share: float in [0.2, 0.5, 0.8]:
			var y := lerpf(low, high, share)
			for side in 2:
				var shell := section.shell_at(y, side * 2 - 1)
				var expected := 0.0 if is_nan(shell) else absf(shell)
				assert_almost_eq(
					_hull.breadth(section.x, y, side),
					expected,
					NEAR,
					"side %d at x %.2f, y %.2f" % [side, section.x, y]
				)


func test_her_shell_closes_at_her_stem_and_is_none_past_her_ends() -> void:
	var sections := _layout.structure.sections
	var first := sections[0]
	var last := sections[sections.size() - 1]
	var stem := last.x + last.length * 0.5
	var low := INF
	var high := -INF
	for point: Vector2 in last.outline:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	var y := (low + high) * 0.5
	assert_almost_eq(_hull.breadth(stem, y, 1), 0.0, NEAR, "closed at her stem")
	assert_gt(_hull.breadth(last.x, y, 1), 0.5, "full at her last section")
	assert_eq(_hull.breadth(stem + 0.5, y, 1), 0.0, "none past her stem")
	assert_eq(_hull.breadth(first.x - first.length * 0.5 - 0.5, y, 0), 0.0, "none past her stern")


func test_she_is_dressed_from_her_transom_to_her_stem_down_past_her_keel() -> void:
	var art := _dressed()
	var structure := _layout.structure
	var sections := structure.sections
	var first := sections[0]
	var last := sections[sections.size() - 1]
	var drawn := _drawn(art)
	assert_almost_eq(drawn.end.x, last.x + last.length * 0.5, 0.1, "to her stem")
	assert_true(drawn.position.x <= first.x - first.length * 0.5 + NEAR, "from her transom")
	assert_lt(drawn.position.y, structure.keel_y, "a keel bar under her keel")


func test_the_wheelhouse_roof_is_drawn() -> void:
	# The wheelhouse roof: the one slab — no thicker than a wall, broader than one — that
	# roofs a room.
	var space := ShipSpace.new(_layout)
	var roof: ShipBlocker
	for blocker: ShipBlocker in _layout.blockers:
		var slab := blocker.top - blocker.bottom <= ShipSpace.WALL_MAX
		if slab and not space.is_wall(blocker) and space.roofs(blocker):
			roof = blocker
	assert_not_null(roof, "the trawler's wheelhouse is roofed")
	var art := _dressed()
	var centre := roof.area.get_center()
	var faces := _faces(art)
	var found := false
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		if absf(a.y - roof.top) > 0.02 or absf(b.y - a.y) > 1e-4 or absf(c.y - a.y) > 1e-4:
			continue
		var triangle := PackedVector2Array(
			[Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]
		)
		if Geometry2D.is_point_in_polygon(centre, triangle):
			found = true
			break
	assert_true(found, "a face at the roof's top over its middle")


func test_her_superstructure_s_side_is_white_over_her_black_hull() -> void:
	var titanic: ShipLayout = load(TITANIC)
	var space := ShipSpace.new(titanic)
	var hull := SectionHull.new(space, RAILING_HEIGHT)
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, space.room_lines())
	hull.build(mesh)
	var node: Node3D = autofree(Node3D.new())
	var finishes := {}
	for finish: int in ShipMesh.Finish.values():
		finishes[finish] = null
	mesh.commit(node, finishes)
	var white := titanic.white_above
	# (x from, x to, y from, y to, paint): amidships under B deck and over it, under A
	# deck's plating at 5.49 m; her fo'c'sle's side over B deck.
	var stretches := [
		[-10.0, 10.0, 0.5, white - 0.6, ShipPaints.hull],
		[-10.0, 10.0, white + 0.6, 5.3, ShipPaints.wall],
		[100.0, 125.0, white + 0.6, 4.0, ShipPaints.hull],
	]
	var seen := [0, 0, 0]
	# A house's side is its foot's dark kick up to FOOT over its foot's band (UV.x).
	const FOOT := 0.12
	var surfaces: Array[Array] = []
	for part: Node in node.get_children():
		# A surface per finish (ShipMesh.commit).
		var drawn := (part as MeshInstance3D).mesh
		for surface in drawn.get_surface_count():
			surfaces.append(drawn.surface_get_arrays(surface))
	for arrays: Array in surfaces:
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var bands: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for index in points.size():
			var point := points[index]
			# Her shell's outside alone: facing out across her.
			if normals[index].z * signf(point.z) < 0.7:
				continue
			for band in stretches.size():
				var at: Array = stretches[band]
				if point.x < at[0] or point.x > at[1] or point.y < at[2] or point.y > at[3]:
					continue
				seen[band] += 1
				var paint: ShipMesh.Paint = at[4]
				assert_true(
					colours[index].is_equal_approx(paint.colour),
					"band %d at %s: %s" % [band, point, colours[index]]
				)
				if paint == ShipPaints.wall:
					assert_gt(bands[index].x, FOOT, "no kick along her white at %s" % point)
	for band in stretches.size():
		assert_gt(seen[band], 0, "band %d drawn" % band)


func test_her_shell_meets_itself_where_her_sheer_steps() -> void:
	var titanic: ShipLayout = load(TITANIC)
	var space := ShipSpace.new(titanic)
	var hull := SectionHull.new(space, RAILING_HEIGHT)
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, space.room_lines())
	hull.build(mesh)
	var faces := _committed_faces(mesh)
	var sections := titanic.structure.sections
	var sides := SectionHull.shell_sides(sections)
	var steps := 0
	for index in range(1, sections.size()):
		var aft := sections[index - 1]
		var sheers := Vector2(_sheer(sides[index * 2 - 2]), _sheer(sides[index * 2]))
		if is_equal_approx(sheers.x, sheers.y):
			continue
		var low := minf(sheers.x, sheers.y)
		steps += 1
		var joint := aft.x + aft.length * 0.5
		# Her starboard shell's corners on the joint, from the run aft of it and the one
		# forward, under the lower sheer and clear of her keel.
		var runs: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
		for at in range(0, faces.size(), 3):
			var a := faces[at]
			var b := faces[at + 1]
			var c := faces[at + 2]
			if absf((b - a).cross(c - a).normalized().y) > 0.9:
				continue
			var run := 0 if (a.x + b.x + c.x) / 3.0 < joint else 1
			for corner: Vector3 in [a, b, c]:
				var on_joint := absf(corner.x - joint) < 1e-3 and corner.z > 1.0
				if on_joint and corner.y < low - 0.05 and corner.y > -8.0:
					runs[run].append(Vector2(corner.y, corner.z))
		assert_gt(runs[0].size(), 2, "the run aft of x %.1f ends on it" % joint)
		assert_gt(runs[1].size(), 2, "the run forward of x %.1f starts on it" % joint)
		var fore := _climbing(runs[1])
		for point: Vector2 in runs[0]:
			var gap := INF
			for at in range(1, fore.size()):
				var near := Geometry2D.get_closest_point_to_segment(point, fore[at - 1], fore[at])
				gap = minf(gap, point.distance_to(near))
			assert_lt(
				gap, GAP, "x %.1f at %.2f m: %.3f m from the run forward" % [joint, point.x, gap]
			)
	assert_gt(steps, 3, "her sheer steps at her wells, poop and superstructure")


func test_her_plating_is_open_over_every_stair_up_through_a_hole_in_a_deck() -> void:
	# The Titanic's stairs up from D deck through her forward well deck, the barque's
	# companionways up through her main deck: no level face of her shell — her deck
	# plating — over a stair whose deck is cut round it, between its treads and its head.
	var ships := 0
	for ship: String in Fleet.names():
		var layout := Fleet.layout(ship)
		if layout.dressed:
			continue
		ships += 1
		var space := ShipSpace.new(layout)
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, space.room_lines())
		var sides := SectionHull.shell_sides(layout.structure.sections)
		SectionHull.shell(layout, mesh, ShipPaints.hull, ShipPaints.wall, ShipPaints.deck, sides)
		var level := _level(_committed_faces(mesh))
		for ramp: ShipRamp in layout.ramps:
			var head := maxf(ramp.start_height, ramp.end_height)
			if not _cut_round(layout, ramp, head):
				continue
			for u: float in [0.25, 0.5, 0.75]:
				for v: float in [0.25, 0.5, 0.75]:
					var at := ramp.area.position + ramp.area.size * Vector2(u, v)
					var tread := ramp.height_at(at.x, at.y)
					var over := _level_over(level, at, tread + CLEAR, head)
					assert_true(
						is_nan(over),
						(
							"%s: her plating at %.3f over the stair at %s, tread %.3f"
							% [ship, over, at, tread]
						)
					)
	assert_gt(ships, 1, "the Titanic and the barque among the fleet's sectioned hulls")


## Whether a deck of [param layout] at [param height] lies just past both sides of
## [param ramp] and its foot: cut round the stair, a hole it comes up through.
func _cut_round(layout: ShipLayout, ramp: ShipRamp, height: float) -> bool:
	var area := ramp.area
	var middle := area.get_center()
	var rising := ramp.end_height > ramp.start_height
	var past := PackedVector2Array()
	if ramp.axis == ShipRamp.Axis.X:
		past.append(Vector2(middle.x, area.position.y - BESIDE))
		past.append(Vector2(middle.x, area.end.y + BESIDE))
		past.append(Vector2(area.position.x - BESIDE if rising else area.end.x + BESIDE, middle.y))
	else:
		past.append(Vector2(area.position.x - BESIDE, middle.y))
		past.append(Vector2(area.end.x + BESIDE, middle.y))
		past.append(Vector2(middle.x, area.position.y - BESIDE if rising else area.end.y + BESIDE))
	for point: Vector2 in past:
		var decked := func(platform: ShipPlatform) -> bool:
			return absf(platform.height - height) <= LEVEL and platform.contains(point.x, point.y)
		if not layout.platforms.any(decked):
			return false
	return true


## Every triangle of [param mesh], committed, in her ship space.
func _committed_faces(mesh: ShipMesh) -> PackedVector3Array:
	var node: Node3D = autofree(Node3D.new())
	var finishes := {}
	for finish: int in ShipMesh.Finish.values():
		finishes[finish] = null
	mesh.commit(node, finishes)
	var faces := PackedVector3Array()
	for part: Node in node.get_children():
		faces.append_array((part as MeshInstance3D).mesh.get_faces())
	return faces


## The level triangles of [param faces], three corners each.
func _level(faces: PackedVector3Array) -> PackedVector3Array:
	var level := PackedVector3Array()
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		if absf(b.y - a.y) <= LEVEL and absf(c.y - a.y) <= LEVEL:
			level.append_array([a, b, c])
	return level


## The height of a triangle of [param level] over [param at] (x/z) higher than
## [param low] and no higher than [param high]; NAN where none is.
func _level_over(level: PackedVector3Array, at: Vector2, low: float, high: float) -> float:
	for index in range(0, level.size(), 3):
		var a := level[index]
		if a.y <= low or a.y > high:
			continue
		var b := level[index + 1]
		var c := level[index + 2]
		var triangle := PackedVector2Array(
			[Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]
		)
		if Geometry2D.is_point_in_polygon(at, triangle):
			return a.y
	return NAN


## A side's sheer: its last point's height (SectionHull.shell_sides()).
func _sheer(side: PackedVector2Array) -> float:
	return side[side.size() - 1].y


## [param points] (y, z) once each, from her keel up.
func _climbing(points: PackedVector2Array) -> PackedVector2Array:
	var sorted := Array(points)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var climbing := PackedVector2Array()
	for point: Vector2 in sorted:
		if climbing.is_empty() or not point.is_equal_approx(climbing[climbing.size() - 1]):
			climbing.append(point)
	return climbing


func _dressed() -> ShipArt:
	var art := ShipArt.new()
	add_child_autofree(art)
	art.build(_layout, RAILING_HEIGHT, BODY_RADIUS)
	return art


## Every mesh under [param root], in its ship space, as one box.
func _drawn(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for instance: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := (
			root.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		)
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## Every triangle drawn under [param root], in its ship space.
func _faces(root: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for instance: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		if mesh.mesh == null:
			continue
		var to_ship := root.global_transform.affine_inverse() * mesh.global_transform
		for corner: Vector3 in mesh.mesh.get_faces():
			faces.append(to_ship * corner)
	return faces
