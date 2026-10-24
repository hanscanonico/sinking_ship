class_name PropPlacing
extends RefCounted
## Where a prop is drawn (#273), from a snapshot's entry of it (D5), in ship space: its
## node's origin and turn. A crate of cargo stands at its underside, unturned. A piece of
## furniture (PropArt.FURNITURE) stands at its underside facing as its layout entry says
## (ShipProp.facing_deg), turning DRIFT_TURN a metre it has been pushed or carried from
## where it stood — one way or the other by its index —; afloat, the water lifting it, it
## bobs and rocks a little, more as it is lifted clear of its floor, never moved for it in
## the match. A ring — any prop of the lifebuoy's kind — is drawn about its middle, its
## face along the node's z and its back at the origin, as the lifebelt model is: lying flat
## where it lies loose; hung on its span's outboard face under the cap rail, facing the
## sea, as RailBuoys hangs one; held at its holder's chest, out ahead of it where it
## looks, facing that way — before the eyes of the seat holding it — or, its holder not
## among the snapshot's seats, where it rides at its feet.

## How high over its holder's feet a held ring's middle is carried, and how far ahead:
## at the chest, its top arc in the foot of the holder's own view.
const HELD_HEIGHT := 1.15
const HELD_AHEAD := 0.4
## How far a piece of furniture turns for every metre it stands from where it stood, in
## radians.
const DRIFT_TURN := 0.3
## Afloat, how far a piece of furniture bobs up and down at most and how long one bob
## takes, in seconds; how far it rocks at most, by kind; and how high over where it stood
## the water must lift it before it bobs and rocks in full.
const BOB := 0.03
const BOB_SECONDS := 3.4
const ROCK_DEG := {&"dining_table": 3.0, &"dining_chair": 9.0}
const LIFTED := 0.15


## Where [param entry] — a prop of [param layout] in a snapshot of tick [param tick]
## whose seats are [param seats], listed by id and maybe only some of them (SH22) — is
## drawn, its railings [param railing_height] tall.
static func of(
	entry: Dictionary, layout: ShipLayout, railing_height: float, seats: Array, tick := 0.0
) -> Transform3D:
	var prop := layout.props[entry["prop"]]
	var pos: Vector3 = entry["pos"]
	if PropArt.FURNITURE.has(prop.kind):
		return _furniture(entry, prop, tick)
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


## Where the piece of furniture [param prop] is drawn standing at [param pos], turned
## as far as it stands from where it stood.
static func placed_at(prop: ShipProp, pos: Vector3, index := 0) -> Transform3D:
	var moved := Vector2(pos.x - prop.pos.x, pos.z - prop.pos.z).length()
	var turn := moved * DRIFT_TURN * (1.0 if index % 2 == 0 else -1.0)
	var yaw := deg_to_rad(prop.facing_deg) + turn
	return Transform3D(RoomDressing.facing(Vector3(cos(yaw), 0.0, sin(yaw))), pos)


## Where the piece of furniture [param prop], as [param entry] has it at [param tick], is
## drawn: placed_at(), and afloat bobbing and rocking on the water.
static func _furniture(entry: Dictionary, prop: ShipProp, tick: float) -> Transform3D:
	var index: int = entry["prop"]
	var placed := placed_at(prop, entry["pos"], index)
	if entry["state"] != PropState.Body.FLOATING:
		return placed
	var lift := clampf((placed.origin.y - prop.pos.y) / LIFTED, 0.0, 1.0)
	var phase := tick * Ticks.SECONDS_PER_TICK / BOB_SECONDS * TAU + index * 2.39996
	placed.origin.y += BOB * lift * sin(phase)
	var rock := deg_to_rad(ROCK_DEG.get(prop.kind, 0.0)) * lift
	var axis := Vector3(cos(phase * 0.37), 0.0, sin(phase * 0.37))
	placed.basis = Basis(axis, rock * sin(phase * 0.83 + 1.0)) * placed.basis
	return placed
