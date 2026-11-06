class_name DoorFrame
extends RefCounted
## A doorway's frame in a wall under a deck, as ShipArt draws one under every lintel
## standing ShipArt.DOOR_FROM or more over its deck: posts either side of the doorway, from
## the deck to the lintel's underside, and a head across it on both faces of the wall,
## ShipArt.FRAME_WIDTH wide and ShipArt.FRAME_PROUD proud of the wall.


## Posts either side of the doorway under [param lintel], from [param deck] to its
## underside, and a head across it on both faces of the wall; none where an end of the
## lintel stands past [param space]'s deck under it.
static func build(mesh: ShipMesh, space: ShipSpace, lintel: ShipBlocker, deck: float) -> void:
	var width := ShipArt.FRAME_WIDTH
	var proud := ShipArt.FRAME_PROUD
	var area := lintel.area
	var middle := area.get_center()
	var along_x := area.size.x >= area.size.y
	var wall := area.size.y if along_x else area.size.x
	var thickness := wall + proud * 2.0
	var head := lintel.bottom + width
	var posts: Array[Rect2] = []
	for end: float in [0.0, 1.0]:
		if along_x:
			var x := lerpf(area.position.x, area.end.x, end)
			posts.append(Rect2(x - width * 0.5, middle.y - thickness * 0.5, width, thickness))
		else:
			var z := lerpf(area.position.y, area.end.y, end)
			posts.append(Rect2(middle.x - thickness * 0.5, z - width * 0.5, thickness, width))
	# A lintel whose ends stand past the deck under it heads no doorway: it is a
	# deck's edge over open space, as the forecastle's over the hold.
	for post: Rect2 in posts:
		if not is_equal_approx(space.deck_under(post.get_center(), lintel.bottom), deck):
			return
	for post: Rect2 in posts:
		mesh.box(post, deck, head, ShipPaints.frame, ShipMesh.SIDES)
	for side: float in [-1.0, 1.0]:
		var face := (wall + proud) * 0.5 * side - proud * 0.5
		var strip := (
			Rect2(area.position.x - width * 0.5, middle.y + face, area.size.x + width, proud)
			if along_x
			else Rect2(middle.x + face, area.position.y - width * 0.5, proud, area.size.y + width)
		)
		mesh.box(strip, lintel.bottom, head, ShipPaints.frame)
