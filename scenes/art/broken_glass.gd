class_name BrokenGlass
extends RefCounted
## The glass the sinking can break (SH31), as ShipArt draws it: over every pane of a
## window or porthole that starts shut and can give way (SinkFailures), on the inside of
## its wall, a piece of its own shown once the pose has it given way (ShipPose.opened) —
## the glass gone but for jagged shards round its frame, the dark of the bore through
## the wall round the view out. The water pouring in through it is InnerWater's; the
## splinters flying as it goes, FailureFx's. Presentation only (D12).

## How far over the pane, into the room, the broken look stands; how far in from its
## rim the bore's dark band reaches, as a share of the pane; how many shards round it,
## and how far in toward its middle they reach, at least and at most.
const PROUD := 0.006
const BORE := 0.8
const SHARDS := 7
const SHARD_REACH := Vector2(0.25, 0.55)
## How near a pane must stand to an opening, along its wall and up it, to be its: the
## art-lint's tolerance (tools/art_lint.gd's PANE_TOLERANCE).
const NEAR := 0.05

## Per opening that can break, by name, the node its broken look hangs from.
var _nodes := {}


## The broken look of every pane of [param panes] (ShipFittings.panes) that is a window
## or porthole of [param layout]'s structure able to break, under [param art] in
## [param paints] (ShipArt.paints).
func _init(layout: ShipLayout, panes: Array[Array], art: Node3D, paints: Dictionary) -> void:
	if layout.structure == null:
		return
	var glass: Array[ShipOpening] = []
	for opening: ShipOpening in layout.structure.openings:
		var kind := opening.kind
		var breaks := opening.starts == ShipOpening.Start.SHUT and opening.can_fail()
		if breaks and kind in [ShipOpening.Kind.PORTHOLE, ShipOpening.Kind.WINDOW]:
			glass.append(opening)
	for pane: Array in panes:
		var found := ShipFittings.openings_of(pane, glass, NEAR)
		if found.size() != 1:
			continue
		var no_rooms: Array[PackedFloat32Array] = [
			PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
		]
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, no_rooms)
		var centre: Vector3 = pane[1] + (pane[2] as Vector3) * PROUD
		if pane[3]:
			_porthole(mesh, centre, pane[2])
		else:
			_window(mesh, centre, pane[2], pane[4])
		var node := Node3D.new()
		node.name = "Broken_%s" % glass[found[0]].name
		node.visible = false
		art.add_child(node)
		mesh.commit(node, paints)
		_nodes[glass[found[0]].name] = node


## Shows each pane [param pose] has given way broken.
func show(pose: ShipPose) -> void:
	for opening: StringName in _nodes:
		var node: Node3D = _nodes[opening]
		var broken: bool = pose.opened.get(opening, 0) == 2
		if node.visible != broken:
			node.visible = broken


## A porthole's glass gone at [param centre], facing [param normal] into its room: the
## dark of its bore round the view out, shards left in its ring.
func _porthole(mesh: ShipMesh, centre: Vector3, normal: Vector3) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var radius := ShipFittings.PORTHOLE_RADIUS
	var view := PackedVector3Array()
	for index in ShipFittings.PORTHOLE_SEGMENTS:
		var angle := TAU * index / ShipFittings.PORTHOLE_SEGMENTS
		view.append(centre + (right * cos(angle) + Vector3.UP * sin(angle)) * radius * BORE)
	mesh.polygon(view, normal, ShipPaints.glass_in, centre.y - radius, NAN)
	var count := ShipFittings.PORTHOLE_SEGMENTS
	for index in count:
		var spokes: Array[Vector3] = []
		for at: int in [index, (index + 1) % count]:
			var angle := TAU * at / count
			spokes.append(right * cos(angle) + Vector3.UP * sin(angle))
		mesh.quad(
			centre + spokes[0] * radius * BORE + normal * 0.001,
			centre + spokes[1] * radius * BORE + normal * 0.001,
			centre + spokes[1] * radius,
			centre + spokes[0] * radius,
			normal,
			ShipPaints.dark,
			0
		)
	for shard in SHARDS:
		var angle := TAU * (shard + 0.37 * (shard % 3)) / SHARDS
		var width := TAU / SHARDS * 0.45
		var reach := lerpf(SHARD_REACH.x, SHARD_REACH.y, fposmod(shard * 0.618, 1.0))
		var tip := angle + width * (fposmod(shard * 0.41, 1.0) - 0.5)
		var at := func(turn: float, out: float) -> Vector3:
			return centre + normal * 0.002 + (right * cos(turn) + Vector3.UP * sin(turn)) * out
		var shard_points := PackedVector3Array(
			[
				at.call(angle - width, radius),
				at.call(angle + width, radius),
				at.call(tip, radius * (1.0 - reach))
			]
		)
		mesh.polygon(shard_points, normal, ShipPaints.glass_out, centre.y - radius, NAN)


