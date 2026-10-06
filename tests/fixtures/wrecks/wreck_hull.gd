class_name WreckHull
extends Resource
## A real wreck as a test-only hull (§5b.4 layer 2): not one of our ships, but a box
## generated from a few published dimensions — as long as her displacement needs at her
## beam and draught, her weight as high as her stated stability puts it — with the
## spaces her damage opened as cells and the damage as holes to the sea. Every number
## the sources do not give is an estimate, and [member notes] says which.

@export var name: StringName
## The box standing for her: length, beam, depth to her bulkhead deck, draught, and her
## centre of mass over her keel, in metres.
@export var length: float
@export var beam: float
@export var depth: float
@export var draught: float
@export var centre_height: float
## The spaces the damage opened and the holes it made, in her ship space: x toward
## the bow from amidships, z to starboard, y up from her waterline (BoxBarge).
@export var cells: Array[FloodCell] = []
@export var openings: Array[ShipOpening] = []
## The list past which the high side's lifeboats are useless, in degrees.
@export var boat_limit_deg: float
## Where every number comes from, est. or a source.
@export_multiline var notes: String

## Each space the damage opened breathes through an air pipe this big, in m², up to her
## deck (est.): her tanks and compartments had them, so the sea fills each to its own
## level, as the sources tell it, rather than squeezing air trapped in it (SH29).
const AIR_PIPE := 0.01


## Her structure, as BoxBarge builds it: level at her draught, her lifeboats both sides;
## its cells and holes her own copies, free to change, each cell with its air pipe.
func structure() -> ShipStructure:
	var barge := BoxBarge.new(length, beam, depth, draught, centre_height)
	barge.section_length = length / 40.0
	for cell: FloodCell in cells:
		barge.cells.append(cell.duplicate())
		var middle := (cell.low + cell.high) * 0.5
		barge.vent(cell.name, Vector3(middle.x, barge.keel() + depth, middle.z), AIR_PIPE)
	for opening: ShipOpening in openings:
		barge.openings.append(opening.duplicate())
	barge.lifeboat(1, boat_limit_deg)
	barge.lifeboat(-1, boat_limit_deg)
	return barge.structure()
