class_name ShipFittings
extends RefCounted
## What a ship's rooms and decks are fitted with (ShipArt), placed by rules on the
## layout, never by hand: glass in every outside wall — a brass-ringed porthole
## below the deck the hull reaches, a framed window above — shown both inside and
## out; furniture by the kind of room its shape says it is; and lifeboats on davits
## under a high deck's open edge. Furniture stands within a body's radius of a wall,
## where no body's centre ever goes, and only where the floor is clear: a prop the
## rules cannot see never stands in anyone's way.

const PORTHOLE_RADIUS := 0.16
const PORTHOLE_RING := 0.05
const PORTHOLE_SEGMENTS := 14
const WINDOW_SIZE := Vector2(0.55, 0.6)
const WINDOW_FRAME := 0.06
## Glass is centred this high over its floor, this far apart, and kept this far from
## a wall's end or a room's corner.
const WINDOW_HEIGHT := 1.45
const WINDOW_SPACING := 1.3
const WINDOW_MARGIN := 0.4
const GLASS_PROUD := 0.012
const FRAME_PROUD := 0.01
## A room narrower than CORRIDOR has no furniture; one below the main deck this big
## is a hold and takes cargo; one above it this big is a saloon and takes banquettes;
## the others a berth, and the highest room, if small, a helm.
const CORRIDOR := 1.8
const HOLD_AREA := 40.0
const SALOON_AREA := 15.0
const PROP_GAP := 0.03
const CARGO_SPACING := 1.2
## Lifeboats hang under the open long edge of a deck that stands at least this high
## over the deck beneath it.
const LIFEBOAT_HEADROOM := 2.4
const LIFEBOAT_LENGTH := 4.0
const LIFEBOAT_BEAM := 1.1
const LIFEBOAT_DEPTH := 0.7
const LIFEBOAT_SPACING := 5.0
## How far the boat hangs out from the deck's edge, and its keel below the deck.
const LIFEBOAT_OUT := 0.3
const LIFEBOAT_DROP := 0.45

var _space: ShipSpace
var _layout: ShipLayout
## How deep furniture stands out from a wall: the body radius.
var _depth: float


func _init(space: ShipSpace, body_radius: float) -> void:
	_space = space
	_layout = space.layout
	_depth = body_radius


func build(mesh: ShipMesh) -> void:
	var top_floor := -INF
	for room: ShipRoom in _layout.rooms:
		top_floor = maxf(top_floor, room.floor_height)
	for room: ShipRoom in _layout.rooms:
		_windows(mesh, room)
		_furnish(mesh, room, room.floor_height >= top_floor)
	_lifeboats(mesh)


## Glass in every outside wall of [param room]: on the wall's inner face, and on its
## outer face — or, below the deck the hull's outline reaches, on the hull's side.
func _windows(mesh: ShipMesh, room: ShipRoom) -> void:
	var height := room.floor_height + WINDOW_HEIGHT
	for run: Array in _space.wall_runs(room):
		var side: int = run[0]
		var half: float = run[3]
		var from: float = run[1] + WINDOW_MARGIN
		var to: float = run[2] - WINDOW_MARGIN
		if to < from:
			continue
		var count := floori((to - from) / WINDOW_SPACING) + 1
		var outward := ShipSpace.outward(side)
		var normal := Vector3(outward.x, 0.0, outward.y)
		for index in count:
			var along := (from + to) * 0.5 + (index - (count - 1) * 0.5) * WINDOW_SPACING
			var on_line := _space.on_side(room, side, along, 0.0)
			var beyond := on_line + outward * (half + ShipMesh.PROBE)
			if (
				not _space.outdoors(Vector3(beyond.x, height, beyond.y))
				or _space.under_a_ramp(beyond, height)
			):
				continue
			var shape := _space.envelope(beyond.x)
			var in_hull := shape.x != INF and height < minf(shape.z, shape.w)
			# A hull's glass goes in its sides, never its ends.
			if in_hull and side % 2 == 1:
				continue
			var inner := on_line - outward * (half + GLASS_PROUD)
			_pane(mesh, Vector3(inner.x, height, inner.y), -normal, in_hull, ShipPaints.glass_in)
			var outer := on_line + outward * (half + GLASS_PROUD)
			if in_hull:
				outer.y = (shape.x if side == 0 else shape.y) + outward.y * GLASS_PROUD
			_pane(mesh, Vector3(outer.x, height, outer.y), normal, in_hull, ShipPaints.glass_out)


