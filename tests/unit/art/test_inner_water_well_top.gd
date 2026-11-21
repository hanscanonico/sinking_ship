extends GutTest
## An open well's top is no hole in a deck: the sea comes aboard a well over its edges
## (ShippedWater), so nothing is drawn pouring down through its sky. Heeled, the top's low
## corner dips under the sea long before its middle does, and a pour hung there stood as a
## cross of waterfalls over the deck, from metres up in the air.

const RunMatch := preload("res://tools/run_match.gd")
## How far the pose heels her, in degrees: her well's low edge under the sea.
const HEEL := 28.0
## How far under the sea her well's water stands, in metres: the sea is the higher side.
const LAG := 0.1

var _structure: ShipStructure
var _layout: ShipLayout
var _schedule: SinkSchedule


func before_all() -> void:
	var config := RunMatch.default_config(1701, 0, &"trawler")
	_structure = config.ship.structure
	_layout = config.ship
	_schedule = config.schedule()


func _sea() -> ShaderMaterial:
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://scenes/art/inner_water.gdshader")
	return sea


## Her heeled HEEL, every cell dry at its floor but [param well], its water LAG under the sea.
func _heeled(well: int) -> ShipPose:
	var turn := Basis(Vector3.RIGHT, deg_to_rad(HEEL))
	var pose := ShipPose.new(0.0, 0.0, HEEL, Transform3D(turn, Vector3.ZERO))
	pose.cells = _schedule.pose_at(0).cells
	for cell: FloodCell in _structure.cells:
		pose.levels.append(pose.world_height(cell.low) - 10.0)
	pose.levels[well] = -LAG
	return pose


func test_a_wells_open_top_is_never_drawn_pouring() -> void:
	var passages := _schedule.passages()
	var top := -1
	var well := -1
	for index in passages.size():
		var opening := passages[index]
		if opening.kind == ShipOpening.Kind.OPEN and ShipOpening.SKY in opening.joins:
			top = index
			for place: StringName in opening.joins:
				well = maxi(well, _structure.cell_named(place))
	assert_ne(top, -1, "the trawler's working deck is open to the sky")
	assert_eq(_structure.cells[well].kind, FloodCell.Kind.OPEN_WELL)
	var water: InnerWater = add_child_autofree(InnerWater.new())
	water.setup(_structure, _layout.rooms, _layout, passages, _schedule.failing(), _sea(), {})
	var pose := _heeled(well)
	var span := CellSurface.reach(pose.transform, water._spans[top])
	assert_lt(span.x, -LAG, "its low corner is under the sea")
	assert_gt(pose.world_height(passages[top].centre), 0.0, "its middle is over it")
	water.show_water(pose, pose, 1.0)
	assert_false(water._pours[top].visible, "no sheet hangs from its middle")
	assert_false(water._crossings[top].visible, "nor one across it")
	assert_false(water._landings[top].visible, "nor froth under them")
