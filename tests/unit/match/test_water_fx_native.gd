extends GutTest
## The water's effects' loops natively (#410, NativeWaterFx) against the GDScript they
## stand in for, bit for bit: on her real ships' sinkings, step after step from her
## first tick to her last, the water inside her drawn by an InnerWater whose loops go to
## the extension and by one whose loops run in GDScript — every sheet, sloshing, stack, pour,
## froth and light the same, shown or hidden, placed and painted alike, and the same
## state kept — and an FxPlanner's and a CuePlanner's effects and sounds of each step
## the same, field for field — on a hull that breaks too, each piece of her read as it
## stands (PieceViews). Where the extension is not loaded there is nothing to hold
## it to; CI sets SINKING_NATIVE_REQUIRED, so a missing library there fails.

const RunMatch := preload("res://tools/run_match.gd")
const SEA := preload("res://scenes/art/water.gdshader")
const SHIPS: Array[StringName] = [&"steamer", &"small_titanic"]
const SEED := 4
## How many ticks each step checked spans, and where between its two poses each of its
## frames is drawn.
const STRIDE := 15
const ALPHAS: Array[float] = [0.37, 1.0]
## How many poses of her sinking her water is set on its edges in, and a hair off one.
const EDGE_POSES := 40
const HAIR := 1e-9
## What is read of each drawn thing's material — but its slot, each InnerWater's own
## (InnerWater.TO_SHIP) — and of an InnerWater's own state.
const PARAMS: Array[StringName] = [
	&"clip_low",
	&"clip_high",
	&"outdoor",
	&"waders",
	&"wader_count",
	&"inflow",
	&"pocket_glow",
	&"world_to_ship",
	&"extent",
	&"strength",
	&"thrown",
	&"burst",
	&"leaking",
]
const STATE: Array[StringName] = [
	&"_ship",
	&"_up",
	&"_level",
	&"_levels",
	&"_wet",
	&"_last_heads",
	&"_burst_cells",
	&"_burst_at",
	&"_burst_ages",
	&"_next_burst",
	&"_airs",
	&"_glows",
	&"_inflows",
	&"_stacks_shown",
]


func test_her_water_is_drawn_alike_as_she_sinks() -> void:
	if not _loaded():
		return
	for ship: StringName in SHIPS:
		var config := RunMatch.default_config(SEED, 2, ship)
		var schedule := config.schedule()
		var sea := ShaderMaterial.new()
		sea.shader = SEA
		var waters: Array[InnerWater] = []
		for side in 2:
			var water: InnerWater = add_child_autofree(InnerWater.new())
			if side == 1:
				water.native = null
			water.setup(
				config.ship.structure,
				config.ship.rooms,
				config.ship,
				schedule.passages(),
				schedule.failing(),
				sea,
				{}
			)
			waters.append(water)
		assert_not_null(waters[0].native, "%s's water is drawn natively" % ship)
		var differences: Array[String] = []
		var shown := {&"sheets": 0, &"pours": 0, &"bursts": 0}
		var end := schedule.end_tick()
		for tick in range(0, end, STRIDE):
			var then := schedule.pose_at(tick)
			var now := schedule.pose_at(tick + STRIDE)
			for alpha: float in ALPHAS:
				var drawn: Array[PackedByteArray] = []
				for water: InnerWater in waters:
					# At its moment, so each sheet sloshes as she turns (CellSlosh).
					var seconds := (tick + STRIDE * alpha) * Ticks.SECONDS_PER_TICK
					water.show_water(then, now, alpha, seconds)
					if water.is_processing():
						water._process(Ticks.SECONDS_PER_TICK * STRIDE / ALPHAS.size())
					drawn.append(var_to_bytes(_state(water, shown if water == waters[0] else {})))
				if drawn[0] != drawn[1] and differences.size() < 4:
					differences.append("tick %d at %s" % [tick, alpha])
		gut.p("%s: %d ticks, shown %s" % [ship, end, shown])
		assert_eq(differences, [] as Array[String], "%s's water is drawn alike" % ship)
		for kind: StringName in shown:
			assert_gt(shown[kind], 0, "%s's sinking draws %s" % [ship, kind])


func test_her_steps_plan_alike_as_she_sinks() -> void:
	if not _loaded():
		return
	for ship: StringName in SHIPS:
		_plans_alike(RunMatch.default_config(SEED, 2, ship), ship, 0, ["WASH", "FLOOD", "POUR"])


