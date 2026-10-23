class_name PropKind
extends Resource
## What a kind of prop is (#273), the same for every prop of the kind: whether a Grab
## press may take it and what holding it costs, whether it is solid, and what it does in
## the sea. What is about one prop's form — where it starts, its size, mass and grip — is
## its layout entry's (ShipProp). One file per kind, data/props/NAME.tres, as the bot
## tiers are one per tier.

const DIRECTORY := "res://data/props"

## Whether a Grab press may take it.
@export var holdable: bool
## Whether it holds bodies back, its lid is a surface and a shove lands on it, as cargo
## does (Hazards); one that is not, bodies walk through, and it hits one only closing at
## crate_impact_speed or more.
@export var solid: bool
## The size every prop of the kind is (ShipProp.radius, ShipProp.height) — its model
## stays inside it; 0 for a kind whose props are each their own size, as cargo is.
@export var radius: float
@export var height: float
@export_group("Held")
## The fastest a body holding it walks, in m/s.
@export var carry_walk: float
## Whether a body holding it may brace, and charge a shove: one that may not throws its
## shove quick, as an exhausted one does.
@export var carry_brace: bool
@export var carry_charge: bool
## Whether a landed charged shove knocks it out of its holder's hands, at its feet.
@export var loose_on_charge: bool
## Whether its holder keeps it in the sea — else it is lost there as its holder starts
## swimming — and the share of the open water's rate the holder's cold meter drains at
## while it does: above 0, so every match still ends. In a pocket of trapped air the
## lower of this and pocket_cold_rate drains.
@export var afloat: bool
@export var sea_cold_rate: float
@export_group("Loose")
## The least it sends a body it runs into at crate_impact_speed or more, in m/s, for a
## kind that is not solid; a solid one sends it at crate_knockback.
@export var knockback: float

static var _loaded: Dictionary[StringName, PropKind] = {}


## The kind called [param kind_name] (data/props/NAME.tres), loaded once; null when there
## is none.
static func named(kind_name: StringName) -> PropKind:
	if not _loaded.has(kind_name):
		var path := "%s/%s.tres" % [DIRECTORY, kind_name]
		_loaded[kind_name] = load(path) as PropKind if ResourceLoader.exists(path) else null
	return _loaded[kind_name]


## Every kind there is, by name, in name order.
static func names() -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.get_extension() == "tres":
			found.append(file.get_basename())
	found.sort()
	return found


## Every reason this kind cannot be played; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if radius < 0.0 or height < 0.0 or (radius == 0.0) != (height == 0.0):
		found.append("prop kind: a size is a radius and a height, both positive or both 0")
	if holdable and carry_walk <= 0.0:
		found.append("prop kind: one that can be held needs a positive carry_walk")
	if afloat and (sea_cold_rate <= 0.0 or sea_cold_rate > 1.0):
		found.append("prop kind: sea_cold_rate must be above 0 and at most 1: the cold still ends")
	if afloat and not holdable:
		found.append("prop kind: only one that can be held keeps its holder afloat")
	if not solid and knockback <= 0.0:
		found.append("prop kind: one that is not solid needs a positive knockback")
	return found
