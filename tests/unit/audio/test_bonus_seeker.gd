extends GutTest
## The finder's ping (BonusSeeker): which bonus aboard the listening seat seeks, from a
## snapshot and the layout's bonus spots alone, and how fast and high it pings for how
## near that bonus lies.

const SEEK := AudioCue.Kind.SEEK


## A layout whose bonus spots lie at [param points].
func _layout(points: Array[Vector3]) -> ShipLayout:
	var layout := ShipLayout.new()
	for point in points:
		var spot := ShipBonusSpot.new()
		spot.point = point
		layout.bonus_spots.append(spot)
	return layout


## A snapshot of seats standing at [param feet], the first [param out] of them out, with a
## bonus lying at each spot of [param spots].
func _snapshot(feet: Array[Vector3], spots: Array[int], out := 0) -> Dictionary:
	var seats: Array = []
	for index in feet.size():
		seats.append({"pos": feet[index], "out": index < out})
	var bonuses: Array = []
	for spot in spots:
		bonuses.append({"planned": 0, "kind": 0, "spot": spot})
	return {"tick": 0, "seats": seats, "bonuses": bonuses}


## Of several bonuses aboard, the one nearest the listener's feet in a straight line, its
## index among the snapshot's bonuses — whatever order they lie in.
func test_seeks_the_nearest_bonus_aboard() -> void:
	var layout := _layout(
		[Vector3(20.0, 0.0, 0.0), Vector3(-6.0, -3.0, 0.0), Vector3(0.0, 0.0, 9.0)]
	)
	var snapshot := _snapshot([Vector3.ZERO, Vector3(19.0, 0.0, 0.0)], [0, 1, 2])
	assert_eq(BonusSeeker.sought(snapshot, layout, 0), 1, "the one 6.7 m off")
	assert_eq(BonusSeeker.sought(snapshot, layout, 1), 0, "each seat its own nearest")
	snapshot = _snapshot([Vector3.ZERO], [2, 0])
	assert_eq(BonusSeeker.sought(snapshot, layout, 0), 0, "by its place in the snapshot")


## Nothing sought past the range, with no bonus aboard, through no seat (the observer
## camera) or through a seat that is out.
func test_seeks_none_out_of_range_or_with_none_to_seek() -> void:
	var layout := _layout([Vector3(BonusSeeker.RANGE + 1.0, 0.0, 0.0), Vector3.ZERO])
	assert_eq(BonusSeeker.sought(_snapshot([Vector3.ZERO], [0]), layout, 0), -1, "past range")
	assert_eq(BonusSeeker.sought(_snapshot([Vector3.ZERO], []), layout, 0), -1, "none aboard")
	var near := _snapshot([Vector3.ZERO, Vector3.ZERO], [1])
	assert_eq(BonusSeeker.sought(near, layout, 1), 0, "a seat beside it seeks it")
	assert_eq(BonusSeeker.sought(near, layout, -1), -1, "no seat listening")
	var out := _snapshot([Vector3.ZERO, Vector3.ZERO], [1], 1)
	assert_eq(BonusSeeker.sought(out, layout, 0), -1, "the seat is out")


## Nearer, the pings come quicker and higher, never the other way: slowest and lowest at
## the range's edge, quickest and highest within CLOSE; and loud enough that the far edge
## is still heard.
func test_pings_quicker_and_higher_the_nearer() -> void:
	assert_almost_eq(BonusSeeker.interval(BonusSeeker.RANGE), BonusSeeker.SLOWEST, 1e-6)
	assert_almost_eq(BonusSeeker.pitch(BonusSeeker.RANGE), BonusSeeker.LOWEST, 1e-6)
	assert_almost_eq(BonusSeeker.interval(BonusSeeker.CLOSE), BonusSeeker.QUICKEST, 1e-6)
	assert_almost_eq(BonusSeeker.pitch(BonusSeeker.CLOSE), BonusSeeker.HIGHEST, 1e-6)
	assert_almost_eq(BonusSeeker.interval(0.0), BonusSeeker.QUICKEST, 1e-6, "at its spot")
	assert_lt(BonusSeeker.QUICKEST, BonusSeeker.SLOWEST)
	assert_gt(BonusSeeker.HIGHEST, BonusSeeker.LOWEST)
	var interval := BonusSeeker.interval(BonusSeeker.RANGE)
	var pitch := BonusSeeker.pitch(BonusSeeker.RANGE)
	for step in range(1, 31):
		var distance := BonusSeeker.RANGE * (1.0 - step / 30.0)
		assert_true(BonusSeeker.interval(distance) <= interval, "quicker at %.1f m" % distance)
		assert_true(BonusSeeker.pitch(distance) >= pitch, "higher at %.1f m" % distance)
		interval = BonusSeeker.interval(distance)
		pitch = BonusSeeker.pitch(distance)
	assert_gte(SoundBank.far(SEEK), BonusSeeker.RANGE, "heard the whole range")
	assert_eq(SoundBank.files(SEEK), ["bonus/seek.wav"])


## The pings fall an interval apart; nearing, the wait left shrinks to the new interval at
## once rather than running out the old one; and a train lost and found again, or turned to
## a nearer bonus, carries on its wait rather than bursting.
func test_pings_an_interval_apart_without_bursting() -> void:
	var seeker := BonusSeeker.new()
	var far := BonusSeeker.RANGE
	assert_true(seeker.ping(0.01, far), "the first at once")
	var frames := 0
	while not seeker.ping(0.01, far):
		frames += 1
	assert_almost_eq(frames * 0.01, BonusSeeker.SLOWEST, 0.02, "an interval on")
	assert_false(seeker.ping(0.1, INF), "none while nothing is sought")
	assert_false(seeker.ping(0.1, BonusSeeker.CLOSE), "found again, the wait carries on")
	assert_true(seeker.ping(0.1, BonusSeeker.CLOSE), "the wait cut to the close interval")
	assert_false(seeker.ping(0.1, BonusSeeker.CLOSE), "and one at a time")
	assert_false(seeker.ping(5.0, INF))
	assert_true(seeker.ping(10.0, far), "a long frame pings once")
	assert_false(seeker.ping(0.01, far), "not again the next frame")
