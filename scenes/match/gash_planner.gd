class_name GashPlanner
extends RefCounted
## The iceberg's strike as seen (FxPlanner): the gash SinkSchedule has her struck with
## (D13) — its line on her shell and the sea it lets in — read against her waterline
## and turned into cues. As HOLED strikes, white water bursts up and out of all of
## the gash at once, spray mist billows up her side over it, foam spreads on the sea
## along it and the sea boils over it where it runs deep; then, for GASH_SECONDS and
## dying down, white water bursts up somewhere new along it every GASH_TICKS. The
## bigger the gash, the harder, higher and thicker all of it. Presentation state
## only; nothing it does reaches the sim (D5, D12).

## How long the gash goes on showing after the strike, in seconds, and how often a
## burst comes up along it after the strike, in ticks.
const GASH_SECONDS := 7.0
const GASH_TICKS := 15
## How big a gash is (size()) is read off the area it lets the sea in through, evenly
## on a log scale from a scrape's to the most there is, in m².
const GASH_AREA := Vector2(0.005, 3.0)
## The strike's white water, from the least gash to the most: how hard it is thrown,
## how high over the sea it climbs, in metres, and how long a sheet of it is along the
## gash — shorter, so more of them, the bigger it is — no more of them than GashFx
## has emitters for; each thrown up GASH_OFF outboard of her shell.
const GASH_STRENGTH := Vector2(0.45, 1.0)
const GASH_RISE := Vector2(2.4, 6.0)
const GASH_SHEET := Vector2(4.0, 1.4)
const GASH_OFF := 0.25
## A stretch of the gash GASH_DEEP or more under the sea throws DEEP_SHARE as hard and
## as high as one at the sea or over it.
const GASH_DEEP := 1.2
const DEEP_SHARE := 0.75
## Spray mist billows up over the sea as high as MIST_RISE, from the least gash to the
## most — over her rail for the least — in metres, as hard as GASH_STRENGTH, leaning
## MIST_LEAN out from her for every metre it climbs: seen standing off her side from
## along her decks.
const MIST_RISE := Vector2(6.0, 7.5)
const MIST_LEAN := 0.55
## Foam lies on the sea along the gash in stretches FROTH_STRETCH long, in metres, as
## many as GashFx has emitters for; as thick as FROTH_STRENGTH, from the least gash to
## the most.
const FROTH_STRETCH := 4.0
const FROTH_STRENGTH := Vector2(0.6, 1.0)
## A burst after the strike climbs FOLLOW_UP as high as the strike did there, as it
## dies down; over a stretch GASH_DEEP under, the boil spits SPITS high instead, at
## least and at most. The sea boils over the gash where it runs deeper than
## GASH_BOILS, in up to BOILS_ALONG places along it.
const FOLLOW_UP := 0.6
const SPITS := Vector2(0.5, 1.4)
const GASH_BOILS := 0.3
const BOILS_ALONG := 3

var _schedule: SinkSchedule
## The ship's structure, where the gash's line on her shell is read against her
## waterline; null for a ship without one.
var _structure: ShipStructure
## How big the gash is, 0…1 (size()).
var _size := 0.0
## The tick the iceberg struck, as its HOLED event told it, or -1 before it.
var _struck := -1


func _init(schedule: SinkSchedule, structure: ShipStructure) -> void:
	_schedule = schedule
	_structure = structure
	if schedule.damage() != null:
		_size = size(schedule.damage().area())


## How big a gash letting the sea in through [param area] m² looks: 0 for a scrape,
## GASH_AREA.x or less, to 1 for GASH_AREA.y or more, evenly on a log scale.
static func size(area: float) -> float:
	if area <= GASH_AREA.x:
		return 0.0
	return clampf(log(area / GASH_AREA.x) / log(GASH_AREA.y / GASH_AREA.x), 0.0, 1.0)


