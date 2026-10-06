class_name FunnelArt
extends RefCounted
## A funnel the sinking can fell (SH31), as ShipArt draws it: its casing below its foot —
## through the deckhouse — part of the ship, and its standing part over its foot on a
## piece of its own, which turns about its foot as the schedule has it fall
## (FunnelFall): from the creak a lean toward the way it will go, shuddering, then the
## fall itself, toppling faster as it goes, until it lies across what it landed on.
## Presentation only (D12): the fall's ticks, its way and the strip it lands across are
## the schedule's; what it knocks down and breaks, the rules'.

## How far it leans as it creaks, in degrees, and how hard and how often it shudders
## there; how far over it lies once down.
const LEAN_DEG := 3.0
const SHUDDER_DEG := 0.5
const SHUDDER_HZ := 5.0
const DOWN_DEG := 84.0
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
## casing from the blocker's bottom to the fitting's foot into [param mesh], and the
## funnel over its foot, with its smoke, into [param piece] (DeckWorks.funnel) under
## [param art]. The smoke's emitter.
static func split(
	mesh: ShipMesh,
	piece: ShipMesh,
	blocker: ShipBlocker,
	fitting: ShipFitting,
	top: float,
	art: ShipArt
) -> CPUParticles3D:
	var foot := fitting.base.y
	if foot > blocker.bottom:
		var segments := DeckWorks.FUNNEL_SEGMENTS
		mesh.cylinder(
			blocker.centre, blocker.radius, blocker.bottom, foot, segments, ShipPaints.funnel
		)
	var standing: ShipBlocker = blocker.duplicate()
	standing.bottom = foot
	return DeckWorks.funnel(piece, standing, top, art)


## Where [param fall]'s funnel stands at [param tick], fractional: turned about its foot
## toward the way it falls — leaning and shuddering from its creak, then falling, faster
## as it goes, until it lies DOWN_DEG over.
static func turned(fall: FunnelFall, tick: float) -> Transform3D:
	var seconds := (tick - fall.warned_at) * Ticks.SECONDS_PER_TICK
	var degrees := 0.0
	if tick >= fall.warned_at:
		var lean := minf(seconds / LEANING, 1.0)
		degrees = LEAN_DEG * lean + SHUDDER_DEG * lean * sin(TAU * SHUDDER_HZ * seconds)
	var fallen := fall.fallen(tick)
	if fallen > 0.0:
		degrees = lerpf(LEAN_DEG, DOWN_DEG, fallen * fallen)
	var axis := Vector3(fall.along.y, 0.0, -fall.along.x).normalized()
	var turn := Basis(axis, deg_to_rad(degrees))
	var foot := fall.fitting.base
	return Transform3D(turn, foot - turn * foot)


## Whether [param fall]'s funnel lies far enough over at [param tick] that its smoke has
## stopped.
static func down(fall: FunnelFall, tick: float) -> bool:
	return fall.fallen(tick) >= 0.5
