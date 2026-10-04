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
##   platform's height and a bottom at or under the waterline at rest. And past
##   every platform's edge, wherever the rules have no floor near its height, no
##   drawn face looks like one: straight down through the heights a body could step
##   down to or jump up onto from that deck, the first face met never faces up — the
##   lifeboats beside an open edge, and the hull's ends all the way out past the end
##   railings. And through every railing span, broken, the opening it leaves stands
##   open as drawn: nothing across it between a step over its deck and a body's
##   height, from its line out to a body's breadth past it.
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
## - Crew: the seats of a full match each wear their own hat and coat, so each reads
##   by its shape as well as its colour, and a brawler draws at most CREW_VERTICES
##   vertices, so a deck full of them stays cheap.
## - The horizon: the sea (SeaAndSky) reaches past every camera's far plane in the
##   match scene, so no view sees the sea's edge.
## - The rooms' furnishings (RoomDressing), on every ship: none stands more than
##   FURNISHING_TOLERANCE into the space a body fills — within a body's radius of
##   anywhere Surfaces lets its centre stand, from a step over what it stands on to its
##   height over it — so nothing drawn at body height is something a body walks
##   through: a table in the middle of a cabin fails, a lifebelt on its wall does not.

const RunMatch := preload("res://tools/run_match.gd")
const MATCH_SCENE := "res://scenes/match/match.tscn"
const SHIPS_DIR := "res://data/ships/"
const ART_DIR := "res://scenes/art/"
const SEED := 1701
const SEATS := 8
## A match the default scenario's collapse comes in before it ends.
const COLLAPSE_SEED := 42
## Match time the seat check watches, at most.
const SEAT_SECONDS := 90.0
const PLATFORM_TOLERANCE := 0.02
const BLOCKER_TOLERANCE := 0.05
const RAMP_TOLERANCE := ShipArt.STEP_RISE * 0.5 + PLATFORM_TOLERANCE
const LADDER_TOLERANCE := 0.05
## How far past a platform's edge the false-floor probes stand, how far apart along
## it, and how near upright a face must turn to read as floor; past an edge that
## ends the decks, probes stand BEYOND_STEP apart out to END_BEYOND, past the stem
## and the counter.
const BEYOND: Array[float] = [0.25, 0.6, 1.0]
const BEYOND_STEP := 0.5
const END_BEYOND := 6.0
const FLOOR_FACING := 0.7
## Through a broken railing span: probes stand OPENING_STEP apart along it, at least
## OPENING_INSET in from its ends where the posts it shares and its remains stand,
## at heights OPENING_RISE apart; they start OPENING_INBOARD inboard of its line.
const OPENING_STEP := 0.4
const OPENING_INSET := 0.6
const OPENING_RISE := 0.15
const OPENING_INBOARD := 0.05
const SEAT_TOLERANCE := 0.001
const CRATE_TOLERANCE := 0.001
const SOLE_TOLERANCE := 0.02
## How far into the space a body fills a furnishing may stand: a wall fitting's
## depth, clear of the mannequin's shoulders. The furnishings' faces are sampled
## FURNISHING_STEP apart, and round each sample the centres tried stand on rings of
## FURNISHING_RINGS shares of a body's reach, FURNISHING_SPOKES to a ring, on a grid of
## FURNISHING_GRID.
const FURNISHING_TOLERANCE := 0.12
const FURNISHING_STEP := 0.08
const FURNISHING_RINGS: Array[float] = [0.0, 0.6, 0.95]
const FURNISHING_SPOKES := 10
const FURNISHING_GRID := 0.05
## The squares of the ship plane the heights a body may stand at are filed under.
const FURNISHING_CELL := 1.0
const CREW_VERTICES := 9000
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
	"PlayedMatch",
	"LoopbackMatch",
	"RemoteMatch",
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
	_check_crew()
	_check_sea_reach()
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


func _check_crew() -> void:
	var rules := RunMatch.default_config(SEED).rules
	var worn := {}
	for seat in SEATS:
		_checks += 1
		var outfit := seat % Brawler.HATS.size()
		var dress := Vector2i(Brawler.HATS[outfit], Brawler.COATS[outfit])
		if worn.has(dress):
			_problems.append("art-lint: seat %d dresses as seat %d" % [seat, worn[dress]])
		worn[dress] = seat
		var brawler := Brawler.new()
		root.add_child(brawler)
		brawler.setup(seat, rules, false)
		var vertices := 0
		for node: Node in brawler.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh
			for surface in mesh.get_surface_count():
				var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				vertices += points.size()
		if vertices > CREW_VERTICES:
			_problems.append(
				(
					"art-lint: seat %d's brawler draws %d vertices, over %d"
					% [seat, vertices, CREW_VERTICES]
				)
			)
		brawler.free()


