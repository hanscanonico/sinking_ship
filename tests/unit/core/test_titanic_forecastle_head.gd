extends GutTest
## The Titanic's forecastle head (#469), from her fo'c'sle step to her stem: a body walks it
## out to her stem along her side as Plate IV draws it, and it never stands past her shell.
## She was laid in 3 m strips, each as narrow as her hull at its forward end, ending 2.8 m
## short of her stem.

## Her forecastle head's deck (tools/gen_titanic.py's FCSL[1]).
const HEAD := 4.9375
## A body's step (data/rules/brawl.tres), how far off the deck its feet may stand.
const STEP := 0.35
## Plate IV's half breadths of her forecastle head, at stations along her (x, half breadth),
## off her side's line (tools/titanic_plates/forecastle.py's SIDE, px 10050-10625).
const PLATE: Array[Vector2] = [
	Vector2(113.91, 8.16),
	Vector2(117.92, 6.77),
	Vector2(121.93, 5.01),
	Vector2(125.94, 3.00),
	Vector2(129.28, 1.04),
]
## How far short of her stem the deck may stop: where she is a few tenths across.
const STEM_SHORT := 0.5
## How far in from her plate's side, or her shell where that stands inside it, the deck may
## stop: a strip half a metre long narrows that much along it at her bow.
const SIDE_SHORT := 0.35
## The grain the deck's edge is found to.
const GRAIN := 0.01

var _layout: ShipLayout
var _surfaces: Surfaces


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")
	_surfaces = Surfaces.new(_layout)


## Her stem's head, where her shell closes: her last section's forward end.
func _stem() -> float:
	var sections := _layout.structure.sections
	var last := sections[sections.size() - 1]
	return last.x + last.length * 0.5


## Whether a body's feet at [param x], [param z] stand on her forecastle head's deck, or on
## gear standing a step high on it (a capstan's bed, a cable holder's plate: DeckGear.PARTS),
## its footing that deck.
func _on_head(x: float, z: float) -> bool:
	var point := Vector3(x, HEAD, z)
	var surface := _surfaces.under(point, STEP)
	if surface == Surfaces.NONE:
		return false
	var deck := _surfaces.footing(surface)
	return deck != Surfaces.NONE and is_equal_approx(_surfaces.height_at(deck, point), HEAD)


## How far out from her centre line her forecastle head's deck runs at [param x] on the
## side [param way] points to.
func _deck_half(x: float, way: float) -> float:
	var z := 0.0
	while _on_head(x, way * (z + GRAIN)):
		z += GRAIN
	return z


func test_her_forecastle_head_runs_on_to_her_stem() -> void:
	var stem := _stem()
	var x := 112.5
	while x < stem and _on_head(x + GRAIN, 0.0):
		x += GRAIN
	assert_gt(
		x, stem - STEM_SHORT, "her forecastle head ends %.2f m short of her stem" % (stem - x)
	)


func test_her_forecastle_head_follows_her_plate_s_side_inside_her_shell() -> void:
	for station: Vector2 in PLATE:
		for way: float in [-1.0, 1.0]:
			var shell := _layout.structure.half_breadth(station.x, HEAD - 0.001, int(way))
			var side := minf(station.y, shell)
			var deck := _deck_half(station.x, way)
			var at := (
				"at x %.2f, side %d: deck %.2f, plate %.2f, shell %.2f"
				% [station.x, way, deck, station.y, shell]
			)
			assert_lte(deck, side, "inside her plate's side and her shell " + at)
			assert_gt(deck, side - SIDE_SHORT, "out to her plate's side or her shell " + at)
