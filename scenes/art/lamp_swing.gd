class_name LampSwing
extends RefCounted
## Swings the rooms' lamps of one dressed ship (ShipArt) in one loop, rather than each
## lamp processing as a node of its own — the Titanic hangs 2,700, and as she turns
## some 540 swing every frame (#410). ShipArt steps it each frame (step), where its
## lamps would have processed. A lamp whose light still has something to show — fading,
## flickering, a fire wavering — takes its whole frame as its own (ShipLamp.step); one
## whose light is settled (ShipLamp.settled) only swings, and its swing is carried here,
## in arrays, until something it shows changes (unsettle): the same sums, in the same
## order, as the lamp would do them, so every lamp hangs and burns to the bit as it did.
## A lamp woken comes awake on the next frame, as a node set processing within a frame
## does (Early).

enum State { ASLEEP, WOKEN, AWAKE }

## Every lamp it carries, by its slot (carry), and the node each hangs from.
var lamps: Array[ShipLamp] = []
var _parents: Array[Node3D] = []
var _parent_of := PackedInt32Array()
## Per slot: asleep, woken, or awake (State); whether it is in _awake; and whether its
## swing is carried here (fast) rather than by the lamp.
var _state := PackedByteArray()
var _listed := PackedByteArray()
var _fast := PackedByteArray()
## The slots awake this frame, and those woken to come awake on the next.
var _awake := PackedInt32Array()
var _woken := PackedInt32Array()
## Per slot carried here: where it hangs and how it swings, its running clock and the
## seconds since its power last dropped (ShipLamp's own), where it hangs from, and its
## slot in the globes that draw its model (-1 for a lamp drawing its own).
var _hang := PackedVector3Array()
var _swing := PackedVector3Array()
var _clock := PackedFloat64Array()
var _since := PackedFloat64Array()
var _at := PackedVector3Array()
var _globe := PackedInt32Array()
## The globes that draw the models of the lamps that do not draw their own (LampGlobes).
var _drawn_by: LampGlobes
## Per parent, the world's down under it this frame, and whether it is worked out yet.
var _downs := PackedVector3Array()
var _down_known := PackedByteArray()
var _early: Early
## The swing of the lamps only swinging, in the game's extension (NativeSwing, #410), or
## null where the GDScript swings them: each hangs to the bit alike (test_lamp_swing).
var native: Object = ArtNative.made(&"NativeSwing")


## Lets go of every lamp, and stands its Early under [param art], the node that steps it.
func reset(art: Node) -> void:
	lamps.clear()
	_parents.clear()
	_parent_of.clear()
	_state.clear()
	_listed.clear()
	_fast.clear()
	_awake.clear()
	_woken.clear()
	_hang.clear()
	_swing.clear()
	_clock.clear()
	_since.clear()
	_at.clear()
	_globe.clear()
	_drawn_by = null
	_downs.clear()
	_down_known.clear()
	if _early == null:
		_early = Early.new()
		_early.swing = self
		_early.name = "LampSwing"
		art.add_child(_early, false, Node.INTERNAL_MODE_FRONT)


## Carries [param lamp], hung from its parent for good, in the next slot — awake, as a
## lamp is when it first enters the tree — and returns it.
func carry(lamp: ShipLamp) -> ShipLamp:
	var slot := lamps.size()
	lamps.append(lamp)
	var parent := lamp.get_parent_node_3d()
	var at := _parents.find(parent)
	if at == -1:
		at = _parents.size()
		_parents.append(parent)
		_downs.append(Vector3.DOWN)
		_down_known.append(0)
	_parent_of.append(at)
	_state.append(State.ASLEEP)
	_listed.append(0)
	_fast.append(0)
	_hang.append(Vector3.DOWN)
	_swing.append(Vector3.ZERO)
	_clock.append(0.0)
	_since.append(0.0)
	_at.append(Vector3.ZERO)
	_globe.append(-1)
	lamp.carried_by(self, slot)
	wake(slot)
	return lamp


## Has [param slot]'s lamp process from the next frame on, unless it is awake already.
func wake(slot: int) -> void:
	if _state[slot] == State.ASLEEP:
		_state[slot] = State.WOKEN
		_woken.append(slot)


## Stops [param slot]'s lamp until it is woken.
func sleep(slot: int) -> void:
	_state[slot] = State.ASLEEP


## Whether [param slot]'s lamp is awake or woken.
func awake(slot: int) -> bool:
	return _state[slot] != State.ASLEEP


## Hands [param slot]'s swing back to its lamp, if it is carried here, and wakes it:
## something it shows has changed (ShipLamp's setters).
func unsettle(slot: int) -> void:
	if _fast[slot] == 1:
		_fast[slot] = 0
		lamps[slot].carry_on(_hang[slot], _swing[slot], _clock[slot], _since[slot])
	wake(slot)


