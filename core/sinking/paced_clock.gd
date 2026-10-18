class_name PacedClock
extends RefCounted
## A sinking's paced clock (Q20, SinkPacing.clock_of): physics seconds after the hit to
## match seconds after it and back, a straight run between knots — each knot the second
## she first holds a share of her water, and the match second it is played at — and on
## past the last at the last pace. Before the first knot it runs one to one. Only +, −,
## × and ÷ (D4): built the same from the same timeline, on the host and on a client.

## Per knot, its physics second and its match second, both rising; the pace — physics
## seconds per match second — from the last on.
var _physics := PackedFloat64Array([0.0])
var _match := PackedFloat64Array([0.0])
var _last_pace := 1.0


## The clock that plays the physics as it is: one to one.
static func even() -> PacedClock:
	return PacedClock.new()


## Adds a knot [param physics_seconds] after the last, played [param match_seconds] after
## it — which a pace of [param pace] gives — and keeps that pace as the last.
func add(physics_seconds: float, match_seconds: float, pace: float) -> void:
	_physics.append(_physics[_physics.size() - 1] + physics_seconds)
	_match.append(_match[_match.size() - 1] + match_seconds)
	_last_pace = pace


## The match second [param seconds] of physics after the hit is played at.
func match_of(seconds: float) -> float:
	return _read(seconds, _physics, _match, 1.0 / _last_pace)


## The physics second the match stands at [param seconds] after the hit.
func physics_of(seconds: float) -> float:
	return _read(seconds, _match, _physics, _last_pace)


## [param at] on the [param from] knots, read on the [param to] knots: straight between
## the two either side, one to one before the first, on at [param past] after the last.
static func _read(
	at: float, from: PackedFloat64Array, to: PackedFloat64Array, past: float
) -> float:
	var last := from.size() - 1
	if at <= from[0]:
		return to[0] + at - from[0]
	if at >= from[last]:
		return to[last] + (at - from[last]) * past
	var low := 0
	var high := last
	while high - low > 1:
		var middle := (low + high) >> 1
		if from[middle] <= at:
			low = middle
		else:
			high = middle
	var span := from[high] - from[low]
	if span <= 0.0:
		return to[high]
	return to[low] + (at - from[low]) * (to[high] - to[low]) / span