func _check_sea_reach() -> void:
	var scene: Node = load(MATCH_SCENE).instantiate()
	for camera: Camera3D in scene.find_children("*", "Camera3D"):
		_checks += 1
		if camera.far >= SeaAndSky.REACH:
			_problems.append(
				(
					"art-lint: %s sees %.0f m, past the sea's %.0f m"
					% [camera.name, camera.far, SeaAndSky.REACH]
				)
			)
	scene.free()


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
	_check_false_floor(art, file, layout, rules)
	_check_crate_light(file, layout, art)
	_checks += 1
	for problem in intrusions(layout, rules, furnishings(art)):
		_problems.append("art-lint: %s: %s" % [file, problem])
	art.free()
	_check_open_spans(file, layout, rules)


## Every face of the rooms' furnishings (RoomDressing) [param art] draws, under its
## Dressing node, in the ship's space: their meshes and their signs' letters.
static func furnishings(art: ShipArt) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for node: Node in art.get_node("Dressing").get_children():
		var place := (node as Node3D).transform
		if node is MeshInstance3D:
			for corner: Vector3 in (node as MeshInstance3D).mesh.get_faces():
				faces.append(place * corner)
		elif node is Label3D:
			var box := (node as Label3D).get_aabb()
			var corners: Array[Vector3] = [
				box.position,
				box.position + Vector3(box.size.x, 0.0, 0.0),
				box.position + Vector3(box.size.x, box.size.y, 0.0),
				box.position + Vector3(0.0, box.size.y, 0.0),
			]
			for index: int in [0, 1, 2, 0, 2, 3]:
				faces.append(place * corners[index])
	return faces


## Where [param faces] stand more than FURNISHING_TOLERANCE into the space a body of
## [param rules] fills on [param layout]: a point of them within a body's radius, less
## the tolerance, of a centre Surfaces lets a body stand at, between a step over what
## that body stands on and its height over it. A face inside a blocker, or wholly over
## or under every body that could stand within reach of it, is passed over unsampled.
## One line per face found so, at most a few.
static func intrusions(
	layout: ShipLayout, rules: BrawlRules, faces: PackedVector3Array
) -> PackedStringArray:
	var surfaces := Surfaces.new(layout)
	var reach := rules.body_radius - FURNISHING_TOLERANCE
	var bands := _standing_bands(layout, reach)
	var standing := {}
	var found := PackedStringArray()
	for index in range(0, faces.size(), 3):
		var triangle := faces.slice(index, index + 3)
		if _inside_a_blocker(layout, triangle) or not _in_a_band(bands, triangle, rules):
			continue
		for point in _spread(triangle):
			var feet := _body_round(surfaces, rules, standing, point, reach)
			if feet.x == INF:
				continue
			var into := rules.body_radius - Vector2(point.x - feet.x, point.z - feet.z).length()
			found.append(
				"furnishing at %s stands %.2f m into a body standing at %s" % [point, into, feet]
			)
			break
		if found.size() >= 5:
			break
	return found


## Per FURNISHING_CELL square of the ship plane, the heights (low, high) a body's feet
## may stand at within [param reach] of it: every platform, ramp and blocker top of
## [param layout] whose area comes that near.
static func _standing_bands(layout: ShipLayout, reach: float) -> Dictionary:
	var bands := {}
	var tops: Array[Array] = []
	for platform: ShipPlatform in layout.platforms:
		tops.append([platform.area, Vector2(platform.height, platform.height)])
	for ramp: ShipRamp in layout.ramps:
		var high := maxf(ramp.start_height, ramp.end_height)
		tops.append([ramp.area, Vector2(ramp.base(), high)])
	for blocker: ShipBlocker in layout.blockers:
		var area := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			area = Rect2(
				blocker.centre - Vector2.ONE * blocker.radius, Vector2.ONE * blocker.radius * 2.0
			)
		tops.append([area, Vector2(blocker.top, blocker.top)])
	for top: Array in tops:
		var area := (top[0] as Rect2).grow(reach)
		var low := Vector2i((area.position / FURNISHING_CELL).floor())
		var high := Vector2i((area.end / FURNISHING_CELL).floor())
		for x in range(low.x, high.x + 1):
			for z in range(low.y, high.y + 1):
				var cell := Vector2i(x, z)
				var heights: PackedVector2Array = bands.get(cell, PackedVector2Array())
				heights.append(top[1])
				bands[cell] = heights
	return bands


