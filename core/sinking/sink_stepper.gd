class_name SinkStepper
extends RefCounted
## The one physics of the sinking (§5b.1, D7, D13): state in, state out — a FloodState
## and a step of simulated seconds give the next FloodState, from her structure, what
## the hit did to it and the sea's constants. Only the bake calls it; nothing else
## moves water. SH26 builds its flooding and heave: water moves between cells, and
## between a cell and the sea, through every opening that is open, under water on both
## sides (an orifice), over a bottom edge (a weir) or falling through a hole in a floor;
## each transfer is capped at what levels its two sides, the openings swept in a fixed
## order that turns round every step, so nothing sloshes (R22); a cell too stiff for the
## step — a full one, whose only surface is the thin one over its ceiling, or one whose
## openings would empty or fill it many times over within it — has its head solved for
## the step instead, one backward step of its level, so the push of the water behind a
## chain of full cells passes straight through it whatever the step's length; the sea is
## an account, so water is never made or lost; and she settles level to where her lift
## is her weight, or goes down once no height of the sea holds her. Every cell vents
## (air is SH29). Only +, −, ×, ÷ and square roots on 64-bit floats run here (D4, R21).
## Ship-local metres, seconds.

## The other side of an opening to the sea or the sky: the water outside her.
const OUTSIDE := -1
## A cell is stiff (_hold_stiff) when its wet openings, at the head across each but no
## more than STIFF_HEAD, would pass more in the step than STIFF_HEAD of its surface holds
## or than it has room for, and some opening has more than STILL_HEAD across it. Under
## LEVEL_HEAD an opening passes water in proportion to the head, not its root (_root).
## Metres.
const STIFF_HEAD := 1.0
const STILL_HEAD := 5e-3
const LEVEL_HEAD := 1e-2
## A held head is solved until the step's water on it is out by no more than
## SURPLUS_TOLERANCE m³ — a slip that stays in that cell's own water, never lost: cells
## held together by Newton's method in at most NEWTON_TRIES tries, each step halved at
## most HALVINGS times, slopes measured over NUDGE metres; one alone by false position, to
## HEAD_TOLERANCE metres in at most TRIES tries, first REACH metres out where its slope
## cannot say how far.
const SURPLUS_TOLERANCE := 1e-2
const NEWTON_TRIES := 6
const HALVINGS := 12
const NUDGE := 1e-7
const HEAD_TOLERANCE := 1e-9
const TRIES := 60
const REACH := 1e-3

var _sea: SeaPhysics
var _hull: LevelHull
## Her own weight as a volume of sea, the sea's height up her at rest with no water in
## her, and her waterplane there: what a hull going down drags through the water.
var _own_volume: float
var _rest: float
var _plan: float
## Per cell: its floor and ceiling, how much water raises its level a metre while it
## has a surface, and how much it holds.
var _cell_names: Array[StringName] = []
var _floor := PackedFloat64Array()
var _ceiling := PackedFloat64Array()
var _area := PackedFloat64Array()
var _capacity := PackedFloat64Array()
## Per opening water can pass, in her openings' order then the gash's: its name and
## kind, its sides (a hole in a floor's first side is the one under it), whether it is
## a hole in a floor, its bottom and top, its width (a wall's) or area (a floor's), and
## the seconds it takes to shut from the hit — 0 for one that stays as it is.
var _names: Array[StringName] = []
var _kinds := PackedInt32Array()
var _first := PackedInt32Array()
var _second := PackedInt32Array()
var _in_floor := PackedByteArray()
var _bottom := PackedFloat64Array()
var _top := PackedFloat64Array()
var _size := PackedFloat64Array()
var _opening_area := PackedFloat64Array()
var _shut_time := PackedFloat64Array()
## Per cell, the openings that touch it, by index, and their whole area; and, within a
## step, 1 where it is a stiff cell whose head is held, as the sea's is, at the height
## solved for the step.
var _touching: Array[PackedInt32Array] = []
var _widest := PackedFloat64Array()
var _held := PackedByteArray()
var _g: float
var _discharge: float


