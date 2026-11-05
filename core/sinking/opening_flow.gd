class_name OpeningFlow
extends RefCounted
## The laws water passes an opening by (§5b.1), as SinkStepper's step asks them: the
## orifice law where both sides stand over it, the weir law over a sill, a wall's
## opening part under and part over, each solved over the step where it has a closed
## form. Only +, −, ×, ÷ and square roots on 64-bit floats run here (D4, R21). Metres,
## seconds.

## Under LEVEL_HEAD an opening passes water in proportion to the head, not its root
## (root). Metres.
const LEVEL_HEAD := 1e-2

var _g: float
var _discharge: float


func _init(sea: SeaPhysics) -> void:
	_g = sea.gravity
	_discharge = sea.discharge


## The water an opening of [param area] passes in [param seconds] with
## [param difference] of head across it, the two sides' heads moving [param give]
## together per m³ it passes: the orifice law, discharge × area × √(2g × difference),
## solved over the step — the root of the difference falls evenly — so it lands on the
## level and never past it.
func orifice(area: float, difference: float, give: float, seconds: float) -> float:
	var rate := _discharge * area * sqrt(2.0 * _g)
	if give <= 0.0:
		return rate * root(difference) * seconds
	var falling := sqrt(difference) - rate * give * seconds * 0.5
	var left := falling * falling if falling > 0.0 else 0.0
	return (difference - left) / give


## The square root of the head [param difference] across an opening, but in proportion
## to it under LEVEL_HEAD: the root's slope runs to infinity at the level, which no real
## opening's flow does and no solve for a held head could follow.
static func root(difference: float) -> float:
	if difference >= LEVEL_HEAD:
		return sqrt(difference)
	return difference / sqrt(LEVEL_HEAD)


## The water a sill of [param width] passes in [param seconds] with [param depth] of
## water over it, the upstream side's head falling [param give] per m³: the weir law,
## ⅔ × discharge × width × √(2g) × depth^1.5, solved over the step.
func weir(width: float, depth: float, give: float, seconds: float) -> float:
	var rate := 2.0 / 3.0 * _discharge * width * sqrt(2.0 * _g)
	if give <= 0.0:
		return rate * depth * sqrt(depth) * seconds
	var inverse_root := 1.0 / sqrt(depth) + rate * give * seconds * 0.5
	return (depth - 1.0 / (inverse_root * inverse_root)) / give


## The flow through a wall's opening [param width] wide from [param bottom] to
## [param top], the water at [param high] on one side and [param low] on the other,
## in m³/s: the orifice law where both sides are over it, the weir law summed over the
## rest of its wet height.
func wall_flow(width: float, bottom: float, top: float, high: float, low: float) -> float:
	var rate := _discharge * width * sqrt(2.0 * _g)
	var flow := 0.0
	var under := minf(low, top) - bottom
	if under > 0.0:
		flow += rate * under * root(high - low)
	var from := maxf(bottom, low)
	var to := minf(top, high)
	if to > from:
		var deep := high - from
		var shallow := high - to
		flow += rate * 2.0 / 3.0 * (deep * sqrt(deep) - shallow * sqrt(shallow))
	return flow