## Whether [param triangle] reaches the heights a body of [param rules] standing
## within reach of it fills — over a step above its feet, under its head — on any of
## [param bands] (_standing_bands).
static func _in_a_band(bands: Dictionary, triangle: PackedVector3Array, rules: BrawlRules) -> bool:
	var low := Vector3.INF
	var high := -Vector3.INF
	for corner: Vector3 in triangle:
		low = low.min(corner)
		high = high.max(corner)
	var from := Vector2i((Vector2(low.x, low.z) / FURNISHING_CELL).floor())
	var to := Vector2i((Vector2(high.x, high.z) / FURNISHING_CELL).floor())
	for x in range(from.x, to.x + 1):
		for z in range(from.y, to.y + 1):
			for feet: Vector2 in bands.get(Vector2i(x, z), PackedVector2Array()):
				if high.y >= feet.x + rules.step_height and low.y <= feet.y + rules.body_height:
					return true
	return false


## Whether [param triangle] stands wholly inside one of [param layout]'s box
## blockers, which hold every body a radius off: an engine's own faces.
static func _inside_a_blocker(layout: ShipLayout, triangle: PackedVector3Array) -> bool:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX:
			continue
		var area := blocker.area.grow(0.002)
		var inside := true
		for corner: Vector3 in triangle:
			if (
				not area.has_point(Vector2(corner.x, corner.z))
				or corner.y < blocker.bottom - 0.002
				or corner.y > blocker.top + 0.002
			):
				inside = false
				break
		if inside:
			return true
	return false


## Points spread over [param triangle] no more than FURNISHING_STEP apart, its
## corners among them.
static func _spread(triangle: PackedVector3Array) -> PackedVector3Array:
	var a := triangle[0]
	var u := triangle[1] - a
	var v := triangle[2] - a
	var longest := maxf(u.length(), maxf(v.length(), (v - u).length()))
	var steps := maxi(1, ceili(longest / FURNISHING_STEP))
	var points := PackedVector3Array()
	for i in steps + 1:
		for j in steps + 1 - i:
			points.append(a + u * (float(i) / steps) + v * (float(j) / steps))
	return points


## The feet of a body of [param rules] that Surfaces lets stand within [param reach]
## of [param point] across the ship plane and whose height takes it in — over a step
## above its feet and under its head — or Vector3.INF when none of the centres tried
## does. [param standing] keeps, per grid centre, what stands under it (_stood_on).
static func _body_round(
	surfaces: Surfaces, rules: BrawlRules, standing: Dictionary, point: Vector3, reach: float
) -> Vector3:
	for ring: float in FURNISHING_RINGS:
		var spokes := 1 if ring == 0.0 else FURNISHING_SPOKES
		for spoke in spokes:
			var turn := TAU * spoke / spokes
			var at := Vector2(point.x, point.z) + Vector2(cos(turn), sin(turn)) * reach * ring
			var cell := Vector2i(roundi(at.x / FURNISHING_GRID), roundi(at.y / FURNISHING_GRID))
			var centre := Vector2(cell) * FURNISHING_GRID
			if centre.distance_to(Vector2(point.x, point.z)) >= reach:
				continue
			if not standing.has(cell):
				standing[cell] = _stood_on(surfaces, rules, centre)
			for under: Vector2 in standing[cell]:
				if point.y - under.x < rules.step_height:
					continue
				if point.y - under.x <= rules.body_height and under.y == 1.0:
					return Vector3(centre.x, under.x, centre.y)
				break
	return Vector3.INF


## Every surface Surfaces has under ship-plane point [param centre], from the top
## down, as (its height there, 1 when a body of [param rules] stands on it there with
## nothing holding it back, else 0).
static func _stood_on(surfaces: Surfaces, rules: BrawlRules, centre: Vector2) -> PackedVector2Array:
	var found := PackedVector2Array()
	var probe := Vector3(centre.x, 1e4, centre.y)
	while found.size() < 8:
		var surface := surfaces.landing(probe)
		if surface == Surfaces.NONE:
			break
		var feet := Vector3(centre.x, surfaces.height_at(surface, probe), centre.y)
		var contacts := surfaces.obstacle_contacts(
			feet, rules.body_radius, rules.body_height, rules.step_height
		)
		found.append(Vector2(feet.y, 1.0 if contacts.is_empty() else 0.0))
		probe.y = feet.y - 0.01
	return found


