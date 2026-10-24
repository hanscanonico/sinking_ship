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
## How far the levelled poses heel her, in degrees.
const HEEL := 12.0
## How near a sheet's height comes to its pose's level: its transform is single
## precision, LIFT over the sea.
const FLOAT_SLACK := 1e-4

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


## The strength the pours shown are drawn at, the strongest.
func _strongest(water: InnerWater) -> float:
	var most := -1.0
	for child: Node in water.get_children():
		var sheet := child as MeshInstance3D
		if sheet == null or not sheet.visible:
			continue
		var material := sheet.material_override as ShaderMaterial
		if material != null and material.shader == InnerWater.SPILL_SHADER:
			most = maxf(most, material.get_shader_parameter(&"strength"))
	return most


func test_a_pour_is_as_strong_as_the_water_passing_it() -> void:
	# The bake's flow through an opening, per metre of its width, where the pose has one
	# (ShipPose.flows); the height the water falls where it has none.
	var wet := _pose(true)
	var water := _water()
	water.show_water(wet, wet, 0.0)
	assert_eq(_strongest(water), 1.0, "a door's height of water falling: a solid sheet")
	var names: Array[StringName] = []
	for opening: ShipOpening in _schedule.passages():
		names.append(opening.name)
	for share: float in [0.0, 0.5, 2.0]:
		var flowing := _pose(true)
		flowing.passages = names
		flowing.flows.resize(names.size())
		for at in names.size():
			var opening := _schedule.passages()[at]
			var wide := opening.size.z if opening.facing() == 0 else opening.size.x
			if opening.facing() == 1:
				wide = maxf(opening.size.x, opening.size.z)
			flowing.flows[at] = share * InnerWater.FLOW_FULL * wide
		var drawn := _water()
		drawn.show_water(flowing, flowing, 0.0)
		assert_almost_eq(
			_strongest(drawn),
			clampf(share, InnerWater.THINNEST, 1.0),
			1e-6,
			"%.1f of a full flow" % share
		)


func test_pour_strength_reads_the_flow_before_the_fall() -> void:
	assert_eq(InnerWater.pour_strength(0.5, -1.0, 1.0), 0.5, "no flow: half a metre falling")
	assert_eq(InnerWater.pour_strength(0.5, InnerWater.FLOW_FULL, 1.0), 1.0, "a full flow")
	assert_eq(InnerWater.pour_strength(2.0, 0.0, 1.0), InnerWater.THINNEST, "nothing passing")
	assert_almost_eq(
		InnerWater.pour_strength(2.0, InnerWater.FLOW_FULL * 0.6, 2.0), 0.3, 1e-9, "per metre"
	)


## A pose of her heeled HEEL, LIFT over the sea, every cell dry at its lowest corner but
## the door's two sides, both their water at the world height of the door's middle — the
## high side's [param raised] over it.
func _levelled(raised := 0.0) -> ShipPose:
	var turned := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(HEEL)), Vector3.UP * LIFT)
	var pose := ShipPose.new(-LIFT, 0.0, HEEL, turned)
	pose.cells = _cells
	for cell: FloodCell in _structure.cells:
		pose.levels.append(CellSurface.reach(turned, AABB(cell.low, cell.high - cell.low)).x)
	var level := pose.world_height(_door.centre)
	pose.levels[_low] = level
	pose.levels[_high] = level + raised
	return pose


## Whether the door's own pour is shown.
func _door_pours(water: InnerWater) -> bool:
	var pour := water._pours[_schedule.passages().find(_door)]
	return pour != null and pour.visible


## The world height [param sheet] stands at on her as [param pose] has her.
func _sheet_height(sheet: MeshInstance3D, pose: ShipPose) -> float:
	return pose.world_height(sheet.transform.origin)


func test_water_level_across_a_heeled_doorway_stands_at_one_height_and_does_not_pour() -> void:
	var water := _water()
	var level := _levelled()
	water.show_water(level, level, 0.0)
	var high: MeshInstance3D = water._surfaces[_high]
	var low: MeshInstance3D = water._surfaces[_low]
	assert_true(high.visible, "the high side's water")
	assert_true(low.visible, "the low side's water")
	assert_almost_eq(_sheet_height(high, level), _sheet_height(low, level), 1e-6, "one height")
	assert_almost_eq(_sheet_height(low, level), level.levels[_low], FLOAT_SLACK, "the pose's")
	assert_false(_door_pours(water), "nothing pours through the door")


func test_a_doorway_pours_only_once_one_side_stands_pours_over_the_other() -> void:
	var under := _levelled(InnerWater.POURS - 0.001)
	var short := _water()
	short.show_water(under, under, 0.0)
	assert_false(_door_pours(short), "just under POURS higher: no pour")
	var over := _levelled(InnerWater.POURS + 0.01)
	var pouring := _water()
	pouring.show_water(over, over, 0.0)
	assert_true(_door_pours(pouring), "past POURS higher: it pours")


func test_a_stacked_box_s_sheet_follows_its_cell_s_water() -> void:
	var stacks := CellBoxes.stacked(_structure, _rooms)
	assert_gt(stacks.size(), 0, "a cell drawn in a stack of boxes")
	var water := _water()
	assert_eq(water._stacks.size(), stacks.size(), "a sheet per stacked box")
	var cell: int = stacks[0][0]
	var box: AABB = stacks[0][1]
	var pose := _pose()
	var reach := CellSurface.reach(pose.transform, box)
	for share: float in [0.3, 0.7]:
		pose = _pose()
		pose.levels[cell] = lerpf(reach.x, reach.y, share)
		water.show_water(pose, pose, 0.0)
		var sheet: MeshInstance3D = water._stacks[0][2]
		assert_true(sheet.visible, "%.1f up its box: shown" % share)
		assert_almost_eq(
			_sheet_height(sheet, pose), pose.levels[cell], FLOAT_SLACK, "at its cell's level"
		)


## What [param water] draws: each sheet's and pour's visibility and, shown, its transform.
func _drawn(water: InnerWater) -> Array:
	var drawn := []
	for child: Node in water.get_children():
		var sheet := child as MeshInstance3D
		if sheet != null:
			drawn.append([sheet.visible, sheet.transform if sheet.visible else Transform3D()])
	return drawn


func test_water_drawn_again_frame_after_frame_draws_as_it_would_drawn_afresh() -> void:
	# The levels and a pour's heights are kept from frame to frame, not made anew: what a
	# frame draws owes nothing to the frames before it.
	var kept := _water()
	var wet := _pose(true)
	kept.show_water(wet, wet, 0.0)
	var over := _levelled(InnerWater.POURS + 0.01)
	kept.show_water(wet, over, 0.6)
	kept.show_water(over, over, 0.0)
	var fresh := _water()
	fresh.show_water(over, over, 0.0)
	assert_true(_door_pours(kept), "the door pours")
	assert_eq(_drawn(kept), _drawn(fresh))
