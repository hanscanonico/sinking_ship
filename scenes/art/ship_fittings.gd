class_name ShipFittings
extends RefCounted
## What a ship's rooms and decks are fitted with (ShipArt), placed by rules on the
## layout, never by hand: glass in every outside wall — a brass-ringed porthole
## below the deck the hull reaches, a framed window above — shown both inside and
## out; banquettes in a saloon and a berth in a cabin, by the kind of room
## RoomDressing says it is (it furnishes the rest); lifeboats on davits under a high
## deck's open edge; a cap rail and a door or vents in every break of the decks; and
## the ground tackle lying on the deck at the bow. Furniture stands within a body's
## radius of a wall, where no body's centre ever goes, and only where the floor is
## clear: a prop the rules cannot see never stands in anyone's way.

const PORTHOLE_RADIUS := 0.16
const PORTHOLE_RING := 0.05
const PORTHOLE_SEGMENTS := 20
const WINDOW_SIZE := Vector2(0.55, 0.6)
## A helm's window where a full one has no room.
const NARROW_WINDOW := Vector2(0.38, 0.6)
const WINDOW_FRAME := 0.06
## The bars dividing a window's glass into panes.
const GLAZING_BAR := 0.025
## Glass is centred this high over its floor, this far apart, and kept this far from
## a wall's end or a room's corner.
const WINDOW_HEIGHT := 1.45
const WINDOW_SPACING := 1.3
const WINDOW_MARGIN := 0.4
const GLASS_PROUD := 0.012
## A porthole in the hull stands this far off its curved plating.
const HULL_GLASS_PROUD := 0.03
const FRAME_PROUD := 0.01
const PROP_GAP := 0.03
## Lifeboats hang beside the open long edge of a deck that stands at least this high
## over the deck beneath it.
const LIFEBOAT_HEADROOM := 2.4
const LIFEBOAT_LENGTH := 4.0
const LIFEBOAT_BEAM := 1.1
const LIFEBOAT_DEPTH := 0.7
const LIFEBOAT_SPACING := 5.0
## How far the boat hangs out from the deck's edge, and its keel over the deck: its
## cover stands higher than a jump, so it never looks like a step off the deck.
const LIFEBOAT_OUT := 0.3
const LIFEBOAT_LIFT := 0.35
## The boat's lines: stations along it, clinker strakes a side and how far each laps
## the one under it, the sheer's rise and the keel's rocker toward the ends, and the
## cover's ridge over the gunwale and its overhang.
const BOAT_STATIONS := 11
const STRAKES := 4
const LAP := 0.02
const BOAT_SHEER := 0.16
const ROCKER := 0.1
const GUNWALE := 0.06
const RIDGE := 0.2
const COVER_OVERHANG := 0.035
## A radial davit: its post's section, how high it stands before it curves out over
## the boat, its fall's section, and the blocks'.
const DAVIT := 0.09
const DAVIT_RISE := 1.3
const FALL := 0.025
const BLOCK := Vector3(0.1, 0.16, 0.08)
## A break in the decks: a deck at least BREAK_LEAST over the one at its end, found
## BREAK_STEP at a time along its edge, along at least BREAK_SPAN of it; its teak cap
## rail, how far proud and how deep, stopping STAIR_GAP short of a stair; a door's
## size, and its frame's bars; a vent's half size.
const BREAK_LEAST := 0.3
const BREAK_STEP := 0.5
const BREAK_SPAN := 0.6
const CAP_PROUD := 0.07
const CAP_DEPTH := 0.12
const STAIR_GAP := 0.05
const BREAK_DOOR := Vector2(0.72, 1.5)
const FRAME_BAR := 0.07
const VENT := Vector2(0.24, 0.17)
## The bow's chain cable: its links on edge this far apart; and the ship's bell's
## bracket over its deck.
const CHAIN_LINK := 0.25
const BELL := 2.6

var _space: ShipSpace
var _layout: ShipLayout
## The hull its portholes are set in.
var _hull: ShipHull
## How deep furniture stands out from a wall: the body radius.
var _depth: float
## Every pane of glass, as seen from inside its room: [room, centre, normal into the
## room, whether a porthole, its half size].
var panes: Array[Array] = []


func _init(space: ShipSpace, hull: ShipHull, body_radius: float) -> void:
	_space = space
	_layout = space.layout
	_hull = hull
	_depth = body_radius