## Past each of [param layout]'s platforms' edges, wherever the rules have no stair
## and no platform within a step down or a jump up of it, the highest face
## [param art] shows in that band, straight down, does not face up: nothing drawn
## looks like deck a body could stand on where the rules have none (D6).
func _check_false_floor(art: ShipArt, file: String, layout: ShipLayout, rules: BrawlRules) -> void:
	var faces := _ship_faces(art, true)
	var cells := _file_faces(faces)
	var ends := Vector2(INF, -INF)
	for platform: ShipPlatform in layout.platforms:
		ends = Vector2(minf(ends.x, platform.area.position.x), maxf(ends.y, platform.area.end.x))
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		var low := platform.height - rules.step_height
		var high := platform.height + rules.jump_height
		_checks += 1
		for point in _beyond(platform.area, ends):
			if _floor_near(layout, point, low, high):
				continue
			var facing := _top_facing(faces, cells, Vector3(point.x, high, point.y), low)
			if facing > FLOOR_FACING:
				_problems.append(
					(
						"art-lint: %s platform %d: drawn floor past its edge at %s"
						% [file, index, point]
					)
				)
				break


## [param layout] dressed with every railing breakable, then each span broken in
## turn: through the opening it leaves, from a step over its deck up to a body's
## height, no face is drawn across its line or out to a body's breadth past it —
## across it, or straight down over it — neither the hull, its ends, the fittings,
## its neighbours nor its own remains: the gap the rules leave open is open as drawn
## (D6).
func _check_open_spans(file: String, layout: ShipLayout, rules: BrawlRules) -> void:
	var art := ShipArt.new()
	root.add_child(art)
	var none: Array[StringName] = []
	var every := PackedInt32Array(range(layout.railings.size()))
	art.build(layout, rules.railing_height, rules.body_radius, none, every)
	var spans := PackedInt32Array()
	var faces := _ship_faces(art, false, spans)
	var cells := _file_faces(faces)
	var breadth := rules.body_radius * 2.0
	for index in layout.railings.size():
		_checks += 1
		art.show_sinking(none, {}, PackedInt32Array([index]), false)
		var remains := _ship_faces(
			art.find_child("Railing%dRemains" % index, true, false) as Node3D
		)
		var railing := layout.railings[index]
		var platform := layout.platforms[railing.platform]
		var along := (railing.to - railing.from).normalized()
		var outward := along.orthogonal()
		if (platform.area.get_center() - railing.from).dot(outward) > 0.0:
			outward = -outward
		var low := platform.height + rules.step_height
		var high := platform.height + rules.body_height
		var segments: Array[PackedVector3Array] = []
		for point in _along_span(railing):
			var height := low
			while height <= high + 0.001:
				var from := point - outward * OPENING_INBOARD
				var to := point + outward * breadth
				segments.append(
					PackedVector3Array(
						[Vector3(from.x, height, from.y), Vector3(to.x, height, to.y)]
					)
				)
				height += OPENING_RISE
			var out := OPENING_STEP * 0.25
			while out <= breadth:
				var over := point + outward * out
				segments.append(
					PackedVector3Array(
						[Vector3(over.x, high, over.y), Vector3(over.x, low, over.y)]
					)
				)
				out += OPENING_STEP * 0.5
		for segment: PackedVector3Array in segments:
			if _blocked(faces, cells, spans, index, remains, segment):
				_problems.append(
					(
						"art-lint: %s railing %d: drawn face across its opening, broken, on %s"
						% [file, index, segment]
					)
				)
				break
	art.free()


## Points along [param railing]'s line OPENING_STEP apart, OPENING_INSET in from
## its ends — its middle alone when it is too short for more.
func _along_span(railing: ShipRailing) -> PackedVector2Array:
	var length := railing.from.distance_to(railing.to)
	var inset := minf(OPENING_INSET, length * 0.5)
	var count := floori((length - inset * 2.0) / OPENING_STEP)
	var points := PackedVector2Array()
	for step in count + 1:
		var share := 0.5 if count == 0 else (inset + (length - inset * 2.0) * step / count) / length
		points.append(railing.from.lerp(railing.to, share))
	return points


