class_name ShipPower
extends RefCounted
## Her lights and pumps (§5b.1, "Things that give way"; step 10 of the physics): her
## generator runs while the water over its foot is under the depth that drowns it — for
## good once it is not — and she lists and trims within what machinery tolerates; past
## either limit it stops, and runs again only once she is back recovers_deg within both
## (the hysteresis). While it does not run her emergency power lights the cells it names
## for its minutes, then nothing does. A cell's lights burn while what powers them runs
## and its water has not reached its lamps, lamp_drop under its ceiling's middle — once it
## has, they are out for good. Her pumps lift water out of their cells to the sea while
## the generator runs. Without a generator she is lit throughout. Heights along the
## world's up from her origin, as the stepper's heads; list and trim as sines read off
## her rotation (R21). Only +, −, ×, ÷ and square roots on 64-bit floats run here (D4).

## What lights her: nothing, her emergency power, or her generator.
enum Power { DARK, EMERGENCY, MAIN }

var _on: bool
var _generator: ShipFitting
## The generator's cell; the sines of its list and trim limits, and of each less its
## margin; the seconds its emergency power lasts.
var _cell := -1
var _list: float
var _trim: float
var _back_list: float
var _back_trim: float
var _emergency := 0.0
## Per cell: its lamps' place, x, y, z — NAN for a cell without any — and 1 where her
## emergency power lights it.
var _lamps := PackedFloat64Array()
var _emergency_cells := PackedByteArray()
## Per pump: its cell and the water it lifts a second.
var _pumps := PackedFloat64Array()


## The power of [param structure] under [param sea]: on only with the failures stage.
func _init(structure: ShipStructure, sea: SeaPhysics) -> void:
	_on = sea.failures
	for cell: FloodCell in structure.cells:
		var middle := (cell.low + cell.high) * 0.5
		var lit := not cell.rooms.is_empty()
		_lamps.append(middle.x if lit else NAN)
		_lamps.append(float(cell.high.y) - sea.lamp_drop if lit else NAN)
		_lamps.append(middle.z if lit else NAN)
	_emergency_cells.resize(structure.cells.size())
	if not _on:
		return
	for fitting: ShipFitting in structure.fittings:
		if fitting.kind == ShipFitting.Kind.PUMP:
			_pumps.append(structure.cell_named(fitting.cell))
			_pumps.append(fitting.rate)
		if fitting.kind != ShipFitting.Kind.GENERATOR or _generator != null:
			continue
		_generator = fitting
		_cell = structure.cell_named(fitting.cell)
		_list = Attitude.sine_of_degrees(fitting.list_limit_deg)
		_trim = Attitude.sine_of_degrees(fitting.trim_limit_deg)
		_back_list = Attitude.sine_of_degrees(fitting.list_limit_deg - fitting.recovers_deg)
		_back_trim = Attitude.sine_of_degrees(fitting.trim_limit_deg - fitting.recovers_deg)
		_emergency = fitting.emergency_minutes * 60.0
		for named: StringName in fitting.emergency_cells:
			_emergency_cells[structure.cell_named(named)] = 1


## Her generator, or null.
func generator() -> ShipFitting:
	return _generator


## [param state] at the hit: her generator running, her emergency power full, every
## cell's lamps dry and lit.
func start(state: FloodState) -> void:
	state.power = Power.MAIN
	state.drowned = false
	state.battery = _emergency
	state.shorted.resize(_lamps.size() / 3)
	_light(state)


## Follows [param state] stepped [param seconds] to [param next]: the generator drowned
## once the water over its foot reaches its depth; stopped past a limit and running
## again back within its margins; the emergency power's minutes spent while the
## generator does not run — under none once they are; each cell's lamps out once its
## water reaches them.
func follow(state: FloodState, next: FloodState, seconds: float) -> void:
	if _generator == null:
		_light(next)
		return
	if state.power != Power.MAIN:
		next.battery = state.battery - seconds
	var gaps := _gaps(next)
	next.drowned = next.drowned or gaps[0] <= SinkFailures.REACHED
	var running := state.power == Power.MAIN
	if running:
		running = minf(gaps[1], gaps[2]) > SinkFailures.REACHED
	else:
		running = gaps[3] <= SinkFailures.REACHED
	if next.drowned or not running:
		next.power = Power.EMERGENCY if next.battery > SinkFailures.REACHED else Power.DARK
	else:
		next.power = Power.MAIN
	_light(next)


## How far [param state] stands from each threshold of her power — the water drowning
## her generator, in metres; her list and her trim stopping it and her coming back
## within its margins, as sines; her emergency power running out, in seconds — then per
## cell from its water reaching its lamps: under 0 past it, INF for none to come.
func gaps(state: FloodState) -> PackedFloat64Array:
	var found := PackedFloat64Array([INF, INF, INF, INF, INF])
	if _generator != null:
		var gaps_now := _gaps(state)
		for at in 4:
			found[at] = gaps_now[at]
		found[4] = state.battery if state.power != Power.MAIN else INF
	var up := Attitude.up(state.rotation)
	for cell in state.shorted.size():
		var lamp := cell * 3
		if is_nan(_lamps[lamp]):
			found.append(INF)
			continue
		var height := up[0] * _lamps[lamp] + up[1] * _lamps[lamp + 1] + up[2] * _lamps[lamp + 2]
		found.append(height - state.heads[cell])
	return found


## Her pumps' cells and rates, cell then rate, while her generator runs at
## [param state]; none while it does not.
func pumping(state: FloodState) -> PackedFloat64Array:
	return _pumps if state.power == Power.MAIN else PackedFloat64Array()


## How far [param state] stands from drowning her generator, from stopping it by her
## list and her trim, and from her being back within its margins (under 0 once she is):
## her list and trim as sines, so past her beam ends or on end — her up turned under
## the world's level — she stands past every limit.
func _gaps(state: FloodState) -> PackedFloat64Array:
	var rotation := state.rotation
	var base := _generator.base
	var foot := rotation[3] * base.x + rotation[4] * base.y + rotation[5] * base.z
	var list := absf(rotation[7])
	var trim := absf(rotation[3])
	var upright := rotation[4]
	return PackedFloat64Array(
		[
			foot + _generator.drowns_at - state.heads[_cell],
			minf(_list - list, upright),
			minf(_trim - trim, upright),
			maxf(maxf(list - _back_list, trim - _back_trim), -upright),
		]
	)


## Each cell's lamps of [param state] out once its water reaches them, then what lights
## each: its power, while its lamps burn — the emergency power only where it reaches.
func _light(state: FloodState) -> void:
	var cells := state.shorted.size()
	state.lit.resize(cells)
	var up := Attitude.up(state.rotation)
	for cell in cells:
		var lamp := cell * 3
		if is_nan(_lamps[lamp]):
			state.lit[cell] = Power.DARK
			continue
		var height := up[0] * _lamps[lamp] + up[1] * _lamps[lamp + 1] + up[2] * _lamps[lamp + 2]
		if _on and state.heads[cell] >= height - SinkFailures.REACHED:
			state.shorted[cell] = 1
		var power := state.power
		if power == Power.EMERGENCY and _emergency_cells[cell] == 0:
			power = Power.DARK
		state.lit[cell] = Power.DARK if state.shorted[cell] == 1 else power
