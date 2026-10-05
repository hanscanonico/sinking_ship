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
## Fresh wood where a rail has splintered.
static var splinter := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.SPLINTER)
static var frame := ShipMesh.Paint.new(
	FINISH.PLAIN, ArtPalette.TEAK, FINISH.PLAIN, ArtPalette.FRAME
)
## Treads are planked like the deck, a shade darker, so a stair reads as wood.
static var tread := ShipMesh.Paint.new(FINISH.DECK, ArtPalette.TREAD)
static var white := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.HOUSE)
## A funnel: buff with a black top outside, a riveted steel casing where it passes
## through a cabin.
static var funnel := ShipMesh.Paint.new(
	FINISH.FUNNEL, ArtPalette.FUNNEL, FINISH.PLATE, ArtPalette.CASING
)
static var mast := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.MAST)
## A staff's flag: the jack at the bow, the ensign at the stern.
static var jack := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.JACK)
static var ensign := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.ENSIGN)
static var dark := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.FUNNEL_TOP)
static var canvas := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.CANVAS)
static var rope := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.ROPE)
static var machine := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.MACHINE)
static var steel := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.STEEL)
static var brass := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.BRASS)
static var upholstery := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.UPHOLSTERY)
static var blanket := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.BLANKET)
static var linen := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.LINEN)
static var crate := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.CRATE)
## The rooms' linings (RoomDressing): walls white outside as every wall is, and
## inside riveted grey-green steel in an engine room, rough timber in a hold and
## varnished panelling in a wheelhouse; checker plate and rough boards underfoot;
## plating and boards overhead, on steel or timber beams.
static var bulkhead := ShipMesh.Paint.new(
	FINISH.HOUSE, ArtPalette.HOUSE, FINISH.PLATE, ArtPalette.BULKHEAD
)
static var hold_wall := ShipMesh.Paint.new(
	FINISH.HOUSE, ArtPalette.HOUSE, FINISH.ROUGH, ArtPalette.HOLD_WALL
)
static var panelling := ShipMesh.Paint.new(
	FINISH.HOUSE, ArtPalette.HOUSE, FINISH.CABIN, ArtPalette.PANELLING
)
static var checker_plate := ShipMesh.Paint.new(
	FINISH.DECK, ArtPalette.DECK, FINISH.PLATE, ArtPalette.CHECKER_PLATE
)
static var hold_floor := ShipMesh.Paint.new(
	FINISH.DECK, ArtPalette.DECK, FINISH.ROUGH, ArtPalette.HOLD_FLOOR
)
static var steel_overhead := ShipMesh.Paint.new(
	FINISH.PLAIN, ArtPalette.CEILING, FINISH.PLATE, ArtPalette.BULKHEAD_OVERHEAD
)
static var hold_overhead := ShipMesh.Paint.new(
	FINISH.PLAIN, ArtPalette.CEILING, FINISH.ROUGH, ArtPalette.HOLD_OVERHEAD
)
static var steel_beam := ShipMesh.Paint.new(
	FINISH.PLAIN, ArtPalette.BEAM, FINISH.PLAIN, ArtPalette.STEEL
)
static var hold_frame := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.HOLD_FRAME)
## What a room's furnishings are made of (RoomDressing).
static var engine := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.ENGINE)
static var bright_steel := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.BRIGHT_STEEL)
static var boiler := ShipMesh.Paint.new(FINISH.PLATE, ArtPalette.BOILER)
static var gauge := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.GAUGE_FACE)
static var stowed := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.STOWED_CRATE)
static var stencil := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.STENCIL)
static var sacking := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.SACKING)
static var enamel := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.ENAMEL)
static var lifebelt := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.LIFEBELT)
static var fire_bucket := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.FIRE_BUCKET)
static var mirror := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.MIRROR)
static var chart := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.CHART)
static var leather := ShipMesh.Paint.new(FINISH.PLAIN, ArtPalette.LEATHER)
## Glass seen from inside a room, and from outside it.
static var glass_in := ShipMesh.Paint.new(FINISH.GLASS_IN, Color.WHITE)
static var glass_out := ShipMesh.Paint.new(FINISH.GLASS_OUT, Color.WHITE)
