extends SceneTree
## `make art-lint`: the art aligns to the data, never the reverse (D6), and reads
## snapshots only (D5). Headless; run with --fixed-fps so match time advances one
## tick per two frames however fast the machine draws.
##
## - The ship (ShipArt), on every ship in data/ships: an upward face within
##   PLATFORM_TOLERANCE of each platform's height across its whole area; a face
##   within BLOCKER_TOLERANCE of every blocker's sides, its top, and a lintel's
##   underside; and over every ramp a stair whose top stands within half a riser
##   (ShipArt.STEP_RISE) and PLATFORM_TOLERANCE of the ramp's height; and down
##   every boarding ladder's rung line, a top within LADDER_TOLERANCE of its
##   platform's height and a bottom at or under the waterline at rest.
## - Seats: through a bots-only match in the real match scene, every brawler's
##   model hangs from its body's feet — the posed ship carrying the interpolated
##   snapshot position — and the mannequin's soles stand on that root.
## - Cargo, through the same match: every crate is drawn at its underside as the
##   interpolated snapshot has it, and not at all once it is lost. And on every ship,
##   a crate set down where its cargo stands outdoors and in the middle of each room
##   is lit as it: a lamp may reach it, and it is as far indoors as where it stands.
## - The collapse: once a match's first collapse has fallen, nothing is drawn at a
##   collapsed platform's height wherever Surfaces, honouring that tick's pose, says
##   it is gone — the dressed deck lies wrecked below, as the rules have it.
## - Snapshots only: no script anywhere under scenes/art names a live sim object.

const RunMatch := preload("res://tools/run_match.gd")
const MATCH_SCENE := "res://scenes/match/match.tscn"
const SHIPS_DIR := "res://data/ships/"
const ART_DIR := "res://scenes/art/"
const SEED := 1701
const SEATS := 8
## A match the default scenario's collapse comes in before it ends.
const COLLAPSE_SEED := 1
## Match time the seat check watches, at most.
const SEAT_SECONDS := 90.0
const PLATFORM_TOLERANCE := 0.02
const BLOCKER_TOLERANCE := 0.05
const RAMP_TOLERANCE := ShipArt.STEP_RISE * 0.5 + PLATFORM_TOLERANCE
const LADDER_TOLERANCE := 0.05
const SEAT_TOLERANCE := 0.001
const CRATE_TOLERANCE := 0.001
const SOLE_TOLERANCE := 0.02
## How far in from a platform's edges the samples start, and how many per side.
const SAMPLE_INSET := 0.1
const SAMPLES_ALONG := 6
const SAMPLES_ACROSS := 3
## How far out of a blocker's face its side rays start, and the cylinder rays per
## height.
const SIDE_REACH := 0.3
const CYLINDER_RAYS := 8
## The side of the cells drawn triangles are filed under, in metres.
const CELL := 0.5
## What art may not name: the live match and the queries only rules make. Enum
## reads off PlayerState are allowed, a PlayerState itself is not.
const LIVE: PackedStringArray = [
	"MatchSim",
	"MatchState",
	"MatchRunner",
	"MatchHost",
	"MatchClient",
	"LoopbackMatch",
	"SimDriver",
	"InputSource",
	"BotView",
	"Surfaces",
	"SinkSchedule",
	"ShoveResolver",
]
const LIVE_PLAYER := "\\bPlayerState\\b(?!\\.(Body|Action|Cause)\\b)"

var _problems := PackedStringArray()
var _checks := 0


func _initialize() -> void:
	# The root joins the tree only once the main loop runs.
	await process_frame
	_check_snapshot_only()
	for file: String in DirAccess.get_files_at(SHIPS_DIR):
		if file.ends_with(".tres"):
			_check_ship(file, load(SHIPS_DIR + file))
	await _check_seats()
	await _check_collapse()
	if not _problems.is_empty():
		printerr("\n".join(_problems))
		printerr("art-lint: %d problem(s) in %d checks" % [_problems.size(), _checks])
		quit(1)
		return
	print("art-lint: %d checks OK" % _checks)
	quit()


func _check_snapshot_only() -> void:
	var live := RegEx.create_from_string("\\b(%s)\\b" % "|".join(LIVE))
	var live_player := RegEx.create_from_string(LIVE_PLAYER)
	for file: String in _scripts_under(ART_DIR):
		_checks += 1
		var lines := FileAccess.get_file_as_string(ART_DIR + file).split("\n")
		for index in lines.size():
			var code := lines[index].get_slice("#", 0)
			var found := live.search(code)
			if found == null:
				found = live_player.search(code)
			if found != null:
				_problems.append(
					(
						"art-lint: %s:%d names %s — art reads snapshots only (D5)"
						% [file, index + 1, found.get_string()]
					)
				)


