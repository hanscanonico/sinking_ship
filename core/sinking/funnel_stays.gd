class_name FunnelStays
extends RefCounted
## Her funnels' stays (§5b.1, "Things that give way"; step 10 of the physics): a funnel
## stands while she lists and trims within what its stays hold and the sea is under its
## foot, and falls once she passes either limit or the sea reaches its foot as she goes
## down, for good, toward her low side: along the world's down, as it stands in her
## deck's plane then (toward). It creaks once she stands creak_share of the way to a
## limit (strained), est. Her list and trim are read off her rotation as sines, a limit
## in degrees through the series sine (R21).
## Only +, −, ×, ÷ and square roots on 64-bit floats run here (D4).

var _funnels: Array[ShipFitting] = []
## Per funnel: the sines of its list and trim limits, and of creak_share of each.
var _list := PackedFloat64Array()
var _trim := PackedFloat64Array()
var _creak_list := PackedFloat64Array()
var _creak_trim := PackedFloat64Array()


## The funnels of [param structure], creaking as [param sea] says.
func _init(structure: ShipStructure, sea: SeaPhysics) -> void:
	for fitting: ShipFitting in structure.fittings:
		if fitting.kind != ShipFitting.Kind.FUNNEL or not sea.failures:
			continue
		_funnels.append(fitting)
		_list.append(Attitude.sine_of_degrees(fitting.list_limit_deg))
		_trim.append(Attitude.sine_of_degrees(fitting.trim_limit_deg))
		_creak_list.append(Attitude.sine_of_degrees(fitting.list_limit_deg * sea.creak_share))
		_creak_trim.append(Attitude.sine_of_degrees(fitting.trim_limit_deg * sea.creak_share))


## Her funnels, in her fittings' order.
func fittings() -> Array[ShipFitting]:
	return _funnels


## Every funnel of [param state] standing, at the hit.
func start(state: FloodState) -> void:
	state.fallen.resize(_funnels.size())


## Lets go, in [param next], every funnel it has brought to a limit.
func follow(next: FloodState) -> void:
	for funnel in _funnels.size():
		if next.fallen[funnel] == 0 and _gap(next, funnel) <= SinkFailures.REACHED:
			next.fallen[funnel] = 1


## Per funnel, how far [param state] stands from letting it go — the nearest of its list,
## its trim, as sines, and the sea under its foot, in metres — under 0 past it.
func gaps(state: FloodState) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	for funnel in _funnels.size():
		found.append(_gap(state, funnel))
	return found


## Whether [param funnel], standing, creaks at [param state]: she lists or trims
## creak_share of the way to its limit.
func strained(state: FloodState, funnel: int) -> bool:
	var rotation := state.rotation
	var listed := absf(rotation[7]) >= _creak_list[funnel]
	return listed or absf(rotation[3]) >= _creak_trim[funnel] or rotation[4] <= 0.0


## The way a funnel falls at [param state]: the world's down as it stands in her deck's
## plane, x then z, a unit — toward her bow when she is down by the head; toward her bow
## too where she stands so level it has none.
static func toward(state: FloodState) -> Vector2:
	var x := -state.rotation[3]
	var z := -state.rotation[5]
	var length := sqrt(x * x + z * z)
	if length <= 0.0:
		return Vector2(1.0, 0.0)
	return Vector2(x / length, z / length)


func _gap(state: FloodState, funnel: int) -> float:
	var rotation := state.rotation
	var base := _funnels[funnel].base
	var foot := rotation[3] * base.x + rotation[4] * base.y + rotation[5] * base.z
	# Her list and trim as sines: past her beam ends or on end, past them all.
	var tilted := minf(_list[funnel] - absf(rotation[7]), _trim[funnel] - absf(rotation[3]))
	return minf(minf(tilted, rotation[4]), foot - state.sea)