## The iceberg striking: along the gash, sheets of white water thrown up and out of
## it, spray mist billowing up over it, foam spreading on the sea along it, and the sea
## boiling over it where it runs deep.
func strike(tick: int, cues: Array[FxCue]) -> void:
	var damage := _schedule.damage()
	if damage == null or damage.trace.size() < 2 or _structure == null:
		return
	_struck = tick
	var trace := damage.trace
	var length := _length(trace)
	var sheet_length := lerpf(GASH_SHEET.x, GASH_SHEET.y, _size)
	var sheets := clampi(ceili(length / sheet_length), 1, GashFx.STRIKES)
	for index in sheets:
		var a := _along(trace, float(index) / sheets)
		var b := _along(trace, float(index + 1) / sheets)
		var middle := (a + b) * 0.5
		# Uneven, as the gash is: no two sheets alike.
		var wobble := 0.85 + 0.15 * sin((index + a.x) * 2.3)
		var sheet := _spray(FxCue.Kind.STRIKE, middle, _hardness(middle) * wobble, tick)
		sheet.rise = _rise(middle) * wobble
		sheet.position = _out(a, sheet.on_sea)
		sheet.end = _out(b, sheet.on_sea)
		cues.append(sheet)
	_mist(trace, mini(sheets, GashFx.MISTS), tick, cues)
	_froth(trace, clampi(ceili(length / FROTH_STRETCH), 1, GashFx.FROTHS), tick, cues)
	_boils(trace, length, tick, cues)


## For GASH_SECONDS after the strike, dying down: every GASH_TICKS a burst somewhere
## new along the gash — white water thrown up where it runs shallow, the boil spitting
## where it runs deep.
func bursts(tick: int, cues: Array[FxCue]) -> void:
	var since := tick - _struck
	if _struck < 0 or since <= 0:
		return
	if since > Ticks.from_seconds(GASH_SECONDS):
		_struck = -1
		return
	if since % GASH_TICKS != 0:
		return
	var fading := 1.0 - float(since) / Ticks.from_seconds(GASH_SECONDS)
	var turn := since / GASH_TICKS
	var at := _along(_schedule.damage().trace, fposmod(turn * 0.618034 + 0.15, 1.0))
	var burst := _spray(FxCue.Kind.SPURT, at, _hardness(at) * fading, tick)
	burst.rise = _rise(at) * FOLLOW_UP * fading
	if _shallow(at) <= 0.0:
		# Air bursting up through the boil: spits on the sea.
		burst.rise = lerpf(SPITS.x, SPITS.y, fposmod(turn * 0.382, 1.0)) * fading
		burst.toward = Vector3.UP
	cues.append(burst)


## Spray mist billowing up off [param trace], the gash, in [param stretches] stretches:
## from the sea against her, as high as the gash is big.
func _mist(trace: PackedVector3Array, stretches: int, tick: int, cues: Array[FxCue]) -> void:
	for index in stretches:
		var a := _along(trace, float(index) / stretches)
		var b := _along(trace, float(index + 1) / stretches)
		var mist := FxCue.new(FxCue.Kind.MIST, tick, _at_waterline(a, GASH_OFF))
		mist.end = _at_waterline(b, GASH_OFF)
		mist.on_sea = true
		mist.strength = lerpf(GASH_STRENGTH.x, GASH_STRENGTH.y, _size)
		mist.rise = lerpf(MIST_RISE.x, MIST_RISE.y, _size)
		mist.toward = Vector3(0.0, 1.0, signf(a.z) * MIST_LEAN).normalized()
		cues.append(mist)


## Foam on the sea against her along [param trace], the gash, in [param stretches]
## stretches, for GASH_SECONDS, drifting off her side.
func _froth(trace: PackedVector3Array, stretches: int, tick: int, cues: Array[FxCue]) -> void:
	for index in stretches:
		var a := _along(trace, float(index) / stretches)
		var b := _along(trace, float(index + 1) / stretches)
		var froth := FxCue.new(FxCue.Kind.FROTH, tick, _at_waterline(a, GASH_OFF))
		froth.end = _at_waterline(b, GASH_OFF)
		froth.on_sea = true
		froth.strength = lerpf(FROTH_STRENGTH.x, FROTH_STRENGTH.y, _size)
		froth.seconds = GASH_SECONDS
		froth.toward = Vector3(0.0, 0.0, signf(a.z))
		cues.append(froth)