func test_her_broken_steps_plan_alike() -> void:
	# Once she has broken, every piece of her read as it stands (PieceViews, #478).
	if not _loaded():
		return
	var config := SimFixtures.breaking(1, null)
	var from := SimFixtures.after_parting(config.schedule(), -10.0)
	_plans_alike(config, &"steamer_weak", from, ["WASH", "FLOOD"])


## An FxPlanner's and a CuePlanner's steps of [param config]'s sinking from [param from],
## natively and in GDScript, field for field: telling of every kind in [param kinds].
func _plans_alike(config: MatchConfig, ship: StringName, from: int, kinds: Array) -> void:
	var sim := MatchSim.create(config)
	var schedule := sim.schedule
	var fxs: Array[FxPlanner] = []
	var cues: Array[CuePlanner] = []
	for side in 2:
		fxs.append(FxPlanner.new(config, sim.surfaces, schedule))
		cues.append(CuePlanner.new(config, sim.surfaces, schedule, 0))
		cues[side].listener_seat = 0
	assert_not_null(fxs[0].native, "%s's effects are planned natively" % ship)
	assert_not_null(cues[0].native, "%s's sounds are planned natively" % ship)
	fxs[1].native = null
	fxs[1]._decks._middles.water = null
	cues[1].native = null
	cues[1]._decks._middles.water = null
	var differences: Array[String] = []
	var told := {}
	var snapshot := sim.snapshot()
	snapshot["events"] = []
	var end := schedule.end_tick()
	for tick in range(from, end, STRIDE):
		var previous := snapshot.duplicate()
		previous["tick"] = tick
		var current := snapshot.duplicate()
		current["tick"] = tick + STRIDE
		var planned: Array[PackedByteArray] = []
		for side in 2:
			var made: Array = []
			for each: FxCue in fxs[side].plan(previous, current):
				made.append(_fields(each))
				if side == 0:
					told[FxCue.Kind.keys()[each.kind]] = true
			for each: AudioCue in cues[side].plan(previous, current):
				made.append(_fields(each))
				if side == 0:
					told[AudioCue.Kind.keys()[each.kind]] = true
			planned.append(var_to_bytes(made))
		if planned[0] != planned[1] and differences.size() < 4:
			differences.append("tick %d" % tick)
	gut.p("%s: %d ticks, told %s" % [ship, end, told.keys()])
	assert_eq(differences, [] as Array[String], "%s's steps plan alike" % ship)
	for kind: String in kinds:
		assert_true(told.has(kind), "%s's sinking tells of %s" % [ship, kind])


func test_her_water_on_its_edges_is_drawn_and_heard_alike() -> void:
	if not _loaded():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 410
	for ship: StringName in SHIPS:
		var config := RunMatch.default_config(SEED, 2, ship)
		var sim := MatchSim.create(config)
		var schedule := sim.schedule
		var sea := ShaderMaterial.new()
		sea.shader = SEA
		var waters: Array[InnerWater] = []
		var cues: Array[CuePlanner] = []
		for side in 2:
			var water: InnerWater = add_child_autofree(InnerWater.new())
			if side == 1:
				water.native = null
			water.setup(
				config.ship.structure,
				config.ship.rooms,
				config.ship,
				schedule.passages(),
				schedule.failing(),
				sea,
				{}
			)
			waters.append(water)
			cues.append(CuePlanner.new(config, sim.surfaces, schedule, 0))
		cues[1].native = null
		var differences: Array[String] = []
		var end := schedule.end_tick()
		for at in EDGE_POSES:
			var base := schedule.pose_at(int(end * (at + 0.5) / EDGE_POSES))
			for water: InnerWater in waters:
				water.show_water(base, base, 0.0)
			var pose := SimFixtures.copy_of(base)
			pose.levels = _edges(waters[1], cues[1], base, rng)
			var drawn: Array[PackedByteArray] = []
			for water: InnerWater in waters:
				water.show_water(pose, pose, 0.0)
				drawn.append(var_to_bytes(_state(water, {})))
			if drawn[0] != drawn[1] and differences.size() < 4:
				differences.append("drawn at pose %d" % at)
			var heard: Array[PackedByteArray] = []
			for cue: CuePlanner in cues:
				var reading := cue._reading(pose)
				heard.append(var_to_bytes([reading.over, reading.pouring]))
			if heard[0] != heard[1] and differences.size() < 4:
				differences.append("heard at pose %d" % at)
		assert_eq(differences, [] as Array[String], "%s's water on its edges is alike" % ship)


