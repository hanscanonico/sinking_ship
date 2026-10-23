class_name BotsAhead
extends RefCounted
## A served match's bots (D10) deciding each beat a beat ahead, on a worker thread, while
## the frames before it are drawn: once every bot of them has been shown the snapshot a
## step made (InputSource.observe), their frames for the next tick are worked out — each
## bot's next_frame, in seat order, as the host's runner asks them at its next step — and
## handed over as the runner asks for them, waited for only if they are not done yet.
## Nothing any bot decides changes, nor when: a bot reads only what it has been shown, so
## deciding as soon as it has been shown is deciding when asked; and it shares nothing
## with the rest of the match but what nobody changes — the snapshots and poses handed it
## — its views, floors, walk graphs and Surfaces its own. Only which thread does the
## work, and when, is this class's: the beat's own time, outside the sim (D2).

## Every one with a beat under way: kept until that beat is waited for, so none is freed
## while its thread works on it, and the game, quitting, waits for them all.
static var _under_way: Array[BotsAhead] = []

var _bots: Array[InputSource] = []
## How many of them have been shown the latest snapshot.
var _shown := 0
## The tick the frames worked out ahead are for, and per bot its frame and whether it is
## there to take.
var _tick := -1
var _frames: Array[InputFrame] = []
var _ready := PackedByteArray()
## The worker's task deciding them, or -1.
var _task := -1


## [param sources], one per seat, with each bot among them deciding ahead: one BotsAhead
## for them all, so they decide on one thread in seat order. Any other source — a seat's
## buffer, a bot's timer — is left as it is.
static func of(sources: Array[InputSource]) -> Array[InputSource]:
	var group := BotsAhead.new()
	var made: Array[InputSource] = []
	for source: InputSource in sources:
		if source is BotInputSource:
			made.append(Seat.new(group, group._bots.size()))
			group._bots.append(source)
		else:
			made.append(source)
	group._frames.resize(group._bots.size())
	group._ready.resize(group._bots.size())
	return made


## Waits for every beat under way: what the game does as it quits.
static func finish_all() -> void:
	for group: BotsAhead in _under_way.duplicate():
		group._finish()


## How many matches' bots have a beat under way, not yet waited for.
static func under_way() -> int:
	return _under_way.size()


## Bot [param index] shown [param snapshot] at [param pose]; the last of them shown it,
## the next tick's decisions start — but for a match that has ended.
func _observe(index: int, snapshot: Dictionary, pose: ShipPose) -> void:
	_finish()
	_bots[index].observe(snapshot, pose)
	_shown += 1
	if _shown < _bots.size():
		return
	_shown = 0
	_ready.fill(0)
	if snapshot["phase"] == MatchState.Phase.ENDED:
		return
	# The one thing of a pose worked out on first asking, worked out here: the rest of
	# the match reads the same pose meanwhile, so the bots' thread only reads it.
	for piece: ShipPose in [pose] + pose.pieces:
		piece.highest_water()
	_tick = snapshot["tick"]
	_under_way.append(self)
	_task = WorkerThreadPool.add_task(_decide, false, "Bots deciding ahead")


## On the worker: every bot's frame for the tick ahead, in seat order.
func _decide() -> void:
	for index in _bots.size():
		_frames[index] = _bots[index].next_frame(_tick)
		_ready[index] = 1


## Bot [param index]'s frame for [param tick]: the one decided ahead, once its beat is
## done — else, for a tick it was not decided for, decided now.
func _frame(index: int, tick: int) -> InputFrame:
	_finish()
	if tick == _tick and _ready[index] == 1:
		_ready[index] = 0
		return _frames[index]
	return _bots[index].next_frame(tick)


func _replans(index: int) -> int:
	_finish()
	var bot := _bots[index] as BotInputSource
	return bot.replans()


func _finish() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_under_way.erase(self)


## A bot's seat, its frames decided ahead with the rest of the match's bots.
class Seat:
	extends InputSource
	var _group: BotsAhead
	var _index: int

	func _init(group: BotsAhead, index: int) -> void:
		_group = group
		_index = index

	func next_frame(tick: int) -> InputFrame:
		return _group._frame(_index, tick)

	func observe(snapshot: Dictionary, pose: ShipPose) -> void:
		_group._observe(_index, snapshot, pose)

	## How many times its brain has searched the walk graph afresh (BotBrain.replans).
	func replans() -> int:
		return _group._replans(_index)
