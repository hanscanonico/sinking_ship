class_name ShipWall
extends Resource
## A watertight wall (§5b.2): across the hull, a bulkhead, or along it, as a hold's
## side. Water cannot pass it below its top; a top short of the deck above lets water
## spill over (an OVER_WALL opening). Ship-local metres (D6).

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
	if cells.size() < 2:
		found.append("structure: wall %s parts no cells" % name)
	return found