## The physics of [param structure] after a hit that did [param damage] — its gash, the
## doors it jammed and the openings it found left open — under [param sea].
func _init(structure: ShipStructure, damage: HitDamage, sea: SeaPhysics) -> void:
	_sea = sea
	_g = sea.gravity
	_discharge = sea.discharge
	_hull = LevelHull.new(structure.sections)
	_own_volume = structure.total_mass() / sea.sea_density
	_rest = _hull.height_of(_own_volume)
	_plan = _hull.waterplane(_rest)
	for cell: FloodCell in structure.cells:
		var plan := (float(cell.high.x) - cell.low.x) * (float(cell.high.z) - cell.low.z)
		var area := plan * cell.permeability_in(sea) * cell.shape
		_cell_names.append(cell.name)
		_floor.append(cell.low.y)
		_ceiling.append(cell.high.y)
		_area.append(area)
		_capacity.append(area * (float(cell.high.y) - cell.low.y))
	var openings: Array[ShipOpening] = structure.openings.duplicate()
	openings.append_array(damage.openings)
	for opening: ShipOpening in openings:
		if opening.starts == ShipOpening.Start.SHUT and not opening.name in damage.left_open:
			continue
		_compile(structure, opening, damage)
	for cell in _area.size():
		var touching := PackedInt32Array()
		var widest := 0.0
		for index in _names.size():
			if _first[index] == cell or _second[index] == cell:
				touching.append(index)
				widest += _opening_area[index]
		_touching.append(touching)
		_widest.append(widest)
	_held.resize(_area.size())


## Her state at the hit: no water in her, the sea where she rests.
func start() -> FloodState:
	var state := FloodState.new()
	state.water.resize(_area.size())
	for cell in _area.size():
		state.heads.append(_floor[cell])
	state.moved.resize(_names.size())
	state.sea = _rest
	return state


## The state [param seconds] of physics after [param state].
func step(state: FloodState, seconds: float) -> FloodState:
	var next := state.copy()
	var heads := state.heads.duplicate()
	var count := _names.size()
	var sea := next.sea
	var held := _hold_stiff(state, heads, sea, seconds)
	for turn in count:
		var index := turn if state.steps % 2 == 0 else count - 1 - turn
		# Dry on both sides below it: nothing to pass, and nothing worth a call.
		var first := _first[index]
		var second := _second[index]
		var bottom := _bottom[index]
		if (
			(sea if first == OUTSIDE else heads[first]) <= bottom
			and (sea if second == OUTSIDE else heads[second]) <= bottom
		):
			next.moved[index] = 0.0
			continue
		var amount := _transfer(index, heads, sea, state.seconds, seconds)
		next.moved[index] = amount
		if amount == 0.0:
			continue
		_give_to(_first[index], -amount, next, heads)
		_give_to(_second[index], amount, next, heads)
	for cell: int in held:
		# A full cell keeps the head it was held at — the push it passes on, where the
		# next step's solve starts — any other stands where its water does.
		if next.water[cell] < _capacity[cell] or heads[cell] < _ceiling[cell]:
			heads[cell] = head(cell, next.water[cell])
		_held[cell] = 0
	next.heads = heads
	next.seconds = state.seconds + seconds
	next.steps = state.steps + 1
	next.sea = _settled(state.sea, _own_volume + next.total(), seconds)
	return next


## Gives [param side] — a cell, or the sea's account — [param amount] m³ of [param
## state]'s water, keeping its head in [param heads] unless the step holds it.
func _give_to(side: int, amount: float, state: FloodState, heads: PackedFloat64Array) -> void:
	if side == OUTSIDE:
		state.sea_given -= amount
		return
	state.water[side] += amount
	if _held[side] == 0:
		heads[side] = head(side, state.water[side])


