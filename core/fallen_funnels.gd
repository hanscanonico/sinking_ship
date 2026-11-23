class_name FallenFunnels
extends RefCounted
## Her funnels as Surfaces meets them once they have come down (SH31, FunnelFall): the
## upright blocker each stood as holds nothing over where it broke off any more, and the
## funnel lying along the strip it fell across holds a body back as a wall does — from where
## it broke off to its girth over that — and stops and hides a shove's line there. It lies
## as her layout has it come to rest (FunnelRest): flat along its whole strip with nothing
## in its way; propped on a deckhouse it fell onto, only as far along as its underside is
## still under what is asked about — a body's head, a line's top — so it holds nobody in
## the room under it, between itself and the room's walls (#790). As far down as the pose
## says (ShipPose.felled); the strip's way is the schedule's. Ship-local metres (D6).

## How far, in metres, a funnel's foot may sit under the bottom of the blocker it stands
## on, and must sit under its top: its foot is single precision, the blocker's heights
## double — the trawler's stack stands at 2.3 m, its foot at 2.2999999523 (#142) — and a
## foot that close to a blocker's top stands on it, not in it.
const FOOT_SLACK := 0.001

## Per funnel of the layout's structure, the layout's blocker it stands on, -1 for none;
## and the falls the pose last honoured has landed. Per fall landed: its foot, as high as
## it broke off (FunnelRest.breaks_at); and how far along it lies for each metre over
## that — INF lying flat, less propped (FunnelRest.resting).
var _layout: ShipLayout
var _funnels: Array[ShipFitting] = []
var _blockers := PackedInt32Array()
var _down: Array[FunnelFall] = []
var _feet := PackedVector3Array()
var _runs := PackedFloat64Array()


func _init(layout: ShipLayout) -> void:
	_layout = layout
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
## blocker's round and its height, FOOT_SLACK lower at both ends.
static func stands_on(fitting: ShipFitting, blocker: ShipBlocker) -> bool:
	if blocker.shape != ShipBlocker.Shape.CYLINDER:
		return false
	var foot := Vector2(fitting.base.x, fitting.base.z)
	var round := foot.distance_to(blocker.centre) <= blocker.radius
	var from := blocker.bottom - FOOT_SLACK
	var to := blocker.top - FOOT_SLACK
	return round and fitting.base.y >= from and fitting.base.y < to


## Takes the falls [param pose] has landed of its funnels — a piece of her has its own
## (Pieces, SH33) —; whether they differ from those it had.
func honour(pose: ShipPose) -> bool:
	var down: Array[FunnelFall] = []
	for fall: FunnelFall in pose.felled:
		if fall.fitting in _funnels:
			down.append(fall)
	if down == _down:
		return false
	_down = down
	_feet.clear()
	_runs.clear()
	for fall: FunnelFall in _down:
		var base := fall.fitting.base
		var foot := FunnelRest.breaks_at(_layout, fall.fitting)
		var rest := FunnelRest.resting(_layout, fall, foot)
		_feet.append(Vector3(base.x, foot, base.z))
		_runs.append(INF if rest >= FunnelRest.DOWN_DEG else tan(deg_to_rad(rest)))
	return true


## Whether any of her funnels is down: none, and every blocker stands to its own top.
func any_down() -> bool:
	return not _down.is_empty()


## The top blocker [param blocker] of the layout stands to now: a fallen funnel's, where
## it broke off — its foot, or the roof it stood through, its casing standing on in the
## room under that —; any other's, [param top].
func top_of(blocker: int, top: float) -> float:
	for index in _down.size():
		if _blockers[_funnels.find(_down[index].fitting)] == blocker:
			return _feet[index].y
	return top


## The funnels lying down as the extension takes them (ContactsNative): each one's foot,
## as high as it broke off; its radius, its height and how far along it lies for each
## metre over its foot (_lies); and the way it fell.
func native_down() -> Array:
	var sizes := PackedFloat64Array()
	var along := PackedVector2Array()
	for index in _down.size():
		var fall := _down[index]
		sizes.append(fall.fitting.radius)
		sizes.append(fall.fitting.height)
		sizes.append(_runs[index])
		along.append(fall.along)
	return [_feet, sizes, along]


## How far along its strip, from its foot, fall [param index] landed lies under
## [param top], a height over its foot: all its height lying flat; propped, from its foot
## to where its underside — tipped up from its rim on the side it fell — stands that high.
func _lies(index: int, top: float) -> float:
	var fitting := _down[index].fitting
	return minf(fitting.height, fitting.radius + (top - _feet[index].y) * _runs[index])


## What the funnels lying down hold back a circle of [param radius] at [param point]
## (x/z) with its feet able to step to [param reach_up] and its head at [param head]:
## per one it reaches — as far along as it lies under that head (_lies) —, out of its
## strip by the least way.
func contacts(
	point: Vector2, reach_up: float, head: float, radius: float
) -> Array[Surfaces.Contact]:
	var found: Array[Surfaces.Contact] = []
	for index in _down.size():
		var fall := _down[index]
		var fitting := fall.fitting
		var foot := _feet[index].y
		if reach_up >= foot + fitting.radius * 2.0 or head <= foot:
			continue
		var local := _into(fall, point)
		var strip := Rect2(0.0, -fitting.radius, _lies(index, head), fitting.radius * 2.0)
		var contact := PlaneShapes.rect_contact(strip, local, radius)
		if contact != null:
			contact.normal = _out_of(fall, contact.normal)
			found.append(contact)
	return found


## Whether a funnel lying down stands across the line from [param start] to [param end]
## (x/z) anywhere between [param low] and [param high], as far along as it lies under
## [param high] (_lies).
func crossed(start: Vector2, end: Vector2, low: float, high: float) -> bool:
	for index in _down.size():
		var fall := _down[index]
		var fitting := fall.fitting
		var foot := _feet[index].y
		if high <= foot or low >= foot + fitting.radius * 2.0:
			continue
		var strip := Rect2(0.0, -fitting.radius, _lies(index, high), fitting.radius * 2.0)
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
