class_name HullGirder
extends RefCounted
## Her hull as a girder (§5b.1, "Bending and breaking"; step 9 of the physics): along
## her, weight and lift do not match station by station — a flooded bow is heavy at one
## end while lift holds up the stern. Her stations are her sections; on each bear her own
## weight, as her mass items spread it along the stretch each bears on, the water in
## every cell, spread along the cell, and the lift of the section's part under the sea
## (ShipMotion.lift_under), each turned to bear across her keel as her attitude has it.
## Adding up the mismatch from her stern gives the shear; adding up the shear gives the
## bending moment, positive hogging — her middle up, her ends down — and what she does
## not bring to rest by her ends, moving as she is, is taken off along her evenly
## (moments). Each station's moment over her strength (GirderStrength) is all that
## decides a break: the worst share is reported, and from SH33 one at a weak spot of hers
## at 1 of what the spot keeps starts a hinge there (HullBreak, share_at).
## Only +, −, ×, ÷ on 64-bit floats run here (D4, R21). Loads as volumes of sea,
## moments as volumes of sea times metres; ship-local metres.

var _motion: ShipMotion
## Her stations' ends, aft to fore — one more than there are stations — and per station
## her own weight on it, as a volume of sea.
var _bounds := PackedFloat64Array()
var _own := PackedFloat64Array()
## Per cell, the share of its water on each station, its stations from the first it
## reaches: _first[cell], then _counts[cell] shares from _starts[cell] in _shares.
var _first := PackedInt32Array()
var _counts := PackedInt32Array()
var _starts := PackedInt32Array()
var _shares := PackedFloat64Array()
## Her strength hogging and sagging, as volumes of sea times metres.
var _hog: float
var _sag: float
## Each section's lift, filled by ShipMotion each time she is measured; and the moment at
## each station's ends then.
var _lift := PackedFloat64Array()
var _moments := PackedFloat64Array()


## [param structure]'s hull under [param sea], moving as [param motion] moves her.
func _init(structure: ShipStructure, sea: SeaPhysics, motion: ShipMotion) -> void:
	_motion = motion
	var weight := sea.sea_density * sea.gravity
	_hog = structure.strength.hog / weight
	_sag = structure.strength.sag / weight
	var count := structure.sections.size()
	_bounds.append(structure.sections[0].x - structure.sections[0].length * 0.5)
	for section: HullSection in structure.sections:
		_bounds.append(section.x + section.length * 0.5)
	_own.resize(count)
	_lift.resize(count)
	for item: MassItem in structure.mass:
		var shares := _spread(item.along.x, item.along.y)
		for station in shares.size():
			_own[station] += item.mass / sea.sea_density * shares[station]
	for cell: FloodCell in structure.cells:
		var shares := _spread(cell.low.x, cell.high.x)
		var first := 0
		while first < count - 1 and shares[first] == 0.0:
			first += 1
		var last := count - 1
		while last > first and shares[last] == 0.0:
			last -= 1
		_first.append(first)
		_counts.append(last - first + 1)
		_starts.append(_shares.size())
		_shares.append_array(shares.slice(first, last + 1))


## Measures [param state]'s bending into it: the share of her strength at her worst
## station, and where along her it is (FloodState.bending, bending_x).
func measure(state: FloodState) -> void:
	_motion.lift_under(state.rotation, state.sea, _lift)
	var loads := _own.duplicate()
	for cell in state.water.size():
		var water := state.water[cell]
		if water <= 0.0:
			continue
		var from := _starts[cell]
		for at in _counts[cell]:
			loads[_first[cell] + at] += water * _shares[from + at]
	# Weight and lift bear on her across her keel as far as her up stands up the world's.
	var across := state.rotation[4]
	for station in loads.size():
		loads[station] = (loads[station] - _lift[station]) * across
	var bending := moments(_bounds, loads)
	_moments = bending
	var worst := 0.0
	var where := 0.0
	for at in bending.size():
		var share := bending[at] / _hog if bending[at] >= 0.0 else bending[at] / _sag
		if absf(share) > absf(worst):
			worst = share
			where = _bounds[at]
	state.bending = worst
	state.bending_x = where


## The bending at [param x] along her at the state last measured, as a share of
## [param kept] of her strength there — positive hogging (SH33, HullBreak): the moment
## read straight between the ends of the station it falls in.
func share_at(x: float, kept: float) -> float:
	var station := 0
	var last := _bounds.size() - 2
	while station < last and _bounds[station + 1] < x:
		station += 1
	var low := _bounds[station]
	var span := _bounds[station + 1] - low
	var weight := clampf((x - low) / span, 0.0, 1.0)
	var moment := _moments[station] + (_moments[station + 1] - _moments[station]) * weight
	return moment / (_hog * kept) if moment >= 0.0 else moment / (_sag * kept)


## The bending moment at each of [param bounds] — the ends of stations aft to fore —
## under [param loads], per station what bears down on it past its lift, spread evenly
## along it: the shear from her stern added up along her, and the moment from the shear,
## positive hogging. A girder that is not at rest — a load not met by its lift, or met
## off its middle — leaves shear and moment at her far end; those are taken off along
## her, the shear as an even load, the moment growing evenly from her stern, so her ends
## carry none.
static func moments(bounds: PackedFloat64Array, loads: PackedFloat64Array) -> PackedFloat64Array:
	var count := loads.size()
	var shear := PackedFloat64Array([0.0])
	var moment := PackedFloat64Array([0.0])
	for station in count:
		var length := bounds[station + 1] - bounds[station]
		var before := shear[station]
		shear.append(before + loads[station])
		moment.append(moment[station] + before * length + loads[station] * length * 0.5)
	var start := bounds[0]
	var span := bounds[count] - start
	var left_shear := shear[count]
	var left_moment := moment[count] - left_shear * span * 0.5
	for at in count + 1:
		var along := bounds[at] - start
		moment[at] -= left_shear * along * along / (2.0 * span) + left_moment * along / span
	return moment


## The share of a load spread evenly from [param from] to [param to] along her that
## each station carries; all of it on the station nearest, where it spreads along none.
func _spread(from: float, to: float) -> PackedFloat64Array:
	var count := _bounds.size() - 1
	var shares := PackedFloat64Array()
	shares.resize(count)
	var low := clampf(from, _bounds[0], _bounds[count])
	var high := clampf(to, _bounds[0], _bounds[count])
	if high - low <= 0.0:
		var station := 0
		while station < count - 1 and _bounds[station + 1] <= low:
			station += 1
		shares[station] = 1.0
		return shares
	for station in count:
		var overlap := minf(high, _bounds[station + 1]) - maxf(low, _bounds[station])
		if overlap > 0.0:
			shares[station] = overlap / (high - low)
	return shares