## Holds every stiff cell's head in [param heads] — see STIFF_HEAD — at the height
## solved for a step of [param seconds] from [param state], the sea at [param sea]: a
## cell alone by [method _balanced], cells that hold each other together by
## [method _solve_together]. A full cell next to a held one is held too, however level
## it stands: it passes on what that one asks of it. Gives the cells it holds.
func _hold_stiff(
	state: FloodState, heads: PackedFloat64Array, sea: float, seconds: float
) -> PackedInt32Array:
	var held := PackedInt32Array()
	var per_metre := _discharge * sqrt(2.0 * _g * STIFF_HEAD) * seconds
	for cell in _area.size():
		var room := minf(_area[cell] * STIFF_HEAD, _capacity[cell] - state.water[cell])
		if state.water[cell] <= 0.0 or _widest[cell] * per_metre <= room:
			continue
		var passes := 0.0
		var moving := false
		var own := heads[cell]
		for index: int in _touching[cell]:
			var other := _second[index] if _first[index] == cell else _first[index]
			var beyond := sea if other == OUTSIDE else heads[other]
			var bottom := _bottom[index]
			if own <= bottom and beyond <= bottom:
				continue
			var share := open_share(_shut_time[index], state.seconds)
			var across := absf(maxf(beyond, bottom) - maxf(own, bottom))
			passes += _opening_area[index] * share * sqrt(minf(across, STIFF_HEAD) / STIFF_HEAD)
			moving = moving or (share > 0.0 and across > STILL_HEAD)
		if moving and passes * per_metre > room:
			held.append(cell)
			_held[cell] = 1
	var at := 0
	while at < held.size():
		var cell := held[at]
		at += 1
		for index: int in _touching[cell]:
			var other := _second[index] if _first[index] == cell else _first[index]
			if other == OUTSIDE or _held[other] == 1 or state.water[other] < _capacity[other]:
				continue
			if heads[cell] <= _bottom[index] and heads[other] <= _bottom[index]:
				continue
			held.append(other)
			_held[other] = 1
	for group: PackedInt32Array in _groups(held, heads):
		if group.size() == 1:
			heads[group[0]] = _balanced(
				group[0], state.water[group[0]], heads, sea, state.seconds, seconds
			)
		else:
			_solve_together(group, state, heads, sea, seconds)
	return held


## [param held] cut into groups that hold each other: cells joined, directly or along
## a chain of held cells, by an opening wet on either side, in her cells' order.
func _groups(held: PackedInt32Array, heads: PackedFloat64Array) -> Array[PackedInt32Array]:
	var found: Array[PackedInt32Array] = []
	var placed := PackedByteArray()
	placed.resize(_area.size())
	for first: int in held:
		if placed[first] == 1:
			continue
		var group := PackedInt32Array([first])
		placed[first] = 1
		var at := 0
		while at < group.size():
			var cell := group[at]
			at += 1
			for index: int in _touching[cell]:
				var other := _second[index] if _first[index] == cell else _first[index]
				if other == OUTSIDE or _held[other] == 0 or placed[other] == 1:
					continue
				var bottom := _bottom[index]
				if heads[cell] <= bottom and heads[other] <= bottom:
					continue
				group.append(other)
				placed[other] = 1
		found.append(group)
	return found


## Solves the heads of [param held] together in [param heads] — each, as in
## [method _balanced], where what the step of [param seconds] passes into it is what
## lifts its water to that head — by Newton's method on all of them at once, the
## slopes measured by nudging each head, every step halved until it brings the largest
## surplus down: one held cell's head pins its neighbour's, so a pair joined wide under
## water moves as one, which solving them in turn would only creep towards.
func _solve_together(
	held: PackedInt32Array, state: FloodState, heads: PackedFloat64Array, sea: float, seconds: float
) -> void:
	var count := held.size()
	var since := state.seconds
	var rows := PackedInt32Array()
	rows.resize(_area.size())
	rows.fill(-1)
	var highest := sea
	for row in count:
		rows[held[row]] = row
	for at: float in heads:
		highest = maxf(highest, at)
	var surplus := _surpluses(held, state, heads, sea, seconds)
	var worst := _largest(surplus)
	var slopes := PackedFloat64Array()
	slopes.resize(count * count)
	var started := PackedFloat64Array()
	started.resize(count)
	for _try in NEWTON_TRIES:
		if worst <= SURPLUS_TOLERANCE:
			return
		slopes.fill(0.0)
		for column in count:
			var cell := held[column]
			var was := heads[cell]
			heads[cell] = was + NUDGE
			slopes[column * count + column] = (
				(
					_surplus(cell, heads[cell], state.water[cell], heads, sea, since, seconds)
					- surplus[column]
				)
				/ NUDGE
			)
			for index: int in _touching[cell]:
				var other := _second[index] if _first[index] == cell else _first[index]
				if other == OUTSIDE or rows[other] < 0:
					continue
				# Only what passes between the two moves the other's surplus.
				var nudged := _transfer(index, heads, sea, since, seconds)
				heads[cell] = was
				var before := _transfer(index, heads, sea, since, seconds)
				heads[cell] = was + NUDGE
				var into_other := 1.0 if _second[index] == other else -1.0
				slopes[rows[other] * count + column] += into_other * (nudged - before) / NUDGE
			heads[cell] = was
		var change := _gauss(slopes, surplus, count)
		for row in count:
			started[row] = heads[held[row]]
		var share := 1.0
		var improved := false
		for _halving in HALVINGS:
			for row in count:
				var cell := held[row]
				heads[cell] = clampf(started[row] - share * change[row], _floor[cell], highest)
			var tried := _surpluses(held, state, heads, sea, seconds)
			var tried_worst := _largest(tried)
			if tried_worst < worst:
				surplus = tried
				worst = tried_worst
				improved = true
				break
			share *= 0.5
		if not improved:
			for row in count:
				heads[held[row]] = started[row]
			return


