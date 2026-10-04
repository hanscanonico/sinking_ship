class_name SeededDraws
extends Draws
## Draws from a seeded RandomNumberGenerator: the same seed, the same draws. A few of
## its outputs give its state away, and with it every draw to come, so it never draws
## a room code on a server others play on.

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func below(count: int) -> int:
	return _rng.randi_range(0, count - 1)


func u32() -> int:
	return _rng.randi()