## A porthole (round, brass-ringed) or a window (square, wooden frame) centred on
## [param centre], facing [param normal].
func _pane(
	mesh: ShipMesh, centre: Vector3, normal: Vector3, porthole: bool, glass: ShipMesh.Paint
) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var lift := normal * FRAME_PROUD
	if porthole:
		var ring := PackedVector3Array()
		var outer := PackedVector3Array()
		for index in PORTHOLE_SEGMENTS:
			var angle := TAU * index / PORTHOLE_SEGMENTS
			var spoke := right * cos(angle) + Vector3.UP * sin(angle)
			ring.append(centre + spoke * PORTHOLE_RADIUS)
			outer.append(centre + spoke * (PORTHOLE_RADIUS + PORTHOLE_RING) + lift)
		mesh.polygon(ring, normal, glass, centre.y - PORTHOLE_RADIUS, NAN)
		for index in PORTHOLE_SEGMENTS:
			var next := (index + 1) % PORTHOLE_SEGMENTS
			mesh.quad(
				ring[index] + lift,
				ring[next] + lift,
				outer[next],
				outer[index],
				normal,
				ShipPaints.brass,
				ShipMesh.RIM_V0
			)
		return
	var half := WINDOW_SIZE * 0.5
	mesh.quad(
		centre - right * half.x - Vector3.UP * half.y,
		centre + right * half.x - Vector3.UP * half.y,
		centre + right * half.x + Vector3.UP * half.y,
		centre - right * half.x + Vector3.UP * half.y,
		normal,
		glass,
		0,
		centre.y - half.y,
		NAN
	)
	var grow := half + Vector2.ONE * WINDOW_FRAME
	var bars: Array[Rect2] = [
		Rect2(-grow.x, -grow.y, grow.x * 2.0, WINDOW_FRAME),
		Rect2(-grow.x, half.y, grow.x * 2.0, WINDOW_FRAME),
		Rect2(-grow.x, -half.y, WINDOW_FRAME, half.y * 2.0),
		Rect2(half.x, -half.y, WINDOW_FRAME, half.y * 2.0),
	]
	for bar: Rect2 in bars:
		var low := bar.position
		var high := bar.end
		mesh.quad(
			centre + right * low.x + Vector3.UP * low.y + lift,
			centre + right * high.x + Vector3.UP * low.y + lift,
			centre + right * high.x + Vector3.UP * high.y + lift,
			centre + right * low.x + Vector3.UP * high.y + lift,
			normal,
			ShipPaints.frame
		)


## A room's furniture, by what kind of room its shape says it is.
func _furnish(mesh: ShipMesh, room: ShipRoom, top_room: bool) -> void:
	var size := room.area.size
	if minf(size.x, size.y) < CORRIDOR or _space.machinery_in(room):
		return
	var area := size.x * size.y
	var runs := _space.wall_runs(room)
	runs.sort_custom(func(a: Array, b: Array) -> bool: return a[2] - a[1] > b[2] - b[1])
	if top_room and area < SALOON_AREA:
		_helm(mesh, room, runs)
	elif room.floor_height < 0.0 and area >= HOLD_AREA:
		for run: Array in runs:
			_cargo(mesh, room, run)
	elif room.floor_height >= 0.0 and area >= SALOON_AREA:
		for run: Array in runs:
			_banquette(mesh, room, run)
	else:
		for run: Array in runs:
			if _berth(mesh, room, run):
				return


