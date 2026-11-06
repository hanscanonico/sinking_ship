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

const BOX := ShipBlocker.Shape.BOX
const ROUND := ShipBlocker.Shape.CYLINDER

## By model (DeckFurniture.GEAR's), its parts, its foot first: each its name (the foot's
## empty), its shape and its box in the model's own space — x along the piece's longer
## side, y up off the deck it stands on, z across, the middle of its footprint at the
## origin; a round's box square about its axis. A piece standing on its side across her
## (its longer side along her z) is turned a quarter (turn()). A model with no parts here
## is its one envelope (envelope()). Every height est., as GEAR's are.
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
	# An electric crane's pedestal, and its machinery house over it, which slews.
	"electric_crane":
	[
		["", ROUND, AABB(Vector3(-0.4375, 0.0, -0.4375), Vector3(0.875, 1.0, 0.875))],
		["house", BOX, AABB(Vector3(-0.75, 1.0, -0.75), Vector3(1.5, 1.5, 1.5))],
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
## How near a blocker stands to a part's size or place to be it, in metres.
const NEAR := 0.001

## Every part's name but a foot's, gathered once (is_part()).
static var _part_names := {}


## The name of [param part] of a piece of [param kind]: its kind's for its foot, else
## its kind's and its own.
static func part_name(kind: StringName, part: String) -> StringName:
	return kind if part.is_empty() else StringName("%s %s" % [kind, part])


## [param size], a size over all GEAR gives (its longer side, its height, its shorter
## side), as a box in its model's space: on the deck, about the middle of its footprint.
static func envelope(size: Vector3) -> AABB:
	return AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)


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


## The size over all (GEAR's) of the piece [param blocker] is the foot of: its kind's size
## whose foot it stands as; Vector3.ZERO where it is no foot of any.
static func foot_of(blocker: ShipBlocker) -> Vector3:
	if not DeckFurniture.GEAR.has(blocker.name):
		return Vector3.ZERO
	var standing := DeckFurniture.size_of(blocker)
	for size: Vector3 in DeckFurniture.GEAR[blocker.name]:
		var foot: Array = parts_of(blocker.name, size)[0]
		if foot[1] == blocker.shape and _size(foot[2]).distance_to(standing) < NEAR:
			return size
	return Vector3.ZERO


## Where the piece [param blocker] is the foot of stands, made at [param size]: its
## model's space in hers, its origin on the deck at the middle of its footprint, turned a
## quarter (turn()) where its foot's longer side lies across her.
static func frame(blocker: ShipBlocker, size: Vector3) -> Transform3D:
	var foot: AABB = parts_of(blocker.name, size)[0][2]
	var middle := blocker.centre
	var basis := Basis.IDENTITY
	if blocker.shape == BOX:
		middle = blocker.area.get_center()
		if blocker.area.size.y > blocker.area.size.x:
			basis = turn()
	var off := basis * Vector3(foot.get_center().x, 0.0, foot.get_center().z)
	return Transform3D(basis, Vector3(middle.x, blocker.bottom - foot.position.y, middle.y) - off)


## The quarter turn a piece standing across her takes: its model's x along her −z and its
## z along her +x, forward.
static func turn() -> Basis:
	return Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)


## The parts of the piece [param blocker] is the foot of, as the blockers her data lays
## for them (tools/gen_titanic.py's gear()), its foot first; none where it is no foot.
static func laid(blocker: ShipBlocker) -> Array[ShipBlocker]:
	var found: Array[ShipBlocker] = []
	var size := foot_of(blocker)
	if size == Vector3.ZERO:
		return found
	var at := frame(blocker, size)
	for part: Array in parts_of(blocker.name, size):
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


## The piece [param blocker] is the foot of, drawn into [param mesh] as its model where it
## stands (frame()), filling each of its parts; nothing for a part of a piece other than
## its foot, which its foot's model draws; false where [param blocker] is no foot of a
## piece with a model, for the caller to draw as its envelope.
static func draw(mesh: ShipMesh, blocker: ShipBlocker) -> bool:
	if is_part(blocker):
		return true
	var size := foot_of(blocker)
	if size == Vector3.ZERO:
		return false
	var made: String = DeckFurniture.GEAR[blocker.name][size]
	if made.is_empty():
		return false
	mesh.model(ShipModel.named(made), frame(blocker, size))
	return true


## [param box]'s size as DeckFurniture.size_of() gives a blocker's: its longer side in
## plan, its height and its shorter side.
static func _size(box: AABB) -> Vector3:
	return Vector3(maxf(box.size.x, box.size.z), box.size.y, minf(box.size.x, box.size.z))
