class_name EyeHold
extends RefCounted
## Where a seat's eye may stand (D14). It stands over the feet along the world's up, so
## on a ship that lists it leans off the body's own upright toward her high side — half
## a metre at 17°, more than the body's radius — and the eye of a body against a wall
## there would stand in the wall or past it, seeing through it. The eye is held short of
## whatever hides one eye from another (Surfaces.line_of_sight): a wall, a shut door, the
## hull, a fallen funnel.

## How far short of what holds it the eye stands: the camera's near plane, out to its
## corners at the widest field of view, with room to spare.
const CLEARANCE := 0.15
## The halvings that find how far the eye may lean: to under a centimetre of a 1 m lean.
const STEPS := 7


## Where the eye of the body with its feet at [param feet] stands, wanting to stand at
## [param eye] — both in the frame of [param here], under [param pose]: [param eye]
## itself while nothing stands within CLEARANCE of it along its lean from the body's
## upright, else back along that lean, CLEARANCE short of what does — on the upright
## itself at the nearest.
static func held(here: Surfaces, pose: ShipPose, feet: Vector3, eye: Vector3) -> Vector3:
	var upright := Vector3(feet.x, eye.y, feet.z)
	var lean := upright.distance_to(eye)
	if is_zero_approx(lean):
		return eye
	var way := (eye - upright) / lean
	var blocked := lean + CLEARANCE
	if here.line_of_sight(upright, upright + way * blocked, pose):
		return eye
	var clear := 0.0
	for step in STEPS:
		var middle := (clear + blocked) * 0.5
		if here.line_of_sight(upright, upright + way * middle, pose):
			clear = middle
		else:
			blocked = middle
	return upright + way * maxf(clear - CLEARANCE, 0.0)
