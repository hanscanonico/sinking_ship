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
## Per cell, as [member levels] is, the pressure of the air trapped in it — its pocket
## (SinkAir) — in metres of sea over nothing, or 0 where its air is free. Empty where
## [member levels] is.
var pockets := PackedFloat64Array()
var cells: CellMap
## Per cell, as [member levels] is, what lights it (ShipPower.Power): 2 her generator,
## 1 her emergency power, 0 nothing — dark. Empty where [member levels] is: lit
## throughout, as before the physics (SH31).
var lit := PackedByteArray()
## The watertight doors the ship is shutting or has shut, by name: how far shut, 0…1.
## A door not here stands open.
var doors_shut: Dictionary[StringName, float] = {}
## What has failed (SinkFailures), by name — an opening, or a watertight wall's panel:
## 1 leaking, 2 given way, for good. One not here holds as it was built.
var opened: Dictionary[StringName, int] = {}
## Her funnels' falls (FunnelFall) by this tick: those warned of — creaking, falling or
## down — never one still to come (D10); and of them those that have landed, lying where
## they fell (FallenFunnels).
var falls: Array[FunnelFall] = []
var felled: Array[FunnelFall] = []
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
## A hull that breaks (SH33): per piece of her (SinkTimeline.spans) its own pose — where
## it stands in the world, its own cells' water and air; this pose itself the whole
## ship's, the first — and the pieces she is in at this tick, aft to fore. Empty, and
## the whole ship alone, for a hull that never breaks.
var pieces: Array[ShipPose] = []
var standing := PackedInt32Array([0])
## The highest water, worked out on first asking (highest_water).
var _highest := NAN


func _init(
	pose_sink: float, pose_trim_deg: float, pose_heel_deg: float, ship_to_world: Transform3D
) -> void:
	sink = pose_sink
	trim_deg = pose_trim_deg
	heel_deg = pose_heel_deg
	transform = ship_to_world


## The pose of piece [param piece] of her: this one, while she is whole.
func of_piece(piece: int) -> ShipPose:
	return self if pieces.is_empty() else pieces[piece]


## Hands every piece's pose what is the whole ship's at this tick: what has failed and
## fallen, the doors shut, the platforms collapsed and collapsing, the railings failed —
## numbered as her layout numbers them, which a piece's own layout does not (Pieces.honour)
## — and the lurch.
func share_with_pieces() -> void:
	for piece: ShipPose in pieces:
		if piece == self:
			continue
		piece.doors_shut = doors_shut
		piece.opened = opened
		piece.falls = falls
		piece.felled = felled
		piece.collapsed = collapsed
		piece.collapsing = collapsing
		piece.broken_railings = broken_railings
		piece.lurch_warning = lurch_warning
		piece.lurch = lurch
		piece.standing = standing


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


## Whether [param ship_point] is in trapped air: over the water of a cell whose air is a
## pocket (Q22: a head there is in a pocket, and the cold comes slower). The helper
## behind Surfaces' answers on the water, as water_level is (D13).
func in_pocket(ship_point: Vector3) -> bool:
	var cell := cell_at(ship_point)
	if cell == CellMap.NONE or pockets.is_empty() or pockets[cell] <= 0.0:
		return false
	return world_height(ship_point) > levels[cell]


## What lights [param ship_point] (ShipPower.Power): its cell's lamps' power, or —
## outside her, on her open decks — the sky's, as her generator's.
func lit_at(ship_point: Vector3) -> int:
	var cell := cell_at(ship_point)
	if cell == CellMap.NONE or lit.is_empty():
		return ShipPower.Power.MAIN
	return lit[cell]


## The world height of the water [param ship_point] is in: its cell's, or the sea's.
func water_level(ship_point: Vector3) -> float:
	var cell := cell_at(ship_point)
	return 0.0 if cell == CellMap.NONE else levels[cell]


## The ship-local height the water [param ship_point] is in stands at over its x/z: a
## point there is wet below it. Its free surface: in a cell that is full, the surface
## over its ceiling — the water of the cell over it, so a swimmer under a flooded hold's
## open top rises into the pocket over it (SH29) — or the sea's, where no cell is. An
## answer at every attitude, for the sea outside her and the water in each of her cells
## alike.
func water_height(ship_point: Vector3) -> float:
	var at := ship_point
	var cell := cell_at(at)
	while cell != CellMap.NONE:
		at.y = cells.ceiling_of(cell)
		if levels[cell] < world_height(at):
			return height_of(levels[cell], ship_point)
		cell = cells.cell_at(at)
	return height_of(0.0, ship_point)


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
