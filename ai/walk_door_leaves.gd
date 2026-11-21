class_name WalkDoorLeaves
extends RefCounted
## Which of a WalkGraph's portals each watertight door's leaf can stand across, so that
## a door sliding forgets only those portals' shut answers (WalkGraph._shut) rather
## than every portal's (#636). Per door a superset, judged from the same line and
## heights Surfaces.blocked hands DoorLeaves.crossed: a line no shut of the door from 0
## to 1 crosses (DoorLeaves.may_cross) is never listed, and never needs to be.

## Per portal, the line WalkGraph._shut asks Surfaces.blocked about — from a body's
## width before its entry to a body's width past its exit —, laid out flat: its start at
## index * 2, its end at index * 2 + 1.
var lines := PackedVector3Array()
## Per portal, 1 where it is no ramp: the portals WalkGraph._shut asks about.
var _flat := PackedByteArray()
var _leaves: DoorLeaves
## Per door, the portals its leaf may stand across.
var _portals: Array[PackedInt32Array] = []
## Per door, how far shut it stood (DoorLeaves.shut_in) when the answers kept were asked.
var _shut := PackedFloat64Array()


## Lists each of [param portals] — its line asked about for a body [param radius] wide
## and step * 2 tall with its feet able to step [param step], as WalkGraph._shut asks
## it — under every door whose leaf may stand across it.
func _init(
	leaves: DoorLeaves, portals: Array[WalkGraph.Portal], radius: float, step: float
) -> void:
	_leaves = leaves
	_portals.resize(leaves.count())
	for door in leaves.count():
		_portals[door] = PackedInt32Array()
	_shut.resize(leaves.count())
	for index in portals.size():
		var portal := portals[index]
		var through := Vector3(portal.along.x, 0.0, portal.along.y) * radius
		lines.append(portal.entry - through)
		lines.append(portal.exit + through)
		_flat.append(1 if portal.ramp == WalkGraph.NONE else 0)
		if portal.ramp != WalkGraph.NONE:
			continue
		var start := Vector2(lines[index * 2].x, lines[index * 2].z)
		var end := Vector2(lines[index * 2 + 1].x, lines[index * 2 + 1].z)
		var feet := minf(lines[index * 2].y, lines[index * 2 + 1].y) + step
		var head := maxf(lines[index * 2].y, lines[index * 2 + 1].y) + step * 2.0
		for door in leaves.count():
			if leaves.may_cross(door, start, end, feet, head):
				_portals[door].append(index)


## Forgets in [param shut] (per portal, 0 not yet known) the answers of the portals
## whose door stands otherwise under [param pose] than when they were asked — every one
## where [param every], or where a door stands past what the lists vouch for (0 to 1).
## Whether it forgot any.
func forget(pose: ShipPose, shut: PackedByteArray, every: bool) -> bool:
	var moved := PackedInt32Array()
	for door in _shut.size():
		var now := DoorLeaves.shut_in(pose, _leaves.name_of(door))
		if now == _shut[door]:
			continue
		if not (now >= 0.0 and now <= 1.0 and _shut[door] <= 1.0):
			every = true
		_shut[door] = now
		moved.append(door)
	if every:
		shut.fill(0)
		return true
	for door in moved:
		for portal in _portals[door]:
			shut[portal] = 0
	return not moved.is_empty()


## Fills in every answer [param shut] (per portal, 0 not yet known, 1 open, 2 shut) does
## not know yet as WalkGraph._shut would, asking [param surfaces] blocked of every line
## for bodies step * 2 tall with their feet able to step [param step]: natively, every
## line at once, where the extension is loaded.
func shut_all(surfaces: Surfaces, shut: PackedByteArray, step: float) -> void:
	var ask := PackedByteArray()
	ask.resize(shut.size())
	for index in shut.size():
		if shut[index] == 0:
			ask[index] = _flat[index]
	# The extension's twin of Surfaces.blocked is held to it (test_blocked_native).
	var mirror := surfaces.native
	var blocked := PackedByteArray()
	if mirror != null:
		blocked = mirror.blocked_all(lines, ask, step * 2.0, step)
	else:
		blocked.resize(ask.size())
		for index in ask.size():
			if (
				ask[index] == 1
				and surfaces.blocked(lines[index * 2], lines[index * 2 + 1], step * 2.0, step)
			):
				blocked[index] = 1
	for index in shut.size():
		if shut[index] == 0:
			shut[index] = 2 if blocked[index] == 1 else 1
