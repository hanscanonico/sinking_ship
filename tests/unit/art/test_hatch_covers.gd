extends GutTest
## A hatch's cover standing indoors (RoomDressing.furnish): a box over one of her
## structure's hatch openings in a room's floor is drawn as the hatch's cover battened
## under its tarpaulin (DeckWorks.hatch), as on her open decks — the Titanic's D deck
## covers of Nos. 1 and 2 and the bunker hatch (#404), in the firemen's quarters and the
## third-class open space, were dressed as tables.

const SHIP := "res://data/ships/titanic.tres"
## How far a hatch's battens' straps stand over its top (DeckWorks.hatch), where no table
## draws anything.
const STRAP_RISE := 0.01

var _layout: ShipLayout
var _space: ShipSpace


func before_all() -> void:
	_layout = load(SHIP)
	_space = ShipSpace.new(_layout)


## Every face [param room]'s furniture is drawn with (RoomDressing.furnish).
func _drawn(room: ShipRoom) -> PackedVector3Array:
	var lines: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, lines)
	RoomDressing.furnish(mesh, _space, room)
	var materials := {}
	for finish: int in ShipMesh.Finish.values():
		materials[finish] = StandardMaterial3D.new()
	var holder := Node3D.new()
	mesh.commit(holder, materials)
	var faces := PackedVector3Array()
	for child: Node in holder.get_children():
		faces.append_array((child as MeshInstance3D).mesh.get_faces())
	holder.free()
	return faces


func test_her_d_deck_hatch_covers_are_drawn_as_hatches() -> void:
	var covers := 0
	for room: ShipRoom in _layout.rooms:
		var found: Array[ShipBlocker] = []
		for blocker: ShipBlocker in _space.furniture(room):
			if DeckFurniture.is_hatch_cover(_layout, blocker):
				found.append(blocker)
		if found.is_empty():
			continue
		var faces := _drawn(room)
		for cover: ShipBlocker in found:
			covers += 1
			var strapped := false
			for corner: Vector3 in faces:
				var over := Vector2(corner.x, corner.z)
				strapped = (
					strapped
					or (
						is_equal_approx(corner.y, cover.top + STRAP_RISE)
						and cover.area.grow(0.05).has_point(over)
					)
				)
			assert_true(strapped, "%s's cover at %s battened, no table" % [room.name, cover.area])
	assert_eq(covers, 4, "No. 1's two halves, No. 2's and the bunker hatch's, on D deck")


func test_a_box_on_no_hatch_is_no_cover() -> void:
	var table := ShipBlocker.new()
	table.shape = ShipBlocker.Shape.BOX
	table.area = Rect2(0.0, 0.0, 1.0, 1.0)
	table.bottom = -1.25
	table.top = -0.5
	assert_false(DeckFurniture.is_hatch_cover(_layout, table))
