extends GutTest
## The dressed ship's face emission natively (#411, NativeShipMesh and NativeIndoorGrid)
## against the GDScript it stands in for, bit for bit: every batch's indices, vertices,
## normals, colours, bands, rim weights and fading boxes, drawn both ways from the same
## calls — made-up boxes, faces, quads and turned boxes over room lines, with slivers,
## zero areas, tilted and narrow faces, edges cut many times and pieces judged on a
## cell's boundary, cut away above and kept to a stretch, fading or not; a real ship's
## rooms judged by her grid both ways, point by point and face by face; and her whole
## art. Where the extension is not loaded there is nothing to hold it to; CI sets
## SINKING_NATIVE_REQUIRED, so a missing library there fails.

const RunMatch := preload("res://tools/run_match.gd")
const SEED := 411
## The room lines the made-up faces are cut at, per axis: some on a chunk line (x 4,
## y 2.5, z 5), some a sliver apart, some a sliver off a chunk line.
const XS: Array[float] = [-6.0, -4.0, -1.0, 0.0, 1.0, 1.002, 2.5, 3.999, 4.0, 6.0, 9.5, 12.0]
const YS: Array[float] = [-2.5, 0.0, 1.25, 2.5, 2.503, 5.0]
const ZS: Array[float] = [-5.0, -2.0, 0.0, 0.5, 4.996, 5.0, 7.5]

var _rng := RandomNumberGenerator.new()
var _paints: Array[ShipMesh.Paint] = [
	ShipMesh.Paint.new(ShipMesh.Finish.DECK, Color(0.6, 0.5, 0.4)),
	ShipMesh.Paint.new(
		ShipMesh.Finish.HULL, Color(0.1, 0.2, 0.3), ShipMesh.Finish.CABIN, Color(0.9, 0.8, 0.7)
	),
	ShipMesh.Paint.new(ShipMesh.Finish.GLASS_OUT, Color(0.3, 0.3, 0.3, 0.5)),
]


func before_each() -> void:
	_rng.seed = SEED


func after_each() -> void:
	ArtNative.allowed = true
	ShipMesh.committed = Callable()


## Whether the extension is loaded: a failure where CI requires it, pending elsewhere.
func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeShipMesh"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false


## Outdoors by a checkerboard of half metres, tilted so a cell's boundary is met.
static func _checkered(point: Vector3) -> bool:
	return (floori(point.x * 2.0) + floori(point.y * 2.0) + floori(point.z * 2.0)) % 2 == 0


static func _cuts() -> Array[PackedFloat32Array]:
	var cuts: Array[PackedFloat32Array] = [
		PackedFloat32Array(XS), PackedFloat32Array(YS), PackedFloat32Array(ZS)
	]
	return cuts


## [param draw] (mesh) -> void called on a mesh drawn by the extension and on one drawn
## by the GDScript, each made by [param made] (-> ShipMesh): fails on any difference
## between their batches.
func _both(made: Callable, draw: Callable, what: String) -> void:
	ArtNative.allowed = true
	var native: ShipMesh = made.call()
	ArtNative.allowed = false
	var reference: ShipMesh = made.call()
	ArtNative.allowed = true
	assert_not_null(native._native, "%s: drawn natively" % what)
	assert_null(reference._native, "%s: drawn in GDScript" % what)
	_rng.seed = SEED
	draw.call(native)
	_rng.seed = SEED
	draw.call(reference)
	_assert_same(native.batches(), reference.batches(), what)


## Fails on the first difference between two meshes' batches, naming it.
func _assert_same(native: Dictionary, reference: Dictionary, what: String) -> void:
	var keys := native.keys()
	keys.sort()
	var others := reference.keys()
	others.sort()
	if keys != others:
		fail_test("%s: batches %s natively, %s in GDScript" % [what, keys, others])
		return
	var names := ["indices", "vertices", "normals", "colours", "uvs", "uv2s", "pieces", "halves"]
	var vertices := 0
	for key: String in keys:
		var mine: ShipMesh.Batch = native[key]
		var theirs: ShipMesh.Batch = reference[key]
		vertices += theirs.vertices.size()
		for name: String in names:
			var a: Variant = mine.get(name)
			var b: Variant = theirs.get(name)
			if var_to_bytes(a) != var_to_bytes(b):
				fail_test(
					"%s: batch %s's %s differ: %s" % [what, key, name, _first_difference(a, b)]
				)
				return
	assert_gt(vertices, 0, "%s: something drawn" % what)


