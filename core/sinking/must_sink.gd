class_name MustSink
extends RefCounted
## Every match's hit sinks her (§5b.1, your answer to Q18): the hit a match plays is
## chosen before it starts, all from the sinking stream in a fixed order. Draw a hit —
## the gash, then the doors that jam and the openings left open, and after the first
## hit's, once, the sea's wave height where the scenario has waves; throw it out at once
## when the quick check finds her afloat with dry deck to spare and stable; bake the one
## that passes, and draw again while the bake leaves her afloat; at most quick_redraws
## thrown out and bakes baked. Then a fixed fallback, drawing nothing: the last hit made
## heavier rung by rung — twice as wide and one cell longer each, fore and aft in turn —
## until the quick check says she founders, baked once; and last her sure hit, with
## every door and porthole shut. This chooses where she is struck and never what
## happens after: every draw comes before the accepted bake (D4), so the sinking stays
## a pure function of (ship, scenario, seed). An explicit hit bypasses it: baked as
## given (given()), in a still sea, it may leave her afloat.


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
	## Whether it came baked from the host (replay): drawn again here, never baked.
	var received := false


## Where a timeline's origin (SinkTimeline.origin) keeps each count of its Choice, and
## the hit's moment, start and width and the sea's wave height, each as a 64-bit
## float's bits — a still sea's origin ends at the width, so it reads as it did before
## there were waves.
enum Origin { DRAWS, THROWN, BAKES, RUNG, SURE, MOMENT, START, WIDTH, WAVE_HEIGHT }


## The hit [param structure]'s match under [param scenario] plays, drawn from
## [param sink_stream], with [param sea]'s physics: Choosing run straight through.
static func choose(
	structure: ShipStructure,
	scenario: SinkScenario,
	sink_stream: RandomNumberGenerator,
	sea: SeaPhysics
) -> Choice:
	var choosing := Choosing.new(structure, scenario, sink_stream, sea)
	choosing.work(1 << 62)
	return choosing.choice()


## Whether a match plays a bake that ends [param end]: she is gone within the cap, or —
## a coast scenario's wreck — rests on the bottom with part of her dry, where the match
## goes on until one seat is left (Q21). Afloat — upright, or upside down on air still
## leaking at the cap — it draws again.
static func played(end: SinkTimeline.End) -> bool:
	return end == SinkTimeline.End.GONE or end == SinkTimeline.End.AGROUND


## [param scenario]'s explicit hit on [param structure], baked as given under
## [param sea]: past the rule, so it may leave her afloat.
static func given(structure: ShipStructure, scenario: SinkScenario, sea: SeaPhysics) -> Choice:
	var choosing := Choosing.new(structure, scenario, null, sea)
	choosing.work(1 << 62)
	return choosing.choice()


## The Choice [param timeline] — baked by the host, with its origin — was baked from,
## drawn again here from [param sink_stream] as the host drew it, but never baked or
## quick-checked: the hits it drew, then the fallback's rungs or the sure hit as the
## origin says, the doors and openings with them. Null when the hit drawn is not the
## one the origin names: a client that cannot draw the host's hit does not play its
## timeline (D4, D11).
static func replay(
	structure: ShipStructure,
	scenario: SinkScenario,
	sink_stream: RandomNumberGenerator,
	timeline: SinkTimeline
) -> Choice:
	var choice := Choice.new()
	choice.timeline = timeline
	choice.received = true
	var bands := scenario.hit if scenario.hit != null else HitBands.new()
	if scenario.explicit_hit != null:
		choice.hit = scenario.explicit_hit
		choice.damage = HitMapper.map_explicit(choice.hit, structure, bands)
		return choice
	var origin := timeline.origin
	if origin.size() < Origin.WAVE_HEIGHT or origin[Origin.DRAWS] < 1:
		return null
	var wave_height := 0.0
	for draw in origin[Origin.DRAWS]:
		choice.hit = IcebergHit.draw(bands, sink_stream)
		choice.damage = HitMapper.map(choice.hit, structure, bands, sink_stream)
		if draw == 0:
			wave_height = scenario.draw_wave_height(sink_stream)
	choice.draws = origin[Origin.DRAWS]
	choice.thrown = origin[Origin.THROWN]
	choice.bakes = origin[Origin.BAKES]
	choice.rung = origin[Origin.RUNG]
	choice.sure = origin[Origin.SURE] == 1
	var drawn := choice.hit
	if choice.sure:
		choice.hit = structure.sure_hit.duplicate()
		choice.hit.moment = drawn.moment
		choice.damage = HitMapper.map_explicit(choice.hit, structure, bands)
	elif choice.rung > 0:
		var weighted := drawn
		for rung in range(1, choice.rung + 1):
			weighted = heavier(weighted, structure, rung)
		weighted.jammed = choice.damage.jammed.duplicate()
		weighted.left_open = choice.damage.left_open.duplicate()
		choice.hit = weighted
		choice.damage = HitMapper.map_explicit(weighted, structure, bands)
	choice.damage.wave_height = wave_height
	if origin.slice(Origin.MOMENT) != _hit_bits(choice):
		return null
	return choice


