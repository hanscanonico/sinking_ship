extends GutTest
## Her cells' water sloshing as she turns (#621, CellSlosh): a sudden turn carries it with
## her and it swings back past level and settles at its own period; a slow one leaves it
## level; the sheet InnerWater draws tilts by it about the water's middle, never further
## than SLOSH_MOST at a box's end, never under a floor it stood over nor up to the
## ceiling; a jump in time restarts it from level; and drawn at no moment it is level.

const RunMatch := preload("res://tools/run_match.gd")
## A frame's seconds, and how far the test turns her, in radians.
const FRAME := 1.0 / 60.0
const TURN := 0.06
## How near a sheet's height at a corner keeps to its bounds: the bound is reckoned at the
## corner's column across her, the sheet met a little off it as she leans.
const SLACK := 0.02

var _structure: ShipStructure
var _rooms: Array[ShipRoom]
var _layout: ShipLayout
var _schedule: SinkSchedule
var _cells: CellMap


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_structure = config.ship.structure
	_rooms = config.ship.rooms
	_layout = config.ship
	_schedule = config.schedule()
	_cells = _schedule.pose_at(0).cells


## φ, the water's tilt from level, through [param seconds] of her angle at [param angle]
## of time, sampled each FRAME, from level at rest, at [param omega].
func _tilts(angle: Callable, seconds: float, omega: float) -> PackedFloat64Array:
	var tilts := PackedFloat64Array()
	var swing := Vector2(-float(angle.call(0.0)), 0.0)
	var was: float = angle.call(0.0)
	var time := 0.0
	while time < seconds:
		time += FRAME
		var now: float = angle.call(time)
		swing = CellSlosh.swung(swing, was, now, FRAME, omega)
		was = now
		tilts.append(swing.x + now)
	return tilts


func test_its_period_is_the_tank_s_first_mode() -> void:
	var length := 6.0
	var deep := CellSlosh.omega_of(length, 100.0)
	assert_almost_eq(deep, sqrt(PI * InnerWater.GRAVITY / length), 1e-4, "deep: √(πg/L)")
	var shallow := CellSlosh.omega_of(length, 0.2)
	assert_almost_eq(shallow, PI / length * sqrt(InnerWater.GRAVITY * 0.2), 0.02, "shallow")
	assert_eq(CellSlosh.omega_of(0.0, 1.0), 0.0, "no box, no swing")


func test_a_sudden_turn_carries_it_then_it_swings_past_level_and_settles() -> void:
	var omega := CellSlosh.omega_of(6.0, 1.0)
	# A turn in one frame: the water turned with her.
	var swing := CellSlosh.swung(Vector2.ZERO, 0.0, TURN, FRAME, omega)
	assert_almost_eq(swing.x + TURN, TURN, TURN * 0.05, "carried with her")
	var tilts := _tilts(
		func(time: float) -> float: return TURN if time > FRAME else 0.0, 30.0, omega
	)
	var crossings: Array[int] = []
	for at in range(1, tilts.size()):
		if signf(tilts[at]) != signf(tilts[at - 1]) and tilts[at - 1] != 0.0:
			crossings.append(at)
	assert_gt(crossings.size(), 4, "swings past level, again and again")
	var half := float(crossings[3] - crossings[1]) * FRAME / 2.0
	var damped := omega * sqrt(1.0 - pow(InnerWater.SLOSH_DAMPING, 2.0))
	assert_almost_eq(half, PI / damped, 0.05, "half a swing at its own period")
	var first := 0.0
	for at in crossings[1]:
		first = maxf(first, absf(tilts[at]))
	var last := 0.0
	for at in range(tilts.size() - 60, tilts.size()):
		last = maxf(last, absf(tilts[at]))
	assert_gt(first, TURN * 0.5, "a swing the size of her turn")
	assert_lt(last, first * 0.05, "settled in a few swings")


func test_a_slow_turn_leaves_it_level() -> void:
	var omega := CellSlosh.omega_of(6.0, 1.0)
	var tilts := _tilts(func(time: float) -> float: return TURN * time / 60.0, 60.0, omega)
	var most := 0.0
	for tilt in tilts:
		most = maxf(most, absf(tilt))
	assert_lt(most, TURN * 0.02, "barely off level")


