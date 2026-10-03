class_name ShipProp
extends Resource
## A loose crate of cargo where the match starts it (D6, SH10): an upright circle
## in the deck plane, as a body is, with a height, a mass and its own grip on the
## deck. Where it is after that is the match's state (PropState), never this.

## Where its underside stands at the start, ship-local.
@export var pos: Vector3
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


## Every reason this crate cannot be loaded; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if radius <= 0.0 or height <= 0.0 or mass <= 0.0:
		found.append("ship: a prop must have a radius, a height and a mass")
	if grip_angle_deg <= 0.0 or grip_angle_deg >= 90.0:
		found.append("ship: a prop's grip_angle_deg must be within 0…90")
	if friction < 0.0:
		found.append("ship: a prop's friction must not be negative")
	return found
