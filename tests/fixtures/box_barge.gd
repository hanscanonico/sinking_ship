class_name BoxBarge
extends RefCounted
## Box barges for the physics' textbook checks (§5b.4 layer 1) and the wreck hulls' test
## hulls (layer 2): a rectangle cut in sections, her weight at a stated height over her
## keel, cells as boxes and holes to the sea. Ship-local metres: x toward the bow, z to
## starboard, y up, her keel at -[member draught] so the sea stands at 0 at rest.

const SEA_DENSITY := 1025.0

var length: float
var beam: float
var depth: float
var draught: float
## Her centre of mass over her keel, and along her from amidships.
var centre_height: float
var centre_x := 0.0
## Her sections, each this long at most.
var section_length := 1.0
## How her mass turns, the water moving with her and her motions' damping (est., the
## steamer's).
var roll_radius := 0.0
var pitch_radius := 0.0
var cells: Array[FloodCell] = []
var openings: Array[ShipOpening] = []
var fittings: Array[ShipFitting] = []


func _init(
	barge_length: float, barge_beam: float, barge_depth: float, at_draught: float, height: float
) -> void:
	length = barge_length
	beam = barge_beam
	depth = barge_depth
	draught = at_draught
	centre_height = height
	roll_radius = 0.4 * barge_beam
	pitch_radius = 0.25 * barge_length


func keel() -> float:
	return -draught


## A cell called [param cell_name] from [param low] to [param high], all of it water's
## to fill.
func cell(cell_name: StringName, low: Vector3, high: Vector3, permeability := 1.0) -> FloodCell:
	var made := FloodCell.new()
	made.name = cell_name
	made.low = low
	made.high = high
	made.permeability = permeability
	cells.append(made)
	return made


## A hole of [param area] m² from cell [param cell_name] to the sea, in her side or her
## bottom at [param centre].
func hole(cell_name: StringName, centre: Vector3, area: float, in_bottom := false) -> void:
	var made := ShipOpening.new()
	made.name = StringName("hole_%s_%d" % [cell_name, openings.size()])
	made.kind = ShipOpening.Kind.GASH
	made.joins = [cell_name, ShipOpening.SEA]
	made.centre = centre
	var side := sqrt(area)
	made.size = Vector3(side, 0.0, side) if in_bottom else Vector3(side, side, 0.0)
	made.area = area
	openings.append(made)


## A lifeboat on [param side], useless past [param limit_deg] of list.
func lifeboat(side: int, limit_deg: float) -> void:
	var made := ShipFitting.new()
	made.name = StringName("lifeboat_%d" % side)
	made.side = side
	made.list_limit_deg = limit_deg
	fittings.append(made)


## Her structure, floating level at her draught.
func structure() -> ShipStructure:
	var made := ShipStructure.new()
	var count := ceili(length / section_length - 1e-9)
	var rectangle := PackedVector2Array(
		[
			Vector2(-beam * 0.5, keel()),
			Vector2(beam * 0.5, keel()),
			Vector2(beam * 0.5, keel() + depth),
			Vector2(-beam * 0.5, keel() + depth)
		]
	)
	for index in count:
		var section := HullSection.new()
		section.x = -length * 0.5 + length * (index + 0.5) / count
		section.length = length / count
		section.outline = rectangle
		made.sections.append(section)
	var item := MassItem.new()
	item.name = &"barge"
	item.mass = length * beam * draught * SEA_DENSITY
	item.centre = Vector3(centre_x, keel() + centre_height, 0.0)
	item.along = Vector2(-length * 0.5, length * 0.5)
	made.mass.append(item)
	made.cells = cells
	made.openings = openings
	made.fittings = fittings
	made.waterline_y = 0.0
	made.keel_y = keel()
	made.roll_radius = roll_radius
	made.pitch_radius = pitch_radius
	made.added_mass = 1.0
	made.heave_damping = 0.5
	made.pitch_damping = 0.5
	made.roll_damping = 0.08
	return made


## How deep her keel stands under the sea at [param x] in [param state], square to her
## keel: her draught there.
static func draught_at(
	state_rotation: PackedFloat64Array, sea: float, x: float, keel_y: float
) -> float:
	var up := Attitude.up(state_rotation)
	return (sea - up[0] * x) / up[1] - keel_y


## Her list in [param rotation], in degrees, starboard down: read off the rotation, as
## the HUD reads it.
static func heel_deg(rotation: PackedFloat64Array) -> float:
	return rad_to_deg(atan2(rotation[7], rotation[8]))


## Her trim in [param rotation], in degrees, bow down.
static func trim_deg(rotation: PackedFloat64Array) -> float:
	return rad_to_deg(atan2(-rotation[3], rotation[0]))
