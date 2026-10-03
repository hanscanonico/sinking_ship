class_name SinkSchedule
extends RefCounted
## The one water authority (D7, D13): the ship's pose at any tick, and which of the
## scenario's events have fired, for whichever SinkScenario the match carries.
## Built once per match; after that it is a pure function of (scenario, seed,
## tick) — nothing a player does moves it, and it is never stored in a snapshot.


## One of the scenario's events, placed on this match's ticks.
class Scheduled:
	var event: SinkEvent
	## The tick its telegraph starts: at, for what is not telegraphed.
	var warned_at: int
	## The tick it happens.
	var at: int
	## The tick it is over: a lurch's swing is back; anything else, at.
	var ends_at: int

	func _init(scheduled_event: SinkEvent, tick: int) -> void:
		event = scheduled_event
		at = tick
		warned_at = tick
		ends_at = tick
		if event.kind == SinkEvent.Kind.LURCH or event.kind == SinkEvent.Kind.COLLAPSE:
			warned_at = tick - Ticks.from_seconds(event.warning)
		if event.kind == SinkEvent.Kind.LURCH:
			ends_at = tick + Ticks.from_seconds(event.duration)


var _freeboard: float
var _pivot: Vector3
var _start_tick: int
var _keyframe_ticks: PackedInt32Array = PackedInt32Array()
var _keyframes: Array[SinkKeyframe] = []
## In the scenario's order.
var _events: Array[Scheduled] = []
var _cap_tick := -1


## [param sink_stream] is the sinking stream, SeedStreams' (match seed, "sink"),
## and this is the only place it is drawn (D4): one draw per event, in the
## scenario's order, whatever its bound.
func _init(scenario: SinkScenario, freeboard: float, sink_stream: RandomNumberGenerator) -> void:
	_freeboard = freeboard
	_pivot = scenario.pivot
	_start_tick = Ticks.from_seconds(scenario.starts_at)
	_keyframes = scenario.keyframes.duplicate()
	for keyframe: SinkKeyframe in _keyframes:
		_keyframe_ticks.append(Ticks.from_seconds(keyframe.at))
	for event: SinkEvent in scenario.events:
		var shift := sink_stream.randf_range(-event.jitter, event.jitter)
		_events.append(Scheduled.new(event, _start_tick + Ticks.from_seconds(event.at + shift)))
	if scenario.cap > 0.0:
		_cap_tick = _start_tick + Ticks.from_seconds(scenario.cap)


func pose_at(tick: int) -> ShipPose:
	var pose := _keyframed(tick)
	var swing := 0.0
	for scheduled: Scheduled in _events:
		var event := scheduled.event
		if tick >= scheduled.warned_at and tick < scheduled.at:
			if event.kind == SinkEvent.Kind.LURCH:
				pose.lurch_warning = event.heel_deg
			elif event.kind == SinkEvent.Kind.COLLAPSE:
				pose.collapsing.append(event.platform)
		if tick < scheduled.at:
			continue
		match event.kind:
			SinkEvent.Kind.LURCH:
				if tick < scheduled.ends_at:
					pose.lurch = event.heel_deg
					var swung := float(tick - scheduled.at) / (scheduled.ends_at - scheduled.at)
					swing += event.heel_deg * sin(PI * swung)
			SinkEvent.Kind.COLLAPSE:
				pose.collapsed.append(event.platform)
			SinkEvent.Kind.RAILING_FAIL:
				pose.broken_railings.append(event.railing)
	if swing != 0.0:
		pose.heel_deg += swing
		pose.transform = _transform(pose.sink, pose.trim_deg, pose.heel_deg)
	return pose


## Every event that has happened by [param tick], in the scenario's order.
func fired(tick: int) -> Array[Scheduled]:
	var found: Array[Scheduled] = []
	for scheduled: Scheduled in _events:
		if scheduled.at <= tick:
			found.append(scheduled)
	return found


## What the sinking announces on [param tick]: every telegraph that starts, then
## every event that happens, each in the scenario's order.
func events_at(tick: int) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for scheduled: Scheduled in _events:
		if scheduled.warned_at == tick and scheduled.warned_at < scheduled.at:
			found.append(SimEvent.sinking(tick, scheduled.event, true))
	for scheduled: Scheduled in _events:
		if scheduled.at == tick:
			found.append(SimEvent.sinking(tick, scheduled.event, false))
	return found


## The tick by which every surface is under and the match ends, or -1 for none.
func cap_tick() -> int:
	return _cap_tick


## The name of the phase the sinking is in at [param tick]: the last keyframe's
## by then that names one, or "" before any does.
func phase_at(tick: int) -> String:
	var elapsed := tick - _start_tick
	var phase := ""
	for index in _keyframes.size():
		if _keyframe_ticks[index] > elapsed:
			break
		if _keyframes[index].phase != "":
			phase = _keyframes[index].phase
	return phase


## The keyframes' pose at [param tick], before any event.
func _keyframed(tick: int) -> ShipPose:
	var elapsed := tick - _start_tick
	if elapsed < 0 or _keyframes.is_empty():
		return _pose(0.0, 0.0, 0.0)
	var last := _keyframes.size() - 1
	if elapsed >= _keyframe_ticks[last]:
		var held := _keyframes[last]
		return _pose(held.sink, held.trim_deg, held.heel_deg)
	if elapsed <= _keyframe_ticks[0]:
		var first := _keyframes[0]
		return _pose(first.sink, first.trim_deg, first.heel_deg)
	var next := 1
	while _keyframe_ticks[next] <= elapsed:
		next += 1
	var from := _keyframes[next - 1]
	var to := _keyframes[next]
	var span := _keyframe_ticks[next] - _keyframe_ticks[next - 1]
	var weight := float(elapsed - _keyframe_ticks[next - 1]) / span
	return _pose(
		lerpf(from.sink, to.sink, weight),
		lerpf(from.trim_deg, to.trim_deg, weight),
		lerpf(from.heel_deg, to.heel_deg, weight)
	)


func _pose(sink: float, trim_deg: float, heel_deg: float) -> ShipPose:
	return ShipPose.new(sink, trim_deg, heel_deg, _transform(sink, trim_deg, heel_deg))


## Positive trim turns the bow (+x) down and positive heel turns starboard (+z)
## down, both about the scenario's pivot; then the ship drops by the sink.
func _transform(sink: float, trim_deg: float, heel_deg: float) -> Transform3D:
	var tilt := (
		Basis(Vector3.BACK, -deg_to_rad(trim_deg)) * Basis(Vector3.RIGHT, deg_to_rad(heel_deg))
	)
	var origin := Vector3(0.0, _freeboard - sink, 0.0) + _pivot - tilt * _pivot
	return Transform3D(tilt, origin)