func build(mesh: ShipMesh) -> void:
	for room: ShipRoom in _layout.rooms:
		_windows(mesh, room)
		_furnish(mesh, room)
	_lifeboats(mesh)
	for found: Array in breaks(_space):
		_fit_break(mesh, found)
	_ground_tackle(mesh)


## Where a deck ends over a lower one with no room of that deck's under its edge —
## a break in the decks, as a poop's forward face or a forecastle's after face — on
## [param space]: per break [x, from z, to z, foot, head, out], its face along x
## between the decks' heights, facing out (1 toward the bow, -1 toward the stern).
static func breaks(space: ShipSpace) -> Array:
	var found := []
	for platform: ShipPlatform in space.layout.platforms:
		var area := platform.area
		for out: float in [-1.0, 1.0]:
			var x := area.position.x if out < 0.0 else area.end.x
			var run := []
			var z := area.position.y + BREAK_STEP * 0.5
			while z < area.end.y:
				var foot := space.deck_under(Vector2(x + out * 0.05, z), platform.height)
				if platform.height - foot < BREAK_LEAST:
					foot = NAN
				if not is_nan(foot):
					var room := RoomDressing.room_at(space, Vector3(x - out * 0.3, foot + 1.0, z))
					if room != -1 and is_equal_approx(space.layout.rooms[room].floor_height, foot):
						foot = NAN
				if not run.is_empty() and not is_equal_approx(run[3], foot):
					found.append(run)
					run = []
				if not is_nan(foot):
					if run.is_empty():
						run = [x, z - BREAK_STEP * 0.5, z, foot, platform.height, out]
					run[2] = minf(z + BREAK_STEP * 0.5, area.end.y)
				z += BREAK_STEP
			if not run.is_empty():
				found.append(run)
	return found.filter(func(run: Array) -> bool: return run[2] - run[1] >= BREAK_SPAN)


## A break's face fitted out, but where a stair climbs it: a teak cap rail along the
## deck's edge over it, and in each stretch between the stairs a door when the face
## stands tall enough for one, else louvred vents either side of a lifebelt.
func _fit_break(mesh: ShipMesh, found: Array) -> void:
	var x: float = found[0]
	var foot: float = found[3]
	var head: float = found[4]
	var out: float = found[5]
	var normal := Vector3(out, 0.0, 0.0)
	var stops := PackedFloat32Array([found[1]])
	for ramp: ShipRamp in _layout.ramps:
		var area := ramp.area
		var touches := is_equal_approx(area.position.x, x) or is_equal_approx(area.end.x, x)
		if touches and area.end.y > found[1] and area.position.y < found[2]:
			stops.append_array([area.position.y - STAIR_GAP, area.end.y + STAIR_GAP])
	stops.append(found[2])
	stops.sort()
	for index in range(0, stops.size() - 1, 2):
		var from := stops[index]
		var to := stops[index + 1]
		if to - from < 0.6:
			continue
		var rail := Rect2(minf(x, x + out * CAP_PROUD), from, CAP_PROUD, to - from)
		mesh.box(rail, head - CAP_DEPTH, head + 0.02, ShipPaints.teak)
		var middle := (from + to) * 0.5
		if head - foot >= BREAK_DOOR.y + 0.2:
			if to - from >= BREAK_DOOR.x + 0.6:
				_break_door(mesh, Vector3(x, foot, middle), normal)
			continue
		if to - from >= 3.0:
			RoomDressing.lifebelt(mesh, Vector3(x, foot + 0.6, middle), normal)
			for side: float in [-1.0, 1.0]:
				_vent(mesh, Vector3(x, foot + 0.6, middle + side * (to - from) * 0.27), normal)
		elif to - from >= 1.0:
			_vent(mesh, Vector3(x, foot + 0.6, middle), normal)


