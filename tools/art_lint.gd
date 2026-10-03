extends SceneTree
## `make art-lint`: the art aligns to the data, never the reverse (D6), and reads
## snapshots only (D5). Headless; run with --fixed-fps so match time advances one
## tick per two frames however fast the machine draws.
##
## - Platforms: on every ship in data/ships, the drawn ship shows an upward face
##   within PLATFORM_TOLERANCE of each platform's height across its whole area.
## - Seats: through a bots-only match in the real match scene, every brawler's
##   model hangs from its body's feet — the posed ship carrying the interpolated
##   snapshot position — and the mannequin's soles stand on that root.
## - Snapshots only: no script anywhere under scenes/art names a live sim object.

const RunMatch := preload("res://tools/run_match.gd")
const MATCH_SCENE := "res://scenes/match/match.tscn"
const SHIPS_DIR := "res://data/ships/"
const ART_DIR := "res://scenes/art/"
const SEED := 1701
const SEATS := 8
## Match time the seat check watches, at most.
const SEAT_SECONDS := 90.0
const PLATFORM_TOLERANCE := 0.02
const SEAT_TOLERANCE := 0.001
const SOLE_TOLERANCE := 0.02
## How far in from a platform's edges the samples start, and how many per side.
const SAMPLE_INSET := 0.1
const SAMPLES_ALONG := 6
const SAMPLES_ACROSS := 3
## What art may not name: the live match and the queries only rules make. Enum
## reads off PlayerState are allowed, a PlayerState itself is not.
const LIVE: PackedStringArray = [
	"MatchSim",
	"MatchState",
	"MatchRunner",
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
			_check_platforms(file, load(SHIPS_DIR + file))
	await _check_seats()
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


## Each platform of [param layout] against the ship as drawn.
func _check_platforms(file: String, layout: ShipLayout) -> void:
	var rules := RunMatch.default_config(SEED).rules
	var art := ShipGreybox.new()
	root.add_child(art)
	art.build(layout, rules.railing_height)
	var faces := _ship_faces(art)
	for index in layout.platforms.size():
		_checks += 1
		var platform := layout.platforms[index]
		var worst := 0.0
		var worst_at := Vector2.ZERO
		for point in _samples(platform.area):
			var off := _nearest_face(faces, point, platform.height)
			if off > worst:
				worst = off
				worst_at = point
		if worst > PLATFORM_TOLERANCE:
			_problems.append(
				(
					"art-lint: %s platform %d: drawn top %.1f cm off its height %.2f m at %s"
					% [file, index, worst * 100.0, platform.height, worst_at]
				)
			)
	art.free()


## Every triangle drawn under [param art], in its (ship) space.
func _ship_faces(art: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for node: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var to_ship := art.global_transform.affine_inverse() * mesh_instance.global_transform
		for corner: Vector3 in mesh_instance.mesh.get_faces():
			faces.append(to_ship * corner)
	return faces


func _samples(area: Rect2) -> PackedVector2Array:
	var inner := area.grow(-SAMPLE_INSET)
	var points := PackedVector2Array()
	for i in SAMPLES_ALONG:
		for j in SAMPLES_ACROSS:
			var along := float(i) / (SAMPLES_ALONG - 1)
			var across := float(j) / (SAMPLES_ACROSS - 1)
			points.append(inner.position + inner.size * Vector2(along, across))
	return points


## How far the drawn face nearest [param height] lies from it, straight above or
## below [param point]; INF when nothing is drawn there at all.
func _nearest_face(faces: PackedVector3Array, point: Vector2, height: float) -> float:
	var from := Vector3(point.x, height + 100.0, point.y)
	var nearest := INF
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			from, Vector3.DOWN, faces[index], faces[index + 1], faces[index + 2]
		)
		if hit != null:
			nearest = minf(nearest, absf((hit as Vector3).y - height))
	return nearest


func _check_seats() -> void:
	var scene: MatchScene = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	scene.start(RunMatch.default_config(SEED, SEATS), true)
	var driver: SimDriver = scene.get_node("SimDriver")
	var runner := driver.runner
	var ship: Node3D = scene.get_node("MatchView/Ship")
	var brawlers: Array[Brawler] = []
	for child: Node in ship.get_children():
		if child is Brawler:
			brawlers.append(child)
	_checks += 1
	if brawlers.size() != SEATS:
		_problems.append("art-lint: %d brawlers drawn for %d seats" % [brawlers.size(), SEATS])
	var misses := {}
	while not runner.is_over() and runner.tick() < Ticks.from_seconds(SEAT_SECONDS):
		await process_frame
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
					% [brawler.seat, off * 1000.0, runner.tick()]
				)
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


## The lowest point of [param model]'s skinned mesh at rest, in its parent's units.
func _sole(model: Node3D) -> float:
	var lowest := INF
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin != null:
			lowest = minf(lowest, mesh_instance.get_aabb().position.y)
	return lowest * model.scale.y
