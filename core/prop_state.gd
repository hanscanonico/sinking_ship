class_name PropState
extends RefCounted
## One prop of hers as the match has it (SH10, #273): a crate of cargo, a lifebuoy, …
## Every field is in the snapshot (D5): what the prop is — its kind, size, mass and
## grip — is the layout's ShipProp at the same index.

## LOST: gone into the sea, for the rest of the match. FLOATING: lifted off its floor
## by its cell's water, riding on it (Hazards). HUNG: on the railing span its layout
## entry names, until a Grab press takes it or the span goes. HELD: in its holder's
## hands. Appended, so the others keep their numbers in the snapshot. Hung or held, it
## is not in the world: no surface, no blocker, nothing a shove lands on, and it meets
## nothing.
enum Body { GROUNDED, AIRBORNE, LOST, FLOATING, HUNG, HELD }

## Its index in [member ShipLayout.props].
var prop: int
## Ship-local; y is its underside's height.
var pos: Vector3
var vel: Vector3
var body: Body = Body.GROUNDED
## What it stands on — afloat, the floor under it.
var surface: int = Surfaces.NONE
## The seat whose shove last sent it, or -1.
var shoved_by: int = -1
## The tick that shove landed on, or -1.
var shoved_at: int = -1
## The seat holding it, or -1: the one truth of who holds what — what a seat holds is
## asked of the props, never kept on the seat. Held, its pos rides at its holder's feet.
var holder: int = -1


func _init(index: int = 0) -> void:
	prop = index


func is_lost() -> bool:
	return body == Body.LOST


## Whether it is loose in the world — standing, falling or afloat — rather than hung,
## held or lost: what the cargo step moves and Surfaces may stand.
func is_loose() -> bool:
	return body == Body.GROUNDED or body == Body.AIRBORNE or body == Body.FLOATING


## Whether a Grab press may take a prop standing [param state]: lying on a deck, afloat at
## hand, or hung on its span (GrabReach) — never one in the air, held or lost.
static func within_grasp(state: Body) -> bool:
	return state == Body.GROUNDED or state == Body.FLOATING or state == Body.HUNG


## The prop [param seat] holds in [param snapshot] — a to_dict() of a match's — or -1.
static func held_in(snapshot: Dictionary, seat: int) -> int:
	for entry: Dictionary in snapshot["props"]:
		if entry["holder"] == seat:
			return entry["prop"]
	return -1


## Every prop of [param layout] where it starts: at rest on the deck, or hung on the
## railing its entry names.
static func from_layout(layout: ShipLayout) -> Array[PropState]:
	var props: Array[PropState] = []
	for index in layout.props.size():
		var crate := PropState.new(index)
		crate.pos = layout.props[index].pos
		if layout.props[index].railing != -1:
			crate.body = Body.HUNG
		props.append(crate)
	return props


## The crates [param snapshot] holds.
static func from_snapshot(snapshot: Dictionary) -> Array[PropState]:
	var props: Array[PropState] = []
	for entry: Dictionary in snapshot["props"]:
		props.append(from_dict(entry))
	return props


## What to_dict() carries, one row per key in its order (SnapshotField).
const FIELDS := [
	{"name": "prop", "kind": SnapshotField.Kind.INT},
	{"name": "body", "kind": SnapshotField.Kind.INT, "key": "state"},
	{"name": "pos", "kind": SnapshotField.Kind.LENGTHS},
	{"name": "vel", "kind": SnapshotField.Kind.SPEEDS},
	{"name": "surface", "kind": SnapshotField.Kind.INT},
	{"name": "shoved_by", "kind": SnapshotField.Kind.INT},
	{"name": "shoved_at", "kind": SnapshotField.Kind.INT},
	{"name": "holder", "kind": SnapshotField.Kind.INT},
]


func to_dict() -> Dictionary:
	return {
		"prop": prop,
		"state": body,
		"pos": pos,
		"vel": vel,
		"surface": surface,
		"shoved_by": shoved_by,
		"shoved_at": shoved_at,
		"holder": holder,
	}


static func from_dict(entry: Dictionary) -> PropState:
	var crate := PropState.new(entry["prop"])
	crate.body = entry["state"]
	crate.pos = entry["pos"]
	crate.vel = entry["vel"]
	crate.surface = entry["surface"]
	crate.shoved_by = entry["shoved_by"]
	crate.shoved_at = entry["shoved_at"]
	crate.holder = entry["holder"]
	return crate
