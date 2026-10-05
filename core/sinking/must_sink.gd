class_name MustSink
extends RefCounted
## Every match's hit sinks her (§5b.1, your answer to Q18): the hit a match plays is
## chosen before it starts, all from the sinking stream in a fixed order. Draw a hit —
## the gash, then the doors that jam and the openings left open; throw it out at once
## when the quick check finds her afloat with dry deck to spare and stable; bake the one
## that passes, and draw again while the bake leaves her afloat; at most quick_redraws
## thrown out and bakes baked. Then a fixed fallback, drawing nothing: the last hit made
## heavier rung by rung — twice as wide and one cell longer each, fore and aft in turn —
## until the quick check says she founders, baked once; and last her sure hit, with
## every door and porthole shut. This chooses where she is struck and never what
## happens after: every draw comes before the accepted bake (D4), so the sinking stays
## a pure function of (ship, scenario, seed). An explicit hit bypasses it: baked as
## given (given()), it may leave her afloat.


## What was chosen, and how it was come by.
class Choice:
	var hit: IcebergHit
	var damage: HitDamage
	var timeline: SinkTimeline
	## Hits drawn, those the quick check threw out, and bakes made, the accepted one's
	## among them.
	var draws := 0
	var thrown := 0
	var bakes := 0
	## The fallback's rung that was baked, 0 for none; and whether the sure hit was.
	var rung := 0
	var sure := false


## The hit [param structure]'s match under [param scenario] plays, drawn from
## [param sink_stream], with [param sea]'s physics.
static func choose(
	structure: ShipStructure,
	scenario: SinkScenario,
	sink_stream: RandomNumberGenerator,
	sea: SeaPhysics
) -> Choice:
	var choice := Choice.new()
	var hull := LevelHull.new(structure.sections)
	var motion := ShipMotion.new(structure, sea, hull.height_of(_own(structure, sea)))
	var bands := scenario.hit
	while true:
		choice.hit = IcebergHit.draw(bands, sink_stream)
		choice.damage = HitMapper.map(choice.hit, structure, bands, sink_stream)
		choice.draws += 1
		if not founders(structure, choice.damage, hull, sea, scenario.spare_deck, motion):
			choice.thrown += 1
			if choice.thrown >= scenario.quick_redraws:
				break
			continue
		if _accepts(choice, structure, scenario, sea):
			return choice
		if choice.bakes >= scenario.bakes:
			break
	var weighted := choice.hit
	for rung in range(1, scenario.rungs + 1):
		weighted = heavier(weighted, structure, rung)
		weighted.jammed = choice.damage.jammed.duplicate()
		weighted.left_open = choice.damage.left_open.duplicate()
		var damage := HitMapper.map_explicit(weighted, structure, bands)
		if founders(structure, damage, hull, sea, scenario.spare_deck, motion):
			var tried := Choice.new()
			tried.hit = weighted
			tried.damage = damage
			if _accepts(tried, structure, scenario, sea):
				tried.draws = choice.draws
				tried.thrown = choice.thrown
				tried.bakes += choice.bakes
				tried.rung = rung
				return tried
			choice.bakes += tried.bakes
			break
	var sure: IcebergHit = structure.sure_hit.duplicate()
	sure.moment = choice.hit.moment
	var last := Choice.new()
	last.hit = sure
	last.damage = HitMapper.map_explicit(sure, structure, bands)
	_accepts(last, structure, scenario, sea)
	last.draws = choice.draws
	last.thrown = choice.thrown
	last.bakes += choice.bakes
	last.sure = true
	return last


## [param scenario]'s explicit hit on [param structure], baked as given under
## [param sea]: past the rule, so it may leave her afloat.
static func given(structure: ShipStructure, scenario: SinkScenario, sea: SeaPhysics) -> Choice:
	var choice := Choice.new()
	choice.hit = scenario.explicit_hit
	var bands := scenario.hit if scenario.hit != null else HitBands.new()
	choice.damage = HitMapper.map_explicit(choice.hit, structure, bands)
	_accepts(choice, structure, scenario, sea)
	return choice


## Bakes [param choice]'s hit into it; whether she is gone by the cap.
static func _accepts(
	choice: Choice, structure: ShipStructure, scenario: SinkScenario, sea: SeaPhysics
) -> bool:
	var stepper := SinkStepper.new(structure, choice.damage, sea)
	choice.timeline = SinkTimeline.bake(stepper, sea, scenario.bake_cap)
	choice.bakes += 1
	return choice.timeline.is_gone()


