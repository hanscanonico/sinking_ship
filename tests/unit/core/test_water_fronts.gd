extends GutTest
## A cell's first water runs out from where it comes in (#642, WaterFronts): a gravity
## current whose front goes at dr/dt = Fr^(2/3)·(g·Q/w(r))^(1/3), beyond which its floor
## holds no water — wet_at false, water_height its floor — until a front covers it.

## The hall's door: how wide, and the m³ a second through it.
const DOOR_WIDE := 0.9
const DOOR_FLOW := 0.5
## How long the hall is, and how wide.
const HALL_LONG := 20.0
const HALL_WIDE := 6.0
## The hold under the hole, a square this wide, and the m³ a second pouring into it.
const HOLD_WIDE := 20.0
const HOLE_FLOW := 2.0
const FROUDE := 1.19
const GRAVITY := 9.81
## How deep the hall's water stands while it spreads, in metres.
const FILM := 0.05


static func _cell(cell_name: StringName, low: Vector3, high: Vector3) -> FloodCell:
	var made := FloodCell.new()
	made.name = cell_name
	made.low = low
	made.high = high
	return made


static func _opening(
	opening_name: StringName,
	kind: ShipOpening.Kind,
	joins: Array[StringName],
	centre: Vector3,
	size: Vector3
) -> ShipOpening:
	var made := ShipOpening.new()
	made.name = opening_name
	made.kind = kind
	made.joins = joins
	made.centre = centre
	made.size = size
	return made


## A level hall from x = 0 to HALL_LONG, its door at x = 0 from a lobby aft of it whose
## water stands high.
static func _hall() -> ShipStructure:
	var made := ShipStructure.new()
	var half := HALL_WIDE * 0.5
	var cells: Array[FloodCell] = [
		_cell(&"lobby", Vector3(-5.0, 0.0, -half), Vector3(0.0, 3.0, half)),
		_cell(&"hall", Vector3(0.0, 0.0, -half), Vector3(HALL_LONG, 3.0, half)),
	]
	made.cells = cells
	var openings: Array[ShipOpening] = [
		_opening(
			&"door",
			ShipOpening.Kind.DOOR,
			[&"lobby", &"hall"],
			Vector3(0.0, 1.0, 0.0),
			Vector3(0.0, 2.0, DOOR_WIDE)
		),
	]
	made.openings = openings
	return made


## A square hold under a deck, a hatch in the deck's middle pouring into it.
static func _hold() -> ShipStructure:
	var made := ShipStructure.new()
	var half := HOLD_WIDE * 0.5
	var cells: Array[FloodCell] = [
		_cell(&"hold", Vector3(-half, 0.0, -half), Vector3(half, 3.0, half)),
		_cell(&"deck", Vector3(-half, 3.0, -half), Vector3(half, 6.0, half)),
	]
	made.cells = cells
	var openings: Array[ShipOpening] = [
		_opening(
			&"hatch",
			ShipOpening.Kind.HATCH,
			[&"deck", &"hold"],
			Vector3(0.0, 3.0, 0.0),
			Vector3(1.0, 0.0, 1.0)
		),
	]
	made.openings = openings
	return made


## A timeline of [param seconds] kept a second apart, [param flow] through its one
## passage [param passage] between its two cells, whose heads stand at [param heads].
static func _timeline(
	passage: StringName, flow: float, seconds: int, heads := Vector2(3.0, 0.0)
) -> SinkTimeline:
	var made := SinkTimeline.new()
	made.cells = 2
	made.passages = [passage]
	for second in seconds + 1:
		made.times.append(float(second))
		made.heads.append_array([heads.x, heads.y])
		made.flows.append(flow if second > 0 else 0.0)
	return made


static func _fronts(
	timeline: SinkTimeline, structure: ShipStructure, wet := PackedByteArray([0, 0])
) -> WaterFronts:
	return WaterFronts.new(timeline, structure, [], PackedInt32Array([0, 1]), wet, FROUDE, GRAVITY)


