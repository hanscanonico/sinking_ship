class_name MatchServing
extends RefCounted
## The held match served on a thread ahead of its start (MatchScene.serve, Game): what
## was served is kept beside the config it was served for, so a countdown never starts
## on what was served for another's settings. Given up, it is let go without waiting —
## its task may wait on pool threads a ship's dressing holds, and those on the main
## thread's frames — and the next serving waits, frame by frame, for it to end first.

## The task serving, -1 when none runs.
var _task := -1
## The config served for, or being served for; null when none is.
var _for: MatchConfig
## Filled in on the task's thread with what it served: its own, so a task given up
## writes into nothing that is still read.
var _result: Array = []


## Whether what was served for [param config] is in hand to take: false while any task
## still runs, its own or one given up before it.
func ready_for(config: MatchConfig) -> bool:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return config != null and _for == config and not _result.is_empty()


## Whether a task still runs, given up or not: nothing new is served until it ends.
func busy() -> bool:
	return _task >= 0 and not WorkerThreadPool.is_task_completed(_task)


## Serves [param config] on a thread, [param serve_it] making what is served; whatever was
## served before is dropped. A task still running is waited for first, never alongside.
func serve(config: MatchConfig, serve_it: Callable) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_for = config
	var result: Array = []
	_result = result
	_task = WorkerThreadPool.add_task(
		func() -> void: result.append(serve_it.call()), false, "Serving a match"
	)


## What was served for [param config], taken: null when nothing is in hand for it — what
## was served for another is dropped, and the match then serves itself as it starts.
func take(config: MatchConfig) -> MatchScene.Served:
	var served: MatchScene.Served = null
	if ready_for(config):
		served = _result[0]
	_for = null
	_result = []
	return served


## Gives up whatever is served or being served, never waiting on it (the class's note).
func cancel() -> void:
	_for = null
	_result = []


## Waits for the task under way, if any: what the game does as it quits, once every
## ship's dressing has finished.
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
