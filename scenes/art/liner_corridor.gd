class_name LinerCorridor
extends RefCounted
## A liner's first-class corridors (RoomDressing.Kind.FIRST_CORRIDOR): her B, C and D
## deck corridors. A corridor's dressing still — handrails, a lifebelt, fire buckets,
## RoomDressing's door signs over each doorway — in white panelling over a red carpet,
## and down both long walls a stateroom door every DOOR_SPACING where no real doorway
## is, each with its number plate and knob, and a brass sconce every SCONCE_SPACING.
## The grand staircase's landings (Kind.STAIRCASE) are LinerPublic's.
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6). So
## everything here is flat on a wall: no furniture stands out in the corridor.

## How far apart along a wall the stateroom doors and the sconces stand.
const DOOR_SPACING := 3.0
const SCONCE_SPACING := 6.0
## A stateroom door: how wide and tall, how deep out of its wall, and its
## architrave's margin round it.
const DOOR := Vector2(0.8, 2.0)
const DOOR_DEPTH := 0.02
const ARCHITRAVE := 0.06
## How far along a wall either side of its middle no door stands: room for the
## lifebelt, or the fire buckets' shelf across from it.
const MIDDLE_CLEAR := 0.85
## How high a sconce burns, and how far its shade stands out of the wall.
const SCONCE_HEIGHT := 1.75
const SCONCE_DEPTH := 0.1
## The corridors' own colours.
const CARPET := Color("7a2630")
const WHITE_PANEL := Color("f1ede2")
const MAHOGANY := Color("5a3420")
const SCONCE_GLOW := Color("fff0c4")

static var _carpet := ShipMesh.Paint.new(
	ShipMesh.Finish.DECK, ArtPalette.DECK, ShipMesh.Finish.PLAIN, CARPET
)
static var _white_panel := ShipMesh.Paint.new(
	ShipMesh.Finish.HOUSE, ArtPalette.HOUSE, ShipMesh.Finish.CABIN, WHITE_PANEL
)
static var _door := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, MAHOGANY)
static var _glow := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, SCONCE_GLOW)

var _space: ShipSpace
## RoomDressing's corridor dressing: (mesh: ShipMesh, room: ShipRoom).
var _passage: Callable


func _init(space: ShipSpace, passage: Callable) -> void:
	_space = space
	_passage = passage


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, _glass: Array[Array]) -> void:
	_passage.call(mesh, room)
	for wall: RoomDressing.Wall in long_walls(_space, room):
		for along: float in doors(_space.layout, wall):
			_stateroom_door(mesh, wall, along)
		for along: float in sconces(_space.layout, wall):
			_sconce(mesh, wall, along)


## The lights [param room] is lit by; none keeps RoomDressing's pendants — the
## sconces are lamps drawn, not lit.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a first-class corridor lines its walls, floor, ceiling and beams with
## (RoomDressing.Part): white panelling, a red carpet, the ship's own overhead.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = [_white_panel, _carpet, null, null]
	return paints


## [param room]'s walls on [param space] along its length, each a stretch between
## doorways.
static func long_walls(space: ShipSpace, room: ShipRoom) -> Array[RoomDressing.Wall]:
	var along_x := room.area.size.x >= room.area.size.y
	var found: Array[RoomDressing.Wall] = []
	for wall: RoomDressing.Wall in RoomDressing.walls(space, room):
		if (wall.side % 2 == 0) == along_x:
			found.append(wall)
	return found


## Where along [param wall] of [param layout] a stateroom door stands: every
## DOOR_SPACING, wholly on the wall, clear of its middle and of any stair beside it.
static func doors(layout: ShipLayout, wall: RoomDressing.Wall) -> PackedFloat32Array:
	var half := DOOR.x * 0.5 + ARCHITRAVE
	return _spots(layout, wall, DOOR_SPACING * 0.5, DOOR_SPACING, half, MIDDLE_CLEAR)


## Where along [param wall] of [param layout] a sconce burns: every SCONCE_SPACING,
## between two doors, clear of the lifebelt in its middle and of any stair.
static func sconces(layout: ShipLayout, wall: RoomDressing.Wall) -> PackedFloat32Array:
	return _spots(layout, wall, DOOR_SPACING, SCONCE_SPACING, 0.1, 0.5)


