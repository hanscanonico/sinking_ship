extends GutTest
## No face stands just inside her shell facing out (ShipHull.under_skin): the outside of
## a wall along her side, and the edge of the deck it stands on, a few centimetres in
## from the skin, are left undrawn, for from afar they tied the shell in depth and
## showed through her black side in white patches (#454). Rays in at her side
## amidships, where the Titanic's rooms' outer walls stand 7 cm in from her parallel
## body, meet her shell and nothing facing out close behind it.

const RAILING_HEIGHT := 1.0
const BODY_RADIUS := 0.35
## The stretch of her drawn, and the heights the rays come in at: B, C, D, E and F
## deck's rooms amidships.
const SPAN := Vector2(-3.0, 3.0)
const HEIGHTS := Vector2(-8.0, 2.0)
## How far out from her centreline the rays start.
const OUT := 30.0
## How far in behind her shell a face facing out ties it in depth, seen from afar: a
## 24-bit depth buffer's step at 300 m from a 5 cm near plane, about 10 cm.
const TIE := 0.1
## How far off her shell's line her own faces may lie, its loft against her sections.
const ON_SHELL := 0.01


func test_no_face_faces_out_just_inside_her_shell() -> void:
	var layout := Fleet.layout(&"titanic")
	var art := ShipArt.new()
	art.span = SPAN
	add_child_autofree(art)
	art.build(layout, RAILING_HEIGHT, BODY_RADIUS)
	var faces := _faces(art)
	var rays := 0
	var behind := 0
	for side: int in [1, -1]:
		var way := Vector3(0.0, 0.0, -side)
		var x := SPAN.x + 0.5
		while x < SPAN.y - 0.25:
			var y := HEIGHTS.x
			while y <= HEIGHTS.y:
				var shell := OUT - layout.structure.half_breadth(x, y, side)
				rays += 1
				for hit: float in _facing(faces, Vector3(x, y, OUT * side), way):
					var depth := hit - shell
					if depth > ON_SHELL and depth < TIE:
						behind += 1
						gut.p("x %.2f y %.2f side %+d: a face %.3f m in" % [x, y, side, depth])
						break
				y += 0.25
			x += 0.5
	assert_gt(rays, 100, "the rays meet her side")
	assert_eq(behind, 0, "no face facing out stands just inside her shell")


## Of [param faces], how far along a ray from [param from] along [param way] each one
## whose front faces back along it lies, nearest first.
func _facing(faces: PackedVector3Array, from: Vector3, way: Vector3) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		# Godot's front faces wind clockwise: their normal is the cross reversed.
		if (b - a).cross(c - a).dot(way) <= 0.0:
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, way, a, b, c)
		if hit != null:
			found.append(from.distance_to(hit as Vector3))
	found.sort()
	return found


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
