class_name ShipSpace
extends RefCounted
## Where things stand on a ShipLayout, as the dressed ship's builders ask it: in a
## room or outdoors, under which ceiling, on which deck, inside which outline of the
## decks, along which walls. Read off the data alone (D6); no rule asks it.

## A room's ceiling height when no deck stands over it (as the greybox's).
const OPEN_ROOM_HEIGHT := 2.5
## A box blocker this thin or thinner is a wall.
const WALL_MAX := 0.3
## A wall at least this tall over its floor is a full wall, not a lintel or a sill.
const FULL_WALL := 1.9
## A box on a room's floor no taller than this is furniture — a table, a bench, a
## counter, a range — not machinery: an engine stands taller.
const FURNITURE_HEIGHT := 1.2
## A margin round a room's box when judging whether a point stands in it.
const INSIDE := 0.02
## How far past a room roof() is asked of; a superset is no harm.
const ROOF_REACH := 1.0
const SLIVER := 0.01
## How far apart walled() looks for a blocker.
const WALL_STEP := 0.05
## Per side (0 to 3), its unit vector out of the room, ship plane (outward()).
const OUTWARD: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

var layout: ShipLayout
## Per room, the platforms, by index, standing over its floor anywhere over its area:
## the only ones roof() need look at, gathered the first time it is asked.
var _over := {}
## Per room, the slabs, by blocker index, over its floor and over its area: the only
## ones ceiling() need look at, gathered the first time it is asked.
var _slabs := {}


func _init(ship: ShipLayout) -> void:
	layout = ship


## Whether ship point [param point] stands outside every room.
func outdoors(point: Vector3) -> bool:
	for room: ShipRoom in layout.rooms:
		if point.y < room.floor_height - INSIDE:
			continue
		var area := room.area.grow(INSIDE)
		if point.x < area.position.x or point.x > area.end.x:
			continue
		if point.z < area.position.y or point.z > area.end.y:
			continue
		if point.y <= ceiling(room, point.x, point.z) + INSIDE:
			return false
	return true


## The share (0…1) of [param area] (x/z) that stands in a room at [param height]:
## what outdoors() says of a point, over a piece that moves between the two.
func indoors(area: Rect2, height: float) -> float:
	var inside := 0.0
	for room: ShipRoom in layout.rooms:
		var overlap := room.area.intersection(area)
		if not overlap.has_area() or height < room.floor_height - INSIDE:
			continue
		var middle := overlap.get_center()
		if height <= ceiling(room, middle.x, middle.y) + INSIDE:
			inside += overlap.get_area()
	return clampf(inside / area.get_area(), 0.0, 1.0)


## The underside of what roofs [param room] over (x, z): the lowest deck standing
## over its floor there, or OPEN_ROOM_HEIGHT above its floor where none does — or a
## slab roofing it lower than either (the trawler's wheelhouse roof).
func ceiling(room: ShipRoom, x: float, z: float) -> float:
	var over := roof(room, x, z)
	var height := room.floor_height + OPEN_ROOM_HEIGHT
	if over != -1:
		height = layout.platforms[over].height
	if not _slabs.has(room):
		var slabs := PackedInt32Array()
		for index in layout.blockers.size():
			var blocker := layout.blockers[index]
			var thin := blocker.top - blocker.bottom <= WALL_MAX
			var above := blocker.bottom > room.floor_height + SLIVER
			if thin and above and not is_wall(blocker) and blocker.area.intersects(room.area):
				slabs.append(index)
		_slabs[room] = slabs
	for index: int in _slabs[room]:
		var slab := layout.blockers[index]
		if slab.bottom < height and slab.area.grow(INSIDE).has_point(Vector2(x, z)):
			height = slab.bottom
	return height


## The platform, by index, that roofs [param room] over (x, z): the lowest deck
## standing over its floor there; -1 where none does.
func roof(room: ShipRoom, x: float, z: float) -> int:
	if not _over.has(room):
		var over := PackedInt32Array()
		for index in layout.platforms.size():
			var platform := layout.platforms[index]
			# Grown past where anyone asks of a room (outdoors() reaches INSIDE past it).
			var reach := platform.area.grow(ROOF_REACH)
			if platform.height > room.floor_height + SLIVER and reach.intersects(room.area, true):
				over.append(index)
		_over[room] = over
	var lowest := -1
	for index: int in _over[room]:
		var platform := layout.platforms[index]
		if platform.contains(x, z):
			if lowest == -1 or platform.height < layout.platforms[lowest].height:
				lowest = index
	return lowest


