class_name ShipWall
extends Resource
## A watertight wall (§5b.2): across the hull, a bulkhead, or along it, as a hold's
## side. Water cannot pass it below its top; a top short of the deck above lets water
## spill over (an OVER_WALL opening). From SH31 it is panels — where it parts two cells,
## one panel — each of which starts to leak at one head of water across it and gives way
## at another, a wall the hit ended beside at a share of both (§5b.1). Ship-local metres
## (D6).

## ACROSS stands at x = [member at], ALONG at z = [member at].
enum Axis { ACROSS, ALONG }

@export var name: StringName
@export var axis: Axis
@export var at: float
## From and to along the hull's other horizontal axis: z when ACROSS, x when ALONG.
@export var span: Vector2
@export var bottom: float
@export var top: float
## The head of water across it, in metres, at which it gives way.
@export var collapse_head: float
## The head at which a panel of it starts to leak, 0 for never, and the area, in m², a
## leaking panel passes.
@export var leak_head: float
@export var leak_area: float
## The cells it parts, by name, on either side.
@export var cells: Array[StringName] = []


## Every reason this wall cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if name.is_empty():
		found.append("structure: a wall has no name")
	if span.y <= span.x or top <= bottom:
		found.append("structure: wall %s has no area" % name)
	if collapse_head <= 0.0:
		found.append("structure: wall %s needs a collapse head" % name)
	if leak_head < 0.0 or leak_head > collapse_head or leak_area < 0.0:
		found.append("structure: wall %s leaks under its collapse head, by an area" % name)
	if cells.size() < 2:
		found.append("structure: wall %s parts no cells" % name)
	return found
