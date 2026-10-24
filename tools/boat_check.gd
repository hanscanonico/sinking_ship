extends RefCounted
## art-lint's measure of a boat stowed on chocks (DeckFurniture.boat) against its box: a
## boat curves away from a box's corners and under its gunwale, so it is held where it
## meets the box — its stem heads its top and its stems its ends, over its keel; its
## gunwale its inboard side amidships; and its davits' feet the deck's edge — rather
## than at every side and corner as a box drawn as a box is.


## Whether [param blocker] is a box on an open deck of [param space]'s ship that
## DeckFurniture draws as a boat stowed on chocks.
static func stowed(space: ShipSpace, blocker: ShipBlocker) -> bool:
	if blocker.shape != ShipBlocker.Shape.BOX or space.is_wall(blocker):
		return false
	if space.layout.structure == null:
		return false
	var middle := blocker.area.get_center()
	var inside := Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y)
	if not space.outdoors(inside):
		return false
	return DeckFurniture.piece_of(space, blocker) == DeckFurniture.Piece.BOAT


## Where a boat stowed on chocks over [param blocker]'s box meets it, each a point on the
## box and the way out of it there, as art-lint probes a blocker's faces.
static func probes(blocker: ShipBlocker) -> Array[Array]:
	var area := blocker.area
	var side := signf(area.get_center().y)
	var edge := area.end.y if side > 0.0 else area.position.y
	var keel := edge - side * (DeckFurniture.BOAT_OFF + DeckFurniture.BOAT_BEAM * 0.5)
	var middle := area.get_center().x
	var gunwale := lerpf(blocker.bottom, blocker.top, 0.75)
	var found: Array[Array] = []
	for end: float in [-1.0, 1.0]:
		var stem := middle + end * area.size.x * 0.5
		found.append([Vector3(stem - end * 0.02, blocker.top, keel), Vector3.UP])
		found.append([Vector3(stem, gunwale, keel), Vector3.RIGHT * end])
		var davit := middle + end * (area.size.x * 0.5 - DeckFurniture.DAVIT_IN)
		found.append([Vector3(davit, blocker.bottom + 0.06, edge), Vector3(0.0, 0.0, side)])
	found.append([Vector3(middle, gunwale, edge - side * area.size.y), Vector3(0.0, 0.0, -side)])
	return found
