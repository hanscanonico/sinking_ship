class_name DoorLeaves
extends RefCounted
## The watertight doors the ship shuts at the hit (§5b.2, SH26), as Surfaces meets
## them: each a steel leaf sliding across its doorway from one jamb over its shut time,
## as far as the pose says (ShipPose.doors_shut); a jammed one never moves. A leaf
## holds a body back like a wall, but pushes anyone in its path to the side of the
## doorway their centre is on — never along it — and hides and stops a shove like a
## wall where it has slid across. Ship-local metres (D6).

## Per door: its name, the axis its doorway is flat across (0 x, 2 z) and where, the
## jamb it slides from and how wide it is, from its sill to its head; and how far shut
## the pose last honoured has it.
var _names: Array[StringName] = []
var _axes := PackedInt32Array()
var _planes := PackedFloat64Array()
var _jambs := PackedFloat64Array()
var _widths := PackedFloat64Array()
var _sills := PackedFloat64Array()
var _heads := PackedFloat64Array()
var _shut := PackedFloat64Array()


func _init(structure: ShipStructure) -> void:
	if structure == null:
		return
	for opening: ShipOpening in structure.openings:
		if not opening.shuts_at_hit:
			continue
		var axis := opening.facing()
		var along := 2 if axis == 0 else 0
		_names.append(opening.name)
		_axes.append(axis)
		_planes.append(opening.centre[axis])
		_jambs.append(opening.centre[along] - opening.size[along] * 0.5)
		_widths.append(opening.size[along])
		_sills.append(opening.centre.y - opening.size.y * 0.5)
		_heads.append(opening.centre.y + opening.size.y * 0.5)
		_shut.append(0.0)


## Takes how far [param pose] has each door shut.
func honour(pose: ShipPose) -> void:
	for door in _names.size():
		_shut[door] = pose.doors_shut.get(_names[door], 0.0)


## What the leaves hold back a circle of [param radius] at [param point] (x/z) with
## its feet able to step to [param reach_up] and its head at [param head]: per leaf it
## reaches, out to the side of the doorway its centre is on, by as much as it reaches
## past the leaf's line.
func contacts(
	point: Vector2, reach_up: float, head: float, radius: float
) -> Array[Surfaces.Contact]:
	var found: Array[Surfaces.Contact] = []
	for door in _names.size():
		if _shut[door] <= 0.0 or reach_up >= _heads[door] or head <= _sills[door]:
			continue
		var across := (point.x if _axes[door] == 0 else point.y) - _planes[door]
		var along := point.y if _axes[door] == 0 else point.x
		var from := _jambs[door]
		var to := from + _widths[door] * _shut[door]
		var off := maxf(maxf(from - along, along - to), 0.0)
		if off >= radius:
			continue
		var reach := sqrt(radius * radius - off * off)
		if absf(across) >= reach:
			continue
		var side := 1.0 if across >= 0.0 else -1.0
		var normal := Vector2(side, 0.0) if _axes[door] == 0 else Vector2(0.0, side)
		found.append(Surfaces.Contact.new(normal, reach - absf(across)))
	return found


## Whether a leaf stands across the line from [param start] to [param end] (x/z)
## anywhere between [param low] and [param high].
func crossed(start: Vector2, end: Vector2, low: float, high: float) -> bool:
	for door in _names.size():
		if _shut[door] <= 0.0 or high <= _sills[door] or low >= _heads[door]:
			continue
		var axis := 0 if _axes[door] == 0 else 1
		var a := start[axis] - _planes[door]
		var b := end[axis] - _planes[door]
		if a * b > 0.0 or a == b:
			continue
		var along := start.lerp(end, a / (a - b))[1 - axis]
		var from := _jambs[door]
		if along >= from and along <= from + _widths[door] * _shut[door]:
			return true
	return false