## [param choice]'s counts, its hit's moment, start and width and its sea's wave
## height, as a timeline's origin keeps them.
static func origin_of(choice: Choice) -> PackedInt64Array:
	var origin := PackedInt64Array(
		[choice.draws, choice.thrown, choice.bakes, choice.rung, 1 if choice.sure else 0]
	)
	origin.append_array(_hit_bits(choice))
	return origin


## [param choice]'s hit's moment, start and width, then its sea's wave height but for a
## still sea's, as 64-bit floats' bits.
static func _hit_bits(choice: Choice) -> PackedInt64Array:
	var hit := choice.hit
	var numbers := PackedFloat64Array([hit.moment, hit.start_x, hit.width])
	if choice.damage.wave_height != 0.0:
		numbers.append(choice.damage.wave_height)
	return numbers.to_byte_array().to_int64_array()


## The must-sink rule a slice at a time (R20): work() takes as many of the bakes' steps
## as it is given, so a scene can spread the rule across frames, and choose() runs it
## straight through — the same draws and bakes either way, in the same order. Draw a
## hit; throw it out when the quick check finds her afloat; bake the one that passes,
## and draw again while the bake leaves her afloat, within quick_redraws and bakes; then
## the fallback's rungs, the first the quick check founders on baked; then the sure hit,
## with every door and porthole shut. An explicit hit is baked once, as given.
class Choosing:
	enum Stage { DRAWING, BAKING, RUNGS, BAKING_RUNG, SURE, BAKING_SURE, GIVEN, DONE }

	var _structure: ShipStructure
	var _scenario: SinkScenario
	var _stream: RandomNumberGenerator
	var _sea: SeaPhysics
	var _bands: HitBands
	var _hull: LevelHull
	var _motion: ShipMotion
	var _stage := Stage.DRAWING
	## The draws' Choice, the fallback's being baked, and the one chosen once done.
	var _drawn := Choice.new()
	var _tried: Choice
	var _chosen: Choice
	var _weighted: IcebergHit
	var _rung := 0
	## The sea's wave height, drawn after the first hit's draws: every hit's damage is
	## struck in it.
	var _wave_height := 0.0
	var _bake: SinkBake
	## The steps every bake has taken so far.
	var _steps := 0

	## The rule for [param structure] under [param scenario], drawing from
	## [param sink_stream] — none for an explicit hit — with [param sea]'s physics.
	func _init(
		structure: ShipStructure,
		scenario: SinkScenario,
		sink_stream: RandomNumberGenerator,
		sea: SeaPhysics
	) -> void:
		_structure = structure
		_scenario = scenario
		_stream = sink_stream
		_sea = sea
		_bands = scenario.hit if scenario.hit != null else HitBands.new()
		_hull = LevelHull.new(structure.sections)
		if scenario.explicit_hit != null:
			_drawn.hit = scenario.explicit_hit
			_drawn.damage = HitMapper.map_explicit(_drawn.hit, structure, _bands)
			_start(_drawn.damage)
			_stage = Stage.GIVEN
			return
		var own := structure.total_mass() / sea.sea_density
		_motion = ShipMotion.new(structure, sea, _hull.height_of(own))

	## Goes on for up to [param steps] of the bakes' steps; whether it is done.
	func work(steps: int) -> bool:
		var left := steps
		while _stage != Stage.DONE and left > 0:
			if _bake != null:
				var before := _bake.steps()
				_bake.run(left)
				left -= _bake.steps() - before
				_steps += _bake.steps() - before
				if not _bake.is_done():
					break
			_advance()
		return _stage == Stage.DONE

	func is_done() -> bool:
		return _stage == Stage.DONE

	## The steps its bakes have taken so far.
	func steps() -> int:
		return _steps

	## What it chose, once done; null before.
	func choice() -> Choice:
		return _chosen

	## Moves on from where the rule stands — a bake just over, or a draw to make — to
	## the next bake, or to its end.
	func _advance() -> void:
		match _stage:
			Stage.DRAWING:
				_draw()
			Stage.BAKING:
				_drawn.bakes += 1
				if MustSink.played(_bake.end()):
					_finish(_drawn)
				elif _drawn.bakes >= _scenario.bakes:
					_to_rungs()
				else:
					_bake = null
					_stage = Stage.DRAWING
			Stage.RUNGS:
				_next_rung()
			Stage.BAKING_RUNG:
				_tried.bakes += 1
				if MustSink.played(_bake.end()):
					_tried.bakes += _drawn.bakes
					_tried.rung = _rung
					_finish(_tried)
				else:
					_drawn.bakes += _tried.bakes
					_stage = Stage.SURE
			Stage.SURE:
				_tried = Choice.new()
				_tried.hit = _structure.sure_hit.duplicate()
				_tried.hit.moment = _drawn.hit.moment
				_tried.damage = HitMapper.map_explicit(_tried.hit, _structure, _bands)
				_tried.damage.wave_height = _wave_height
				_start(_tried.damage)
				_stage = Stage.BAKING_SURE
			Stage.BAKING_SURE:
				_tried.bakes += 1 + _drawn.bakes
				_tried.sure = true
				_finish(_tried)
			Stage.GIVEN:
				_drawn.bakes += 1
				_finish(_drawn)

	## Draws a hit: thrown out at once where the quick check finds her afloat — on to the
	## fallback once quick_redraws are — else baked.
	func _draw() -> void:
		_drawn.hit = IcebergHit.draw(_bands, _stream)
		_drawn.damage = HitMapper.map(_drawn.hit, _structure, _bands, _stream)
		if _drawn.draws == 0:
			_wave_height = _scenario.draw_wave_height(_stream)
		_drawn.damage.wave_height = _wave_height
		_drawn.draws += 1
		var spare := _scenario.spare_deck
		var failing := _scenario.quick_failing
		if MustSink.founders(_structure, _drawn.damage, _hull, _sea, spare, failing, _motion):
			_start(_drawn.damage)
			_stage = Stage.BAKING
			return
		_drawn.thrown += 1
		if _drawn.thrown >= _scenario.quick_redraws:
			_to_rungs()

	func _to_rungs() -> void:
		_bake = null
		_weighted = _drawn.hit
		_rung = 0
		_stage = Stage.RUNGS

	## The next rung heavier, baked once the quick check says she founders on it; past
	## the last rung, the sure hit.
	func _next_rung() -> void:
		while _rung < _scenario.rungs:
			_rung += 1
			_weighted = MustSink.heavier(_weighted, _structure, _rung)
			_weighted.jammed = _drawn.damage.jammed.duplicate()
			_weighted.left_open = _drawn.damage.left_open.duplicate()
			var damage := HitMapper.map_explicit(_weighted, _structure, _bands)
			damage.wave_height = _wave_height
			var spare := _scenario.spare_deck
			var failing := _scenario.quick_failing
			if MustSink.founders(_structure, damage, _hull, _sea, spare, failing, _motion):
				_tried = Choice.new()
				_tried.hit = _weighted
				_tried.damage = damage
				_start(damage)
				_stage = Stage.BAKING_RUNG
				return
		_stage = Stage.SURE

	func _start(damage: HitDamage) -> void:
		damage.sea_depth = _scenario.sea_depth
		_bake = SinkBake.new(SinkStepper.new(_structure, damage, _sea), _sea, _scenario.bake_cap)

	## Ends the rule on [param chosen]: its bake made its timeline — compacted only now,
	## for the one bake kept — stamped with how it was come by.
	func _finish(chosen: Choice) -> void:
		chosen.draws = _drawn.draws
		chosen.thrown = _drawn.thrown
		chosen.timeline = _bake.timeline()
		chosen.timeline.origin = MustSink.origin_of(chosen)
		_chosen = chosen
		_bake = null
		_stage = Stage.DONE


