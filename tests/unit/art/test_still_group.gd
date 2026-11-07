extends GutTest
## Her lamps' globes and her signs' letters stand apart from her (StillGroup, #410): each
## is top level, so her moving reaches none, and is placed just before each frame is drawn
## where Godot would have drawn it as a node — the node it hangs under, times its own
## transform, to the bit. The extension and the GDScript place them alike.

const LAMPS := 6
const SIGNS := 5
const FRAMES := 12


## Whether the extension is loaded: a failure where CI requires it, pending elsewhere.
func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeStill"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false


## Her moving as a piece does, frame [param frame] of a turn and a lurch.
static func _moved(frame: int) -> Transform3D:
	var turn := Basis(Vector3(0.3, 1.0, -0.2).normalized(), 0.37 + 0.013 * frame)
	return Transform3D(turn, Vector3(12.5 + 0.7 * frame, -3.25 - 0.11 * frame, 7.0))


## A frame of her under [param ship], off the identity as a dressing's node may stand.
static func _frame_under(ship: Node3D) -> Node3D:
	var frame := Node3D.new()
	frame.transform = Transform3D(Basis(Vector3.UP, 0.21), Vector3(0.5, 1.25, -2.0))
	ship.add_child(frame)
	return frame


## Labels hung under [param under] where signs hang, off the identity each.
static func _letters(under: Node3D) -> Array[GeometryInstance3D]:
	var made: Array[GeometryInstance3D] = []
	for index in SIGNS:
		var label := Label3D.new()
		label.text = "Sign %d" % index
		label.basis = Basis.looking_at(Vector3(sin(index), 0.0, cos(index)))
		label.position = Vector3(index * 3.1, 2.2, -index * 0.7)
		under.add_child(label)
		made.append(label)
	return made


func test_held_instances_are_placed_where_godot_draws_them_as_nodes() -> void:
	# Two ships moved alike: on one the letters are held, on the other they stay nodes.
	var ships: Array[Node3D] = []
	var letters: Array = []
	var still := StillInstances.new()
	for side in 2:
		var ship := Node3D.new()
		add_child_autofree(ship)
		ships.append(ship)
		letters.append(_letters(_frame_under(ship)))
	ships[0].add_child(still)
	var group := still.group(letters[0][0].get_parent())
	for label: GeometryInstance3D in letters[0]:
		var own := label.transform
		group.hold(label)
		assert_true(label.top_level, "held, it stands apart from her")
		assert_eq(label.transform, own, "and keeps its own hanging")
	group.hold(letters[0][0])
	assert_eq(group.held().size(), SIGNS, "held twice is held once")
	var mismatches: Array[String] = []
	for frame in FRAMES:
		for ship: Node3D in ships:
			ship.transform = _moved(frame)
		still.drawing()
		for index in SIGNS:
			var node: Transform3D = letters[1][index].global_transform
			if var_to_bytes(group.placed_of(index)) != var_to_bytes(node):
				mismatches.append("frame %d sign %d" % [frame, index])
			assert_eq(
				letters[0][index].global_transform,
				letters[0][index].transform,
				"her moving never reaches one held"
			)
	assert_eq(mismatches.size(), 0, "placed where the node is drawn: %s" % ", ".join(mismatches))
	# Let go, it follows her as a node again, where it hung.
	group.release(letters[0][2])
	assert_false(letters[0][2].top_level, "let go, it follows her again")
	assert_eq(
		var_to_bytes(letters[0][2].global_transform),
		var_to_bytes(letters[1][2].global_transform),
		"hung as it was"
	)
	assert_eq(group.held().size(), SIGNS - 1, "and is no longer placed")


func test_a_group_is_placed_again_after_its_art_is_hung_anew() -> void:
	var ship := Node3D.new()
	add_child_autofree(ship)
	var still := StillInstances.new()
	ship.add_child(still)
	var group := still.group(_frame_under(ship))
	still.drawing()
	assert_false(is_nan(group.placed().origin.x), "placed")
	ship.remove_child(still)
	ship.add_child(still)
	assert_true(is_nan(group.placed().origin.x), "hung anew, to be placed again")
	group.place()
	group.unplace()
	assert_true(is_nan(group.placed().origin.x), "unplaced, to be placed again")


