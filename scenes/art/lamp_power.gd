class_name LampPower
extends RefCounted
## Her rooms' lamps lit as a pose has the cells they hang in (ShipArt.show_power): each
## handed its power and whether the water has reached it only as that changes, worked
## out for every lamp at once (#410) — in the game's extension where it is loaded, else
## here, the same either way (test_lamp_power) — and those within WAKE_REACH of the eye
## found among the lamps in its stretch of her alone, as near as a walk of every lamp
## finds them.

## How near the eye a lamp is woken to swing as she turns, in metres (near).
const WAKE_REACH := 40.0
## How much further along her than WAKE_REACH a lamp is still measured from the eye:
## far more than a float32's rounding moves a distance.
const WAKE_SLACK := 1.0

var _lamps: Array[ShipLamp] = []
var _at := PackedVector3Array()
## Per lamp, the power and drowning last handed it (power * 2 + drowned), -1 before any:
## each lamp is handed only what changed, not 2,700 of them every tick on the Titanic.
var _shown := PackedInt32Array()
## Where they hang, their cells found once a cell map and their heights worked out
## together each pose (StillPoints).
var _points: StillPoints
## The lamps by where they hang along her, and how far along her each hangs (near).
var _by_x := PackedInt32Array()
var _xs := PackedFloat64Array()
## The NativeWater the loop over every lamp goes to, or null where it runs here.
var water: Object = StillPoints.native_water()


## [param lamps], hanging at [param at] in her.
func _init(lamps: Array[ShipLamp], at: PackedVector3Array) -> void:
	_lamps = lamps
	_at = at
	_points = StillPoints.new(at)
	_shown.resize(lamps.size())
	_shown.fill(-1)
	var order := range(at.size())
	order.sort_custom(
		func(a: int, b: int) -> bool: return at[a].x < at[b].x or (at[a].x == at[b].x and a < b)
	)
	for index: int in order:
		_by_x.append(index)
		_xs.append(at[index].x)


## Hands each lamp what [param pose] — one that keeps her cells — has of its cell: its
## power, and whether its water has reached the lamp.
func show(pose: ShipPose) -> void:
	_points.read(pose)
	var cells := _points.cells()
	var world := _points.world_points()
	var changed := PackedInt32Array()
	if water != null:
		var found: Array = water.lamps_shown(cells, pose.lit, pose.levels, world, _shown)
		changed = found[0]
		_shown = found[1]
	else:
		changed = _changed(cells, pose.lit, pose.levels, world)
	for index in changed:
		var shown := _shown[index]
		var lamp := _lamps[index]
		lamp.power = shown >> 1
		lamp.drowned = shown & 1 == 1


## The lamps within WAKE_REACH of [param eye] in her, ascending: measured as a walk of
## every lamp would measure them, only those within WAKE_REACH and WAKE_SLACK of it along
## her are measured at all.
func near(eye: Vector3) -> PackedInt32Array:
	var reach := WAKE_REACH * WAKE_REACH
	var found := PackedInt32Array()
	var from := _xs.bsearch(eye.x - WAKE_REACH - WAKE_SLACK)
	var to := _xs.bsearch(eye.x + WAKE_REACH + WAKE_SLACK, false)
	for at in range(from, to):
		var index := _by_x[at]
		if _at[index].distance_squared_to(eye) <= reach:
			found.append(index)
	found.sort()
	return found


## The lamps whose power or drowning changes under a pose whose cells hold them at
## [param cells], lit [param lit], its water at [param levels] and the lamps at
## [param world]: each lamp's new state kept in _shown.
func _changed(
	cells: PackedInt32Array,
	lit: PackedByteArray,
	levels: PackedFloat64Array,
	world: PackedVector3Array
) -> PackedInt32Array:
	var changed := PackedInt32Array()
	for index in cells.size():
		var cell := cells[index]
		if cell == CellMap.NONE:
			continue
		var power: int = lit[cell]
		var drowned := levels[cell] >= world[index].y
		var shown := power * 2 + (1 if drowned else 0)
		if shown == _shown[index]:
			continue
		_shown[index] = shown
		changed.append(index)
	return changed
