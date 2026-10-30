extends GutTest
## A room's wall along her side is drawn up to the room's ceiling (ShipArt): where the
## deck over a room stops short of its hull-side wall, the room reaches up to the next
## deck, and from inside it nothing shows her shell's outside — the sky — over the wall
## (#147): the small Titanic's galley, roofed by A deck along its port side where C and B
## deck stop short. (The Titanic's traced C deck, #368, reaches her side.)

const RAILING_HEIGHT := 1.0
const BODY_RADIUS := 0.35
## How far past a wall's line its face may stand: half its thickness and a little.
const NEAR := 0.15


func test_a_tall_room_s_hull_side_shows_its_wall_up_to_its_deckhead() -> void:
	var art := ShipArt.new()
	add_child_autofree(art)
	art.build(Fleet.layout(&"small_titanic"), RAILING_HEIGHT, BODY_RADIUS)
	var faces := _faces(art)
	# [what, eye, the way to her side, the wall's line]: each eye a metre and more over
	# its room's wall's top.
	var cases := [
		["the galley's port side", Vector3(-21.0, 2.0, -12.3), Vector3.FORWARD, -13.0],
	]
	for case: Array in cases:
		var hit := _first_hit(faces, case[1], case[2])
		assert_false(hit.is_empty(), "%s: something drawn" % case[0])
		if hit.is_empty():
			continue
		var at: Vector3 = hit[0]
		assert_lt(absf(at.z - case[3]), NEAR, "%s: its wall, short of her shell" % case[0])
		assert_lt((hit[1] as Vector3).dot(case[2]), -0.5, "%s: facing into the room" % case[0])


## The nearest triangle of [param faces] a ray from [param from] along [param way]
## meets, as [where, its front's normal]; empty where none does.
func _first_hit(faces: PackedVector3Array, from: Vector3, way: Vector3) -> Array:
	var nearest: Array = []
	var best := INF
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, way, a, b, c)
		if hit == null:
			continue
		var distance := from.distance_to(hit as Vector3)
		if distance < best:
			best = distance
			# Godot's front faces wind clockwise: their normal is the cross reversed.
			nearest = [hit, -(b - a).cross(c - a).normalized()]
	return nearest


## Every triangle drawn under [param root], in its space.
func _faces(root: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for instance: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var to_ship := root.global_transform.affine_inverse() * mesh.global_transform
		for corner: Vector3 in mesh.mesh.get_faces():
			faces.append(to_ship * corner)
	return faces