## The height of the highest platform under [param platform]'s middle and lower
## than it — where its deck lands if it gives way — or its own height when none is.
func floor_beneath(platform: ShipPlatform) -> float:
	var middle := platform.area.get_center()
	var beneath := -INF
	for other: ShipPlatform in layout.platforms:
		if other.height < platform.height and other.contains(middle.x, middle.y):
			beneath = maxf(beneath, other.height)
	return beneath if beneath != -INF else platform.height


## The highest deck at or below [param height] under [param point]; NAN when none.
func deck_under(point: Vector2, height: float) -> float:
	var deck := NAN
	for platform: ShipPlatform in layout.platforms:
		if platform.height <= height + SLIVER and platform.contains(point.x, point.y):
			if is_nan(deck) or platform.height > deck:
				deck = platform.height
	return deck


## Whether some lower platform lies under [param platform]: it roofs it, on beams.
func stands_over_a_platform(platform: ShipPlatform) -> bool:
	for other: ShipPlatform in layout.platforms:
		if other.height < platform.height and other.area.intersects(platform.area):
			return true
	return false


## Whether a platform rests on [param blocker]'s top.
func deck_on(blocker: ShipBlocker) -> bool:
	for platform: ShipPlatform in layout.platforms:
		if not is_equal_approx(platform.height, blocker.top):
			continue
		if blocker.shape == ShipBlocker.Shape.BOX and platform.area.intersects(blocker.area):
			return true
		if (
			blocker.shape == ShipBlocker.Shape.CYLINDER
			and platform.contains(blocker.centre.x, blocker.centre.y)
		):
			return true
	return false


## Whether [param point], ship plane, stands over [param blocker]'s footprint.
static func over(blocker: ShipBlocker, point: Vector2) -> bool:
	if blocker.shape == ShipBlocker.Shape.CYLINDER:
		return point.distance_to(blocker.centre) <= blocker.radius
	return blocker.area.has_point(point)


## Whether a blocker stands at [param height] within [param reach] of [param point],
## ship plane, the way [param toward] points: one holds a body back there (WALL_STEP
## apart).
func walled(point: Vector2, toward: Vector2, height: float, reach: float) -> bool:
	for step in range(1, floori(reach / WALL_STEP) + 1):
		var at := point + toward * WALL_STEP * step
		for blocker: ShipBlocker in layout.blockers:
			if height >= blocker.bottom and height <= blocker.top and over(blocker, at):
				return true
	return false


## Whether [param blocker] is a wall: a box no thicker than WALL_MAX.
func is_wall(blocker: ShipBlocker) -> bool:
	return (
		blocker.shape == ShipBlocker.Shape.BOX
		and minf(blocker.area.size.x, blocker.area.size.y) <= WALL_MAX
	)


## Whether nothing of the ship but floor stands in [param area] between
## [param bottom] and [param top]: no blocker, no ramp, and a deck at [param bottom]
## under all of it.
func clear(area: Rect2, bottom: float, top: float) -> bool:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.top <= bottom + SLIVER or blocker.bottom >= top - SLIVER:
			continue
		if blocker.shape == ShipBlocker.Shape.BOX:
			if area.grow(-SLIVER).intersects(blocker.area):
				return false
		else:
			var nearest := blocker.centre.clamp(area.position, area.end)
			if nearest.distance_to(blocker.centre) < blocker.radius:
				return false
	for ramp: ShipRamp in layout.ramps:
		if area.intersects(ramp.area):
			return false
	var corners: Array[Vector2] = [
		area.position,
		area.end,
		area.get_center(),
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.position.y),
	]
	for corner: Vector2 in corners:
		if not is_equal_approx(deck_under(corner, bottom), bottom):
			return false
	return true


## Whether [param point] (x/z) lies over a ramp standing higher than half a metre
## under [param height] there.
func under_a_ramp(point: Vector2, height: float) -> bool:
	for ramp: ShipRamp in layout.ramps:
		if ramp.contains(point.x, point.y) and ramp.height_at(point.x, point.y) > height - 0.5:
			return true
	return false


## Every room edge, deck edge and floor height, per axis x, y, z: where a face is
## cut so each piece of it lies wholly in one room or wholly outside.
func room_lines() -> Array[PackedFloat32Array]:
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for room: ShipRoom in layout.rooms:
		xs.append_array([room.area.position.x, room.area.end.x])
		zs.append_array([room.area.position.y, room.area.end.y])
		ys.append(room.floor_height)
	for platform: ShipPlatform in layout.platforms:
		xs.append_array([platform.area.position.x, platform.area.end.x])
		zs.append_array([platform.area.position.y, platform.area.end.y])
		ys.append(platform.height)
	var lines: Array[PackedFloat32Array] = [xs, ys, zs]
	return lines