## Every [param spacing] along [param wall] from [param first] past its start, those
## [param half] either side of which lie wholly on it, over no stair and more than
## [param clear] from its middle.
static func _spots(
	layout: ShipLayout,
	wall: RoomDressing.Wall,
	first: float,
	spacing: float,
	half: float,
	clear: float
) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	var along := wall.from + first
	while along + half <= wall.to:
		var area := wall.rect(along - half, along + half, 0.0, 0.5)
		var clear_of_stairs := not RoomDressing.over_a_ramp(
			layout, area, wall.floor, wall.floor + 2.5
		)
		if along - half >= wall.from and absf(along - wall.middle()) > clear and clear_of_stairs:
			found.append(along)
		along += spacing
	return found


## A slab on [param wall] over [param span] — from x to y along it, z to w over its
## floor — standing [param near] to [param far] out from its face: its front, its ends
## when [param ends], its top when [param top] and its underside when [param under];
## unrimmed quads, two triangles a face. A face only a standing eye could never see —
## the top of a piece over the eye, the underside of one under it — is left out.
static func _slab(
	mesh: ShipMesh,
	wall: RoomDressing.Wall,
	span: Vector4,
	near: float,
	far: float,
	paint: ShipMesh.Paint,
	top := true,
	under := false,
	ends := true
) -> void:
	var back: Array[Vector3] = [
		wall.at(span.x, span.z, near),
		wall.at(span.y, span.z, near),
		wall.at(span.y, span.w, near),
		wall.at(span.x, span.w, near),
	]
	var front: Array[Vector3] = []
	for corner: Vector3 in back:
		front.append(corner + wall.normal * (far - near))
	mesh.quad(front[0], front[1], front[2], front[3], wall.normal, paint, 0)
	if ends:
		mesh.quad(back[0], front[0], front[3], back[3], -wall.right, paint, 0)
		mesh.quad(front[1], back[1], back[2], front[2], wall.right, paint, 0)
	if top:
		mesh.quad(front[3], front[2], back[2], back[3], Vector3.UP, paint, 0)
	if under:
		mesh.quad(back[0], back[1], front[1], front[0], Vector3.DOWN, paint, 0)


## A stateroom door on [param wall] at [param along]: a teak architrave flat on the
## panelling, a mahogany door DOOR_DEPTH out of it, a brass number plate over a brass
## knob.
func _stateroom_door(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var surround := Vector2(DOOR.x * 0.5 + ARCHITRAVE, (DOOR.y + ARCHITRAVE) * 0.5)
	var middle := wall.at(along, surround.y, 0.006)
	RoomDressing.panel(mesh, middle, wall.right, surround, wall.normal, ShipPaints.frame, 0)
	var half := DOOR.x * 0.5
	var leaf := Vector4(along - half, along + half, 0.0, DOOR.y)
	_slab(mesh, wall, leaf, 0.0, DOOR_DEPTH, _door, false)
	var plate := wall.at(along, 1.55, DOOR_DEPTH + 0.003)
	var size := Vector2(0.06, 0.035)
	RoomDressing.panel(mesh, plate, wall.right, size, wall.normal, ShipPaints.brass, 0)
	var knob := along + half - 0.1
	var at := Vector4(knob - 0.025, knob + 0.025, 0.975, 1.025)
	_slab(mesh, wall, at, DOOR_DEPTH, DOOR_DEPTH + 0.05, ShipPaints.brass)


## A sconce on [param wall] at [param along]: a brass back plate, an arm out of it and
## a glowing shade SCONCE_DEPTH out at SCONCE_HEIGHT.
func _sconce(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var back := wall.at(along, SCONCE_HEIGHT - 0.05, 0.004)
	var plate := Vector2(0.05, 0.09)
	RoomDressing.panel(mesh, back, wall.right, plate, wall.normal, ShipPaints.brass, 0)
	var low := SCONCE_HEIGHT - 0.1
	var arm := Vector4(along - 0.012, along + 0.012, low, low + 0.024)
	_slab(mesh, wall, arm, 0.004, 0.03, ShipPaints.brass, false, true, false)
	var shade := Vector4(along - 0.06, along + 0.06, low + 0.024, SCONCE_HEIGHT + 0.06)
	_slab(mesh, wall, shade, 0.03, SCONCE_DEPTH, _glow, false, true)
