class_name BodyWater
extends RefCounted
## The water a body off its feet is in (D6, D7), asked the one way by all that Movement
## floats, sinks or drops into it. Her cells are boxes cut to her shell, and her walls stand
## inside them: alongside her, under the turn of her side or past the wall of a hold
## narrower than she is, a body's feet are in a cell's box with no floor of hers under them.
## That body is outside her walls, in the sea, and the cell's water — or its want of any —
## is not its own. Nor is the water of the cell under a floor it lies on (over_floor).

## How far over a body's feet the floor under them is looked for, in metres (est.): feet
## lying on a floor are at its height as a Vector3 keeps it, which may round to a hair
## under the floor — the trawler's lower deck, 2.2 m down — and that floor is theirs still.
const ON_FLOOR := 0.001


## Whether [param feet] are outside her walls though in one of her cells' boxes under
## [param pose]: in a cell, with no floor of [param surfaces] under them.
static func outside(surfaces: Surfaces, pose: ShipPose, feet: Vector3) -> bool:
	return pose.cell_at(feet) != CellMap.NONE and floor_under(surfaces, feet) == Surfaces.NONE


## The floor of [param surfaces] under [param feet], or the one they lie on
## (Surfaces.landing, from ON_FLOOR over them): Surfaces.NONE where there is none.
static func floor_under(surfaces: Surfaces, feet: Vector3) -> int:
	return surfaces.landing(Vector3(feet.x, feet.y + ON_FLOOR, feet.z))


## The ship-local height the water [param feet] are in stands at over them
## (ShipPose.water_height): the sea's, outside her walls; the water's they hang in from
## under its floor (hung_in), where their own cell has none for them.
static func height(surfaces: Surfaces, rules: BrawlRules, pose: ShipPose, feet: Vector3) -> float:
	if outside(surfaces, pose, feet):
		return pose.height_of(0.0, feet)
	if surfaces.wet(feet, pose):
		return pose.water_height(feet)
	var over := hung_in(rules, pose, feet)
	return pose.water_height(feet) if is_nan(over) else over


## Whether [param feet] are under the water they are in (Surfaces.wet): the sea's, outside
## her walls; the water's they hang in from under its floor (hung_in).
static func wet(surfaces: Surfaces, rules: BrawlRules, pose: ShipPose, feet: Vector3) -> bool:
	if outside(surfaces, pose, feet):
		return pose.wet_at(feet, pose.world_height(feet), CellMap.NONE)
	return surfaces.wet(feet, pose) or not is_nan(hung_in(rules, pose, feet))


## The ship-local height of the water [param feet], dry in their own cell, hang in from
## under its floor; NAN where there is none. Her cells are stacked boxes, each with its own
## water: over an open stairwell or a hatch, a deck's water stands on that deck's height
## with the dry air of the cell under it right below. A body off its feet in that water
## whose feet sink through the opening — onto the head of the stair, a hair under the deck —
## has not left it: within a step (step_height) under the floor of a cell whose water is
## deep enough there to swim in (wade_depth), it is in that water still — and from there
## it swims back onto the deck, up the stair or beside the opening, as onto any edge a step
## up (Movement._swim_step). Whatever of hers stands in that step over its feet is its
## bottom, not a lid on the water: a stair it swims up rises over its feet each tick
## before the water lifts them onto the tread (Movement.come_to_rest), and read as out of
## the water under that tread it was in the air there, thrown back down the stair and in
## the water again, several times a second. Read as out of the water on the stair's head,
## it stood up on the top tread, dry, a step from water it swam in again — and whatever
## pushed it back that step, a railing or a crate, had it in and out several times a
## second (#777). A body on its feet is asked none of this (Movement.in_the_sea): it swims
## from the deck down, and stands a step under it.
static func hung_in(rules: BrawlRules, pose: ShipPose, feet: Vector3) -> float:
	var over := Vector3(feet.x, feet.y + rules.step_height, feet.z)
	var cell := pose.cell_at(over)
	if cell == CellMap.NONE or cell == pose.cell_at(feet):
		return NAN
	var water := pose.water_height(over)
	return water if water - pose.cells.floor_of(cell) >= rules.wade_depth else NAN


## [param feet], or the point over them on the surface they went under this tick, come
## from [param feet_before]'s height: under a flooded room's floor lies another cell, with
## its own water or none, and a swimmer sunk a hair under that floor is in the room's.
static func over_floor(surfaces: Surfaces, feet: Vector3, feet_before: float) -> Vector3:
	if feet.y >= feet_before:
		return feet
	var crossed := floor_under(surfaces, Vector3(feet.x, feet_before, feet.z))
	if crossed == Surfaces.NONE:
		return feet
	return Vector3(feet.x, maxf(feet.y, surfaces.height_at(crossed, feet)), feet.z)


## The floor a swimmer with its feet at [param feet], come from [param feet_before]'s
## height, has left the water over: the one under it, when its feet are out of the water
## and what stands over that floor is shallow enough to find its feet in (stand_depth,
## short of the wade_depth that swims it again, #777) — a compartment the water has not
## reached, a room it has run out of. Surfaces.NONE while it is in water, or over water it
## falls back into, or over the sea.
static func dry_floor(
	surfaces: Surfaces, rules: BrawlRules, pose: ShipPose, feet: Vector3, feet_before: float
) -> int:
	var at := over_floor(surfaces, feet, feet_before)
	var under := floor_under(surfaces, Vector3(at.x, maxf(at.y, feet_before), at.z))
	if under == Surfaces.NONE or wet(surfaces, rules, pose, at):
		return Surfaces.NONE
	var depth := pose.water_height(at) - surfaces.height_at(under, at)
	return under if depth < rules.stand_depth else Surfaces.NONE
