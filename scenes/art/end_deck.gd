class_name EndDeck
extends RefCounted
## The open deck at one of her ends, whole: of the platforms open to the sky, the one
## reaching furthest toward her bow or her stern, with every piece of the same deck
## joined to it edge to edge — her generators cut a deck into pieces round its openings,
## her stairs' and her hatches', so the piece at the very end is often a strip.
## What stands at her ends stands on it: the ground tackle at her bow (ShipFittings),
## her mooring gear at both (MooringGear). Read off the data alone (D6).

## How far under the deck a stair stands and is no matter to what lies on it (bare()):
## one going down to the deck beneath, under its planking.
const STAIR_UNDER := 0.5

## Its height, and its pieces.
var height: float
var pieces: Array[ShipPlatform] = []
## The box in the ship plane its pieces stand in together.
var spread: Rect2


## The open deck at the end of [param space]'s ship [param toward] points to (1 her bow,
## -1 her stern); null when no platform of hers is open to the sky.
static func of(space: ShipSpace, toward: float) -> EndDeck:
	var end: ShipPlatform = null
	var reach := -INF
	for platform: ShipPlatform in space.layout.platforms:
		var middle := platform.area.get_center()
		if not space.outdoors(Vector3(middle.x, platform.height + 0.5, middle.y)):
			continue
		var along := platform.area.end.x if toward > 0.0 else -platform.area.position.x
		var further := along > reach + ShipSpace.SLIVER
		if further or (absf(along - reach) <= ShipSpace.SLIVER and platform.height > end.height):
			end = platform
			reach = along
	if end == null:
		return null
	var deck := EndDeck.new()
	deck.height = end.height
	deck.pieces.append(end)
	var index := 0
	while index < deck.pieces.size():
		var touching := deck.pieces[index].area.grow(ShipSpace.SLIVER)
		for other: ShipPlatform in space.layout.platforms:
			if other in deck.pieces or not is_equal_approx(other.height, end.height):
				continue
			if touching.intersects(other.area, true):
				deck.pieces.append(other)
		index += 1
	deck.spread = end.area
	for piece: ShipPlatform in deck.pieces:
		deck.spread = deck.spread.merge(piece.area)
	return deck


## How far to port and to starboard (least z, greatest z) its pieces reach at
## [param x]; Vector2.INF where none stands there.
func across(x: float) -> Vector2:
	var reach := Vector2.INF
	for piece: ShipPlatform in pieces:
		if x < piece.area.position.x or x > piece.area.end.x:
			continue
		if reach == Vector2.INF:
			reach = Vector2(piece.area.position.y, piece.area.end.y)
		reach = Vector2(minf(reach.x, piece.area.position.y), maxf(reach.y, piece.area.end.y))
	return reach


## Whether ship-plane point [param point] stands over one of its pieces.
func holds(point: Vector2) -> bool:
	for piece: ShipPlatform in pieces:
		if piece.contains(point.x, point.y):
			return true
	return false


## Whether [param area] (ship plane) lies wholly on its pieces with nothing of
## [param layout] standing on it up to [param top] over the deck: no blocker, and no
## stair standing at the deck there or over it — a stair going down through one of its
## openings leaves no piece under it, and one under its planking (STAIR_UNDER) is none
## of its business, unlike ShipSpace.clear(), which minds every stair under an area.
func bare(layout: ShipLayout, area: Rect2, top: float) -> bool:
	var corners: Array[Vector2] = [
		area.position,
		area.end,
		area.get_center(),
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.position.y),
	]
	for corner: Vector2 in corners:
		if not holds(corner):
			return false
	for blocker: ShipBlocker in layout.blockers:
		if blocker.top <= height + ShipSpace.SLIVER or blocker.bottom >= height + top:
			continue
		if blocker.shape == ShipBlocker.Shape.BOX:
			if area.grow(-ShipSpace.SLIVER).intersects(blocker.area):
				return false
		elif (
			blocker.centre.clamp(area.position, area.end).distance_to(blocker.centre)
			< blocker.radius
		):
			return false
	for ramp: ShipRamp in layout.ramps:
		if not area.intersects(ramp.area):
			continue
		# A stair slopes along its axis: over the area, it stands highest at one end of
		# what the two share.
		var shared := ramp.area.intersection(area)
		var highest := maxf(
			ramp.height_at(shared.position.x, shared.position.y),
			ramp.height_at(shared.end.x, shared.end.y)
		)
		if highest > height - STAIR_UNDER:
			return false
	return true