## A pose of her upright or trimmed by [param trim] radians, [param cell]'s water at
## [param depth] over its floor's middle, the rest dry.
func _pose(trim: float, cell: int, depth: float) -> ShipPose:
	var turned := Transform3D(Basis(Vector3.BACK, trim), Vector3.UP * 40.0)
	var pose := ShipPose.new(-40.0, rad_to_deg(trim), 0.0, turned)
	pose.cells = _cells
	for each: FloodCell in _structure.cells:
		pose.levels.append((turned * each.low).y - 1.0)
	var floor := _structure.cells[cell].low.lerp(_structure.cells[cell].high, 0.5)
	floor.y = _structure.cells[cell].low.y
	pose.levels[cell] = (turned * floor).y + depth
	return pose


func _water() -> InnerWater:
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://scenes/art/inner_water.gdshader")
	var water: InnerWater = add_child_autofree(InnerWater.new())
	water.setup(_structure, _rooms, _layout, _schedule.passages(), _schedule.failing(), sea, {})
	return water


## A cell drawn in a box of its own, the longest along her of those.
func _long_cell(water: InnerWater) -> int:
	var found := -1
	for cell in water._surfaces.size():
		if water._surfaces[cell] == null:
			continue
		if found == -1 or water._boxes[cell].size.x > water._boxes[found].size.x:
			found = cell
	return found


## The world height of [param surface]'s sheet over ship point [param point], her drawn at
## [param ship].
static func _sheet_height(surface: MeshInstance3D, ship: Transform3D, point: Vector3) -> float:
	var placed := surface.transform
	var normal := (ship.basis * placed.basis.z.cross(placed.basis.x)).normalized()
	var origin := ship * placed.origin
	var at := ship * point
	return origin.y - (normal.x * (at.x - origin.x) + normal.z * (at.z - origin.z)) / normal.y


func test_her_sheet_tilts_and_stays_in_its_box() -> void:
	var water := _water()
	var cell := _long_cell(water)
	var box := water._boxes[cell]
	var depth := box.size.y * 0.4
	var level := _pose(0.0, cell, depth)
	var turned := _pose(TURN, cell, depth)
	water.show_water(level, level, 0.0, 10.0)
	var surface := water._surfaces[cell]
	assert_true(surface.visible, "the cell's water shows")
	var placed := surface.transform
	water.show_water(level, turned, 1.0, 10.0 + FRAME)
	var ship := water._ship
	var lifted := 0.0
	for corner in 4:
		var end := box.position
		end.x = box.position.x if corner & 1 == 0 else box.end.x
		end.z = box.position.z if corner & 2 == 0 else box.end.z
		var water_level := turned.levels[cell]
		var height := _sheet_height(surface, ship, end)
		var floor := (ship * end).y
		var top := (ship * Vector3(end.x, box.end.y, end.z)).y
		lifted = maxf(lifted, absf(height - water_level))
		assert_lt(absf(height - water_level), InnerWater.SLOSH_MOST + SLACK, "at most SLOSH_MOST")
		if water_level > floor:
			assert_gt(height, floor - SLACK, "never under a floor it covered")
		assert_lt(height, top, "never to the ceiling")
	assert_gt(lifted, 0.05, "tilted, carried with her")
	# Long after, at rest, level again; a jump in time restarts it from level.
	for frame in 3600:
		water.show_water(turned, turned, 0.0, 10.0 + FRAME * (frame + 2))
	for corner: Vector3 in [box.position, box.end]:
		var height := _sheet_height(surface, water._ship, corner)
		assert_almost_eq(height, turned.levels[cell], 0.01, "settled level")
	var flat := CellSurface.placed(water._ship, water._level, box, turned.levels[cell])
	water.show_water(level, turned, 1.0, 100.0)
	assert_eq(surface.transform, flat, "a jump in time: level")
	water.show_water(level, level, 0.0)
	assert_eq(surface.transform, placed, "drawn at no moment: level")


func test_on_a_hull_creeping_slower_than_calm_her_water_sleeps_level() -> void:
	var water := _water()
	var cell := _long_cell(water)
	var box := water._boxes[cell]
	var depth := box.size.y * 0.4
	var creep := InnerWater.SLOSH_CALM * 0.5
	for frame in 240:
		var pose := _pose(creep * FRAME * frame, cell, depth)
		water.show_water(pose, pose, 0.0, 10.0 + FRAME * frame)
		var flat := CellSurface.placed(water._ship, water._level, box, pose.levels[cell])
		assert_eq(water._surfaces[cell].transform, flat, "asleep: drawn level, unswung")
		if frame > 1:
			assert_true(water._slosh.still, "a calm frame asks no sheet's tilt")
