class_name InputLog
extends RefCounted
## Every frame a match was stepped with, as received, tick by tick — with the seed
## and the data hash it was played under, so a replay refuses changed numbers.

var match_seed: int
var seats: int
var data_hash: String
var first_tick: int
var _ticks: Array[Array] = []


func _init(config: MatchConfig, from_tick: int = 0) -> void:
	match_seed = config.match_seed
	seats = config.seats
	data_hash = config.data_hash()
	first_tick = from_tick


func record(tick: int, frames: Array[InputFrame]) -> void:
	assert(tick == first_tick + _ticks.size(), "the log records ticks in order")
	_ticks.append(frames.duplicate())


## The frame [param seat] sent on [param tick], or null.
func frame(tick: int, seat: int) -> InputFrame:
	var index := tick - first_tick
	if index < 0 or index >= _ticks.size():
		return null
	var frames: Array = _ticks[index]
	return frames[seat] if seat < frames.size() else null


func last_tick() -> int:
	return first_tick + _ticks.size() - 1


## Whether this log was played under [param config]'s seed, seats and data.
func matches(config: MatchConfig) -> bool:
	return (
		config.match_seed == match_seed
		and config.seats == seats
		and config.data_hash() == data_hash
	)


## One source per seat that answers this log's frames.
func replay_sources() -> Array[InputSource]:
	var sources: Array[InputSource] = []
	for seat in seats:
		sources.append(ReplayInputSource.new(self, seat))
	return sources
