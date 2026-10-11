class_name GashPlanner
extends RefCounted
## The iceberg's strike as seen (FxPlanner): the gash SinkSchedule has her struck with
## (D13) — its line on her shell and the sea it lets in — read against her waterline
## and turned into cues. As HOLED strikes, white water bursts up and out of all of
## the gash at once, spray mist billows up her side over it, foam spreads on the sea
## along it and the sea boils over it where it runs deep; then, for GASH_SECONDS and
## dying down, white water bursts up somewhere new along it every GASH_TICKS. The
## bigger the gash, the harder, higher and thicker all of it. Inside her (breach()),
## the rent the iceberg tore along it shows from the strike on, and the sea jets in
## through it wherever it opens a room people walk in, as hard as the sea outside
## stands over the room's water, dying into a boil over it once the room's water tops
## it, and gone once that stands level with the sea: what the pose answers at each
## tick, so a replay shows what the live match did. Presentation state only; nothing
## it does reaches the sim (D5, D12).

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
## Inside her, every BREACH_TICKS from the strike, the sea comes in through each stretch
## of the gash into a cell whose water is drawn — a room people walk in, never a void —
## so long as the sea outside stands LEVEL or more, in metres, over the room's water
## there; a stretch over the sea throws nothing.
const BREACH_TICKS := 6
const LEVEL := 0.05
## The head over the room's water at which the sea jets in at its hardest, in metres:
## how hard goes as the speed it comes in at does, the head's root.
const FULL_HEAD := 1.5
## How thick a sheet the sea jets in as, from the least gash to the most (size()), in
## metres: a thin sheet of spray for a scrape, a wall of water for the worst; leaving
## the gash leaning JET_DROP down for every metre in, and thrown no less than JET_LEAST
## across the room.
const JET_SHEET := Vector2(0.06, 0.7)
const JET_DROP := 0.15
const JET_LEAST := 0.3
## The rent in her plating along each stretch of the gash: on the room's lining —
## RENT_PROUD in front of the wall between the room and her shell, or RENT_IN in from
## her shell where none stands — on her hull RENT_OUT out from it, and never less than
## RENT_LEAST tall. The sea jets in from JET_PROUD in front of that lining, and boils up
## on the room's water BOIL_IN in from it.
const RENT_IN := 0.3
const RENT_PROUD := 0.02
const RENT_OUT := 0.03
const RENT_LEAST := 0.15
const JET_PROUD := 0.05
const BOIL_IN := 0.3

var _schedule: SinkSchedule
## The ship's structure, where the gash's line on her shell is read against her
## waterline; null for a ship without one.
var _structure: ShipStructure
## How big the gash is, 0…1 (size()).
var _size := 0.0
## The tick the iceberg struck, as its HOLED event told it, or -1 before it.
var _struck := -1
## Per cell of her structure, 1 where its water is drawn (InnerWater.boxes): a room
## people walk in.
var _drawn := PackedByteArray()
## Whether the rent along the gash has been told.
var _torn := false
## Per stretch of the gash, how far across her the room's lining stands in front of it:
## the inboard face of the wall between the room and her shell there, or NAN for none.
var _linings := PackedFloat64Array()
## The atmosphere's pressure as metres of sea: what a pocket's air (ShipPose.pockets)
## squeezes past.
var _atmosphere := 0.0


## Plans [param schedule]'s strike on [param structure], whose cells' water is drawn
## where [param drawn] has 1 for them, in her cells' order, and whose rooms are walled
## by [param walls].
func _init(
	schedule: SinkSchedule,
	structure: ShipStructure,
	drawn := PackedByteArray(),
	walls: Array[ShipBlocker] = []
) -> void:
	_schedule = schedule
	_structure = structure
	_drawn = drawn
	var sea := SeaPhysics.load_default()
	_atmosphere = sea.air_pressure / (sea.sea_density * sea.gravity)
	if schedule.damage() != null:
		_size = size(schedule.damage().area())
		for opening: ShipOpening in schedule.damage().openings:
			_linings.append(_lining(opening, walls))


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


## Inside her, over the step through the sim's ticks from [param from_tick] up to
## [param tick], with her standing as [param pose] has her at [param tick]: once, from
## the strike on, the rent along the gash; and on every BREACH_TICKS from the strike
## until she has gone, the sea coming in through each stretch of it that opens a room
## people walk in.
func breach(from_tick: int, tick: int, pose: ShipPose, cues: Array[FxCue]) -> void:
	var damage := _schedule.damage()
	var struck := _schedule.hit_tick()
	if damage == null or _structure == null or struck < 0 or tick <= struck:
		return
	if not _torn:
		_torn = true
		_rents(damage, struck, cues)
	var beat := struck + (tick - 1 - struck) / BREACH_TICKS * BREACH_TICKS
	# A broken hull's pieces keep cells of their own, and once she has gone the gash is
	# the least of it.
	var whole := pose.pieces.is_empty() and pose.levels.size() == _structure.cells.size()
	var gone := _schedule.gone_tick()
	if beat < from_tick or not whole or (gone >= 0 and tick >= gone):
		return
	for index in damage.openings.size():
		_inrush(index, damage.openings[index], pose, tick, cues)


