class_name FallenFunnels
extends RefCounted
## Her funnels as Surfaces meets them once they have come down (SH31, FunnelFall): the
## upright blocker each stood as holds nothing over its foot any more, and the funnel
## lying along the strip it fell across holds a body back as a wall does — from the deck
## at its foot to its girth over it — and stops and hides a shove's line there. As far
## down as the pose says (ShipPose.felled); the strip's way is the schedule's.
## Ship-local metres (D6).

## Per funnel of the layout's structure, the layout's blocker it stands on, -1 for none;
## and the falls the pose last honoured has landed.
var _funnels: Array[ShipFitting] = []
var _blockers := PackedInt32Array()
var _down: Array[FunnelFall] = []


func _init(layout: ShipLayout) -> void:
	if layout.structure == null:
		return
	for fitting: ShipFitting in layout.structure.fittings:
		if fitting.kind != ShipFitting.Kind.FUNNEL:
			continue
		_funnels.append(fitting)
		var on := -1
		for index in layout.blockers.size():
			if stands_on(fitting, layout.blockers[index]):
				on = index
		_blockers.append(on)


## Whether [param fitting] — a funnel — stands on [param blocker]: its foot within the
## blocker's round and its height.
static func stands_on(fitting: ShipFitting, blocker: ShipBlocker) -> bool:
	if blocker.shape != ShipBlocker.Shape.CYLINDER:
		return false
	var foot := Vector2(fitting.base.x, fitting.base.z)
	var round := foot.distance_to(blocker.centre) <= blocker.radius
	return round and fitting.base.y >= blocker.bottom and fitting.base.y < blocker.top


## Takes the falls [param pose] has landed; whether they differ from those it had.
func honour(pose: ShipPose) -> bool:
	if pose.felled == _down:
		return false
	_down = pose.felled.duplicate()
	return true


## The top blocker [param blocker] of the layout stands to now: a fallen funnel's, its
## foot; any other's, [param top].
func top_of(blocker: int, top: float) -> float:
	for fall: FunnelFall in _down:
		if _blockers[_funnels.find(fall.fitting)] == blocker:
			return fall.fitting.base.y
	return top


## What the funnels lying down hold back a circle of [param radius] at [param point]
## (x/z) with its feet able to step to [param reach_up] and its head at [param head]:
## per one it reaches, out of its strip by the least way.
func contacts(
	point: Vector2, reach_up: float, head: float, radius: float
) -> Array[Surfaces.Contact]:
	var found: Array[Surfaces.Contact] = []
	for fall: FunnelFall in _down:
		var fitting := fall.fitting
		if reach_up >= fitting.base.y + fitting.radius * 2.0 or head <= fitting.base.y:
			continue
		var local := _into(fall, point)
		var strip := Rect2(0.0, -fitting.radius, fitting.height, fitting.radius * 2.0)
		var contact := PlaneShapes.rect_contact(strip, local, radius)
		if contact != null:
			contact.normal = _out_of(fall, contact.normal)
			found.append(contact)
	return found


## Whether a funnel lying down stands across the line from [param start] to [param end]
## (x/z) anywhere between [param low] and [param high].
func crossed(start: Vector2, end: Vector2, low: float, high: float) -> bool:
	for fall: FunnelFall in _down:
		var fitting := fall.fitting
		if high <= fitting.base.y or low >= fitting.base.y + fitting.radius * 2.0:
			continue
		var strip := Rect2(0.0, -fitting.radius, fitting.height, fitting.radius * 2.0)
		if PlaneShapes.segment_meets_rect(_into(fall, start), _into(fall, end), strip):
			return true
	return false


## [param point] (x/z) in [param fall]'s strip's own axes: along it from its foot, and
## across it.
static func _into(fall: FunnelFall, point: Vector2) -> Vector2:
	var off := point - Vector2(fall.fitting.base.x, fall.fitting.base.z)
	return Vector2(off.dot(fall.along), off.x * fall.along.y - off.y * fall.along.x)


## A way [param local] in [param fall]'s strip's axes, back in the ship's x/z.
static func _out_of(fall: FunnelFall, local: Vector2) -> Vector2:
	var along := fall.along
	return along * local.x + Vector2(along.y, -along.x) * local.y
