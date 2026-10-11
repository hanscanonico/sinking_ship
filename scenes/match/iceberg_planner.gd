class_name IcebergPlanner
extends RefCounted
## The iceberg she strikes, as seen (Iceberg draws it): a seeded, jagged mass of ice
## sized to her, and where it stands at any tick. From the match's start it looms off
## the struck side, ahead of her, and closes in; as HOLED strikes, its spur grinds aft
## along the gash, fore end to aft end, through GashPlanner's GASH_SECONDS — the white
## water bursting where the ice is; then it falls astern and away from her, and stays
## in sight. Every pose is a pure function of (hit, ship, seed, tick), never of frame
## time, so a scrubbed or restored match shows it where it was (D5). Presentation
## only: it has no collision and nothing it does reaches the sim (D12).
##
## Poses are in the sea's frame: her ship-local x and z as she lies before the hit,
## level, and y over the sea. The berg's own frame has the sea at y = 0 and its spur
## pointing along +z, toward her.

## How far off the gash's fore end it first looms, at least and in her lengths, in
## metres; and how far off her bow line it bears as it closes in, in degrees.
const LOOM_LEAST := 150.0
const LOOM_LENGTHS := 1.4
const LOOM_BEARING_DEG := 22.0
## How far astern of the gash's aft end it drifts off to, at least and in her lengths,
## in metres; how far off her stern line it bears as it goes, in degrees; the least
## speed it gathers toward as it goes off, in metres a second; and how far it turns as
## it goes, in degrees.
const DRIFT_LEAST := 110.0
const DRIFT_LENGTHS := 1.0
const DRIFT_BEARING_DEG := 18.0
const DRIFT_SPEED := 2.5
const DRIFT_TURN_DEG := 35.0
## How high it towers over the sea, as a share of her top deck's height over it, at
## least and at most; how wide it is at the sea, as a share of its height; how deep
## it goes under, as a share of its height, and never deeper than this share of the
## sea there.
const TOWERS := Vector2(1.4, 1.8)
const SPREAD := Vector2(0.6, 0.85)
const DRAUGHT := 2.0
const SEA_SHARE := 0.9
## The least height of her top deck over the sea it is measured against, in metres.
const DECK_LEAST := 3.0
## How many sides each ring of it has, and the rings', from its foot to under its peak:
## height as a share of its depth under the sea (below 0) or its height over it, and
## width as a share of its width at the sea.
const SIDES := 9
const UNDER_RINGS: Array[Vector2] = [
	Vector2(-1.0, 0.35), Vector2(-0.7, 0.85), Vector2(-0.4, 1.0), Vector2(-0.15, 0.97)
]
const OVER_RINGS: Array[Vector2] = [
	Vector2(0.0, 0.92), Vector2(0.22, 0.78), Vector2(0.5, 0.55), Vector2(0.78, 0.32)
]
## How unevenly each corner of a ring stands out, at least and at most, and how far
## round from its even place it may stand, as a share of a side.
const JAGGED := Vector2(0.78, 1.15)
const SKEW := 0.3
## How far its peak leans off its middle, outboard, as a share of its width.
const LEAN := 0.4
## The spur: how far over the gash's shallowest point and under its deepest its blade
## runs, in metres, and how close it lies to the sea at most; and how far its body
## stands off her shell over the sea as the spur runs along the gash.
const BLADE_OVER := 0.4
const BLADE_UNDER := 1.0
const BLADE_TOP := -0.3
const CLEAR := 0.4
## Its ice: facing up, on its steep faces, and under the sea.
const ICE := Color("dfe8ee")
const ICE_SHADE := Color("a9c3d3")
const ICE_UNDER := Color("4f8f9e")

## Ticks: the strike, as HOLED tells it, and the end of the scrape.
var hit_tick := 0
var scrape_end := 0
## Metres: how high it towers over the sea, how wide its waterline ring is round its
## middle, and how deep it goes.
var height := 0.0
var radius := 0.0
var depth := 0.0

var _side := 1
## Where the spur runs along her shell, fore end first, in the sea's frame.
var _line := PackedVector3Array()
var _line_length := 0.0
## How far its loom and its drift reach, in metres, and the spur's speed along the
## gash, in metres a tick.
var _loom := 0.0
var _drift := 0.0
var _scrape_speed := 0.0
## The spur's blade: how far from its middle, along +z, and from what height to what.
var _reach := 0.0
var _blade := Vector2.ZERO
var _shape := PackedVector3Array()
var _shades := PackedColorArray()


