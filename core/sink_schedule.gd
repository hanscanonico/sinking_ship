class_name SinkSchedule
extends RefCounted
## The one water authority (D7, D13): the ship's pose at any tick, for whichever
## SinkScenario the match carries. Built once per match; after that the pose is a
## pure function of (scenario, seed, tick) — nothing a player does moves it, and it
## is never stored in a snapshot.

var _freeboard: float
var _pivot: Vector3
var _start_tick: int
var _keyframe_ticks: PackedInt32Array = PackedInt32Array()
var _keyframes: Array[SinkKeyframe] = []


## [param _sink_stream] is the sinking stream, SeedStreams' (match seed, "sink"),
## and this is the only place it may be drawn (D4). SH1's scenarios carry no jitter,
## so nothing draws from it yet.
func _init(scenario: SinkScenario, freeboard: float, _sink_stream: RandomNumberGenerator) -> void:
	_freeboard = freeboard
	_pivot = scenario.pivot
	_start_tick = Ticks.from_seconds(scenario.starts_at)
	_keyframes = scenario.keyframes.duplicate()
	for keyframe: SinkKeyframe in _keyframes:
		_keyframe_ticks.append(Ticks.from_seconds(keyframe.at))


func pose_at(tick: int) -> ShipPose:
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


## Positive trim turns the bow (+x) down and positive heel turns starboard (+z)
## down, both about the scenario's pivot; then the ship drops by the sink.
func _pose(sink: float, trim_deg: float, heel_deg: float) -> ShipPose:
	var tilt := (
		Basis(Vector3.BACK, -deg_to_rad(trim_deg)) * Basis(Vector3.RIGHT, deg_to_rad(heel_deg))
	)
	var origin := Vector3(0.0, _freeboard - sink, 0.0) + _pivot - tilt * _pivot
	return ShipPose.new(sink, trim_deg, heel_deg, Transform3D(tilt, origin))
