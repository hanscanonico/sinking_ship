class_name FunnelArt
extends RefCounted
## A funnel the sinking can fell (SH31), as ShipArt draws it: its casing below its foot —
## through the deckhouse — part of the ship, and its standing part over its foot on a
## piece of its own, which turns about its foot as the schedule has it fall
## (FunnelFall): from the creak a lean toward the way it will go, shuddering, then the
## fall itself, toppling faster as it goes, until it rests on what it landed on — tipped
## over the rim of its foot on the side it falls, so it never sinks into the deck, and
## stopped where it first meets a roof, a wall's top or a deck in its way (resting).
## Presentation only (D12): the fall's ticks, its way and the strip it lands across are
## the schedule's; what it knocks down and breaks, the rules'.

## How far it leans as it creaks, in degrees, and how hard and how often it shudders
## there; how far over it lies once down with nothing in its way: flat on its deck.
const LEAN_DEG := 3.0
const SHUDDER_DEG := 0.5
const SHUDDER_HZ := 5.0
const DOWN_DEG := 90.0
## How far apart, in metres, its path is sampled for what it lands on, and how far over
## a top must stand above its foot to hold it.
const REST_SAMPLE := 0.1
const REST_CLEAR := 0.02
## The seconds its lean takes to come on as it starts to creak.
const LEANING := 1.0


## The FUNNEL fitting of [param layout]'s structure standing on [param blocker] — its
## foot within the blocker's round and its height — or null for none.
static func fitting_of(layout: ShipLayout, blocker: ShipBlocker) -> ShipFitting:
	if layout.structure == null:
		return null
	for fitting: ShipFitting in layout.structure.fittings:
		if fitting.kind == ShipFitting.Kind.FUNNEL and FallenFunnels.stands_on(fitting, blocker):
			return fitting
	return null


## Draws [param blocker], a funnel to [param top] that [param fitting] stands on: its
## casing from the blocker's bottom to where it breaks off, [param foot] high
## (breaks_at), into [param mesh], and the funnel over that, with its smoke, into
## [param piece] (DeckWorks.funnel) under [param art]. The smoke's emitter.
static func split(
	mesh: ShipMesh, piece: ShipMesh, blocker: ShipBlocker, foot: float, top: float, art: ShipArt
) -> CPUParticles3D:
	if foot > blocker.bottom:
		var segments := DeckWorks.FUNNEL_SEGMENTS
		mesh.cylinder(
			blocker.centre, blocker.radius, blocker.bottom, foot, segments, ShipPaints.funnel
		)
	var standing: ShipBlocker = blocker.duplicate()
	standing.bottom = foot
	return DeckWorks.funnel(piece, standing, top, art)


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


## Where [param fall]'s funnel stands at [param tick], fractional, broken off
## [param foot] high (breaks_at): turned about the rim there on the side it falls —
## leaning and shuddering from its creak, then falling, faster as it goes, until it lies
## [param rest] degrees over (resting).
static func turned(fall: FunnelFall, tick: float, rest := DOWN_DEG, foot := NAN) -> Transform3D:
	var seconds := (tick - fall.warned_at) * Ticks.SECONDS_PER_TICK
	var degrees := 0.0
	if tick >= fall.warned_at:
		var lean := minf(seconds / LEANING, 1.0)
		degrees = LEAN_DEG * lean + SHUDDER_DEG * lean * sin(TAU * SHUDDER_HZ * seconds)
	var fallen := fall.fallen(tick)
	if fallen > 0.0:
		degrees = lerpf(LEAN_DEG, maxf(rest, LEAN_DEG), fallen * fallen)
	var axis := Vector3(fall.along.y, 0.0, -fall.along.x).normalized()
	var turn := Basis(axis, deg_to_rad(degrees))
	var rim := _rim(fall, fall.fitting.base.y if is_nan(foot) else foot)
	return Transform3D(turn, rim - turn * rim)


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
	var rim := _rim(fall, foot)
	var from := Vector2(rim.x, rim.z)
	var tip_at := from + fall.along * length
	var path := Rect2(from, Vector2.ZERO).expand(tip_at).grow(fitting.radius)
	var found := _over(layout, fitting, foot, path)
	var best := deg_to_rad(DOWN_DEG)
	var count := ceili(length / REST_SAMPLE)
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
				if high <= REST_CLEAR or low > tip:
					continue
				var angle := meets if high >= tip else atan2(reach, high)
				best = minf(best, angle)
	return rad_to_deg(best)


## Where [param fall]'s funnel stands at [param tick] on [param layout] (turned): where
## it breaks off and how far over it comes to rest kept in [param rests] by its
## fitting's name while its way stays the same (breaks_at, resting).
static func turned_on(
	rests: Dictionary, layout: ShipLayout, fall: FunnelFall, tick: float
) -> Transform3D:
	var kept: Array = rests.get(fall.fitting.name, [])
	if kept.is_empty() or kept[0] != fall.along:
		var foot := breaks_at(layout, fall.fitting)
		kept = [fall.along, resting(layout, fall, foot), foot]
		rests[fall.fitting.name] = kept
	return turned(fall, tick, kept[1], kept[2])


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


## The point it tips over of [param fall]'s funnel broken off [param foot] high: its rim
## there on the side it falls.
static func _rim(fall: FunnelFall, foot: float) -> Vector3:
	var fitting := fall.fitting
	var along := Vector2(fitting.base.x, fitting.base.z) + fall.along * fitting.radius
	return Vector3(along.x, foot, along.y)


## Whether [param fall]'s funnel lies far enough over at [param tick] that its smoke has
## stopped.
static func down(fall: FunnelFall, tick: float) -> bool:
	return fall.fallen(tick) >= 0.5
