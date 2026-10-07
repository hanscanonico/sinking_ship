class_name FailureFx
extends RefCounted
## What things giving way show (SH31), as FxPlanner plans the rest of the sinking: a
## door, a hatch, a window, a porthole or a wall's panel bursting — white water thrown
## through it into the side it gives way into, splinters off it; a funnel creaking and
## falling — soot coughed from its top — and landing: dust and soot billowing up where
## it comes down, wreckage raining round, and where it goes over the side, the sea
## thrown up. The pour that follows is InnerWater's, the funnel's fall ShipArt's.
## Presentation only (D12): it reads the events a step raised and the poses the
## schedule answers, and moves nothing.

## How high a burst through an opening throws its white water, in metres, at the least
## and at a head of BURST_HEAD or more across it; how far a funnel landing's dust
## spreads and its wreckage rains round; how high it throws the sea up over the side.
const BURST_RISE := Vector2(0.6, 1.8)
const BURST_HEAD := 2.0
const LANDING_DUST := 2.5
const LANDING_DEBRIS := 4.0
const LANDING_SPRAY := 3.0

var _structure: ShipStructure
var _schedule: SinkSchedule
## Every opening that can give way, by name, its own and her walls' panels'.
var _failing := {}


func _init(structure: ShipStructure, schedule: SinkSchedule) -> void:
	_structure = structure
	_schedule = schedule
	for opening: ShipOpening in schedule.failing():
		_failing[opening.name] = opening
	if structure == null:
		return
	for opening: ShipOpening in structure.openings:
		if opening.shuts_at_hit:
			_failing[opening.name] = opening


## The cues of the step to [param current], whose events it raised, from
## [param previous], under [param pose_now] — the schedule's at its tick.
func plan(
	previous: Dictionary, current: Dictionary, pose_now: ShipPose, cues: Array[FxCue]
) -> void:
	var tick: int = current["tick"]
	for event: Dictionary in current["events"]:
		match event["kind"]:
			SimEvent.Kind.OPENING_GAVE_WAY:
				_burst(_failing.get(event["cell"]), pose_now, tick, cues)
			SimEvent.Kind.FUNNEL_STRAINING, SimEvent.Kind.FUNNEL_FALLING:
				for fall: FunnelFall in pose_now.falls:
					if fall.fitting.name == event["cell"]:
						var top := fall.fitting.base + Vector3.UP * fall.fitting.height
						cues.append(FxCue.new(FxCue.Kind.BELCH, tick, top))
	for fall: FunnelFall in pose_now.falls:
		if fall.lands_at > previous["tick"] and fall.lands_at <= tick:
			_landing(fall, pose_now, tick, cues)


## [param opening] bursting at [param tick] under [param pose]: white water thrown out
## of it into the side whose water stands lower — the higher the more head across it —
## and splinters off it.
func _burst(opening: ShipOpening, pose: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	if opening == null:
		return
	var levels := PackedFloat64Array()
	var middles: Array[Vector3] = []
	for place: StringName in opening.joins:
		var cell := _structure.cell_named(place)
		levels.append(0.0 if cell == -1 else pose.levels[cell])
		var box: FloodCell = _structure.cells[cell] if cell != -1 else null
		middles.append((box.low + box.high) * 0.5 if box != null else Vector3(NAN, NAN, NAN))
	var into := 1 if levels[0] >= levels[1] else 0
	var axis := opening.facing()
	var toward := Vector3.ZERO
	if is_nan(middles[into].x):
		toward[axis] = signf(opening.centre[axis] - middles[1 - into][axis])
	else:
		toward[axis] = signf(middles[into][axis] - opening.centre[axis])
	if axis == 1:
		toward = Vector3.DOWN if into == 0 else Vector3.UP
	var half := opening.size * 0.5
	half[axis] = 0.0
	var along := Vector3.RIGHT if axis != 0 else Vector3.BACK
	var foot := opening.centre - Vector3.UP * half.y
	var spray := FxCue.new(FxCue.Kind.SPRAY, tick, foot - along * half.dot(along))
	spray.end = foot + along * half.dot(along)
	spray.toward = (toward + Vector3.UP * 0.3).normalized()
	var head := absf(levels[0] - levels[1])
	spray.strength = 1.0
	spray.rise = lerpf(BURST_RISE.x, BURST_RISE.y, clampf(head / BURST_HEAD, 0.0, 1.0))
	cues.append(spray)
	var splinters := FxCue.new(FxCue.Kind.SPLINTERS, tick, opening.centre)
	splinters.strength = 0.8
	cues.append(splinters)


## [param fall]'s funnel coming down at [param tick] under [param pose]: dust and soot
## billowing up along it, wreckage raining round where it lands, and — where its top goes
## over her side, no water of hers or deck under it — the sea thrown up there.
func _landing(fall: FunnelFall, pose: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	var foot := fall.fitting.base
	var way := Vector3(fall.along.x, 0.0, fall.along.y)
	var middle := foot + way * fall.fitting.height * 0.5
	var cloud := FxCue.new(FxCue.Kind.CLOUD, tick, middle)
	cloud.radius = LANDING_DUST
	cues.append(cloud)
	var debris := FxCue.new(FxCue.Kind.DEBRIS, tick, middle)
	debris.radius = LANDING_DEBRIS
	cues.append(debris)
	var splinters := FxCue.new(FxCue.Kind.SPLINTERS, tick, middle)
	cues.append(splinters)
	var top := foot + way * fall.fitting.height
	if pose.cell_at(top) == CellMap.NONE and pose.world_height(top) < LANDING_SPRAY:
		var spray := FxCue.new(FxCue.Kind.SPRAY, tick, top)
		spray.on_sea = true
		spray.toward = Vector3.UP
		spray.rise = LANDING_SPRAY
		cues.append(spray)
		var splash := FxCue.new(FxCue.Kind.SPLASH, tick, top)
		splash.on_sea = true
		splash.rise = LANDING_SPRAY * 0.6
		cues.append(splash)
