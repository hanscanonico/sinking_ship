class_name SinkFailures
extends RefCounted
## Things that give way (§5b.1; steps 3, 9 and 10 of the physics; SH31): SinkStepper's
## failures stage. Every shut door, hatch, window and porthole that can fail, every
## watertight door once the ship has shut it, and every panel of a watertight wall —
## where it parts two cells — starts to leak at one head of water across it and gives way
## at another, for good: a collapse is one-way. A hinged door opens at its leak head with
## the flow and holds against it to its collapse head. A wall the hit ended beside, and
## every door in it, gives way at the share of its strength — its collapse head — the hit
## left it (HitDamage); its seals leak where they did.
## The heads are the stepper's, read across each opening as its flow reads them. It
## holds the rest of the fittings the physics fails too — her funnels (FunnelStays), her
## generator, emergency power, lights and pumps (ShipPower) — and her bending
## (HullGirder), and gives the bake how far she stands from every threshold, so a step
## lands where each is first passed (gaps): every failure is a threshold on the bake's
## own state, never a draw (D4). Only +, −, ×, ÷ and square roots on 64-bit floats run
## here (R21). Heads in metres of sea.

## Water this close to a threshold, in metres — or a sine, or a second — has reached
## it: the bake's millimetre (SinkBake.REACHED), so a step it lands there fails it.
const REACHED := 1e-3
## What an opening's failure leaves it (FloodState.opened): given way.
const GAVE_WAY := 1.0

## Per opening that can fail, in the stepper's order: its index there, the seconds the
## ship takes to shut it (SinkOpenings.open_share: under 0 for one shut from the start) —
## none fails before it is shut — the heads at which it leaks and gives way — 0 for
## never — its leak's share of its area, and for a hinged door the side it opens toward,
## 1 its second, -1 its first, 0 for none.
var _index := PackedInt32Array()
var _shut_time := PackedFloat64Array()
var _leak := PackedFloat64Array()
var _collapse := PackedFloat64Array()
var _leak_share := PackedFloat64Array()
var _toward := PackedInt32Array()
## Per opening that can fail, its first side and its second there: a cell, or the sea.
var _first := PackedInt32Array()
var _second := PackedInt32Array()
var _structure: ShipStructure
var _damage: HitDamage
var _air: SinkAir
## The heads across every watched opening at the state last asked of, and that state.
var _across := PackedFloat64Array()
var _across_state: FloodState
var _funnels: FunnelStays
var _power: ShipPower
var _girder: HullGirder


## The failures of [param structure] after a hit that did [param damage], under
## [param sea]'s constants, her pockets' pressures [param air]'s; her bending measured as
## [param motion] moves her, with the bending stage on and a strength to measure it
## against.
func _init(
	structure: ShipStructure, damage: HitDamage, sea: SeaPhysics, motion: ShipMotion, air: SinkAir
) -> void:
	_structure = structure
	_damage = damage
	_air = air
	_funnels = FunnelStays.new(structure, sea)
	_power = ShipPower.new(structure, sea)
	if sea.bending and motion != null and structure.strength != null:
		_girder = HullGirder.new(structure, sea, motion)


## What of [param structure] is shut and can fail after [param damage], in her data's
## order: every opening that starts shut, can fail and the hit did not leave open; then
## every panel of her watertight walls (panels). A door the ship shuts at the hit is
## among her openings already (watch).
static func shut(structure: ShipStructure, damage: HitDamage) -> Array[ShipOpening]:
	var found: Array[ShipOpening] = []
	for opening: ShipOpening in structure.openings:
		var left_open := opening.name in damage.left_open
		if opening.starts == ShipOpening.Start.SHUT and not left_open and opening.can_fail():
			found.append(opening)
	found.append_array(panels(structure))
	return found


## A panel for every pair of cells a watertight wall of [param structure] parts, where
## their faces meet on it: shut, leaking and giving way at the wall's heads.
static func panels(structure: ShipStructure) -> Array[ShipOpening]:
	var made: Array[ShipOpening] = []
	for wall: ShipWall in structure.walls:
		var axis := 0 if wall.axis == ShipWall.Axis.ACROSS else 2
		var other := 2 - axis
		for before: StringName in wall.cells:
			var low := structure.cells[structure.cell_named(before)]
			if not is_equal_approx(low.high[axis], wall.at):
				continue
			for after: StringName in wall.cells:
				var high := structure.cells[structure.cell_named(after)]
				if not is_equal_approx(high.low[axis], wall.at):
					continue
				var from := maxf(maxf(low.low[other], high.low[other]), wall.span.x)
				var to := minf(minf(low.high[other], high.high[other]), wall.span.y)
				var bottom := maxf(maxf(low.low.y, high.low.y), wall.bottom)
				var top := minf(minf(low.high.y, high.high.y), wall.top)
				if to <= from or top <= bottom:
					continue
				var joins: Array[StringName] = [before, after]
				var centre := Vector3(0.0, (bottom + top) * 0.5, 0.0)
				centre[axis] = wall.at
				centre[other] = (from + to) * 0.5
				var size := Vector3(0.0, top - bottom, 0.0)
				size[other] = to - from
				var panel := ShipOpening.new()
				panel.name = StringName("panel_%s_%s_%s" % [wall.name, before, after])
				panel.kind = ShipOpening.Kind.PANEL
				panel.joins = joins
				panel.centre = centre
				panel.size = size
				panel.starts = ShipOpening.Start.SHUT
				panel.leak_head = wall.leak_head
				panel.collapse_head = wall.collapse_head
				panel.leak_area = wall.leak_area
				made.append(panel)
	return made


