class_name TimelineStream
extends RefCounted
## A match's sinking timeline on its way from the server to a room's players (D11,
## §5b.4): the server baked it, and a client never does. Its header goes out first,
## with the match's first beat; then its pages in order — each one by the time the match
## comes within timeline_lead of the first tick that reads a state of it, and beyond
## that as many more a beat as fit in timeline_bytes_per_beat (ServerRules). So the
## first minutes are there before the countdown ends, every page comes well ahead of the
## tick that needs it, and a long timeline never floods a connection.

var _sections: Array[PackedByteArray] = []
## Per section, the tick by which a client must hold it: the header's at once; a page's
## the tick the match reads between the page before and it.
var _needed := PackedInt32Array()
var _lead: int
var _budget: int
var _next := 0


## The stream of [param schedule]'s timeline, as [param rules] pace it.
func _init(schedule: SinkSchedule, rules: ServerRules) -> void:
	var timeline := schedule.timeline()
	_sections = timeline.sections()
	_lead = Ticks.from_seconds(rules.timeline_lead)
	_budget = rules.timeline_bytes_per_beat
	_needed.append(-_lead)
	for page in range(1, _sections.size()):
		var state := maxi((page - 1) * SinkTimeline.PAGE_STATES - 1, 0)
		_needed.append(schedule.physics_tick(timeline.times[state]))


## The sections to send on [param tick], in order: every one due by then, and more as
## long as the beat's bytes stay within its budget.
func due(tick: int) -> Array[int]:
	var sending: Array[int] = []
	var spent := 0
	while _next < _sections.size():
		var bytes := _sections[_next].size()
		if _needed[_next] - _lead > tick and spent + bytes > _budget:
			break
		sending.append(_next)
		spent += bytes
		_next += 1
	return sending


## The bytes of section [param index], 0 the header.
func section(index: int) -> PackedByteArray:
	return _sections[index]


## The tick by which a client must hold section [param index].
func needed_by(index: int) -> int:
	return _needed[index]


func is_done() -> bool:
	return _next == _sections.size()


func size() -> int:
	return _sections.size()
