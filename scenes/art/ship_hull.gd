class_name ShipHull
extends RefCounted
## The hull, lofted round the decks (ShipArt): stations at every deck and blocker
## end, where the side follows the outermost deck edge down to a knee clear of
## everything inside, rounds a bilge to a flat bottom, and rises and narrows toward
## raked ends. A step in the sheer or the beam ends one run of the loft and starts
## the next, joined by the step between their sections; the hull's two ends are
## capped. A teak toe rail runs along the sheer. Its paint (ship.gdshaderinc) is
## dark above the boot line, red oxide below.

## How far the hull reaches below the waterline of a level, unsunk ship: where decks
## stand below the main deck, and at its two ends.
const DRAFT := 2.0
const END_DRAFT := 0.5
## How far the stem and the stern lean in per metre down, and how much narrower the
## bottom is at the ends than amidships.
const RAKE := 0.3
const END_PINCH := 0.55
## How far the knee stays below anything inside the hull, and the keel below that.
const KNEE_CLEARANCE := 0.25
const KEEL_CLEARANCE := 0.4
## The toe rail along the sheer: its width and how high it stands over the deck.
const TOE_RAIL_WIDTH := 0.07
const TOE_RAIL_HEIGHT := 0.1
## How far a break face between two runs stands into the taller one.
const BREAK_INSET := 0.005
const SLIVER := ShipSpace.SLIVER

var _space: ShipSpace
var _layout: ShipLayout
## The x range of the decks, and of the decks below the main deck: where the keel
## runs deep. Without any, the middle half.
var _span := Vector2(INF, -INF)
var _deep := Vector2(INF, -INF)


func _init(space: ShipSpace) -> void:
	_space = space
	_layout = space.layout


func build(mesh: ShipMesh) -> void:
	var stations := PackedFloat32Array()
	for platform: ShipPlatform in _layout.platforms:
		var area := platform.area
		_span = Vector2(minf(_span.x, area.position.x), maxf(_span.y, area.end.x))
		if platform.height < 0.0:
			_deep = Vector2(minf(_deep.x, area.position.x), maxf(_deep.y, area.end.x))
		stations.append_array([area.position.x, area.end.x])
	for blocker: ShipBlocker in _layout.blockers:
		var reach := ShipSpace.x_reach(blocker)
		stations.append_array([reach.x, reach.y])
	if _deep.x > _deep.y:
		_deep = Vector2(lerpf(_span.x, _span.y, 0.25), lerpf(_span.x, _span.y, 0.75))
	stations.sort()
	var xs := PackedFloat32Array()
	for x: float in stations:
		if x >= _span.x - SLIVER and x <= _span.y + SLIVER:
			if xs.is_empty() or x - xs[xs.size() - 1] > SLIVER:
				xs.append(clampf(x, _span.x, _span.y))
	var run := PackedFloat32Array([xs[0]])
	var shape := _space.envelope((xs[0] + xs[1]) * 0.5)
	var behind := PackedVector3Array()
	var behind_shape := Vector4.INF
	for index in range(1, xs.size()):
		run.append(xs[index])
		var last := index == xs.size() - 1
		var next := Vector4.INF if last else _space.envelope((xs[index] + xs[index + 1]) * 0.5)
		if last or not next.is_equal_approx(shape):
			if shape.x != INF:
				var profiles := _run(mesh, run, shape)
				if behind.is_empty():
					_cap(mesh, profiles[0], Vector3.LEFT, shape)
				else:
					_step(mesh, behind, behind_shape, profiles[0], shape)
				if last:
					_cap(mesh, profiles[profiles.size() - 1], Vector3.RIGHT, shape)
				behind = profiles[profiles.size() - 1]
				behind_shape = shape
			run = PackedFloat32Array([xs[index]])
			shape = next


## One run of the loft through stations [param xs] under the outline [param shape],
## and its toe rails; its sections, aft to fore.
func _run(mesh: ShipMesh, xs: PackedFloat32Array, shape: Vector4) -> Array[PackedVector3Array]:
	var top := maxf(shape.z, shape.w)
	var profiles: Array[PackedVector3Array] = []
	var middles := PackedFloat32Array()
	for x: float in xs:
		var profile := _profile(x, shape)
		profiles.append(profile)
		middles.append((top + profile[profile.size() / 2].y) * 0.5)
	for i in profiles.size() - 1:
		for j in profiles[i].size() - 1:
			var a := profiles[i][j]
			var b := profiles[i][j + 1]
			var c := profiles[i + 1][j + 1]
			var d := profiles[i + 1][j]
			var normal := (c - a).cross(d - b).normalized()
			var middle := (a + b + c + d) * 0.25
			var out := Vector3(0.0, middle.y - (middles[i] + middles[i + 1]) * 0.5, middle.z)
			if normal.dot(out) < 0.0:
				normal = -normal
			mesh.quad(a, b, c, d, normal, ShipPaints.hull, 0, NAN, top)
	for side in 2:
		var edge := shape.x if side == 0 else shape.y
		var deck := shape.z if side == 0 else shape.w
		var from := edge - 0.005 if side == 0 else edge - TOE_RAIL_WIDTH
		mesh.box(
			Rect2(xs[0], from, xs[xs.size() - 1] - xs[0], TOE_RAIL_WIDTH + 0.005),
			deck - ShipArt.PLANK,
			deck + TOE_RAIL_HEIGHT,
			ShipPaints.teak
		)
	return profiles


