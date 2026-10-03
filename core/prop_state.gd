class_name PropState
extends RefCounted
## One crate of the ship's cargo as the match has it (SH10). Every field is in the
## snapshot (D5): what the crate is — its size, mass and grip — is the layout's
## ShipProp at the same index.

## LOST: gone into the sea, for the rest of the match.
enum Body { GROUNDED, AIRBORNE, LOST }

## Its index in [member ShipLayout.props].
var prop: int
## Ship-local; y is its underside's height.
var pos: Vector3
var vel: Vector3
var body: Body = Body.GROUNDED
var surface: int = Surfaces.NONE
## The seat whose shove last sent it, or -1.
var shoved_by: int = -1
## The tick that shove landed on, or -1.
var shoved_at: int = -1


func _init(index: int = 0) -> void:
	prop = index


func is_lost() -> bool:
	return body == Body.LOST


## Every crate of [param layout] where it starts, at rest on the deck.
static func from_layout(layout: ShipLayout) -> Array[PropState]:
	var props: Array[PropState] = []
	for index in layout.props.size():
		var crate := PropState.new(index)
		crate.pos = layout.props[index].pos
		props.append(crate)
	return props


## The crates [param snapshot] holds.
static func from_snapshot(snapshot: Dictionary) -> Array[PropState]:
	var props: Array[PropState] = []
	for entry: Dictionary in snapshot["props"]:
		props.append(from_dict(entry))
	return props


func to_dict() -> Dictionary:
	return {
		"prop": prop,
		"state": body,
		"pos": pos,
		"vel": vel,
		"surface": surface,
		"shoved_by": shoved_by,
		"shoved_at": shoved_at,
	}


static func from_dict(entry: Dictionary) -> PropState:
	var crate := PropState.new(entry["prop"])
	crate.body = entry["state"]
	crate.pos = entry["pos"]
	crate.vel = entry["vel"]
	crate.surface = entry["surface"]
	crate.shoved_by = entry["shoved_by"]
	crate.shoved_at = entry["shoved_at"]
	return crate