## Watches [param opening], the stepper's [param index], whose sides there are
## [param sides] and which the ship takes [param shut_time] to shut — one shut until it
## fails, or a door the ship shuts at the hit and did not jam: the heads it leaks and
## gives way at — in a wall the hit weakened, the share of its collapse head the hit left
## it, never leaking later than that — and the side a hinged door opens toward.
func watch(index: int, opening: ShipOpening, sides: Vector2i, shut_time: float) -> void:
	var kept := kept_share(_structure, _damage, opening)
	_index.append(index)
	_first.append(sides.x)
	_second.append(sides.y)
	_shut_time.append(shut_time)
	var collapse := opening.collapse_head * kept
	_leak.append(minf(opening.leak_head, collapse) if collapse > 0.0 else opening.leak_head)
	_collapse.append(collapse)
	_leak_share.append(minf(opening.leak_area / opening.flow_area(), 1.0))
	var toward := 0
	if not opening.opens_toward.is_empty():
		var cell := _structure.cell_named(opening.opens_toward)
		toward = 1 if (cell if cell != -1 else SinkStepper.OUTSIDE) == sides.y else -1
	_toward.append(toward)


## Whether the stepper's opening [param index] is one that can fail.
func watches(index: int) -> bool:
	return index in _index


## Every watched opening (watch) as the extension takes them (SinkNative.watched): their
## indices, first and second sides, shut times, leak and collapse heads, leak shares and
## the sides they open toward.
func watched() -> Array:
	return [_index, _first, _second, _shut_time, _leak, _collapse, _leak_share, _toward]


## Fills [param state], at the hit, with nothing given way: her funnels standing, her
## generator running and her lights on, her bending measured.
func start(state: FloodState) -> void:
	_funnels.start(state)
	_power.start(state)
	measure(state)


## Measures [param state]'s bending into it (HullGirder), with the bending stage on: the
## bake asks it of every state it keeps — it moves nothing, so a step tried and not kept
## never pays for it.
func measure(state: FloodState) -> void:
	if _girder != null:
		_girder.measure(state)


## Fails into [param next] — [param state] stepped [param seconds] by [param stepper],
## which stands turned to it — whatever its heads and attitude have brought to a
## threshold: each opening at its heads, her funnels, her power and lights; and lifts
## out to the sea what her pumps lifted over the step while her generator ran, her
## motion meeting the lighter water in the next step.
func follow(state: FloodState, next: FloodState, seconds: float, stepper: SinkStepper) -> void:
	var pumped := _power.pumping(state)
	for at in range(0, pumped.size(), 2):
		var cell := int(pumped[at])
		var amount := minf(pumped[at + 1] * seconds, maxf(next.water[cell], 0.0))
		next.water[cell] -= amount
		next.sea_given -= amount
		next.heads[cell] = stepper.head(cell, next.water[cell])
	var heads := _heads_across(next, stepper)
	var native := stepper.native()
	if native != null:
		next.opened = native.failed(heads, next.opened, next.seconds)
	else:
		_fail(next, heads)
	_funnels.follow(next)
	_power.follow(state, next, seconds)


## Fails into [param next] each watched opening shut that its head across,
## [param heads], brings to its giving way or its leak (follow).
func _fail(next: FloodState, heads: PackedFloat64Array) -> void:
	var opened := next.opened
	for watched in _index.size():
		var index := _index[watched]
		# What has given way stays so, shut or not: asked first, as the cheaper.
		if opened[index] >= GAVE_WAY:
			continue
		var shut := SinkOpenings.open_share(_shut_time[watched], next.seconds) <= 0.0
		if not shut:
			continue
		var across := heads[watched]
		if _gives_way_gap(watched, across) <= REACHED:
			next.opened[index] = GAVE_WAY
		elif (
			next.opened[index] == 0.0
			and _leak[watched] > 0.0
			and _leak[watched] - absf(across) <= REACHED
		):
			next.opened[index] = _leak_share[watched]


## How far under each threshold [param state] stands — per opening that can fail its
## leak's, then its giving way's; then her funnels' and her power's (FunnelStays,
## ShipPower) — under 0 past it, whether it has failed there or not, so the bake lands a
## step where it is first passed; INF for none to come. Her lamps are none of these:
## they never move the physics, so no step lands on them (ShipPower.lamp_gaps).
func gaps(state: FloodState, stepper: SinkStepper) -> PackedFloat64Array:
	var heads := _heads_across(state, stepper)
	var native := stepper.native()
	var found := native.failure_gaps(heads) if native != null else _opening_gaps(heads)
	found.append_array(_funnels.gaps(state))
	found.append_array(_power.gaps(state))
	return found