func test_the_signs_drawn_near_the_eye_are_held_and_those_further_let_go() -> void:
	var ship := Node3D.new()
	add_child_autofree(ship)
	var still := StillInstances.new()
	ship.add_child(still)
	var labels: Array[Label3D] = []
	for index in SIGNS:
		var label := Label3D.new()
		label.position = Vector3(index * 20.0, 2.0, 0.0)
		labels.append(label)
	var pool := SignPool.new()
	ship.add_child(pool)
	pool.take(labels, still)
	pool.show_near(Vector3.ZERO)
	var group: StillGroup = still.groups()[0]
	assert_eq(group.frame, pool, "the pool's letters hang under it")
	assert_eq(pool.drawn(), 2, "the signs within reach are drawn")
	assert_eq(group.held().size(), 2, "and held")
	for label: Label3D in group.held():
		assert_true(label.top_level and label.get_parent() == pool, "drawn apart from her")
	pool.show_near(Vector3(80.0, 2.0, 0.0))
	assert_eq(group.held().size(), 2, "the near ones held")
	assert_true(labels[3] in group.held() and labels[4] in group.held(), "and only they")
	assert_false(labels[0].top_level, "one out of reach is let go")
	assert_eq(labels[0].transform, Transform3D(Basis(), Vector3(0.0, 2.0, 0.0)), "as it hung")


func test_her_lamps_globes_are_held() -> void:
	var ship := Node3D.new()
	add_child_autofree(ship)
	var still := StillInstances.new()
	ship.add_child(still)
	var hung: Array[ShipLamp] = []
	var brass := StandardMaterial3D.new()
	for index in LAMPS:
		var lamp := ShipLamp.new()
		lamp.position = Vector3(index * 7.5, 2.0, index * 0.25)
		ship.add_child(lamp)
		var glass := StandardMaterial3D.new()
		glass.emission_enabled = true
		var kind := ShipLamp.Kind.PENDANT if index % 2 == 0 else ShipLamp.Kind.CARGO
		lamp.setup(index * 1.7, glass, brass, kind)
		lamp.set_process(false)
		hung.append(lamp)
	var globes := LampGlobes.new()
	ship.add_child(globes)
	globes.take(hung, still)
	var cells: Array[GeometryInstance3D] = []
	for child: Node in globes.get_children():
		cells.append(child as GeometryInstance3D)
	assert_gt(cells.size(), 1, "her lamps are drawn by cells")
	assert_eq(still.groups()[0].held(), cells, "every cell held")
	ship.transform = _moved(3)
	still.drawing()
	for index in cells.size():
		assert_eq(
			still.groups()[0].placed_of(index),
			globes.global_transform * cells[index].transform,
			"cell %d where the globes stand" % index
		)


func test_the_extension_and_the_gdscript_place_them_alike() -> void:
	if not _loaded():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 410
	var rids: Array[RID] = []
	var locals: Array[Transform3D] = []
	var instances: Array[RID] = []
	for index in 64:
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var own := Transform3D(
			Basis(axis.normalized(), rng.randf_range(-PI, PI)).scaled(Vector3.ONE * 1.3),
			Vector3(rng.randf_range(-90, 90), rng.randf_range(-20, 20), rng.randf_range(-30, 30))
		)
		locals.append(own)
		var instance := RenderingServer.instance_create()
		instances.append(instance)
		rids.append(instance)
	var native: Object = ClassDB.instantiate(&"NativeStill")
	native.call(&"hold_each", rids, locals)
	assert_eq(native.call(&"size"), locals.size(), "the extension holds each")
	var mismatches := 0
	for frame in FRAMES:
		var at := _moved(frame) * Transform3D(Basis(Vector3.FORWARD, rng.randf()), Vector3.ZERO)
		var placed: Array = native.call(&"placed", at)
		native.call(&"place", at)
		for index in locals.size():
			if var_to_bytes(placed[index]) != var_to_bytes(at * locals[index]):
				mismatches += 1
	assert_eq(mismatches, 0, "the extension places each as the GDScript multiplies it")
	native.call(&"hold", rids)
	var whole: Array = native.call(&"placed", _moved(1))
	assert_eq(whole[0], _moved(1), "held whole, each stands where it is told")
	for instance: RID in instances:
		RenderingServer.free_rid(instance)