static func _first_difference(a: Variant, b: Variant) -> String:
	if a.size() != b.size():
		return "%d natively, %d in GDScript" % [a.size(), b.size()]
	for index in a.size():
		if var_to_bytes(a[index]) != var_to_bytes(b[index]):
			return "at %d, %s natively, %s in GDScript" % [index, a[index], b[index]]
	return "nowhere"


func _mesh(outdoors: Callable) -> ShipMesh:
	return ShipMesh.new(outdoors, _cuts())


func _paint() -> ShipMesh.Paint:
	return _paints[_rng.randi_range(0, _paints.size() - 1)]


## A length: mostly metres, now and then a sliver, nothing or a hair either side of one.
func _length() -> float:
	match _rng.randi_range(0, 9):
		0:
			return 0.0
		1:
			return ShipMesh.SLIVER * _rng.randf_range(0.5, 2.0)
		2:
			return ShipMesh.NARROW + _rng.randf_range(-0.01, 0.01)
		3:
			return float(_rng.randi_range(1, 8))
	return _rng.randf_range(0.01, 14.0)


## A coordinate: mostly anywhere, now and then on a room line or a chunk line.
func _at(lines: Array[float], step: float) -> float:
	match _rng.randi_range(0, 5):
		0:
			return lines[_rng.randi_range(0, lines.size() - 1)]
		1:
			return step * _rng.randi_range(-3, 3)
		2:
			return lines[_rng.randi_range(0, lines.size() - 1)] + _rng.randf_range(-0.01, 0.01)
	return _rng.randf_range(-8.0, 14.0)


func _point() -> Vector3:
	return Vector3(_at(XS, 4.0), _at(YS, 2.5), _at(ZS, 5.0))


func _edge() -> Vector3:
	var edge := Vector3.ZERO
	match _rng.randi_range(0, 4):
		0:
			edge = Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-3.0, 3.0), 0.0)
		1:
			edge = Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))
		_:
			edge[_rng.randi_range(0, 2)] = _length() * (1.0 if _rng.randf() < 0.7 else -1.0)
	return edge


func _draw_boxes(mesh: ShipMesh) -> void:
	for index in 300:
		var area := Rect2(_at(XS, 4.0), _at(ZS, 5.0), _length(), _length())
		var bottom := _at(YS, 2.5)
		var top := bottom + _length()
		var foot := NAN if _rng.randf() < 0.5 else bottom - _rng.randf()
		var head := NAN if _rng.randf() < 0.5 else top + _rng.randf()
		mesh.box(area, bottom, top, _paint(), _rng.randi_range(0, ShipMesh.ALL_FACES), foot, head)


func _draw_faces(mesh: ShipMesh) -> void:
	for index in 400:
		var foot := NAN if _rng.randf() < 0.5 else _rng.randf_range(-3.0, 3.0)
		var head := NAN if _rng.randf() < 0.5 else _rng.randf_range(-3.0, 6.0)
		mesh.face(_point(), _edge(), _edge(), _paint(), _rng.randi_range(0, 15), foot, head)


func _draw_quads(mesh: ShipMesh) -> void:
	for rims in 16:
		for index in 12:
			var a := _point()
			var u := _edge()
			var v := _edge() if index % 3 != 0 else Vector3.ZERO
			var twist := Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 0.1
			var normal := u.cross(v).normalized()
			if index % 4 == 0:
				normal = -normal
			mesh.quad(a, a + u, a + u + v + twist, a + v, normal, _paint(), rims)


func _draw_turned(mesh: ShipMesh) -> void:
	for index in 60:
		var basis := Basis.from_euler(
			Vector3(_rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI))
		)
		if index % 5 == 0:
			basis = basis.scaled(Vector3(-1.0, 1.0, 1.0))
		var size := Vector3(_length(), _length(), _length())
		mesh.turned_box(Transform3D(basis, _point()), size, _paint(), _rng.randi_range(0, 15))
		mesh.beam(_point(), _point(), Vector2(0.2, 0.1), _paint())


func _draw_all(mesh: ShipMesh) -> void:
	_draw_boxes(mesh)
	_draw_faces(mesh)
	_draw_quads(mesh)
	_draw_turned(mesh)
	mesh.cylinder(Vector2(1.0, 0.5), 0.8, -1.0, 4.0, 12, _paint())
	var ring := PackedVector3Array(
		[Vector3(0, 1, 0), Vector3(2, 1, 0), Vector3(2.5, 1, 1.5), Vector3(0, 1, 2)]
	)
	mesh.polygon(ring, Vector3.UP, _paint(), 0.0, 1.0)
	mesh.smooth_quad(
		PackedVector3Array(
			[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0.2), Vector3(0, 1, 0)]
		),
		PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.UP, Vector3.BACK]),
		_paint(),
		PackedFloat32Array([1.0, 1.0, 0.0, 0.0]),
		-0.5
	)


