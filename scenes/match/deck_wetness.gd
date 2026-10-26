class_name DeckWetness
extends RefCounted
## How wet each patch of the decks is (SinkingFx): a patch out on deck the sea comes
## within REACH of — its lap, its wash, a lurch dipping the deck's edge under — is
## soaked, and dries over DRY_SECONDS once the sea has drawn back off it. Read off where
## the ship is drawn: the sea is the world plane y = 0 (D7). A patch in a room is never
## the sea's — a dry room below the waterline stays dry, and a flooding room's water is
## its cell's own (InnerWater) — so no deck is soaked indoors, and a deck wholly in her
## rooms is not tracked. Presentation only (D12).

## The side of a patch, in metres.
const CELL := 0.5
## How far over the sea the sea still wets a patch, in metres.
const REACH := 0.3
const DRY_SECONDS := 30.0
## The steps wetness is told in, so a drying deck changes its picture seldom.
const LEVELS := 15
## Spray soaks the decks within this height of where it bursts, in metres.
const SOAK_HEIGHT := 0.3
## How far over a deck its air is judged in a room or out on deck (ShipSpace.rooms_at),
## in metres: past a ceiling's margin, so the room under a deck, whose ceiling it is,
## never holds it.
const OVER := 0.5

## Per layout, per platform by index, the rooms its deck stands in and its patches out
## of them (rooms_on, out_on_deck): made once a run, the first time they are asked for —
## as her ship is dressed, off the main thread (ShipDressing) — hence the guard.
static var _indoors := {}
static var _indoors_guard := Mutex.new()

## The platforms tracked, by index in the layout: every one that cannot fall and stands
## out on deck somewhere.
var platforms := PackedInt32Array()

var _layout: ShipLayout
## Per tracked platform: patches across and along, the wetness of each 0…1, row by
## row, and its picture, one byte a patch, with the bytes it was last given.
var _sizes: Array[Vector2i] = []
var _wet: Array[PackedFloat32Array] = []
var _pictures: Array[Image] = []
var _bytes: Array[PackedByteArray] = []
## Per tracked platform, its patches out on deck (out_on_deck), and 1 where every one
## of them is.
var _out: Array[PackedByteArray] = []
var _whole := PackedByteArray()
## Per tracked platform, whether any patch of it is wet, whether all of it is under
## the sea's reach, and whether any of it stands over the sea.
var _any := PackedByteArray()
var _soaked := PackedByteArray()
var _above := PackedByteArray()


## Tracks every platform of [param layout] not named in [param falls] that stands out
## on deck somewhere.
func _init(layout: ShipLayout, falls: Array[StringName] = []) -> void:
	_layout = layout
	var outs := out_on_deck(layout)
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		var out := outs[index]
		var outside := out.count(1)
		if platform.name in falls or outside == 0:
			continue
		platforms.append(index)
		_out.append(out)
		_whole.append(1 if outside == out.size() else 0)
		var size := Vector2i((platform.area.size / CELL).ceil())
		_sizes.append(size)
		var wet := PackedFloat32Array()
		wet.resize(size.x * size.y)
		_wet.append(wet)
		_pictures.append(Image.create_empty(size.x, size.y, false, Image.FORMAT_R8))
		var bytes := PackedByteArray()
		bytes.resize(size.x * size.y)
		_bytes.append(bytes)
	_any.resize(platforms.size())
	_soaked.resize(platforms.size())
	_above.resize(platforms.size())


## Per platform of [param layout], by index, the rooms, by index, its deck stands in —
## its air OVER over it in each (ShipSpace.rooms_at) — whose floors no sea outside her
## reaches.
static func rooms_on(layout: ShipLayout) -> Array[PackedInt32Array]:
	return _indoors_of(layout)[0]


## Per platform of [param layout], by index, its patches a byte each, row by row as its
## picture keeps them: 1 where the middle of the patch's share of the deck — a far
## edge's patch reaches past it — stands out of every room the deck stands in
## (rooms_on), each grown as ShipSpace.outdoors() grows a room; 0 in one.
static func out_on_deck(layout: ShipLayout) -> Array[PackedByteArray]:
	return _indoors_of(layout)[1]