## A teak door, shut, in a break's face standing on [param sill] (its foot's middle)
## facing [param normal]: a frame, two sunk panels, a louvre over them and a brass
## knob.
func _break_door(mesh: ShipMesh, sill: Vector3, normal: Vector3) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var half := BREAK_DOOR * 0.5
	var middle := sill + Vector3.UP * (half.y + 0.06)
	var frame := half + Vector2.ONE * FRAME_BAR
	RoomDressing.panel(mesh, middle + normal * 0.02, right, frame, normal, ShipPaints.frame)
	RoomDressing.panel(mesh, middle + normal * 0.03, right, half, normal, ShipPaints.teak)
	for row: float in [-0.38, 0.12]:
		var sunk := middle + normal * 0.034 + Vector3.UP * row * half.y * 2.0
		var size := Vector2(half.x - 0.08, half.y * 0.38)
		RoomDressing.panel(mesh, sunk, right, size, normal, ShipPaints.frame, ShipMesh.RIM_ALL)
	for slat in 4:
		var louvre := middle + normal * 0.034 + Vector3.UP * (half.y - 0.12 - slat * 0.045)
		RoomDressing.panel(
			mesh, louvre, right, Vector2(half.x - 0.1, 0.008), normal, ShipPaints.dark, 0
		)
	var knob := middle + normal * 0.05 + right * (half.x - 0.09) - Vector3.UP * 0.08
	mesh.turned_box(Transform3D(Basis.IDENTITY, knob), Vector3.ONE * 0.04, ShipPaints.brass, 0)


## The ground tackle on the deck at the bow, all of it lying flat, under a toe rail's
## height, where bodies walk: either side, a hawse pipe's mouth by the end railing and
## the chain cable run from it aft to the deck pipe down to the chain locker; a
## fairlead on the toe rail at the stem; and the ship's bell on the mast that stands
## on that deck, over a jumping head.
func _ground_tackle(mesh: ShipMesh) -> void:
	var fore: ShipPlatform = null
	for platform: ShipPlatform in _layout.platforms:
		if fore == null or platform.area.end.x > fore.area.end.x + ShipMesh.SLIVER:
			fore = platform
		elif (
			is_equal_approx(platform.area.end.x, fore.area.end.x) and platform.height > fore.height
		):
			fore = platform
	var area := fore.area
	var deck := fore.height
	var end := area.end.x
	var middle := area.get_center().y
	if area.size.x < 6.0 or area.size.y < 4.0:
		return
	for side: float in [-1.0, 1.0]:
		var hawse := Vector2(end - 0.8, middle + side * area.size.y * 0.33)
		var pipe := Vector2(end - 3.6, middle + side * 0.45)
		_deck_pipe(mesh, hawse, deck, 0.2)
		_deck_pipe(mesh, pipe, deck, 0.13)
		_chain(mesh, Vector3(hawse.x, deck, hawse.y), Vector3(pipe.x, deck, pipe.y))
	var chock := Rect2(end - ShipHull.TOE_RAIL_WIDTH - 0.04, middle - 0.18, 0.12, 0.36)
	mesh.box(chock, deck, deck + 0.12, ShipPaints.dark, ShipMesh.TOP | ShipMesh.SIDES)
	for blocker: ShipBlocker in _layout.blockers:
		if (
			blocker.shape == ShipBlocker.Shape.CYLINDER
			and is_equal_approx(blocker.bottom, deck)
			and area.has_point(blocker.centre)
		):
			_bell(mesh, blocker, deck)
			return


## A deck pipe's mouth of [param radius] at [param at] on the deck at [param deck]: a
## raised iron rim round a dark mouth.
func _deck_pipe(mesh: ShipMesh, at: Vector2, deck: float, radius: float) -> void:
	mesh.cylinder(at, radius, deck, deck + 0.035, 10, ShipPaints.steel)
	var mouth := Vector3(at.x, deck + 0.037, at.y)
	RoomDressing.disc(mesh, mouth, Vector3.UP, radius * 0.7, ShipPaints.dark, 10)


## A chain cable lying on the deck from [param from] to [param to]: its flat links a
## band, its links on edge standing up from it CHAIN_LINK apart.
func _chain(mesh: ShipMesh, from: Vector3, to: Vector3) -> void:
	var length := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	var along := (to - from).normalized()
	var across := along.cross(Vector3.UP).normalized()
	var count := floori(length / CHAIN_LINK)
	var turn := Basis(across, Vector3.UP, along)
	var flat := Vector3(0.05, 0.012, length)
	mesh.turned_box(
		Transform3D(turn, (from + to) * 0.5 + Vector3.UP * 0.006), flat, ShipPaints.dark, 0
	)
	for link in count:
		var at := from + along * (CHAIN_LINK * (link + 0.5)) + Vector3.UP * 0.025
		mesh.turned_box(Transform3D(turn, at), Vector3(0.014, 0.05, CHAIN_LINK), ShipPaints.dark, 0)