## A level pose of [param structure] [param seconds] after the hit, its cells' water at
## world heights [param levels], its fronts as [param fronts] has them then.
static func _pose(
	structure: ShipStructure, fronts: WaterFronts, seconds: float, levels: PackedFloat64Array
) -> ShipPose:
	var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	pose.cells = CellMap.new(structure)
	pose.levels = levels
	pose.pockets = PackedFloat64Array([0.0, 0.0])
	fronts.pose(pose, seconds)
	return pose


## The first second, to a hundredth, [param fronts]' front [param front] reaches
## [param distance] out: INF for never within [param until].
static func _arrival(fronts: WaterFronts, front: int, distance: float, until: float) -> float:
	var seconds := 0.0
	while seconds <= until:
		if fronts.reach_of(front, seconds) >= distance:
			return seconds
		seconds += 0.01
	return INF


## The integral of dr/dt = Fr^(2/3)·(g·Q/w(r))^(1/3), w = max(b, π·r) at most
## [param widest], from 0 to [param distance]: the seconds it takes.
static func _integral(flow: float, least: float, widest: float, distance: float) -> float:
	var pull := pow(FROUDE, 2.0 / 3.0) * pow(GRAVITY, 1.0 / 3.0)
	var reach := 0.0
	var seconds := 0.0
	var step := 1e-4
	while reach < distance:
		var wide := clampf(PI * reach, least, widest)
		reach += pull * pow(flow / wide, 1.0 / 3.0) * step
		seconds += step
	return seconds


func test_a_door_floods_the_near_floor_first() -> void:
	var structure := _hall()
	var fronts := _fronts(_timeline(&"door", DOOR_FLOW, 60), structure)
	assert_eq(fronts.of_cell(1), Vector2i(0, 1), "the hall has the door's front")
	assert_eq(fronts.of_cell(0).y, 0, "the lobby, upstream, has none")
	var near := Vector3(1.0, 0.0, 0.0)
	var far := Vector3(15.0, 0.0, 0.0)
	var near_at := INF
	var far_at := INF
	for tick in 60 * Ticks.RATE:
		var seconds := Ticks.to_seconds(tick)
		var pose := _pose(structure, fronts, seconds, PackedFloat64Array([3.0, FILM]))
		if is_inf(near_at) and pose.wet_at(near, 0.0, 1):
			near_at = seconds
		if is_inf(far_at) and pose.wet_at(far, 0.0, 1):
			far_at = seconds
		if is_inf(far_at):
			assert_eq(pose.water_height(far), 0.0, "15 m off, before it comes, the floor")
	assert_lt(near_at, far_at, "1 m from the door is wet before 15 m")
	var arrives := _arrival(fronts, 0, 5.0, 60.0)
	var integral := _integral(DOOR_FLOW, DOOR_WIDE, HALL_WIDE, 5.0)
	assert_almost_eq(arrives, integral, 1.0 / Ticks.RATE, "at 5 m when the integral says")


func test_a_hole_spreads_round_itself() -> void:
	var structure := _hold()
	var fronts := _fronts(_timeline(&"hatch", HOLE_FLOW, 120, Vector2(0.0, 3.0)), structure)
	assert_eq(fronts.of_cell(0), Vector2i(0, 1), "the hold under the hatch has its front")
	var corner := WaterFronts.apart(fronts.rect_of(0), HOLD_WIDE * 0.5, HOLD_WIDE * 0.5)
	var quarter := _arrival(fronts, 0, corner * 0.25, 120.0)
	var whole := _arrival(fronts, 0, corner, 120.0)
	assert_lt(quarter, whole, "a quarter of the way out sooner than all of it")
	var pose := _pose(structure, fronts, quarter + 0.05, PackedFloat64Array([FILM, 6.0]))
	for way: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var at := Vector3(way.x, 0.0, way.y) * (0.5 + corner * 0.2)
		assert_true(pose.wet_at(at, 0.0, 0), "wet round it every way: %s" % way)
	assert_false(pose.wet_at(Vector3(9.0, 0.0, 9.0), 0.0, 0), "not yet in the far corner")


