class_name HullSection
extends Resource
## One cut across the hull (§5b.2): the outline of everything enclosed at [member x] —
## the hull from its keel to its sheer and the deckhouses on it — standing for the
## stretch of hull [member length] long about it. Ship-local metres (D6).

## Where along the ship it is cut, and the length of hull it stands for, centred on it.
@export var x: float
@export var length: float
## Closed and counter-clockwise in (z, y) — z to starboard, y up — its last point
## joining its first.
@export var outline: PackedVector2Array


## The z of the outline's outermost point at height [param y] on [param side] — 1 for
## starboard, -1 for port: where her shell stands there; NAN where the outline does not
## reach that height.
func shell_at(y: float, side: int) -> float:
	var outermost := -INF
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if a.y == b.y or (a.y - y) * (b.y - y) > 0.0:
			continue
		var z := a.x + (float(b.x) - a.x) * (y - a.y) / (float(b.y) - a.y)
		outermost = maxf(outermost, z * side)
	return outermost * side if outermost > -INF else NAN


## Every reason this section cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if length <= 0.0:
		found.append("structure: section at x %s has no length" % x)
	if outline.size() < 3:
		found.append("structure: section at x %s has no outline" % x)
		return found
	var twice := 0.0
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		twice += float(a.x) * b.y - float(b.x) * a.y
	if twice <= 0.0:
		found.append("structure: section at x %s is not counter-clockwise" % x)
	return found