## Every .gd under [param dir] and its subfolders, as paths relative to it.
func _scripts_under(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(file)
	for sub: String in DirAccess.get_directories_at(dir):
		for file: String in _scripts_under(dir + sub + "/"):
			found.append(sub + "/" + file)
	return found


## Each platform, blocker and ramp of [param layout] against the ship as drawn.
func _check_ship(file: String, layout: ShipLayout) -> void:
	var rules := RunMatch.default_config(SEED).rules
	var art := ShipArt.new()
	root.add_child(art)
	art.build(layout, rules.railing_height, rules.body_radius)
	var faces := _ship_faces(art)
	var cells := _file_faces(faces)
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		_check_tops(
			faces,
			cells,
			"%s platform %d" % [file, index],
			_samples(platform.area),
			func(_point: Vector2) -> float: return platform.height,
			PLATFORM_TOLERANCE
		)
	for index in layout.ramps.size():
		var ramp := layout.ramps[index]
		_check_tops(
			faces,
			cells,
			"%s ramp %d" % [file, index],
			_samples(ramp.area),
			func(point: Vector2) -> float: return ramp.height_at(point.x, point.y),
			RAMP_TOLERANCE
		)
	for index in layout.blockers.size():
		_check_blocker(
			faces, cells, "%s blocker %d" % [file, index], layout.blockers[index], layout
		)
	for index in layout.ladders.size():
		_check_ladder(faces, cells, "%s ladder %d" % [file, index], layout.ladders[index], layout)
	_check_crate_light(file, layout, art)
	art.free()


## [param art]'s first crate set down where [param layout]'s cargo first stands, then
## in the middle of each room: drawn off the outdoor layer, which no lamp lights, and
## with its paints wholly outdoors at the first spot when that stands outdoors and
## wholly indoors in a room.
func _check_crate_light(file: String, layout: ShipLayout, art: ShipArt) -> void:
	if layout.props.is_empty():
		return
	var prop := layout.props[0]
	var space := ShipSpace.new(layout)
	var spots: Array[Vector3] = [prop.pos]
	var wanted := PackedFloat64Array([0.0 if space.outdoors(prop.pos + Vector3.UP * 0.1) else 1.0])
	for room: ShipRoom in layout.rooms:
		var middle := room.area.get_center()
		spots.append(Vector3(middle.x, room.floor_height, middle.y))
		wanted.append(1.0)
	var crate := art.crates()[0]
	var unlit := 1 << (ShipMesh.OUTDOOR_LAYER - 1)
	for index in spots.size():
		crate.position = spots[index]
		art._process(0.0)
		for part: Node in crate.get_children():
			var drawn := part as MeshInstance3D
			var paint := drawn.mesh.surface_get_material(0) as ShaderMaterial
			var indoors: float = paint.get_shader_parameter("indoors")
			_checks += 1
			if drawn.layers & ~unlit == 0 or not is_equal_approx(indoors, wanted[index]):
				_problems.append(
					(
						"art-lint: %s crate at %s: %s on layers %d, %.2f indoors for %.0f"
						% [file, spots[index], drawn.name, drawn.layers, indoors, wanted[index]]
					)
				)


## Straight down the middle of [param ladder]'s rung line, ShipArt.LADDER_OUT
## outboard of its platform's edge: the highest face drawn there within
## LADDER_TOLERANCE of the deck, and the lowest at or under the waterline at rest —
## a swimmer finds it from the sea, and it leads all the way up.
func _check_ladder(
	faces: PackedVector3Array,
	cells: Dictionary,
	what: String,
	ladder: ShipLadder,
	layout: ShipLayout
) -> void:
	_checks += 1
	var platform := layout.platforms[ladder.platform]
	var outward := (ladder.to - ladder.from).normalized().orthogonal()
	if (platform.area.get_center() - ladder.from).dot(outward) > 0.0:
		outward = -outward
	var middle := (ladder.from + ladder.to) * 0.5 + outward * ShipArt.LADDER_OUT
	var top := _first_face(faces, cells, Vector3(middle.x, platform.height + 1.0, middle.y), -1.0)
	var bottom := _first_face(faces, cells, Vector3(middle.x, -100.0, middle.y), 1.0)
	if absf(top - platform.height) > LADDER_TOLERANCE:
		_problems.append(
			"art-lint: %s: drawn top %.1f cm off its deck" % [what, (top - platform.height) * 100.0]
		)
	if bottom > -layout.freeboard:
		_problems.append(
			"art-lint: %s: rungs stop %.2f m over the waterline" % [what, bottom + layout.freeboard]
		)


## The height of the first face drawn on the vertical line from [param from], going
## up when [param way] is 1 and down when it is -1; [param from]'s own height when
## nothing is.
func _first_face(faces: PackedVector3Array, cells: Dictionary, from: Vector3, way: float) -> float:
	var direction := Vector3.UP * way
	var nearest := INF
	for index: int in cells.get(Vector2i(floori(from.x / CELL), floori(from.z / CELL)), []):
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			from, direction, faces[index], faces[index + 1], faces[index + 2]
		)
		if hit != null:
			nearest = minf(nearest, ((hit as Vector3) - from).dot(direction))
	return from.y if nearest == INF else from.y + nearest * way


