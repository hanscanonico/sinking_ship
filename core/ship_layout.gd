class_name ShipLayout
extends Resource
## The ship as data, in ship-local metres (D6): x toward the bow, z to starboard,
## y up, origin on the main deck amidships. Collision never comes from a mesh; the
## greybox is generated from this. Nothing here assumes a size or a deck count.

## Height of the main deck above the sea when the ship is level and unsunk.
@export var freeboard: float
## How far under its top a deck's underside stands: the floor of a ship upside down
## (§5b.3, SH32).
@export var deck_thickness: float
@export var platforms: Array[ShipPlatform] = []
## The stairs between platforms; which platforms a ramp joins is where its ends lie.
@export var ramps: Array[ShipRamp] = []
@export var blockers: Array[ShipBlocker] = []
## Railing spans along platform edges; an edge with no span is open.
@export var railings: Array[ShipRailing] = []
## Boarding ladders: where a swimmer climbs up the side from the sea.
@export var ladders: Array[ShipLadder] = []
## Where seats start, ship-local; the match stream shuffles who gets which.
@export var spawns: Array[Vector3] = []
## The seats a match on her takes, fewest to most: the menu offers these (SH30, the
## start of SH21's bounds).
@export var min_seats: int
@export var max_seats: int
## The loose cargo (SH10), where each crate starts; the match moves them.
@export var props: Array[ShipProp] = []
## Rooms by name, for the lint, the walk graph, the HUD and the greybox; no rule
## reads them (D6).
@export var rooms: Array[ShipRoom] = []
## Whether the dressed art (ShipArt) lofts her hull as ShipHull does: her generator cut
## her sections from that loft, and `make art-lint` holds the two together. A ship
## lofted any other way is dressed all the same, her hull the shell her sections
## enclose (SectionHull, SH23). No rule reads it.
@export var dressed: bool = true
## Where her shell's paint turns from her hull's to her superstructure's white, in metres
## up ship space: over it wherever her shell stands a deck higher still (SectionHull) —
## the Titanic's B deck. INF, the default, paints her shell hull to its top. No rule
## reads it.
@export var white_above: float = INF
## The physics' view of the same hull (§5b.2): sections, cells, walls, openings and
## mass; null on a ship the physics does not float. No rule reads it yet (D13).
@export var structure: ShipStructure


## The index of the first room holding feet at [param ship_point] (ShipRoom.holds),
## or -1 when it stands in none.
func room_at(ship_point: Vector3, step: float) -> int:
	for index in rooms.size():
		if rooms[index].holds(ship_point, step):
			return index
	return -1


## The heights, ship space, over which [param opening] — a stretch of a gash — opens a
## place people can be: its part between the lowest floor of the rooms in its cell
## along it and the cell's top. A part of it wholly under every such floor opens none.
## An empty span (x past y) where it opens none. The breach drawn inside her and the
## hits report both read it (#148).
func opened_place(opening: ShipOpening) -> Vector2:
	var none := Vector2(INF, -INF)
	var cell := structure.cell_named(opening.joins[0]) if structure != null else -1
	if cell < 0:
		return none
	var box := structure.cells[cell]
	var from_x := opening.centre.x - opening.size.x * 0.5
	var to_x := opening.centre.x + opening.size.x * 0.5
	var floor_y := INF
	for room: ShipRoom in rooms:
		if room.name in box.rooms and room.area.position.x < to_x and room.area.end.x > from_x:
			floor_y = minf(floor_y, room.floor_height)
	var low := maxf(opening.centre.y - opening.size.y * 0.5, floor_y)
	var high := minf(opening.centre.y + opening.size.y * 0.5, box.high.y)
	return Vector2(low, high) if low < high else none


## Whether [param opening], a stretch of a gash, opens a place people can be
## (opened_place).
func opens_place(opening: ShipOpening) -> bool:
	var span := opened_place(opening)
	return span.x < span.y


## The middle of the railing at [param railing], [param above] its deck.
func railing_middle(railing: int, above: float) -> Vector3:
	var span := railings[railing]
	var middle := (span.from + span.to) * 0.5
	return Vector3(middle.x, platforms[span.platform].height + above, middle.y)


## Every reason this layout cannot host [param seats] seats; empty when it can.
func problems(seats: int) -> PackedStringArray:
	var found := PackedStringArray()
	if freeboard <= 0.0:
		found.append("ship: freeboard must be positive")
	if platforms.is_empty():
		found.append("ship: no platforms")
	for platform: ShipPlatform in platforms:
		if platform == null or platform.area.size.x <= 0.0 or platform.area.size.y <= 0.0:
			found.append("ship: a platform has no area")
	for ramp: ShipRamp in ramps:
		if ramp == null or ramp.area.size.x <= 0.0 or ramp.area.size.y <= 0.0:
			found.append("ship: a ramp has no area")
		elif is_equal_approx(ramp.start_height, ramp.end_height):
			found.append("ship: a ramp does not rise")
	for blocker: ShipBlocker in blockers:
		if blocker == null or blocker.top <= blocker.bottom:
			found.append("ship: a blocker has no height")
		elif (
			blocker.shape == ShipBlocker.Shape.BOX
			and (blocker.area.size.x <= 0.0 or blocker.area.size.y <= 0.0)
		):
			found.append("ship: a box blocker has no area")
		elif blocker.shape == ShipBlocker.Shape.CYLINDER and blocker.radius <= 0.0:
			found.append("ship: a cylinder blocker has no radius")
	for railing: ShipRailing in railings:
		if railing == null or railing.from.is_equal_approx(railing.to):
			found.append("ship: a railing has no length")
		elif railing.platform < 0 or railing.platform >= platforms.size():
			found.append("ship: a railing names platform %d" % railing.platform)
		elif (
			platforms[railing.platform] != null
			and not platforms[railing.platform].edge_holds(railing.from, railing.to)
		):
			found.append("ship: a railing does not run along its platform's edge")
	for ladder: ShipLadder in ladders:
		if ladder == null or ladder.from.is_equal_approx(ladder.to):
			found.append("ship: a ladder has no width")
		elif ladder.platform < 0 or ladder.platform >= platforms.size():
			found.append("ship: a ladder names platform %d" % ladder.platform)
		elif (
			platforms[ladder.platform] != null
			and not platforms[ladder.platform].edge_holds(ladder.from, ladder.to)
		):
			found.append("ship: a ladder does not run along its platform's edge")
	for room: ShipRoom in rooms:
		if room == null or room.area.size.x <= 0.0 or room.area.size.y <= 0.0:
			found.append("ship: a room has no area")
	for prop: ShipProp in props:
		if prop == null:
			found.append("ship: a prop is missing")
		else:
			found.append_array(prop.problems())
	if min_seats < 1 or max_seats < min_seats:
		found.append("ship: min_seats must be at least 1 and at most max_seats")
	elif seats < min_seats or seats > max_seats:
		found.append("ship: %d seats, where she takes %d to %d" % [seats, min_seats, max_seats])
	if spawns.size() < seats:
		found.append("ship: %d spawns for %d seats" % [spawns.size(), seats])
	if structure != null:
		found.append_array(structure.problems())
	return found
