extends GutTest
## §5b.4 layer 1: Hydrostatics against closed forms and counted points — a box cut by
## the sea at any attitude, a box barge afloat, a section upside down.

const SEED := 24
## Random attitudes the box is cut at, and the points thrown at it per attitude.
const ATTITUDES := 6
const SAMPLES := 60000
## How many standard errors a counted volume or centre may stand from the cut's.
const ERRORS := 4.0
const EXACT := 1e-9
const SEA_DENSITY := 1025.0


## A section of [param length] at [param x] with [param outline], (z, y) pairs.
func _section(x: float, length: float, outline: Array) -> HullSection:
	var section := HullSection.new()
	section.x = x
	section.length = length
	for point: Vector2 in outline:
		section.outline.append(point)
	return section


## A box barge: [param count] sections of a rectangle [param half_beam] either side of
## the centreline from [param keel] to [param deck], [param length] long in all,
## centred on x = 0.
func _barge(
	count: int, length: float, half_beam: float, keel: float, deck: float
) -> Array[HullSection]:
	var sections: Array[HullSection] = []
	var rectangle := [
		Vector2(-half_beam, keel),
		Vector2(half_beam, keel),
		Vector2(half_beam, deck),
		Vector2(-half_beam, deck),
	]
	for index in count:
		var x := -length * 0.5 + length * (index + 0.5) / count
		sections.append(_section(x, length / count, rectangle))
	return sections


func test_box_cut_matches_monte_carlo_at_random_attitudes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var low := Vector3(2.0, -1.0, -0.5)
	var high := Vector3(6.0, 1.5, 3.0)
	var box_volume := (high.x - low.x) * (high.y - low.y) * (high.z - low.z)
	for attitude in ATTITUDES:
		var up := Vector3.ZERO
		while up.length() < 0.2:
			up = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var sea := Hydrostatics.Sea.new(up.x, up.y, up.z, 0.0)
		var lowest := INF
		var highest := -INF
		for corner in 8:
			var at := Vector3(
				high.x if corner & 1 else low.x,
				high.y if corner & 2 else low.y,
				high.z if corner & 4 else low.z
			)
			var height := -sea.depth(at.x, at.y, at.z)
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
		sea.height = lerpf(lowest, highest, rng.randf_range(0.2, 0.8))
		var cut := Hydrostatics.cut_box(low.x, high.x, low.y, high.y, low.z, high.z, sea)
		var under := 0
		var sums := PackedFloat64Array([0.0, 0.0, 0.0])
		var squares := PackedFloat64Array([0.0, 0.0, 0.0])
		for _sample in SAMPLES:
			var point := PackedFloat64Array(
				[
					rng.randf_range(low.x, high.x),
					rng.randf_range(low.y, high.y),
					rng.randf_range(low.z, high.z),
				]
			)
			if sea.depth(point[0], point[1], point[2]) > 0.0:
				under += 1
				for axis in 3:
					sums[axis] += point[axis]
					squares[axis] += point[axis] * point[axis]
		var share := float(under) / SAMPLES
		var share_error := sqrt(share * (1.0 - share) / SAMPLES)
		var what := "attitude %d, up %s" % [attitude, up.normalized()]
		assert_almost_eq(cut.volume / box_volume, share, ERRORS * share_error, what + ": volume")
		var centre := PackedFloat64Array([cut.x, cut.y, cut.z])
		for axis in 3:
			var mean := sums[axis] / under
			var error := sqrt(maxf(squares[axis] / under - mean * mean, 0.0) / under)
			assert_almost_eq(centre[axis], mean, ERRORS * error, what + ": centre")
		# The waterplane is how fast the volume grows as the sea rises, and lies on it.
		var step := 1e-5
		var above := Hydrostatics.cut_box(
			low.x, high.x, low.y, high.y, low.z, high.z, sea.at_height(sea.height + step)
		)
		var below := Hydrostatics.cut_box(
			low.x, high.x, low.y, high.y, low.z, high.z, sea.at_height(sea.height - step)
		)
		var growth := (above.volume - below.volume) / (2.0 * step)
		assert_almost_eq(cut.waterplane, growth, 1e-4 * growth, what + ": waterplane")
		assert_almost_eq(sea.depth(cut.plane_x, cut.plane_y, cut.plane_z), 0.0, 1e-9, what)


func test_box_cut_is_exact_upright() -> void:
	var cut := Hydrostatics.cut_box(0.0, 4.0, -2.0, 1.0, -1.0, 2.0, Hydrostatics.level(0.25))
	assert_almost_eq(cut.volume, 4.0 * 2.25 * 3.0, EXACT)
	assert_almost_eq(cut.x, 2.0, EXACT)
	assert_almost_eq(cut.y, -0.875, EXACT)
	assert_almost_eq(cut.z, 0.5, EXACT)
	assert_almost_eq(cut.waterplane, 12.0, EXACT)
	assert_almost_eq(cut.plane_x, 2.0, EXACT)
	assert_almost_eq(cut.plane_y, 0.25, EXACT)
	assert_almost_eq(cut.plane_z, 0.5, EXACT)
	var drowned := Hydrostatics.cut_box(0.0, 4.0, -2.0, 1.0, -1.0, 2.0, Hydrostatics.level(5.0))
	assert_almost_eq(drowned.volume, 36.0, EXACT, "wholly under")
	assert_eq(drowned.waterplane, 0.0, "no waterplane wholly under")
	var dry := Hydrostatics.cut_box(0.0, 4.0, -2.0, 1.0, -1.0, 2.0, Hydrostatics.level(-3.0))
	assert_eq(dry.volume, 0.0, "nothing under wholly above")