## Every held cell's surplus (_surplus) at the heads in [param heads].
func _surpluses(
	held: PackedInt32Array, state: FloodState, heads: PackedFloat64Array, sea: float, seconds: float
) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	for cell: int in held:
		found.append(
			_surplus(cell, heads[cell], state.water[cell], heads, sea, state.seconds, seconds)
		)
	return found


static func _largest(values: PackedFloat64Array) -> float:
	var most := 0.0
	for value: float in values:
		most = maxf(most, absf(value))
	return most


## The x for which [param matrix] (rows of [param count]) times x is [param values]:
## Gauss's elimination, the largest pivot first.
static func _gauss(
	matrix: PackedFloat64Array, values: PackedFloat64Array, count: int
) -> PackedFloat64Array:
	var m := matrix.duplicate()
	var v := values.duplicate()
	for column in count:
		var pivot := column
		for row in range(column + 1, count):
			if absf(m[row * count + column]) > absf(m[pivot * count + column]):
				pivot = row
		if pivot != column:
			for at in count:
				var kept := m[column * count + at]
				m[column * count + at] = m[pivot * count + at]
				m[pivot * count + at] = kept
			var kept_value := v[column]
			v[column] = v[pivot]
			v[pivot] = kept_value
		var lead := m[column * count + column]
		if lead == 0.0:
			continue
		for row in range(column + 1, count):
			var factor := m[row * count + column] / lead
			if factor == 0.0:
				continue
			for at in range(column, count):
				m[row * count + at] -= factor * m[column * count + at]
			v[row] -= factor * v[column]
	var x := PackedFloat64Array()
	x.resize(count)
	for row in range(count - 1, -1, -1):
		var sum := v[row]
		for at in range(row + 1, count):
			sum -= m[row * count + at] * x[at]
		var lead := m[row * count + row]
		x[row] = sum / lead if lead != 0.0 else 0.0
	return x


## The head of held cell [param cell], holding [param water] m³, at which what the step
## passes into it over its openings, its neighbours' heads in [param heads], is what
## lifts its own water to that head: its level stepped backwards (R22), so a full cell
## passes on what it is given. Found by false position (the Illinois kind) between its
## floor, where nothing leaves it, and the highest head about it, where nothing comes in,
## starting from where [param heads] holds it and as far as its slope there says.
func _balanced(
	cell: int, water: float, heads: PackedFloat64Array, sea: float, since: float, seconds: float
) -> float:
	var low := _floor[cell]
	var high := head(cell, water)
	for index: int in _touching[cell]:
		var other := _second[index] if _first[index] == cell else _first[index]
		high = maxf(high, sea if other == OUTSIDE else heads[other])
	var start := clampf(heads[cell], low, high)
	var at_start := _surplus(cell, start, water, heads, sea, since, seconds)
	if absf(at_start) <= SURPLUS_TOLERANCE:
		return start
	# First as far as its slope there says the surplus runs out, then out from where it
	# stood, further each time, until the surplus turns.
	var rising := at_start > 0.0
	var end := high if rising else low
	var slope := (
		(_surplus(cell, start + NUDGE, water, heads, sea, since, seconds) - at_start) / NUDGE
	)
	var reach := absf(at_start / slope) if slope < 0.0 else REACH
	var near := start
	var at_near := at_start
	var far := start
	var at_far := at_start
	while at_far * at_start > 0.0:
		if far == end:
			return end
		near = far
		at_near = at_far
		far = minf(near + reach, high) if rising else maxf(near - reach, low)
		at_far = _surplus(cell, far, water, heads, sea, since, seconds)
		if absf(at_far) <= SURPLUS_TOLERANCE:
			return far
		reach *= 4.0
	var at_low := at_near if rising else at_far
	var at_high := at_far if rising else at_near
	low = near if rising else far
	high = far if rising else near
	var kept := 0
	for _try in TRIES:
		if high - low <= HEAD_TOLERANCE:
			break
		var at := low + (high - low) * at_low / (at_low - at_high)
		var surplus := _surplus(cell, at, water, heads, sea, since, seconds)
		if absf(surplus) <= SURPLUS_TOLERANCE:
			return at
		# Illinois: an end kept twice running counts for half, so both ends close in.
		if surplus > 0.0:
			low = at
			at_low = surplus
			if kept == 1:
				at_high *= 0.5
			kept = 1
		else:
			high = at
			at_high = surplus
			if kept == -1:
				at_low *= 0.5
			kept = -1
	return low + (high - low) * at_low / (at_low - at_high)


