class_name DeckGear
extends RefCounted
## The parts a piece of her deck gear (DeckFurniture.GEAR) is made of, where it is more
## than its one envelope (#381). Each part is a box or a round, as every blocker is, and
## its piece's model fills it as art-lint holds any blocker drawn: a box's sides and its
## flat top where the box's are, a round's side round its axis and its top over it, so a
## body is held off each part where it is drawn. A barrel or a drum on a shaft lying along
## the deck fills no part — a box's top is flat and a round stands upright — so such gear
## houses its barrels; machinery standing upright, a crane's pedestal or a cable holder's
## wildcat, stands as a round of its own.
##
## The first part is the piece's foot: on the deck it stands on, named its kind and at one
## of its kind's sizes, the blocker the piece is drawn from (foot_of()). Each other part is
## a blocker of its own, named its kind and the part (part_name()), drawn as its piece is.
## Where its foot alone cannot say how a piece stands — a crane's jib forward or aft of
## its pedestal, and how long — its parts as her data lays them do (stance()).

const BOX := ShipBlocker.Shape.BOX
const ROUND := ShipBlocker.Shape.CYLINDER

## By model (DeckFurniture.GEAR's), its parts, its foot first: each its name (the foot's
## empty), its shape and its box in the model's own space — x along the piece's longer
## side, y up off the deck it stands on, z across, the middle of its footprint at the
## origin; a round's box square about its axis. A piece standing on its side across her
## (its longer side along her z) is turned a quarter (turn()), and one standing the other
## way about half round (half_turn()). A model with no parts here is its one envelope
## (envelope()). Every height est., as GEAR's are.
##
## An electric crane (#381) is stowed: its jib lowered to lie level along its x on a
## crutch post under its head, the way Plate III's elevation draws its pair's jib, the
## post standing on the deck under it — past the edge of the crane's own deck, the deck
## below (DROPS). Its jib's underside a door's height over the crane's deck (a body walks
## under it) and its top flush with its machinery house's, so a body walks out along it;
## its section and the post's est. Each pair's model is made for where it stands, its jib
## the plate's length but where that would stand its post on a ladder or another crane's:
## - electric_crane_688, her wells': 6.875 m, short of the plate's 7.35 m (the forward
##   well's) and 9.5 m (the after well's), its post clear of the forecastle's ladders and
##   of the poop cranes' posts;
## - electric_crane_925, her poop's: 9.25 m (the plate's 9.3 m), over her poop's front to
##   its post on the after well, forward of the poop's ladders;
## - electric_crane_700, A deck's: 7.0 m (the plate's), aft past A deck's end to its post
##   on B deck.
const PARTS := {
	# A warping capstan's round bed bolted to the deck, the plate's ring, and on it its
	# barrel, whelped and waisted under its drumhead, a little over half as wide.
	"capstan_162":
	[
		["", ROUND, AABB(Vector3(-0.8125, 0.0, -0.8125), Vector3(1.625, 0.125, 1.625))],
		["barrel", ROUND, AABB(Vector3(-0.5, 0.125, -0.5), Vector3(1.0, 0.8125, 1.0))],
	],
	"capstan_137":
	[
		["", ROUND, AABB(Vector3(-0.6875, 0.0, -0.6875), Vector3(1.375, 0.125, 1.375))],
		["barrel", ROUND, AABB(Vector3(-0.4375, 0.125, -0.4375), Vector3(0.875, 0.8125, 0.875))],
	],
	"capstan_112":
	[
		["", ROUND, AABB(Vector3(-0.5625, 0.0, -0.5625), Vector3(1.125, 0.125, 1.125))],
		["barrel", ROUND, AABB(Vector3(-0.375, 0.125, -0.375), Vector3(0.75, 0.8125, 0.75))],
	],
	# A cable holder's bedplate on the deck, the cable led to it along her deck from its
	# hawse pipe (ShipFittings), under its cover into its wildcat; and the wildcat on it
	# about its upright spindle, its brake drum and its cap.
	"cable_holder":
	[
		["", BOX, AABB(Vector3(-1.375, 0.0, -1.09375), Vector3(2.75, 0.25, 2.1875))],
		["wildcat", ROUND, AABB(Vector3(-0.875, 0.25, -0.875), Vector3(1.75, 0.5, 1.75))],
	],
	# An electric crane's pedestal, its machinery house over it, which slews, its jib
	# lowered from the house's fore face and the crutch post under its head.
	"electric_crane_688":
	[
		["", ROUND, AABB(Vector3(-3.875, 0.0, -0.4375), Vector3(0.875, 1.0, 0.875))],
		["house", BOX, AABB(Vector3(-4.1875, 1.0, -0.75), Vector3(1.5, 1.5, 1.5))],
		["jib", BOX, AABB(Vector3(-2.6875, 2.125, -0.25), Vector3(6.875, 0.375, 0.5))],
		["crutch", ROUND, AABB(Vector3(3.8125, 0.0, -0.1875), Vector3(0.375, 2.125, 0.375))],
	],
	"electric_crane_925":
	[
		["", ROUND, AABB(Vector3(-5.0625, 0.0, -0.4375), Vector3(0.875, 1.0, 0.875))],
		["house", BOX, AABB(Vector3(-5.375, 1.0, -0.75), Vector3(1.5, 1.5, 1.5))],
		["jib", BOX, AABB(Vector3(-3.875, 2.125, -0.25), Vector3(9.25, 0.375, 0.5))],
		["crutch", ROUND, AABB(Vector3(5.0, -3.3125, -0.1875), Vector3(0.375, 5.4375, 0.375))],
	],
	"electric_crane_700":
	[
		["", ROUND, AABB(Vector3(-3.9375, 0.0, -0.4375), Vector3(0.875, 1.0, 0.875))],
		["house", BOX, AABB(Vector3(-4.25, 1.0, -0.75), Vector3(1.5, 1.5, 1.5))],
		["jib", BOX, AABB(Vector3(-2.75, 2.125, -0.25), Vector3(7.0, 0.375, 0.5))],
		["crutch", ROUND, AABB(Vector3(3.875, -2.75, -0.1875), Vector3(0.375, 4.875, 0.375))],
	],
	# The steam windlass's bedplate, its two upright steam cylinders at its ends and the
	# case of its gearing between them, its main shaft and cable lifters housed.
	"steam_windlass":
	[
		["", BOX, AABB(Vector3(-2.8125, 0.0, -1.65625), Vector3(5.625, 0.3125, 3.3125))],
		["cylinder", ROUND, AABB(Vector3(-2.5625, 0.3125, -0.5), Vector3(1.0, 0.9375, 1.0))],
		["cylinder", ROUND, AABB(Vector3(1.5625, 0.3125, -0.5), Vector3(1.0, 0.9375, 1.0))],
		[
			"gear case",
			BOX,
			AABB(Vector3(-1.5625, 0.3125, -1.40625), Vector3(3.125, 0.9375, 2.8125))
		],
	],
	# The steam winch's bedplate, its two upright steam cylinders at its after end and the
	# frame of its gearing, its barrel and its warping ends housed, forward of them.
	"steam_winch":
	[
		["", BOX, AABB(Vector3(-1.90625, 0.0, -1.375), Vector3(3.8125, 0.25, 2.75))],
		["cylinder", ROUND, AABB(Vector3(-1.65625, 0.25, 0.25), Vector3(0.875, 1.0, 0.875))],
		["cylinder", ROUND, AABB(Vector3(-1.65625, 0.25, -1.125), Vector3(0.875, 1.0, 0.875))],
		["frame", BOX, AABB(Vector3(-0.78125, 0.25, -1.125), Vector3(2.4375, 1.0, 2.25))],
	],
}
## By model, how far under the deck its foot stands on a piece reaches where a part of it
## stands past that deck's edge on the deck below: a crane's crutch post, the poop's on her
## after well and A deck's on B deck (PARTS).
const DROPS := {"electric_crane_925": 3.3125, "electric_crane_700": 2.75}
## How near a blocker stands to a part's size or place to be it, in metres.
const NEAR := 0.001