## Whether, straight above or below each of [param points], a drawn face lies within
## [param tolerance] of the height [param height_at] gives there.
func _check_tops(
	faces: PackedVector3Array,
	cells: Dictionary,
	what: String,
	points: PackedVector2Array,
	height_at: Callable,
	tolerance: float
) -> void:
	_checks += 1
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for point in points:
		var height: float = height_at.call(point)
		var off := _nearest_face(faces, cells, Vector3(point.x, height, point.y), Vector3.DOWN)
		if off > worst:
			worst = off
			worst_at = point
	if worst > tolerance:
		_problems.append(
			"art-lint: %s: drawn top %.1f cm off its height at %s" % [what, worst * 100.0, worst_at]
		)


## [param blocker]'s faces against the drawn ship: rays across each side at a spread
## of points, onto its top, and under a lintel; each probe is a point on a face and
## the way out of it.
func _check_blocker(
	faces: PackedVector3Array,
	cells: Dictionary,
	what: String,
	blocker: ShipBlocker,
	layout: ShipLayout
) -> void:
	_checks += 1
	var probes: Array[Array] = []
	var span := blocker.top - blocker.bottom
	var heights: Array[float] = [
		blocker.bottom + span * 0.25, blocker.bottom + span * 0.5, blocker.bottom + span * 0.75
	]
	if blocker.shape == ShipBlocker.Shape.CYLINDER:
		var centre := Vector3(blocker.centre.x, 0.0, blocker.centre.y)
		probes.append([Vector3(centre.x, blocker.top, centre.z), Vector3.UP])
		for ray in CYLINDER_RAYS:
			var out := Vector3.RIGHT.rotated(Vector3.UP, TAU * ray / CYLINDER_RAYS)
			for height in heights:
				probes.append([centre + out * blocker.radius + Vector3.UP * height, out])
	else:
		var area := blocker.area
		for point in _samples(area.grow(SAMPLE_INSET * 0.5)):
			probes.append([Vector3(point.x, blocker.top, point.y), Vector3.UP])
		var middle := area.get_center()
		var deck := -INF
		for platform: ShipPlatform in layout.platforms:
			if platform.height <= blocker.bottom and platform.contains(middle.x, middle.y):
				deck = maxf(deck, platform.height)
		if blocker.bottom > deck + 0.5:
			probes.append([Vector3(middle.x, blocker.bottom, middle.y), Vector3.DOWN])
		for fraction: float in [0.2, 0.5, 0.8]:
			var x := lerpf(area.position.x, area.end.x, fraction)
			var z := lerpf(area.position.y, area.end.y, fraction)
			for height in heights:
				probes.append([Vector3(x, height, area.position.y), Vector3.FORWARD])
				probes.append([Vector3(x, height, area.end.y), Vector3.BACK])
				probes.append([Vector3(area.position.x, height, z), Vector3.LEFT])
				probes.append([Vector3(area.end.x, height, z), Vector3.RIGHT])
	var worst := 0.0
	var worst_at := Vector3.ZERO
	for probe: Array in probes:
		var point: Vector3 = probe[0]
		var out: Vector3 = probe[1]
		var off := _nearest_face(faces, cells, point, -out)
		if off > worst:
			worst = off
			worst_at = point
	if worst > BLOCKER_TOLERANCE:
		_problems.append(
			"art-lint: %s: drawn face %.1f cm off its data at %s" % [what, worst * 100.0, worst_at]
		)


