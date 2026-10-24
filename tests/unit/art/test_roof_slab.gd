extends GutTest
## A slab roofing a room over, no deck of its own (ShipArt): planked up to its own top
## all over — under a deck laid on part of it, the deck's planks, and elsewhere its
## own — so no stretch of it stands a plank short of its data (art-lint's blocker
## check; #300's roofs over the Titanic's F deck rooms).

const RAILING_HEIGHT := 1.0
const BODY_RADIUS := 0.35
## How near the slab's top a face looking up must stand.
const NEAR := 0.005
const TOP := 2.5


## A cabin on the flat deck roofed by a slab, a deck laid on the slab's after half
## alone, dressed.
func _art() -> ShipArt:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	var room := ShipRoom.new()
	room.name = &"cabin"
	room.area = Rect2(0.0, -2.0, 4.0, 4.0)
	layout.rooms = [room]
	var slab := ShipBlocker.new()
	slab.area = room.area
	slab.bottom = TOP - 0.2
	slab.top = TOP
	layout.blockers = [slab]
	var deck := ShipPlatform.new()
	deck.name = &"roof"
	deck.area = Rect2(0.0, -2.0, 2.0, 4.0)
	deck.height = TOP
	var platforms: Array[ShipPlatform] = []
	platforms.append_array(layout.platforms)
	platforms.append(deck)
	layout.platforms = platforms
	var art := ShipArt.new()
	add_child_autofree(art)
	art.build(layout, RAILING_HEIGHT, BODY_RADIUS)
	return art


func test_a_slab_is_planked_up_to_its_top_where_no_deck_covers_it() -> void:
	var faces := _faces(_art())
	for point: Vector2 in [Vector2(1.0, 0.0), Vector2(3.0, 0.0)]:
		assert_true(_faces_up_at(faces, point, TOP), "a top at its height over %s" % point)


## Whether a face looking up stands within NEAR of [param height] straight under
## [param point] seen from over it.
func _faces_up_at(faces: PackedVector3Array, point: Vector2, height: float) -> bool:
	var from := Vector3(point.x, height + 1.0, point.y)
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, a, b, c)
		if hit == null or absf((hit as Vector3).y - height) > NEAR:
			continue
		if FaceCells.facing(a, b, c) > 0.5:
			return true
	return false


## Every triangle drawn under [param art], in its space.
func _faces(art: ShipArt) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for instance: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var to_ship := art.global_transform.affine_inverse() * mesh.global_transform
		for corner: Vector3 in mesh.mesh.get_faces():
			faces.append(to_ship * corner)
	return faces