## Steps every lamp awake by [param delta] seconds: as ShipLamp.step would, a lamp at a
## time, each toward the world's down under the node it hangs from. A lamp only swinging
## is swung here, its sums as the lamp's own, and its model drawn with the others' at once.
func step(delta: float) -> void:
	_down_known.fill(0)
	var awake := PackedInt32Array()
	var placing := PackedInt32Array()
	var placed: Array[Transform3D] = []
	var shown := PackedByteArray()
	var swung := _swung(delta) if native != null else _none_swung()
	var bases: Array = swung[0]
	var globes_at: Array = swung[1]
	var going: PackedByteArray = swung[2]
	var at := 0
	for slot in _awake:
		if _state[slot] != State.AWAKE:
			_listed[slot] = 0
			continue
		var lamp := lamps[slot]
		var on := true
		if _fast[slot] == 0:
			on = lamp.step(delta)
			if lamp.settled() and lamp.kind() != ShipLamp.Kind.FIRE:
				_take(slot)
		elif native != null:
			# Swung in the extension, in this order, ahead of the loop (_swung).
			lamp.basis = bases[at]
			on = going[at] == 1
			if _globe[slot] != -1:
				placing.append(_globe[slot])
				placed.append(globes_at[at])
				shown.append(1 if lamp.visible else 0)
			at += 1
		else:
			_clock[slot] += delta
			var parent := _parent_of[slot]
			if _down_known[parent] == 0:
				_down_known[parent] = 1
				var under := _parents[parent].global_basis.inverse()
				_downs[parent] = (under * Vector3.DOWN).normalized()
			var down := _downs[parent]
			var hang := _hang[slot]
			var swing := _swing[slot]
			swing += ((down - hang) * ShipLamp.STIFFNESS - swing * ShipLamp.DAMPING) * delta
			hang = (hang + swing * delta).normalized()
			_since[slot] += delta
			# ShipLamp.still, for a lamp done fading and steady.
			if swing.length() < ShipLamp.STILL and (down - hang).length() < ShipLamp.STILL:
				hang = down
				swing = Vector3.ZERO
				on = false
			_hang[slot] = hang
			_swing[slot] = swing
			var hung := Basis(Quaternion(Vector3.DOWN, hang))
			lamp.basis = hung
			if _globe[slot] != -1:
				placing.append(_globe[slot])
				placed.append(Transform3D(hung, _at[slot]))
				shown.append(1 if lamp.visible else 0)
		if on:
			awake.append(slot)
		else:
			_state[slot] = State.ASLEEP
			_listed[slot] = 0
	_awake = awake
	if not placing.is_empty():
		_drawn_by.place_all(placing, placed, shown)


## Swings every lamp awake and only swinging by [param delta] seconds in the extension,
## in the order step reaches them, each toward the world's down under the node it hangs
## from: per lamp swung, its new basis, its globe's transform and whether it swings on.
## A slow lamp step reaches first never swings here this frame, though it is taken.
func _swung(delta: float) -> Array:
	var slots := PackedInt32Array()
	var downs_of := PackedInt32Array()
	for slot in _awake:
		if _state[slot] != State.AWAKE or _fast[slot] == 0:
			continue
		var parent := _parent_of[slot]
		if _down_known[parent] == 0:
			_down_known[parent] = 1
			var under := _parents[parent].global_basis.inverse()
			_downs[parent] = (under * Vector3.DOWN).normalized()
		slots.append(slot)
		downs_of.append(parent)
	if slots.is_empty():
		return _none_swung()
	var rules := PackedFloat64Array([delta, ShipLamp.STIFFNESS, ShipLamp.DAMPING, ShipLamp.STILL])
	var found: Array = native.swing(
		slots, downs_of, _downs, _hang, _swing, _clock, _since, _at, rules
	)
	_hang = found[0]
	_swing = found[1]
	_clock = found[2]
	_since = found[3]
	return [found[5], found[6], found[4]]


## What _swung finds when it swings none.
static func _none_swung() -> Array:
	return [[], [], PackedByteArray()]


## The lamps woken over the last frame come awake: before any node's frame, as a node
## set processing then would.
func _come_awake() -> void:
	for slot in _woken:
		if _state[slot] != State.WOKEN:
			continue
		_state[slot] = State.AWAKE
		if _listed[slot] == 0:
			_listed[slot] = 1
			_awake.append(slot)
	_woken.clear()


## Carries [param slot]'s swing here from its lamp, its light settled.
func _take(slot: int) -> void:
	var state := lamps[slot].swing_state()
	_fast[slot] = 1
	_hang[slot] = state[0]
	_swing[slot] = state[1]
	_clock[slot] = state[2]
	_since[slot] = state[3]
	_at[slot] = state[4]
	_globe[slot] = state[6]
	if state[5] != null:
		assert(_drawn_by == null or _drawn_by == state[5], "one ShipArt's lamps, one globes")
		_drawn_by = state[5]


## Ahead of the frame's nodes (FrameProbe's alone before it), it brings the lamps woken
## since the last frame awake for this one.
class Early:
	extends Node

	const EARLY := -(1 << 29)

	var swing: LampSwing

	func _init() -> void:
		process_priority = EARLY

	func _process(_delta: float) -> void:
		swing._come_awake()