## The berg [param hit], struck at [param struck] tick, makes on [param layout] in the
## match of [param match_seed]: its spur running along [param trace] — the gash on her
## shell, aft to fore, ship-local (HitDamage.trace) — or, without one, along the hit's
## own line on her shell; under at most a sea [param sea_depth] deep.
func _init(
	hit: IcebergHit,
	struck: int,
	layout: ShipLayout,
	match_seed: int,
	trace := PackedVector3Array(),
	sea_depth := INF
) -> void:
	var structure := layout.structure
	hit_tick = struck
	scrape_end = struck + Ticks.from_seconds(GashPlanner.GASH_SECONDS)
	_side = 1 if hit.side >= 0 else -1
	var line := trace if trace.size() >= 2 else _hit_line(hit, structure)
	for index in range(line.size() - 1, -1, -1):
		var point := line[index]
		_line.append(Vector3(point.x, point.y - structure.waterline_y, point.z))
	_line_length = _length(_line)
	var span := _span(structure)
	var ship_length := span.y - span.x
	_loom = maxf(LOOM_LEAST, ship_length * LOOM_LENGTHS)
	_drift = maxf(DRIFT_LEAST, ship_length * DRIFT_LENGTHS)
	_scrape_speed = _line_length / maxi(scrape_end - hit_tick, 1)
	var rng := SeedStreams.derive(match_seed, "iceberg")
	var deck := maxf(_top_deck(layout) - structure.waterline_y, DECK_LEAST)
	height = deck * rng.randf_range(TOWERS.x, TOWERS.y)
	radius = height * rng.randf_range(SPREAD.x, SPREAD.y)
	depth = height * DRAUGHT
	if is_finite(sea_depth) and sea_depth > 0.0:
		depth = minf(depth, sea_depth * SEA_SHARE)
	var shallowest := -INF
	var deepest := INF
	var standoff := 0.0
	for point in _line:
		shallowest = maxf(shallowest, point.y)
		deepest = minf(deepest, point.y)
		standoff = maxf(standoff, _beam_at(structure, point.x) - point.z * _side)
	_blade = Vector2(deepest - BLADE_UNDER, minf(shallowest + BLADE_OVER, BLADE_TOP))
	_blade.x = maxf(_blade.x, -depth * 0.85)
	_blade.y = maxf(_blade.y, _blade.x + 0.2)
	_build(rng, standoff + CLEAR)


## The berg of [param schedule]'s hit on [param layout] in the match of
## [param match_seed], along the gash it struck; null when nothing strikes her.
static func for_match(
	schedule: SinkSchedule, layout: ShipLayout, match_seed: int
) -> IcebergPlanner:
	var hit := schedule.hit()
	if hit == null or layout.structure == null:
		return null
	var damage := schedule.damage()
	var trace := damage.trace if damage != null else PackedVector3Array()
	var sea := damage.sea_depth if damage != null else INF
	return IcebergPlanner.new(hit, schedule.hit_tick(), layout, match_seed, trace, sea)


## Its faces, three corners each, in its own frame (spur along +z, the sea at y = 0).
func shape() -> PackedVector3Array:
	return _shape


## Each face's colour, one a face, in shape()'s order: linear, as a mesh's.
func shades() -> PackedColorArray:
	return _shades


## The spur's blade, its own frame: the point of it at [param y] over the sea.
func spur(y: float) -> Vector3:
	return Vector3(0.0, clampf(y, _blade.x, _blade.y), _reach)


## Where it stands at [param tick] — a fraction between two ticks for a frame drawn
## between them — in the sea's frame: on the sea, its spur's blade wherever the spur
## is then.
func pose_at(tick: float) -> Transform3D:
	var at := spur_at(tick)
	var basis := Basis(Vector3.UP, _yaw(tick))
	var origin := at - basis * Vector3(0.0, 0.0, _reach)
	return Transform3D(basis, Vector3(origin.x, 0.0, origin.z))