## The ship's bell under a bracket on the after side of [param mast], over head
## height on the deck at [param deck], its lanyard hanging.
func _bell(mesh: ShipMesh, mast: ShipBlocker, deck: float) -> void:
	var height := deck + BELL
	var out := mast.radius + 0.22
	var root := Vector3(mast.centre.x - mast.radius, height, mast.centre.y)
	var tip := Vector3(mast.centre.x - out, height, mast.centre.y)
	mesh.beam(root, tip, Vector2(0.04, 0.05), ShipPaints.dark, 0)
	var spot := Vector2(tip.x + 0.05, tip.z)
	mesh.cylinder(spot, 0.07, height - 0.17, height - 0.02, 10, ShipPaints.brass)
	mesh.cylinder(spot, 0.1, height - 0.22, height - 0.17, 10, ShipPaints.brass, false)
	var lanyard := Vector3(spot.x, height - 0.22, spot.y)
	mesh.beam(lanyard, lanyard + Vector3.DOWN * 0.08, Vector2.ONE * 0.015, ShipPaints.rope, 0)


## A louvred vent in a break's face at [param centre], facing [param normal].
func _vent(mesh: ShipMesh, centre: Vector3, normal: Vector3) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	RoomDressing.panel(mesh, centre + normal * 0.02, right, VENT, normal, ShipPaints.frame)
	for slat in 5:
		var at := centre + normal * 0.025 + Vector3.UP * (VENT.y - 0.06 - slat * 0.06)
		RoomDressing.panel(
			mesh, at, right, Vector2(VENT.x - 0.04, 0.012), normal, ShipPaints.dark, 0
		)


## Glass in every outside wall of [param room]: on the wall's inner face, and on its
## outer face — or, below the deck the hull's outline reaches, on the hull's side. A
## helm, which wants to see out, takes a narrow window either side of a stair outside
## that leaves no room for a full one; a hold's portholes have their deadlights shut
## inside.
func _windows(mesh: ShipMesh, room: ShipRoom) -> void:
	var height := room.floor_height + WINDOW_HEIGHT
	var kind := RoomDressing.kind_of(_space, room)
	var helm := kind == RoomDressing.Kind.HELM
	for run: Array in _space.wall_runs(room):
		var side: int = run[0]
		var half: float = run[3]
		var outward := ShipSpace.outward(side)
		var spots := PackedFloat32Array()
		var sizes: Array[Vector2] = []
		var stretches: Array[Vector2] = [Vector2(run[1], run[2])]
		if helm:
			stretches = _clear_of_stairs(room, run, height)
		# Narrow windows only either side of a stair outside: a wall it cuts in two.
		var beside_stair := stretches.size() > 1
		for stretch: Vector2 in stretches:
			var from := stretch.x + WINDOW_MARGIN
			var to := stretch.y - WINDOW_MARGIN
			if to >= from:
				var count := floori((to - from) / WINDOW_SPACING) + 1
				for index in count:
					spots.append((from + to) * 0.5 + (index - (count - 1) * 0.5) * WINDOW_SPACING)
					sizes.append(WINDOW_SIZE)
			elif (
				beside_stair
				and stretch.y - stretch.x >= NARROW_WINDOW.x + WINDOW_FRAME * 2.0 + 0.04
			):
				spots.append((stretch.x + stretch.y) * 0.5)
				sizes.append(NARROW_WINDOW)
		var normal := Vector3(outward.x, 0.0, outward.y)
		for index in spots.size():
			var on_line := _space.on_side(room, side, spots[index], 0.0)
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
			var size := sizes[index]
			var inner := on_line - outward * (half + GLASS_PROUD)
			var inside := Vector3(inner.x, height, inner.y)
			if in_hull and kind == RoomDressing.Kind.HOLD:
				_deadlight(mesh, inside, -normal)
			else:
				_pane(mesh, inside, -normal, in_hull, ShipPaints.glass_in, size)
			panes.append([room, inside, -normal, in_hull, size * 0.5])
			var outer := on_line + outward * (half + GLASS_PROUD)
			var out_normal := normal
			if in_hull:
				var hull_side := 0 if side == 0 else 1
				out_normal = _hull.normal(outer.x, height, hull_side)
				outer.y = outward.y * _hull.breadth(outer.x, height, hull_side)
				outer += Vector2(out_normal.x, out_normal.z) * HULL_GLASS_PROUD
			var at := Vector3(outer.x, height, outer.y)
			_pane(mesh, at, out_normal, in_hull, ShipPaints.glass_out, size)