## Per watched opening, how far under its leak and its giving way [param heads] across
## it stand (gaps).
func _opening_gaps(heads: PackedFloat64Array) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	for watched in _index.size():
		var across := absf(heads[watched])
		var leaks := _leak[watched] > 0.0 and _leak_share[watched] > 0.0
		found.append(_leak[watched] - across if leaks else INF)
		found.append(_gives_way_gap(watched, heads[watched]))
	return found


## Her funnels and her power, for the bake's events.
func funnels() -> FunnelStays:
	return _funnels


func power() -> ShipPower:
	return _power


## Her hull as a girder, or null where nothing measures her bending.
func girder() -> HullGirder:
	return _girder


## The head across every watched opening at [param state], [param stepper] turned to
## it: each side's push — the sea's outside — lifted by its pocket's as the stepper's
## flow is, no higher than any surface in her, and no lower than its sill, its first's less
## its second's; none dry on both sides. Worked out once for each state, which a step's
## failures and the bake's landing both ask of.
func _heads_across(state: FloodState, stepper: SinkStepper) -> PackedFloat64Array:
	if state == _across_state:
		return _across
	_across_state = state
	# The extension lifts as SinkAir does; an air that lifts otherwise is worked here.
	var native := stepper.native()
	if native != null and _air.get_script() == SinkAir:
		_across = native.across(state, stepper.ceilings(), stepper.sills(), _air)
		return _across
	_across.resize(_index.size())
	# The head each side truly pushes with: the sea's, or a cell's own but over its
	# ceiling no higher than the surface drives it — past that it is only water over its
	# box on the thin surface, a step's slip reading as metres of head. Worked here, the
	# stepper's arrays read once: this runs over every watched opening for every state.
	var heads := state.heads
	var ceilings := stepper.ceilings()
	var sills := stepper.sills()
	var surface := _highest_surface(state, ceilings)
	for watched in _index.size():
		var first := _first[watched]
		var second := _second[watched]
		var sill := sills[_index[watched]]
		var pushing := (
			state.sea
			if first == SinkStepper.OUTSIDE
			else minf(heads[first], maxf(ceilings[first], surface))
		)
		var pushed := (
			state.sea
			if second == SinkStepper.OUTSIDE
			else minf(heads[second], maxf(ceilings[second], surface))
		)
		_across[watched] = 0.0
		if pushing > sill or pushed > sill:
			pushing = minf(pushing + _air.lift(first, second, heads), surface)
			pushed = minf(pushed + _air.lift(second, first, heads), surface)
			_across[watched] = maxf(pushing, sill) - maxf(pushed, sill)
	return _across


## The highest any water of [param state] stands with a surface of its own: the sea, or a
## cell wet and not full — a dry cell's head is only its floor. Nothing in her pushes
## higher, a pocket no more than the water squeezing it: past that it is a step's slip.
## [param ceilings] are the stepper's (SinkStepper.ceilings).
func _highest_surface(state: FloodState, ceilings: PackedFloat64Array) -> float:
	var highest := state.sea
	var heads := state.heads
	var water := state.water
	for cell in heads.size():
		if water[cell] > 0.0 and heads[cell] < ceilings[cell]:
			highest = maxf(highest, heads[cell])
	return highest


## How far under the head at which watched opening [param watched] gives way the head
## [param across] it (_heads_across) stands: a hinged door pushed the way it opens
## gives way at its leak head; INF for one that never does.
func _gives_way_gap(watched: int, across: float) -> float:
	var with_flow := _toward[watched] != 0 and across * _toward[watched] > 0.0
	var head := _collapse[watched]
	if with_flow and _leak[watched] > 0.0:
		head = _leak[watched]
	if head <= 0.0:
		return INF
	return head - absf(across)


## The share of its heads [param opening] of [param structure] keeps after
## [param damage]: what the hit left a watertight wall it ended beside, for a panel of it
## or an opening in it — flat across its axis, on its plane, between two of the cells it
## parts — and all of them for any other.
static func kept_share(structure: ShipStructure, damage: HitDamage, opening: ShipOpening) -> float:
	for wall: ShipWall in structure.walls:
		if wall.name in damage.weakened and in_wall(wall, opening):
			return damage.weakened_to
	return 1.0


## Whether [param opening] is a panel of [param wall] or an opening in it: flat across its
## axis, on its plane, between two of the cells it parts.
static func in_wall(wall: ShipWall, opening: ShipOpening) -> bool:
	var axis := 0 if wall.axis == ShipWall.Axis.ACROSS else 2
	if opening.facing() != axis or not is_equal_approx(opening.centre[axis], wall.at):
		return false
	return opening.joins[0] in wall.cells and opening.joins[1] in wall.cells
