extends GutTest
## §5b.4 layer 1: her hull as a girder (HullGirder) against the textbook's closed forms —
## a box whose weight lies along it as its lift does carries no bending; a load in the
## middle of a girder held up evenly bends it by PL/8 there; a load at one end, held up
## by a lift that grows toward it as a trimmed box's does, bends it by 4PL/27 a third
## of the way along from it — two-thirds of the way from the other end (Rawson & Tupper);
## and what no lift meets is taken off along her, so her ends carry none.

## A girder cut into this many stations, and the share its moments come within.
const STATIONS := 300
const WITHIN := 0.01


## The ends of [param count] even stations along a girder [param length] long.
func _bounds(length: float, count: int) -> PackedFloat64Array:
	var bounds := PackedFloat64Array()
	for at in count + 1:
		bounds.append(-length * 0.5 + length * at / count)
	return bounds


func test_uniform_box_has_no_bending() -> void:
	# A box barge, her weight spread along her as evenly as her lift, nothing in her:
	# afloat and at rest, every station carries no bending at all.
	var barge := BoxBarge.new(40.0, 10.0, 8.0, 4.0, 3.0)
	barge.section_length = 2.0
	var structure := barge.structure()
	structure.strength = GirderStrength.new()
	structure.strength.hog = 50e6
	structure.strength.sag = 50e6
	var sea := SeaPhysics.load_default()
	var stepper := SinkStepper.new(structure, HitDamage.new(), sea)
	var state := stepper.start()
	assert_almost_eq(state.bending, 0.0, 1e-9, "no bending in her at rest")
	var bake := SinkBake.new(stepper, sea, 60.0)
	bake.run(1 << 62)
	assert_almost_eq(bake.bending(), 0.0, 1e-9, "nor at any state the bake kept")


func test_load_amidships_gives_pl_over_8() -> void:
	# A girder 40 m long held up evenly, P in its middle: PL/8, sagging, at its middle.
	var length := 40.0
	var load := 100.0
	var loads := PackedFloat64Array()
	for station in STATIONS:
		loads.append(-load / STATIONS)
	loads[STATIONS / 2 - 1] += load * 0.5
	loads[STATIONS / 2] += load * 0.5
	var bounds := _bounds(length, STATIONS)
	var moments := HullGirder.moments(bounds, loads)
	var worst := 0
	for at in moments.size():
		if absf(moments[at]) > absf(moments[worst]):
			worst = at
	var expected := load * length / 8.0
	assert_almost_eq(moments[worst], -expected, expected * WITHIN, "PL/8, sagging")
	assert_almost_eq(bounds[worst], 0.0, length / STATIONS, "at her middle")
	assert_almost_eq(moments[0], 0.0, 1e-9, "none at one end")
	assert_almost_eq(moments[STATIONS], 0.0, 1e-9, "nor at the other")


func test_load_at_one_end_gives_4pl_over_27_at_two_thirds() -> void:
	# P at the after end, held up by a lift (P/L)(4 − 6x/L), x from that end — the lift
	# of a box trimmed by it, its force and its moment the load's: 4PL/27, hogging, a third
	# of the way from the loaded end, two-thirds of the way from the other.
	var length := 40.0
	var load := 100.0
	var bounds := _bounds(length, STATIONS)
	var loads := PackedFloat64Array()
	for station in STATIONS:
		var from := (bounds[station] - bounds[0]) / length
		var to := (bounds[station + 1] - bounds[0]) / length
		# The lift on the station: (P/L)(4x − 3x²/L) between its ends, x from the end.
		var lift := load * ((4.0 * to - 3.0 * to * to) - (4.0 * from - 3.0 * from * from))
		loads.append(-lift)
	loads[0] += load
	var moments := HullGirder.moments(bounds, loads)
	var worst := 0
	for at in moments.size():
		if absf(moments[at]) > absf(moments[worst]):
			worst = at
	var expected := 4.0 * load * length / 27.0
	assert_almost_eq(absf(moments[worst]), expected, expected * WITHIN, "4PL/27")
	var from_far_end := bounds[STATIONS] - bounds[worst]
	assert_almost_eq(from_far_end, length * 2.0 / 3.0, length / STATIONS, "two-thirds along")


func test_a_load_no_lift_meets_leaves_her_ends_free() -> void:
	# A load her lift does not meet — she is moving, not at rest — is taken off along her:
	# spread as evenly as her weight it only moves her as one and bends no station; a lone
	# load at her bow leaves neither end carrying any.
	var length := 40.0
	var load := 100.0
	var bounds := _bounds(length, STATIONS)
	var even := PackedFloat64Array()
	for station in STATIONS:
		even.append(load / STATIONS)
	var worst := 0.0
	for moment: float in HullGirder.moments(bounds, even):
		worst = maxf(worst, absf(moment))
	assert_almost_eq(worst, 0.0, load * length * 1e-9, "even, no bending anywhere")
	var at_bow := PackedFloat64Array()
	at_bow.resize(STATIONS)
	at_bow[STATIONS - 1] = load
	var moments := HullGirder.moments(bounds, at_bow)
	assert_almost_eq(moments[0], 0.0, load * length * 1e-9, "none at her stern")
	assert_almost_eq(moments[STATIONS], 0.0, load * length * 1e-9, "nor at her bow")
	assert_gt(absf(moments[STATIONS / 2]), load * length * 0.01, "but bending between")