## The ship-plane rectangle [param from]…[param to] along [param run] and
## [param near]…[param far] in from its wall's face.
func _along(room: ShipRoom, run: Array, from: float, to: float, near: float, far: float) -> Rect2:
	var half: float = run[3]
	var a := _space.on_side(room, run[0], from, half + near)
	var b := _space.on_side(room, run[0], to, half + far)
	return Rect2(a, Vector2.ZERO).expand(b)


## A berth along [param run]: a wooden frame, a mattress, a blanket and a pillow.
## Whether there was room for it.
func _berth(mesh: ShipMesh, room: ShipRoom, run: Array) -> bool:
	var floor := room.floor_height
	var length := minf(1.9, run[2] - run[1] - PROP_GAP * 2.0)
	if length < 1.5:
		return false
	var start: float = run[1] + PROP_GAP
	var end := start + length
	var frame := _along(room, run, start, end, PROP_GAP, _depth)
	if not _space.clear(frame, floor, floor + 0.6):
		return false
	var faces := ShipMesh.SIDES | ShipMesh.TOP
	mesh.box(frame, floor, floor + 0.36, ShipPaints.frame, faces)
	var mattress := _along(room, run, start + 0.05, end - 0.05, PROP_GAP + 0.03, _depth - 0.03)
	mesh.box(mattress, floor + 0.36, floor + 0.47, ShipPaints.linen, faces)
	var blanket := _along(
		room, run, start + length * 0.35, end - 0.03, PROP_GAP + 0.01, _depth - 0.01
	)
	mesh.box(blanket, floor + 0.4, floor + 0.5, ShipPaints.blanket, faces)
	var pillow := _along(room, run, start + 0.08, start + 0.4, PROP_GAP + 0.06, _depth - 0.06)
	mesh.box(pillow, floor + 0.47, floor + 0.55, ShipPaints.linen, faces)
	return true


## A banquette along [param run]: a wooden base, a seat and a back.
func _banquette(mesh: ShipMesh, room: ShipRoom, run: Array) -> void:
	var floor := room.floor_height
	var start: float = run[1] + PROP_GAP
	var end: float = run[2] - PROP_GAP
	if end - start < 1.0:
		return
	var seat := _along(room, run, start, end, PROP_GAP, _depth)
	if not _space.clear(seat, floor, floor + 0.9):
		return
	var faces := ShipMesh.SIDES | ShipMesh.TOP
	mesh.box(seat, floor, floor + 0.28, ShipPaints.frame, faces)
	var cushion := _along(room, run, start + 0.02, end - 0.02, PROP_GAP, _depth - 0.02)
	mesh.box(cushion, floor + 0.28, floor + 0.42, ShipPaints.upholstery, faces)
	var back := _along(room, run, start + 0.02, end - 0.02, 0.0, PROP_GAP + 0.1)
	mesh.box(back, floor + 0.42, floor + 0.85, ShipPaints.upholstery, faces)


## Crates and barrels against the wall along [param run], a crate stacked here and
## there.
func _cargo(mesh: ShipMesh, room: ShipRoom, run: Array) -> void:
	var floor := room.floor_height
	var size := _depth - PROP_GAP
	var slots := floori((run[2] - run[1]) / CARGO_SPACING)
	for slot in slots:
		var at: float = run[1] + 0.2 + slot * CARGO_SPACING
		var spot := _along(room, run, at, at + size, PROP_GAP, _depth)
		if not _space.clear(spot, floor, floor + size * 2.0):
			continue
		if slot % 3 == 1:
			var centre := spot.get_center()
			var radius := size * 0.45
			mesh.cylinder(centre, radius, floor, floor + 0.55, 10, ShipPaints.frame)
			for hoop: float in [0.12, 0.43]:
				mesh.cylinder(
					centre,
					radius + 0.01,
					floor + hoop - 0.02,
					floor + hoop + 0.02,
					10,
					ShipPaints.steel,
					false
				)
			continue
		mesh.box(spot, floor, floor + size, ShipPaints.crate, ShipMesh.SIDES | ShipMesh.TOP)
		if slot % 3 == 0:
			var middle := spot.get_center()
			mesh.turned_box(
				Transform3D(
					Basis(Vector3.UP, 0.25), Vector3(middle.x, floor + size * 1.4, middle.y)
				),
				Vector3.ONE * size * 0.8,
				ShipPaints.crate
			)