## The stretches (from, to) along [param run] of [param room]'s walls with no stair
## climbing outside it at [param height].
func _clear_of_stairs(room: ShipRoom, run: Array, height: float) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var side: int = run[0]
	var span := Vector2(run[1], run[2])
	var half: float = run[3]
	var outward := ShipSpace.outward(side)
	var start := NAN
	var count := maxi(1, ceili((span.y - span.x) / 0.05))
	for index in count + 1:
		var along := lerpf(span.x, span.y, float(index) / count)
		var beyond := _space.on_side(room, side, along, 0.0) + outward * (half + 0.1)
		var clear := index < count and not _space.under_a_ramp(beyond, height + 0.5)
		if clear and is_nan(start):
			start = along
		elif not clear and not is_nan(start):
			found.append(Vector2(start, along))
			start = NAN
	return found


## A porthole's deadlight shut over it inside, centred on [param centre] facing
## [param normal]: a dark iron cover in its brass ring, dogged shut either side.
func _deadlight(mesh: ShipMesh, centre: Vector3, normal: Vector3) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var ring := PackedVector3Array()
	var cover := PackedVector3Array()
	for index in PORTHOLE_SEGMENTS:
		var angle := TAU * index / PORTHOLE_SEGMENTS
		var spoke := right * cos(angle) + Vector3.UP * sin(angle)
		ring.append(centre + spoke * (PORTHOLE_RADIUS + PORTHOLE_RING) + normal * FRAME_PROUD)
		cover.append(centre + spoke * PORTHOLE_RADIUS + normal * (FRAME_PROUD + 0.012))
	mesh.polygon(ring, normal, ShipPaints.brass, centre.y - PORTHOLE_RADIUS, NAN)
	mesh.polygon(cover, normal, ShipPaints.steel, centre.y - PORTHOLE_RADIUS, NAN)
	for side: float in [-1.0, 1.0]:
		var dog := centre + right * side * (PORTHOLE_RADIUS + 0.02) + normal * 0.03
		var place := Transform3D(Basis(right, Vector3.UP, normal), dog)
		mesh.turned_box(place, Vector3(0.05, 0.03, 0.03), ShipPaints.brass, 0)


## A porthole (round, brass-ringed) or a window (square, wooden frame) centred on
## [param centre], facing [param normal].
func _pane(
	mesh: ShipMesh,
	centre: Vector3,
	normal: Vector3,
	porthole: bool,
	glass: ShipMesh.Paint,
	size := WINDOW_SIZE
) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var up := right.cross(normal).normalized()
	var lift := normal * FRAME_PROUD
	if porthole:
		var ring := PackedVector3Array()
		var outer := PackedVector3Array()
		for index in PORTHOLE_SEGMENTS:
			var angle := TAU * index / PORTHOLE_SEGMENTS
			var spoke := right * cos(angle) + up * sin(angle)
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
	var half := size * 0.5
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
	# Each bar and its rims: the frame's are darkened, the glazing bars' are not.
	var bars := [
		[Rect2(-grow.x, -grow.y, grow.x * 2.0, WINDOW_FRAME), ShipMesh.RIM_ALL],
		[Rect2(-grow.x, half.y, grow.x * 2.0, WINDOW_FRAME), ShipMesh.RIM_ALL],
		[Rect2(-grow.x, -half.y, WINDOW_FRAME, half.y * 2.0), ShipMesh.RIM_ALL],
		[Rect2(half.x, -half.y, WINDOW_FRAME, half.y * 2.0), ShipMesh.RIM_ALL],
		[Rect2(-GLAZING_BAR * 0.5, -half.y, GLAZING_BAR, half.y * 2.0), 0],
		[Rect2(-half.x, half.y * 0.2 - GLAZING_BAR * 0.5, half.x * 2.0, GLAZING_BAR), 0],
	]
	for bar: Array in bars:
		var low := (bar[0] as Rect2).position
		var high := (bar[0] as Rect2).end
		mesh.quad(
			centre + right * low.x + Vector3.UP * low.y + lift,
			centre + right * high.x + Vector3.UP * low.y + lift,
			centre + right * high.x + Vector3.UP * high.y + lift,
			centre + right * low.x + Vector3.UP * high.y + lift,
			normal,
			ShipPaints.frame,
			bar[1]
		)


