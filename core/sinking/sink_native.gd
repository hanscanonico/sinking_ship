class_name SinkNative
extends RefCounted
## SinkStepper's hottest loops in the game's extension (native/, #411): its solves for a
## held head, alone (_balanced) or together (_newton), and its sweep of the openings,
## with every flow, surplus, volume and height they ask, worked by a NativeSink to the
## same answers bit for bit (test_sink_native). The stepper keeps every state: this
## hands the extension her layout once, and what its loops read at each turn, step and
## change of what is open, and unpacks what they give back. None where the extension is
## not loaded — the web, a checkout that never ran make native — and the stepper's
## GDScript runs instead.

var _sink: Object
var _openings: int
var _cells: int


func _init(sink: Object) -> void:
	_sink = sink


## The extension's loops for a stepper whose compiled [param openings] are its first and
## second sides, holes in a floor, middles, half extents and flow areas, over cells in
## [param boxes] holding [param capacity], with [param air] and wells [param shipped]
## under [param sea]; null where the extension is not loaded.
static func made(
	openings: Array,
	boxes: Array[TiltedBox],
	capacity: PackedFloat64Array,
	air: SinkAir,
	shipped: ShippedWater,
	sea: SeaPhysics
) -> SinkNative:
	if not ClassDB.class_exists(&"NativeSink"):
		return null
	var native := SinkNative.new(ClassDB.instantiate(&"NativeSink"))
	var frames := PackedFloat64Array()
	var full_area := PackedFloat64Array()
	for box: TiltedBox in boxes:
		frames.append_array(box.frame())
		full_area.append(box.full_area())
	var constants := PackedFloat64Array([sea.gravity, sea.discharge, air.atmosphere(), air.least()])
	native._sink.setup(
		openings[0],
		openings[1],
		openings[2],
		openings[3],
		openings[4],
		openings[5],
		frames,
		capacity,
		full_area,
		constants
	)
	var wells := shipped.layout()
	native._sink.wells(wells[0], wells[1], wells[2], wells[3], wells[4])
	native._openings = openings[0].size()
	native._cells = boxes.size()
	return native


## The NativeSink itself.
func sink() -> Object:
	return _sink


## Each cell's openings water can pass, by index, as SinkStepper._touch found them.
func touched(touching: Array[PackedInt32Array]) -> void:
	var from := PackedInt32Array([0])
	var flat := PackedInt32Array()
	for each: PackedInt32Array in touching:
		flat.append_array(each)
		from.append(flat.size())
	_sink.touched(from, flat)


## Her cells and openings turned to where the world's up is [param up] in her axes.
func turned(up: PackedFloat64Array) -> void:
	_sink.turned(up)


## Each opening's share open in the step under way.
func shared(shares: PackedFloat64Array) -> void:
	_sink.shared(shares)


## The step begun: [param air]'s pockets and [param shipped]'s wells' edges.
func began(air: SinkAir, shipped: ShippedWater) -> void:
	var pockets := air.pockets()
	_sink.began(
		pockets[0],
		pockets[1],
		pockets[2],
		pockets[3],
		pockets[4],
		pockets[5],
		pockets[6],
		shipped.surface()
	)


## SinkStepper._balanced, the cells marked 1 in [param held] held.
func balanced(
	cell: int,
	water: float,
	heads: PackedFloat64Array,
	held: PackedByteArray,
	sea: float,
	seconds: float
) -> float:
	return _sink.balanced(cell, water, heads, held, sea, seconds)


## SinkStepper._newton over [param group], each cell holding [param water]: its heads
## left in [param heads] as the solve leaves them; whether it closed.
func newton(
	group: PackedInt32Array,
	water: PackedFloat64Array,
	heads: PackedFloat64Array,
	held: PackedByteArray,
	sea: float,
	seconds: float
) -> bool:
	var found: PackedFloat64Array = _sink.newton(group, water, heads, held, sea, seconds)
	for row in group.size():
		heads[group[row]] = found[row + 1]
	return found[0] == 1.0


## SinkStepper._sweep, turned round where [param reverse]: [param next]'s water, what
## each opening moved and the sea's account as it leaves them; gives the heads.
func sweep(
	reverse: bool,
	next: FloodState,
	heads: PackedFloat64Array,
	held: PackedByteArray,
	sea: float,
	seconds: float
) -> PackedFloat64Array:
	var found: PackedFloat64Array = _sink.sweep(
		reverse, heads, next.water, held, sea, seconds, next.sea_given
	)
	next.moved = found.slice(0, _openings)
	next.water = found.slice(_openings, _openings + _cells)
	next.sea_given = found[_openings + _cells * 2]
	return found.slice(_openings + _cells, _openings + _cells * 2)
