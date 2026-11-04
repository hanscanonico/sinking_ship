class_name RoomOutlets
extends RefCounted
## Per room of a layout, what the air in it blows out through as it floods, and the
## machine standing in it with the vents its steam comes up through (FxPlanner): found
## once, as the match's effects are planned, each room asking only the boxes near it.

## How many vents a machinery room breathes through, at most.
const VENTS := 2

## Per room, the openings air blows out of as it floods: points and their outward.
var openings: Array[PackedVector3Array] = []
var outwards: Array[PackedVector3Array] = []
## Per room, the top of the machine standing in it, or NAN for none; and the vents
## its steam comes up through.
var machines := PackedVector3Array()
var vents: Array[PackedVector3Array] = []

var _layout: ShipLayout
var _space: ShipSpace
## Her boxes, by blocker index, on a grid over their footprints: a room asks only those
## near it, in the order a scan of every blocker meets them.
var _boxes: SpatialIndex
## Per blocker, whether it is a hatch (_is_hatch): 0 not yet asked, 1 one, 2 not.
var _hatches := PackedByteArray()


func _init(layout: ShipLayout, space: ShipSpace, surfaces: Surfaces, rules: BrawlRules) -> void:
	_layout = layout
	_space = space
	_boxes = SpatialIndex.new(SpatialIndex.bounds_of(layout), ShipSpace.ROOM_CELL)
	for index in layout.blockers.size():
		var blocker := layout.blockers[index]
		if blocker.shape == ShipBlocker.Shape.BOX:
			_boxes.insert(index, blocker.area.grow(ShipSpace.NEAR_SLACK))
	_hatches.resize(layout.blockers.size())
	for room: ShipRoom in layout.rooms:
		_find_openings(room, surfaces, rules)
		_find_machine(room)


## [param room]'s doorways out onto the open deck, at chest height, and every hatch
## standing on a deck over it, at its top: what the air in it blows out through as
## it floods, where it can be seen.
func _find_openings(room: ShipRoom, surfaces: Surfaces, rules: BrawlRules) -> void:
	var points := PackedVector3Array()
	var ways := PackedVector3Array()
	for door: ShipRoom.Door in room.doors(surfaces, rules.body_height, rules.step_height):
		var middle := door.middle()
		var at := Vector3(middle.x, room.floor_height + rules.body_height * 0.6, middle.y)
		var outward := Vector3(door.outward.x, 0.0, door.outward.y)
		if not _space.outdoors(at + outward * 0.6):
			continue
		points.append(at)
		ways.append(outward)
	for index: int in _boxes.near(room.area.grow(ShipSpace.NEAR_SLACK)):
		var blocker := _layout.blockers[index]
		if blocker.bottom > room.floor_height and _is_hatch(index):
			var middle := blocker.area.get_center()
			if room.area.has_point(middle):
				points.append(Vector3(middle.x, blocker.top, middle.y))
				ways.append(Vector3.UP)
	openings.append(points)
	outwards.append(ways)


## The machine standing in [param room] — a box that is not a wall, indoors, as
## ShipArt draws an engine — and the vents up from it: skylights in the open deck
## straight over the room, along its middle.
func _find_machine(room: ShipRoom) -> void:
	var machine := Vector3(NAN, NAN, NAN)
	for index: int in _boxes.near(room.area.grow(ShipSpace.NEAR_SLACK)):
		var blocker := _layout.blockers[index]
		if _space.is_wall(blocker):
			continue
		var middle := blocker.area.get_center()
		if absf(blocker.bottom - room.floor_height) >= 0.05 or not room.area.has_point(middle):
			continue
		if not _space.outdoors(Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y)):
			machine = Vector3(middle.x, blocker.top, middle.y)
	machines.append(machine)
	var found := PackedVector3Array()
	if not is_nan(machine.x):
		var area := room.area
		for share in VENTS:
			var at := Vector2(
				area.position.x + area.size.x * (share + 1.0) / (VENTS + 1.0), area.get_center().y
			)
			var deck := _space.deck_under(at, INF)
			var vent := Vector3(at.x, deck, at.y)
			if not is_nan(deck) and _space.outdoors(vent + Vector3.UP * 0.5):
				found.append(vent)
	vents.append(found)


## Whether the blocker at [param index], a box, is one standing outdoors on a deck that
## is not a wall: ShipArt's tarpaulined hatch. Asked once a blocker, as every room round
## it asks it.
func _is_hatch(index: int) -> bool:
	if _hatches[index] == 0:
		var blocker := _layout.blockers[index]
		var hatch := not _space.is_wall(blocker)
		if hatch:
			var middle := blocker.area.get_center()
			var inside := Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y)
			hatch = _space.outdoors(inside)
		_hatches[index] = 1 if hatch else 2
	return _hatches[index] == 1