## A passenger room's furniture, by what kind of room RoomDressing says it is.
func _furnish(mesh: ShipMesh, room: ShipRoom) -> void:
	var kind := RoomDressing.kind_of(_space, room)
	if kind != RoomDressing.Kind.SALOON and kind != RoomDressing.Kind.CABIN:
		return
	var runs := _space.wall_runs(room)
	runs.sort_custom(func(a: Array, b: Array) -> bool: return a[2] - a[1] > b[2] - b[1])
	if kind == RoomDressing.Kind.SALOON:
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


## Lifeboats on davits beside the open long edges of every deck standing high
## enough over the deck beneath, where the air beyond the edge is open.
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
			var keel := platform.height + LIFEBOAT_LIFT
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


## A double-ended clinker boat lying fore and aft, its keel's middle at
## [param keel]: white strakes, each lapping the one under it and shaded round as
## the hull they make, a teak gunwale, its sheer rising and its keel rockered toward
## the stems, under a ridged canvas cover.
func _boat(mesh: ShipMesh, keel: Vector3) -> void:
	var hull: Array[PackedVector3Array] = []
	var round: Array[PackedVector3Array] = []
	var cover: Array[PackedVector3Array] = []
	for station in BOAT_STATIONS:
		var along := float(station) / (BOAT_STATIONS - 1) * 2.0 - 1.0
		var x := keel.x + along * LIFEBOAT_LENGTH * 0.5
		var fullness := pow(1.0 - along * along, 0.55)
		var half := LIFEBOAT_BEAM * 0.5 * fullness
		var bottom := keel.y + ROCKER * pow(along, 4.0)
		var gunwale := keel.y + LIFEBOAT_DEPTH + BOAT_SHEER * along * along
		var shares := PackedFloat32Array([0.0, GUNWALE / LIFEBOAT_DEPTH])
		var side := PackedVector3Array([_boat_point(x, half, gunwale, bottom, 0.0)])
		side.append(_boat_point(x, half, gunwale, bottom, shares[1]))
		for strake in STRAKES:
			var share := (strake + 1.0) / STRAKES * 0.92
			side.append(
				_boat_point(x, half, gunwale, bottom, share) + Vector3(0, 0, LAP * fullness)
			)
			side.append(_boat_point(x, half, gunwale, bottom, share))
			shares.append_array([share, share])
		var section := PackedVector3Array()
		var normals := PackedVector3Array()
		for index in side.size():
			var point := side[index]
			section.append(Vector3(point.x, point.y, keel.z - point.z))
			var out := _boat_normal(half, gunwale - bottom, shares[index])
			normals.append(Vector3(0.0, out.y, -out.x))
		section.append(Vector3(x, bottom, keel.z))
		normals.append(Vector3.DOWN)
		for index in range(side.size() - 1, -1, -1):
			var point := side[index]
			section.append(Vector3(point.x, point.y, keel.z + point.z))
			var out := _boat_normal(half, gunwale - bottom, shares[index])
			normals.append(Vector3(0.0, out.y, out.x))
		hull.append(section)
		round.append(normals)
		var edge := half + COVER_OVERHANG * fullness
		var ridge := gunwale + RIDGE * fullness
		var low := gunwale - 0.04 * fullness
		(
			cover
			. append(
				PackedVector3Array(
					[
						Vector3(x, low, keel.z - edge),
						Vector3(x, gunwale + RIDGE * 0.7 * fullness, keel.z - half * 0.5),
						Vector3(x, ridge, keel.z),
						Vector3(x, gunwale + RIDGE * 0.7 * fullness, keel.z + half * 0.5),
						Vector3(x, low, keel.z + edge),
					]
				)
			)
		)
	var count := hull[0].size()
	# Each normal turned square to the boat's run along its length there.
	for i in BOAT_STATIONS:
		for j in count:
			var along := hull[mini(i + 1, BOAT_STATIONS - 1)][j] - hull[maxi(i - 1, 0)][j]
			along = along.normalized()
			round[i][j] = (round[i][j] - along * round[i][j].dot(along)).normalized()
	for i in BOAT_STATIONS - 1:
		for j in count - 1:
			var band := mini(j, count - 2 - j)
			var paint := ShipPaints.teak if band == 0 else ShipPaints.white
			var corners := PackedVector3Array(
				[hull[i][j], hull[i][j + 1], hull[i + 1][j + 1], hull[i + 1][j]]
			)
			# A lap's lip, where one strake's edge stands proud of the next, stays flat.
			if is_equal_approx(corners[0].y, corners[1].y) or band == 0:
				_boat_quad(mesh, corners[0], corners[1], corners[2], corners[3], keel, paint)
				continue
			var at := PackedVector3Array(
				[round[i][j], round[i][j + 1], round[i + 1][j + 1], round[i + 1][j]]
			)
			mesh.smooth_quad(corners, at, paint)
		for j in 4:
			_boat_quad(
				mesh,
				cover[i][j],
				cover[i][j + 1],
				cover[i + 1][j + 1],
				cover[i + 1][j],
				keel,
				ShipPaints.canvas
			)


