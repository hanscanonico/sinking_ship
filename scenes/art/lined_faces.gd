class_name LinedFaces
extends RefCounted
## The ship's own faces where they may look into a room with a lining of its own
## (RoomDressing.lining): a deck's planks and ceiling, a wall's sides. Each piece of a
## face takes the lining of the room it looks into for what it is to that room — a top
## its floor, a bottom its ceiling, a side its wall — so a face is cut where the
## lining it shows changes, where such a room begins or ends, and at the chunk lines;
## never at the edge between two rooms that line it alike.

var _dressing: RoomDressing


func _init(dressing: RoomDressing) -> void:
	_dressing = dressing


## A box as ShipMesh.box() draws it in [param paint] — [param faces] of it — on
## [param mesh]: of the faces [param lined] names, each piece in the lining of the room
## it looks into (face()).
func box(
	mesh: ShipMesh,
	area: Rect2,
	bottom: float,
	top: float,
	paint: ShipMesh.Paint,
	faces: int,
	lined: int,
	foot := NAN,
	head := NAN
) -> void:
	foot = bottom if is_nan(foot) else foot
	head = top if is_nan(head) else head
	var x0 := area.position.x
	var x1 := area.end.x
	var z0 := area.position.y
	var z1 := area.end.y
	var dx := Vector3(area.size.x, 0.0, 0.0)
	var dy := Vector3(0.0, top - bottom, 0.0)
	var dz := Vector3(0.0, 0.0, area.size.y)
	var floor := RoomDressing.Part.FLOOR
	var wall := RoomDressing.Part.WALL
	# The faces as ShipMesh.box() lays them out, each with what it is to a room.
	var sides := [
		[ShipMesh.TOP, Vector3(x0, top, z0), dz, dx, floor],
		[ShipMesh.BOTTOM, Vector3(x0, bottom, z0), dx, dz, RoomDressing.Part.OVERHEAD],
		[ShipMesh.POS_X, Vector3(x1, bottom, z0), dy, dz, wall],
		[ShipMesh.NEG_X, Vector3(x0, bottom, z0), dz, dy, wall],
		[ShipMesh.POS_Z, Vector3(x0, bottom, z1), dx, dy, wall],
		[ShipMesh.NEG_Z, Vector3(x0, bottom, z0), dy, dx, wall],
	]
	for side: Array in sides:
		if faces & side[0]:
			var part: int = side[4] if lined & side[0] else -1
			face(mesh, side[1], side[2], side[3], paint, part, foot, head)


## A face from [param origin] along [param u] and [param v] in [param paint] on
## [param mesh], each piece in the lining for [param part] (-1 for none) of the room it
## looks into, if any; only the whole face's edges rimmed. A face too narrow for
## ShipMesh to cut — a plank's edge, a wall's top — is cut at the chunk lines all the
## same, so it lies in one chunk's mesh a piece, never a sliver the length of the deck
## that every lamp along it reaches.
func face(
	mesh: ShipMesh,
	origin: Vector3,
	u: Vector3,
	v: Vector3,
	paint: ShipMesh.Paint,
	part: int,
	foot: float,
	head: float
) -> void:
	var normal := u.cross(v).normalized()
	var narrow := minf(u.length(), v.length()) < ShipMesh.NARROW
	var box := AABB(origin, Vector3.ZERO).expand(origin + u + v).grow(ShipMesh.PROBE)
	if not narrow and (part == -1 or not _dressing.lined_near(box)):
		mesh.face(origin, u, v, paint, ShipMesh.RIM_ALL, foot, head)
		return
	var lines := _dressing.lining_lines(box) if part != -1 else _no_lines()
	var u_cuts := ShipMesh.splits(origin, u, lines)
	var v_cuts := ShipMesh.splits(origin, v, lines)
	var shows := []
	for i in u_cuts.size() - 1:
		for j in v_cuts.size() - 1:
			shows.append(_lining(origin, u, v, u_cuts, v_cuts, i, j, part))
	var kept := ShipMesh.needed(origin, u, v, u_cuts, v_cuts, shows)
	u_cuts = kept[0]
	v_cuts = kept[1]
	for i in u_cuts.size() - 1:
		for j in v_cuts.size() - 1:
			var at := origin + u * u_cuts[i] + v * v_cuts[j]
			var piece_u := u * (u_cuts[i + 1] - u_cuts[i])
			var piece_v := v * (v_cuts[j + 1] - v_cuts[j])
			var lining := _lining(origin, u, v, u_cuts, v_cuts, i, j, part)
			var rims := (
				(ShipMesh.RIM_U0 if i == 0 else 0)
				| (ShipMesh.RIM_U1 if i == u_cuts.size() - 2 else 0)
				| (ShipMesh.RIM_V0 if j == 0 else 0)
				| (ShipMesh.RIM_V1 if j == v_cuts.size() - 2 else 0)
			)
			mesh.face(at, piece_u, piece_v, paint if lining == null else lining, rims, foot, head)


## The lining for [param part] (-1 for none) of the room the piece of a face from
## [param origin] along [param u] and [param v] between cuts [param i] and i + 1 of
## [param u_cuts] and [param j] and j + 1 of [param v_cuts] looks into; null for none.
func _lining(
	origin: Vector3,
	u: Vector3,
	v: Vector3,
	u_cuts: PackedFloat32Array,
	v_cuts: PackedFloat32Array,
	i: int,
	j: int,
	part: int
) -> ShipMesh.Paint:
	if part == -1:
		return null
	var middle := origin + u * (u_cuts[i] + u_cuts[i + 1]) * 0.5
	middle += v * (v_cuts[j] + v_cuts[j + 1]) * 0.5
	return _dressing.lining(middle + u.cross(v).normalized() * ShipMesh.PROBE, part)


## No lines to cut at but the chunk lines (ShipMesh.splits()).
static func _no_lines() -> Array[PackedFloat32Array]:
	var none: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	return none
