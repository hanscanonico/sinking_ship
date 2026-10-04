class_name DeckWetness
extends RefCounted
## How wet each patch of the decks is (SinkingFx): a patch the sea comes within
## REACH of — its lap, its wash, a lurch dipping the deck's edge under — is soaked,
## and dries over DRY_SECONDS once the sea has drawn back off it. Read off where the
## ship is drawn: the sea is the world plane y = 0 (D7). Presentation only (D12).

## The side of a patch, in metres.
const CELL := 0.5
## How far over the sea the sea still wets a patch, in metres.
const REACH := 0.3
const DRY_SECONDS := 30.0
## The steps wetness is told in, so a drying deck changes its picture seldom.
const LEVELS := 15
## Spray soaks the decks within this height of where it bursts, in metres.
const SOAK_HEIGHT := 0.3

## The platforms tracked, by index in the layout: every one that cannot fall.
var platforms := PackedInt32Array()

var _layout: ShipLayout
## Per tracked platform: patches across and along, the wetness of each 0…1, row by
## row, and its picture, one byte a patch, with the bytes it was last given.
var _sizes: Array[Vector2i] = []
var _wet: Array[PackedFloat32Array] = []
var _pictures: Array[Image] = []
var _bytes: Array[PackedByteArray] = []
## Per tracked platform, whether any patch of it is wet, whether all of it is under
## the sea's reach, and whether any of it stands over the sea.
var _any := PackedByteArray()
var _soaked := PackedByteArray()
var _above := PackedByteArray()


## Tracks every platform of [param layout] not named in [param falls].
func _init(layout: ShipLayout, falls: Array[StringName] = []) -> void:
	_layout = layout
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		if platform.name in falls:
			continue
		platforms.append(index)
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
	if highest < REACH:
		# All of it soaked: nothing to work out patch by patch.
		if _soaked[slot] == 1:
			return false
		wet.fill(1.0)
		bytes.fill(255)
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
			var now := 1.0 if above < REACH else maxf(wet[patch] - drying, 0.0)
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


## Soaks every patch within [param radius] of ship point [param point] on the decks
## at its height: where spray comes down. The pictures show it as they next update.
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
		for row in range(maxi(from.y, 0), mini(to.y, size.y)):
			for column in range(maxi(from.x, 0), mini(to.x, size.x)):
				var middle := area.position + (Vector2(column, row) + Vector2(0.5, 0.5)) * CELL
				if middle.distance_to(Vector2(point.x, point.z)) <= radius:
					wet[row * size.x + column] = 1.0
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
