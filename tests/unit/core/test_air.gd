extends GutTest
## §5b.4 layer 1: the air in her cells (SinkAir) against closed forms — Boyle's law in a
## closed tank under the sea, a vented one filling to the sea, a pocket's leak by the
## orifice law, an upturned box trapping air against its old floor, and the push of
## squeezed air on the water coming in. Each in a barge so broad the water in her tanks
## barely moves the sea up her, her attitude stage off so she stays as she is set
## (§5b.3: the stages keep a test meaningful).

## The barge: a kilometre square, 40 m deep, floating 20 m deep, so the sea stands at 0.
const BROAD := 1000.0
## The tank: 10 × 10 m, its floor 10 m under the sea and its ceiling 5 m over that.
const FLOOR := -10.0
const CEILING := -5.0
## Its hole to the sea, in its floor.
const HOLE := 0.1


func _sea() -> SeaPhysics:
	var sea: SeaPhysics = SeaPhysics.load_default().duplicate()
	sea.attitude = false
	return sea


## The atmosphere's pressure as metres of sea.
func _atmosphere() -> float:
	var sea := _sea()
	return sea.air_pressure / (sea.sea_density * sea.gravity)


## The broad barge holding one tank from [param low] to [param high], its air leaking
## through [param leak] m², a hole of HOLE m² to the sea in its floor; vented to the sky
## through its ceiling when [param vented].
func _tank(low: Vector3, high: Vector3, leak := 0.0, vented := false) -> SinkStepper:
	var barge := BoxBarge.new(BROAD, BROAD, 40.0, 20.0, 10.0)
	barge.section_length = 100.0
	barge.cell(&"tank", low, high).leak_area = leak
	var middle := (low + high) * 0.5
	barge.hole(&"tank", Vector3(middle.x, low.y, middle.z), HOLE, true)
	if vented:
		barge.vent(&"tank", Vector3(middle.x, high.y, middle.z), 0.01)
	return SinkStepper.new(barge.structure(), HitDamage.new(), _sea())


## The closed tank's water over its floor once it stops: Boyle's law, the air squeezed
## from its 5 m to 5 − h until its pressure is the sea's 10 − h under the surface —
## (5 − h)(H + 10 − h) = 5 H, H the atmosphere's metres of sea.
func _boyle() -> float:
	var h := _atmosphere()
	return ((h + 15.0) - sqrt((h + 15.0) * (h + 15.0) - 200.0)) * 0.5


## [param state] stepped [param seconds] at a time for [param span] seconds more.
func _run(stepper: SinkStepper, state: FloodState, seconds: float, span: float) -> FloodState:
	var until := state.seconds + span
	while state.seconds < until - 1e-9:
		state = stepper.step(state, seconds)
	return state


func test_closed_tank_10_m_down_fills_2_18_m() -> void:
	var closed := _boyle()
	assert_almost_eq(closed, 2.18, 0.005, "the research's worked example")
	for seconds: float in [1.0, 30.0]:
		var stepper := _tank(Vector3(-5.0, FLOOR, -5.0), Vector3(5.0, CEILING, 5.0))
		var state := stepper.start()
		assert_almost_eq(state.air[0], 500.0, 1e-9, "sealed: all its air trapped from the start")
		var risen := 0.0
		while state.seconds < 3600.0:
			state = stepper.step(state, seconds)
			var fill := state.heads[0] - FLOOR
			# Down by no more than the solve's own slip over its floor (SinkStepper).
			var slip := SinkStepper.SURPLUS_TOLERANCE / 100.0
			assert_gte(fill, risen - slip, "never back down at a %s s step (R22)" % seconds)
			risen = fill
		assert_almost_eq(risen, closed, 1e-3, "2.18 m of its 5 m at a %s s step" % seconds)
		var push := stepper.pressures(state)[0] - _atmosphere()
		assert_almost_eq(push, state.sea - state.heads[0], 1e-3, "its air at the sea's pressure")


func test_vented_cell_fills_to_the_sea_level() -> void:
	# The same tank, reaching 5 m out of the sea, its ceiling's vent clear of it.
	var stepper := _tank(Vector3(-5.0, FLOOR, -5.0), Vector3(5.0, 5.0, 5.0), 0.0, true)
	var state := _run(stepper, stepper.start(), 1.0, 3600.0)
	assert_eq(state.air[0], SinkAir.FREE, "its air goes free")
	assert_almost_eq(state.heads[0], state.sea, 1e-3, "to the sea's level")
	assert_eq(stepper.pressures(state)[0], 0.0, "and holds no pocket")


