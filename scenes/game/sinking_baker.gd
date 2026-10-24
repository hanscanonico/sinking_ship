class_name SinkingBaker
extends Node
## A match's sinking made on a worker thread (R20, §5b.4): its config's must-sink bakes
## run on there a step at a time (MatchConfig.bake_some) while the menu and a held
## countdown go on drawing at their own pace — no frame waits on a step, the Titanic's a
## second or more. The bake stays the same bake: only where it runs is this node's, and
## the clock it reads is the wall's, outside the sim (D2). While the thread bakes a
## sinking nothing else may touch it, so whether one is made is asked of the baker
## (done()), never of its config; a config that took that very sinking from another
## (MatchConfig.share_sinking) is the same bake under way. Given a [member cache] (a dev
## tool's --bake-cache), a sinking baked before for the very same inputs is taken from it
## rather than baked, and one baked here is kept in it.

signal baked(config: MatchConfig)

## A bake's steps per look at whether it is stopped: a step is a millisecond or two on
## the M1 Air, the Titanic's up to a second or two.
const STEPS_PER_LOOK := 1
## About as many steps as a match's bakes take, for the progress shown: SH27's census
## had 951 a bake at the median and 1.44 bakes a match.
const TYPICAL_STEPS := 1400.0
## A frame's length, in microseconds, that a budget (bake()) is a share of.
const FRAME_USEC := 16667
## The longest the thread rests between steps to keep to a budget, in microseconds.
const LONGEST_REST := 1000000

## Sinkings baked before, for a dev tool (BakeCache); null, the default, for none.
var cache: BakeCache
## The config whose sinking is wanted, told of once it is made; null for none.
var _config: MatchConfig
## The bake the thread works on — or one made at once, told of the next frame — and the
## thread's task, -1 while none runs. A bake asked to stop runs on to the end of its step,
## and is waited for before another starts.
var _bake: Bake
var _task := -1
## Wanted while the thread still bakes another sinking: started once that one stops.
var _next: MatchConfig
## Microseconds of each frame the thread bakes in, 0 for all of them.
var _budget_usec := 0
var _started_usec := 0


## A sinking the thread bakes: its config and — shared with the thread, under its lock —
## whether it is to stop and how far on it is. An object of its own, never the node, so
## the thread's call never holds the node while the tree frees it.
class Bake:
	extends RefCounted

	var config: MatchConfig
	var _budget_usec: int
	var _lock := Mutex.new()
	var _stopping := false
	var _steps := 0
	var _made := false

	## [param baked]'s bakes begun here, on the main thread, so every config that takes
	## the sinking takes the very one the thread works on (share_sinking).
	func _init(baked: MatchConfig, budget_usec: int) -> void:
		config = baked
		_budget_usec = budget_usec
		_made = baked.bake_some(0)
		_steps = baked.bake_steps()

	## On the thread: the bakes run on a step at a time until made or stopped, in
	## [member _budget_usec] of each frame when not 0.
	func run() -> void:
		var made := false
		while not made:
			_lock.lock()
			var stopping := _stopping
			_lock.unlock()
			if stopping:
				return
			var began := Time.get_ticks_usec()
			made = config.bake_some(SinkingBaker.STEPS_PER_LOOK)
			var steps := config.bake_steps()
			_lock.lock()
			_steps = steps
			_made = made
			_lock.unlock()
			if _budget_usec > 0 and not made:
				var took := Time.get_ticks_usec() - began
				var rest := took * (SinkingBaker.FRAME_USEC - _budget_usec) / _budget_usec
				OS.delay_usec(mini(rest, SinkingBaker.LONGEST_REST))

	func stop() -> void:
		_lock.lock()
		_stopping = true
		_lock.unlock()

	func steps() -> int:
		_lock.lock()
		var steps := _steps
		_lock.unlock()
		return steps

	func made() -> bool:
		_lock.lock()
		var made := _made
		_lock.unlock()
		return made


## Bakes [param config]'s sinking from where it stands, on the thread: at its full pace,
## or [param budget_ms] of each frame when given, to measure the hold or show it. One that
## took the sinking under way from another goes on with that bake.
func bake(config: MatchConfig, budget_ms := 0.0) -> void:
	_budget_usec = roundi(budget_ms * 1000.0)
	if config == _config:
		return
	_config = config
	_next = null
	if _bake == null:
		_start(config)
	elif not config.same_sinking(_bake.config):
		_bake.stop()
		_next = config


## The config being baked, or null.
func baking() -> MatchConfig:
	return _config


## Whether [param config]'s sinking is made: never while the thread is on it.
func done(config: MatchConfig) -> bool:
	if _bake != null and config.same_sinking(_bake.config):
		return false
	return config.bake_some(0)


## Stops baking: the config keeps what was baked, for whoever bakes it next.
func stop() -> void:
	_config = null
	_next = null
	if _bake != null:
		_bake.stop()


## How far on the bakes look, 0…1: their steps against a match's usual, never back.
func progress() -> float:
	if _config == null:
		return 1.0
	var steps := 0
	if _bake != null and _config.same_sinking(_bake.config):
		steps = _bake.steps()
	elif _bake == null:
		steps = _config.bake_steps()
	return 1.0 - exp(-steps / TYPICAL_STEPS)


func _process(_delta: float) -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _bake != null:
		var worked := _bake
		_bake = null
		if worked.made():
			if cache != null:
				cache.store(worked.config)
			_report(worked.config)
	if _next != null:
		var next := _next
		_next = null
		_start(next)


func _exit_tree() -> void:
	_halt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_halt()


## Stops the thread, waiting for its step under way: what leaving the tree does.
func _halt() -> void:
	_config = null
	_next = null
	if _task >= 0:
		_bake.stop()
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_bake = null


## Sets the thread on [param config]'s sinking.
func _start(config: MatchConfig) -> void:
	_started_usec = Time.get_ticks_usec()
	if cache != null and not config.bake_some(0) and cache.take(config):
		print(
			(
				"sinking taken from the bake cache in %.2f s"
				% [(Time.get_ticks_usec() - _started_usec) / 1e6]
			)
		)
	_bake = Bake.new(config, _budget_usec)
	if not _bake.made():
		_task = WorkerThreadPool.add_task(_bake.run, false, "Sinking bake")


## [param made]'s sinking is made: the config wanted is told, when it is that sinking.
func _report(made: MatchConfig) -> void:
	var wanted := _config
	if wanted == null or not (wanted == made or wanted.same_sinking(made)):
		return
	_config = null
	print(
		(
			"sinking baked in %.2f s on its thread, %d steps"
			% [(Time.get_ticks_usec() - _started_usec) / 1e6, made.bake_steps()]
		)
	)
	baked.emit(wanted)
