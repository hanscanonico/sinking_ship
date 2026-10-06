class_name SeaPhysics
extends Resource
## The physics' constants, the same for every ship (§5b.2): the sea, the air, how
## much of each kind of cell water can fill, the step's limits, and the stages of the
## physics, each switched on by the milestone that builds it. The numbers live in
## data/physics/sea.tres. SinkStepper reads them (D13).

const PATH := "res://data/physics/sea.tres"

## In m/s², kg/m³ and Pa.
@export var gravity: float
@export var sea_density: float
@export var air_density: float
@export var air_pressure: float
## The share of the ideal flow a real opening passes.
@export var discharge: float
## A cell filled to its ceiling keeps a thin imaginary surface over it, this share of
## its floor, so the push of the water behind it passes on (§5b.1).
@export var full_surface: float
## How hard a hull going down broadside is dragged by the water: the drag coefficient
## of her waterplane, est.
@export var sink_drag: float
## How far under the sea, in metres, the top of a hull that has gone is followed before
## the bake stops: past where anything of her is seen or stood on.
@export var gone_depth: float
## The share of a cell water can fill, by FloodCell.Kind, where the cell states none.
@export var permeability_accommodation: float
@export var permeability_machinery: float
@export var permeability_cargo: float
@export var permeability_stores: float
@export var permeability_void: float
@export var permeability_bunker: float
@export var permeability_open_well: float
## In kg/m³.
@export var steel_density: float
## The seabed: this many contacts hold her weight sunk this far into it, in metres,
## and slide on it against this friction.
@export var seabed_contacts: int
@export var seabed_sink: float
@export var seabed_friction: float
## The step's least and greatest length in seconds, and the most a step may turn or
## sink her: degrees of list and of trim, metres.
@export var step_min: float
@export var step_max: float
@export var step_list_deg: float
@export var step_trim_deg: float
@export var step_sink: float
## A face steeper than this, in degrees, is not a floor.
@export var stand_limit_deg: float
## The most a match follows her, in degrees from upright: past it movement cannot
## follow her until SH32, and the match settles (§5b.3's interim rule).
@export var supported_deg: float
## A lurch: the list changing faster than this, in degrees a second, warned at least
## this many seconds ahead.
@export var lurch_rate_deg: float
@export var lurch_warning: float
## The timeline keeps a state only where its neighbours, read between, would miss its
## water or her height in the sea by more than keep_level metres, her attitude by more
## than keep_turn_deg degrees, or a pocket's pressure by more than keep_air metres of
## sea — or whether a cell holds one at all (§5b.4, est.).
@export var keep_level: float
@export var keep_turn_deg: float
@export var keep_air: float
## A pocket holding less air than this, in m³ at the atmosphere's pressure, is gone:
## its cell's water moves as though its air were free (§5b.1, est.).
@export var pocket_least: float
## The stages of the physics (§5b.3), each off until its milestone switches it on.
@export var flooding: bool
@export var attitude: bool
@export var air: bool
@export var failures: bool
@export var capsized_movement: bool
@export var breaking: bool


static func load_default() -> SeaPhysics:
	return load(PATH)


## The share of a [param kind] cell water can fill.
func permeability(kind: FloodCell.Kind) -> float:
	var by_kind: Array[float] = [
		permeability_accommodation,
		permeability_machinery,
		permeability_cargo,
		permeability_stores,
		permeability_void,
		permeability_bunker,
		permeability_open_well,
	]
	return by_kind[kind]


## Every reason these constants cannot be read; empty when they can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if gravity <= 0.0 or sea_density <= 0.0 or air_density <= 0.0 or air_pressure <= 0.0:
		found.append("sea: gravity, densities and pressure must be positive")
	if discharge <= 0.0 or discharge > 1.0:
		found.append("sea: discharge must be within 0…1")
	if full_surface <= 0.0 or full_surface > 1.0 or sink_drag <= 0.0 or gone_depth <= 0.0:
		found.append("sea: a full cell's surface, the drag and the depth gone must be positive")
	for kind: int in FloodCell.Kind.values():
		var share := permeability(kind)
		if share <= 0.0 or share > 1.0:
			found.append("sea: permeability %s must be within 0…1" % FloodCell.Kind.keys()[kind])
	if steel_density <= 0.0 or seabed_contacts < 1 or seabed_sink <= 0.0 or seabed_friction < 0.0:
		found.append("sea: steel and the seabed need positive numbers")
	if step_min <= 0.0 or step_max < step_min:
		found.append("sea: the step must run from a positive least to a greatest")
	if step_list_deg <= 0.0 or step_trim_deg <= 0.0 or step_sink <= 0.0:
		found.append("sea: a step's limits must be positive")
	if stand_limit_deg <= 0.0 or stand_limit_deg >= 90.0:
		found.append("sea: the stand limit must be within 0…90°")
	if supported_deg <= 0.0 or supported_deg > 180.0:
		found.append("sea: the supported attitude must be within 0…180°")
	if lurch_rate_deg <= 0.0 or lurch_warning < 0.0:
		found.append("sea: a lurch needs a rate and a warning")
	if keep_level < 0.0 or keep_turn_deg < 0.0 or keep_turn_deg >= 90.0 or keep_air < 0.0:
		found.append("sea: the timeline's tolerances must not be negative, nor its turn reach 90°")
	if pocket_least <= 0.0:
		found.append("sea: the least air a pocket holds must be positive")
	return found