## A window's glass gone at [param centre], facing [param normal] into its room, its
## half size [param half]: the dark inside its frame round the view out, shards along
## its edges and in its corners.
func _window(mesh: ShipMesh, centre: Vector3, normal: Vector3, half: Vector2) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var point := func(x: float, y: float, proud: float) -> Vector3:
		return centre + right * x + Vector3.UP * y + normal * proud
	var inner := half * BORE
	mesh.quad(
		point.call(-inner.x, -inner.y, 0.0),
		point.call(inner.x, -inner.y, 0.0),
		point.call(inner.x, inner.y, 0.0),
		point.call(-inner.x, inner.y, 0.0),
		normal,
		ShipPaints.glass_in,
		0
	)
	# The dark band round it: four strips between the view and the frame.
	var strips := [
		Rect2(-half.x, -half.y, half.x * 2.0, half.y - inner.y),
		Rect2(-half.x, inner.y, half.x * 2.0, half.y - inner.y),
		Rect2(-half.x, -inner.y, half.x - inner.x, inner.y * 2.0),
		Rect2(inner.x, -inner.y, half.x - inner.x, inner.y * 2.0),
	]
	for strip: Rect2 in strips:
		mesh.quad(
			point.call(strip.position.x, strip.position.y, 0.001),
			point.call(strip.end.x, strip.position.y, 0.001),
			point.call(strip.end.x, strip.end.y, 0.001),
			point.call(strip.position.x, strip.end.y, 0.001),
			normal,
			ShipPaints.dark,
			0
		)
	for shard in SHARDS:
		var share := fposmod(shard * 0.618 + 0.13, 1.0)
		var reach := lerpf(SHARD_REACH.x, SHARD_REACH.y, fposmod(shard * 0.41, 1.0))
		var edge := shard % 4
		var along := lerpf(-1.0, 1.0, share)
		var width := 0.18
		var base_a := Vector2.ZERO
		var base_b := Vector2.ZERO
		var tip := Vector2.ZERO
		match edge:
			0:
				base_a = Vector2((along - width) * half.x, -half.y)
				base_b = Vector2((along + width) * half.x, -half.y)
				tip = Vector2(along * half.x, -half.y * (1.0 - reach * 2.0))
			1:
				base_a = Vector2((along + width) * half.x, half.y)
				base_b = Vector2((along - width) * half.x, half.y)
				tip = Vector2(along * half.x, half.y * (1.0 - reach * 2.0))
			2:
				base_a = Vector2(-half.x, (along + width) * half.y)
				base_b = Vector2(-half.x, (along - width) * half.y)
				tip = Vector2(-half.x * (1.0 - reach * 2.0), along * half.y)
			_:
				base_a = Vector2(half.x, (along - width) * half.y)
				base_b = Vector2(half.x, (along + width) * half.y)
				tip = Vector2(half.x * (1.0 - reach * 2.0), along * half.y)
		var shard_points := PackedVector3Array(
			[
				point.call(base_a.x, base_a.y, 0.002),
				point.call(base_b.x, base_b.y, 0.002),
				point.call(tip.x, tip.y, 0.002),
			]
		)
		mesh.polygon(shard_points, normal, ShipPaints.glass_out, centre.y - half.y, NAN)