## A point down one side of a boat's section at x — (x, height, how far out) — a
## [param share] (0 gunwale … 1 keel) of the way round from the gunwale to the keel.
func _boat_point(x: float, half: float, gunwale: float, bottom: float, share: float) -> Vector3:
	var angle := share * PI * 0.5
	var out := half * pow(cos(angle), 0.7)
	return Vector3(x, bottom + (gunwale - bottom) * (1.0 - sin(angle)), out)


## The outward normal (out, up) of a boat's section [param half] wide and
## [param depth] deep a [param share] of the way round from its gunwale to its keel
## (_boat_point).
static func _boat_normal(half: float, depth: float, share: float) -> Vector2:
	var angle := minf(share, 0.999) * PI * 0.5
	var out := depth * cos(angle)
	var up := -0.7 * half * sin(angle) * pow(cos(angle), -0.3)
	return Vector2(out, up).normalized()


## One flat piece of a boat, facing out from its middle line at [param keel].
func _boat_quad(
	mesh: ShipMesh,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	keel: Vector3,
	paint: ShipMesh.Paint
) -> void:
	var normal := (c - a).cross(d - b)
	if normal.length_squared() < 1e-10:
		return
	normal = normal.normalized()
	var middle := (a + b + c + d) * 0.25
	if normal.dot(middle - Vector3(middle.x, keel.y + LIFEBOAT_DEPTH * 0.5, keel.z)) < 0.0:
		normal = -normal
	mesh.quad(a, b, c, d, normal, paint, 0)


## A radial davit at [param x]: a white post off the deck's edge at [param edge],
## curving out over the boat's middle at [param middle], a block at its head and
## its fall down to a block on the boat's gunwale.
func _davit(mesh: ShipMesh, x: float, edge: float, middle: float, deck: float, side: float) -> void:
	var post := edge + side * (DAVIT * 0.5 + 0.02)
	var radius := absf(middle - post)
	var section := Vector2.ONE * DAVIT
	var from := Vector3(x, deck - 0.5, post)
	var bend := Vector3(x, deck + DAVIT_RISE, post)
	mesh.beam(from, bend, section, ShipPaints.white, 0)
	var steps := 5
	var last := bend
	for step in range(1, steps + 1):
		var angle := PI * 0.5 * step / steps
		var next := bend + Vector3(0.0, radius * sin(angle), side * radius * (1.0 - cos(angle)))
		mesh.beam(last, next, section, ShipPaints.white, 0)
		last = next
	var head := last + Vector3.DOWN * (DAVIT * 0.5 + BLOCK.y * 0.5)
	mesh.turned_box(Transform3D(Basis.IDENTITY, head), BLOCK, ShipPaints.dark, 0)
	var gunwale := deck + LIFEBOAT_LIFT + LIFEBOAT_DEPTH + BOAT_SHEER * 0.6
	var hook := Vector3(x, gunwale + BLOCK.y * 0.5 + RIDGE, middle)
	mesh.beam(head, hook, Vector2.ONE * FALL, ShipPaints.rope, 0)
	mesh.turned_box(Transform3D(Basis.IDENTITY, hook), BLOCK, ShipPaints.dark, 0)
