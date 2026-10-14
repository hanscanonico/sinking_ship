class_name EngineRoom
extends RefCounted
## An engine room's machinery (RoomDressing), placed by rules on the layout: an
## engine filling the footprint of each block the rules hold every body out of, the
## boilers set in the room's forward bulkhead with their fires (ShipLamp) glowing in
## their furnaces, the main steam pipes from them overhead into the engine, pipes
## along the hull sides over head height, and a gauge board and fire buckets on the
## after bulkhead; and where the room's lamps hang, over the lanes beside the engine.

## A boiler: its front's radius at most, its foot and its furnace's mouth over the
## floor; the main steam pipe's radius, and how far outside the engine's footprint
## it runs.
const BOILER_RADIUS := 1.0
## The least a boiler's front's radius is drawn, in metres: under a stokehold's gallery
## (#74) the deckhead leaves little more.
const BOILER_LEAST := 0.5
## The boiler fronts modelled, largest first, [radius, model]: a boiler is drawn the
## largest one its room has space for, never a model scaled. BOILER_RADIUS heads it and
## BOILER_LEAST ends it.
const BOILER_FRONTS: Array[Array] = [
	[1.0, "boiler_100"], [0.85, "boiler_85"], [0.65, "boiler_65"], [0.5, "boiler_50"]
]
const BOILER_FOOT := 0.2
const FURNACE_HEIGHT := 0.62
const STEAM_PIPE := 0.07
const PIPE_OFFSET := 0.25
## Boilers stand side by side along a bulkhead this far apart at least, past their
## fronts' full breadth.
const BOILER_GAP := 0.6
## The pipes along the hull sides run this high over the floor, and this far under any
## deck over them at least.
const SIDE_PIPE := 2.1
const SIDE_PIPE_CLEAR := 0.04
## A stair this near a hull side breaks the pipe along it: a body on it reaches there.
const STAIR_REACH := 0.8
## An engine: its bedplate, its crankcase's and its columns' tops over the floor, and
## its cylinders' lagging, as tall as the deckhead lets them stand, up to LAGGING;
## the cylinders' radii, high to low pressure, as shares of the largest.
const BEDPLATE := 0.14
const CRANKCASE := 0.6
const COLUMNS := 1.25
const LAGGING := 0.35
const CYLINDER_SCALE: Array[float] = [0.72, 0.86, 1.0]
## How far in from its footprint the engine's open columns stand back.
const RECESS := 0.045

var _space: ShipSpace
var _layout: ShipLayout


func _init(space: ShipSpace) -> void:
	_space = space
	_layout = space.layout


