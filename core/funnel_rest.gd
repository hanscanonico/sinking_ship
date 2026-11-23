class_name FunnelRest
extends RefCounted
## How a funnel the sinking fells (SH31, FunnelFall) comes to rest on her, as her layout
## lays out what is in its way (D6): where it breaks off — its foot, or where it rises out
## of a roof it stands through — and how far over it goes, tipped over its rim there on
## the side it falls until its underside meets a wall's top, a roof or a deck. One answer
## for the two that ask: FallenFunnels, for what the funnel lying there holds back, and
## FunnelArt, which draws it — a funnel propped on a deckhouse holds nobody inside the
## deckhouse under it (#790). Ship-local metres.

## How far over, in degrees, it lies with nothing in its way: flat on its deck.
const DOWN_DEG := 90.0
## How far apart, in metres, its path is sampled for what it lands on, and how far over
## a top must stand above its foot to hold it.
const SAMPLE := 0.1
const CLEAR := 0.02


## How high [param fitting]'s funnel breaks off as it falls on [param layout]: at its
## foot, or where it rises out of a roof or a deck it stands through — a deck over its
## foot that holds it as it goes over, never one it falls into.
static func breaks_at(layout: ShipLayout, fitting: ShipFitting) -> float:
	var foot := fitting.base.y
	var top := foot + fitting.height
	var at := Vector2(fitting.base.x, fitting.base.z)
	var pierced := foot
	var found := _over(layout, fitting, foot, Rect2(at, Vector2.ZERO))
	for span: Vector2 in _spans_at(found, at):
		if span.y < top:
			pierced = maxf(pierced, span.y)
	return pierced


## How far over, in degrees, [param fall]'s funnel comes to rest on [param layout],
## broken off [param foot] high (breaks_at): tipped over the rim there, where its
## underside first meets the top of a blocker — a deckhouse's wall or roof — or a deck
## standing over its foot in its path, as the layout lays them out (D6); DOWN_DEG, flat on
## what it broke off from, when nothing is in its way. Its path is its width wide, as long
## as it stands over its break.
static func resting(layout: ShipLayout, fall: FunnelFall, foot: float) -> float:
	var fitting := fall.fitting
	var length := fitting.base.y + fitting.height - foot
	var across := Vector2(fall.along.y, -fall.along.x)
	var tips := rim(fall, foot)
	var from := Vector2(tips.x, tips.z)
	var tip_at := from + fall.along * length
	var path := Rect2(from, Vector2.ZERO).expand(tip_at).grow(fitting.radius)
	var found := _over(layout, fitting, foot, path)
	var best := deg_to_rad(DOWN_DEG)
	var count := ceili(length / SAMPLE)
	for at in range(1, count):
		var reach := length * at / count
		# How high the tip stands as it first reaches this far: anything wholly over
		# that it passes under.
		var tip := sqrt(length * length - reach * reach)
		var meets := asin(reach / length)
		if meets >= best:
			break
		for side: float in [-1.0, 0.0, 1.0]:
			var point := from + fall.along * reach + across * (fitting.radius * side)
			for span: Vector2 in _spans_at(found, point):
				var low := span.x - foot
				var high := span.y - foot
				if high <= CLEAR or low > tip:
					continue
				var angle := meets if high >= tip else atan2(reach, high)
				best = minf(best, angle)
	return rad_to_deg(best)


## The point it tips over of [param fall]'s funnel broken off [param foot] high: its rim
## there on the side it falls.
static func rim(fall: FunnelFall, foot: float) -> Vector3:
	var fitting := fall.fitting
	var along := Vector2(fitting.base.x, fitting.base.z) + fall.along * fitting.radius
	return Vector3(along.x, foot, along.y)


## The blockers and decks of [param layout] standing over [param foot] anywhere in
## [param area] (x/z) — never the blocker [param fitting] stands on.
static func _over(
	layout: ShipLayout, fitting: ShipFitting, foot: float, area: Rect2
) -> Array[Resource]:
	var found: Array[Resource] = []
	for blocker: ShipBlocker in layout.blockers:
		if blocker.top <= foot or FallenFunnels.stands_on(fitting, blocker):
			continue
		var round := Vector2(blocker.radius, blocker.radius)
		var bounds := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			bounds = Rect2(blocker.centre - round, round * 2.0)
		if _meets(bounds, area):
			found.append(blocker)
	for platform: ShipPlatform in layout.platforms:
		if platform.height > foot and _meets(platform.area, area):
			found.append(platform)
	return found


## The bottom and top heights of each of [param found] (_over) standing at
## [param point] (x/z): a blocker's, from its bottom to its top; a deck's, its height.
static func _spans_at(found: Array[Resource], point: Vector2) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for thing: Resource in found:
		var platform := thing as ShipPlatform
		if platform != null:
			if platform.contains(point.x, point.y):
				spans.append(Vector2(platform.height, platform.height))
			continue
		var blocker := thing as ShipBlocker
		var inside := false
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			inside = point.distance_to(blocker.centre) <= blocker.radius
		else:
			inside = _covers(blocker.area, point)
		if inside:
			spans.append(Vector2(blocker.bottom, blocker.top))
	return spans


## Whether [param a] and [param b] overlap or touch.
static func _meets(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x <= b.end.x
		and b.position.x <= a.end.x
		and a.position.y <= b.end.y
		and b.position.y <= a.end.y
	)


## Whether [param area] holds [param point], its edges with it.
static func _covers(area: Rect2, point: Vector2) -> bool:
	return (
		point.x >= area.position.x
		and point.x <= area.end.x
		and point.y >= area.position.y
		and point.y <= area.end.y
	)