## Every part's name but a foot's, gathered once (is_part()).
static var _part_names := {}


## The name of [param part] of a piece of [param kind]: its kind's for its foot, else
## its kind's and its own.
static func part_name(kind: StringName, part: String) -> StringName:
	return kind if part.is_empty() else StringName("%s %s" % [kind, part])


## [param size], a size over all GEAR gives (its longer side, its height, its shorter
## side), as a box in its model's space: on the deck, about the middle of its footprint —
## and down [param drop] under it, where a part of it stands on the deck below (DROPS).
static func envelope(size: Vector3, drop := 0.0) -> AABB:
	return AABB(Vector3(-size.x * 0.5, -drop, -size.z * 0.5), size + Vector3.UP * drop)


## The box over all of the model [param made], made at [param size] (GEAR's): envelope(),
## down as far as its DROPS.
static func envelope_of(made: String, size: Vector3) -> AABB:
	return envelope(size, DROPS.get(made, 0.0))


## The parts of a piece of [param kind] made at [param size], its foot first: each its
## name (part_name()), its shape and its box in its model's space (PARTS); a piece of no
## parts its one envelope, round for a kind DeckFurniture.ROUND_GEAR names.
static func parts_of(kind: StringName, size: Vector3) -> Array[Array]:
	var made: String = DeckFurniture.GEAR[kind][size]
	var found: Array[Array] = []
	if PARTS.has(made):
		for part: Array in PARTS[made]:
			found.append([part_name(kind, part[0]), part[1], part[2]])
		return found
	var shape := ROUND if kind in DeckFurniture.ROUND_GEAR else BOX
	found.append([kind, shape, envelope(size)])
	return found