## The lights an engine room [param room] is lit by: a pendant over each lane beside
## its engine and a fire in each boiler.
func lights(room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	for lane: Vector2 in _lanes(room):
		var hang := RoomDressing.under_ceiling(_space, room, lane)
		found.append(RoomDressing.Light.new(hang, ShipLamp.Kind.PENDANT))
	for boiler: Array in _boilers(room):
		var wall: RoomDressing.Wall = boiler[0]
		var fire := wall.at(boiler[1], FURNACE_HEIGHT)
		found.append(RoomDressing.Light.new(fire, ShipLamp.Kind.FIRE, wall.normal))
	return found


## An engine standing in [param blocker]'s footprint, which the rules hold every body
## out of, from its bottom to [param top] and over it up to the deckhead, where no
## body can stand: an inverted triple-expansion engine — a bedplate, a crankcase with
## inspection doors, columns round its four faces with bright piston rods and
## crossheads between them, a cylinder block with a gauge board, a starting wheel
## and a reversing lever on its after face — and over it three cylinders, high,
## intermediate and low pressure, in teak lagging under steel covers, with their valve
## chests. Its faces stand within RECESS of the footprint's, where art-lint looks.
func _machinery(mesh: ShipMesh, blocker: ShipBlocker, top: float) -> void:
	var area := blocker.area
	var foot := blocker.bottom
	var case_top := minf(foot + CRANKCASE, top - 0.6)
	var columns_top := minf(foot + COLUMNS, top - 0.25)
	RoomDressing.block(
		mesh, area.grow(0.03), foot, foot + BEDPLATE, ShipPaints.steel, ShipMesh.RIM_ALL
	)
	RoomDressing.block(mesh, area, foot + BEDPLATE, case_top, ShipPaints.machine, ShipMesh.RIM_ALL)
	RoomDressing.block(
		mesh, area.grow(-RECESS), case_top, columns_top, ShipPaints.machine, ShipMesh.RIM_ALL
	)
	RoomDressing.block(mesh, area, columns_top, top, ShipPaints.engine, ShipMesh.RIM_ALL)
	RoomDressing.block(mesh, area.grow(0.015), case_top - 0.03, case_top, ShipPaints.bright_steel)
	RoomDressing.block(mesh, area.grow(0.02), top - 0.08, top, ShipPaints.brass)
	var along_x := area.size.x >= area.size.y
	var long := area.size.x if along_x else area.size.y
	var short := area.size.y if along_x else area.size.x
	var cylinders := 3 if long >= 2.0 else 1
	var pitch := long / cylinders
	var head := (case_top + columns_top) * 0.5
	for side in 4:
		var out := ShipSpace.outward(side)
		var normal := Vector3(out.x, 0.0, out.y)
		var right := normal.cross(Vector3.UP)
		var middle := area.get_center() + out * (area.size * 0.5).dot(out.abs())
		var width := absf((area.size * 0.5).dot(Vector2(out.y, out.x)))
		var bays := cylinders if (side % 2 == 1) != along_x else 2
		for post in bays + 1:
			var at := middle + Vector2(right.x, right.z) * width * (2.0 * post / bays - 1.0)
			var column := Rect2(at - Vector2.ONE * 0.07, Vector2.ONE * 0.14).intersection(area)
			RoomDressing.block(mesh, column, case_top, columns_top, ShipPaints.engine)
		for bay in bays:
			var along := width * (2.0 * (bay + 0.5) / bays - 1.0)
			var face := middle + Vector2(right.x, right.z) * along
			var door := Vector3(face.x, (foot + BEDPLATE + case_top) * 0.5, face.y)
			var half := Vector2(0.15, (case_top - foot) * 0.3)
			_inspection_door(mesh, door, normal, half)
			var rod := face - out * 0.027
			var shaft := Rect2(rod - Vector2.ONE * 0.016, Vector2.ONE * 0.032)
			RoomDressing.block(mesh, shaft, case_top, columns_top, ShipPaints.bright_steel)
			var crosshead := Rect2(rod - Vector2.ONE * 0.025, Vector2.ONE * 0.05)
			RoomDressing.block(mesh, crosshead, head - 0.06, head + 0.06, ShipPaints.bright_steel)
	_controls(mesh, area, along_x, columns_top, top)
	var lagging := _lagging(area, top)
	for index in cylinders:
		var centre := _engine_point(area, along_x, pitch * (index + 0.5), 0.0)
		var scale := CYLINDER_SCALE[index % CYLINDER_SCALE.size()]
		var radius := minf(pitch * 0.45, short * 0.3) * scale
		mesh.cylinder(centre, radius, top, top + lagging, 10, ShipPaints.teak, false)
		var band := top + lagging * 0.5
		var hoop := ShipPaints.brass
		mesh.cylinder(centre, radius + 0.012, band - 0.015, band + 0.015, 10, hoop, false)
		var cover := top + lagging
		mesh.cylinder(centre, radius + 0.035, cover, cover + 0.05, 10, ShipPaints.bright_steel)
		var chest := _engine_point(area, along_x, pitch * (index + 0.5), short * 0.32)
		var chest_box := Rect2(chest - Vector2.ONE * 0.13, Vector2.ONE * 0.26)
		RoomDressing.block(mesh, chest_box, top, top + lagging * 0.85, ShipPaints.engine)
	var inlet := _steam_inlet(blocker, top)
	if not is_nan(inlet.y):
		var cover := Vector3(inlet.x, top + lagging + 0.05, inlet.z)
		RoomDressing.pipe(mesh, cover, inlet, STEAM_PIPE)
		RoomDressing.flange(mesh, cover + Vector3.UP * 0.03, Vector3.UP, STEAM_PIPE)


## Where the steam pipe from the boilers comes down into [param blocker]'s engine,
## standing [param top] high: over its first cylinder, under the deckhead's beams;
## NAN height when no deck stands over it.
func _steam_inlet(blocker: ShipBlocker, top: float) -> Vector3:
	var area := blocker.area
	var along_x := area.size.x >= area.size.y
	var long := area.size.x if along_x else area.size.y
	var pitch := long / (3 if long >= 2.0 else 1)
	var at := _engine_point(area, along_x, pitch * 0.5, 0.0)
	return Vector3(at.x, _pipe_height(at, top), at.y)


## The height of the cylinders' lagging over [param area]'s engine standing
## [param top] high: LAGGING, or less under a low deckhead.
func _lagging(area: Rect2, top: float) -> float:
	var room := _pipe_height(area.get_center(), top)
	if is_nan(room):
		return LAGGING
	return clampf(room - STEAM_PIPE - 0.17 - top, 0.1, LAGGING)


## The height steam pipes run at over ship point [param at], under the beams of the
## lowest deck over [param above]; NAN when no deck stands over it.
func _pipe_height(at: Vector2, above: float) -> float:
	var deck := INF
	for platform: ShipPlatform in _layout.platforms:
		if platform.height > above and platform.contains(at.x, at.y):
			deck = minf(deck, platform.height)
	if deck == INF:
		return NAN
	return deck - ShipArt.PLANK - ShipArt.BEAM_DEPTH - STEAM_PIPE - 0.03


## The ship-plane point [param along] [param area]'s long axis and [param across] its
## middle line.
static func _engine_point(area: Rect2, along_x: bool, along: float, across: float) -> Vector2:
	var middle := area.get_center()
	if along_x:
		return Vector2(area.position.x + along, middle.y + across)
	return Vector2(middle.x + across, area.position.y + along)


## An inspection door on an engine's crankcase centred on [param middle] facing
## [param normal], [param half] its size: a plate with a brass-rimmed lid, a handle.
func _inspection_door(mesh: ShipMesh, middle: Vector3, normal: Vector3, half: Vector2) -> void:
	var right := normal.cross(Vector3.UP)
	RoomDressing.panel(mesh, middle + normal * 0.012, right, half, normal, ShipPaints.engine)
	RoomDressing.ring(mesh, middle + normal * 0.016, normal, 0.06, 0.085, ShipPaints.brass, 8)
	var handle := middle + normal * 0.03 + Vector3.UP * (half.y - 0.04)
	var turn := Basis(right, Vector3.UP, normal)
	mesh.turned_box(Transform3D(turn, handle), Vector3(0.14, 0.025, 0.025), ShipPaints.brass, 0)


## The controls on [param area]'s after face, where its driver stands: a gauge board
## of three brass-rimmed gauges on the cylinder block from [param low] to
## [param top], a starting wheel and a reversing lever under it.
func _controls(mesh: ShipMesh, area: Rect2, along_x: bool, low: float, top: float) -> void:
	var middle := area.get_center()
	var face := Vector3(area.position.x, 0.0, middle.y)
	var normal := Vector3.LEFT
	if not along_x:
		face = Vector3(middle.x, 0.0, area.position.y)
		normal = Vector3.FORWARD
	var right := normal.cross(Vector3.UP)
	var board := face + Vector3.UP * (low + top) * 0.5
	var half := Vector2(minf(0.5, area.size.length() * 0.18), minf(0.2, (top - low) * 0.4))
	RoomDressing.panel(mesh, board + normal * 0.015, right, half, normal, ShipPaints.dark)
	for index in 3:
		var gauge := board + right * (index - 1) * half.x * 0.62 + normal * 0.02
		RoomDressing.gauge(mesh, gauge, normal, minf(0.085, half.y * 0.8))
	var wheel := face + Vector3.UP * (low - 0.05) - right * half.x * 0.5 + normal * 0.05
	RoomDressing.wheel(mesh, wheel, normal, 0.15, 0.015, 5, ShipPaints.bright_steel)
	var lever := face + right * half.x * 0.6 + normal * 0.025
	var grip := lever + Vector3.UP * (low - 0.1)
	var foot := Vector3(lever.x, grip.y - 0.7, lever.z)
	mesh.beam(foot, grip, Vector2(0.03, 0.03), ShipPaints.bright_steel, 0)
	mesh.turned_box(Transform3D(Basis.IDENTITY, grip), Vector3.ONE * 0.05, ShipPaints.brass, 0)


## [param room]'s own: its engines (_machinery), the boilers in its forward bulkhead,
## their main steam pipes overhead aft along the engine's side into it, pipes along
## its hull sides over head height but over a stair climbing beside one, and on its
## after bulkhead a gauge board and fire buckets on a shelf.
func build(mesh: ShipMesh, room: ShipRoom) -> void:
	var machines := _space.machinery(room)
	for machine: ShipBlocker in machines:
		var top := machine.top - (ShipArt.PLANK if _space.deck_on(machine) else 0.0)
		_machinery(mesh, machine, top)
	for boiler: Array in _boilers(room):
		_boiler(mesh, boiler)
		if not machines.is_empty():
			_steam_pipe(mesh, boiler, machines[0])
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.length() < 1.0:
			continue
		if wall.outdoors_beyond():
			# Over head height, and under any gallery standing over the wall (#74) — none
			# where the gallery leaves no room for it over a head.
			var foot := wall.at(wall.middle(), 0.0)
			var under := _space.ceiling(room, foot.x, foot.z) - room.floor_height
			var height := minf(SIDE_PIPE, under - ShipArt.PLANK - SIDE_PIPE_CLEAR)
			if height < RoomDressing.HEADROOM:
				continue
			for run: Vector2 in _clear_of_stairs(wall, Vector2(wall.from + 0.05, wall.to - 0.05)):
				var from := wall.at(run.x, height, 0.08)
				RoomDressing.pipe(mesh, from, wall.at(run.y, height, 0.08), 0.05)
		elif wall.side == 3:
			var board := wall.at(wall.middle(), 1.45, 0.012)
			RoomDressing.panel(
				mesh, board, wall.right, Vector2(0.38, 0.24), wall.normal, ShipPaints.dark
			)
			for index in 2:
				var gauge := board + wall.right * (index - 0.5) * 0.36 + wall.normal * 0.01
				RoomDressing.gauge(mesh, gauge, wall.normal, 0.09)
			RoomDressing.fire_buckets(mesh, wall, wall.middle())


## The stretches of [param run] along [param wall] clear of every stair climbing
## within STAIR_REACH of it, where a body on the stair would stand in a pipe on it; none
## shorter than a pipe's worth.
func _clear_of_stairs(wall: RoomDressing.Wall, run: Vector2) -> Array[Vector2]:
	var runs: Array[Vector2] = [run]
	var near := wall.rect(wall.from, wall.to, 0.0, STAIR_REACH)
	for ramp: ShipRamp in _space.layout.ramps:
		if not ramp.area.intersects(near):
			continue
		var cut := Vector2(ramp.area.position.x, ramp.area.end.x)
		if wall.side % 2 == 1:
			cut = Vector2(ramp.area.position.y, ramp.area.end.y)
		var left: Array[Vector2] = []
		for stretch: Vector2 in runs:
			if cut.y <= stretch.x or cut.x >= stretch.y:
				left.append(stretch)
				continue
			if cut.x - stretch.x >= STAIR_REACH:
				left.append(Vector2(stretch.x, cut.x))
			if stretch.y - cut.y >= STAIR_REACH:
				left.append(Vector2(cut.y, stretch.y))
		runs = left
	return runs


## The main steam pipe from [param boiler]'s stop valve up under the beams, along its
## bulkhead to beside [param engine], aft along the engine's side and over into it — but
## for a boiler under a gallery (#74), whose pipe goes up behind its bulkhead, clear of
## the gallery and of any stair at its foot.
func _steam_pipe(mesh: ShipMesh, boiler: Array, engine: ShipBlocker) -> void:
	var wall: RoomDressing.Wall = boiler[0]
	var radius: float = boiler[2]
	var valve := wall.at(boiler[1], BOILER_FOOT + radius * 2.0 + 0.04, 0.16)
	var inlet := _steam_inlet(engine, engine.top)
	if is_nan(inlet.y) or _space.ceiling(wall.room, valve.x, valve.z) < inlet.y:
		return
	var beside := engine.area.grow(PIPE_OFFSET)
	var over := Vector3(valve.x, inlet.y, valve.z)
	var along := Vector3(clampf(valve.x, beside.position.x, beside.end.x), inlet.y, valve.z)
	if wall.side % 2 == 1:
		along = Vector3(valve.x, inlet.y, clampf(valve.z, beside.position.y, beside.end.y))
	var aft := Vector3(inlet.x, inlet.y, along.z)
	if wall.side % 2 == 0:
		aft = Vector3(along.x, inlet.y, inlet.z)
	var route: Array[Vector3] = [valve, over, along, aft, inlet]
	for index in route.size() - 1:
		RoomDressing.pipe(mesh, route[index], route[index + 1], STEAM_PIPE)
		if index > 0:
			RoomDressing.flange(
				mesh, route[index], (route[index + 1] - route[index]).normalized(), STEAM_PIPE
			)


## The middle of each lane beside [param room]'s machinery, across the room's long
## way: where its lamps hang.
func _lanes(room: ShipRoom) -> Array[Vector2]:
	var lanes: Array[Vector2] = []
	var machines := _space.machinery(room)
	if machines.is_empty():
		return lanes
	var area := room.area
	var engine := machines[0].area
	var middle := engine.get_center()
	var across_z := engine.position.y - area.position.y + area.end.y - engine.end.y
	var across_x := engine.position.x - area.position.x + area.end.x - engine.end.x
	if across_z >= across_x:
		lanes.append(Vector2(middle.x, (area.position.y + engine.position.y) * 0.5))
		lanes.append(Vector2(middle.x, (area.end.y + engine.end.y) * 0.5))
	else:
		lanes.append(Vector2((area.position.x + engine.position.x) * 0.5, middle.y))
		lanes.append(Vector2((area.end.x + engine.end.x) * 0.5, middle.y))
	return lanes


## The boilers set in [param room]'s forward bulkhead: per stretch of it long enough
## to hold one, as many as it holds side by side, [Wall, along it, radius] — on the
## floor its machinery stands on, never on the galleries over it (#74).
func _boilers(room: ShipRoom) -> Array[Array]:
	var found: Array[Array] = []
	if not _space.machinery_in(room):
		return found
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.side != 1:
			continue
		var at := wall.at(wall.middle(), 0.0)
		var height := _space.ceiling(room, at.x, at.z) - room.floor_height
		height -= ShipArt.PLANK + ShipArt.BEAM_DEPTH
		var radius := front_for(minf(wall.length() - 0.2, height - 0.3) * 0.5)
		if is_nan(radius):
			continue
		# As many side by side as the stretch holds at their full breadth: a stokehold's
		# bulkhead, unbroken by a door, holds two (#74).
		var count := maxi(1, floori((wall.length() - 0.2) / (BOILER_RADIUS * 2.0 + BOILER_GAP)))
		for index in count:
			found.append([wall, lerpf(wall.from, wall.to, (index + 0.5) / count), radius])
	return found


## The largest modelled boiler front's radius (BOILER_FRONTS) no more than
## [param room_for]; NAN when even the least is too large.
static func front_for(room_for: float) -> float:
	for front: Array in BOILER_FRONTS:
		if (front[0] as float) <= room_for + 0.0001:
			return front[0] as float
	return NAN


## A Scotch boiler's front, flat in its bulkhead, the model of its radius
## (BOILER_FRONTS): a black riveted shell ringed in steel, its furnaces — the middle one
## open round the fire's mouth (ShipLamp) behind its grate bars, a front of three
## furnaces' breadth shut doors either side — ashpits under them, stays across it, two
## water gauge glasses, a pressure gauge, and the steam stop valve on top of a front
## that stands it over head height.
func _boiler(mesh: ShipMesh, boiler: Array) -> void:
	var wall: RoomDressing.Wall = boiler[0]
	var radius: float = boiler[2]
	var model := ""
	for front: Array in BOILER_FRONTS:
		if is_equal_approx(front[0] as float, radius):
			model = front[1] as String
	var turn := Basis(Vector3.UP.cross(wall.normal), Vector3.UP, wall.normal)
	mesh.model(ShipModel.named(model), Transform3D(turn, wall.at(boiler[1], 0.0)))