## The decks' outline across the ship at [param x]: (port edge z, starboard edge z,
## port edge height, starboard edge height); INF when no deck stands there.
func envelope(x: float) -> Vector4:
	var shape := Vector4.INF
	for platform: ShipPlatform in layout.platforms:
		var area := platform.area
		if x <= area.position.x or x >= area.end.x:
			continue
		if shape.x == INF:
			shape = Vector4(area.position.y, area.end.y, platform.height, platform.height)
			continue
		if (
			area.position.y < shape.x - SLIVER
			or (absf(area.position.y - shape.x) <= SLIVER and platform.height > shape.z)
		):
			shape.x = area.position.y
			shape.z = platform.height
		if (
			area.end.y > shape.y + SLIVER
			or (absf(area.end.y - shape.y) <= SLIVER and platform.height > shape.w)
		):
			shape.y = area.end.y
			shape.w = platform.height
	return shape


## The lowest thing inside the hull at [param x]: a deck's underside, [param plank]
## below its top, or a blocker's foot.
func content_bottom(x: float, plank: float) -> float:
	var lowest := INF
	for platform: ShipPlatform in layout.platforms:
		if x >= platform.area.position.x - SLIVER and x <= platform.area.end.x + SLIVER:
			lowest = minf(lowest, platform.height - plank)
	for blocker: ShipBlocker in layout.blockers:
		var reach := x_reach(blocker)
		if x >= reach.x - SLIVER and x <= reach.y + SLIVER:
			lowest = minf(lowest, blocker.bottom)
	return lowest


## The x a blocker reaches from and to.
static func x_reach(blocker: ShipBlocker) -> Vector2:
	if blocker.shape == ShipBlocker.Shape.BOX:
		return Vector2(blocker.area.position.x, blocker.area.end.x)
	return Vector2(blocker.centre.x - blocker.radius, blocker.centre.x + blocker.radius)


## The full walls standing on [param room]'s floor along its sides, as runs
## [side, from, to, half thickness]: side 0 at its least z, 1 at its greatest x,
## 2 at its greatest z, 3 at its least x; from and to along the side, merged where
## pieces meet and held off the corners by the wall's half thickness. The gaps
## between runs are its doorways.
func wall_runs(room: ShipRoom) -> Array:
	var runs := []
	var area := room.area
	for side in 4:
		var along_x := side % 2 == 0
		var line := side_line(room, side)
		var low := area.position.x if along_x else area.position.y
		var high := area.end.x if along_x else area.end.y
		var pieces: Array[Vector2] = []
		var half := 0.0
		for blocker: ShipBlocker in layout.blockers:
			if not _full_wall_of(blocker, room):
				continue
			var box := blocker.area
			var across_low := box.position.y if along_x else box.position.x
			var across_high := box.end.y if along_x else box.end.x
			if across_high - across_low > WALL_MAX:
				continue
			if line < across_low - SLIVER or line > across_high + SLIVER:
				continue
			half = (across_high - across_low) * 0.5
			var from := box.position.x if along_x else box.position.y
			var to := box.end.x if along_x else box.end.y
			pieces.append(Vector2(maxf(from, low), minf(to, high)))
		pieces.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var merged: Array[Vector2] = []
		for piece: Vector2 in pieces:
			if piece.y - piece.x < SLIVER:
				continue
			if not merged.is_empty() and piece.x <= merged[merged.size() - 1].y + SLIVER:
				merged[merged.size() - 1].y = maxf(merged[merged.size() - 1].y, piece.y)
			else:
				merged.append(piece)
		for piece: Vector2 in merged:
			var from := maxf(piece.x, low + half)
			var to := minf(piece.y, high - half)
			if to - from > SLIVER:
				runs.append([side, from, to, half])
	return runs


## The z (sides 0 and 2) or x (sides 1 and 3) of [param room]'s side [param side].
func side_line(room: ShipRoom, side: int) -> float:
	var area := room.area
	return [area.position.y, area.end.x, area.end.y, area.position.x][side]


## Where [param distance] along [param side]'s line and [param depth] in from it
## stands, ship plane.
func on_side(room: ShipRoom, side: int, distance: float, depth: float) -> Vector2:
	var line := side_line(room, side)
	var point := Vector2(distance, line) if side % 2 == 0 else Vector2(line, distance)
	return point - outward(side) * depth


