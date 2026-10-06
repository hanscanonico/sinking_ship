class_name SinkSchedule
extends RefCounted
## The one water authority (D7, D13): the ship's pose at any tick, the water in every
## cell, which watertight doors are shut, what the sinking has announced, and the
## iceberg hit — where it struck and when. A physical scenario's sinking is baked once,
## at match start, from the hit the must-sink rule chose (MustSink) or the explicit one
## the scenario gives: SinkStepper run in the steps it chooses to the end (SinkTimeline),
## read between its steps — her attitude turned from one kept rotation to the next, the
## sea and each cell's water carried between them — her trim and heel read off it for
## the HUD and every reader, its lurches warned, and the phase she is in named from where
## she stands. An authored fixture plays its keyframes and events. Either
## way, once built it is a pure function of (ship, scenario, seed, tick) — nothing a
## player does moves it, and it is never stored in a snapshot (D5).

## The phases the physics names, from where she stands (§5b.4): past these many degrees
## of list she is capsizing, past these listing; past these of trim she is by the head
## or the stern — whichever lean is the more of its own mark (est.).
const CAPSIZING_DEG := 30.0
const LISTING_DEG := 5.0
const TRIMMED_DEG := 2.0


## One of an authored scenario's events, placed on this match's ticks.
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
var _hit: IcebergHit
var _damage: HitDamage
var _hit_tick := -1
## The physics' sinking: how the hit was chosen, the bake, the match tick of each of
## its kept seconds, her cells, and the doors the ship shuts with the seconds each
## takes.
var _choice: MustSink.Choice
var _timeline: SinkTimeline
var _frame_ticks := PackedInt32Array()
var _cells: CellMap
var _doors: Array[StringName] = []
var _door_times := PackedFloat64Array()
var _passages: Array[ShipOpening] = []
var _clock := 1.0
## What the physics announces, on its ticks, in the timeline's order; and the tick she
## is gone, or -1.
var _physics_events: Array[SimEvent] = []
var _gone_tick := -1
var _plunge_tick := -1
## Per kept step, its rotation as the world turns her; her centre of mass, which she
## turns about; the physics' lurches — the ticks each is warned, swings and is over, and
## the list it swings her by; the tick she passes the attitude a match follows, or -1;
## the tick a cell first takes water, or -1; and the tick the water stopped with her
## afloat, or -1.
var _turns: Array[Quaternion] = []
var _pivot_of_mass := Vector3.ZERO
var _lurch_ticks := PackedInt32Array()
var _lurch_heels := PackedFloat64Array()
var _unsupported_tick := -1
var _flooding_tick := -1
var _afloat_tick := -1


## [param sink_stream] is the sinking stream, SeedStreams' (match seed, "sink"),
## and this is the only place it is drawn (D4): the must-sink rule draws every hit it
## tries from it, on [param structure] — the hit, then its unevenness, the doors that
## jam and the openings left open — before the accepted bake, under [param sea]'s
## physics. Without a structure — the menu's backdrop — no hit is struck.
func _init(
	scenario: SinkScenario,
	freeboard: float,
	sink_stream: RandomNumberGenerator,
	structure: ShipStructure = null,
	sea: SeaPhysics = null
) -> void:
	_freeboard = freeboard
	_pivot = scenario.pivot
	_start_tick = Ticks.from_seconds(scenario.starts_at)
	_keyframes = scenario.keyframes.duplicate()
	for keyframe: SinkKeyframe in _keyframes:
		_keyframe_ticks.append(Ticks.from_seconds(keyframe.at))
	for event: SinkEvent in scenario.events:
		_events.append(Scheduled.new(event, _start_tick + Ticks.from_seconds(event.at)))
		if event.kind == SinkEvent.Kind.PLUNGE and _plunge_tick == -1:
			_plunge_tick = _events.back().at
	if structure == null or not scenario.is_physical():
		return
	var physics := sea if sea != null else SeaPhysics.load_default()
	var centre := structure.mass_centre()
	_pivot_of_mass = Vector3(centre[0], centre[1], centre[2])
	if scenario.explicit_hit != null:
		_choice = MustSink.given(structure, scenario, physics)
	else:
		_choice = MustSink.choose(structure, scenario, sink_stream, physics)
	_hit = _choice.hit
	_damage = _choice.damage
	_timeline = _choice.timeline
	_hit_tick = _start_tick + Ticks.from_seconds(_hit.moment)
	_clock = scenario.clock
	_cells = CellMap.new(structure)
	for opening: ShipOpening in structure.openings:
		if opening.shuts_at_hit and not opening.name in _damage.jammed:
			_doors.append(opening.name)
			_door_times.append(opening.shut_time)
		if opening.starts == ShipOpening.Start.OPEN or opening.name in _damage.left_open:
			_passages.append(opening)
	_passages.append_array(_damage.openings)
	for frame in _timeline.count():
		_frame_ticks.append(_tick_of(_timeline.times[frame]))
		_turns.append(_turn_of(frame).get_rotation_quaternion())
	var unsupported := _timeline.first_past(physics.supported_deg)
	if unsupported != -1:
		_unsupported_tick = _frame_ticks[unsupported]
	for event: SinkTimeline.Event in _timeline.events:
		var tick := _tick_of(event.seconds)
		_physics_events.append(SimEvent.physics(tick, event.kind, event.name, event.heel_deg))
		match event.kind:
			SinkTimeline.Kind.PLUNGING:
				_plunge_tick = tick
			SinkTimeline.Kind.FLOODING:
				_flooding_tick = tick if _flooding_tick == -1 else _flooding_tick
			SinkTimeline.Kind.LURCHING:
				_lurch_ticks.append(tick)
			SinkTimeline.Kind.LURCHED:
				_lurch_ticks.append(tick)
				_lurch_ticks.append(tick + Ticks.from_seconds(event.lasts / _clock))
				_lurch_heels.append(event.heel_deg)
	if _timeline.gone_at >= 0.0:
		_gone_tick = _tick_of(_timeline.gone_at)
	if _timeline.end == SinkTimeline.End.AFLOAT:
		_afloat_tick = end_tick()