## Where the point of its spur is at [param tick], in the sea's frame: on the gash as
## it scrapes along it, at the gash's height there.
func spur_at(tick: float) -> Vector3:
	if tick < hit_tick:
		var share := clampf((hit_tick - tick) / maxf(hit_tick, 1.0), 0.0, 1.0)
		# Closing in at the speed it scrapes at when it strikes, and faster further off.
		var even := clampf(_scrape_speed * maxf(hit_tick, 1.0) / _loom, 0.0, 1.0)
		var off := _loom * (even * share + (1.0 - even) * share * share)
		var bearing := deg_to_rad(LOOM_BEARING_DEG)
		return _line[0] + Vector3(cos(bearing), 0.0, _side * sin(bearing)) * off
	if tick <= scrape_end:
		return _along(_line, (tick - hit_tick) / maxf(scrape_end - hit_tick, 1.0))
	var gone := _drift * _gone(tick)
	var away := deg_to_rad(DRIFT_BEARING_DEG)
	return _line[_line.size() - 1] + Vector3(-cos(away), 0.0, _side * sin(away)) * gone


## How far it has gone of its drift at [param tick], after the scrape: 0…1, going off
## as fast as it scraped, gathering way toward DRIFT_SPEED if that is faster, and
## slowing: 1 − e^(−kt)·(1 + (k − a)t), whose speed starts at a, the scrape's.
func _gone(tick: float) -> float:
	var since := tick - scrape_end
	var scraped := _scrape_speed / _drift
	var pace := maxf(_scrape_speed, DRIFT_SPEED / Ticks.RATE) / _drift
	return 1.0 - exp(-pace * since) * (1.0 + (pace - scraped) * since)


## Which way it faces at [param tick]: its spur toward her, turning as it drifts off.
func _yaw(tick: float) -> float:
	var yaw := PI if _side == 1 else 0.0
	if tick > scrape_end:
		yaw += _side * deg_to_rad(DRIFT_TURN_DEG) * _gone(tick)
	return yaw


## Builds its faces, from [param rng]: rings of uneven corners from its foot to its
## peak, leaning outboard over the sea, flattened on the side toward her under it, and
## the spur's blade standing [param standoff] out past the rest toward her.
func _build(rng: RandomNumberGenerator, standoff: float) -> void:
	var rings: Array[PackedVector3Array] = []
	var heights := PackedFloat32Array()
	for ring in UNDER_RINGS:
		heights.append(ring.x * depth)
	for ring in OVER_RINGS:
		heights.append(ring.x * height)
	var widths := PackedFloat32Array()
	for ring in UNDER_RINGS + OVER_RINGS:
		widths.append(ring.y)
	var lean := rng.randf_range(PI * 0.6, PI * 1.4)
	var lean_way := Vector3(sin(lean), 0.0, cos(lean))
	for index in heights.size():
		var y := heights[index] * rng.randf_range(0.94, 1.06)
		var middle := lean_way * radius * LEAN * maxf(y / height, 0.0)
		var ring := PackedVector3Array()
		for corner in SIDES:
			var turn := TAU * corner / SIDES
			if corner != 0:
				turn += rng.randf_range(-SKEW, SKEW) * TAU / SIDES
			var out := widths[index] * radius * rng.randf_range(JAGGED.x, JAGGED.y)
			ring.append(middle + Vector3(sin(turn) * out, y, cos(turn) * out))
		rings.append(ring)
	# Nothing of it over the sea, nor under it, comes nearer her than the spur's root.
	var inboard := 0.0
	for ring in rings:
		for corner in ring:
			if corner.y >= 0.0:
				inboard = maxf(inboard, corner.z)
	for index in rings.size():
		var ring := rings[index]
		for corner in ring.size():
			var point := ring[corner]
			if point.y < 0.0 and point.z > inboard:
				ring[corner] = Vector3(point.x, point.y, inboard)
		rings[index] = ring
	_reach = inboard + standoff
	_insert_blade(rings)
	var peak := lean_way * radius * LEAN + Vector3.UP * height * rng.randf_range(0.95, 1.08)
	peak += Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)) * radius
	var foot := Vector3(0.0, -depth * 1.05, 0.0)
	var middles := PackedVector3Array()
	for ring in rings:
		var sum := Vector3.ZERO
		for corner in ring:
			sum += corner
		middles.append(sum / ring.size())
	for index in rings.size() - 1:
		var low := rings[index]
		var high := rings[index + 1]
		var inside := (middles[index] + middles[index + 1]) * 0.5
		for corner in SIDES:
			var next := (corner + 1) % SIDES
			if rng.randf() < 0.5:
				_face(low[corner], low[next], high[next], inside, rng)
				_face(low[corner], high[next], high[corner], inside, rng)
			else:
				_face(low[corner], low[next], high[corner], inside, rng)
				_face(low[next], high[next], high[corner], inside, rng)
	var top := rings[rings.size() - 1]
	for corner in SIDES:
		var next := (corner + 1) % SIDES
		_face(top[corner], top[next], peak, middles[rings.size() - 1], rng)
		_face(rings[0][next], rings[0][corner], foot, middles[0], rng)


