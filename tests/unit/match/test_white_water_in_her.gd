extends GutTest
## White water from the sinking stays out of her dark rooms, or takes their light
## there: no streak of it glows white in a room her lamps no longer light.

const RunMatch := preload("res://tools/run_match.gd")

const SPRAY := FxCue.Kind.SPRAY
## How far in from her side a sheet of spray thrown up it may reach, in metres.
const SHEET_DEPTH := 0.35


func test_the_sea_breaks_over_her_sides_out_on_the_sea_never_inside_her() -> void:
	# Her shell stands wider than her decks: a sheet outboard of the decks alone lay
	# inside her, flung in over her flooded galley as white streaks in the dark
	# (freighter, seed 1656700529, 6:43).
	var sim := MatchSim.create(RunMatch.default_config(1656700529, 0, &"freighter"))
	var plunge := sim.schedule.plunge_tick()
	var from := ceili(plunge / float(FxPlanner.SWALLOW_TICKS)) * FxPlanner.SWALLOW_TICKS
	var cues := FxProbe.sink(
		FxPlanner.new(sim.config, sim.surfaces, sim.schedule),
		sim,
		from,
		sim.schedule.end_tick(),
		FxPlanner.SWALLOW_TICKS
	)
	var sheets := _of(cues, SPRAY).filter(
		func(cue: FxCue) -> bool: return cue.rise == FxPlanner.PLUNGE_RISE
	)
	assert_gt(sheets.size(), 0, "the sea breaking over her sides")
	var inside := 0
	for sheet: FxCue in sheets:
		var pose := sim.schedule.pose_at(sheet.tick)
		for share: float in [0.0, 0.5, 1.0]:
			var drawn := pose.transform * sheet.position.lerp(sheet.end, share)
			drawn.y = 0.0
			var ship_point := pose.transform.affine_inverse() * drawn
			# Its own depth's worth in from her side is the sheet, not her inside.
			ship_point.z += signf(ship_point.z) * SHEET_DEPTH
			if pose.cell_at(ship_point) != CellMap.NONE:
				inside += 1
	assert_eq(inside, 0, "none of %d sheets inside her" % sheets.size())


func test_white_water_bursting_into_a_room_takes_its_light() -> void:
	# A door or porthole bursting into her flooded galley, her lamps out, threw white
	# water as bright as on deck: glowing streaks in the dark (freighter, 6:41).
	var sim := MatchSim.create(RunMatch.default_config(1656700529, 0, &"freighter"))
	var structure := sim.config.ship.structure
	var inner: ShipOpening = null
	for opening: ShipOpening in sim.schedule.failing():
		if opening.joins.all(
			func(cell: StringName) -> bool: return structure.cell_named(cell) != -1
		):
			inner = opening
			break
	assert_not_null(inner, "a door between two of her rooms gives way")
	var tick := sim.schedule.plunge_tick()
	var pose := sim.schedule.pose_at(tick)
	assert_false(pose.lit.is_empty(), "her rooms are lit by her power")
	var kept := pose.lit
	var shown := PackedFloat32Array()
	for power: int in [ShipPower.Power.DARK, ShipPower.Power.EMERGENCY, ShipPower.Power.MAIN]:
		var lit := kept.duplicate()
		lit.fill(power)
		pose.lit = lit
		var gave := {"kind": SimEvent.Kind.OPENING_GAVE_WAY, "cell": inner.name}
		var cues: Array[FxCue] = []
		FailureFx.new(structure, sim.schedule).plan(
			{"tick": tick - 1}, {"tick": tick, "events": [gave]}, pose, cues
		)
		shown.append(_of(cues, SPRAY)[0].lit)
	pose.lit = kept
	assert_lt(shown[0], shown[1], "darker in a room on emergency light than on none")
	assert_lt(shown[1], shown[2], "darker on emergency light than under her lamps")
	assert_lt(shown[2], 1.0, "dimmer under her lamps than out on deck")
	assert_lte(shown[0], 0.15, "near black in a dark room")


## The cues of [param kind] among [param cues].
func _of(cues: Array[FxCue], kind: FxCue.Kind) -> Array[FxCue]:
	return FxProbe.of(cues, kind)