## A side's unit vector out of the room, in the ship plane.
static func outward(side: int) -> Vector2:
	return OUTWARD[side]


## Whether a box thicker than a wall and taller than furniture stands on
## [param room]'s floor inside it: an engine, a boiler — machinery.
func machinery_in(room: ShipRoom) -> bool:
	return not machinery(room).is_empty()


## The boxes thicker than a wall and taller than FURNITURE_HEIGHT standing on
## [param room]'s floor inside it.
func machinery(room: ShipRoom) -> Array[ShipBlocker]:
	var found: Array[ShipBlocker] = []
	for blocker: ShipBlocker in _on_floor(room):
		if blocker.top - blocker.bottom > FURNITURE_HEIGHT:
			found.append(blocker)
	return found


## The boxes thicker than a wall and no taller than FURNITURE_HEIGHT standing on
## [param room]'s floor inside it: its tables, benches, counters and ranges.
func furniture(room: ShipRoom) -> Array[ShipBlocker]:
	var found: Array[ShipBlocker] = []
	for blocker: ShipBlocker in _on_floor(room):
		if blocker.top - blocker.bottom <= FURNITURE_HEIGHT:
			found.append(blocker)
	return found


## The boxes thicker than a wall standing on [param room]'s floor, their middle
## inside it.
func _on_floor(room: ShipRoom) -> Array[ShipBlocker]:
	var found: Array[ShipBlocker] = []
	for blocker: ShipBlocker in layout.blockers:
		if (
			blocker.shape == ShipBlocker.Shape.BOX
			and not is_wall(blocker)
			and absf(blocker.bottom - room.floor_height) < 0.05
			and room.area.has_point(blocker.area.get_center())
		):
			found.append(blocker)
	return found


## Whether [param blocker] is one of [param room]'s full walls: a wall standing on its
## floor, over FULL_WALL tall or up to the deck over it — a stokehold's, under its
## galleries (#74).
func _full_wall_of(blocker: ShipBlocker, room: ShipRoom) -> bool:
	if not is_wall(blocker) or absf(blocker.bottom - room.floor_height) >= 0.05:
		return false
	if not blocker.area.grow(INSIDE).intersects(room.area):
		return false
	if blocker.top - blocker.bottom > FULL_WALL:
		return true
	var at := blocker.area.get_center().clamp(room.area.position, room.area.end)
	return blocker.top >= ceiling(room, at.x, at.y) - SLIVER


## The parts of [param area] no platform at [param height] covers.
func uncovered(area: Rect2, height: float) -> Array[Rect2]:
	var bare: Array[Rect2] = [area]
	for platform: ShipPlatform in layout.platforms:
		if not is_equal_approx(platform.height, height):
			continue
		var left: Array[Rect2] = []
		for rect: Rect2 in bare:
			left.append_array(_minus(rect, platform.area))
		bare = left
	return bare


## [param rect] with [param cut] taken out of it: up to four rectangles.
static func _minus(rect: Rect2, cut: Rect2) -> Array[Rect2]:
	var overlap := rect.intersection(cut)
	if not overlap.has_area():
		return [rect]
	var pieces: Array[Rect2] = []
	var x0 := rect.position.x
	var x1 := rect.end.x
	if overlap.position.x > x0 + SLIVER:
		pieces.append(Rect2(x0, rect.position.y, overlap.position.x - x0, rect.size.y))
	if overlap.end.x < x1 - SLIVER:
		pieces.append(Rect2(overlap.end.x, rect.position.y, x1 - overlap.end.x, rect.size.y))
	var middle := Vector2(overlap.position.x, overlap.end.x)
	if overlap.position.y > rect.position.y + SLIVER:
		var depth := overlap.position.y - rect.position.y
		pieces.append(Rect2(middle.x, rect.position.y, middle.y - middle.x, depth))
	if overlap.end.y < rect.end.y - SLIVER:
		var depth := rect.end.y - overlap.end.y
		pieces.append(Rect2(middle.x, overlap.end.y, middle.y - middle.x, depth))
	return pieces


## Whether [param blocker] roofs a room over: its middle over some room's floor.
func roofs(blocker: ShipBlocker) -> bool:
	var middle := blocker.area.get_center()
	for room: ShipRoom in layout.rooms:
		if room.area.has_point(middle) and room.floor_height < blocker.bottom:
			return true
	return false