## Puts the spur's blade in [param rings]: two rings at its top and its foot, each
## where the rings round it would be there, with its corner toward her drawn out to
## the blade.
func _insert_blade(rings: Array[PackedVector3Array]) -> void:
	for y in PackedFloat32Array([_blade.x, _blade.y]):
		var above := 0
		while above < rings.size() and rings[above][0].y <= y:
			above += 1
		var low := rings[maxi(above - 1, 0)]
		var high := rings[mini(above, rings.size() - 1)]
		var ring := PackedVector3Array()
		for corner in SIDES:
			var gap := high[corner].y - low[corner].y
			var share := clampf((y - low[corner].y) / gap, 0.0, 1.0) if gap > 0.001 else 0.0
			var point := low[corner].lerp(high[corner], share)
			ring.append(Vector3(point.x, y, point.z))
		ring[0] = Vector3(0.0, y, _reach)
		rings.insert(above, ring)


## A face from [param a], [param b] and [param c], turned away from [param inside],
## with its colour: ice, bluer the steeper and the deeper it lies, no two faces quite
## alike.
func _face(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, rng: RandomNumberGenerator) -> void:
	var normal := (b - a).cross(c - a)
	var middle := (a + b + c) / 3.0
	# Godot's faces are wound clockwise seen from outside.
	if normal.dot(middle - inside) > 0.0:
		_shape.append_array([a, c, b])
	else:
		_shape.append_array([a, b, c])
	var up := absf(normal.normalized().y) if normal.length() > 0.0 else 0.0
	var colour := ICE_SHADE.lerp(ICE, up)
	if middle.y < 0.0:
		colour = ICE_UNDER
	colour = colour * rng.randf_range(0.9, 1.04)
	colour.a = 1.0
	_shades.append(colour.srgb_to_linear())


## Her shell's line where [param hit] strikes [param structure], aft to fore,
## ship-local: for a hit without a gash on her (HitDamage.trace).
static func _hit_line(hit: IcebergHit, structure: ShipStructure) -> PackedVector3Array:
	var line := PackedVector3Array()
	var steps := maxi(ceili(hit.length / 2.0), 1)
	for step in steps + 1:
		var x := hit.start_x + hit.length * step / steps
		var y := structure.waterline_y - hit.depth_at(x)
		var section := structure.section_at(x)
		var z := section.shell_at(y, hit.side) if section != null else NAN
		if is_nan(z):
			z = _half_beam(structure) * hit.side
		line.append(Vector3(x, y, z))
	return line


## How far out from her middle she stands at [param x], anywhere up her side.
static func _beam_at(structure: ShipStructure, x: float) -> float:
	var section := structure.section_at(x)
	if section == null:
		return _half_beam(structure)
	var widest := 0.0
	for point in section.outline:
		widest = maxf(widest, absf(point.x))
	return widest


static func _half_beam(structure: ShipStructure) -> float:
	var widest := 0.0
	for section: HullSection in structure.sections:
		for point in section.outline:
			widest = maxf(widest, absf(point.x))
	return widest


## Her ends along x, from her sections.
static func _span(structure: ShipStructure) -> Vector2:
	var span := Vector2(INF, -INF)
	for section: HullSection in structure.sections:
		span.x = minf(span.x, section.x - section.length * 0.5)
		span.y = maxf(span.y, section.x + section.length * 0.5)
	return span if span.x < span.y else Vector2.ZERO


## Her highest deck's height, ship-local.
static func _top_deck(layout: ShipLayout) -> float:
	var top := -INF
	for platform: ShipPlatform in layout.platforms:
		top = maxf(top, platform.height)
	return top if is_finite(top) else layout.structure.waterline_y


static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for index in points.size() - 1:
		total += points[index].distance_to(points[index + 1])
	return total


## The point [param share] of the way along the line through [param points].
static func _along(points: PackedVector3Array, share: float) -> Vector3:
	var left := _length(points) * clampf(share, 0.0, 1.0)
	for index in points.size() - 1:
		var step := points[index].distance_to(points[index + 1])
		if left <= step and step > 0.0:
			return points[index].lerp(points[index + 1], left / step)
		left -= step
	return points[points.size() - 1]
