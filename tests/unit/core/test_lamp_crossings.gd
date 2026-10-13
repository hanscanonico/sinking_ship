extends GutTest
## #112: a cell's lamps are presentation — they short as its water reaches them, and say
## so — and never steer the physics. A barge whose hold has lamps, baked beside the same
## barge whose hold has none, steps through the same states to the same end: only the
## hold's SHORTED differs, placed inside the step whose water passed its lamps. Her
## generator's room keeps its lamps in both, and her generator its thresholds, which the
## bake still lands on — they gate her pumps.

## The hold: its lamps hang the sea's lamp_drop under its ceiling, which stands this far
## over her waterline.
const HOLD_CEILING := 0.5


## A barge holed in her engine room aft and her hold forward, her generator aft, its
## emergency power lighting both for an hour; the hold with lamps — a room in it — or
## none.
func _barge(lit_hold: bool) -> ShipStructure:
	var barge := BoxBarge.new(40.0, 10.0, 8.0, 3.0, 3.0)
	barge.section_length = 2.0
	var engine := barge.cell(&"engine_room", Vector3(-15.0, -3.0, -5.0), Vector3(-5.0, 1.0, 5.0))
	var engine_rooms: Array[StringName] = [&"engine room"]
	engine.rooms = engine_rooms
	var hold := barge.cell(&"hold", Vector3(5.0, -3.0, -5.0), Vector3(15.0, HOLD_CEILING, 5.0))
	if lit_hold:
		var hold_rooms: Array[StringName] = [&"hold"]
		hold.rooms = hold_rooms
	barge.hole(&"engine_room", Vector3(-10.0, -3.0, 0.0), 0.02, true)
	barge.vent(&"engine_room", Vector3(-10.0, 1.0, 0.0), 0.5)
	barge.hole(&"hold", Vector3(10.0, -3.0, 2.0), 0.05, true)
	barge.vent(&"hold", Vector3(10.0, HOLD_CEILING, 0.0), 0.5)
	var generator := ShipFitting.new()
	generator.kind = ShipFitting.Kind.GENERATOR
	generator.name = &"generator"
	generator.cell = &"engine_room"
	generator.base = Vector3(-10.0, -3.0, 2.0)
	generator.drowns_at = 0.5
	generator.list_limit_deg = 25.0
	generator.trim_limit_deg = 12.0
	generator.recovers_deg = 3.0
	generator.emergency_minutes = 60.0
	var lit: Array[StringName] = [&"engine_room", &"hold"]
	generator.emergency_cells = lit
	barge.fittings.append(generator)
	return barge.structure()


func _baked(structure: ShipStructure, sea: SeaPhysics) -> SinkBake:
	var bake := SinkBake.new(SinkStepper.new(structure, HitDamage.new(), sea), sea, 3600.0)
	bake.run(1 << 62)
	return bake


## [param bake]'s events but the SHORTED ones naming [param cell], as text.
func _others(bake: SinkBake, cell: StringName) -> PackedStringArray:
	var found := PackedStringArray()
	for event: SinkTimeline.Event in bake.events():
		if event.kind == SinkTimeline.Kind.SHORTED and event.name == cell:
			continue
		found.append("%s %s %s %s" % [event.seconds, event.kind, event.name, event.piece])
	return found


func _shorted_at(bake: SinkBake, cell: StringName) -> float:
	for event: SinkTimeline.Event in bake.events():
		if event.kind == SinkTimeline.Kind.SHORTED and event.name == cell:
			return event.seconds
	return -1.0


func test_a_lamp_never_changes_the_bake() -> void:
	var sea := SeaPhysics.load_default()
	var dark := _baked(_barge(false), sea)
	var lit := _baked(_barge(true), sea)
	var shorted := _shorted_at(lit, &"hold")
	assert_gt(shorted, 0.0, "the hold's water reaches its lamps")
	assert_eq(_shorted_at(dark, &"hold"), -1.0, "a hold without lamps never shorts")
	assert_gt(_shorted_at(lit, &"engine_room"), 0.0, "the engine room's lamps short in the lit one")
	assert_true(lit.times() == dark.times(), "the same steps")
	assert_true(lit.rotations() == dark.rotations(), "the same attitudes")
	assert_true(lit.seas() == dark.seas(), "the same sea up her")
	assert_true(lit.waters() == dark.waters(), "the same water in every cell")
	assert_true(lit.heads() == dark.heads(), "the same heads in every cell")
	assert_true(lit.end() == dark.end(), "the same end")
	assert_true(lit.gone_at() == dark.gone_at(), "gone at the same second")
	assert_true(_others(lit, &"hold") == _others(dark, &"hold"), "every other event alike")


func test_a_lamp_shorts_inside_the_step_that_reached_it() -> void:
	# The hold's lamps stand lamp_drop under its ceiling's middle: the step before the
	# event stands under them, the step after at or past them.
	var sea := SeaPhysics.load_default()
	var structure := _barge(true)
	var bake := _baked(structure, sea)
	var shorted := _shorted_at(bake, &"hold")
	var times := bake.times()
	var after := 1
	while after < times.size() and times[after] < shorted:
		after += 1
	assert_lt(after, times.size(), "a step ends at or after it")
	assert_gt(shorted, times[after - 1], "after the step's start")
	assert_true(shorted <= times[after], "by the step's end")
	var cell := structure.cell_named(&"hold")
	var hold := structure.cells[cell]
	var lamp := Vector3(
		(hold.low.x + hold.high.x) * 0.5,
		hold.high.y - sea.lamp_drop,
		(hold.low.z + hold.high.z) * 0.5
	)
	var gaps := PackedFloat64Array()
	for state: int in [after - 1, after]:
		var up := Attitude.up(bake.rotations().slice(state * 9, state * 9 + 9))
		var height := up[0] * lamp.x + up[1] * lamp.y + up[2] * lamp.z
		gaps.append(height - bake.heads()[state * bake.cells() + cell])
	assert_gt(gaps[0], SinkFailures.REACHED, "under its lamps before the step")
	assert_true(gaps[1] <= SinkFailures.REACHED, "at or past them after it")
	# The timeline keeps the state ending that step — at its microsecond — the hold dark
	# from it.
	var timeline := bake.timeline()
	var frame := timeline.frame_at(times[after] + 1e-6)
	assert_almost_eq(timeline.times[frame], times[after], 1e-6, "the step's end kept")
	assert_eq(timeline.lit(frame, cell), ShipPower.Power.DARK, "the hold dark there")
	assert_ne(timeline.lit(frame - 1, cell), ShipPower.Power.DARK, "and lit before it")
	# Kept for the light it changes, not for its fit: however loose the compaction, the
	# state survives.
	var loose := SinkTimeline.made(bake, 1000.0, 180.0, 1000.0)
	var kept := loose.frame_at(times[after] + 1e-6)
	assert_almost_eq(loose.times[kept], times[after], 1e-6, "kept however loose the fit")
	assert_eq(loose.lit(kept, cell), ShipPower.Power.DARK, "the hold dark there too")