func test_box_barge_floats_at_its_draught() -> void:
	var sections := _barge(10, 20.0, 3.0, -2.0, 1.0)
	var draught := 1.2
	var volume := 20.0 * 6.0 * draught
	var level := Hydrostatics.float_at(sections, Hydrostatics.level(0.0), volume)
	assert_almost_eq(level.height, -2.0 + draught, EXACT, "afloat at her draught")
	var weight := PackedFloat64Array([0.0, -1.0, 0.0])
	var rest := Hydrostatics.rest(sections, volume, weight)
	assert_almost_eq(rest.trim(), 0.0, EXACT, "no trim")
	assert_almost_eq(rest.list(), 0.0, EXACT, "no list")
	assert_almost_eq(rest.height, -2.0 + draught, EXACT, "at rest at her draught")
	# A box's GM: KB = draught / 2, BM = beam² / (12 draught); listed a little, the
	# wall-sided lever adds BM / 2 · tan² of the list.
	var gm := (draught * 0.5) + 36.0 / (12.0 * draught) - (-1.0 + 2.0)
	var heel := Hydrostatics.HEEL
	var expected := gm + 36.0 / (12.0 * draught) * 0.5 * heel * heel
	var measured := Hydrostatics.metacentric_height(sections, volume, weight, rest)
	assert_almost_eq(measured, expected, 1e-6, "GM of a box barge")
	# Weight off the centreline: she lists toward it until her lift stands under it.
	weight[2] = 0.1
	var listed := Hydrostatics.rest(sections, volume, weight)
	assert_gt(listed.list(), 0.0, "weight to starboard lists her to starboard")
	var cut := Hydrostatics.cut_hull(sections, listed)
	var lever := Hydrostatics.lever(cut, weight, listed)
	assert_almost_eq(lever[1], 0.0, 1e-8, "her lift under her weight")
	assert_almost_eq(cut.volume, volume, 1e-6, "displacing her weight")


func test_section_cut_works_upside_down() -> void:
	var house := [
		Vector2(-2.0, -2.0),
		Vector2(2.0, -2.0),
		Vector2(2.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(-1.0, 1.0),
		Vector2(-1.0, 0.0),
		Vector2(-2.0, 0.0),
	]
	var section := _section(3.0, 2.0, house)
	# Upside down, the world's up her down: the sea takes what stands above y = 0.5
	# on her — the top of the deckhouse, which now hangs lowest.
	var inverted := Hydrostatics.Sea.new(0.0, -1.0, 0.0, -0.5)
	var cut := Hydrostatics.cut_section(section, inverted)
	assert_almost_eq(cut.volume, 1.0 * 2.0, EXACT, "the house's top half under")
	assert_almost_eq(cut.x, 3.0, EXACT)
	assert_almost_eq(cut.y, 0.75, EXACT)
	assert_almost_eq(cut.z, 0.0, EXACT)
	assert_almost_eq(cut.waterplane, 2.0 * 2.0, EXACT, "the house's breadth, her length")
	assert_almost_eq(cut.plane_y, 0.5, EXACT)
	# Deeper, the sea takes the hull's deck and the house: two shapes, one cut.
	var deeper := Hydrostatics.cut_section(section, inverted.at_height(0.5))
	assert_almost_eq(deeper.volume, (4.0 * 0.5 + 2.0 * 1.0) * 2.0, EXACT, "deck and house under")
	# Half her area on the deck's band at y -0.25, half in the house at 0.5.
	assert_almost_eq(deeper.y, 0.125, EXACT)
	assert_almost_eq(deeper.waterplane, 4.0 * 2.0, EXACT)
	# On her side, starboard up: the sea takes her port side to the centreline.
	var on_side := Hydrostatics.cut_section(section, Hydrostatics.Sea.new(0.0, 0.0, 1.0, 0.0))
	assert_almost_eq(on_side.volume, (2.0 * 2.0 + 1.0) * 2.0, EXACT, "her port half")
	assert_lt(on_side.z, 0.0, "to port")


func test_tilted_box_water_matches_the_cut_at_random_attitudes() -> void:
	# A cell's water (TiltedBox) at random attitudes, and near level where its spreads
	# grow narrow: the volume under a surface and its centre as the box cut by that
	# surface has them, and the height for that volume back where it was.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var low := Vector3(4.0, -2.5, -3.75)
	var high := Vector3(15.0, 0.0, 3.75)
	var capacity := 11.0 * 2.5 * 7.5
	var box := TiltedBox.new(low, high, capacity, 1.0)
	for attitude in 300:
		var spread: float = [1.0, 0.2, 1e-4, 1e-7][attitude % 4]
		var up := Vector3(rng.randf_range(-spread, spread), 1.0, rng.randf_range(-spread, spread))
		if attitude % 4 == 0:
			up = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var length := sqrt(float(up.x) * up.x + float(up.y) * up.y + float(up.z) * up.z)
		var ux := float(up.x) / length
		var uy := float(up.y) / length
		var uz := float(up.z) / length
		box.turn(ux, uy, uz)
		var height := rng.randf_range(box.bottom(), box.top())
		var cut := Hydrostatics.cut_box(
			low.x, high.x, low.y, high.y, low.z, high.z, Hydrostatics.Sea.new(ux, uy, uz, height)
		)
		var water := box.volume(height)
		assert_almost_eq(water, cut.volume, capacity * 1e-9, "volume, attitude %d" % attitude)
		assert_almost_eq(box.height(water), height, 1e-7, "height back, attitude %d" % attitude)
		if cut.volume > capacity * 1e-3:
			var centre := box.centre(height)
			var off := Vector3(centre[0] - cut.x, centre[1] - cut.y, centre[2] - cut.z)
			assert_lt(off.length(), 1e-6, "centre, attitude %d" % attitude)
