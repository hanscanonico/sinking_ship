class_name ShipOccluders
extends OccluderInstance3D
## What of the dressed ship hides from the renderer whatever stands wholly behind it
## (occlusion culling), so a corridor deep in the Titanic draws her few hundred pieces
## in sight rather than thousands down her length: the broad, solid faces ShipArt draws,
## as flat quads in ship space. Every deck's top, but a deck the sinking can collapse;
## every wall down its middle, from its foot to its top, so a doorway under its lintel
## stays open; every slab roofing a room. Each stops EDGE short of its edges, is kept to
## the stretch of her the art draws (span) and stays under its cut-away (cut_above). The
## hull is none: the sinking opens its portholes. Walls are drawn solid with their
## windows on their faces (ShipArt, ShipFittings), so a window hides what a wall does.
## It stands where the ship it hangs under is drawn, but is moved only once she has moved
## SLIP from where it was last put, anywhere along her: the renderer builds an occluder
## that moves afresh, a whole scene's worth, every frame it does, and a sinking ship moves
## a hair every frame. Drawn only (D5).

## How far in from each edge a quad stops: past how far the occluders may stand off a
## moving ship — SLIP, and the renderer rebuilding them on a thread a frame or two
## behind — so no quad left behind hides a doorway's edge or a deck's.
const EDGE := 0.05
## A wall shorter than this along its length hides too little to be worth a quad.
const LEAST := 0.3
## How far, in metres, the ship may move from where its occluder was last put, at the
## furthest point of it, before it is put again: well inside EDGE.
const SLIP := 0.02

## How far from her origin its furthest point stands: how far a turn of her moves it.
var _reach := 0.0


## The occluder of [param space]'s ship, as of() makes it, standing where the ship it
## hangs under is drawn.
func _init(
	space: ShipSpace = null,
	falls: Array[StringName] = [],
	span := Vector2(-INF, INF),
	cut_above := INF
) -> void:
	name = "Occluders"
	top_level = true
	if space != null:
		cut(space, falls, span, cut_above)


## Makes it again, kept to [param span] along her: as of() makes it.
func cut(space: ShipSpace, falls: Array[StringName], span: Vector2, cut_above: float) -> void:
	var made := of(space, falls, span, cut_above)
	_reach = 0.0
	for point: Vector3 in made.vertices:
		_reach = maxf(_reach, point.length())
	occluder = made


func _enter_tree() -> void:
	global_transform = (get_parent() as Node3D).global_transform


func _process(_delta: float) -> void:
	var drawn := (get_parent() as Node3D).global_transform
	if moved_past(global_transform, drawn, _reach):
		global_transform = drawn


## Whether a ship drawn at [param drawn] has moved SLIP or more from [param placed], at
## any point within [param reach] of her origin: how far her origin moved, and how far
## her turn carried a point a metre out along any of her axes, [param reach] times —
## read off her axes themselves, which keep a hair's turn a single-precision angle loses.
static func moved_past(placed: Transform3D, drawn: Transform3D, reach: float) -> bool:
	var turned := maxf(
		maxf((drawn.basis.x - placed.basis.x).length(), (drawn.basis.y - placed.basis.y).length()),
		(drawn.basis.z - placed.basis.z).length()
	)
	return placed.origin.distance_to(drawn.origin) + turned * reach >= SLIP


## The occluder of [param space]'s ship: her decks but those named in [param falls], her
## walls and her slabs, kept to [param span] along her and under [param cut_above].
static func of(
	space: ShipSpace, falls: Array[StringName] = [], span := Vector2(-INF, INF), cut_above := INF
) -> ArrayOccluder3D:
	var points := PackedVector3Array()
	var order := PackedInt32Array()
	for platform: ShipPlatform in space.layout.platforms:
		if not platform.name in falls and platform.height < cut_above:
			_level(points, order, platform.area, platform.height, span)
	for blocker: ShipBlocker in space.layout.blockers:
		if space.is_wall(blocker):
			_upright(points, order, blocker, minf(blocker.top, cut_above), span)
		elif (
			blocker.shape == ShipBlocker.Shape.BOX
			and blocker.top - blocker.bottom <= ShipSpace.WALL_MAX
			and blocker.top < cut_above
			and space.roofs(blocker)
		):
			_level(points, order, blocker.area, blocker.top, span)
	var occluder := ArrayOccluder3D.new()
	occluder.set_arrays(points, order)
	return occluder


## A level quad over [param area] at [param height], cut to [param span].
static func _level(
	points: PackedVector3Array, order: PackedInt32Array, area: Rect2, height: float, span: Vector2
) -> void:
	var x0 := maxf(area.position.x, span.x) + EDGE
	var x1 := minf(area.end.x, span.y) - EDGE
	var z0 := area.position.y + EDGE
	var z1 := area.end.y - EDGE
	if x1 <= x0 or z1 <= z0:
		return
	_quad(
		points,
		order,
		[
			Vector3(x0, height, z0),
			Vector3(x1, height, z0),
			Vector3(x1, height, z1),
			Vector3(x0, height, z1)
		]
	)


## An upright quad down the middle of wall [param wall], from its foot to [param top],
## cut to [param span].
static func _upright(
	points: PackedVector3Array,
	order: PackedInt32Array,
	wall: ShipBlocker,
	top: float,
	span: Vector2
) -> void:
	var area := wall.area
	var low := wall.bottom + EDGE
	var high := top - EDGE
	var middle := area.get_center()
	# A wall thin across x runs along z, at its middle's x; else along x.
	var along_z := area.size.x <= area.size.y
	var from := area.position.y + EDGE if along_z else maxf(area.position.x, span.x) + EDGE
	var to := area.end.y - EDGE if along_z else minf(area.end.x, span.y) - EDGE
	if high <= low or to - from < LEAST or along_z and (middle.x < span.x or middle.x > span.y):
		return
	if along_z:
		_quad(
			points,
			order,
			[
				Vector3(middle.x, low, from),
				Vector3(middle.x, low, to),
				Vector3(middle.x, high, to),
				Vector3(middle.x, high, from)
			]
		)
	else:
		_quad(
			points,
			order,
			[
				Vector3(from, low, middle.y),
				Vector3(to, low, middle.y),
				Vector3(to, high, middle.y),
				Vector3(from, high, middle.y)
			]
		)


## The quad on [param corners], in turn round it, as two triangles: an occluder hides
## from either side, whichever way it winds.
static func _quad(points: PackedVector3Array, order: PackedInt32Array, corners: Array) -> void:
	var at := points.size()
	for corner: Vector3 in corners:
		points.append(corner)
	order.append_array([at, at + 1, at + 2, at, at + 2, at + 3])
