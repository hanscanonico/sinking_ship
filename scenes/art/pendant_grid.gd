class_name PendantGrid
extends RefCounted
## The pendants a plain room is lit by (RoomDressing.lights): one under the middle of
## each RoomDressing.LAMP_SPACING square its floor is cut into, each reaching as far as
## the far corner of its own square. A pendant's own reach (ShipLamp.RANGE) lights a
## cabin; under it alone a saloon or a car deck stood near black between its lamps.

## The furthest a pendant is asked to reach, in metres.
const REACH_MOST := 9.5


## How many squares [param area] is cut into, along x and along z.
static func across(area: Rect2) -> Vector2i:
	var spacing := RoomDressing.LAMP_SPACING
	return Vector2i(maxi(1, ceili(area.size.x / spacing)), maxi(1, ceili(area.size.y / spacing)))


## How far a pendant hung [param drop] metres over the floor must reach to light the
## far corner of its square of [param area]: never under a lamp's own reach.
static func reach(area: Rect2, drop: float) -> float:
	var half := area.size / Vector2(across(area)) * 0.5
	return clampf(Vector3(half.x, drop, half.y).length(), ShipLamp.RANGE, REACH_MOST)


## The pendants of [param room], under its ceiling.
static func lights(space: ShipSpace, room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	var area := room.area
	var squares := across(area)
	for i in squares.x:
		for j in squares.y:
			var share := Vector2((i + 0.5) / squares.x, (j + 0.5) / squares.y)
			var at := RoomDressing.under_ceiling(space, room, area.position + area.size * share)
			var light := RoomDressing.Light.new(at, ShipLamp.Kind.PENDANT)
			light.reach = reach(area, at.y - room.floor_height)
			found.append(light)
	return found