## Every triangle drawn under [param art], in its (ship) space.
func _ship_faces(art: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for node: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var to_ship := art.global_transform.affine_inverse() * mesh_instance.global_transform
		for corner: Vector3 in mesh_instance.mesh.get_faces():
			faces.append(to_ship * corner)
	return faces


## The triangles of [param faces], filed by the CELL-sized squares of the ship plane
## their bounds cover: Vector2i -> Array of first-corner indices (an Array, which a
## Dictionary holds by reference, where a packed array would be copied out).
func _file_faces(faces: PackedVector3Array) -> Dictionary:
	var cells := {}
	for index in range(0, faces.size(), 3):
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for corner in 3:
			var at := faces[index + corner]
			low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
			high = Vector2(maxf(high.x, at.x), maxf(high.y, at.z))
		for x in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
			for z in range(floori(low.y / CELL), floori(high.y / CELL) + 1):
				var cell := Vector2i(x, z)
				if not cells.has(cell):
					cells[cell] = []
				(cells[cell] as Array).append(index)
	return cells


func _samples(area: Rect2) -> PackedVector2Array:
	var inner := area.grow(-SAMPLE_INSET)
	var points := PackedVector2Array()
	for i in SAMPLES_ALONG:
		for j in SAMPLES_ACROSS:
			var along := float(i) / (SAMPLES_ALONG - 1)
			var across := float(j) / (SAMPLES_ACROSS - 1)
			points.append(inner.position + inner.size * Vector2(along, across))
	return points


## How far the drawn face nearest [param point] lies from it along the line through
## it in [param direction] (vertical, or across a side within SIDE_REACH); INF when
## nothing is drawn on that line at all.
func _nearest_face(
	faces: PackedVector3Array, cells: Dictionary, point: Vector3, direction: Vector3
) -> float:
	var reach := 100.0 if absf(direction.y) > 0.5 else SIDE_REACH
	var from := point - direction * reach
	var candidates := {}
	for at: Vector3 in [from, point, point + direction * reach]:
		var cell := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
		for index: int in cells.get(cell, []):
			candidates[index] = true
	var nearest := INF
	for index: int in candidates:
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			from, direction, faces[index], faces[index + 1], faces[index + 2]
		)
		if hit != null:
			var along := ((hit as Vector3) - from).dot(direction)
			if along <= reach * 2.0:
				nearest = minf(nearest, absf(along - reach))
	return nearest


func _check_seats() -> void:
	var scene: MatchScene = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	scene.start(RunMatch.default_config(SEED, SEATS), true, true)
	var driver: SimDriver = scene.get_node("SimDriver")
	var client := driver.client
	var ship: Node3D = scene.get_node("MatchView/Ship")
	var brawlers: Array[Brawler] = []
	for child: Node in ship.get_children():
		if child is Brawler:
			brawlers.append(child)
	_checks += 1
	if brawlers.size() != SEATS:
		_problems.append("art-lint: %d brawlers drawn for %d seats" % [brawlers.size(), SEATS])
	var crates: Array[Node3D] = (scene.get_node("MatchView/Ship/ShipArt") as ShipArt).crates()
	_checks += 1
	if crates.size() != client.config.ship.props.size():
		_problems.append(
			(
				"art-lint: %d crates drawn for %d props"
				% [crates.size(), client.config.ship.props.size()]
			)
		)
	var misses := {}
	var crates_moved := false
	while not client.is_over() and driver.current["tick"] < Ticks.from_seconds(SEAT_SECONDS):
		await process_frame
		crates_moved = _check_cargo(ship, driver, crates, misses) or crates_moved
		var seats_then: Array = driver.previous["seats"]
		var seats_now: Array = driver.current["seats"]
		for brawler: Brawler in brawlers:
			var then: Dictionary = seats_then[brawler.seat]
			var now: Dictionary = seats_now[brawler.seat]
			if now["out"]:
				continue
			var feet: Vector3 = (
				ship.global_transform * (then["pos"] as Vector3).lerp(now["pos"], driver.alpha)
			)
			var off := brawler.model_root().global_position.distance_to(feet)
			if off > SEAT_TOLERANCE and not misses.has(brawler.seat):
				misses[brawler.seat] = (
					"art-lint: seat %d's model hangs %.1f mm off its feet at tick %d"
					% [brawler.seat, off * 1000.0, driver.current["tick"]]
				)
	_checks += 1
	if not crates_moved:
		_problems.append("art-lint: no crate moved in %.0f s of seed %d" % [SEAT_SECONDS, SEED])
	for index in crates.size():
		_checks += 1
		if misses.has("crate %d" % index):
			_problems.append(misses["crate %d" % index])
	for brawler: Brawler in brawlers:
		_checks += 1
		if misses.has(brawler.seat):
			_problems.append(misses[brawler.seat])
		var sole := _sole(brawler.model_root())
		if absf(sole) > SOLE_TOLERANCE:
			_problems.append(
				(
					"art-lint: seat %d's soles stand %.1f cm off its model root"
					% [brawler.seat, sole * 100.0]
				)
			)
	scene.queue_free()