## [param layout]'s rooms_on and out_on_deck, made the first time they are asked for, on
## whatever thread asks.
static func _indoors_of(layout: ShipLayout) -> Array:
	_indoors_guard.lock()
	var found: Array = _indoors.get(layout, [])
	_indoors_guard.unlock()
	if found.is_empty():
		found = _indoors_made(layout)
		_indoors_guard.lock()
		_indoors[layout] = found
		_indoors_guard.unlock()
	return found


static func _indoors_made(layout: ShipLayout) -> Array:
	var space := ShipSpace.new(layout)
	var rooms: Array[PackedInt32Array] = []
	var outs: Array[PackedByteArray] = []
	for platform: ShipPlatform in layout.platforms:
		var area := platform.area
		var size := Vector2i((area.size / CELL).ceil())
		var out := PackedByteArray()
		out.resize(size.x * size.y)
		out.fill(1)
		var on := space.rooms_at(area, platform.height + OVER)
		for index: int in on:
			var inside := layout.rooms[index].area.grow(ShipSpace.INSIDE)
			for row in size.y:
				var z := _on_deck(area.position.y, area.end.y, row)
				if z < inside.position.y or z > inside.end.y:
					continue
				for column in size.x:
					var x := _on_deck(area.position.x, area.end.x, column)
					if x >= inside.position.x and x <= inside.end.x:
						out[row * size.x + column] = 0
		rooms.append(on)
		outs.append(out)
	return [rooms, outs]


## The middle of patch [param patch]'s share of a deck's way from [param start] to
## [param end].
static func _on_deck(start: float, end: float, patch: int) -> float:
	return (start + patch * CELL + minf(start + (patch + 1) * CELL, end)) * 0.5


## The stretches of the line from [param from] to [param to] across platform
## [param platform] of [param layout], by index, that stand out on deck — out of every
## room its deck stands in (rooms_on), each grown as ShipSpace.outdoors() grows a room:
## each as the shares of the way along the line it starts and ends at, in order; the
## whole line on a deck in no room.
static func out_on_deck_along(
	layout: ShipLayout, platform: int, from: Vector3, to: Vector3
) -> PackedVector2Array:
	var runs := PackedVector2Array([Vector2(0.0, 1.0)])
	var start := Vector2(from.x, from.z)
	var way := Vector2(to.x - from.x, to.z - from.z)
	for index: int in rooms_on(layout)[platform]:
		var inside := _within(start, way, layout.rooms[index].area.grow(ShipSpace.INSIDE))
		if inside.x >= inside.y:
			continue
		var left := PackedVector2Array()
		for run: Vector2 in runs:
			if run.x < inside.x:
				left.append(Vector2(run.x, minf(run.y, inside.x)))
			if run.y > inside.y:
				left.append(Vector2(maxf(run.x, inside.y), run.y))
		runs = left
	return runs


## The shares of the way from [param start] along [param way] (ship plane) between
## which it stands in [param area]; the first past the second where it never does.
static func _within(start: Vector2, way: Vector2, area: Rect2) -> Vector2:
	var span := Vector2(0.0, 1.0)
	for axis in 2:
		if is_zero_approx(way[axis]):
			if start[axis] < area.position[axis] or start[axis] > area.end[axis]:
				return Vector2(1.0, 0.0)
			continue
		var enter := (area.position[axis] - start[axis]) / way[axis]
		var leave := (area.end[axis] - start[axis]) / way[axis]
		span.x = maxf(span.x, minf(enter, leave))
		span.y = minf(span.y, maxf(enter, leave))
	return span


## Every tracked platform's patches [param seconds] on, with the ship drawn at
## [param ship_to_world]: soaks what the sea reaches and dries the rest. Returns the
## tracked platforms, by their place in [member platforms], whose picture changed.
func update(ship_to_world: Transform3D, seconds: float) -> PackedInt32Array:
	var changed := PackedInt32Array()
	for slot in platforms.size():
		if update_one(slot, ship_to_world, seconds):
			changed.append(slot)
	return changed


