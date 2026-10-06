extends GutTest
## §5b.4 layer 1: the ship's motion against closed forms on box barges (BoxBarge) — a
## bow room flooded trims her as the wall-sided equilibrium says, a slack tank costs her
## the GM its free surface's formula says, her righting arm on the wall-sided formula,
## negative stability falls to the loll angle on the side it was seeded toward — and the
## rotation's two promises: it stays square through a full roll, and a capsize keeps its
## history, never snapping back.

const SEED := 27
## Draughts within 2% (the plan's band); angles and lever arms within these.
const DRAUGHT_SHARE := 0.02
const LEVER := 1e-3
const LOLL_DEG := 0.5
## Long enough for any barge here to come to rest, in physics seconds.
const SETTLE := 3600.0


func _sea() -> SeaPhysics:
	return SeaPhysics.load_default()


## [param barge] stepped from [param state] as the bake steps her until she lies still
## or SETTLE has passed, every state kept in [param kept] when it is given.
func _settled(stepper: SinkStepper, state: FloodState, kept: Array[FloodState] = []) -> FloodState:
	while state.seconds < SETTLE:
		state = stepper.advance(state)
		kept.append(state)
		var still := (
			absf(state.heave_rate) < SinkBake.STILL_RISE
			and absf(state.pitch_rate) < SinkBake.STILL_TURN
			and absf(state.roll_rate) < SinkBake.STILL_TURN
		)
		if still and state.seconds > 60.0:
			break
	return state


func test_bow_room_flooded_trims_the_barge_to_7_41_and_3_70_m() -> void:
	# 20 m long, 12 m wide, 10 m deep, floating 5 m deep with her weight 4 m over her
	# keel; the 1.5 m room at her bow holed at the keel, a hatch on deck letting its air
	# out. The wall-sided equilibrium —
	# the lift of what stays dry under a trimmed waterline straight over her weight —
	# puts her bow 7.39 m and her stern 3.70 m deep (est. dimensions: the plan names the
	# answer, not the barge).
	var barge := BoxBarge.new(20.0, 12.0, 10.0, 5.0, 4.0)
	barge.section_length = 0.5
	barge.cell(&"bow_room", Vector3(8.5, -5.0, -6.0), Vector3(10.0, 5.0, 6.0))
	barge.hole(&"bow_room", Vector3(9.25, -5.0, 0.0), 1.0, true)
	barge.vent(&"bow_room", Vector3(9.25, 5.0, 0.0), 1.0)
	var structure := barge.structure()
	var stepper := SinkStepper.new(structure, HitDamage.new(), _sea())
	var timeline := SinkTimeline.bake(stepper, _sea(), SETTLE)
	assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "she floats once the water stops")
	var last := timeline.count() - 1
	var rotation := timeline.rotations.slice(last * 9, last * 9 + 9)
	var sea := timeline.seas[last]
	var bow := BoxBarge.draught_at(rotation, sea, 10.0, barge.keel())
	var stern := BoxBarge.draught_at(rotation, sea, -10.0, barge.keel())
	assert_almost_eq(bow, 7.41, 7.41 * DRAUGHT_SHARE, "her bow 7.41 m deep")
	assert_almost_eq(stern, 3.70, 3.70 * DRAUGHT_SHARE, "her stern 3.70 m deep")
	assert_almost_eq(BoxBarge.heel_deg(rotation), 0.0, 1e-6, "and no list")


func test_free_surface_loss_matches_its_formula() -> void:
	# Two barges carrying the same 160 m³ of water 2 m deep in a tank 10 by 8 m: in one
	# the tank is 4 m tall and the water's surface is free, in the other it is 2 m tall
	# and full. Her GM differs by the surface's moment over her displacement:
	# l b³ / 12 / V (Rawson & Tupper).
	var gms := PackedFloat64Array()
	for tall: float in [4.0, 2.0]:
		var barge := BoxBarge.new(40.0, 12.0, 10.0, 4.0, 3.0)
		barge.section_length = 2.0
		barge.cell(&"tank", Vector3(-5.0, -3.5, -4.0), Vector3(5.0, -3.5 + tall, 4.0))
		var stepper := SinkStepper.new(barge.structure(), HitDamage.new(), _sea())
		var state := stepper.start()
		state.water[0] = 160.0
		state.heads[0] = stepper.head(0, 160.0)
		state = _settled(stepper, state)
		var displaced := 40.0 * 12.0 * 4.0 + 160.0
		gms.append(state.roll_stiffness / (_sea().gravity * displaced))
	var expected := 10.0 * 8.0 * 8.0 * 8.0 / 12.0 / (40.0 * 12.0 * 4.0 + 160.0)
	assert_almost_eq(gms[1] - gms[0], expected, expected * 0.01, "the loss: l b³ / 12 / V")


