extends GutTest

var _points: PackedVector3Array
var _indices: PackedInt32Array
var _bounds: AABB


func before_all() -> void:
	var mesh := SeaAndSky.sea_mesh()
	var arrays := mesh.surface_get_arrays(0)
	_points = arrays[Mesh.ARRAY_VERTEX]
	_indices = arrays[Mesh.ARRAY_INDEX]
	_bounds = mesh.get_aabb()


func test_every_face_of_the_sea_faces_up() -> void:
	var turned := 0
	for index in range(0, _indices.size(), 3):
		var a := _points[_indices[index]]
		var b := _points[_indices[index + 1]]
		var c := _points[_indices[index + 2]]
		# Godot draws a face's front turning clockwise, so one facing up crosses down.
		if (b - a).cross(c - a).y >= 0.0:
			turned += 1
	assert_eq(turned, 0)


func test_the_sea_reaches_past_its_reach_every_way() -> void:
	assert_lte(_bounds.position.x, -SeaAndSky.REACH)
	assert_lte(_bounds.position.z, -SeaAndSky.REACH)
	assert_gte(_bounds.end.x, SeaAndSky.REACH)
	assert_gte(_bounds.end.z, SeaAndSky.REACH)


func test_the_fine_grid_and_the_skirt_meet_point_for_point() -> void:
	var half := SeaAndSky.CELL * SeaAndSky.CELLS / 2.0
	var seam := {}
	for point: Vector3 in _points:
		if maxf(absf(point.x), absf(point.z)) == half:
			seam[point] = seam.get(point, 0) + 1
	assert_eq(seam.size(), SeaAndSky.CELLS * 4)
	for count: int in seam.values():
		assert_eq(count, 2)