## Per cell of [param base], a level on one of the edges the walks compare it with —
## where a sheet or a stack starts or stops showing, where her floor is heard flooding,
## where an opening it is a side of starts pouring or crossing — or a hair off one, as
## [param water] and [param cue] work them out under [param base].
func _edges(
	water: InnerWater, cue: CuePlanner, base: ShipPose, rng: RandomNumberGenerator
) -> PackedFloat64Array:
	var ship := water._ship
	var first := maxf(SinkTimeline.FIRST_WATER, InnerWater.CLEAR_OF_FLOOR)
	var edges: Array[PackedFloat64Array] = []
	for cell in base.levels.size():
		edges.append(PackedFloat64Array([base.levels[cell]]))
		if water._surfaces[cell] != null:
			var reach := CellSurface.reach(ship, water._boxes[cell])
			edges[cell].append_array([reach.x + first, reach.y - InnerWater.SHOWS])
	for stack: Array in water._stacks:
		var reach := CellSurface.reach(ship, stack[1])
		edges[stack[0]].append_array([reach.x + first, reach.y - InnerWater.SHOWS])
	for at in water._stack_cells.size():
		var reach := CellSurface.reach(ship, water._stack_bounds[at])
		var slack := InnerWater.STACK_SLACK
		edges[water._stack_cells[at]].append_array(
			[reach.x + first - slack, reach.y - InnerWater.SHOWS + slack]
		)
	var basis := base.transform.basis
	var row := Vector3(basis.x.y, basis.y.y, basis.z.y)
	var rise := base.transform.origin.y
	for cell in cue._floors.size():
		var half := cue._floor_halves[cell]
		var reach := absf(row.x) * half.x + absf(row.y) * half.y + absf(row.z) * half.z
		edges[cell].append(row.dot(cue._floors[cell]) - reach + rise + CuePlanner.SHOWS)
	for index in water._passages.size():
		var middle := row.dot(water._centres[index]) + rise
		var lowest := middle - water._reaches[index]
		var highest := middle + water._reaches[index]
		for side in 2:
			var cell := water._slots[index * 2 + side]
			if cell < base.levels.size():
				edges[cell].append_array(
					[lowest + InnerWater.SHOWS, highest - InnerWater.POURS, lowest, highest]
				)
	var levels := PackedFloat64Array()
	for cell in edges.size():
		var level := edges[cell][rng.randi_range(0, edges[cell].size() - 1)]
		var hair: float = [0.0, 0.0, HAIR, -HAIR][rng.randi_range(0, 3)]
		levels.append(level + hair)
	return levels


## [param water]'s state and every drawn thing of it, as bytes compare them; counting
## into [param shown] what it shows.
func _state(water: InnerWater, shown: Dictionary) -> Array:
	var state := []
	for name: StringName in STATE:
		state.append(water.get(name))
	for child: Node in water.get_children():
		var drawn := child as Node3D
		if drawn == null:
			continue
		state.append(drawn.visible)
		var mesh := drawn as MeshInstance3D
		if mesh == null:
			state.append(drawn.position)
			if drawn is OmniLight3D:
				state.append((drawn as OmniLight3D).omni_range)
			continue
		state.append(mesh.top_level)
		if mesh.visible:
			state.append(mesh.transform)
		var material := mesh.material_override as ShaderMaterial
		for param: StringName in PARAMS:
			state.append(material.get_shader_parameter(param))
		if mesh.visible and not shown.is_empty():
			if material.shader == InnerWater.SPILL_SHADER:
				shown[&"pours"] += 1
			elif material.shader == InnerWater.WATER_SHADER:
				shown[&"sheets"] += 1
			elif material.get_shader_parameter(&"burst") >= 0.0:
				shown[&"bursts"] += 1
	return state


## Every field of [param cue], in order.
func _fields(cue: Object) -> Array:
	var fields := []
	for property: Dictionary in cue.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(cue.get(property["name"]))
	return fields


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeWaterFx"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