## Whether [param segment] (from, to) crosses a face of [param faces] — but those of
## span [param broken], per [param spans] — or one of [param remains].
func _blocked(
	faces: PackedVector3Array,
	cells: Dictionary,
	spans: PackedInt32Array,
	broken: int,
	remains: PackedVector3Array,
	segment: PackedVector3Array
) -> bool:
	var from := segment[0]
	var to := segment[1]
	for index in range(0, remains.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			from, to, remains[index], remains[index + 1], remains[index + 2]
		)
		if hit != null:
			return true
	var low := Vector2i(floori(minf(from.x, to.x) / CELL), floori(minf(from.z, to.z) / CELL))
	var high := Vector2i(floori(maxf(from.x, to.x) / CELL), floori(maxf(from.z, to.z) / CELL))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			for index: int in cells.get(Vector2i(x, z), []):
				if spans[index / 3] == broken:
					continue
				var hit: Variant = Geometry3D.segment_intersects_triangle(
					from, to, faces[index], faces[index + 1], faces[index + 2]
				)
				if hit != null:
					return true
	return false


## Points of the ship plane BEYOND [param area]'s edges, BEYOND_STEP apart along each
## — and out to END_BEYOND past an edge on [param ends], the decks' x range.
func _beyond(area: Rect2, ends: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var far := BEYOND.duplicate()
	var reach := BEYOND[BEYOND.size() - 1] + BEYOND_STEP
	while reach <= END_BEYOND:
		far.append(reach)
		reach += BEYOND_STEP
	for reach_out: float in far:
		for side in 4:
			if reach_out > BEYOND[BEYOND.size() - 1]:
				var x := area.end.x if side == 1 else area.position.x
				if side % 2 == 0 or not is_equal_approx(x, ends.y if side == 1 else ends.x):
					continue
			var along_x := side % 2 == 0
			var length := area.size.x if along_x else area.size.y
			var count := maxi(1, floori(length / BEYOND_STEP))
			for step in count + 1:
				var share := (
					lerpf(SAMPLE_INSET, length - SAMPLE_INSET, float(step) / count) / length
				)
				var at := (
					area.position
					+ area.size * (Vector2(share, 0.0) if along_x else Vector2(0.0, share))
				)
				match side:
					0:
						points.append(Vector2(at.x, area.position.y - reach_out))
					1:
						points.append(Vector2(area.end.x + reach_out, at.y))
					2:
						points.append(Vector2(at.x, area.end.y + reach_out))
					3:
						points.append(Vector2(area.position.x - reach_out, at.y))
	return points


## Whether a platform of [param layout] stands over [param point] between
## [param low] and [param high], or any ramp does: a stair is floor the rules have,
## its stringers and all.
func _floor_near(layout: ShipLayout, point: Vector2, low: float, high: float) -> bool:
	for platform: ShipPlatform in layout.platforms:
		if (
			platform.contains(point.x, point.y)
			and platform.height >= low
			and platform.height <= high
		):
			return true
	for ramp: ShipRamp in layout.ramps:
		if ramp.contains(point.x, point.y):
			return true
	return false


## How far up (its normal's y) the highest face straight under [param from] and over
## [param low] faces; -1 when there is none.
func _top_facing(faces: PackedVector3Array, cells: Dictionary, from: Vector3, low: float) -> float:
	var highest := -INF
	var facing := -1.0
	for index: int in cells.get(Vector2i(floori(from.x / CELL), floori(from.z / CELL)), []):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, a, b, c)
		if hit == null:
			continue
		var height := (hit as Vector3).y
		if height >= low and height > highest:
			highest = height
			# Godot's front faces wind clockwise: their normal is the cross reversed.
			facing = -(b - a).cross(c - a).normalized().y
	return facing


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


## Every triangle drawn under [param art], in the ship's space — those shown now
## alone when [param shown] says so. Into [param spans], when given, per triangle the
## railing span it is drawn under (ShipArt's "Railing<n>" nodes), or -1.
func _ship_faces(art: Node3D, shown := false, spans := PackedInt32Array()) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var ship := art
	while ship != null and not ship is ShipArt:
		ship = ship.get_parent() as Node3D
	var span_name := RegEx.create_from_string("^Railing(\\d+)$")
	for node: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if shown and not mesh_instance.is_visible_in_tree():
			continue
		var span := -1
		var up := mesh_instance.get_parent()
		while up != null and up != ship:
			var found := span_name.search(up.name)
			if found != null:
				span = found.get_string(1).to_int()
			up = up.get_parent()
		var to_ship := ship.global_transform.affine_inverse() * mesh_instance.global_transform
		var corners := mesh_instance.mesh.get_faces()
		for corner: Vector3 in corners:
			faces.append(to_ship * corner)
		for _triangle in corners.size() / 3:
			spans.append(span)
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
