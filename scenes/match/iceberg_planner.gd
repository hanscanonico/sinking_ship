class_name IcebergPlanner
extends RefCounted
## The iceberg she strikes, as seen (Iceberg draws it): one of the bergs modelled in
## Blender (BERGS), picked by the seed and scaled to her, and where it stands at any
## tick. From the match's start it looms off the struck side, ahead of her, and closes
## in; as HOLED strikes, its spur grinds aft along the gash, fore end to aft end,
## through GashPlanner's GASH_SECONDS — the white water bursting where the ice is;
## then it falls astern and away from her, and stays in sight. Every pose is a pure
## function of (hit, ship, seed, tick), never of frame time, so a scrubbed or restored
## match shows it where it was (D5). Presentation only: it has no collision and
## nothing it does reaches the sim (D12). Growlers it has shed float round its foot,
## on its side away from her, and go where it goes, rocking on the swell.
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
## least and at most; how wide it is over all, each side of its middle, as a share of
## its height, at least and at most; how deep it goes under, as a share of its
## height, and never deeper than this share of the sea there; and how far its foot
## stands under that depth, as a share of it.
const TOWERS := Vector2(1.4, 1.8)
const SPREAD := Vector2(0.6, 0.85)
const DRAUGHT := 2.0
const SEA_SHARE := 0.9
const FOOT := 1.05
## The least height of her top deck over the sea it is measured against, in metres.
const DECK_LEAST := 3.0
## The bergs, modelled in Blender (assets/models/NAME and its README), one picked
## a match: each modelled BERG_HEIGHT metres over the sea, its foot DRAUGHT × FOOT of
## that under it, as wide as SPREAD allows, its spur toward her along +z.
const BERGS: Array[String] = ["iceberg_tabular", "iceberg_drydock", "iceberg_wedge"]
const BERG_HEIGHT := 10.0
## How near two of a model's points along +z stand to be its spur's blade, in metres.
const BLADE_NEAR := 0.01
## The spur: how far over the gash's shallowest point and under its deepest its blade
## runs, in metres, and how close it lies to the sea at most; and how far its body
## stands off her shell over the sea as the spur runs along the gash.
const BLADE_OVER := 0.4
const BLADE_UNDER := 1.0
const BLADE_TOP := -0.3
const CLEAR := 0.4
## The growlers, bits of ice it has shed, modelled in Blender (assets/models/NAME):
## each GROWLER_SPAN metres across at most, GROWLER_RISE over the sea and
## GROWLER_DRAUGHT under it at BERG_HEIGHT's measure, and scaled as the berg is and by
## GROWLER_SIZE again, at least and at most. How many float round it, at least and at
## most; how far out from its middle, as a share of the most a berg spreads (SPREAD.y
## of its height), at least and at most; and how far round from straight away from
## her they float, either way, in degrees — short of square across, so none is ever
## between it and her.
const GROWLERS: Array[String] = ["growler_a", "growler_b", "growler_c"]
const GROWLER_SPAN := 2.4
const GROWLER_RISE := 0.6
const GROWLER_DRAUGHT := 1.6
const GROWLER_SIZE := Vector2(0.6, 1.5)
const GROWLER_COUNT := Vector2i(5, 8)
const GROWLER_OUT := Vector2(1.45, 2.4)
const GROWLER_ARC_DEG := 80.0
## How far a growler rocks on the swell, in degrees, how often, in hertz, and how much
## faster or slower one rocks than the next, at most, as a share.
const GROWLER_ROCK_DEG := 4.0
const GROWLER_ROCK_HZ := 0.2
const GROWLER_ROCK_SPREAD := 0.25

## Ticks: the strike, as HOLED tells it, and the end of the scrape.
var hit_tick := 0
var scrape_end := 0
## The model it is drawn from, of BERGS.
var berg := ""
## Metres: how high it towers over the sea, how wide it stands out from its middle at
## most, and how deep it goes.
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
var _normals := PackedVector3Array()
var _shades := PackedColorArray()
var _growlers: Array[Growler] = []

## Every model of BERGS and GROWLERS read, by name: read once a process.
static var _models := {}


## A berg or a growler as modelled: its faces, three corners each, in its own frame at
## BERG_HEIGHT's measure; each corner's normal, smooth across the ice and sharp at its
## ledges as the model shades it; each face's colour, linear, as the model carries it;
## and, for a berg, its spur's blade, the corners furthest along +z, as far out as they
## stand and halfway up between them.
class Model:
	var corners := PackedVector3Array()
	var normals := PackedVector3Array()
	var shades := PackedColorArray()
	var bounds := AABB()
	var blade_z := 0.0
	var blade_middle := 0.0


## A growler: its model, of GROWLERS; where it floats, in the berg's own frame, on the
## sea; which way it is turned, in radians; how much bigger than modelled it is; where
## in its rocking it is at the match's start, about x and about z, in radians; and how
## fast it rocks, as a share of GROWLER_ROCK_HZ.
class Growler:
	var model := ""
	var at := Vector3.ZERO
	var yaw := 0.0
	var size := 1.0
	var phase := Vector2.ZERO
	var pace := 1.0


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
	berg = BERGS[rng.randi_range(0, BERGS.size() - 1)]
	var model := model_of(berg)
	radius = model.bounds.size.x * 0.5 * height / BERG_HEIGHT
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
	_build(model, standoff + CLEAR)
	_float_growlers(match_seed)


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


## Each corner's normal, in shape()'s order: as modelled, but flat across a face the
## spur's blade was drawn out on.
func normals() -> PackedVector3Array:
	return _normals