## Tracked platform [param slot]'s patches [param seconds] on, as update() does
## them all; whether its picture changed.
func update_one(slot: int, ship_to_world: Transform3D, seconds: float) -> bool:
	var platform := _layout.platforms[platforms[slot]]
	var area := platform.area
	var size := _sizes[slot]
	var basis := ship_to_world.basis
	# The world height of the patch at (column, row) is a plane over the deck.
	var start := basis.y.y * platform.height + ship_to_world.origin.y
	start += basis.x.y * (area.position.x + CELL * 0.5) + basis.z.y * (area.position.y + CELL * 0.5)
	var across := basis.x.y * CELL
	var along := basis.z.y * CELL
	var far := Vector2(across * (size.x - 1), along * (size.y - 1))
	var lowest := start + minf(far.x, 0.0) + minf(far.y, 0.0)
	var highest := start + maxf(far.x, 0.0) + maxf(far.y, 0.0)
	_above[slot] = 1 if highest > 0.0 else 0
	if _any[slot] == 0 and lowest > REACH:
		return false
	var wet := _wet[slot]
	var bytes := _bytes[slot]
	var out := _out[slot]
	if highest < REACH:
		# All of it soaked out on deck: nothing to work out patch by patch.
		if _soaked[slot] == 1:
			return false
		if _whole[slot] == 1:
			wet.fill(1.0)
			bytes.fill(255)
		else:
			for patch in out.size():
				if out[patch] == 1:
					wet[patch] = 1.0
					bytes[patch] = 255
		_soaked[slot] = 1
		_any[slot] = 1
		_pictures[slot].set_data(size.x, size.y, false, Image.FORMAT_R8, bytes)
		return true
	_soaked[slot] = 0
	var drying := seconds / DRY_SECONDS
	var any := false
	var moved := false
	for row in size.y:
		for column in size.x:
			var patch := row * size.x + column
			var above := start + across * column + along * row
			var reached := above < REACH and out[patch] == 1
			var now := 1.0 if reached else maxf(wet[patch] - drying, 0.0)
			wet[patch] = now
			any = any or now > 0.0
			var level := roundi(now * LEVELS) * 255 / LEVELS
			if bytes[patch] != level:
				bytes[patch] = level
				moved = true
	_any[slot] = 1 if any else 0
	if moved:
		_pictures[slot].set_data(size.x, size.y, false, Image.FORMAT_R8, bytes)
	return moved


## Soaks every patch out on deck within [param radius] of ship point [param point] on
## the decks at its height: where spray comes down. The pictures show it as they next
## update.
func soak(point: Vector3, radius: float) -> void:
	for slot in platforms.size():
		var platform := _layout.platforms[platforms[slot]]
		if absf(platform.height - point.y) > SOAK_HEIGHT:
			continue
		var area := platform.area
		var size := _sizes[slot]
		var from := Vector2i(
			((Vector2(point.x, point.z) - area.position - Vector2.ONE * radius) / CELL).floor()
		)
		var to := Vector2i(
			((Vector2(point.x, point.z) - area.position + Vector2.ONE * radius) / CELL).ceil()
		)
		var wet := _wet[slot]
		var out := _out[slot]
		for row in range(maxi(from.y, 0), mini(to.y, size.y)):
			for column in range(maxi(from.x, 0), mini(to.x, size.x)):
				var patch := row * size.x + column
				var middle := area.position + (Vector2(column, row) + Vector2(0.5, 0.5)) * CELL
				if out[patch] == 1 and middle.distance_to(Vector2(point.x, point.z)) <= radius:
					wet[patch] = 1.0
					_any[slot] = 1


## Tracked platform [param slot]'s wetness, a byte a patch: column along x, row
## along z, from the platform's least corner.
func picture(slot: int) -> Image:
	return _pictures[slot]


## How much of tracked platform [param slot] its picture covers, in metres: whole
## patches, a little past its far edges.
func extent(slot: int) -> Vector2:
	return Vector2(_sizes[slot]) * CELL


## Whether any patch of tracked platform [param slot] is wet and some of the deck
## stands over the sea: whether there is anything to draw.
func shows(slot: int) -> bool:
	return _any[slot] == 1 and _above[slot] == 1


## How wet the patch over ship point ([param x], [param z]) of tracked platform
## [param slot] is, 0…1.
func wetness(slot: int, x: float, z: float) -> float:
	var area := _layout.platforms[platforms[slot]].area
	var size := _sizes[slot]
	var column := clampi(int((x - area.position.x) / CELL), 0, size.x - 1)
	var row := clampi(int((z - area.position.y) / CELL), 0, size.y - 1)
	return _wet[slot][row * size.x + column]
