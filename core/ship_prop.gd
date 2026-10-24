class_name ShipProp
extends Resource
## A prop of hers where the match starts it (D6, SH10, #273) — a crate of cargo unless
## its kind says otherwise: an upright circle in the deck plane, as a body is, with a
## height, a mass and its own grip on the deck. Where it is after that is the match's
## state (PropState), never this.

## Its kind (PropKind), by the name of its file under data/props/.
@export var kind: StringName = &"cargo"
## The railing span it hangs on at the start, by its index in ShipLayout.railings — a
## lifebuoy's station; -1 for one that starts on the deck. Hung, its pos is the point of
## the span it hangs from, at its deck's height.
@export var railing: int = -1

## Where its underside stands at the start, ship-local.
@export var pos: Vector3
## The way its front faces, in degrees from her +x toward her +z as a body's facing
## turns: a chair's toward its table. It slides, gives way and floats without turning.
@export var facing_deg: float
@export var radius: float
## How high its lid stands above its underside: a body jumps onto it, as onto a hatch.
@export var height: float
## In kilograms, weighed against BrawlRules.body_mass: a shove sends it slower than
## a body, and it shares its speed with a body it runs into by the two masses.
@export var mass: float
## The combined deck slope it holds at; past it, the deck pulls it downhill.
@export var grip_angle_deg: float
## How fast the deck slows it while it slides, in m/s².
@export var friction: float


## Its kind; null when there is no such kind.
func prop_kind() -> PropKind:
	return PropKind.named(kind)


## Every reason this prop cannot be loaded; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	var own := prop_kind()
	if own == null:
		found.append("ship: a prop's kind %s is not under %s" % [kind, PropKind.DIRECTORY])
	elif (
		own.radius > 0.0
		and not (is_equal_approx(radius, own.radius) and is_equal_approx(height, own.height))
	):
		found.append("ship: a %s prop must be its kind's size" % kind)
	elif railing != -1 and not own.holdable:
		found.append("ship: only a prop that can be held hangs on a railing")
	if radius <= 0.0 or height <= 0.0 or mass <= 0.0:
		found.append("ship: a prop must have a radius, a height and a mass")
	if grip_angle_deg <= 0.0 or grip_angle_deg >= 90.0:
		found.append("ship: a prop's grip_angle_deg must be within 0…90")
	if friction < 0.0:
		found.append("ship: a prop's friction must not be negative")
	return found
