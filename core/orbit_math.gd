class_name OrbitMath
extends RefCounted
## The orbit camera's sums (R5, #213), pure: where an eye orbiting a pivot stands,
## held over the sea and outside her hull's box; how a pan and a lock move the pivot;
## and how far off the whole ship is framed from. Angles in radians, the world's y up,
## the sea the plane y = 0 (D7). Nothing here is sent or read by a rule.

## The share of her length the eye stands off a long hull to frame it whole, and the
## length past which a hull is long, in multiples of the near distance — as the
## observer camera frames her (ObserverCamera).
const LONG_HULL := 3.0
const LONG_HULL_DISTANCE := 0.8


## The eye [param distance] from [param pivot], turned [param yaw] about the world's up
## — 0 standing on the pivot's +z side, looking along -z — and raised [param pitch]
## above the level.
static func eye_of(pivot: Vector3, yaw: float, pitch: float, distance: float) -> Vector3:
	var level := cos(pitch) * distance
	return pivot + Vector3(sin(yaw) * level, sin(pitch) * distance, cos(yaw) * level)


## [param pivot] moved [param by] — right and back positive, in metres — in the frame
## an eye turned [param yaw] sees, on its own level, held inside [param bounds] (x/z).
static func pan(pivot: Vector3, yaw: float, by: Vector2, bounds: Rect2) -> Vector3:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var moved := pivot + right * by.x + back * by.y
	return Vector3(
		clampf(moved.x, bounds.position.x, bounds.end.x),
		pivot.y,
		clampf(moved.z, bounds.position.y, bounds.end.y)
	)


## [param eye] no lower than [param clearance] over the sea.
static func over_sea(eye: Vector3, clearance: float) -> Vector3:
	return Vector3(eye.x, maxf(eye.y, clearance), eye.z)


## [param eye] kept out of [param box]: itself when outside; else moved along the line
## from [param pivot] through it to where that line leaves the box — or, the pivot
## outside the box, to where the line enters it, so the box never stands between.
static func out_of(eye: Vector3, pivot: Vector3, box: AABB) -> Vector3:
	if not box.has_point(eye):
		return eye
	var way := eye - pivot
	if way.is_zero_approx():
		return eye
	var enters := -INF
	var leaves := INF
	for axis in 3:
		if is_zero_approx(way[axis]):
			continue
		var near := (box.position[axis] - pivot[axis]) / way[axis]
		var far := (box.end[axis] - pivot[axis]) / way[axis]
		enters = maxf(enters, minf(near, far))
		leaves = minf(leaves, maxf(near, far))
	var at := leaves if box.has_point(pivot) else enters
	return pivot + way * at


## [param pivot] drawn toward [param target] at [param rate] per second over
## [param delta] seconds: the lock's follow.
static func follow(pivot: Vector3, target: Vector3, rate: float, delta: float) -> Vector3:
	return pivot.lerp(target, clampf(rate * delta, 0.0, 1.0))


## How far off the eye stands to frame the whole of a hull of [param deck] (the decks'
## bounds in the ship plane): [param near] for a short one, a share of her length for
## a long one, as the observer camera frames her.
static func whole_ship_distance(deck: Rect2, near: float) -> float:
	return deck.size.x * LONG_HULL_DISTANCE if deck.size.x > near * LONG_HULL else near