## What a step of [param seconds] would pass into cell [param cell], its head held at
## [param at], beyond lifting its [param water] m³ to that head: positive while more
## comes in than [param at] holds.
func _surplus(
	cell: int,
	at: float,
	water: float,
	heads: PackedFloat64Array,
	sea: float,
	since: float,
	seconds: float
) -> float:
	var was := heads[cell]
	heads[cell] = at
	var into := 0.0
	for index: int in _touching[cell]:
		var other := _second[index] if _first[index] == cell else _first[index]
		var bottom := _bottom[index]
		if at <= bottom and (sea if other == OUTSIDE else heads[other]) <= bottom:
			continue
		var amount := _transfer(index, heads, sea, since, seconds)
		into += amount if _second[index] == cell else -amount
	heads[cell] = was
	return into - (volume_at(cell, at) - water)


## How high the water of cell [param cell] holding [param water] m³ stands: from its
## floor up while it has a surface; once it is full, over its ceiling as though it had
## a thin surface there of full_surface of its own (§5b.1), so the push of the water
## behind it passes on.
func head(cell: int, water: float) -> float:
	if water <= _capacity[cell]:
		return _floor[cell] + water / _area[cell]
	return _ceiling[cell] + (water - _capacity[cell]) / (_area[cell] * _sea.full_surface)


## The water cell [param cell] holds with its head at [param height], in m³.
func volume_at(cell: int, height: float) -> float:
	if height <= _floor[cell]:
		return 0.0
	if height <= _ceiling[cell]:
		return _area[cell] * (height - _floor[cell])
	return _capacity[cell] + _area[cell] * _sea.full_surface * (height - _ceiling[cell])


## The sea's height up her at rest with no water in her, and the top of everything
## enclosed: wholly under once the sea stands over it.
func rest() -> float:
	return _rest


func top() -> float:
	return _hull.top()


func cell_name(cell: int) -> StringName:
	return _cell_names[cell]


func floor_of(cell: int) -> float:
	return _floor[cell]


func ceiling_of(cell: int) -> float:
	return _ceiling[cell]


## The physics second the last door the ship shuts is shut.
func last_door() -> float:
	var last := 0.0
	for shut_time: float in _shut_time:
		last = maxf(last, shut_time)
	return last


## The openings water can pass, in the order the stepper sweeps them, by name.
func opening_names() -> Array[StringName]:
	return _names


func opening_kind(index: int) -> ShipOpening.Kind:
	return _kinds[index] as ShipOpening.Kind


## How open, 0…1, an opening is [param seconds] after the hit: one the ship shuts in
## [param shut_time] slides shut evenly, one that jammed or that is not shut — 0 —
## stays as it is. The schedule's doors and the physics' read this one answer.
static func open_share(shut_time: float, seconds: float) -> float:
	if shut_time <= 0.0:
		return 1.0
	return clampf(1.0 - seconds / shut_time, 0.0, 1.0)