## The quick check (§5b.1), without the bake: whether, with every cell the gash opens
## flooded to the sea and then each cell that would overflow from those in turn — over
## the bottom of any opening left open, from a flooded cell or the sea — she founders:
## no level of the sea holds her, or she floats with less than [param spare] of dry
## main deck, or unstable (GM, less what her loose water costs, not above 0). With the
## attitude stage on she floats trimmed and listed by where that water sits — the trim
## and list her lift's stiffness (ShipMotion, [param motion]) gives the turn the water
## puts on her, to first order — and each opening and her deck's corners are judged at
## that attitude. With the failures stage on (SH31) a shut door, hatch, porthole or
## window that can fail, and every panel of her watertight walls, passes water once it
## stands under [param failing] of the least head it leaks or gives way at
## (SinkFailures), as the physics would let it through. A leak — a limber hole, a hold's
## side wall — floods its cell over hours where the rest floods in minutes: the water
## spreads first by every other way, then by the leaks too, and she is judged at every
## state it passes through — listed toward her gash while the far side waits on its leak,
## as much as at the end. Only a hit she floats on, stable, with deck to spare at every
## one of them is ever thrown out: the bake would leave her afloat too.
static func founders(
	structure: ShipStructure,
	damage: HitDamage,
	hull: LevelHull,
	sea: SeaPhysics,
	spare: float,
	failing: float,
	motion: ShipMotion = null
) -> bool:
	if sea.attitude and motion == null:
		motion = ShipMotion.new(structure, sea, hull.height_of(_own(structure, sea)))
	var count := structure.cells.size()
	var flooded := PackedByteArray()
	flooded.resize(count)
	for opening: ShipOpening in damage.openings:
		flooded[structure.cell_named(opening.joins[0])] = 1
	var ways := _ways(structure, damage, failing if sea.failures else 0.0)
	var own := _own(structure, sea)
	var tilt := PackedFloat64Array([0.0, 0.0, 0.0])
	for leaks: bool in [false, true]:
		var changed := true
		while changed:
			var level := _level(structure, sea, hull, flooded, own)
			if is_inf(level):
				return true
			if motion != null:
				tilt = _tilt(structure, sea, motion, flooded, level)
			if _short(structure, sea, flooded, level, tilt, motion, spare):
				return true
			changed = false
			for way: Array in ways:
				if (way[4] and not leaks) or _clearance(way[2], tilt, motion, level) >= -way[3]:
					continue
				var first: int = way[0]
				var second: int = way[1]
				var first_wet := first == SinkStepper.OUTSIDE or flooded[first] == 1
				var second_wet := second == SinkStepper.OUTSIDE or flooded[second] == 1
				if first_wet != second_wet:
					flooded[second if first_wet else first] = 1
					changed = true
	return false