func test_made_up_faces_are_drawn_alike() -> void:
	if not _loaded():
		return
	for outdoors: Callable in [_checkered, func(_p: Vector3) -> bool: return true]:
		_both(_mesh.bind(outdoors), _draw_all, "made-up faces")


func test_cut_away_kept_to_a_stretch_and_fading_alike() -> void:
	if not _loaded():
		return
	var cut := func() -> ShipMesh:
		var mesh := _mesh(_checkered)
		mesh.cut_above = 1.3
		mesh.keep = Vector2(-1.0, 6.0)
		return mesh
	_both(cut, _draw_all, "cut away and kept")
	var fading := func() -> ShipMesh:
		var mesh := _mesh(_checkered)
		mesh.fading = func(piece: AABB) -> bool: return piece.position.y > 0.4
		return mesh
	var nested := func(mesh: ShipMesh) -> void:
		_draw_all(mesh)
		mesh._open()
		_draw_boxes(mesh)
		mesh._close()
	_both(fading, nested, "fading")


func test_an_outdoors_over_callable_is_asked_alike() -> void:
	if not _loaded():
		return
	var over := func(
		origin: Vector3,
		u: Vector3,
		v: Vector3,
		u_cuts: PackedFloat32Array,
		v_cuts: PackedFloat32Array,
		normal: Vector3,
		probe: float
	) -> Array:
		if u_cuts.size() % 2 == 0:
			return []
		var shows := []
		for i in u_cuts.size() - 1:
			for j in v_cuts.size() - 1:
				var middle := ShipMesh._middle(origin, u, v, u_cuts, v_cuts, i, j)
				shows.append(not _checkered(middle + normal * probe))
		return shows
	var made := func() -> ShipMesh:
		var mesh := _mesh(_checkered)
		mesh.outdoors_over = over
		return mesh
	_both(made, _draw_faces, "outdoors over")


func test_splits_and_needed_alike() -> void:
	if not _loaded():
		return
	var native: Object = ClassDB.instantiate(&"NativeShipMesh")
	var cuts := _cuts()
	for index in 2000:
		var origin := _point()
		var edge := _edge()
		var mine: PackedFloat32Array = native.splits(origin, edge, cuts)
		var theirs := ShipMesh.splits(origin, edge, cuts)
		if mine != theirs:
			fail_test("splits of %s along %s: %s, not %s" % [origin, edge, mine, theirs])
			return
		var other := _edge()
		var across := ShipMesh.splits(origin, other, cuts)
		# What each piece shows: whether it is outdoors, or the lining it takes (LinedFaces).
		var kinds: Array = [true, false] if index % 2 == 0 else [null, _paints[0], _paints[1]]
		var shows := []
		for cell in (theirs.size() - 1) * (across.size() - 1):
			shows.append(kinds[_rng.randi_range(0, kinds.size() - 1)])
		var kept: Array = native.needed(origin, edge, other, theirs, across, shows)
		var wanted := ShipMesh.needed(origin, edge, other, theirs, across, shows)
		if kept[0] != wanted[0] or kept[1] != wanted[1]:
			fail_test(
				"needed of %s along %s and %s: %s, not %s" % [origin, edge, other, kept, wanted]
			)
			return
	assert_true(true, "2000 edges split alike")


## Her grid made by the extension or by the GDScript, as ArtNative allows.
func _space(layout: ShipLayout, native: bool) -> ShipSpace:
	ArtNative.allowed = native
	var space := ShipSpace.new(layout)
	assert_eq(space.rooms_grid.native() != null, native)
	ArtNative.allowed = true
	return space


## Per room, its box as ShipArt._rooms_boxed() makes it.
static func _boxes(layout: ShipLayout) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for room: ShipRoom in layout.rooms:
		var top := room.floor_height + ShipSpace.OPEN_ROOM_HEIGHT
		for platform: ShipPlatform in layout.platforms:
			if platform.height > room.floor_height and platform.area.intersects(room.area):
				top = maxf(top, platform.height)
		var foot := Vector3(room.area.position.x, room.floor_height, room.area.position.y)
		var size := Vector3(room.area.size.x, top - room.floor_height, room.area.size.y)
		boxes.append(AABB(foot, size).grow(ShipSpace.INSIDE + ShipSpace.SLIVER))
	return boxes


