class_name ShipPose
extends RefCounted
## Where the ship stands in the world at one tick, as SinkSchedule answers it. The
## sea is the world plane y = 0; [member transform] takes a ship-local point to the
## world, so a point is wet when its world height is below zero.

var sink: float
var trim_deg: float
var heel_deg: float
var transform: Transform3D
## What the scenario's events have done by this tick, and what they telegraph now —
## derived from (scenario, seed, tick) like the rest of the pose, never stored (D5).
## The platforms, by name, that have collapsed: no longer surfaces.
var collapsed: Array[StringName] = []
## The platforms, by name, whose collapse is telegraphed now: standing, not for long.
var collapsing: Array[StringName] = []
## The layout's railings, by index, that have failed.
var broken_railings := PackedInt32Array()
## The heel the lurch telegraphed now will swing by, signed as heel_deg; 0 for none.
var lurch_warning: float
## The heel the lurch under way swings by at its height, signed; 0 for none. Its
## part of the swing is already in heel_deg.
var lurch: float


func _init(
	pose_sink: float, pose_trim_deg: float, pose_heel_deg: float, ship_to_world: Transform3D
) -> void:
	sink = pose_sink
	trim_deg = pose_trim_deg
	heel_deg = pose_heel_deg
	transform = ship_to_world


func world_height(ship_point: Vector3) -> float:
	return (transform * ship_point).y


## The ship-local height the sea stands at over the ship-plane point
## ([param x], [param z]): a point there is wet below it.
func sea_height(x: float, z: float) -> float:
	var basis := transform.basis
	return -(basis.x.y * x + basis.z.y * z + transform.origin.y) / basis.y.y


## The world's downward pull of [param strength], in ship space: its x/z part is
## the deck's downhill, whichever way the ship leans.
func ship_gravity(strength: float) -> Vector3:
	return transform.basis.inverse() * Vector3(0.0, -strength, 0.0)


## The way, in the ship plane, a heel of [param heel] puts the deck down: toward
## starboard (+z) for a positive one.
static func low_side(heel: float) -> Vector2:
	return Vector2(0.0, signf(heel))


## The deck's combined slope, trim and heel together, in degrees.
func slope_deg() -> float:
	return rad_to_deg(Vector3.UP.angle_to(transform.basis * Vector3.UP))
