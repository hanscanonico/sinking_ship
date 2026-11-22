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
## (ShipPose.water_height): the sea's, outside her walls.
static func height(surfaces: Surfaces, pose: ShipPose, feet: Vector3) -> float:
	if outside(surfaces, pose, feet):
		return pose.height_of(0.0, feet)
	return pose.water_height(feet)


## Whether [param feet] are under the water they are in (Surfaces.wet): the sea's, outside
## her walls.
static func wet(surfaces: Surfaces, pose: ShipPose, feet: Vector3) -> bool:
	if outside(surfaces, pose, feet):
		return pose.wet_at(feet, pose.world_height(feet), CellMap.NONE)
	return surfaces.wet(feet, pose)


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
## and what stands over that floor is too shallow to swim in (wade_depth, as a body in the
## air lands on such a bottom: Movement.in_the_sea) — a compartment the water has not
## reached, a room it has run out of. Surfaces.NONE while it is in water, or over water it
## falls back into, or over the sea.
static func dry_floor(
	surfaces: Surfaces, rules: BrawlRules, pose: ShipPose, feet: Vector3, feet_before: float
) -> int:
	var at := over_floor(surfaces, feet, feet_before)
	var under := floor_under(surfaces, Vector3(at.x, maxf(at.y, feet_before), at.z))
	if under == Surfaces.NONE or wet(surfaces, pose, at):
		return Surfaces.NONE
	var depth := pose.water_height(at) - surfaces.height_at(under, at)
	return under if depth < rules.wade_depth else Surfaces.NONE
