class_name SimDriver
extends Node
## The only thing in a scene that steps the match (D2): an accumulator that runs a
## PlayedMatch — a LoopbackMatch, the local host and this player's client over the
## wire between them (SH11), or a RemoteMatch played from a server (SH12) — at 30 Hz
## however fast frames come, and keeps the client's last two views for the scene to
## interpolate between. The scene reads the client's views, never the host (D5).
## Or, watching a replay (start_replay, R4), it steps a ReplayTimeline at the pace a
## ReplayClock sets — paused, a tick at a time, or at a speed — and seeks it; the
## scene reads the same two views either way, and never knows which it is drawing.

signal stepped(events: Array[SimEvent])
## The local seat's predicted body moved [param by] as the client caught up with
## the host: the view draws the jump away (D12).
signal corrected(by: Vector3)
## The replay was sought to [param tick]: both views are its snapshot now, and whatever
## presentation built from the ticks before is to be built again from it (D5).
signal sought(tick: int)

## A long hitch is dropped rather than caught up, so a stall never fast-forwards.
const MAX_STEPS_PER_FRAME := 5

var client: MatchClient
var previous: Dictionary
var current: Dictionary
## How far the display is from [member previous] to [member current], 0…1.
var alpha: float

var _played: PlayedMatch
var _accumulator := 0.0
## The replay watched instead of a match played (start_replay), and its pace.
var _timeline: ReplayTimeline
var _clock: ReplayClock


func start(played: PlayedMatch) -> void:
	_timeline = null
	_clock = null
	_played = played
	client = played.client
	previous = client.view()
	current = client.view()
	alpha = 0.0
	_accumulator = 0.0


## Watches [param timeline] instead of playing a match: stepped from where it stands at
## [param rules]' speeds, 1× first, playing.
func start_replay(timeline: ReplayTimeline, rules: ReplayRules) -> void:
	_played = null
	client = null
	_timeline = timeline
	_clock = ReplayClock.new(rules.speeds)
	previous = timeline.snapshot()
	current = previous
	alpha = 0.0
	_accumulator = 0.0


## Whether a match or a replay is under way.
func started() -> bool:
	return client != null or _timeline != null


func replaying() -> bool:
	return _timeline != null


## The sim whose views these are: the client's prediction, or the replay's.
func sim() -> MatchSim:
	return _timeline.sim() if replaying() else client.sim


func config() -> MatchConfig:
	return sim().config


## The newest view: the client's, or the replay's snapshot.
func latest() -> Dictionary:
	return _timeline.snapshot() if replaying() else client.view()


## Whether the match has ended, or the replay has reached its end.
func is_over() -> bool:
	return _timeline.at_end() if replaying() else client.is_over()


## The replay's pace; null while a match is played.
func clock() -> ReplayClock:
	return _clock


func timeline() -> ReplayTimeline:
	return _timeline


## One beat of the match, now.
func step() -> void:
	previous = current
	var events: Array[SimEvent]
	if replaying():
		events = _timeline.step()
		current = _timeline.snapshot()
	else:
		events = _played.step()
		current = client.view()
		if client.correction != Vector3.ZERO:
			corrected.emit(client.correction)
	stepped.emit(events)


## The replay one tick on, shown at once — or, with [param direction] under 0, back to
## the tick before. Meant while the clock is paused; nothing while a match is played.
func step_once(direction: int) -> void:
	if not replaying():
		return
	if direction < 0:
		seek(_timeline.tick() - 1)
		return
	if _timeline.at_end():
		return
	step()
	previous = current
	alpha = 0.0
	_clock.reset()


## The replay to [param tick], clamped to it: both views its snapshot there, and
## sought told. Nothing while a match is played.
func seek(tick: int) -> void:
	if not replaying():
		return
	_timeline.seek(tick)
	_clock.reset()
	previous = _timeline.snapshot()
	current = previous
	alpha = 0.0
	sought.emit(_timeline.tick())


func _process(delta: float) -> void:
	if replaying():
		_advance_replay(delta)
		return
	if client == null:
		return
	if client.is_over():
		previous = current
		alpha = 0.0
		return
	_accumulator += delta
	var steps := 0
	while _accumulator >= Ticks.SECONDS_PER_TICK and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= Ticks.SECONDS_PER_TICK
		steps += 1
		step()
		if client.is_over():
			break
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = minf(_accumulator, Ticks.SECONDS_PER_TICK)
	alpha = clampf(_accumulator / Ticks.SECONDS_PER_TICK, 0.0, 1.0)


## The replay on by [param delta] seconds at the clock's pace; standing still, on the
## newest snapshot, while paused or at its end.
func _advance_replay(delta: float) -> void:
	var steps := _clock.advance(delta, _timeline.at_end())
	if _clock.paused or _timeline.at_end():
		previous = current
		alpha = 0.0
		return
	for _step in steps:
		step()
		if _timeline.at_end():
			break
	alpha = _clock.alpha()