## The quick check (§5b.1), without the bake: whether, with every cell the gash opens
## flooded to the sea and then each cell that would overflow from those in turn — over
## the bottom of any opening left open, from a flooded cell or the sea — she founders:
## no level of the sea holds her, or she floats with less than [param spare] of dry
## main deck, or unstable (GM, less what her loose water costs, not above 0). With the
## attitude stage on she floats trimmed and listed by where that water sits — the trim
## and list her lift's stiffness (ShipMotion, [param motion]) gives the turn the water
## puts on her, to first order — and each opening and her deck's corners are judged at
## that attitude. Only a hit she floats on, stable, with deck to spare is ever thrown
## out: the bake would leave her afloat too.
static func founders(
	structure: ShipStructure,
	damage: HitDamage,
	hull: LevelHull,
	sea: SeaPhysics,
	spare: float,
	motion: ShipMotion = null
) -> bool:
	if sea.attitude and motion == null:
		motion = ShipMotion.new(structure, sea, hull.height_of(_own(structure, sea)))
	var count := structure.cells.size()
	var flooded := PackedByteArray()
	flooded.resize(count)
	for opening: ShipOpening in damage.openings:
		flooded[structure.cell_named(opening.joins[0])] = 1
	var ways := _ways(structure, damage)
	var own := _own(structure, sea)
	var level := INF
	var tilt := PackedFloat64Array([0.0, 0.0, 0.0])
	var changed := true
	while changed:
		level = _level(structure, sea, hull, flooded, own)
		if is_inf(level):
			return true
		if motion != null:
			tilt = _tilt(structure, sea, motion, flooded, level)
		changed = false
		for way: Array in ways:
			if _clearance(way[2], tilt, motion, level) >= 0.0:
				continue
			var first: int = way[0]
			var second: int = way[1]
			var first_wet := first == SinkStepper.OUTSIDE or flooded[first] == 1
			var second_wet := second == SinkStepper.OUTSIDE or flooded[second] == 1
			if first_wet != second_wet:
				flooded[second if first_wet else first] = 1
				changed = true
	for cell: FloodCell in structure.cells:
		if cell.high.y != SinkTimeline.MAIN_DECK:
			continue
		for corner in 4:
			var x := float(cell.low.x if corner & 1 == 0 else cell.high.x)
			var z := float(cell.low.z if corner & 2 == 0 else cell.high.z)
			var deck := PackedFloat64Array([x, cell.high.y, z, x, cell.high.y, z])
			if _clearance(deck, tilt, motion, level) < spare:
				return true
	if level > -spare:
		return true
	return _stability(structure, sea, flooded, level) <= 0.0


## Her own weight as a volume of sea.
static func _own(structure: ShipStructure, sea: SeaPhysics) -> float:
	return structure.total_mass() / sea.sea_density


## How far the lowest of [param corners] — the least and greatest corners of a
## rectangle, x, y, z each — stands over the sea at [param level], turned by
## [param tilt] (_tilt) about her centre of mass; level without [param motion].
static func _clearance(
	corners: PackedFloat64Array, tilt: PackedFloat64Array, motion: ShipMotion, level: float
) -> float:
	if motion == null:
		return corners[1] - level
	var centre := motion.centre()
	var lowest := INF
	for corner in 4:
		var x := corners[0 if corner & 1 == 0 else 3] - centre[0]
		var z := corners[2 if corner & 2 == 0 else 5] - centre[2]
		lowest = minf(lowest, corners[1] + tilt[1] * x - tilt[2] * z)
	return lowest + tilt[0] - level


