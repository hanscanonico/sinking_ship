class_name ShipStructure
extends Resource
## The physics' view of a ship (§5b.2, D6): the same hull as its ShipLayout, in the
## same ship-local metres — the outline of everything enclosed, cut across in
## sections; the cells water and air fill; the watertight walls; every opening
## between two cells or a cell and the outside; her mass and where it sits; and her
## fittings.
## Generated with the layout (tools/gen_steamer.py). The sinking physics reads it
## (SinkStepper, D13); `make ship-check` proves she floats on it, level, where she is
## said to, and founders on her sure hit.

## Where the intact ship floats, level, and the bottom of her hull.
@export var waterline_y: float
@export var keel_y: float
## Aft to fore, each standing for its own stretch of the hull.
@export var sections: Array[HullSection] = []
@export var cells: Array[FloodCell] = []
@export var walls: Array[ShipWall] = []
@export var openings: Array[ShipOpening] = []
@export var mass: Array[MassItem] = []
## How her mass is spread for turning: radii of gyration about her length (a roll)
## and across her (a pitch), in metres.
@export var roll_radius: float
@export var pitch_radius: float
## The water that moves with her, as a share of her mass, adding to her inertia.
@export var added_mass: float
## How fast a heave, a roll and a pitch die away, as shares of critical damping.
@export var heave_damping: float
@export var roll_damping: float
@export var pitch_damping: float
## What she carries that the sinking acts on: her lifeboats (SH27).
@export var fittings: Array[ShipFitting] = []
## Where along her (x) and up her shell (y) an iceberg's gash can be at all.
@export var hit_zone_x: Vector2
@export var hit_zone_y: Vector2
## The must-sink rule's last rung (§5b.1): a hit, with every watertight door and
## porthole shut, that `make ship-check` proves sinks her within the bake's cap.
@export var sure_hit: IcebergHit


## The index of the cell called [param cell_name], or -1.
func cell_named(cell_name: StringName) -> int:
	for index in cells.size():
		if cells[index] != null and cells[index].name == cell_name:
			return index
	return -1


## The section standing for the hull at [param x], or null past her ends.
func section_at(x: float) -> HullSection:
	for section: HullSection in sections:
		if section == null:
			continue
		var half := section.length * 0.5
		if x >= section.x - half and x < section.x + half:
			return section
	return null


## Her whole weight, in kilograms.
func total_mass() -> float:
	var total := 0.0
	for item: MassItem in mass:
		total += item.mass
	return total


## Her centre of mass: x, y, z.
func mass_centre() -> PackedFloat64Array:
	var moment := PackedFloat64Array([0.0, 0.0, 0.0])
	for item: MassItem in mass:
		for axis in 3:
			moment[axis] += item.mass * item.centre[axis]
	var total := total_mass()
	for axis in 3:
		moment[axis] /= total
	return moment


## Every reason this structure cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if keel_y >= waterline_y:
		found.append("structure: the keel must stand under the waterline")
	if sections.is_empty() or cells.is_empty() or mass.is_empty():
		found.append("structure: sections, cells and mass are all needed")
	var aft := -INF
	for section: HullSection in sections:
		if section == null:
			found.append("structure: a section is missing")
			continue
		found.append_array(section.problems())
		if section.x - section.length * 0.5 < aft - 0.001:
			found.append("structure: sections must run aft to fore without overlapping")
		aft = section.x + section.length * 0.5
	var names: Array[StringName] = [ShipOpening.SEA, ShipOpening.SKY]
	for cell: FloodCell in cells:
		if cell == null:
			found.append("structure: a cell is missing")
			continue
		found.append_array(cell.problems())
		if cell.name in names:
			found.append("structure: two cells are called %s" % cell.name)
		names.append(cell.name)
	for wall: ShipWall in walls:
		if wall == null:
			found.append("structure: a wall is missing")
			continue
		found.append_array(wall.problems())
		for cell_name: StringName in wall.cells:
			if cell_named(cell_name) == -1:
				found.append("structure: wall %s parts no cell called %s" % [wall.name, cell_name])
	for opening: ShipOpening in openings:
		if opening == null:
			found.append("structure: an opening is missing")
			continue
		found.append_array(opening.problems())
		for place: StringName in opening.joins:
			if not place in names:
				found.append("structure: opening %s joins no %s" % [opening.name, place])
	for item: MassItem in mass:
		if item == null:
			found.append("structure: a mass item is missing")
			continue
		found.append_array(item.problems())
	for fitting: ShipFitting in fittings:
		if fitting == null:
			found.append("structure: a fitting is missing")
			continue
		found.append_array(fitting.problems())
	if roll_radius <= 0.0 or pitch_radius <= 0.0 or added_mass < 0.0:
		found.append("structure: radii of gyration must be positive, added mass not negative")
	if heave_damping < 0.0 or roll_damping < 0.0 or pitch_damping < 0.0:
		found.append("structure: damping must not be negative")
	if hit_zone_x.y <= hit_zone_x.x or hit_zone_y.y <= hit_zone_y.x:
		found.append("structure: the hit zone must run from its least to its most")
	if sure_hit == null or sure_hit.length <= 0.0 or sure_hit.width <= 0.0:
		found.append("structure: she needs a sure hit that opens something")
	return found
