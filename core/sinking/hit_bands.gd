class_name HitBands
extends Resource
## The bands a match's iceberg hit is drawn from (§5b.2): a scenario's, not a ship's —
## where on her shell a gash can be at all is her hit zone (ShipStructure). Each band
## is from x to y. Ship-local metres (D6).

## Seconds after the scenario's start.
@export var moment: Vector2
## The chance it strikes her starboard side; the rest of the time, her port side.
@export var starboard: float = 0.5
## Where along her the gash starts, and how far forward it runs from there.
@export var start_x: Vector2
@export var length: Vector2
## How far under her waterline each end of the gash is; below 0, above it.
@export var depth: Vector2
## How wide the gash would be as one even slit, in metres: drawn evenly on a log
## scale, so a pinhole is as likely as a little more than one.
@export var width: Vector2
## How deep it reaches inboard from her shell, in metres.
@export var bite: Vector2
## Each cell's share of the gash is its share of the length times a factor from this
## band: real damage is uneven.
@export var unevenness: Vector2
## A cell the gash runs through for less than this many metres is not holed: a sliver
## of a run opens nothing worth the name.
@export var least_run: float
## A watertight wall within this many metres of either end of the gash keeps this
## share of its strength.
@export var weakens_within: float
@export var weakened_to: float


## Every reason these bands cannot be drawn from; empty when they can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	for band: Vector2 in [moment, start_x, length, depth, width, bite, unevenness]:
		if band.y < band.x:
			found.append("hit: every band must run from its least to its most")
			break
	if moment.x < 0.0:
		found.append("hit: its moment must not come before the scenario starts")
	if starboard < 0.0 or starboard > 1.0:
		found.append("hit: the chance of her starboard side must be within 0…1")
	if length.x <= 0.0 or width.x <= 0.0 or bite.x <= 0.0 or unevenness.x <= 0.0:
		found.append("hit: its length, width, bite and unevenness must be more than 0")
	if least_run < 0.0:
		found.append("hit: the least run must not be negative")
	if weakens_within < 0.0 or weakened_to <= 0.0 or weakened_to > 1.0:
		found.append("hit: a weakened wall keeps a share of its strength within 0…1")
	return found
