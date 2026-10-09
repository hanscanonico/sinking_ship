class_name IndexRules
extends Resource
## The spatial index's cells (SpatialIndex, SH18), in metres; the numbers live in
## data/sim/index.tres. They change how fast the sim answers, never what it answers:
## no match reads them, so a match's data hash leaves them out. A side of INF makes a
## grid of one cell — every query a scan of everything, as before the index.

const PATH := "res://data/sim/index.tres"

## The side of a cell of the grid each Surfaces keeps of its surfaces and railings.
@export var surface_cell: float
## The side of a cell of the grid a piece's bodies are put on to find who touches whom
## and who a shove could reach.
@export var body_cell: float


static func load_default() -> IndexRules:
	return load(PATH)