func test_a_covered_floor_is_wet_everywhere() -> void:
	var structure := _hall()
	var fronts := _fronts(_timeline(&"door", DOOR_FLOW, 120), structure)
	var done := fronts.span_of(1).y
	assert_true(is_finite(done), "the door's front covers the hall")
	var pose := _pose(structure, fronts, done + 0.01, PackedFloat64Array([3.0, FILM]))
	assert_true(pose.spreading.is_empty(), "no cell spreading once covered")
	for x: float in [0.5, 5.0, 10.0, 19.9]:
		for z: float in [-2.9, 0.0, 2.9]:
			assert_true(pose.wet_at(Vector3(x, 0.0, z), 0.0, 1), "wet at %s, %s" % [x, z])


func test_water_there_at_the_hit_is_everywhere() -> void:
	var structure := _hall()
	var fronts := _fronts(_timeline(&"door", DOOR_FLOW, 60), structure, PackedByteArray([0, 1]))
	assert_eq(fronts.of_cell(1).y, 0, "a cell wet at the hit has no front")
	var pose := _pose(structure, fronts, 0.5, PackedFloat64Array([3.0, FILM]))
	assert_true(pose.wet_at(Vector3(15.0, 0.0, 0.0), 0.0, 1), "wet at once, far from the door")
	assert_almost_eq(pose.water_height(Vector3(15.0, 0.0, 0.0)), FILM, 1e-9, "its level")


func test_same_seed_same_fronts_and_a_restored_match_goes_on_the_same() -> void:
	var config := SimFixtures.config(2, load(SimFixtures.STEAMER_SINKING), 1, SimFixtures.steamer())
	var schedule := config.schedule()
	assert_not_null(schedule.water_fronts(), "her flooding spreads")
	var spreading := -1
	var tick := schedule.hit_tick() + 1
	while tick < schedule.end_tick() and spreading == -1:
		if not schedule.pose_at(tick).spreading.is_empty():
			spreading = tick
		tick += Ticks.RATE
	assert_gt(spreading, 0, "some cell spreading at some tick")
	var again := SimFixtures.config(2, load(SimFixtures.STEAMER_SINKING), 1, SimFixtures.steamer())
	var other := again.schedule().pose_at(spreading)
	assert_eq(other.spreading, schedule.pose_at(spreading).spreading, "the same cells spread")
	assert_eq(other.reaches, schedule.pose_at(spreading).reaches, "their fronts as far")
	var idle: Array[InputFrame] = []
	for seat in config.seats:
		idle.append(InputFrame.new(seat, 0))
	var played := MatchSim.from_snapshot(MatchJump.snapshot(config, spreading), config)
	var restored := MatchSim.from_snapshot(played.snapshot(), again)
	for step in Ticks.RATE:
		played.step(idle)
		restored.step(idle)
	assert_eq(restored.pose().reaches, played.pose().reaches, "the fronts run on the same")
	assert_eq(
		var_to_bytes(restored.snapshot()), var_to_bytes(played.snapshot()), "the match goes on"
	)


func test_inner_waters_mask_agrees_with_wet() -> void:
	var structure := _hall()
	var fronts := _fronts(_timeline(&"door", DOOR_FLOW, 60), structure)
	var surfaces := Surfaces.new(SimFixtures.deck())
	for seconds: float in [1.0, 4.0, 9.0]:
		var pose := _pose(structure, fronts, seconds, PackedFloat64Array([3.0, FILM]))
		var mask := FrontMask.of(pose, 1)
		assert_false((mask[0] as PackedVector4Array).is_empty(), "masked at %s s" % seconds)
		for x in range(1, 20):
			for z: float in [-2.5, 0.0, 2.5]:
				var point := Vector3(float(x) - 0.3, FILM * 0.5, z)
				var drawn := FrontMask.margin(mask[0], mask[1], point.x, point.z) >= 0.0
				assert_eq(drawn, surfaces.wet(point, pose), "%s s, %s" % [seconds, point])