## Whether [param blocker] is a part of a piece of her gear other than its foot: a
## crane's house, a cable holder's wildcat.
static func is_part(blocker: ShipBlocker) -> bool:
	if _part_names.is_empty():
		for kind: StringName in DeckFurniture.GEAR:
			for size: Vector3 in DeckFurniture.GEAR[kind]:
				for part: Array in parts_of(kind, size).slice(1):
					_part_names[part[0]] = true
	return _part_names.has(blocker.name)


## The size over all (GEAR's) of the piece [param blocker] is the foot of: its kind's first
## size whose foot it stands as; Vector3.ZERO where it is no foot of any. Of sizes whose
## foot is the same, where it stands tells which (stance()).
static func foot_of(blocker: ShipBlocker) -> Vector3:
	var sizes := _sizes(blocker)
	return sizes[0] if not sizes.is_empty() else Vector3.ZERO


## Where the piece [param blocker] is the foot of stands, made at [param size]: its
## model's space in hers, its origin on the deck at the middle of its footprint, turned a
## quarter (turn()) where its foot's longer side lies across her, and from there half
## round (half_turn()) where [param half] — a crane whose jib points aft.
static func frame(blocker: ShipBlocker, size: Vector3, half := false) -> Transform3D:
	var foot: AABB = parts_of(blocker.name, size)[0][2]
	var middle := blocker.centre
	var basis := Basis.IDENTITY
	if blocker.shape == BOX:
		middle = blocker.area.get_center()
		if blocker.area.size.y > blocker.area.size.x:
			basis = turn()
	if half:
		basis = basis * half_turn()
	var off := basis * Vector3(foot.get_center().x, 0.0, foot.get_center().z)
	return Transform3D(basis, Vector3(middle.x, blocker.bottom - foot.position.y, middle.y) - off)


## The quarter turn a piece standing across her takes: its model's x along her −z and its
## z along her +x, forward.
static func turn() -> Basis:
	return Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)


## The half turn a piece standing the other way about takes: its model's x along her −x
## and its z along her −z.
static func half_turn() -> Basis:
	return Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD)


## How the piece [param blocker] is the foot of stands among [param layout]'s blockers:
## [its size over all (GEAR's), its frame()] — of its kind's sizes whose foot it stands as,
## turned as its foot lies or half round from there, the first whose every other part
## [param layout] lays where that puts it: her data says which way a crane's jib points,
## and which of her cranes it is, by where it lays the jib and its post. Its first size,
## as its foot lies, where nothing else could be or [param layout] lays none whole;
## [Vector3.ZERO, Transform3D.IDENTITY] where it is no foot.
static func stance(layout: ShipLayout, blocker: ShipBlocker) -> Array:
	var sizes := _sizes(blocker)
	if sizes.is_empty():
		return [Vector3.ZERO, Transform3D.IDENTITY]
	var first := [sizes[0], frame(blocker, sizes[0])]
	if sizes.size() == 1 and _even(blocker.name, sizes[0]):
		return first
	var named := _named(layout, blocker.name)
	for size: Vector3 in sizes:
		for half: bool in [false, true]:
			var at := frame(blocker, size, half)
			var parts := _placed(blocker.name, size, at)
			if parts.slice(1).all(func(part: ShipBlocker) -> bool: return _lays(named, part)):
				return [size, at]
	return first


## The parts of the piece [param blocker] is the foot of, as the blockers her data lays
## for them (tools/gen_titanic.py's gear()) where [param layout] has it stand (stance()),
## its foot first; none where it is no foot.
static func laid(layout: ShipLayout, blocker: ShipBlocker) -> Array[ShipBlocker]:
	var standing := stance(layout, blocker)
	if standing[0] == Vector3.ZERO:
		return [] as Array[ShipBlocker]
	return _placed(blocker.name, standing[0], standing[1])


