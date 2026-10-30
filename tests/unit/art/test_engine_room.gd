extends GutTest
## An engine room's machinery (EngineRoom) keeps out of the space a body fills: no main
## steam pipe runs where a body climbing a stair stands — on the barque, the ferry and
## the tug one ran under the deckhead straight over the stair down — and over an engine
## a body could stand on, as the freighter's, nothing stands between a step over its
## top and a body's height: its cylinders stand no higher than a step, and no steam pipe
## comes down into it.

## How far into a body a fitting may stand: a wall fitting's depth, as art-lint allows
## (tools/furnishing_check.gd).
const TOLERANCE := 0.12
## How far apart across a stair the bodies tried stand.
const GRID := 0.1

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


func test_no_steam_pipe_runs_where_a_body_climbing_a_stair_stands() -> void:
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		var engine_room := EngineRoom.new(ShipSpace.new(layout))
		for room: ShipRoom in layout.rooms:
			for route: Array in engine_room.steam_routes(room):
				for index in route.size() - 1:
					var from: Vector3 = route[index]
					var to: Vector3 = route[index + 1]
					var body := _body_reaching(layout, from, to)
					var named := (
						"%s's steam pipe %s-%s, a body on a stair at %s" % [ship, from, to, body]
					)
					assert_eq(body, Vector3.INF, named)


func test_only_the_pipes_over_the_barque_ferry_and_tug_stairs_go() -> void:
	var lost := {&"barque": 1, &"ferry": 1, &"tug": 1, &"trawler": 0, &"freighter": 0}
	for ship: StringName in lost:
		var layout := Fleet.layout(ship)
		var stairless: ShipLayout = layout.duplicate()
		stairless.ramps = []
		var named := "%s's main steam pipes" % ship
		assert_eq(_routes(layout), _routes(stairless) - lost[ship], named)


## How many main steam pipes [param layout]'s engine rooms run (EngineRoom.steam_routes).
func _routes(layout: ShipLayout) -> int:
	var engine_room := EngineRoom.new(ShipSpace.new(layout))
	var routes := 0
	for room: ShipRoom in layout.rooms:
		routes += engine_room.steam_routes(room).size()
	return routes


func test_nothing_stands_in_a_body_on_an_engine_it_could_stand_on() -> void:
	var stood_on := 0
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		var space := ShipSpace.new(layout)
		for room: ShipRoom in layout.rooms:
			var engines := space.machinery(room)
			# Only an engine room's are EngineRoom's: a steering gear's are LowerSpaces'.
			if engines.is_empty() or RoomDressing.kind_of(space, room) != RoomDressing.Kind.ENGINE:
				continue
			var faces := _drawn(space, room)
			for engine: ShipBlocker in engines:
				if not _room_over(layout, engine):
					continue
				stood_on += 1
				var low := engine.top + _rules.step_height
				var high := engine.top + _rules.body_height
				for corner: Vector3 in faces:
					var over := engine.area.has_point(Vector2(corner.x, corner.z))
					var named := "%s's %s: drawn at %s over its engine" % [ship, room.name, corner]
					assert_false(over and corner.y > low and corner.y < high, named)
	assert_gt(stood_on, 0, "an engine a body could stand on: the freighter's")


## Where a body of the rules standing on a stair of [param layout] stands more than
## TOLERANCE into a pipe from [param from] to [param to]: its feet, or Vector3.INF.
func _body_reaching(layout: ShipLayout, from: Vector3, to: Vector3) -> Vector3:
	var reach := _rules.body_radius - TOLERANCE + EngineRoom.STEAM_PIPE
	var plan_from := Vector2(from.x, from.z)
	var plan_to := Vector2(to.x, to.z)
	for ramp: ShipRamp in layout.ramps:
		var steps := Vector2i((ramp.area.size / GRID).ceil())
		for i in steps.x + 1:
			for j in steps.y + 1:
				var at := ramp.area.position + ramp.area.size * Vector2(i, j) / Vector2(steps)
				var nearest := Geometry2D.get_closest_point_to_segment(at, plan_from, plan_to)
				if nearest.distance_to(at) > reach:
					continue
				var feet := ramp.height_at(at.x, at.y)
				var pipe_low := minf(from.y, to.y) - EngineRoom.STEAM_PIPE
				var pipe_high := maxf(from.y, to.y) + EngineRoom.STEAM_PIPE
				if pipe_high > feet + _rules.step_height and pipe_low < feet + _rules.body_height:
					return Vector3(at.x, feet, at.y)
	return Vector3.INF


## Whether a body of the rules fits over [param engine]'s top: the deck over it stands
## its height over the top or more.
func _room_over(layout: ShipLayout, engine: ShipBlocker) -> bool:
	var middle := engine.area.get_center()
	var deck := INF
	for platform: ShipPlatform in layout.platforms:
		if platform.height > engine.top and platform.contains(middle.x, middle.y):
			deck = minf(deck, platform.height)
	return deck != INF and deck - engine.top >= _rules.body_height


## Every face of [param room]'s machinery as EngineRoom.build draws it.
func _drawn(space: ShipSpace, room: ShipRoom) -> PackedVector3Array:
	var lines: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, lines)
	EngineRoom.new(space).build(mesh, room)
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
