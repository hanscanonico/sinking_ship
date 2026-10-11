extends GutTest
## Every deck drawn has an underside, whatever lies under it (ShipArt): the Titanic's
## forecastle head, with no deck beneath it, shows a ceiling from below and never the
## sky through it.

const TITANIC := "res://data/ships/titanic.tres"
const RAILING_HEIGHT := 1.0
const BODY_RADIUS := 0.35
## How far under the planking's underside a drawn face may stand.
const NEAR := 0.02


func test_the_forecastle_head_is_closed_from_below() -> void:
	var layout: ShipLayout = load(TITANIC)
	var space := ShipSpace.new(layout)
	# The forecastle head: her forecastle's highest strips; its foremost one.
	var head: ShipPlatform
	for platform: ShipPlatform in layout.platforms:
		if platform.name != &"forecastle":
			continue
		if head == null or platform.height > head.height + 1e-4:
			head = platform
		elif (
			is_equal_approx(platform.height, head.height)
			and platform.area.position.x > head.area.position.x
		):
			head = platform
	assert_not_null(head, "the Titanic has a forecastle")
	assert_false(space.stands_over_a_platform(head), "no deck under her forecastle head")
	var art := ShipArt.new()
	add_child_autofree(art)
	art.build(layout, RAILING_HEIGHT, BODY_RADIUS)
	var faces := _faces(art)
	var under := head.height - ShipArt.PLANK
	var area := head.area.grow(-0.1)
	for along in 3:
		for across in 3:
			var point := area.position + area.size * Vector2(along, across) * 0.5
			assert_true(_faces_down_under(faces, point, under), "an underside under %s" % point)


## Whether a face looking down stands within NEAR of [param height] straight over
## [param point].
func _faces_down_under(faces: PackedVector3Array, point: Vector2, height: float) -> bool:
	var from := Vector3(point.x, height - 1.0, point.y)
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.UP, a, b, c)
		if hit == null or absf((hit as Vector3).y - height) > NEAR:
			continue
		# Godot's front faces wind clockwise: their normal is the cross reversed.
		if -(b - a).cross(c - a).normalized().y < -0.5:
			return true
	return false


## Every triangle drawn under [param root], in its ship space.
func _faces(root: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for instance: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		if mesh.mesh == null:
			continue
		var to_ship := root.global_transform.affine_inverse() * mesh.global_transform
		for corner: Vector3 in mesh.mesh.get_faces():
			faces.append(to_ship * corner)
	return faces