## The piece [param blocker] of [param layout] is the foot of, drawn into [param mesh] as
## its model where it stands (stance()), filling each of its parts; nothing for a part of
## a piece other than its foot, which its foot's model draws; false where [param blocker]
## is no foot of a piece with a model, for the caller to draw as its envelope.
static func draw(mesh: ShipMesh, layout: ShipLayout, blocker: ShipBlocker) -> bool:
	if is_part(blocker):
		return true
	var standing := stance(layout, blocker)
	if standing[0] == Vector3.ZERO:
		return false
	var made: String = DeckFurniture.GEAR[blocker.name][standing[0]]
	if made.is_empty():
		return false
	mesh.model(ShipModel.named(made), standing[1])
	return true


## Every size over all (GEAR's) of [param blocker]'s kind whose foot it stands as, in
## GEAR's order.
static func _sizes(blocker: ShipBlocker) -> Array[Vector3]:
	var found: Array[Vector3] = []
	if not DeckFurniture.GEAR.has(blocker.name):
		return found
	var standing := DeckFurniture.size_of(blocker)
	for size: Vector3 in DeckFurniture.GEAR[blocker.name]:
		var foot: Array = parts_of(blocker.name, size)[0]
		if foot[1] == blocker.shape and _size(foot[2]).distance_to(standing) < NEAR:
			found.append(size)
	return found


## The parts of a piece of [param kind] made at [param size] standing at [param at], as
## blockers, its foot first.
static func _placed(kind: StringName, size: Vector3, at: Transform3D) -> Array[ShipBlocker]:
	var found: Array[ShipBlocker] = []
	for part: Array in parts_of(kind, size):
		var box: AABB = at * (part[2] as AABB)
		var made := ShipBlocker.new()
		made.name = part[0]
		made.shape = part[1]
		made.bottom = box.position.y
		made.top = box.end.y
		if made.shape == ROUND:
			made.centre = Vector2(box.get_center().x, box.get_center().z)
			made.radius = box.size.x * 0.5
		else:
			made.area = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		found.append(made)
	return found


## Whether a piece of [param kind] made at [param size] is the same piece turned half
## round: each part where another of its name and shape stood. Its foot alone tells how
## such a piece stands.
static func _even(kind: StringName, size: Vector3) -> bool:
	var parts := parts_of(kind, size)
	for part: Array in parts:
		var box: AABB = part[2]
		var turned := AABB(Vector3(-box.end.x, box.position.y, -box.end.z), box.size)
		var found := parts.any(
			func(other: Array) -> bool:
				return (
					other[0] == part[0]
					and other[1] == part[1]
					and (other[2] as AABB).position.distance_to(turned.position) < NEAR
					and (other[2] as AABB).size.distance_to(turned.size) < NEAR
				)
		)
		if not found:
			return false
	return true


## [param layout]'s blockers named for a part of a piece of [param kind] other than its
## foot, by name.
static func _named(layout: ShipLayout, kind: StringName) -> Dictionary:
	var wanted := {}
	for size: Vector3 in DeckFurniture.GEAR[kind]:
		for part: Array in parts_of(kind, size).slice(1):
			wanted[part[0]] = true
	var found := {}
	for blocker: ShipBlocker in layout.blockers:
		if wanted.has(blocker.name):
			if not found.has(blocker.name):
				found[blocker.name] = []
			(found[blocker.name] as Array).append(blocker)
	return found


## Whether one of [param named]'s blockers (_named()) is [param part]: its name, shape,
## heights and footprint within NEAR.
static func _lays(named: Dictionary, part: ShipBlocker) -> bool:
	for blocker: ShipBlocker in named.get(part.name, []):
		if blocker.shape != part.shape:
			continue
		if absf(blocker.bottom - part.bottom) > NEAR or absf(blocker.top - part.top) > NEAR:
			continue
		if part.shape == ROUND:
			if (
				blocker.centre.distance_to(part.centre) <= NEAR
				and absf(blocker.radius - part.radius) <= NEAR
			):
				return true
		elif (
			blocker.area.position.distance_to(part.area.position) <= NEAR
			and blocker.area.size.distance_to(part.area.size) <= NEAR
		):
			return true
	return false


## [param box]'s size as DeckFurniture.size_of() gives a blocker's: its longer side in
## plan, its height and its shorter side.
static func _size(box: AABB) -> Vector3:
	return Vector3(maxf(box.size.x, box.size.z), box.size.y, minf(box.size.x, box.size.z))