## The schedule of [param config]'s match: its scenario on its ship, off its own
## sinking stream.
static func for_match(config: MatchConfig) -> SinkSchedule:
	var sink_stream := SeedStreams.derive(config.match_seed, "sink")
	return new(config.scenario, config.ship.freeboard, sink_stream, config.ship.structure)


## The match tick [param seconds] of physics after the hit is, through the scenario's
## clock (Q20, deferred) and Ticks, the one conversion.
func _tick_of(seconds: float) -> int:
	return _hit_tick + Ticks.from_seconds(seconds / _clock)


func pose_at(tick: int) -> ShipPose:
	if _timeline != null:
		return _physical(tick)
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


## The pose the bake has at [param tick], read between the two kept steps either side
## of it: her rotation turned from one to the other the short way round, the sea's
## height up her and every cell's water carried between them; at rest before the hit and
## as last kept after the end. She turns about her centre of mass, which keeps its place
## across the world, and stands as high as the sea up her says — at rest at her
## freeboard, as an authored pose does. Her trim and heel are read off the rotation.
func _physical(tick: int) -> ShipPose:
	var last := _frame_ticks.size() - 1
	var frame := 0
	var weight := 0.0
	if tick >= _frame_ticks[last]:
		frame = last
	elif tick > _hit_tick:
		frame = _frame_ticks.bsearch(tick, false) - 1
		var span := _frame_ticks[frame + 1] - _frame_ticks[frame]
		weight = float(tick - _frame_ticks[frame]) / span if span > 0 else 1.0
	var next := mini(frame + 1, last)
	var sea := lerpf(_timeline.seas[frame], _timeline.seas[next], weight)
	var turn := Basis(_turns[frame].slerp(_turns[next], weight))
	var sink := sea - _timeline.rest
	var origin := turn * -_pivot_of_mass + _pivot_of_mass
	origin.y = _freeboard - sink
	var trim_deg := rad_to_deg(atan2(-turn.x.y, turn.x.x))
	var heel_deg := rad_to_deg(atan2(turn.y.z, turn.z.z))
	var pose := ShipPose.new(sink, trim_deg, heel_deg, Transform3D(turn, origin))
	pose.cells = _cells
	var count := _timeline.cells
	pose.levels.resize(count)
	for cell in count:
		var head := lerpf(
			_timeline.heads[frame * count + cell], _timeline.heads[next * count + cell], weight
		)
		pose.levels[cell] = head + origin.y
	if tick >= _hit_tick:
		var seconds := Ticks.to_seconds(tick - _hit_tick) * _clock
		for door in _doors.size():
			pose.doors_shut[_doors[door]] = 1.0 - SinkStepper.open_share(_door_times[door], seconds)
	for lurch in _lurch_heels.size():
		if tick >= _lurch_ticks[lurch * 3] and tick < _lurch_ticks[lurch * 3 + 1]:
			pose.lurch_warning = _lurch_heels[lurch]
		elif tick >= _lurch_ticks[lurch * 3 + 1] and tick < _lurch_ticks[lurch * 3 + 2]:
			pose.lurch = _lurch_heels[lurch]
	return pose


