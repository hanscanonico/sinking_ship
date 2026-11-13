class_name WatchedStepper
extends SinkStepper
## SinkStepper with every step it takes handed to its watch (FloodWatch, #619): the step
## as it begins its sweep — turned to where it starts, its air begun, its wells' water
## given — the water as each stage leaves it, and the state it comes to. It reads, never
## writes: a bake of it is the bake of a SinkStepper, step for step. The pieces she breaks
## into are watched by the same watch (HullBreak.split).

var watch: FloodWatch
## The held cells of the step under way, as its sweep found them.
var _held_cells := PackedInt32Array()


func _init(structure: ShipStructure, damage: HitDamage, sea: SeaPhysics) -> void:
	super(structure, damage, sea)
	watch = FloodWatch.new()


func advance(state: FloodState) -> FloodState:
	watch.advancing = true
	var next := super.advance(state)
	watch.advancing = false
	return next


func step(state: FloodState, seconds: float) -> FloodState:
	watch.released = PackedInt32Array()
	var next := super.step(state, seconds)
	watch.stepped(self, state, next, seconds, _held_cells, _shares)
	return next


## The group let go, told to the watch (FloodWatch.RELEASED).
func _release(
	group: PackedInt32Array,
	state: FloodState,
	heads: PackedFloat64Array,
	sea: float,
	seconds: float
) -> void:
	watch.released.append_array(group)
	super._release(group, state, heads, sea, seconds)


## The sweep watched: begun where the step starts — its water before its wells took the
## sea's and after — and the water it leaves, before her pumps lift theirs out.
func _sweep(
	state: FloodState, next: FloodState, heads: PackedFloat64Array, sea: float, seconds: float
) -> PackedFloat64Array:
	_held_cells.clear()
	for cell in _held.size():
		if _held[cell] == 1:
			_held_cells.append(cell)
	watch.begun(self, _air, _shipped, _in_floor, _boxes, state)
	watch.mark(state.water)
	watch.mark(next.water)
	var left := super._sweep(state, next, heads, sea, seconds)
	watch.mark(next.water)
	return left