## The rise, pitch — bow up — and roll — starboard down — in radians, by which she
## floats with every [param flooded] cell flooded to the sea standing [param level] up
## her: her lift less those cells' water and less their surfaces, its push on her and
## its stiffness (ShipMotion) solved once — to first order, since she floats level
## when nothing is flooded.
static func _tilt(
	structure: ShipStructure,
	sea: SeaPhysics,
	motion: ShipMotion,
	flooded: PackedByteArray,
	level: float
) -> PackedFloat64Array:
	var upright := Attitude.level()
	var lift := motion.lift_under(upright, level)
	var centre := motion.centre()
	var volume := lift[ShipMotion.Lift.VOLUME]
	var moment := PackedFloat64Array(
		[
			volume * lift[ShipMotion.Lift.X],
			volume * lift[ShipMotion.Lift.Y],
			volume * lift[ShipMotion.Lift.Z],
		]
	)
	for index in flooded.size():
		if flooded[index] == 0:
			continue
		var cell := structure.cells[index]
		var water := _water(cell, sea, level)
		if water <= 0.0:
			continue
		var top := minf(level, cell.high.y)
		volume -= water
		moment[0] -= water * (float(cell.low.x) + cell.high.x) * 0.5
		moment[1] -= water * (float(cell.low.y) + top) * 0.5
		moment[2] -= water * (float(cell.low.z) + cell.high.z) * 0.5
		if level >= cell.high.y:
			continue
		# Its surface is no longer her waterplane: the sea's, not hers.
		var share := cell.permeability_in(sea) * cell.shape
		var x0 := float(cell.low.x) - centre[0]
		var x1 := float(cell.high.x) - centre[0]
		var z0 := float(cell.low.z) - centre[2]
		var z1 := float(cell.high.z) - centre[2]
		var plan := (x1 - x0) * (z1 - z0) * share
		lift[ShipMotion.Lift.AREA] -= plan
		lift[ShipMotion.Lift.AHEAD] -= plan * (x0 + x1) * 0.5
		lift[ShipMotion.Lift.ABEAM] -= plan * (z0 + z1) * 0.5
		lift[ShipMotion.Lift.AHEAD_AHEAD] -= plan * (x0 * x0 + x0 * x1 + x1 * x1) / 3.0
		lift[ShipMotion.Lift.AHEAD_ABEAM] -= plan * (x0 + x1) * (z0 + z1) * 0.25
		lift[ShipMotion.Lift.ABEAM_ABEAM] -= plan * (z0 * z0 + z0 * z1 + z1 * z1) / 3.0
	lift[ShipMotion.Lift.VOLUME] = volume
	for axis in 3:
		lift[ShipMotion.Lift.X + axis] = moment[axis] / volume
	return motion.rest_turn(upright, lift)


## Every opening of [param structure] water can pass after [param damage]: its two
## sides — a cell, or SinkStepper.OUTSIDE — and its least and greatest corners. A door the
## ship shuts is shut, but one that jammed.
static func _ways(structure: ShipStructure, damage: HitDamage) -> Array[Array]:
	var ways: Array[Array] = []
	var openings: Array[ShipOpening] = structure.openings.duplicate()
	openings.append_array(damage.openings)
	for opening: ShipOpening in openings:
		if opening.starts == ShipOpening.Start.SHUT and not opening.name in damage.left_open:
			continue
		if opening.shuts_at_hit and not opening.name in damage.jammed:
			continue
		var sides: Array[int] = []
		for place: StringName in opening.joins:
			var cell := structure.cell_named(place)
			sides.append(cell if cell != -1 else SinkStepper.OUTSIDE)
		var half := opening.size * 0.5
		var corners := PackedFloat64Array(
			[
				opening.centre.x - half.x,
				opening.centre.y - half.y,
				opening.centre.z - half.z,
				opening.centre.x + half.x,
				opening.centre.y + half.y,
				opening.centre.z + half.z,
			]
		)
		ways.append([sides[0], sides[1], corners])
	return ways


## The level sea at which she floats with every [param flooded] cell flooded to it, or
## INF where none holds her: her lift less the water in those cells is her own weight
## [param own] as sea.
static func _level(
	structure: ShipStructure, sea: SeaPhysics, hull: LevelHull, flooded: PackedByteArray, own: float
) -> float:
	var low := hull.bottom()
	var high := hull.top()
	if _spare(structure, sea, hull, flooded, own, high) < 0.0:
		return INF
	for _step in Hydrostatics.SOLVE_STEPS:
		var middle := (low + high) * 0.5
		if _spare(structure, sea, hull, flooded, own, middle) < 0.0:
			low = middle
		else:
			high = middle
	return high


