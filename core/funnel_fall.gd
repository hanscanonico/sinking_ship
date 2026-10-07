class_name FunnelFall
extends RefCounted
## One funnel's fall as a match plays it (§5b.1, SH31): the physics lets it go
## (SinkTimeline's FUNNEL_FALLING) and the schedule places it on the match's ticks — its
## creak from when it is warned, its fall from when its stays let it go, until it lands
## a fall's time later along [member along], the world's down as it stood in her deck's
## plane. It lands across a strip: from its foot along that way as long as it stands
## tall, as wide as it is. What the strip lands on — a roof too light to take it, the
## railings it crosses — is Surfaces' to say (lands_on, crosses, D13); a body in it on its
## landing tick is knocked down, a rule (Hazards, D12). Match data like the timeline it
## is read from, never in a snapshot (D5). Ship-local metres (D6).

## How far apart, in metres, the strip is sampled along it as Surfaces is asked what
## lies under it: under the narrowest railing's reach.
const SAMPLE := 0.1

var fitting: ShipFitting
## The way it falls, in her deck's plane, x then z: a unit.
var along: Vector2
## The ticks its creak begins, its fall begins and it lands.
var warned_at: int
var falls_at: int
var lands_at: int


func _init(
	funnel: ShipFitting, toward: Vector2, warned_tick: int, falls_tick: int, lands_tick: int
) -> void:
	fitting = funnel
	along = toward
	warned_at = warned_tick
	falls_at = falls_tick
	lands_at = lands_tick


## How far it has fallen at [param tick] — fractional, as a view reads between ticks —
## 0 standing, 1 landed.
func fallen(tick: float) -> float:
	if tick <= falls_at:
		return 0.0
	if lands_at <= falls_at:
		return 1.0
	return clampf((tick - falls_at) / (lands_at - falls_at), 0.0, 1.0)


## Whether a body of [param radius], its feet at [param feet], stands in the strip it
## lands across: its circle over the strip, its feet within the funnel's reach under its
## foot — from the deck it stands on down to as far below as it stands tall.
func covers(feet: Vector3, radius: float) -> bool:
	var base := fitting.base
	if feet.y > base.y + fitting.radius or feet.y < base.y - fitting.height:
		return false
	var off := Vector2(feet.x - base.x, feet.z - base.z)
	var reach := off.dot(along)
	var aside := absf(off.x * along.y - off.y * along.x)
	return (
		reach >= -radius and reach <= fitting.height + radius and aside <= fitting.radius + radius
	)


## The platforms of [param layout] it crushes as it lands, each once: those of the
## fitting's crushes that are, as [param surfaces] answers, the highest surface under
## its strip somewhere along it, from as high as its top stands.
func lands_on(layout: ShipLayout, surfaces: Surfaces) -> Array[StringName]:
	var crushed: Array[StringName] = []
	if fitting.crushes.is_empty():
		return crushed
	var base := fitting.base
	var top := base.y + fitting.height
	var count := ceili(fitting.height / SAMPLE)
	for at in range(1, count + 1):
		var point := Vector2(base.x, base.z) + along * (fitting.height * at / count)
		var under := surfaces.landing(Vector3(point.x, top, point.y))
		if under == Surfaces.NONE or under >= layout.platforms.size():
			continue
		var platform_name := layout.platforms[under].name
		if platform_name in fitting.crushes and not platform_name in crushed:
			crushed.append(platform_name)
	return crushed


## The railings it breaks as it lands, in ascending order: each whose span, standing
## [param railing_height] on its deck within the funnel's reach under its foot, the strip
## crosses coming from its foot, as [param surfaces] meets a falling body's circle.
func crosses(surfaces: Surfaces, railing_height: float) -> PackedInt32Array:
	var broken := PackedInt32Array()
	var base := fitting.base
	var low := Vector3(base.x, base.y - fitting.height, base.z)
	var came_from := Vector2(base.x, base.z)
	var count := ceili(fitting.height / SAMPLE)
	for at in range(1, count + 1):
		var point := came_from + along * (fitting.height * at / count)
		var contacts := surfaces.airborne_rail_contacts(
			Vector3(point.x, low.y, point.y),
			came_from,
			fitting.radius,
			fitting.height + fitting.radius,
			railing_height
		)
		for contact: Surfaces.Contact in contacts:
			if contact.railing != -1 and not contact.railing in broken:
				broken.append(contact.railing)
	broken.sort()
	return broken
