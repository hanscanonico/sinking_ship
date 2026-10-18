extends GutTest
## The water inside her walks her openings once a tick (#87): which may pour between the
## two poses it is drawn between is worked out once for that pair (InnerWater._find_wet),
## and every frame draws only those. One wet at either pose pours wherever between them
## its water stands over its bottom; one dry at both is hidden.

const RunMatch := preload("res://tools/run_match.gd")
## How high over the sea the test's poses lift her: every opening of hers clear of it.
const LIFT := 50.0

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