func test_pocket_leaks_at_its_leak_rate() -> void:
	# A 1 000 m³ tank under the sea to its ceiling, leaking 10⁻³ m²: the research's
	# pocket that lasts about 2 h (§5b.1).
	var leak := 1e-3
	var stepper := _tank(Vector3(-5.0, -10.0, -5.0), Vector3(5.0, 0.0, 5.0), leak)
	var state := _run(stepper, stepper.start(), 1.0, 600.0)
	var sea := _sea()
	var h := _atmosphere()
	var push := stepper.pressures(state)[0] - h
	# The orifice law for air: Cd a √(2 Δp / ρ) at its own density, as free air — Δp the
	# pocket's pressure over the sea's at its ceiling, here at the surface.
	var over := push - maxf(state.sea - 0.0, 0.0)
	var law := (
		sea.discharge
		* leak
		* sqrt(2.0 * sea.gravity * over * sea.sea_density / sea.air_density * (h + push) / h)
	)
	var before := state.air[0]
	var after := stepper.step(state, 1.0)
	assert_almost_eq(before - after.air[0], law, law * 1e-6, "the orifice law, a second's leak")
	var gone := state
	while gone.air[0] > sea.pocket_least and gone.seconds < 6.0 * 3600.0:
		gone = stepper.step(gone, 10.0)
	assert_lt(gone.air[0], sea.pocket_least, "it leaks away")
	var hours := gone.seconds / 3600.0
	assert_between(hours, 1.5, 2.5, "in about 2 h: %.2f h" % hours)
	assert_almost_eq(gone.heads[0], 0.0, 0.01, "the water up to its ceiling")


func test_upside_down_box_traps_air_under_its_old_floor() -> void:
	# The same box, its hatch in its ceiling, 5 to 10 m under the sea either way up.
	# Upright, the air goes up through the hatch and the sea fills it; upside down, the
	# hatch is under it and the air stays against its old floor, squeezed as the closed
	# tank's is — read from world heights, with no rule for which way up she is.
	var upright := _box(Vector3(-5.0, -10.0, -5.0), Vector3(5.0, -5.0, 5.0))
	var state := _run(upright, upright.start(), 1.0, 3600.0)
	assert_eq(upright.pressures(state)[0], 0.0, "upright: its air goes up the hatch")
	assert_gt(state.heads[0], -5.0, "and the sea fills it")
	var upturned := _box(Vector3(-5.0, 5.0, -5.0), Vector3(5.0, 10.0, 5.0))
	var turned := upturned.start()
	turned.rotation = PackedFloat64Array([1.0, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, -1.0])
	# The sea meets its hatch the moment it is over: a millisecond, then a second a step.
	turned = _run(upturned, upturned.step(turned, 1e-3), 1.0, 3600.0)
	assert_gte(turned.air[0], 0.0, "upside down: trapped")
	assert_almost_eq(
		turned.heads[0] - -10.0, _boyle(), 2e-3, "against its old floor, as Boyle has it"
	)


func test_trapped_air_slows_the_inflow() -> void:
	# With its water 1 m over its floor, the sea comes into the vented tank by the 9 m
	# head across its hole, and into the closed one by what its squeezed air leaves of
	# it: the orifice law, the pocket's pressure taken off the push.
	var sea := _sea()
	var h := _atmosphere()
	var rates := PackedFloat64Array()
	for vented: bool in [true, false]:
		var top := 5.0 if vented else CEILING
		var stepper := _tank(Vector3(-5.0, FLOOR, -5.0), Vector3(5.0, top, 5.0), 0.0, vented)
		var state := stepper.start()
		while state.heads[0] - FLOOR < 1.0:
			state = stepper.step(state, 0.01)
		var push := 0.0
		if not vented:
			push = stepper.pressures(state)[0] - h
			var squeezed := 5.0 * h / (CEILING - state.heads[0]) - h
			assert_almost_eq(push, squeezed, 1e-9, "Boyle's law: 5 H / (5 − fill) − H")
		var next := stepper.step(state, 0.01)
		var rate := next.moved[0] / 0.01
		var law := (
			sea.discharge * HOLE * sqrt(2.0 * sea.gravity * (state.sea - state.heads[0] - push))
		)
		assert_almost_eq(absf(rate), law, law * 0.01, "vented %s: the orifice law" % vented)
		rates.append(absf(rate))
	assert_lt(rates[1], rates[0] * 0.9, "the trapped air holds the sea back")


## The broad barge holding one box from [param low] to [param high], a hatch of HOLE m²
## to the sky in its ceiling.
func _box(low: Vector3, high: Vector3) -> SinkStepper:
	var barge := BoxBarge.new(BROAD, BROAD, 40.0, 20.0, 10.0)
	barge.section_length = 100.0
	barge.cell(&"box", low, high)
	var middle := (low + high) * 0.5
	barge.vent(&"box", Vector3(middle.x, high.y, middle.z), HOLE)
	return SinkStepper.new(barge.structure(), HitDamage.new(), _sea())
