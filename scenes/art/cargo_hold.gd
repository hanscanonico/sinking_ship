class_name CargoHold
extends RefCounted
## A hold's own (RoomDressing), placed by rules on the layout: frames and stringers
## up its hull sides and racks of stowed cargo along them over head height; a tween
## deck over head height stowed with crates, sacks and barrels behind a cargo net,
## wherever its ceiling stands high; the coaming and strongbacks of a hatch overhead;
## and shaded cargo lamps (ShipLamp) along it, clear of its stairs.

## A hold: frames this far apart up its hull sides, stringers this far apart up
## them; a tween deck wherever its ceiling stands TWEEN_ROOM over its floor, its
## beams' underside TWEEN over the floor, and its top TWEEN_TOP over that: low enough
## to stay more than a step under the main deck, so from the deck's edge it never
## looks like a floor to step down to.
const FRAME_SPACING := 1.1
const STRINGER_SPACING := 0.9
const TWEEN_ROOM := 3.2
const TWEEN := 2.0
const TWEEN_TOP := 0.21
## How deep a rack over head height stands out from its hull side; how far back from
## a tween deck's open edge its net hangs and its cargo is stowed — past the strip
## beyond the edge of a deck beside it where anything flat would look like a floor to
## step down to — and how deep the cargo is drawn: what shows from below.
const RACK := 0.55
const STOW_BACK := 0.95
const STOW_DEPTH := 1.2

var _space: ShipSpace
var _layout: ShipLayout


func _init(space: ShipSpace) -> void:
	_space = space
	_layout = space.layout