func test_wall_sided_righting_arm() -> void:
	# 40 by 10 by 6 m, 3 m deep, her weight 3.78 m over her keel: GM 0.5 m, BM 2.78 m.
	# Wall-sided, until her deck edge dips at 31°: GZ = sin φ (GM + BM tan² φ / 2).
	var barge := BoxBarge.new(40.0, 10.0, 6.0, 3.0, 3.78)
	var structure := barge.structure()
	var sea := _sea()
	var motion := ShipMotion.new(structure, sea, 0.0)
	var own := 40.0 * 10.0 * 3.0
	var centre := motion.centre()
	var bm := 10.0 * 10.0 / (12.0 * 3.0)
	var gm := 1.5 + bm - 3.78
	for degrees: float in [5.0, 10.0, 15.0, 20.0, 25.0]:
		var rotation := Attitude.rolled(Attitude.level(), deg_to_rad(degrees))
		# The sea where she displaces her own weight at this list.
		var low := -10.0
		var high := 10.0
		for _step in 80:
			var middle := (low + high) * 0.5
			if motion.lift_under(rotation, middle)[ShipMotion.Lift.VOLUME] < own:
				low = middle
			else:
				high = middle
		var lift := motion.lift_under(rotation, (low + high) * 0.5)
		var arm := Attitude.abeam(
			rotation,
			lift[ShipMotion.Lift.X] - centre[0],
			lift[ShipMotion.Lift.Y] - centre[1],
			lift[ShipMotion.Lift.Z] - centre[2]
		)
		var phi := deg_to_rad(degrees)
		var expected := sin(phi) * (gm + bm * tan(phi) * tan(phi) * 0.5)
		assert_almost_eq(arm, expected, LEVER, "GZ at %s°" % degrees)


func test_negative_stability_falls_to_the_loll_angle_on_the_seeded_side() -> void:
	# 40 by 10 by 6 m, 3 m deep, her weight 4.5 m over her keel: GM -0.22 m. Upright she
	# is unstable; nudged either way she lolls to tan φ = √(-2 GM / BM), 21.7°, on that
	# side — the side a seeded stream picks first, then the other.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var bm := 10.0 * 10.0 / (12.0 * 3.0)
	var gm := 1.5 + bm - 4.5
	var loll := rad_to_deg(atan(sqrt(-2.0 * gm / bm)))
	var first := 1.0 if rng.randf() < 0.5 else -1.0
	for side: float in [first, -first]:
		var barge := BoxBarge.new(40.0, 10.0, 6.0, 3.0, 4.5)
		barge.section_length = 2.0
		var stepper := SinkStepper.new(barge.structure(), HitDamage.new(), _sea())
		var state := stepper.start()
		state.rotation = Attitude.rolled(state.rotation, side * 1e-3)
		state = _settled(stepper, state)
		var heel := BoxBarge.heel_deg(state.rotation)
		assert_almost_eq(
			heel, side * loll, LOLL_DEG, "she lolls to %.1f° to the seeded side" % loll
		)
		assert_gt(state.roll_stiffness, 0.0, "stable there")


func test_rotation_stays_square_through_a_full_roll() -> void:
	# Rolled right round in steps of a third of a degree with a pitch along the way, the
	# rotation is square to 10⁻¹² at every step and back where it started.
	var rotation := Attitude.level()
	var steps := 1080
	var worst := 0.0
	for step in steps:
		rotation = Attitude.squared(Attitude.rolled(rotation, TAU / steps))
		if step < steps / 2:
			rotation = Attitude.squared(Attitude.pitched(rotation, 0.001))
		else:
			rotation = Attitude.squared(Attitude.pitched(rotation, -0.001))
		worst = maxf(worst, Attitude.squareness(rotation))
	assert_lt(worst, 1e-12, "square at every step")
	var level := Attitude.level()
	for index in 9:
		assert_almost_eq(rotation[index], level[index], 1e-9, "back upright, entry %d" % index)
	assert_eq(rotation[6], 0.0, "her bow never swings off its heading")
	# Each turn leaves her a hair off square, as rounding does; squaring brings her back:
	# skewed far past what rounding ever leaves, she is square again in one call.
	var skewed := Attitude.rolled(Attitude.pitched(Attitude.level(), 0.2), 0.3)
	skewed[1] += 1e-6
	skewed[4] *= 1.0 + 1e-6
	skewed[8] -= 1e-6
	assert_gt(Attitude.squareness(skewed), 1e-7, "skewed off square")
	assert_lt(Attitude.squareness(Attitude.squared(skewed)), 1e-15, "squared back")


func test_a_capsize_keeps_its_history() -> void:
	# 40 by 10 by 6 m, 3 m deep, her weight 6 m over her keel: past her deck edge she
	# has nothing left to right her and turns over. At a long step as at a short one the
	# roll carries on from where it was — a few degrees a step at most, never a jump to
	# where a balance solved afresh would put her — and once past her beam ends she never
	# comes back toward upright: she comes to rest far over, alike at both steps.
	var rests := PackedFloat64Array()
	for seconds: float in [0.05, 10.0]:
		var sea: SeaPhysics = _sea().duplicate()
		sea.step_max = seconds
		var barge := BoxBarge.new(40.0, 10.0, 6.0, 3.0, 6.0)
		barge.section_length = 2.0
		var stepper := SinkStepper.new(barge.structure(), HitDamage.new(), sea)
		var state := stepper.start()
		state.rotation = Attitude.rolled(state.rotation, 1e-3)
		var kept: Array[FloodState] = []
		state = _settled(stepper, state, kept)
		var turned := 0.0
		var biggest := 0.0
		var past := false
		var least_past := INF
		var since := 0.0
		for kept_state: FloodState in kept:
			var rolled := kept_state.roll_rate * (kept_state.seconds - since)
			since = kept_state.seconds
			turned += rolled
			biggest = maxf(biggest, absf(rolled))
			past = past or turned > PI * 0.5
			if past:
				least_past = minf(least_past, turned)
		assert_lte(rad_to_deg(biggest), 5.0, "step %s: no jump" % seconds)
		assert_gt(rad_to_deg(least_past), 90.0, "step %s: never back past her beam ends" % seconds)
		rests.append(absf(BoxBarge.heel_deg(state.rotation)))
	assert_gt(rests[0], 150.0, "at rest far over")
	assert_almost_eq(rests[0], rests[1], 1.0, "alike at a long step")