## A ship's wheel on its pedestal and a brass binnacle, against the forward wall.
func _helm(mesh: ShipMesh, room: ShipRoom, runs: Array) -> void:
	var floor := room.floor_height
	for run: Array in runs:
		if run[0] != 1:
			continue
		var middle: float = (run[1] + run[2]) * 0.5
		var post := _along(room, run, middle - 0.07, middle + 0.07, 0.15, 0.29)
		if not _space.clear(post, floor, floor + 1.4):
			return
		mesh.box(post, floor, floor + 0.95, ShipPaints.frame, ShipMesh.SIDES | ShipMesh.TOP)
		var at := _space.on_side(room, 1, middle, run[3] + 0.32)
		var hub := Vector3(at.x, floor + 1.05, at.y)
		var normal := Vector3.LEFT
		var right := normal.cross(Vector3.UP).normalized()
		var inner := PackedVector3Array()
		var outer := PackedVector3Array()
		for index in 16:
			var spoke := right * cos(TAU * index / 16) + Vector3.UP * sin(TAU * index / 16)
			inner.append(hub + spoke * 0.28)
			outer.append(hub + spoke * 0.34)
		for index in 16:
			var next := (index + 1) % 16
			mesh.quad(
				inner[index], inner[next], outer[next], outer[index], normal, ShipPaints.frame
			)
		for angle: float in [0.0, PI / 4.0, PI / 2.0, PI * 0.75]:
			mesh.turned_box(
				Transform3D(Basis(Vector3.RIGHT, angle), hub),
				Vector3(0.03, 0.74, 0.03),
				ShipPaints.frame
			)
		var binnacle := _along(room, run, middle + 0.45, middle + 0.75, 0.05, _depth)
		if _space.clear(binnacle, floor, floor + 1.2):
			var centre := binnacle.get_center()
			mesh.cylinder(centre, 0.13, floor, floor + 1.0, 12, ShipPaints.brass)
			mesh.cylinder(centre, 0.1, floor + 1.0, floor + 1.12, 12, ShipPaints.dark)
		return


## Lifeboats on davits under the open long edges of every deck standing high enough
## over the deck beneath, where the air beyond the edge is open.
func _lifeboats(mesh: ShipMesh) -> void:
	for index in _layout.platforms.size():
		var platform := _layout.platforms[index]
		var area := platform.area
		if area.size.x < LIFEBOAT_LENGTH + 0.5:
			continue
		for side: float in [-1.0, 1.0]:
			var edge := area.position.y if side < 0.0 else area.end.y
			if _railed(index, edge):
				continue
			var middle := edge + side * (LIFEBOAT_OUT + LIFEBOAT_BEAM * 0.5)
			var outer := edge + side * (LIFEBOAT_OUT + LIFEBOAT_BEAM + 0.2)
			var x := area.get_center().x
			var below := _space.deck_under(Vector2(x, outer), platform.height - LIFEBOAT_HEADROOM)
			if is_nan(below) or is_nan(_space.deck_under(Vector2(x, middle), below)):
				continue
			var keel := platform.height - LIFEBOAT_DROP
			var reach := Rect2(area.position.x, minf(edge, outer), area.size.x, absf(outer - edge))
			if not _open(reach, keel):
				continue
			var count := floori(area.size.x / LIFEBOAT_SPACING)
			for boat in count:
				var at := area.position.x + area.size.x * (boat + 0.5) / count
				_boat(mesh, Vector3(at, keel, middle))
				for end: float in [-1.0, 1.0]:
					var davit := at + end * (LIFEBOAT_LENGTH * 0.5 - 0.35)
					_davit(mesh, davit, edge, middle, platform.height, side)