## The lights a hold [param room] is lit by: cargo lamps a quarter and three fifths
## along it, but where one would hang over a stair.
func lights(room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	var area := room.area
	var middle := area.get_center()
	for share: float in [0.25, 0.6]:
		var spot := Vector2(lerpf(area.position.x, area.end.x, share), middle.y)
		if area.size.x < area.size.y:
			spot = Vector2(middle.x, lerpf(area.position.y, area.end.y, share))
		var hang := RoomDressing.under_ceiling(_space, room, spot)
		var reach := Rect2(spot, Vector2.ZERO).grow(0.6)
		if not RoomDressing.over_a_ramp(_layout, reach, room.floor_height, hang.y):
			found.append(RoomDressing.Light.new(hang, ShipLamp.Kind.CARGO))
	return found


## [param room]'s own: frames and stringers up its hull sides, and racks of stowed
## cargo along them over head height; a tween deck stowed with cargo behind a net
## wherever its ceiling stands high; the hatch's coaming and strongbacks overhead; a
## lifebelt by its after door.
func build(mesh: ShipMesh, room: ShipRoom) -> void:
	var floor := room.floor_height
	var tween := _tween_area(room)
	var belted := false
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.side == 3 and wall.length() > 1.0 and not belted:
			RoomDressing.lifebelt(mesh, wall.at(wall.middle(), 1.35), wall.normal)
			belted = true
		if not wall.outdoors_beyond():
			continue
		if wall.side % 2 == 0:
			_racks(mesh, wall, tween)
		var along := wall.from + FRAME_SPACING * 0.5
		while along < wall.to - 0.1:
			var foot := wall.at(along, 0.0)
			var head := _space.ceiling(room, foot.x, foot.z) - ShipArt.PLANK
			var frame := wall.rect(along - 0.05, along + 0.05, 0.0, 0.06)
			RoomDressing.block(mesh, frame, floor, head, ShipPaints.hold_frame)
			along += FRAME_SPACING
		var low := wall.at(wall.from, 0.0)
		var high := _space.ceiling(room, low.x, low.z) - floor - 0.3
		var height := STRINGER_SPACING
		while height < high:
			var stringer := wall.rect(wall.from, wall.to, 0.0, 0.09)
			RoomDressing.block(
				mesh, stringer, floor + height - 0.07, floor + height + 0.07, ShipPaints.hold_frame
			)
			height += STRINGER_SPACING
	if tween.has_area():
		_tween_deck(mesh, room, tween)
	_hatch_beams(mesh, room)


## Racks along [param wall], a hull side, over head height and short of
## [param tween], each a board on knees from the wall stowed with sacks and lashed
## crates under the beams.
func _racks(mesh: ShipMesh, wall: RoomDressing.Wall, tween: Rect2) -> void:
	var end := wall.to - 0.2
	if tween.has_area():
		end = minf(end, tween.position.x - 0.3)
	var from := wall.from + 0.3
	if end - from < 1.0:
		return
	var shelf := RoomDressing.HEADROOM + 0.05
	var at := wall.at(from, 0.0)
	var head := _space.ceiling(wall.room, at.x, at.z) - wall.floor - ShipArt.PLANK
	head -= ShipArt.BEAM_DEPTH + 0.03
	var low := wall.floor + shelf
	RoomDressing.block(
		mesh, wall.rect(from, end, 0.0, RACK), low - 0.04, low, ShipPaints.hold_floor
	)
	var knee := from + 0.1
	while knee < end:
		var root := wall.at(knee, RoomDressing.HEADROOM - 0.12, 0.03)
		var reach := wall.at(knee, shelf - 0.05, RACK - 0.08)
		mesh.beam(root, reach, Vector2(0.06, 0.06), ShipPaints.hold_frame, 0)
		knee += 1.8
	var along := from + 0.05
	var slot := 0
	while along + 0.5 < end:
		var spot := wall.rect(along, along + 0.48, 0.06, RACK - 0.04)
		if slot % 3 == 1:
			var lid := wall.floor + minf(head, shelf + 0.38)
			RoomDressing.block(mesh, spot, low, lid, ShipPaints.stowed)
			var band := (low + lid) * 0.5
			RoomDressing.block(mesh, spot.grow(0.004), band - 0.04, band + 0.04, ShipPaints.stencil)
		else:
			var middle := spot.get_center()
			var lean := 0.15 if slot % 2 == 0 else -0.1
			for layer in 2:
				var place := Vector3(middle.x, low + 0.1 + layer * 0.17, middle.y)
				var sack := Vector3(0.44, 0.19, 0.34)
				var turn := Basis(Vector3.UP, lean * (1.0 - 2.0 * layer))
				mesh.turned_box(Transform3D(turn, place), sack, ShipPaints.sacking, 0)
		along += 0.62
		slot += 1


## The part of [param room] whose ceiling stands TWEEN_ROOM or more over its floor,
## clear of its walls, blockers and stairs: where a tween deck spans it, wall to
## wall; an empty Rect2 when none does.
func _tween_area(room: ShipRoom) -> Rect2:
	var floor := room.floor_height
	var inner := room.area.grow(-ShipSpace.WALL_MAX * 0.5 + 0.05)
	for platform: ShipPlatform in _layout.platforms:
		if platform.height - floor < TWEEN_ROOM or not platform.area.intersects(inner):
			continue
		var area := platform.area.intersection(inner)
		for blocker: ShipBlocker in _layout.blockers:
			if blocker.shape != ShipBlocker.Shape.BOX or not blocker.area.intersects(area):
				continue
			if blocker.top > floor + TWEEN and blocker.bottom < floor + TWEEN + 0.5:
				area = _clear_of(area, blocker.area)
		for ramp: ShipRamp in _layout.ramps:
			if ramp.area.intersects(area) and ramp.base() < floor + TWEEN + 0.5:
				area = _clear_of(area, ramp.area)
		return area
	return Rect2()


## [param area] cut back along x past [param obstacle], keeping its larger part.
static func _clear_of(area: Rect2, obstacle: Rect2) -> Rect2:
	var aft := Rect2(area.position, Vector2(obstacle.position.x - area.position.x, area.size.y))
	var fore := Rect2(Vector2(obstacle.end.x, area.position.y), Vector2.ZERO)
	fore.end = area.end
	var kept := aft if aft.size.x > fore.size.x else fore
	return kept if kept.size.x > 0.5 else Rect2()


## A tween deck across [param area] of [param room], its beams wall to wall over head
## height, boarded over, a fascia along its open edge, stowed with crates, sacks and
## barrels behind a cargo net — as deep as shows from the floor below.
func _tween_deck(mesh: ShipMesh, room: ShipRoom, area: Rect2) -> void:
	var under := room.floor_height + TWEEN
	var deck := under + TWEEN_TOP - 0.05
	var x := area.position.x + 0.15
	while x < area.end.x:
		var beam := Rect2(x - 0.06, area.position.y, 0.12, area.size.y)
		RoomDressing.block(mesh, beam, under, deck, ShipPaints.hold_frame)
		x += 0.9
	RoomDressing.block(mesh, area, deck, deck + 0.05, ShipPaints.hold_floor)
	var fascia := Rect2(area.position.x, area.position.y, 0.05, area.size.y)
	RoomDressing.block(mesh, fascia, under - 0.05, deck + 0.05, ShipPaints.hold_frame)
	var head := INF
	for corner: Vector2 in [area.position, area.end, area.get_center()]:
		head = minf(head, _space.ceiling(room, corner.x, corner.y))
	head -= ShipArt.PLANK + ShipArt.BEAM_DEPTH + 0.1
	var floor := deck + 0.05
	var z := area.position.y + 0.1
	var column := 0
	while z < area.end.y - 0.5:
		var width := 0.85 if column % 3 != 1 else 0.75
		var depth := minf(area.size.x - STOW_BACK - 0.1, STOW_DEPTH)
		var stack := Rect2(area.position.x + STOW_BACK, z, depth, width)
		_stow(mesh, stack, floor, head, column)
		z += width + 0.08
		column += 1
	var net := Vector3(area.position.x + STOW_BACK - 0.08, floor + 0.12, area.position.y + 0.2)
	_net(mesh, net, area.size.y - 0.4, minf(1.3, head - floor - 0.2))


## One stack of stowed cargo over [param footprint] on a deck at [param floor], no
## higher than [param head]: by [param column] and row, crates stacked and lashed, a
## pile of sacks, or a barrel on its end with a crate on it.
func _stow(mesh: ShipMesh, footprint: Rect2, floor: float, head: float, column: int) -> void:
	var width := footprint.size.y
	var x := footprint.position.x
	var row := 0
	while x + 0.5 < footprint.end.x:
		var size := minf(width, 0.8 if (row + column) % 2 == 0 else 0.7)
		var spot := Rect2(x, footprint.position.y + (width - size) * 0.5, size, size)
		var middle := spot.get_center()
		match (column + row * 2) % 3:
			0:
				var height := floor
				for layer in 2:
					if height + size * 0.85 > head:
						break
					crate(mesh, spot.grow(-0.03 * layer), height, height + size * 0.85)
					height += size * 0.85
			1:
				var height := floor
				var lean := 0.12
				while height + 0.28 <= head and height < floor + 0.7:
					var place := Vector3(middle.x, height + 0.14, middle.y)
					var sack := Vector3(size * 0.95, 0.28, size * 0.6)
					mesh.turned_box(
						Transform3D(Basis(Vector3.UP, lean), place), sack, ShipPaints.sacking, 0
					)
					height += 0.26
					lean = -lean
			2:
				var radius := size * 0.45
				mesh.cylinder(middle, radius, floor, floor + 0.72, 8, ShipPaints.frame, false)
				var hoop := floor + 0.36
				var band := ShipPaints.steel
				mesh.cylinder(middle, radius + 0.01, hoop - 0.03, hoop + 0.03, 8, band, false)
				if floor + 0.72 + size * 0.8 <= head:
					crate(mesh, spot.grow(-0.04), floor + 0.72, floor + 0.72 + size * 0.7)
		x += size + 0.06
		row += 1


## A stowed crate over [param area] from [param bottom] to [param top]: pale pine
## with a stencilled band, roped down over its lid — smaller and paler than the deck
## cargo that slides.
static func crate(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	RoomDressing.block(mesh, area, bottom, top, ShipPaints.stowed)
	var band := (bottom + top) * 0.5
	RoomDressing.block(mesh, area.grow(0.004), band - 0.04, band + 0.04, ShipPaints.stencil)
	var middle := area.get_center()
	for across: bool in [true, false]:
		var lash := Rect2(middle.x - 0.02, area.position.y, 0.04, area.size.y)
		if not across:
			lash = Rect2(area.position.x, middle.y - 0.02, area.size.x, 0.04)
		RoomDressing.block(mesh, lash.grow(0.012), bottom + 0.02, top + 0.012, ShipPaints.rope)


## A cargo net hung across x = [param corner].x, from [param corner] along z for
## [param width] and up for [param height]: a mesh of manila rope.
func _net(mesh: ShipMesh, corner: Vector3, width: float, height: float) -> void:
	var cell := 0.34
	var thread := Vector2.ONE * 0.018
	var columns := maxi(1, floori(width / cell))
	for column in columns + 1:
		var low := corner + Vector3.BACK * width * column / columns
		mesh.beam(low, low + Vector3.UP * height, thread, ShipPaints.rope, 0)
	var rows := maxi(1, floori(height / cell))
	var pieces := ceili(width / RoomDressing.PIECE)
	for row in rows + 1:
		var left := corner + Vector3(-0.02, height * row / rows, 0.0)
		for piece in pieces:
			var from := left + Vector3.BACK * width * piece / pieces
			mesh.beam(from, from + Vector3.BACK * width / pieces, thread, ShipPaints.rope, 0)


## Under every hatch standing on a deck that roofs [param room]: its coaming's
## timbers round the opening and strongbacks across it, under the deck, overhead.
func _hatch_beams(mesh: ShipMesh, room: ShipRoom) -> void:
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX or _space.is_wall(blocker):
			continue
		var area := blocker.area.intersection(room.area)
		var middle := area.get_center()
		if not area.has_area():
			continue
		if not is_equal_approx(_space.ceiling(room, middle.x, middle.y), blocker.bottom):
			continue
		var under := blocker.bottom - ShipArt.PLANK
		var low := under - ShipArt.BEAM_DEPTH - 0.06
		# Kept to the hold: a timber past its bulkhead would show in the room beyond.
		var rim := area.grow(0.12).intersection(room.area)
		for edge: Rect2 in [
			Rect2(rim.position, Vector2(rim.size.x, 0.12)),
			Rect2(rim.position.x, area.end.y, rim.size.x, 0.12),
			Rect2(rim.position.x, area.position.y, 0.12, area.size.y),
			Rect2(area.end.x, area.position.y, 0.12, area.size.y),
		]:
			RoomDressing.block(mesh, edge, low, under, ShipPaints.hold_frame)
		var count := maxi(1, floori(area.size.x))
		for index in count:
			var x := area.position.x + area.size.x * (index + 0.5) / count
			var strongback := Rect2(x - 0.06, area.position.y, 0.12, area.size.y)
			RoomDressing.block(mesh, strongback, low + 0.03, under, ShipPaints.hold_frame)