## Each of [param crates] against the snapshots [param driver] interpolates: drawn
## at its underside on the posed [param ship], or hidden once lost; the first miss
## per crate goes in [param misses]. True when any crate moved between the two.
func _check_cargo(
	ship: Node3D, driver: SimDriver, crates: Array[Node3D], misses: Dictionary
) -> bool:
	var moved := false
	for index in crates.size():
		var then: Dictionary = driver.previous["props"][index]
		var now: Dictionary = driver.current["props"][index]
		var key := "crate %d" % index
		var lost: bool = now["state"] == PropState.Body.LOST
		if crates[index].visible == lost and not misses.has(key):
			misses[key] = (
				"art-lint: %s %s at tick %d"
				% [
					key,
					"drawn though lost" if lost else "hidden though on board",
					driver.current["tick"]
				]
			)
		if lost:
			continue
		moved = moved or then["pos"] != now["pos"]
		var feet: Vector3 = (
			ship.global_transform * (then["pos"] as Vector3).lerp(now["pos"], driver.alpha)
		)
		var off := crates[index].global_position.distance_to(feet)
		if off > CRATE_TOLERANCE and not misses.has(key):
			misses[key] = (
				"art-lint: %s drawn %.1f mm off its snapshot at tick %d"
				% [key, off * 1000.0, driver.current["tick"]]
			)
	return moved


## The lowest point of [param model]'s skinned mesh at rest, in its parent's units.
func _sole(model: Node3D) -> float:
	var lowest := INF
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin != null:
			lowest = minf(lowest, mesh_instance.get_aabb().position.y)
	return lowest * model.scale.y


func _check_collapse() -> void:
	var scene: MatchScene = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	scene.start(RunMatch.default_config(COLLAPSE_SEED), true, true)
	# The lint steps the match itself, paused, until the tick the view shows has the
	# collapse fallen, then shows it. The client's sim stands at the newest snapshot,
	# never behind the view: what has collapsed by the view's tick has there too.
	scene.set_paused(true)
	var driver: SimDriver = scene.get_node("SimDriver")
	var sim := driver.client.sim
	var shown := func() -> ShipPose: return sim.schedule.pose_at(driver.current["tick"])
	_checks += 1
	while not driver.client.is_over() and (shown.call() as ShipPose).collapsed.is_empty():
		driver.step()
	for _tick in Ticks.from_seconds(MatchView.FALL_SECONDS) + 1:
		driver.step()
	var collapsed := (shown.call() as ShipPose).collapsed
	if collapsed.is_empty():
		_problems.append("art-lint: seed %d ends before anything collapses" % COLLAPSE_SEED)
		scene.queue_free()
		return
	driver.previous = driver.current
	await process_frame
	var faces := _ship_faces(scene.get_node("MatchView/Ship/ShipArt"))
	var cells := _file_faces(faces)
	var layout := sim.config.ship
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		if not platform.name in collapsed:
			continue
		_checks += 1
		var nearest := INF
		for point in _samples(platform.area):
			var at := Vector3(point.x, platform.height, point.y)
			if sim.surfaces.under(at, PLATFORM_TOLERANCE) == index:
				_problems.append(
					(
						"art-lint: Surfaces still stands platform %d at %s after it collapsed"
						% [index, point]
					)
				)
				continue
			nearest = minf(nearest, _nearest_face(faces, cells, at, Vector3.DOWN))
		if nearest <= PLATFORM_TOLERANCE:
			_problems.append(
				(
					"art-lint: collapsed platform %d (%s) still drawn at its height, %.1f cm off"
					% [index, platform.name, nearest * 100.0]
				)
			)
	scene.queue_free()