## Whether nothing of the ship stands in [param area] at or above [param height]: no
## deck over it and no room round it — open air for a boat to hang in.
func _open(area: Rect2, height: float) -> bool:
	for platform: ShipPlatform in _layout.platforms:
		if platform.height >= height and platform.area.intersects(area):
			return false
	var middle := area.get_center()
	return _space.outdoors(Vector3(middle.x, height + LIFEBOAT_DEPTH * 0.5, middle.y))


## Whether platform [param index] carries a railing along its edge at z [param edge].
func _railed(index: int, edge: float) -> bool:
	for railing: ShipRailing in _layout.railings:
		if (
			railing.platform == index
			and is_equal_approx(railing.from.y, edge)
			and is_equal_approx(railing.to.y, edge)
		):
			return true
	return false


## A double-ended boat lying fore and aft, its keel's middle at [param keel], under
## a canvas cover.
func _boat(mesh: ShipMesh, keel: Vector3) -> void:
	var stations: Array[Vector2] = [
		Vector2(-0.5, 0.0),
		Vector2(-0.38, 0.8),
		Vector2(0.0, 1.0),
		Vector2(0.38, 0.8),
		Vector2(0.5, 0.0),
	]
	var gunwale := keel.y + LIFEBOAT_DEPTH
	var sections: Array[PackedVector3Array] = []
	for station: Vector2 in stations:
		var x := keel.x + station.x * LIFEBOAT_LENGTH
		var half := LIFEBOAT_BEAM * 0.5 * station.y
		var rise := (1.0 - station.y) * 0.3
		(
			sections
			. append(
				PackedVector3Array(
					[
						Vector3(x, gunwale, keel.z - half),
						Vector3(x, keel.y + 0.2 + rise, keel.z - half * 0.8),
						Vector3(x, keel.y + rise, keel.z),
						Vector3(x, keel.y + 0.2 + rise, keel.z + half * 0.8),
						Vector3(x, gunwale, keel.z + half),
						Vector3(x, gunwale + 0.14 * station.y, keel.z),
					]
				)
			)
		)
	for i in sections.size() - 1:
		for j in 6:
			var a := sections[i][j]
			var b := sections[i][(j + 1) % 6]
			var c := sections[i + 1][(j + 1) % 6]
			var d := sections[i + 1][j]
			var normal := (c - a).cross(d - b).normalized()
			var middle := (a + b + c + d) * 0.25
			if normal.dot(middle - Vector3(middle.x, keel.y + 0.35, keel.z)) < 0.0:
				normal = -normal
			mesh.quad(a, b, c, d, normal, ShipPaints.canvas if j >= 4 else ShipPaints.white, 0)
	var rail := Rect2(
		keel.x - LIFEBOAT_LENGTH * 0.4,
		keel.z - LIFEBOAT_BEAM * 0.5 - 0.02,
		LIFEBOAT_LENGTH * 0.8,
		LIFEBOAT_BEAM + 0.04
	)
	mesh.box(rail, gunwale - 0.06, gunwale, ShipPaints.teak, ShipMesh.SIDES)


## A davit at [param x]: a post off the deck's edge at [param edge], an arm out over
## the boat's middle, and its fall down to the boat.
func _davit(mesh: ShipMesh, x: float, edge: float, middle: float, deck: float, side: float) -> void:
	var from := edge + side * 0.02
	var post := Rect2(Vector2(x - 0.05, from), Vector2.ZERO).expand(
		Vector2(x + 0.05, from + side * 0.1)
	)
	mesh.box(post, deck - 0.7, deck + 1.0, ShipPaints.dark)
	var arm := Rect2(Vector2(x - 0.04, from), Vector2.ZERO).expand(Vector2(x + 0.04, middle))
	mesh.box(arm, deck + 0.9, deck + 1.0, ShipPaints.dark)
	var gunwale := deck - LIFEBOAT_DROP + LIFEBOAT_DEPTH
	mesh.box(
		Rect2(x - 0.01, middle - 0.01, 0.02, 0.02),
		gunwale,
		deck + 0.9,
		ShipPaints.beam,
		ShipMesh.SIDES
	)
