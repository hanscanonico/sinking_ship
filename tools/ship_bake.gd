extends SceneTree
## A ship drawn as a scene of marked pieces, baked into the ShipLayout the sim reads
## (SH17, D6) — ShipSceneBake reads the scene, and holds its vocabulary. Headless.
##
##   make bake-ship SCENE=authoring/NAME/NAME.tscn OUT=data/ships/NAME.tres
##       the scene baked, her layout and structure linted (ShipLayout.problems) and
##       saved as OUT
##   make bake-check
##       every authoring/NAME/NAME.tscn baked and held to data/ships/NAME.tres field for
##       field, every difference printed and the exit non-zero on any
##   make ship-scene SHIP=NAME
##       data/ships/NAME.tres drawn as authoring/NAME/NAME.tscn (ShipSceneDraw)
##
##   godot --headless --path . -s res://tools/ship_bake.gd -- --scene=… --out=…
##   godot --headless --path . -s res://tools/ship_bake.gd -- --scene=… --check=…
##   godot --headless --path . -s res://tools/ship_bake.gd -- --draw=… --scene=…


func _initialize() -> void:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		args[arg.get_slice("=", 0).trim_prefix("--")] = _res(arg.get_slice("=", 1))
	var scene: String = args.get("scene", "")
	if args.has("draw"):
		quit(_draw(args["draw"], scene))
	elif not ResourceLoader.exists(scene, "PackedScene"):
		printerr("bake: no scene at %s" % scene)
		quit(1)
	elif args.has("check"):
		quit(_check(scene, args["check"]))
	elif args.has("out"):
		quit(_bake(scene, args["out"]))
	else:
		printerr("bake: --out=<ship.tres> or --check=<ship.tres> is needed")
		quit(1)


static func _res(path: String) -> String:
	return path if path.is_empty() or path.begins_with("res://") else "res://" + path


func _bake(scene: String, out: String) -> int:
	var baked := ShipSceneBake.of_scene(scene)
	var layout := baked.layout
	var problems := baked.problems
	if problems.is_empty():
		problems = layout.problems(layout.max_seats)
	if not problems.is_empty():
		printerr("\n".join(problems))
		return 1
	var saved := ResourceSaver.save(layout, out)
	if saved != OK:
		printerr("bake: could not save %s: %s" % [out, error_string(saved)])
		return 1
	print("bake: %s → %s · %s" % [scene, out, _counts(layout)])
	return 0


func _check(scene: String, wanted_path: String) -> int:
	var wanted := load(wanted_path) as ShipLayout
	if wanted == null:
		printerr("bake-check: no ship at %s" % wanted_path)
		return 1
	var baked := ShipSceneBake.of_scene(scene)
	var found := baked.problems
	found.append_array(ShipSceneBake.differences(baked.layout, wanted, "ship"))
	if not found.is_empty():
		printerr("\n".join(found))
		printerr(
			(
				"bake-check: %s does not bake to %s — %d difference(s)"
				% [scene, wanted_path, found.size()]
			)
		)
		return 1
	print("bake-check: %s bakes to %s field for field · %s" % [scene, wanted_path, _counts(wanted)])
	return 0


func _draw(ship: String, scene: String) -> int:
	var layout := load(ship) as ShipLayout
	if layout == null or scene.is_empty():
		printerr("bake: no ship at %s, or no --scene= to draw her as" % ship)
		return 1
	var root := ShipSceneDraw.scene(layout, ship.get_file().get_basename())
	var packed := PackedScene.new()
	var status := packed.pack(root)
	root.free()
	if status == OK:
		DirAccess.make_dir_recursive_absolute(scene.get_base_dir())
		status = ResourceSaver.save(packed, scene)
	if status != OK:
		printerr("bake: could not draw %s as %s: %s" % [ship, scene, error_string(status)])
		return 1
	print("bake: %s drawn as %s · %s" % [ship, scene, _counts(layout)])
	return 0


static func _counts(layout: ShipLayout) -> String:
	var told := (
		"%d platforms, %d ramps, %d blockers, %d railings, %d ladders, %d spawns, %d props, %d rooms"
		% [
			layout.platforms.size(),
			layout.ramps.size(),
			layout.blockers.size(),
			layout.railings.size(),
			layout.ladders.size(),
			layout.spawns.size(),
			layout.props.size(),
			layout.rooms.size(),
		]
	)
	var structure := layout.structure
	if structure != null:
		told += (
			"; %d sections, %d cells, %d walls, %d openings, %d masses, %d fittings"
			% [
				structure.sections.size(),
				structure.cells.size(),
				structure.walls.size(),
				structure.openings.size(),
				structure.mass.size(),
				structure.fittings.size(),
			]
		)
	return told