## Her lift past her weight with the sea at [param height] and every [param flooded]
## cell flooded to it, as m³ of sea.
static func _spare(
	structure: ShipStructure,
	sea: SeaPhysics,
	hull: LevelHull,
	flooded: PackedByteArray,
	own: float,
	height: float
) -> float:
	var spare := hull.volume(height) - own
	for cell in flooded.size():
		if flooded[cell] == 1:
			spare -= _water(structure.cells[cell], sea, height)
	return spare


## The water [param cell] holds flooded to [param height], in m³.
static func _water(cell: FloodCell, sea: SeaPhysics, height: float) -> float:
	var depth := clampf(height - cell.low.y, 0.0, float(cell.high.y) - cell.low.y)
	var plan := (float(cell.high.x) - cell.low.x) * (float(cell.high.z) - cell.low.z)
	return plan * cell.permeability_in(sea) * cell.shape * depth


## Her GM afloat at the sea's [param height] with every [param flooded] cell flooded to
## it — its water as weight at its middle — less what its loose water costs her: each
## partly filled cell's surface turning with her (its breadth cubed by its length over
## twelve) over her displacement.
static func _stability(
	structure: ShipStructure, sea: SeaPhysics, flooded: PackedByteArray, height: float
) -> float:
	var displaced := structure.total_mass() / sea.sea_density
	var centre := structure.mass_centre()
	for axis in 3:
		centre[axis] *= displaced
	var loose := 0.0
	for index in flooded.size():
		if flooded[index] == 0:
			continue
		var cell := structure.cells[index]
		var water := _water(cell, sea, height)
		if water <= 0.0:
			continue
		var top := minf(height, cell.high.y)
		centre[0] += water * (float(cell.low.x) + cell.high.x) * 0.5
		centre[1] += water * (float(cell.low.y) + top) * 0.5
		centre[2] += water * (float(cell.low.z) + cell.high.z) * 0.5
		displaced += water
		if height < cell.high.y:
			var breadth := float(cell.high.z) - cell.low.z
			var length := float(cell.high.x) - cell.low.x
			loose += (
				cell.permeability_in(sea) * cell.shape * length * breadth * breadth * breadth / 12.0
			)
	for axis in 3:
		centre[axis] /= displaced
	var level := Hydrostatics.level(height)
	var upright := Hydrostatics.metacentric_height(structure.sections, displaced, centre, level)
	return upright - loose / displaced


## [param hit] one rung heavier (§5b.1): twice its equivalent width, and run on over
## the next cell along her past one end — forward on an odd [param rung], aft on an even
## one, and the other way once that end is at her hit zone's — so that the rungs spread
## the gash out from where it struck.
static func heavier(hit: IcebergHit, structure: ShipStructure, rung: int) -> IcebergHit:
	var made: IcebergHit = hit.duplicate()
	made.width = hit.width * 2.0
	var zone := structure.hit_zone_x
	var fore := minf(hit.end_x(), zone.y)
	var aft := maxf(hit.start_x, zone.x)
	var ends := PackedFloat64Array()
	for cell: FloodCell in structure.cells:
		ends.append_array(PackedFloat64Array([cell.low.x, cell.high.x]))
	ends.sort()
	var ahead := minf(_past(ends, fore, 2), zone.y)
	var astern := maxf(_before(ends, aft, 2), zone.x)
	var forward := rung % 2 == 1
	if forward and ahead <= fore or not forward and astern >= aft:
		forward = not forward
	if forward:
		made.start_x = aft
		made.length = ahead - aft
	else:
		made.start_x = astern
		made.length = fore - astern
	# Its depth along the line, kept at each end where it ran.
	made.depth_start = hit.depth_at(made.start_x)
	made.depth_end = hit.depth_at(made.start_x + made.length)
	return made


## The [param nth] of [param ends] past [param x], or INF.
static func _past(ends: PackedFloat64Array, x: float, nth: int) -> float:
	var found := 0
	var last := x
	for end: float in ends:
		if end > last + HitMapper.SLIVER:
			found += 1
			last = end
			if found == nth:
				return end
	return INF


## The [param nth] of [param ends] before [param x], or -INF.
static func _before(ends: PackedFloat64Array, x: float, nth: int) -> float:
	var found := 0
	var last := x
	for index in range(ends.size() - 1, -1, -1):
		if ends[index] < last - HitMapper.SLIVER:
			found += 1
			last = ends[index]
			if found == nth:
				return ends[index]
	return -INF
