class_name PropPlacing
extends RefCounted
## Where a prop is drawn (#273), from a snapshot's entry of it (D5), in ship space: its
## node's origin and turn. A crate of cargo stands at its underside, unturned. A ring —
## any prop of the lifebuoy's kind — is drawn about its middle, its face along the node's
## z and its back at the origin, as the lifebelt model is: lying flat where it lies loose;
## hung on its span's outboard face under the cap rail, facing the sea, as RailBuoys
## hangs one; held at its holder's chest, out ahead of it where it looks, facing that way
## — before the eyes of the seat holding it — or, its holder not among the snapshot's
## seats, where it rides at its feet.

## How high over its holder's feet a held ring's middle is carried, and how far ahead:
## at the chest, its top arc in the foot of the holder's own view.
const HELD_HEIGHT := 1.15
const HELD_AHEAD := 0.4


## Where [param entry] — a prop of [param layout] in a snapshot whose seats are
## [param seats], listed by id and maybe only some of them (SH22) — is drawn, its railings
## [param railing_height] tall.
static func of(
	entry: Dictionary, layout: ShipLayout, railing_height: float, seats: Array
) -> Transform3D:
	var prop := layout.props[entry["prop"]]
	var pos: Vector3 = entry["pos"]
	if prop.kind != &"lifebuoy":
		return Transform3D(Basis.IDENTITY, pos)
	match entry["state"] as PropState.Body:
		PropState.Body.HUNG:
			var out := layout.railing_outward(prop.railing)
			var normal := Vector3(out.x, 0.0, out.y)
			var drop := ShipArt.RAIL_DEPTH + RailBuoys.UNDER_CAP + prop.radius
			var middle := pos + Vector3.UP * (railing_height - drop) + normal * RailBuoys.OUT
			return Transform3D(RoomDressing.facing(normal), middle)
		PropState.Body.HELD:
			var holder := MatchState.entry_of(seats, entry["holder"])
			if holder.is_empty():
				return Transform3D(Basis.IDENTITY, pos + Vector3.UP * HELD_HEIGHT)
			var ahead := Vector2.from_angle(holder["facing"])
			var normal := Vector3(ahead.x, 0.0, ahead.y)
			var feet: Vector3 = holder["pos"]
			var middle := feet + Vector3.UP * HELD_HEIGHT + normal * HELD_AHEAD
			return Transform3D(RoomDressing.facing(normal), middle)
	return Transform3D(RoomDressing.facing(Vector3.UP), pos)
