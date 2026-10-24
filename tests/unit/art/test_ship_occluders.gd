extends GutTest
## ShipOccluders: what of the dressed ship hides what stands behind it from the renderer.
## Every deck that stands and every wall is one of its quads, a deck the sinking can
## collapse is none, and every doorway under a lintel is left open, on the steamer and
## on the Titanic; it keeps to the stretch the art draws and under its cut-away; and the
## dressed ship carries it, cut again as her span moves.

const STEAMER := "res://data/ships/steamer.tres"
const TITANIC := "res://data/ships/titanic.tres"
const TRAWLER := "res://data/ships/trawler.tres"
## How far either side of a face a probe runs through it, in metres: past a wall's
## thickness, short of the next wall.
const PROBE := 0.2


## Whether the segment from [param from] to [param to] crosses one of [param occluder]'s
## triangles.
static func _crosses(occluder: ArrayOccluder3D, from: Vector3, to: Vector3) -> bool:
	var points := occluder.vertices
	var order := occluder.indices
	var reach := AABB(from, Vector3.ZERO).expand(to).grow(0.01)
	for at in range(0, order.size(), 3):
		var a := points[order[at]]
		var b := points[order[at + 1]]
		var c := points[order[at + 2]]
		if not reach.intersects(AABB(a, Vector3.ZERO).expand(b).expand(c).grow(0.01)):
			continue
		if Geometry3D.segment_intersects_triangle(from, to, a, b, c) != null:
			return true
	return false


## The probe across wall [param wall] at [param along] of its length (0…1) and
## [param height]: through its middle plane, from one side to the other.
static func _across(wall: ShipBlocker, along: float, height: float) -> Array[Vector3]:
	var area := wall.area
	var middle := area.get_center()
	if area.size.x <= area.size.y:
		var z := lerpf(area.position.y, area.end.y, along)
		return [Vector3(middle.x - PROBE, height, z), Vector3(middle.x + PROBE, height, z)]
	var x := lerpf(area.position.x, area.end.x, along)
	return [Vector3(x, height, middle.y - PROBE), Vector3(x, height, middle.y + PROBE)]


## Whether [param point] stands inside one of [param space]'s boxes.
static func _solid(space: ShipSpace, point: Vector3) -> bool:
	for blocker: ShipBlocker in space.layout.blockers:
		var inside := blocker.area.grow(0.01).has_point(Vector2(point.x, point.z))
		var between := point.y >= blocker.bottom - 0.01 and point.y <= blocker.top + 0.01
		if blocker.shape == ShipBlocker.Shape.BOX and inside and between:
			return true
	return false


## Every lintel of [param space]'s ship: per wall standing over the deck under it by
## more than ShipArt.DOOR_FROM, that wall and the deck's height. What stands under one
## is a doorway but where another of her boxes fills it.
static func _doorways(space: ShipSpace) -> Array[Array]:
	var found: Array[Array] = []
	for blocker: ShipBlocker in space.layout.blockers:
		if not space.is_wall(blocker):
			continue
		var deck := space.deck_under(blocker.area.get_center(), blocker.bottom)
		if not is_nan(deck) and blocker.bottom - deck > ShipArt.DOOR_FROM:
			found.append([blocker, deck])
	return found