## The hull's end: [param ring] filled, facing [param outward].
func _cap(mesh: ShipMesh, ring: PackedVector3Array, outward: Vector3, shape: Vector4) -> void:
	var normal := _newell(ring)
	if normal.dot(outward) < 0.0:
		normal = -normal
	mesh.polygon(ring, normal, ShipPaints.hull, NAN, maxf(shape.z, shape.w))


## Where one run of the loft meets the next at the same station: the step between
## the two sections up to the lower deck edge — facing the narrower side — and,
## above that, the taller run's break face up to its deck. Never a whole section:
## that would wall off a room the two runs share.
func _step(
	mesh: ShipMesh,
	aft: PackedVector3Array,
	aft_shape: Vector4,
	fore: PackedVector3Array,
	fore_shape: Vector4
) -> void:
	var low := Vector2(minf(aft_shape.z, fore_shape.z), minf(aft_shape.w, fore_shape.w))
	var a := aft.duplicate()
	var b := fore.duplicate()
	for section: PackedVector3Array in [a, b]:
		section[0].y = minf(section[0].y, low.x)
		section[section.size() - 1].y = minf(section[section.size() - 1].y, low.y)
	var top := maxf(maxf(aft_shape.z, aft_shape.w), maxf(fore_shape.z, fore_shape.w))
	for j in a.size() - 1:
		var aft_width := absf(a[j].z) + absf(a[j + 1].z)
		var fore_width := absf(b[j].z) + absf(b[j + 1].z)
		if absf(aft_width - fore_width) < SLIVER:
			continue
		var normal := Vector3.RIGHT if aft_width > fore_width else Vector3.LEFT
		mesh.quad(a[j], a[j + 1], b[j + 1], b[j], normal, ShipPaints.hull, 0, NAN, top)
	var aft_top := maxf(aft_shape.z, aft_shape.w)
	var fore_top := maxf(fore_shape.z, fore_shape.w)
	if absf(aft_top - fore_top) < SLIVER:
		return
	var taller := aft_shape if aft_top > fore_top else fore_shape
	var facing := Vector3.RIGHT if aft_top > fore_top else Vector3.LEFT
	# Set into the taller run, so a blocker standing on the same line shows in front.
	var x := aft[0].x - facing.x * BREAK_INSET
	var bottom := minf(aft_top, fore_top)
	var height := maxf(aft_top, fore_top) - bottom
	mesh.face(
		Vector3(x, bottom, taller.x),
		Vector3(0.0, 0.0, taller.y - taller.x) if facing.x < 0.0 else Vector3(0.0, height, 0.0),
		Vector3(0.0, height, 0.0) if facing.x < 0.0 else Vector3(0.0, 0.0, taller.y - taller.x),
		ShipPaints.hull,
		ShipMesh.RIM_ALL,
		NAN,
		maxf(aft_top, fore_top)
	)


## The hull's section at [param x] under the outline [param shape], from the port
## deck edge down round the keel and up to the starboard deck edge; at the hull's two
## ends it leans in toward the keel.
func _profile(x: float, shape: Vector4) -> PackedVector3Array:
	var deep_keel := -(_layout.freeboard + DRAFT)
	var end_keel := -(_layout.freeboard + END_DRAFT)
	var keel := deep_keel
	if x < _deep.x - SLIVER:
		keel = lerpf(end_keel, deep_keel, inverse_lerp(_span.x, _deep.x, x))
	elif x > _deep.y + SLIVER:
		keel = lerpf(deep_keel, end_keel, inverse_lerp(_deep.y, _span.y, x))
	var inside := _space.content_bottom(x, ShipArt.PLANK)
	keel = minf(keel, inside - KEEL_CLEARANCE)
	var end := 0.0
	if x <= _span.x + SLIVER:
		end = -1.0
	elif x >= _span.y - SLIVER:
		end = 1.0
	var section: Array[Vector2] = []
	section.append_array(_side(shape.x, shape.z, keel, inside, end != 0.0))
	section.append(Vector2(0.0, keel))
	var starboard := _side(shape.y, shape.w, keel, inside, end != 0.0)
	starboard.reverse()
	section.append_array(starboard)
	var top := maxf(shape.z, shape.w)
	var points := PackedVector3Array()
	for point: Vector2 in section:
		points.append(Vector3(x - end * RAKE * (top - point.y), point.y, point.x))
	return points


## One side of a section (z, y), from the deck edge at ([param edge], [param deck])
## down to the keel at [param keel].
func _side(edge: float, deck: float, keel: float, inside: float, pinched: bool) -> Array[Vector2]:
	var knee := maxf(minf(lerpf(keel, deck, 0.4), inside - KNEE_CLEARANCE), keel + 0.3)
	var squeeze := END_PINCH if pinched else 1.0
	var points: Array[Vector2] = [
		Vector2(edge, deck),
		Vector2(edge, knee),
		Vector2(edge * 0.93 * lerpf(1.0, squeeze, 0.5), knee - 0.55 * (knee - keel)),
		Vector2(edge * 0.72 * squeeze, keel + 0.12 * (knee - keel)),
		Vector2(edge * 0.4 * squeeze, keel),
	]
	return points


## The normal of the plane through [param ring] (Newell's method).
func _newell(ring: PackedVector3Array) -> Vector3:
	var normal := Vector3.ZERO
	for index in ring.size():
		var a := ring[index]
		var b := ring[(index + 1) % ring.size()]
		normal += Vector3(
			(a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)
		)
	return normal.normalized()
