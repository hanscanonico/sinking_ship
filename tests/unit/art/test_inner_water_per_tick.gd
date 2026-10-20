extends GutTest
## The water inside her walks her openings once a tick (#87): which may pour between the
## two poses it is drawn between is worked out once for that pair (InnerWater._find_wet),
## and every frame draws only those. One wet at either pose pours wherever between them
## its water stands over its bottom; one dry at both is hidden; and water that has risen
## over an opening's top since last drawn still bursts its air out, pouring or not.

const RunMatch := preload("res://tools/run_match.gd")
## How high over the sea the test's poses lift her: every opening of hers clear of it.
const LIFT := 50.0
## How deep under the sea the sunk poses have her: every opening of hers under it.
const DEEP := 200.0

var _structure: ShipStructure
var _rooms: Array[ShipRoom]
var _schedule: SinkSchedule
var _cells: CellMap
## A doorway between two of her cells that water is drawn pouring through, and its
## two sides: water at its top on the first pours through it, and the first's other doors.
var _door: ShipOpening
var _high := -1
var _low := -1


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_structure = config.ship.structure
	_rooms = config.ship.rooms
	_schedule = config.schedule()
	_cells = _schedule.pose_at(0).cells
	var unseen := [ShipOpening.Kind.GASH, ShipOpening.Kind.FLOOR_GAPS, ShipOpening.Kind.LEAK]
	for opening: ShipOpening in _schedule.passages():
		if opening.kind in unseen or opening.facing() == 1 or opening.joins.size() != 2:
			continue
		var sides := PackedInt32Array()
		for place: StringName in opening.joins:
			sides.append(_structure.cell_named(place))
		if -1 in sides:
			continue
		_door = opening
		_high = sides[0]
		_low = sides[1]
		break


func _water() -> InnerWater:
	var water: InnerWater = add_child_autofree(InnerWater.new())
	water.setup(_structure, _rooms, _schedule.passages(), _schedule.failing(), _sea(), {})
	return water


func _sea() -> ShaderMaterial:
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://scenes/art/inner_water.gdshader")
	return sea


## A pose of her upright, LIFT over the sea, every cell dry at its floor — but the door's
## high side, its water at the door's top when [param wet].
func _pose(wet := false) -> ShipPose:
	var pose := ShipPose.new(-LIFT, 0.0, 0.0, Transform3D(Basis.IDENTITY, Vector3.UP * LIFT))
	pose.cells = _cells
	for cell: FloodCell in _structure.cells:
		pose.levels.append(cell.low.y + LIFT)
	if wet:
		pose.levels[_high] = _door.centre.y + _door.size.y * 0.5 + LIFT
	return pose


## A pose of her upright, DEEP under the sea, every cell dry at its floor — or, when
## [param flooded], every cell's water level with the sea's.
func _sunk(flooded: bool) -> ShipPose:
	var pose := ShipPose.new(DEEP, 0.0, 0.0, Transform3D(Basis.IDENTITY, Vector3.DOWN * DEEP))
	pose.cells = _cells
	for cell: FloodCell in _structure.cells:
		pose.levels.append(0.0 if flooded else cell.low.y - DEEP)
	return pose


## The bursts of air shown: the froths visible that are not a pour's landing.
func _bursting(water: InnerWater) -> int:
	var shown := 0
	for child: Node in water.get_children():
		var froth := child as MeshInstance3D
		if froth == null or not froth.visible:
			continue
		var material := froth.material_override as ShaderMaterial
		if material == null or material.shader != InnerWater.FROTH_SHADER:
			continue
		if material.get_shader_parameter(&"burst") >= 0.0:
			shown += 1
	return shown


## The pours shown: the spill sheets visible.
func _pouring(water: InnerWater) -> int:
	var shown := 0
	for child: Node in water.get_children():
		var sheet := child as MeshInstance3D
		if sheet == null or not sheet.visible:
			continue
		var material := sheet.material_override as ShaderMaterial
		if material != null and material.shader == InnerWater.SPILL_SHADER:
			shown += 1
	return shown


func test_her_has_a_doorway_to_pour_through() -> void:
	assert_not_null(_door, "a doorway between two cells, drawn pouring")


func test_dry_at_both_poses_nothing_pours() -> void:
	var water := _water()
	water.show_water(_pose(), _pose(), 0.5)
	assert_eq(_pouring(water), 0)


func test_wet_at_both_poses_its_doors_pour() -> void:
	var water := _water()
	var wet := _pose(true)
	water.show_water(wet, wet, 0.0)
	assert_gt(_pouring(water), 0, "its cell's doors pour")


