extends GutTest
## NativeSurfaces.blocked_all — every portal's line WalkGraph._shut asks about at once
## (WalkDoorLeaves.shut_all) — answers what Surfaces.blocked answers line by line in
## GDScript, on every ship, her doors open, and shut with a funnel down: so a walk graph
## shut by the batch shuts the portals asking one at a time shut. Where the extension is
## not loaded there is nothing to hold it to, and CI sets SINKING_NATIVE_REQUIRED, so a
## missing library there fails rather than passes.

const SHIPS: Array[ShipLayout] = [
	preload("res://data/ships/titanic.tres"),
	preload("res://data/ships/small_titanic.tres"),
	preload("res://data/ships/steamer.tres"),
	preload("res://data/ships/trawler.tres"),
	preload("res://data/ships/tug.tres"),
	preload("res://data/ships/barque.tres"),
]

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 216


func test_every_ship_blocks_natively_as_blocked_does() -> void:
	if not _loaded():
		return
	var rules := SimFixtures.rules()
	var step := rules.step_height
	for layout: ShipLayout in SHIPS:
		var native := Surfaces.new(layout)
		ContactsNative.off = true
		var reference := Surfaces.new(layout)
		ContactsNative.off = false
		assert_not_null(native.native, "the native Surfaces asks the extension")
		var leaves: WalkDoorLeaves = WalkGraph.new(layout, reference, rules)._door_leaves
		var lines := leaves.lines.duplicate()
		var portals := lines.size() / 2
		# Each portal's entry to another's exit too: lines through her walls, blocked.
		for index in portals:
			lines.append(leaves.lines[index * 2])
			lines.append(leaves.lines[(index * 7 + 1) % portals * 2 + 1])
		var ask := PackedByteArray()
		for index in lines.size() / 2:
			ask.append(1 if index % 5 != 0 else 0)
		for shut: bool in [false, true]:
			var pose := _pose(layout, shut)
			native.honour(pose)
			reference.honour(pose)
			var found: PackedByteArray = native.native.blocked_all(lines, ask, step * 2.0, step)
			var expected := PackedByteArray()
			for index in ask.size():
				var line_blocked := reference.blocked(
					lines[index * 2], lines[index * 2 + 1], step * 2.0, step
				)
				expected.append(1 if ask[index] == 1 and line_blocked else 0)
			var name := "%s, doors %s" % [layout.resource_path, "shut" if shut else "open"]
			assert_eq(found, expected, name)
			assert_gt(expected.count(1), 0, name + ": some line blocked")


func test_a_walk_graph_shuts_at_once_what_it_shuts_one_by_one() -> void:
	var rules := SimFixtures.rules()
	for layout: ShipLayout in [SHIPS[1], SHIPS[2]]:
		var pose := _pose(layout, true)
		var batched := WalkGraph.new(layout, Surfaces.new(layout), rules)
		ContactsNative.off = true
		var one_by_one := WalkGraph.new(layout, Surfaces.new(layout), rules)
		ContactsNative.off = false
		batched.surfaces().honour(pose)
		one_by_one.surfaces().honour(pose)
		batched._shut_every_portal(pose)
		var expected := PackedByteArray()
		for index in batched._portal_shut.size():
			expected.append(2 if one_by_one._shut(index, pose) else 1)
		assert_eq(batched._portal_shut, expected, layout.resource_path)
		assert_gt(expected.count(2), 0, layout.resource_path + ": some portal shut")


## [param layout] at rest, with her watertight doors shut and a funnel down where
## [param shut].
func _pose(layout: ShipLayout, shut: bool) -> ShipPose:
	var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	if not shut or layout.structure == null:
		return pose
	for opening: ShipOpening in layout.structure.openings:
		if opening.shuts_at_hit:
			pose.doors_shut[opening.name] = 1.0
	for fitting: ShipFitting in layout.structure.fittings:
		if fitting.kind == ShipFitting.Kind.FUNNEL:
			var way := Vector2.from_angle(_rng.randf_range(0.0, TAU))
			pose.felled.append(FunnelFall.new(fitting, way, 0, 0, 0))
			break
	return pose


## Whether the extension is loaded: a failure where CI requires it, pending elsewhere.
func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeSurfaces"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