func test_every_standing_deck_and_wall_is_a_quad_and_a_deck_that_falls_none() -> void:
	var space := ShipSpace.new(load(STEAMER))
	var platforms := space.layout.platforms
	var falling: StringName = platforms[platforms.size() / 2].name
	var falls: Array[StringName] = [falling]
	var occluder := ShipOccluders.of(space, falls)
	for platform: ShipPlatform in platforms:
		# A sliver of a deck, no broader than a quad stops short of its edges, is none.
		if minf(platform.area.size.x, platform.area.size.y) <= ShipOccluders.EDGE * 2.0 + 0.01:
			continue
		var middle := platform.area.get_center()
		var over := Vector3(middle.x, platform.height + 0.1, middle.y)
		var under := Vector3(middle.x, platform.height - 0.1, middle.y)
		var hides := _crosses(occluder, over, under)
		if platform.name == falling:
			assert_false(hides, "%s can fall: no quad of it" % platform.name)
		else:
			assert_true(hides, "%s hides what is under it" % platform.name)
	var walls := 0
	for blocker: ShipBlocker in space.layout.blockers:
		var long := maxf(blocker.area.size.x, blocker.area.size.y)
		if not space.is_wall(blocker) or long < ShipOccluders.LEAST + ShipOccluders.EDGE * 2.0:
			continue
		if blocker.top - blocker.bottom < ShipOccluders.EDGE * 4.0:
			continue
		walls += 1
		var probe := _across(blocker, 0.5, (blocker.bottom + blocker.top) * 0.5)
		assert_true(_crosses(occluder, probe[0], probe[1]), "the wall at %s" % blocker.area)
	assert_gt(walls, 20, "her walls")


func test_every_doorway_under_a_lintel_is_left_open() -> void:
	for path: String in [STEAMER, TITANIC]:
		var space := ShipSpace.new(load(path))
		var occluder := ShipOccluders.of(space)
		var open := 0
		for doorway: Array in _doorways(space):
			var lintel: ShipBlocker = doorway[0]
			var deck: float = doorway[1]
			for along: float in [0.25, 0.5, 0.75]:
				for up: float in [0.2, 0.5, 0.8]:
					var probe := _across(lintel, along, lerpf(deck, lintel.bottom, up))
					if _solid(space, (probe[0] + probe[1]) * 0.5):
						continue
					open += 1
					assert_false(
						_crosses(occluder, probe[0], probe[1]),
						(
							"%s: the doorway under %s, %.2f along it, %.2f up"
							% [path, lintel.area, along, up]
						)
					)
		assert_gt(open, 30, "%s's doorways" % path)


func test_it_keeps_to_its_span_and_under_its_cut_away() -> void:
	var space := ShipSpace.new(load(STEAMER))
	var span := Vector2(-6.0, 4.0)
	var cut := 1.0
	var occluder := ShipOccluders.of(space, [], span, cut)
	assert_gt(occluder.indices.size(), 0, "something of her stretch")
	for point: Vector3 in occluder.vertices:
		assert_between(point.x, span.x, span.y, "along her at %s" % point)
		assert_true(point.y < cut, "under the cut at %s" % point)
	var stretch := Rect2(span.x, -1e6, span.y - span.x, 2e6)
	for platform: ShipPlatform in space.layout.platforms:
		# Its part in the stretch, short of its edges as its quad stops (EDGE).
		var kept := platform.area.intersection(stretch).grow(-ShipOccluders.EDGE - 0.01)
		if not kept.has_area() or platform.height >= cut:
			continue
		var middle := kept.get_center()
		var over := Vector3(middle.x, platform.height + 0.1, middle.y)
		var under := Vector3(middle.x, platform.height - 0.1, middle.y)
		assert_true(_crosses(occluder, over, under), "%s within the stretch" % platform.name)


func test_the_dressed_ship_carries_its_occluder_cut_again_as_her_span_moves() -> void:
	var art := ShipArt.new()
	add_child_autofree(art)
	art.build(load(TRAWLER), 1.0, 0.35)
	var occluders: OccluderInstance3D = art.get_node("Occluders")
	var whole := occluders.occluder as ArrayOccluder3D
	assert_gt(whole.indices.size(), 0, "her decks and walls")
	art.show_span(Vector2(-2.0, 2.0))
	var kept := occluders.occluder as ArrayOccluder3D
	assert_gt(kept.indices.size(), 0, "her decks and walls amidships")
	assert_lt(kept.indices.size(), whole.indices.size(), "fewer than all of her")
	for point: Vector3 in kept.vertices:
		assert_between(point.x, -2.0, 2.0, "within the stretch at %s" % point)