func test_wet_only_at_the_later_pose_it_pours_once_its_water_has_risen() -> void:
	var water := _water()
	var dry := _pose()
	var wet := _pose(true)
	water.show_water(dry, wet, 0.0)
	assert_eq(_pouring(water), 0, "dry at the tick drawn from")
	water.show_water(dry, wet, 1.0)
	assert_gt(_pouring(water), 0, "the same two poses: poured by the next tick")


func test_a_pour_is_hidden_once_its_door_is_dry_the_whole_tick() -> void:
	var water := _water()
	var wet := _pose(true)
	water.show_water(wet, wet, 0.0)
	var dry := _pose()
	water.show_water(dry, dry, 0.0)
	assert_eq(_pouring(water), 0)


func test_water_over_every_top_since_last_drawn_bursts_though_nothing_pours() -> void:
	var water := _water()
	water.show_water(_sunk(false), _sunk(false), 0.0)
	var dry := _bursting(water)
	# A frame later, ticks on, every cell full to the sea's level, far over every top:
	# nothing pours anywhere — the water stands level through her — but her air has gone.
	var full := _sunk(true)
	water.show_water(full, full, 0.0)
	assert_eq(_pouring(water), 0, "nothing pours")
	assert_gt(_bursting(water), dry, "her air out")


func test_water_climbing_its_full_rate_or_faster_churns_wholly() -> void:
	assert_eq(InnerWater.inflow(0.0, 0.03, 1.0 / 30.0, 0.3), 1.0)


func test_water_standing_or_falling_does_not_churn() -> void:
	assert_eq(InnerWater.inflow(0.5, 0.5, 1.0 / 30.0, 0.3), 0.0, "standing")
	assert_eq(InnerWater.inflow(0.5, 0.4, 1.0 / 30.0, 0.3), 0.0, "falling")
	assert_eq(InnerWater.inflow(0.0, 0.03, 0.0, 0.3), 0.0, "no time gone by")


func test_water_climbing_slower_churns_by_its_share_of_the_full_rate() -> void:
	assert_almost_eq(InnerWater.inflow(0.0, 0.005, 1.0 / 30.0, 0.3), 0.5, 1e-6)


## How hard the door's high side's sheet churns, as its material is told.
func _inflow_of(water: InnerWater) -> float:
	var sheet: MeshInstance3D = water._surfaces[_high]
	var churn: Variant = (sheet.material_override as ShaderMaterial).get_shader_parameter(&"inflow")
	return 0.0 if churn == null else churn


func test_a_sheet_churns_a_fifth_of_the_way_more_each_tick_its_water_climbs_fast() -> void:
	var water := _water()
	assert_not_null(water._surfaces[_high], "the door's high side's water is drawn")
	var calm := _pose()
	water.show_water(calm, calm, 0.0)
	assert_eq(_inflow_of(water), 0.0, "calm before")
	var risen := _pose()
	risen.levels[_high] += 0.1
	water.show_water(calm, risen, 0.0)
	assert_almost_eq(_inflow_of(water), 0.2, 1e-6, "a fifth of the way on the first tick")
	water.show_water(calm, risen, 0.7)
	assert_almost_eq(_inflow_of(water), 0.2, 1e-6, "once a tick, not once a frame")
	var higher := _pose()
	higher.levels[_high] += 0.2
	water.show_water(risen, higher, 0.0)
	assert_almost_eq(_inflow_of(water), 0.36, 1e-6, "a fifth more of what is left")
	var settled := _pose()
	settled.levels[_high] += 0.2
	water.show_water(higher, settled, 0.0)
	assert_almost_eq(_inflow_of(water), 0.288, 1e-6, "standing still, a fifth back")


func test_a_cell_s_water_shows_from_its_first_water_as_the_transcript_tells_it() -> void:
	var reach := Vector2(-1.0, 1.5)
	var first := SinkTimeline.FIRST_WATER
	assert_true(InnerWater.shows(reach.x + first + 1e-4, reach), "just over its first water")
	assert_true(InnerWater.shows(reach.x + first, reach), "at its first water, flooding")
	assert_false(InnerWater.shows(reach.x + first - 1e-4, reach), "just under it: dry")
	assert_false(InnerWater.shows(reach.y, reach), "full: no surface")


func test_a_cell_s_water_is_never_drawn_close_enough_to_fight_a_dry_floor() -> void:
	var reach := Vector2(0.0, 2.5)
	assert_false(InnerWater.shows(InnerWater.CLEAR_OF_FLOOR * 0.5, reach))
	assert_gte(SinkTimeline.FIRST_WATER, InnerWater.CLEAR_OF_FLOOR, "the first water clears it")
