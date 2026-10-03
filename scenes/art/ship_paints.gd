class_name ShipPaints
extends RefCounted
## The dressed ship's paints (ShipMesh.Paint), one per kind of surface, in
## ArtPalette's colours: outdoors, and indoors where that differs.

const FINISH := ShipMesh.Finish

static var deck := ShipMesh.Paint.new(FINISH.DECK, ArtPalette.DECK)
static var ceiling := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.CEILING)
static var beam := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.BEAM)
static var hull := ShipMesh.Paint.new(FINISH.HULL, ArtPalette.HULL)
## A wall: a white house outside, a painted cabin inside.
static var wall := ShipMesh.Paint.new(
	FINISH.HOUSE, ArtPalette.HOUSE, FINISH.CABIN, ArtPalette.CABIN
)
static var teak := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.TEAK)
static var frame := ShipMesh.Paint.new(
	FINISH.PLAIN, ArtPalette.TEAK, FINISH.PLAIN, ArtPalette.FRAME
)
## Treads are planked like the deck, a shade darker, so a stair reads as wood.
static var tread := ShipMesh.Paint.new(FINISH.DECK, ArtPalette.TREAD)
static var white := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.HOUSE)
## A funnel: buff with a black top outside, cabin paint where it passes through one.
static var funnel := ShipMesh.Paint.new(
	FINISH.FUNNEL, ArtPalette.FUNNEL, FINISH.CABIN, ArtPalette.CABIN
)
static var mast := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.MAST)
static var dark := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.FUNNEL_TOP)
static var canvas := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.CANVAS)
static var machine := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.MACHINE)
static var steel := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.STEEL)
static var brass := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.BRASS)
static var upholstery := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.UPHOLSTERY)
static var blanket := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.BLANKET)
static var linen := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.LINEN)
static var crate := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.CRATE)
## Glass seen from inside a room, and from outside it.
static var glass_in := ShipMesh.Paint.new(FINISH.GLASS_IN, Color.WHITE)
static var glass_out := ShipMesh.Paint.new(FINISH.GLASS_OUT, Color.WHITE)
