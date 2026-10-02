class_name WaterLevel
extends RefCounted
## How high the water stands: it rises at a fixed rate over time and stops at its
## maximum. A value — `advanced` returns a new level and leaves this one alone.
##
## Node-free like the rest of `core/`.

var height: float
var rise_rate: float
var max_height: float


func _init(start_height: float, rate: float, ceiling: float) -> void:
	max_height = maxf(ceiling, 0.0)
	rise_rate = maxf(rate, 0.0)
	height = clampf(start_height, 0.0, max_height)


func advanced(seconds: float) -> WaterLevel:
	var risen: float = height + rise_rate * maxf(seconds, 0.0)
	return WaterLevel.new(risen, rise_rate, max_height)


func is_full() -> bool:
	return height >= max_height
