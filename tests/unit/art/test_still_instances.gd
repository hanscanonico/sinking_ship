extends GutTest
## Her still art stands apart from her node (StillInstances, #410): each instance it holds
## is top level, so her moving reaches none, and is placed just before each frame is drawn
## where the ShipArt it hangs under stands — after she breaks, each stretch's instances
## where its own piece stands, and placed again wherever a stretch is hung anew. The
## extension and the GDScript hand RenderingServer the same transform.

const LOOSE := 3


## Whether the extension is loaded: a failure where CI requires it, pending elsewhere.
func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeStill"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false


## A piece of her under [param holder]: an art node holding LOOSE meshes hung as the
## identity, held by its StillInstances, and one mesh hung off it, which it leaves be.
func _piece(holder: Node3D) -> StillInstances:
	var art := Node3D.new()
	holder.add_child(art)
	var meshes: Array[MeshInstance3D] = []
	for index in LOOSE + 1:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		art.add_child(mesh)
		meshes.append(mesh)
	meshes[LOOSE].position = Vector3(1.0, 0.0, 0.0)
	var still := StillInstances.new()
	art.add_child(still)
	still.take(meshes)
	return still


## A frame drawn: each placed as RenderingServer.frame_pre_draw has them, which a headless
## run never emits.
func _drawn(stills: Array[StillInstances]) -> void:
	for still: StillInstances in stills:
		still.drawing()


func test_each_piece_s_still_instances_follow_that_piece_after_the_break() -> void:
	var holders: Array[Node3D] = []
	var stills: Array[StillInstances] = []
	for piece in 2:
		var holder := Node3D.new()
		add_child_autofree(holder)
		holders.append(holder)
		stills.append(_piece(holder))
	for still: StillInstances in stills:
		assert_eq(still.held().size(), LOOSE, "it holds the meshes hung as the identity")
		for mesh: MeshInstance3D in still.held():
			assert_true(mesh.top_level, "each stands apart from her")
			assert_eq(mesh.transform, Transform3D.IDENTITY, "and keeps its own hanging")
		var off := still.get_parent().get_child(LOOSE) as MeshInstance3D
		assert_false(off.top_level, "one hung off it follows her as a node")
	# She has broken: her two pieces part, each its own way.
	for frame in 4:
		holders[0].transform = Transform3D(Basis(Vector3.RIGHT, 0.1 * frame), Vector3(0, -frame, 0))
		holders[1].transform = Transform3D(Basis(Vector3.FORWARD, -0.2 * frame), Vector3(40, 0, 0))
		_drawn(stills)
		for piece in 2:
			var art := stills[piece].get_parent() as Node3D
			assert_eq(
				stills[piece].placed(), art.global_transform, "piece %d where it stands" % piece
			)
	# A stretch hung anew on the other piece is placed again where that piece stands.
	var art := stills[0].get_parent() as Node3D
	art.reparent(holders[1], false)
	assert_true(is_nan(stills[0].placed().origin.x), "hung anew, to be placed again")
	_drawn(stills)
	assert_eq(stills[0].placed(), holders[1].global_transform, "where its new piece stands")


func test_the_extension_and_the_gdscript_place_them_alike() -> void:
	if not _loaded():
		return
	var holder := Node3D.new()
	add_child_autofree(holder)
	var still := _piece(holder)
	var at := Transform3D(Basis(Vector3.UP, 0.7), Vector3(3.0, -2.0, 1.5))
	still.place(at, false)
	assert_eq(still.placed(), at, "the GDScript placed them")
	var native: Object = ClassDB.instantiate(&"NativeStill")
	var rids: Array[RID] = []
	for mesh: MeshInstance3D in still.held():
		rids.append(mesh.get_instance())
	native.call(&"hold", rids)
	assert_eq(native.call(&"size"), LOOSE, "the extension holds each")
	native.call(&"place", at)
	still.place(at * at)
	assert_eq(still.placed(), at * at, "the extension placed them")
