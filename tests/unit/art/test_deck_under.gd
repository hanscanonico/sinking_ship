extends GutTest
## ShipSpace.deck_under() reads its platforms highest first off a grid of their areas;
## it answers as a walk of every platform in order (_by_scan, as it read them before), bit
## for bit, on every ship: along a sweep, and at every platform's corners and middle and a
## hair either side of its edges, at its height, a sliver under it, and above everything.

const SHIPS: Array[String] = [
	"barque",
	"ferry",
	"flat_deck",
	"freighter",
	"small_titanic",
	"steamer",
	"titanic",
	"trawler",
	"tug"
]
## How far apart the sweep's points lie, in metres.
const STEP := 1.0
## How far either side of an edge a point is put.
const NUDGE := 0.0001


func test_deck_under_answers_as_the_scan_on_every_ship() -> void:
	for ship: String in SHIPS:
		var space := ShipSpace.new(load("res://data/ships/%s.tres" % ship))
		var heights := PackedFloat64Array([INF, -INF])
		var points := PackedVector2Array()
		for platform: ShipPlatform in space.layout.platforms:
			heights.append(platform.height)
			heights.append(platform.height - ShipSpace.SLIVER)
			heights.append(platform.height - ShipSpace.SLIVER - NUDGE)
			var area := platform.area
			points.append(area.get_center())
			for x: float in [area.position.x, area.end.x]:
				for z: float in [area.position.y, area.end.y]:
					for nudge: Vector2 in [
						Vector2.ZERO,
						Vector2(NUDGE, 0.0),
						Vector2(-NUDGE, 0.0),
						Vector2(0.0, NUDGE),
						Vector2(0.0, -NUDGE)
					]:
						points.append(Vector2(x, z) + nudge)
		var mismatches := 0
		var asked := 0
		for point: Vector2 in points:
			for height: float in heights.slice(0, 2) + _some(heights, point):
				asked += 1
				mismatches += _mismatch(space, point, height)
		var bounds := SpatialIndex.bounds_of(space.layout).grow(1.0)
		var x := bounds.position.x
		while x <= bounds.end.x:
			var z := bounds.position.y
			while z <= bounds.end.y:
				for height: float in heights.slice(0, 2) + _some(heights, Vector2(x, z)):
					asked += 1
					mismatches += _mismatch(space, Vector2(x, z), height)
				z += STEP
			x += STEP * 3.0
		assert_eq(
			mismatches, 0, "%s: %d of %d answers differ from the scan" % [ship, mismatches, asked]
		)


## A handful of [param heights], picked by [param point], so that every point is asked at
## several without asking every one at every point.
func _some(heights: PackedFloat64Array, point: Vector2) -> PackedFloat64Array:
	var picked := PackedFloat64Array()
	var start := absi(hash(point)) % heights.size()
	for offset in 6:
		picked.append(heights[(start + offset * 7) % heights.size()])
	return picked


func _mismatch(space: ShipSpace, point: Vector2, height: float) -> int:
	var fast := space.deck_under(point, height)
	var scan := _by_scan(space.layout, point, height)
	return 0 if var_to_bytes(fast) == var_to_bytes(scan) else 1


## The highest platform of [param layout] at or below [param height] under [param point],
## of equal ones the first; NAN when none.
func _by_scan(layout: ShipLayout, point: Vector2, height: float) -> float:
	var deck := NAN
	for platform: ShipPlatform in layout.platforms:
		if platform.height <= height + ShipSpace.SLIVER and platform.contains(point.x, point.y):
			if is_nan(deck) or platform.height > deck:
				deck = platform.height
	return deck
