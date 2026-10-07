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
## the bow from amidships, z to starboard, y up from her waterline (BoxBarge); and what
## the sinking fails aboard her — her generator (SH31).
@export var cells: Array[FloodCell] = []
@export var openings: Array[ShipOpening] = []
@export var fittings: Array[ShipFitting] = []
## The list past which the high side's lifeboats are useless, in degrees.
@export var boat_limit_deg: float
## How deep the sea is under her, in metres (SH32): where she can come to rest; INF for
## water deeper than she reaches.
@export var sea_depth := INF
## How fast her roll dies away, as a share of critical (BoxBarge's 0.08 unless her
## notes say otherwise): a flat side driven broadside through the water as she goes over
## is damped far harder than a small roll is.
@export var roll_damping := 0.08
## Her cells shut fast, with no air pipe: their air is trapped once their openings are
## under, and leaks only through their seams (FloodCell.leak_area).
@export var sealed: Array[StringName] = []
## Where every number comes from, est. or a source.
@export_multiline var notes: String

## Each space the damage opened breathes through an air pipe this big, in m², up to her
## deck (est.): her tanks and compartments had them, so the sea fills each to its own
## level, as the sources tell it, rather than squeezing air trapped in it (SH29).
const AIR_PIPE := 0.01


## Her structure, as BoxBarge builds it: level at her draught, her lifeboats both sides;
## its cells and holes her own copies, free to change, each cell but a sealed one with
## its air pipe.
func structure() -> ShipStructure:
	var barge := BoxBarge.new(length, beam, depth, draught, centre_height)
	barge.section_length = length / 40.0
	for cell: FloodCell in cells:
		barge.cells.append(cell.duplicate())
		if cell.name in sealed:
			continue
		var middle := (cell.low + cell.high) * 0.5
		barge.vent(cell.name, Vector3(middle.x, barge.keel() + depth, middle.z), AIR_PIPE)
	for opening: ShipOpening in openings:
		barge.openings.append(opening.duplicate())
	barge.lifeboat(1, boat_limit_deg)
	barge.lifeboat(-1, boat_limit_deg)
	for fitting: ShipFitting in fittings:
		barge.fittings.append(fitting.duplicate())
	var made := barge.structure()
	made.roll_damping = roll_damping
	return made