func test_her_rooms_are_judged_alike() -> void:
	if not _loaded():
		return
	var layout := RunMatch.default_config(SEED, 0, &"small_titanic").ship
	var native := _space(layout, true)
	var reference := _space(layout, false)
	var boxes := _boxes(layout)
	var none: Array[AABB] = []
	var asked := 0
	for index in layout.rooms.size():
		var room := layout.rooms[index]
		var area := room.area
		var top := reference.ceiling(room, area.get_center().x, area.get_center().y)
		# On the room's every edge and a hair either side, at its floor and ceiling.
		var xs: Array[float] = [area.position.x, area.end.x, area.get_center().x]
		var zs: Array[float] = [area.position.y, area.end.y, area.get_center().y]
		var ys: Array[float] = [room.floor_height, top, (room.floor_height + top) * 0.5]
		for x: float in xs:
			for z: float in zs:
				for hair: float in [-ShipSpace.INSIDE, -1e-7, 0.0, 1e-7, ShipSpace.INSIDE]:
					var mine := native.rooms_grid.ceiling(index, x + hair, z - hair)
					var theirs := reference.rooms_grid.ceiling(index, x + hair, z - hair)
					if var_to_bytes(mine) != var_to_bytes(theirs):
						fail_test("ceiling of %s at %s, %s" % [room.name, x + hair, z - hair])
						return
					for y: float in ys:
						var point := Vector3(x + hair, y + hair, z + hair)
						for with: Array[AABB] in [boxes, none]:
							asked += 1
							if native.outdoors(point, with) != reference.outdoors(point, with):
								fail_test("outdoors of %s, by %s's edge" % [point, room.name])
								return
	assert_gt(asked, 10000)


func test_faces_over_her_rooms_are_drawn_alike() -> void:
	if not _loaded():
		return
	var layout := RunMatch.default_config(SEED, 0, &"small_titanic").ship
	var spaces := {true: _space(layout, true), false: _space(layout, false)}
	var boxes := _boxes(layout)
	var made := func() -> ShipMesh:
		var space: ShipSpace = spaces[ArtNative.allowed]
		var outdoors := func(point: Vector3) -> bool: return space.outdoors(point, boxes)
		var mesh := ShipMesh.new(outdoors, space.room_lines())
		mesh.judge_by(space.rooms_grid, boxes)
		return mesh
	var draw := func(mesh: ShipMesh) -> void:
		var paint := _paints[1]
		for room: ShipRoom in layout.rooms:
			var area := room.area
			var floor := room.floor_height
			# Its floor, walls on its edges and its ceiling, as the art lays them.
			mesh.box(area.grow(0.3), floor - 0.05, floor, paint)
			var aft := Rect2(area.position.x - 0.1, area.position.y, 0.1, area.size.y)
			mesh.box(aft, floor, floor + 2.5, paint)
			var side := Rect2(area.position.x, area.end.y, area.size.x, 0.05)
			mesh.box(side, floor, floor + 2.5, paint)
			var fore := Vector3(area.end.x, floor, area.position.y)
			mesh.face(fore, Vector3(0, 2.5, 0), Vector3(0, 0, area.size.y), paint)
			mesh.box(area, floor + 2.5, floor + 2.55, paint, ShipMesh.BOTTOM)
	_both(made, draw, "faces over her rooms")


## Every batch her whole art commits, hashed in order: drawn by the extension when
## [param native], else by the GDScript.
func _art_hash(config: MatchConfig, native: bool) -> PackedByteArray:
	ArtNative.allowed = native
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var count := [0]
	ShipMesh.committed = func(key: String, arrays: Array, finish: int) -> void:
		count[0] += 1
		hash.update(var_to_bytes([key, finish, arrays]))
	var art := ShipArt.new()
	art.rules = config.rules
	art.build(config.ship, config.rules.railing_height, config.rules.body_radius)
	art.free()
	ShipMesh.committed = Callable()
	ArtNative.allowed = true
	assert_gt(count[0], 100, "her art committed")
	return hash.finish()


func test_her_whole_art_is_drawn_alike() -> void:
	if not _loaded():
		return
	var config := RunMatch.default_config(SEED, 0, &"steamer")
	assert_eq(_art_hash(config, true).hex_encode(), _art_hash(config, false).hex_encode())