## Each face's colour, one a face, in shape()'s order: linear, as a mesh's.
func shades() -> PackedColorArray:
	return _shades


## The spur's blade, its own frame: the point of it at [param y] over the sea.
func spur(y: float) -> Vector3:
	return Vector3(0.0, clampf(y, _blade.x, _blade.y), _reach)


## The growlers floating round it, as the seed has them.
func growlers() -> Array[Growler]:
	return _growlers


## Where growler [param index] floats at [param tick] — a fraction between two ticks
## for a frame drawn between them — in the berg's own frame: on the sea where it lies,
## turned its way, as big as it is, and rocking on the swell.
func growler_at(index: int, tick: float) -> Transform3D:
	var growler := _growlers[index]
	var swing := TAU * GROWLER_ROCK_HZ * growler.pace * tick / Ticks.RATE
	var rock := deg_to_rad(GROWLER_ROCK_DEG)
	var tilt := Basis(Vector3.RIGHT, rock * sin(swing + growler.phase.x))
	tilt *= Basis(Vector3.BACK, rock * sin(swing * 1.3 + growler.phase.y))
	var basis := tilt * Basis(Vector3.UP, growler.yaw) * growler.size
	return Transform3D(basis, growler.at)


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


## The model of BERGS or GROWLERS named [param name], read from its .glb the first
## time it is asked for and the same Model every time after.
static func model_of(name: String) -> Model:
	if _models.has(name):
		return _models[name]
	var path := "res://assets/models".path_join(name).path_join(name + ".glb")
	var mesh := ShipModel.mesh_of(load(path))
	var model := Model.new()
	model.bounds = mesh.get_aabb()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var order := PackedInt32Array(range(points.size()))
		if arrays[Mesh.ARRAY_INDEX] != null:
			order = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, order.size(), 3):
			for corner in 3:
				model.corners.append(points[order[index + corner]])
				model.normals.append(normals[order[index + corner]])
			model.shades.append(colours[order[index]])
	model.blade_z = model.bounds.end.z
	var blade := Vector2(INF, -INF)
	for corner in model.corners:
		if corner.z > model.blade_z - BLADE_NEAR:
			blade = Vector2(minf(blade.x, corner.y), maxf(blade.y, corner.y))
	model.blade_middle = (blade.x + blade.y) * 0.5
	_models[name] = model
	return model


## Builds its faces from [param model]: scaled to its height, nothing under its foot,
## and the spur's blade standing [param standoff] out past the rest over the sea toward
## her, as deep as the gash is.
func _build(model: Model, standoff: float) -> void:
	var scale := height / BERG_HEIGHT
	var inboard := -INF
	for corner in model.corners:
		if corner.y >= 0.0:
			inboard = maxf(inboard, corner.z * scale)
	_reach = inboard + standoff
	var foot := -depth * FOOT
	var drawn_out := {}
	for index in model.corners.size():
		var corner := model.corners[index]
		var point := corner * scale
		if corner.z > model.blade_z - BLADE_NEAR:
			point = Vector3(0.0, _blade.y if corner.y > model.blade_middle else _blade.x, _reach)
			drawn_out[index / 3] = true
		point.y = maxf(point.y, foot)
		_shape.append(point)
	# A face drawn out to the blade lies flat as it now lies.
	_normals = model.normals.duplicate()
	for face: int in drawn_out:
		var at := face * 3
		# Wound clockwise from outside: the cross product points in.
		var a := _shape[at]
		var flat := -(_shape[at + 1] - a).cross(_shape[at + 2] - a).normalized()
		for corner in 3:
			_normals[at + corner] = flat
	_shades = model.shades


## Floats its growlers round its foot as the match of [param match_seed] has them: as
## many as GROWLER_COUNT allows, each on its side away from her, out past the most a
## berg spreads, and none crowding another. A stream of their own, so the berg the
## seed picks is the berg it picked before there were growlers.
func _float_growlers(match_seed: int) -> void:
	var rng := SeedStreams.derive(match_seed, "growlers")
	var count := rng.randi_range(GROWLER_COUNT.x, GROWLER_COUNT.y)
	var scale := height / BERG_HEIGHT
	var spread := SPREAD.y * height
	var arc := deg_to_rad(GROWLER_ARC_DEG)
	for _try in count * 8:
		if _growlers.size() == count:
			return
		var growler := Growler.new()
		growler.model = GROWLERS[rng.randi_range(0, GROWLERS.size() - 1)]
		growler.size = scale * rng.randf_range(GROWLER_SIZE.x, GROWLER_SIZE.y)
		var bearing := rng.randf_range(-arc, arc)
		var out := spread * rng.randf_range(GROWLER_OUT.x, GROWLER_OUT.y)
		growler.at = Vector3(sin(bearing) * out, 0.0, -cos(bearing) * out)
		growler.yaw = rng.randf_range(0.0, TAU)
		growler.phase = Vector2(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))
		growler.pace = 1.0 + rng.randf_range(-GROWLER_ROCK_SPREAD, GROWLER_ROCK_SPREAD)
		if _clear_of_the_growlers(growler):
			_growlers.append(growler)


## Whether [param growler] floats clear of every growler afloat: a growler reaches no
## further from its middle than across its span's corner.
func _clear_of_the_growlers(growler: Growler) -> bool:
	for other in _growlers:
		var room := (growler.size + other.size) * GROWLER_SPAN * sqrt(0.5)
		if growler.at.distance_to(other.at) < room:
			return false
	return true


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
