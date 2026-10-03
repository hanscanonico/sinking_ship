class_name ShipPose
extends RefCounted
## Where the ship stands in the world at one tick, as SinkSchedule answers it. The
## sea is the world plane y = 0; [member transform] takes a ship-local point to the
## world, so a point is wet when its world height is below zero.

var sink: float
var trim_deg: float
var heel_deg: float
var transform: Transform3D


func _init(
	pose_sink: float, pose_trim_deg: float, pose_heel_deg: float, ship_to_world: Transform3D
) -> void:
	sink = pose_sink
	trim_deg = pose_trim_deg
	heel_deg = pose_heel_deg
	transform = ship_to_world


func world_height(ship_point: Vector3) -> float:
	return (transform * ship_point).y
