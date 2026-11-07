extends GutTest
## Her boundaries that are not watertight leak (#513): every hatch trunk's casing weeps
## through its seams into each cell standing beside it, as does the end wall two of her
## deckhouses share. Each leak's area is the seams' gaps (tools/titanic_leakage.py, its
## sizes and their sources there): tenths of a millimetre along a few metres of seam per
## square metre of casing, never the casing opened.

## A leak's area over the face it weeps through: at least a hundred-thousandth of it, at
## most a thousandth.
const SHARE := Vector2(1e-5, 1e-3)

var _structure: ShipStructure


func before_all() -> void:
	_structure = Fleet.layout(&"titanic").structure


## The cells sharing a face standing up with [param name]'s, by name: each its face's area.
func _beside(name: StringName) -> Dictionary:
	var it := _structure.cells[_structure.cell_named(name)]
	var found := {}
	for cell: FloodCell in _structure.cells:
		if cell == it:
			continue
		for axis: int in [0, 2]:
			var other := 2 - axis
			var touches := (
				absf(cell.low[axis] - it.high[axis]) < 1e-4
				or absf(cell.high[axis] - it.low[axis]) < 1e-4
			)
			var tall := minf(cell.high.y, it.high.y) - maxf(cell.low.y, it.low.y)
			var wide := (
				minf(cell.high[other], it.high[other]) - maxf(cell.low[other], it.low[other])
			)
			if touches and tall > 1e-3 and wide > 1e-3:
				found[cell.name] = tall * wide
	return found


func _leak(a: StringName, b: StringName) -> ShipOpening:
	for opening: ShipOpening in _structure.openings:
		if opening.kind == ShipOpening.Kind.LEAK and a in opening.joins and b in opening.joins:
			return opening
	return null


func _assert_weeps(a: StringName, b: StringName, face: float) -> void:
	var leak := _leak(a, b)
	assert_not_null(leak, "%s weeps into %s" % [a, b])
	if leak == null:
		return
	var share := leak.flow_area() / face
	gut.p("%s → %s: %.4f m² over %.1f m²" % [a, b, leak.flow_area(), face])
	assert_between(share, SHARE.x, SHARE.y, "%s's seams into %s, a share of its face" % [a, b])


func test_each_trunks_casing_weeps_into_every_cell_beside_it() -> void:
	var trunks := 0
	for cell: FloodCell in _structure.cells:
		if not String(cell.name).ends_with("_trunk"):
			continue
		trunks += 1
		var beside := _beside(cell.name)
		assert_gt(beside.size(), 0, "%s stands beside cells" % cell.name)
		for other: StringName in beside:
			_assert_weeps(cell.name, other, beside[other])
	assert_gt(trunks, 0, "her No. 1 hatch is trunked")


func test_the_end_wall_two_of_her_houses_share_weeps() -> void:
	var beside := _beside(&"officers_house")
	assert_true(
		beside.has(&"staircase_house"), "the officers' house stands against the staircase's"
	)
	if beside.has(&"staircase_house"):
		_assert_weeps(&"staircase_house", &"officers_house", beside[&"staircase_house"])