## Adds [param opening] of [param structure] to the openings water can pass.
func _compile(structure: ShipStructure, opening: ShipOpening, damage: HitDamage) -> void:
	var sides := PackedInt32Array()
	for place: StringName in opening.joins:
		sides.append(
			(
				structure.cell_named(place)
				if not place in [ShipOpening.SEA, ShipOpening.SKY]
				else OUTSIDE
			)
		)
	var floor_hole := opening.facing() == 1
	if floor_hole:
		# The side under the hole first: a cell whose middle stands below it.
		var first_under := _under(structure, sides[0], opening.centre.y)
		if not first_under:
			sides = PackedInt32Array([sides[1], sides[0]])
		_bottom.append(opening.centre.y)
		_top.append(opening.centre.y)
		_size.append(opening.flow_area())
	else:
		var half := opening.size.y * 0.5
		_bottom.append(opening.centre.y - half)
		_top.append(opening.centre.y + half)
		_size.append(opening.flow_area() / opening.size.y)
	_opening_area.append(opening.flow_area())
	_names.append(opening.name)
	_kinds.append(opening.kind)
	_first.append(sides[0])
	_second.append(sides[1])
	_in_floor.append(1 if floor_hole else 0)
	var shuts := opening.shuts_at_hit and not opening.name in damage.jammed
	_shut_time.append(opening.shut_time if shuts else 0.0)


## Whether [param side] lies under a hole in a floor at [param height]: a cell whose
## middle is below it; the outside is under a hole only when a cell is over it.
static func _under(structure: ShipStructure, side: int, height: float) -> bool:
	if side == OUTSIDE:
		return false
	var cell := structure.cells[side]
	return (cell.low.y + cell.high.y) * 0.5 < height


## The water that passes opening [param index] in [param seconds] from [param since]
## seconds after the hit, with the cells' heads [param heads] and the sea at
## [param sea]: positive from its first side to its second. Solved over the step where
## the flow has a closed form with the two sides' surfaces held — under water on both
## sides, over a sill, falling through a floor — else the flow now times the step; and
## never more than levels the two sides.
func _transfer(
	index: int, heads: PackedFloat64Array, sea: float, since: float, seconds: float
) -> float:
	var first := _first[index]
	var second := _second[index]
	var first_head := sea if first == OUTSIDE else heads[first]
	var second_head := sea if second == OUTSIDE else heads[second]
	var bottom := _bottom[index]
	if first_head <= bottom and second_head <= bottom:
		return 0.0
	var share := open_share(_shut_time[index], since)
	if share <= 0.0:
		return 0.0
	var size := _size[index] * share
	if _in_floor[index] == 1:
		# Over the hole, water stands no lower than the hole.
		second_head = maxf(second_head, bottom)
	var forward := first_head > second_head
	var up := first if forward else second
	var down := second if forward else first
	var high := maxf(first_head, second_head)
	var low := minf(first_head, second_head)
	var amount := 0.0
	if _in_floor[index] == 1:
		if first_head >= bottom:
			# The cell under the hole reaches it: an orifice between the two sides.
			amount = _orifice(size, high - low, _give(up) + _give(down), seconds)
		else:
			# Water falls through it at the rate the depth over it drives.
			amount = _orifice(size, high - bottom, _give(up), seconds)
	else:
		var top := _top[index]
		if low >= top:
			amount = _orifice(size * (top - bottom), high - low, _give(up) + _give(down), seconds)
		elif low <= bottom and high <= top:
			amount = _weir(size, high - bottom, _give(up), seconds)
		else:
			amount = _flow(size, bottom, top, high, low) * seconds
	amount = minf(amount, _levelling(up, down, heads, sea, bottom))
	return amount if forward else -amount


## How much a cell's head moves per m³ it gives or takes while it has a surface; the
## sea's never moves, nor a held full cell's within its step.
func _give(side: int) -> float:
	return 0.0 if side == OUTSIDE or _held[side] == 1 else 1.0 / _area[side]


## The water an opening of [param area] passes in [param seconds] with
## [param difference] of head across it, the two sides' heads moving [param give]
## together per m³ it passes: the orifice law, discharge × area × √(2g × difference),
## solved over the step — the root of the difference falls evenly — so it lands on the
## level and never past it.
func _orifice(area: float, difference: float, give: float, seconds: float) -> float:
	var rate := _discharge * area * sqrt(2.0 * _g)
	if give <= 0.0:
		return rate * _root(difference) * seconds
	var root := sqrt(difference) - rate * give * seconds * 0.5
	var left := root * root if root > 0.0 else 0.0
	return (difference - left) / give


