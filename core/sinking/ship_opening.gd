class_name ShipOpening
extends Resource
## A way water or air gets from one cell to another, or to the sea or the sky
## (§5b.1): a doorway, a watertight door, a porthole, a window, a stairwell, a hatch,
## the gap over a low wall, the gaps in a floor, a small leak. A rectangle in ship
## space, flat across one axis. Ship-local metres (D6).

## OPEN joins two cells of one space with nothing between them: the hold and the
## space under the forecastle over it. GASH is the iceberg's, to the sea: never in a
## ship's data, made by HitMapper for the cells a hit crosses. PANEL is a watertight
## wall's where it parts two cells: never in a ship's data either, made by SinkFailures
## from her walls, shut until it leaks or gives way (SH31). TORN is a broken hull's cut
## face, to the sea: made by PieceStructure for each cell the cut opens (SH33).
enum Kind {
	DOOR,
	WATERTIGHT_DOOR,
	PORTHOLE,
	WINDOW,
	STAIRWELL,
	HATCH,
	OVER_WALL,
	FLOOR_GAPS,
	LEAK,
	VENT,
	FREEING_PORT,
	OPEN,
	GASH,
	PANEL,
	TORN,
}
enum Start { OPEN, SHUT }

## What [member joins] names for the outside of the hull: the sea against its shell,
## the sky over its decks. Which the outside is at any moment is its height's to say.
const SEA := &"sea"
const SKY := &"sky"

@export var name: StringName
@export var kind: Kind
## The two cells it joins, or a cell and SEA or SKY.
@export var joins: Array[StringName] = []
@export var centre: Vector3
## Its extent along x, y and z: zero along the one axis it is flat across.
@export var size: Vector3
## The area water passes through, in m², where the rectangle only says where it is —
## the gaps in a floor, a leak; 0 takes the rectangle's own.
@export var area: float
@export var starts: Start
## The chance the hit finds it the other way: a porthole left open, a watertight door
## jammed open.
@export var flip_chance: float
## Whether the ship shuts it at the hit, and the seconds that takes.
@export var shuts_at_hit: bool
@export var shut_time: float
## Heads of water across it, in metres, at which, shut, it starts to leak and gives way;
## 0 for never (SinkFailures, SH31).
@export var leak_head: float
@export var collapse_head: float
## What it passes, in m², once it leaks.
@export var leak_area: float
## A hinged door's: the cell it swings open into; empty for none. Water pushing it that
## way opens it at its leak head; against it, it holds to its collapse head.
@export var opens_toward: StringName


## The axis (0 x, 1 y, 2 z) it is flat across; -1 when it is not flat across one.
func facing() -> int:
	var flat := -1
	for axis in 3:
		if size[axis] == 0.0:
			if flat != -1:
				return -1
			flat = axis
	return flat


## The area water passes through, in m².
func flow_area() -> float:
	if area > 0.0:
		return area
	var across := facing()
	if across == -1:
		return 0.0
	return float(size[(across + 1) % 3]) * size[(across + 2) % 3]


## Every reason this opening cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if name.is_empty():
		found.append("structure: an opening has no name")
	if joins.size() != 2 or joins[0] == joins[1]:
		found.append("structure: opening %s must join two places" % name)
	elif joins[0] in [SEA, SKY] and joins[1] in [SEA, SKY]:
		found.append("structure: opening %s joins no cell" % name)
	if facing() == -1 or flow_area() <= 0.0:
		found.append("structure: opening %s must be a rectangle flat across one axis" % name)
	if flip_chance < 0.0 or flip_chance > 1.0:
		found.append("structure: opening %s's flip chance must be within 0…1" % name)
	if shut_time < 0.0 or leak_head < 0.0 or collapse_head < 0.0 or leak_area < 0.0:
		found.append("structure: opening %s's times, heads and areas must not be negative" % name)
	if collapse_head > 0.0 and leak_head > collapse_head:
		found.append("structure: opening %s must leak before it gives way" % name)
	if not opens_toward.is_empty() and not opens_toward in joins:
		found.append(
			"structure: opening %s opens into %s, which it does not join" % [name, opens_toward]
		)
	return found


## Whether, shut, it can leak or give way.
func can_fail() -> bool:
	return leak_head > 0.0 or collapse_head > 0.0