## The sea coming in through [param opening], the gash's [param index]th stretch, under
## [param pose], where it opens a room people walk in: jetting across the room from the
## part of it under the sea and over the room's water while that stands under its top;
## once the room's water tops it, boiling up over it; nothing once the sea outside
## stands no more than LEVEL over the room's water.
func _inrush(
	index: int, opening: ShipOpening, pose: ShipPose, tick: int, cues: Array[FxCue]
) -> void:
	var cell := _structure.cell_named(opening.joins[0])
	if cell < 0 or cell >= _drawn.size() or _drawn[cell] == 0:
		return
	var half := opening.size * 0.5
	var low := pose.world_height(opening.centre - Vector3(0.0, half.y, 0.0))
	var high := pose.world_height(opening.centre + Vector3(0.0, half.y, 0.0))
	var inside := pose.levels[cell]
	var head := -maxf(pushing(pose, cell), low)
	if head < LEVEL:
		return
	var side := float(_schedule.hit().side)
	# In front of the room's lining; where none stands, inboard of her shell as
	# InnerWater hangs a pour off it.
	var z := opening.centre.z - side * InnerWater.OFF_SHELL
	if not is_nan(_linings[index]):
		z = _linings[index] - side * JET_PROUD
	var a := Vector3(opening.centre.x - half.x, 0.0, z)
	var b := a + Vector3(opening.size.x, 0.0, 0.0)
	var strength := clampf(sqrt(head / FULL_HEAD), 0.0, 1.0)
	var cue: FxCue
	if inside < high:
		var from := (maxf(inside, low) + minf(0.0, high)) * 0.5
		a.y = pose.height_of(from, a)
		b.y = pose.height_of(from, b)
		cue = FxCue.new(FxCue.Kind.JET, tick, a)
		cue.toward = Vector3(0.0, -JET_DROP, -side).normalized()
		cue.radius = lerpf(JET_SHEET.x, JET_SHEET.y, size(opening.area))
		# Thrown as far as its speed carries it falling to the room's floor or water.
		var room := _structure.cells[cell]
		var middle := (a + b) * 0.5
		var floor := pose.world_height(Vector3(middle.x, room.low.y, middle.z))
		var fall := maxf(from - maxf(inside, floor), 0.05)
		var across := room.high.z - room.low.z - InnerWater.OFF_SHELL
		cue.rise = clampf(2.0 * sqrt(head * fall), JET_LEAST, maxf(across, JET_LEAST))
	else:
		a.z -= side * BOIL_IN
		b.z = a.z
		a.y = pose.height_of(inside, a)
		b.y = pose.height_of(inside, b)
		cue = FxCue.new(FxCue.Kind.BOIL, tick, a)
	cue.end = b
	cue.strength = strength
	cue.source = index
	cues.append(cue)


## The world height the water in [param cell] pushes back from under [param pose]: its
## level, and over it the squeeze of the air trapped in it, where it is a pocket's.
func pushing(pose: ShipPose, cell: int) -> float:
	var level := pose.levels[cell]
	if cell < pose.pockets.size() and pose.pockets[cell] > 0.0:
		level += maxf(pose.pockets[cell] - _atmosphere, 0.0)
	return level


## The rent the iceberg tore along every stretch of [param damage]'s gash at
## [param struck]: on the room's lining wherever a stretch opens a room people walk in,
## and on her hull wherever one to the sea stood over it as she was struck.
func _rents(damage: HitDamage, struck: int, cues: Array[FxCue]) -> void:
	var pose := _schedule.pose_at(struck)
	var side := float(_schedule.hit().side)
	for index in damage.openings.size():
		var opening := damage.openings[index]
		var half := opening.size * 0.5
		var a := opening.centre - Vector3(half.x, 0.0, 0.0)
		var b := opening.centre + Vector3(half.x, 0.0, 0.0)
		var cell := _structure.cell_named(opening.joins[0])
		if cell >= 0 and cell < _drawn.size() and _drawn[cell] == 1:
			var lining := _linings[index]
			var inboard := RENT_IN
			if not is_nan(lining):
				inboard = side * (opening.centre.z - lining) + RENT_PROUD
			cues.append(_rent(a, b, half.y, -side * inboard, struck))
		if opening.joins[1] != ShipOpening.SEA:
			continue
		var top := opening.centre.y + half.y
		var sea := pose.height_of(0.0, opening.centre)
		if sea >= top:
			continue
		var bottom := maxf(opening.centre.y - half.y, sea)
		a.y = (top + bottom) * 0.5
		b.y = a.y
		cues.append(_rent(a, b, (top - bottom) * 0.5, side * RENT_OUT, struck))


## The room's lining in front of [param opening], a stretch of the gash: the inboard
## face of the outermost of [param walls] standing between the middle of its cell and
## her shell at its middle and its height, or NAN where none does.
func _lining(opening: ShipOpening, walls: Array[ShipBlocker]) -> float:
	var cell := _structure.cell_named(opening.joins[0])
	if cell < 0 or _schedule.hit() == null:
		return NAN
	var side := float(_schedule.hit().side)
	var middle := (_structure.cells[cell].low.z + _structure.cells[cell].high.z) * 0.5
	var found := NAN
	for wall: ShipBlocker in walls:
		var area := wall.area
		if wall.bottom > opening.centre.y or wall.top < opening.centre.y:
			continue
		if opening.centre.x < area.position.x or opening.centre.x > area.end.x:
			continue
		var inner := area.position.y if side > 0.0 else area.end.y
		var between := side * (inner - middle) > 0.0 and side * (inner - opening.centre.z) <= 0.0
		if between and (is_nan(found) or side * inner > side * found):
			found = inner
	return found


## A rent from [param a] to [param b], on her shell, [param half] as tall either side of
## them, moved [param off] across her — in, onto a room's lining, or out, onto her hull
## — and facing that way.
static func _rent(a: Vector3, b: Vector3, half: float, off: float, tick: int) -> FxCue:
	var across := Vector3(0.0, 0.0, off)
	var rent := FxCue.new(FxCue.Kind.RENT, tick, a + across)
	rent.end = b + across
	rent.radius = maxf(half, RENT_LEAST * 0.5)
	rent.toward = Vector3(0.0, 0.0, signf(off))
	return rent


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
