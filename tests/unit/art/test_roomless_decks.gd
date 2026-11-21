extends GutTest
## Every floor of the Titanic a body walks on, on her lowest weather deck (C deck) or
## above it, roofed by a deck over it and inside her shell, is a room's — or one of her
## covered promenades, which stay weather (the owner's ruling, test_roofed_indoors.gd),
## or a well her deck files name no room's.
## Below C deck RoofedIndoors paints roofed space no room holds as indoors; above it her
## art paints such a floor as weather — sun, sky and streaked plating in her middle — as
## it did the strip between C deck's forward second-class entrance and her house's after
## end, a door from either first-class corridor into it (the owner's replay of
## 2026-11-19, seed 582689430).

const TITANIC := "res://data/ships/titanic.tres"
const NO_BOXES: Array[AABB] = []
## The grid her floors are walked at, in metres.
const STEP := 0.5
## A deck this far over a floor, or less, roofs it.
const ROOF := 4.0
## A body's head height over a floor, where a point is asked whether it is a room's.
const HEAD := 1.0
## Clear of her shell's inside by this much, a point stands in her.
const SHELL := 0.6
## A patch of fewer points than this is a sliver no body stands in: between a room's wall
## stepped inside her curve and her shell, or by a flight's side.
const SLIVER := 9
## The roofed floors no room holds that are meant so, each (what, x0, x1, |z| from, |z|
## to, floor from, floor to): her covered promenades, which stay weather by the owner's
## ruling (#357), and the wells and pockets her deck files name no room's (NOT_ROOMS).
const KNOWN: Array[Array] = [
	["A deck's promenades under her boat deck", -INF, INF, 0.0, INF, 5.0, 6.0],
	[
		"B deck's open after end between the smoking room's bar and lavatory",
		-87.0,
		-84.5,
		0.0,
		5.0,
		2.5,
		3.0
	],
	["C deck's second-class promenade's runs at her sides", -91.0, -64.5, 7.4, INF, -0.1, 0.1],
	["C deck's third-class promenades under the poop's front", -111.5, -106.5, 4.4, INF, -0.1, 0.1],
	["the well under B deck's after end (c.py's NOT_ROOMS)", -94.5, -92.0, 0.0, 1.5, -0.1, 0.1],
	["the windlass room's forward tip (c.py's NOT_ROOMS)", 123.5, 128.0, 0.0, 2.5, 1.0, 2.0],
]

var _layout: ShipLayout
var _space: ShipSpace


func before_all() -> void:
	_layout = load(TITANIC)
	_space = ShipSpace.new(_layout)


func test_every_roofed_floor_inside_her_is_a_rooms_or_a_promenades() -> void:
	var found := {}  # Vector3i on the grid -> true
	for platform: ShipPlatform in _layout.platforms:
		var y := platform.height
		if y < -0.1:
			continue
		var area := platform.area
		var x := area.position.x + STEP * 0.5
		while x < area.end.x:
			var z := area.position.y + STEP * 0.5
			while z < area.end.y:
				if _roomless(x, y, z):
					found[Vector3i(roundi(x / STEP), roundi(y * 100.0), roundi(z / STEP))] = true
				z += STEP
			x += STEP
	assert_eq(_patches(found), PackedStringArray(), "roofed floors in her no room holds")


## Each patch of [param found] its points touch in, as its floor and its box in x and z.
func _patches(found: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for start: Vector3i in found:
		if seen.has(start):
			continue
		seen[start] = true
		var low := start
		var high := start
		var count := 0
		var queue: Array[Vector3i] = [start]
		while not queue.is_empty():
			var at: Vector3i = queue.pop_back()
			count += 1
			low = Vector3i(mini(low.x, at.x), at.y, mini(low.z, at.z))
			high = Vector3i(maxi(high.x, at.x), at.y, maxi(high.z, at.z))
			for step: Vector3i in [
				Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)
			]:
				var next := at + step
				if found.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		if count < SLIVER:
			continue
		out.append(
			(
				"floor %.2f, x %.1f..%.1f, z %.1f..%.1f (%d points)"
				% [low.y / 100.0, low.x * STEP, high.x * STEP, low.z * STEP, high.z * STEP, count]
			)
		)
	out.sort()
	return out


## Whether the floor at (x, y, z) is no room's, roofed, inside her shell, clear of her
## walls and meant so nowhere (KNOWN).
func _roomless(x: float, y: float, z: float) -> bool:
	var head := Vector3(x, y + HEAD, z)
	if not _space.outdoors(head, NO_BOXES):
		return false
	if (
		absf(z)
		> (
			_layout.structure.half_breadth(x, y + HEAD, signi(int(signf(z)) if z != 0.0 else 1))
			- SHELL
		)
	):
		return false
	if not _roofed(x, y, z) or _in_a_blocker(head):
		return false
	for known: Array in KNOWN:
		if (
			x >= known[1]
			and x <= known[2]
			and absf(z) >= known[3]
			and absf(z) <= known[4]
			and y >= known[5]
			and y <= known[6]
		):
			return false
	return true


func _roofed(x: float, y: float, z: float) -> bool:
	for platform: ShipPlatform in _layout.platforms:
		if (
			platform.height > y + 1.8
			and platform.height <= y + ROOF
			and platform.area.has_point(Vector2(x, z))
		):
			return true
	return false


func _in_a_blocker(point: Vector3) -> bool:
	for blocker: ShipBlocker in _layout.blockers:
		if point.y < blocker.bottom or point.y > blocker.top:
			continue
		if (
			blocker.shape == ShipBlocker.Shape.BOX
			and blocker.area.grow(0.1).has_point(Vector2(point.x, point.z))
		):
			return true
		if (
			blocker.shape != ShipBlocker.Shape.BOX
			and Vector2(point.x, point.z).distance_to(blocker.centre) < blocker.radius + 0.1
		):
			return true
	return false
