class_name SinkingBaker
extends Node
## A match's sinking made a slice a frame (R20, §5b.4): its config's must-sink bakes are
## given steps (MatchConfig.bake_some) while this frame's slice of time lasts, so
## neither the menu nor a held countdown freezes while they run. The bake stays the
## same bake — only how it is spread over frames is this node's — and the clock it
## reads is the wall's, outside the sim (D2). On the menu it runs gently; holding the
## countdown, harder.

signal baked(config: MatchConfig)

## A bake's steps per look at the clock: a step is a millisecond or two on the M1 Air.
const STEPS_PER_LOOK := 1
## About as many steps as a match's bakes take, for the progress shown: SH27's census
## had 951 a bake at the median and 1.44 bakes a match.
const TYPICAL_STEPS := 1400.0

var _config: MatchConfig
var _budget_usec := 0
var _started_usec := 0
var _frames := 0
var _longest_usec := 0
var _spent_usec := 0


## Bakes [param config]'s sinking from where it stands, [param budget_ms] of each frame
## at most — a step past it at worst.
func bake(config: MatchConfig, budget_ms: float) -> void:
	if config != _config:
		_config = config
		_started_usec = Time.get_ticks_usec()
		_frames = 0
		_longest_usec = 0
		_spent_usec = 0
	_budget_usec = roundi(budget_ms * 1000.0)


## The config being baked, or null.
func baking() -> MatchConfig:
	return _config


## Stops baking: the config keeps what was baked, for whoever bakes it next.
func stop() -> void:
	_config = null


## How far on the bakes look, 0…1: their steps against a match's usual, never back.
func progress() -> float:
	if _config == null:
		return 1.0
	return 1.0 - exp(-_config.bake_steps() / TYPICAL_STEPS)


func _process(_delta: float) -> void:
	if _config == null:
		return
	var started := Time.get_ticks_usec()
	var done := false
	while not done and Time.get_ticks_usec() - started < _budget_usec:
		done = _config.bake_some(STEPS_PER_LOOK)
	var slice := Time.get_ticks_usec() - started
	_frames += 1
	_spent_usec += slice
	_longest_usec = maxi(_longest_usec, slice)
	if not done:
		return
	var config := _config
	_config = null
	print(
		(
			"sinking baked in %.2f s over %d frames · %.2f s of it baking · the longest slice %.1f ms"
			% [
				(Time.get_ticks_usec() - _started_usec) / 1e6,
				_frames,
				_spent_usec / 1e6,
				_longest_usec / 1000.0,
			]
		)
	)
	baked.emit(config)
