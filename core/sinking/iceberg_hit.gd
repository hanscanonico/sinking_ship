class_name IcebergHit
extends Resource
## The iceberg scraping one side of her, once a match (§5b.1): when, which side,
## where the gash starts and how far forward it runs, how far under her waterline
## each end of it is, how wide it would be as one even slit, and how deep it bites
## inboard. A match's is drawn from the sinking stream before anything else is (D4), so
## it is a pure function of (scenario, seed); an explicit one — a ship's sure hit, a
## test's, a tool's HIT= — is data, and says itself which doors jam and which openings
## were left open. HitMapper turns either into what it opens on a ship. Ship-local
## metres (D6).

## The stream's bits that make the width's place on its log scale.
const WIDTH_BITS := 32

## Seconds after the scenario's start.
@export var moment: float
## 1 for her starboard side (+z), -1 for her port side.
@export var side: int = 1
@export var start_x: float
@export var length: float
## Metres under her waterline at the gash's start and at its end; below 0, above it.
@export var depth_start: float
@export var depth_end: float
## Metres: the gash as one even slit.
@export var width: float
## Metres inboard from her shell.
@export var bite: float
## An explicit hit's watertight doors that jam open and openings that were left open,
## by name; a drawn hit's are drawn (HitMapper).
@export var jammed: Array[StringName] = []
@export var left_open: Array[StringName] = []


## A hit drawn from [param bands] off [param sink_stream], in a fixed order: moment,
## side, start, length, the depth at the start then at the end, width, bite.
static func draw(bands: HitBands, sink_stream: RandomNumberGenerator) -> IcebergHit:
	var hit := IcebergHit.new()
	hit.moment = sink_stream.randf_range(bands.moment.x, bands.moment.y)
	hit.side = 1 if sink_stream.randf() < bands.starboard else -1
	hit.start_x = sink_stream.randf_range(bands.start_x.x, bands.start_x.y)
	hit.length = sink_stream.randf_range(bands.length.x, bands.length.y)
	hit.depth_start = sink_stream.randf_range(bands.depth.x, bands.depth.y)
	hit.depth_end = sink_stream.randf_range(bands.depth.x, bands.depth.y)
	hit.width = log_even(bands.width, sink_stream.randi())
	hit.bite = sink_stream.randf_range(bands.bite.x, bands.bite.y)
	return hit


## The value at [param bits] — WIDTH_BITS of them, read as a binary fraction u from
## the highest — of a scale even in the logarithm from [param band].x to .y:
## x · (y / x)^u. The power is built bit by bit from the ratio's square root, its
## square root's, and so on, so only ×, ÷ and square roots run and every platform
## rounds it alike (D4, R21).
static func log_even(band: Vector2, bits: int) -> float:
	var value := float(band.x)
	var root := float(band.y) / band.x
	for place in WIDTH_BITS:
		root = sqrt(root)
		if bits & (1 << (WIDTH_BITS - 1 - place)):
			value *= root
	return value


func end_x() -> float:
	return start_x + length


## Metres under her waterline at [param x], along the gash's straight line.
func depth_at(x: float) -> float:
	return depth_start + (depth_end - depth_start) * (x - start_x) / length


func side_name() -> String:
	return "starboard" if side == 1 else "port"
