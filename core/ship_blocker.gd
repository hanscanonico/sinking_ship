class_name ShipBlocker
extends Resource
## Something solid standing on the ship (D6) — a deckhouse, a funnel, a hatch — as
## an upright box or cylinder between two heights, in ship space. Bodies are pushed
## out of it in the deck plane, and a shove does not pass through it.

enum Shape { BOX, CYLINDER }

@export var shape: Shape
## BOX: the footprint in the ship's x/z plane; position is its (x, z) minimum corner.
@export var area: Rect2
## CYLINDER: the axis, in the ship's x/z plane.
@export var centre: Vector2
## CYLINDER: the radius.
@export var radius: float
## The heights its underside and its top stand at.
@export var bottom: float
@export var top: float
## Fitted inside her lines: her hull (ShipHull) is lofted round her decks and what
## stood in her before, never round this, which stands where her hull already lets it
## (#148). No rule reads it.
@export var fitted: bool
## What it is, for the art to draw it as: the gear on her open decks by its name — a
## capstan, an electric winch, a crane (DeckFurniture.GEAR) —, laid at a size its kind
## is made at, and each other part of a piece made of more than one by its kind's
## name and its own, a crane's "electric crane house" (DeckGear.PARTS); a hatch's
## coaming over no opening of her structure's, "hatch" (DeckFurniture.HATCH); empty
## for a wall, a house, any other hatch and all the rest,
## which the art reads from its shape and where it stands. No rule reads it.
@export var name: StringName