## Whether she founders floating with every [param flooded] cell flooded to the sea at
## [param level], turned by [param tilt] (_tilt): less than [param spare] of her main
## deck dry, or unstable.
static func _short(
	structure: ShipStructure,
	sea: SeaPhysics,
	flooded: PackedByteArray,
	level: float,
	tilt: PackedFloat64Array,
	motion: ShipMotion,
	spare: float
) -> bool:
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
## sides — a cell, or SinkStepper.OUTSIDE — its least and greatest corners, the depth
## of water over its foot it passes under — none for one open — and whether it is a leak.
## A door the ship shuts is shut, but one that jammed; while [param failing] is over 0, a
## shut one and her walls' panels pass under that share of the least head each leaks or
## gives way at.
static func _ways(structure: ShipStructure, damage: HitDamage, failing: float) -> Array[Array]:
	var ways: Array[Array] = []
	var openings: Array[ShipOpening] = structure.openings.duplicate()
	openings.append_array(damage.openings)
	if failing > 0.0:
		openings.append_array(SinkFailures.panels(structure))
	for opening: ShipOpening in openings:
		var shut := (
			opening.starts == ShipOpening.Start.SHUT and not opening.name in damage.left_open
		)
		shut = shut or opening.shuts_at_hit and not opening.name in damage.jammed
		var under := 0.0
		if shut:
			var kept := SinkFailures.kept_share(structure, damage, opening)
			under = opening.collapse_head * kept if opening.collapse_head > 0.0 else INF
			var hinged := not opening.opens_toward.is_empty()
			if opening.leak_head > 0.0 and (opening.leak_area > 0.0 or hinged):
				under = minf(under, opening.leak_head)
			if failing <= 0.0 or is_inf(under):
				continue
			under *= failing
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
		ways.append([sides[0], sides[1], corners, under, opening.kind == ShipOpening.Kind.LEAK])
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