## Kept step [param frame]'s rotation as a Basis: the world's axes of her ship's.
func _turn_of(frame: int) -> Basis:
	var r := _timeline.rotations.slice(frame * 9, frame * 9 + 9)
	return Basis(Vector3(r[0], r[3], r[6]), Vector3(r[1], r[4], r[7]), Vector3(r[2], r[5], r[8]))


## Every event of an authored scenario that has happened by [param tick], in its order.
func fired(tick: int) -> Array[Scheduled]:
	var found: Array[Scheduled] = []
	for scheduled: Scheduled in _events:
		if scheduled.at <= tick:
			found.append(scheduled)
	return found


## What the sinking announces on [param tick]: the iceberg striking, then every
## telegraph that starts, then every event that happens, each in the scenario's order.
func events_at(tick: int) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	if tick == _hit_tick:
		found.append(SimEvent.holed(tick))
	for event: SimEvent in _physics_events:
		if event.tick == tick:
			found.append(event)
	for scheduled: Scheduled in _events:
		if scheduled.warned_at == tick and scheduled.warned_at < scheduled.at:
			found.append(SimEvent.sinking(tick, scheduled.event, true))
	for scheduled: Scheduled in _events:
		if scheduled.at == tick:
			found.append(SimEvent.sinking(tick, scheduled.event, false))
	return found


## The tick the sinking ends on: the bake's last kept second, or an authored
## fixture's last keyframe. What was the cap, before the physics (§5b.4).
func end_tick() -> int:
	if _timeline != null:
		return _frame_ticks[_frame_ticks.size() - 1]
	if _keyframes.is_empty():
		return -1
	return _start_tick + _keyframe_ticks[_keyframe_ticks.size() - 1]


## The tick she is wholly under the sea and going down, or -1 when she never is: an
## authored fixture, or an explicit hit she floats on.
func gone_tick() -> int:
	return _gone_tick


## The tick the plunge begins — her main deck under the sea, or an authored fixture's
## PLUNGE — or -1 for never.
func plunge_tick() -> int:
	return _plunge_tick


## The tick she first stands further from upright than a match follows her
## (SeaPhysics.supported_deg, §5b.3's interim rule until SH32), or -1 for never: on it
## the match settles, everyone left going out together.
func unsupported_tick() -> int:
	return _unsupported_tick


## How the match's hit was chosen and baked, or null without a physical sinking.
func choice() -> MustSink.Choice:
	return _choice


## The openings water can pass after the hit, as the physics has them (SinkStepper):
## those that start open or were left open, and the gash's — a door the ship shuts,
## while the pose has it open. Empty without a physical sinking.
func passages() -> Array[ShipOpening]:
	return _passages


## The bake, or null without a physical sinking.
func timeline() -> SinkTimeline:
	return _timeline


## The match's iceberg hit as drawn, or null for none.
func hit() -> IcebergHit:
	return _hit


## What the hit does to the ship — its gash and the fittings it finds — or null for
## none.
func damage() -> HitDamage:
	return _damage


## The tick the iceberg strikes, or -1 for none.
func hit_tick() -> int:
	return _hit_tick


## The name of the phase the sinking is in at [param tick], or "" before it has one.
## The physics' is named from where she stands then (§5b.4): Holed until a cell takes
## water, then Flooding; Listing, By the head or By the stern once she leans past their
## marks; Capsizing past its list; Afloat once the water has stopped. An authored
## fixture's is the last keyframe's by then that names one.
func phase_at(tick: int) -> String:
	if _timeline != null:
		return _physical_phase(tick)
	var elapsed := tick - _start_tick
	var phase := ""
	for index in _keyframes.size():
		if _keyframe_ticks[index] > elapsed:
			break
		if _keyframes[index].phase != "":
			phase = _keyframes[index].phase
	return phase


func _physical_phase(tick: int) -> String:
	if tick < _hit_tick:
		return ""
	if _afloat_tick != -1 and tick >= _afloat_tick:
		return "Afloat"
	var pose := _physical(tick)
	var listing := absf(pose.heel_deg) / LISTING_DEG
	var trimmed := absf(pose.trim_deg) / TRIMMED_DEG
	if absf(pose.heel_deg) >= CAPSIZING_DEG:
		return "Capsizing"
	if listing >= 1.0 and listing >= trimmed:
		return "Listing"
	if trimmed >= 1.0:
		return "By the head" if pose.trim_deg > 0.0 else "By the stern"
	return "Flooding" if _flooding_tick != -1 and tick >= _flooding_tick else "Holed"


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