## The square root of the head [param difference] across an opening, but in proportion
## to it under LEVEL_HEAD: the root's slope runs to infinity at the level, which no real
## opening's flow does and no solve for a held head could follow.
static func _root(difference: float) -> float:
	if difference >= LEVEL_HEAD:
		return sqrt(difference)
	return difference / sqrt(LEVEL_HEAD)


## The water a sill of [param width] passes in [param seconds] with [param depth] of
## water over it, the upstream side's head falling [param give] per m³: the weir law,
## ⅔ × discharge × width × √(2g) × depth^1.5, solved over the step.
func _weir(width: float, depth: float, give: float, seconds: float) -> float:
	var rate := 2.0 / 3.0 * _discharge * width * sqrt(2.0 * _g)
	if give <= 0.0:
		return rate * depth * sqrt(depth) * seconds
	var inverse_root := 1.0 / sqrt(depth) + rate * give * seconds * 0.5
	return (depth - 1.0 / (inverse_root * inverse_root)) / give


## The flow through a wall's opening [param width] wide from [param bottom] to
## [param top], the water at [param high] on one side and [param low] on the other,
## in m³/s: the orifice law where both sides are over it, the weir law summed over the
## rest of its wet height.
func _flow(width: float, bottom: float, top: float, high: float, low: float) -> float:
	var rate := _discharge * width * sqrt(2.0 * _g)
	var flow := 0.0
	var under := minf(low, top) - bottom
	if under > 0.0:
		flow += rate * under * _root(high - low)
	var from := maxf(bottom, low)
	var to := minf(top, high)
	if to > from:
		var deep := high - from
		var shallow := high - to
		flow += rate * 2.0 / 3.0 * (deep * sqrt(deep) - shallow * sqrt(shallow))
	return flow


## The most that can pass from [param up] to [param down] over an edge at
## [param sill], the cells' heads at [param heads] and the sea at [param sea]: what
## brings the two to one level, or [param up] down to the edge where that level would
## be under it. A held side stands where it is held, as the sea does: between two of
## them the step's flow is the whole answer.
func _levelling(up: int, down: int, heads: PackedFloat64Array, sea: float, sill: float) -> float:
	var up_held := up == OUTSIDE or _held[up] == 1
	var down_held := down == OUTSIDE or _held[down] == 1
	if up_held and down_held:
		return INF
	if up_held:
		var high := sea if up == OUTSIDE else heads[up]
		return maxf(volume_at(down, high) - volume_at(down, heads[down]), 0.0)
	var water := volume_at(up, heads[up])
	var level := sea if down == OUTSIDE else heads[down]
	if not down_held:
		level = _common_level(up, down, water + volume_at(down, heads[down]))
	return maxf(water - volume_at(up, maxf(level, sill)), 0.0)


## The one level at which cells [param a] and [param b] together hold [param total]
## m³: the two volumes rise straight between their floors and ceilings, so the level
## lies on the straight stretch between the two breaks that bracket it.
func _common_level(a: int, b: int, total: float) -> float:
	var breaks := PackedFloat64Array([_floor[a], _ceiling[a], _floor[b], _ceiling[b]])
	breaks.sort()
	var below := breaks[0]
	var held := 0.0
	for at: float in breaks:
		var holds := volume_at(a, at) + volume_at(b, at)
		if holds >= total:
			if holds <= held:
				return at
			return below + (at - below) * (total - held) / (holds - held)
		below = at
		held = holds
	var full := (_area[a] + _area[b]) * _sea.full_surface
	return below + (total - held) / full


## Where the sea stands up her once she carries [param displaced] m³ of weight as sea,
## [param seconds] after it stood at [param sea]: level where her lift is her weight;
## where no height of the sea holds her, lower by the speed a hull sinks at whose
## weight past her lift is dragged through the water broadside (sink_drag), est.
func _settled(sea: float, displaced: float, seconds: float) -> float:
	if displaced <= _hull.whole():
		return _hull.height_of(displaced)
	var excess := displaced - _hull.volume(sea)
	return sea + sqrt(2.0 * _g * excess / (_sea.sink_drag * _plan)) * seconds
