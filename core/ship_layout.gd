class_name ShipLayout
extends Resource
## The ship as data, in ship-local metres (D6): x toward the bow, z to starboard,
## y up, origin on the main deck amidships. Collision never comes from a mesh; the
## greybox is generated from this.

## Height of the main deck above the sea when the ship is level and unsunk.
@export var freeboard: float
@export var platforms: Array[ShipPlatform] = []
## Where seats start, ship-local; the match stream shuffles who gets which.
@export var spawns: Array[Vector3] = []


## Every reason this layout cannot host [param seats] seats; empty when it can.
func problems(seats: int) -> PackedStringArray:
	var found := PackedStringArray()
	if freeboard <= 0.0:
		found.append("ship: freeboard must be positive")
	if platforms.is_empty():
		found.append("ship: no platforms")
	for platform: ShipPlatform in platforms:
		if platform == null or platform.area.size.x <= 0.0 or platform.area.size.y <= 0.0:
			found.append("ship: a platform has no area")
	if spawns.size() < seats:
		found.append("ship: %d spawns for %d seats" % [spawns.size(), seats])
	return found
