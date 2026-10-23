class_name MooringGear
extends RefCounted
## What she is made fast by alongside (ShipFittings), on the open deck at each end of
## her (EndDeck): by either side a pair of mooring bitts (BITTS_MODEL), and beside each
## a coil of mooring line flaked down on the deck, its end led to the bitts
## (COIL_MODEL). All of it lies under a step over its deck, where bodies walk, as the
## ground tackle does: on the deck, outdoors, clear of every blocker, stair and
## opening, of the ground tackle, of where a seat starts and of where a swimmer comes
## aboard (_fits). Placed by rules on the layout, never by hand.

## The modelled pair of bitts (assets/models/bitts): its origin the middle of its
## base's underside on the deck, its two posts along x; its box over all there.
const BITTS_MODEL := "bitts"
const BITTS_BOX := AABB(Vector3(-0.42, 0.0, -0.15), Vector3(0.84, 0.3, 0.3))
## The modelled coil (assets/models/rope_coil): its origin on the deck under the middle
## of its turns, its end led off toward +x; its box over all there.
const COIL_MODEL := "rope_coil"
const COIL_BOX := AABB(Vector3(-0.29, 0.0, -0.3), Vector3(0.81, 0.14, 0.59))
## How far in from the deck's end the middle of a pair of bitts stands, and in from her
## side; where it does not fit there, it is tried BITTS_STEP further in each time, up to
## BITTS_TRIES times. How much further from the end, and in from her side, its coil lies.
const BITTS_FROM_END := 1.6
const BITTS_IN := 0.3
const BITTS_STEP := 0.4
const BITTS_TRIES := 11
const COIL_ALONG := 1.0
const COIL_IN := 0.5
## How near where a seat starts, or where a boarding ladder comes over her side, none
## of it stands, in the ship plane.
const CLEAR_OF := 1.0

## Every piece placed, as [model name, its place in ship space]: build()'s.
var placed: Array[Array] = []

var _space: ShipSpace
var _layout: ShipLayout
## Where the ground tackle lies, in the ship plane: kept clear.
var _kept: Array[Rect2] = []


## Gear for [param space]'s ship, kept clear of [param kept] (ShipFittings.tackle).
func _init(space: ShipSpace, kept: Array[Rect2] = []) -> void:
	_space = space
	_layout = space.layout
	_kept = kept


## Places it all, each piece where it fits (_fits), drawn into [param mesh]: either side
## of each end deck, the pair of bitts nearest its end that fits, by her side wherever
## the deck narrows, and its coil beside it when that fits too.
func build(mesh: ShipMesh) -> void:
	for toward: float in [1.0, -1.0]:
		var deck := EndDeck.of(_space, toward)
		if deck == null:
			continue
		var end := deck.spread.end.x if toward > 0.0 else deck.spread.position.x
		for side: float in [-1.0, 1.0]:
			for step in BITTS_TRIES:
				var x := end - toward * (BITTS_FROM_END + BITTS_STEP * step)
				var edge := _edge(deck, x, side)
				if is_nan(edge):
					continue
				var bitts := Transform3D(
					Basis.IDENTITY, Vector3(x, deck.height, edge - side * BITTS_IN)
				)
				if not _fits(bitts, BITTS_BOX, deck):
					continue
				_place(mesh, BITTS_MODEL, bitts)
				# Its end led toward the bitts: forward at her bow, aft at her stern.
				var turn := Basis.IDENTITY if toward > 0.0 else Basis(Vector3.UP, PI)
				var at := Vector3(x - toward * COIL_ALONG, deck.height, edge - side * COIL_IN)
				var coil := Transform3D(turn, at)
				if _fits(coil, COIL_BOX, deck):
					_place(mesh, COIL_MODEL, coil)
				break


## Her side's line on [param side] (1 starboard, -1 port) along a pair of bitts whose
## middle stands at [param x] on [param deck]: the furthest in the deck reaches over the
## whole of its length, where it narrows toward her end; NAN where it does not reach.
func _edge(deck: EndDeck, x: float, side: float) -> float:
	var fore := deck.across(x + BITTS_BOX.end.x)
	var aft := deck.across(x + BITTS_BOX.position.x)
	if fore == Vector2.INF or aft == Vector2.INF:
		return NAN
	return minf(fore.y, aft.y) if side > 0.0 else maxf(fore.x, aft.x)


## [param place]'s box [param box] in the ship plane: its footprint.
static func footprint(place: Transform3D, box: AABB) -> Rect2:
	var placed_box := place * box
	return Rect2(placed_box.position.x, placed_box.position.z, placed_box.size.x, placed_box.size.z)


## Whether [param box] set at [param place] fits on [param deck]: wholly on its pieces
## with nothing standing there (EndDeck.bare), outdoors, clear of the ground tackle and
## of every other piece placed, and CLEAR_OF where a seat starts or a ladder comes
## aboard.
func _fits(place: Transform3D, box: AABB, deck: EndDeck) -> bool:
	var area := footprint(place, box)
	var middle := area.get_center()
	return (
		deck.bare(_layout, area, box.end.y)
		and _space.outdoors(Vector3(middle.x, deck.height + box.end.y, middle.y))
		and _clear_of_what_lies_there(area)
		and _clear_of_comings_and_goings(area.grow(CLEAR_OF), deck.height)
	)


## Whether [param area] keeps off the ground tackle and every piece placed already.
func _clear_of_what_lies_there(area: Rect2) -> bool:
	for kept: Rect2 in _kept:
		if kept.intersects(area):
			return false
	for piece: Array in placed:
		if footprint(piece[1], _box_of(piece[0])).intersects(area):
			return false
	return true


## Whether no seat starts, and no swimmer comes aboard by a ladder, in [param room] on
## the deck at [param height].
func _clear_of_comings_and_goings(room: Rect2, height: float) -> bool:
	for spawn: Vector3 in _layout.spawns:
		if is_equal_approx(spawn.y, height) and room.has_point(Vector2(spawn.x, spawn.z)):
			return false
	for ladder: ShipLadder in _layout.ladders:
		var rungs := Rect2(ladder.from, Vector2.ZERO).expand(ladder.to).grow(ShipSpace.SLIVER)
		var aboard := _layout.platforms[ladder.platform].height
		if is_equal_approx(aboard, height) and room.intersects(rungs):
			return false
	return true


func _place(mesh: ShipMesh, model: String, place: Transform3D) -> void:
	mesh.model(ShipModel.named(model), place)
	placed.append([model, place])


static func _box_of(model: String) -> AABB:
	return BITTS_BOX if model == BITTS_MODEL else COIL_BOX
