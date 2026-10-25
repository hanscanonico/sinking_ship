extends GutTest
## LinedFaces: a face of the ship's own looking into rooms with linings of their own
## takes each room's lining, cut where the lining it shows changes and at the chunk
## lines — never at the edge between two rooms lined alike — and is cut only at the
## edges of the lined rooms it reaches (RoomDressing.lining_lines).

## Two first-class corridors lined alike, x 0 to 6 and 6 to 10, then a store lined as a
## hold, 10 to 14: all across the flat deck, z -4 to 4.
const ROOMS := [
	[&"B deck corridor", 0.0, 6.0],
	[&"C deck corridor", 6.0, 10.0],
	[&"fore store", 10.0, 14.0],
]
## A floor over all three, short of their ends: the chunk lines x 4, 8 and 12 and z 0
## cross it.
const ORIGIN := Vector3(0.5, 0.0, -3.5)
const ACROSS := Vector3(0.0, 0.0, 7.0)
const ALONG := Vector3(13.0, 0.0, 0.0)

var _paint := ShipMesh.Paint.new(ShipMesh.Finish.DECK, Color.WHITE)
var _dressing: RoomDressing


func before_each() -> void:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	var rooms: Array[ShipRoom] = []
	for entry: Array in ROOMS:
		var room := ShipRoom.new()
		room.name = entry[0]
		room.area = Rect2(entry[1], -4.0, entry[2] - entry[1], 8.0)
		rooms.append(room)
	layout.rooms = rooms
	_dressing = RoomDressing.new(ShipSpace.new(layout))


## The floor drawn over the rooms, each piece in the floor of the room it looks into,
## committed: its mesh instances.
func _floor() -> Array[MeshInstance3D]:
	var none: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, none)
	var floor := RoomDressing.Part.FLOOR
	LinedFaces.new(_dressing).face(mesh, ORIGIN, ACROSS, ALONG, _paint, floor, -0.1, 0.0)
	var node := Node3D.new()
	add_child_autofree(node)
	var materials := {}
	for finish: int in ShipMesh.Finish.values():
		materials[finish] = StandardMaterial3D.new()
	mesh.commit(node, materials)
	var found: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		found.append(child as MeshInstance3D)
	return found


## Each corner of [param instances] with its colour, as [corner, colour].
func _corners(instances: Array[MeshInstance3D]) -> Array[Array]:
	var found: Array[Array] = []
	for instance: MeshInstance3D in instances:
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in vertices.size():
				found.append([vertices[index], colours[index]])
	return found


## Where along [param axis] (0 x, 2 z) the pieces of [param instances] meet, in order:
## each corner's, but for those at the floor's edges and their rims.
func _seams(instances: Array[MeshInstance3D], axis: int) -> Array[float]:
	var low := ORIGIN[axis] + ShipMesh.RIM + 0.01
	var high := ORIGIN[axis] + (ALONG + ACROSS)[axis] - ShipMesh.RIM - 0.01
	var found: Array[float] = []
	for corner: Array in _corners(instances):
		var at := snappedf((corner[0] as Vector3)[axis], 0.001)
		if at > low and at < high and not at in found:
			found.append(at)
	found.sort()
	return found


func test_a_face_is_cut_where_its_lining_changes_and_at_its_chunk_lines() -> void:
	var drawn := _floor()
	assert_eq(_seams(drawn, 0), [4.0, 8.0, 10.0, 12.0] as Array[float], "along")
	assert_eq(_seams(drawn, 2), [0.0] as Array[float], "across")


func test_each_piece_takes_the_floor_of_the_room_it_looks_into() -> void:
	var carpet: ShipMesh.Paint = LinerCorridor.linings()[RoomDressing.Part.FLOOR]
	for corner: Array in _corners(_floor()):
		var at: Vector3 = corner[0]
		var colour: Color = corner[1]
		if at.x < 9.99:
			assert_eq(colour, carpet.colour_in, "the corridors' carpet at %s" % at)
		elif at.x > 10.01:
			assert_eq(colour, ShipPaints.hold_floor.colour_in, "the store's floor at %s" % at)


func test_only_the_lined_rooms_a_face_reaches_cut_it() -> void:
	var over_the_store := AABB(Vector3(10.5, -0.2, -3.5), Vector3(3.0, 0.4, 7.0))
	var lines := _dressing.lining_lines(over_the_store)
	assert_eq(lines[0], PackedFloat32Array([10.0, 14.0]), "along: the store's ends alone")
	assert_eq(lines[1], PackedFloat32Array(), "none up")
	assert_eq(lines[2], PackedFloat32Array([-4.0, 4.0]), "across")
