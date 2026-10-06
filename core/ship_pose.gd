class_name ShipPose
extends RefCounted
## Where the ship stands in the world at one tick, and the water in and around her, as
## SinkSchedule answers it. The sea outside is the world plane y = 0; the water inside
## her is each cell's own, level with the world at its own height (D7). [member
## transform] takes a ship-local point to the world; a point is wet below the water it
## is in — its cell's, or the sea's outside every cell.

var sink: float
var trim_deg: float
var heel_deg: float
var transform: Transform3D
## Per cell of [member cells], in her cells' order, the world height its water stands
## at — over its ceiling once it is full, as the push of the water behind it does
## (§5b.1). Empty for a ship without cells or an authored fixture: inside her the water
## is then the sea's.
var levels := PackedFloat64Array()
var cells: CellMap
## The watertight doors the ship is shutting or has shut, by name: how far shut, 0…1.
## A door not here stands open.
var doors_shut: Dictionary[StringName, float] = {}
## What an authored fixture's events have done by this tick, and what they telegraph
## now — derived from (scenario, tick) like the rest of the pose, never stored (D5).
## The platforms, by name, that have collapsed: no longer surfaces.
var collapsed: Array[StringName] = []
## The platforms, by name, whose collapse is telegraphed now: standing, not for long.
var collapsing: Array[StringName] = []
## The layout's railings, by index, that have failed.
var broken_railings := PackedInt32Array()
## The heel the lurch telegraphed now will swing by, signed as heel_deg; 0 for none.
var lurch_warning: float
## The heel the lurch under way swings by at its height, signed; 0 for none. Its
## part of the swing is already in heel_deg.
var lurch: float
## The highest water, worked out on first asking (highest_water).
var _highest := NAN


func _init(
	pose_sink: float, pose_trim_deg: float, pose_heel_deg: float, ship_to_world: Transform3D
) -> void:
	sink = pose_sink
	trim_deg = pose_trim_deg
	heel_deg = pose_heel_deg
	transform = ship_to_world


func world_height(ship_point: Vector3) -> float:
	return (transform * ship_point).y


## The cell [param ship_point] lies in, or CellMap.NONE outside her — or for a pose
## that keeps no cells.
func cell_at(ship_point: Vector3) -> int:
	if levels.is_empty():
		return CellMap.NONE
	return cells.cell_at(ship_point)


## The highest any water in or around her stands in the world: no point over it is wet.
func highest_water() -> float:
	if is_nan(_highest):
		_highest = 0.0
		for level: float in levels:
			_highest = maxf(_highest, level)
	return _highest


## The world height of the water [param ship_point] is in: its cell's, or the sea's.
func water_level(ship_point: Vector3) -> float:
	var cell := cell_at(ship_point)
	return 0.0 if cell == CellMap.NONE else levels[cell]


## The ship-local height the water [param ship_point] is in stands at over its x/z: a
## point there is wet below it. An answer at every attitude, for the sea outside her
## and the water in each of her cells alike.
func water_height(ship_point: Vector3) -> float:
	return height_of(water_level(ship_point), ship_point)


## The ship-local height over [param ship_point]'s x/z of water standing at world height
## [param level] — a cell's from [member levels], or the sea's 0.
func height_of(level: float, ship_point: Vector3) -> float:
	var basis := transform.basis
	var x := ship_point.x
	var z := ship_point.z
	return -(basis.x.y * x + basis.z.y * z + transform.origin.y - level) / basis.y.y


## How far [param ship_point] stands above the water under it, in world metres — its
## cell's, or, while that cell holds none, the water of the cell under its floor, and so
## on down to the sea outside her; below 0, under water. What a body sees coming for
## the floor it stands on.
func above_water(ship_point: Vector3) -> float:
	var under := ship_point
	var cell := cell_at(under)
	while cell != CellMap.NONE:
		under.y = cells.floor_of(cell)
		if levels[cell] > world_height(under) + CellMap.DRY:
			return world_height(ship_point) - levels[cell]
		under.y -= CellMap.DRY
		cell = cells.cell_at(under)
	return world_height(ship_point)


## The world's downward pull of [param strength], in ship space: its x/z part is
## the deck's downhill, whichever way the ship leans.
func ship_gravity(strength: float) -> Vector3:
	return transform.basis.inverse() * Vector3(0.0, -strength, 0.0)


## The way, in the ship plane, a heel of [param heel] puts the deck down: toward
## starboard (+z) for a positive one.
static func low_side(heel: float) -> Vector2:
	return Vector2(0.0, signf(heel))


## The deck's combined slope, trim and heel together, in degrees.
func slope_deg() -> float:
	return rad_to_deg(Vector3.UP.angle_to(transform.basis * Vector3.UP))