## The sea boiling over [param trace], the gash, [param length] long, where it runs
## deeper than GASH_BOILS: in up to BOILS_ALONG places along it, one for a short one.
func _boils(trace: PackedVector3Array, length: float, tick: int, cues: Array[FxCue]) -> void:
	for place in BOILS_ALONG:
		var at := _along(trace, (place + 0.5) / BOILS_ALONG)
		var depth := _structure.waterline_y - at.y
		if depth < GASH_BOILS or (length < GASH_SHEET.x and place != BOILS_ALONG / 2):
			continue
		var boil := FxCue.new(FxCue.Kind.BUBBLES, tick, _at_waterline(at, 0.6))
		boil.on_sea = true
		boil.radius = clampf(length / BOILS_ALONG * 0.5, 0.8, 2.5)
		boil.seconds = GASH_SECONDS * clampf(depth / GASH_DEEP, 0.5, 1.0)
		boil.strength = 1.0
		cues.append(boil)


## How near the sea the gash runs at [param point], on it: 1 at the sea or over it,
## nothing GASH_DEEP under.
func _shallow(point: Vector3) -> float:
	return clampf(1.0 - (_structure.waterline_y - point.y) / GASH_DEEP, 0.0, 1.0)


## How hard the gash throws white water up at [param point], on it, as it strikes:
## harder the bigger it is, and the shallower it runs there.
func _hardness(point: Vector3) -> float:
	var strength := lerpf(GASH_STRENGTH.x, GASH_STRENGTH.y, _size)
	return strength * lerpf(DEEP_SHARE, 1.0, _shallow(point))


## How high over the sea the strike throws white water at [param point], on it.
func _rise(point: Vector3) -> float:
	return lerpf(GASH_RISE.x, GASH_RISE.y, _size) * lerpf(DEEP_SHARE, 1.0, _shallow(point))


## White water of [param kind] thrown up and out of the gash at [param point], on it,
## [param strength] hard: from her shell where it runs over the sea, from the sea
## outboard of her where it runs under it.
func _spray(kind: FxCue.Kind, point: Vector3, strength: float, tick: int) -> FxCue:
	var under := point.y < _structure.waterline_y
	var spray := FxCue.new(kind, tick, _out(point, under))
	spray.on_sea = under
	spray.strength = clampf(strength, 0.0, 1.0)
	spray.toward = Vector3(0.0, 2.0, signf(point.z)).normalized()
	return spray


## Where white water leaves the gash at [param point], on it: GASH_OFF outboard of her
## shell there, or of the sea against her shell over it where the point, or the stretch
## it is thrown from, [param under] the sea, runs under it.
func _out(point: Vector3, under: bool) -> Vector3:
	if under or point.y < _structure.waterline_y:
		return _at_waterline(point, GASH_OFF)
	return point + Vector3(0.0, 0.0, signf(point.z) * GASH_OFF)


## The sea against her shell over [param point] of the gash, [param off] outboard of it.
func _at_waterline(point: Vector3, off: float) -> Vector3:
	var side := signf(point.z)
	var waterline := _structure.waterline_y
	var section := _structure.section_at(point.x)
	var shell := section.shell_at(waterline, int(side)) if section != null else NAN
	var z := point.z if is_nan(shell) else shell
	return Vector3(point.x, waterline, z + side * off)


## How long the line through [param points] is.
static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for index in points.size() - 1:
		total += points[index].distance_to(points[index + 1])
	return total


## The point [param share] of the way along the line through [param points].
static func _along(points: PackedVector3Array, share: float) -> Vector3:
	var left := _length(points) * share
	for index in points.size() - 1:
		var step := points[index].distance_to(points[index + 1])
		if left <= step and step > 0.0:
			return points[index].lerp(points[index + 1], left / step)
		left -= step
	return points[points.size() - 1]
