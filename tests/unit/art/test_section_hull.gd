extends GutTest
## A ship whose sections are not cut from ShipHull's loft — the trawler, the Titanic —
## is dressed all the same (SH23), her hull the shell her sections enclose
## (SectionHull): as broad as they are wherever one is cut, closed at her stem, with a
## keel under her; and a slab roofing a room — the trawler's wheelhouse roof — is drawn.

const TRAWLER := "res://data/ships/trawler.tres"
const RAILING_HEIGHT := 1.0
const BODY_RADIUS := 0.35
## How far the drawn breadth may stand off her sections' reach, in metres.
const NEAR := 0.01

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
	# The wheelhouse roof: the one slab — no thicker than a wall, broader than one — whose
	# middle stands in a room.
	var space := ShipSpace.new(_layout)
	var roof: ShipBlocker
	for blocker: ShipBlocker in _layout.blockers:
		var area := blocker.area
		var middle := Vector3(
			area.get_center().x, (blocker.bottom + blocker.top) * 0.5, area.get_center().y
		)
		var slab := blocker.top - blocker.bottom <= ShipSpace.WALL_MAX
		if slab and minf(area.size.x, area.size.y) > 1.0 and not space.outdoors(middle):
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
