extends GutTest
## The free camera's floor against her sinking as the physics bakes it: under the lowest
## point of her hull — of every piece of her standing — at every moment her sinking is
## followed, so the camera gets under her all the way down. She goes down on end, her
## length hanging under her: tens of metres deeper than her keel lies under her decks
## level, a long hull over a hundred. Read off the match's own SinkSchedule for a hull
## that goes down on end, a long one, and one that breaks; and the match's free camera
## has that floor.

const MATCH := preload("res://scenes/match/match.tscn")
const SEED := 1701
## How many ticks apart her poses are read: a second of the match, and her last tick.
const EVERY := Ticks.RATE
## How far past SeaPhysics.gone_depth the bake's last step may carry a hull's highest
## point, in metres, est.: a metre on the ferry, the most seen through the fleet.
const LAST_STEP := 2.0


## The match's sinking of [param ship] on SEED.
func _config(ship: StringName) -> MatchConfig:
	return MatchConfig.from_rules(load("res://data/match/default.tres"), SEED, 1, ship)


## How low the lowest point of her hull stands in the world through [param schedule]'s
## sinking, to its last tick: every corner of every section of every piece of her standing
## (ShipPose.standing), as its pose sets it.
func _lowest(schedule: SinkSchedule) -> float:
	var lowest := INF
	var end := schedule.end_tick()
	var tick := 0
	while true:
		var pose := schedule.pose_at(tick)
		for piece: int in pose.standing:
			var to_world := pose.of_piece(piece).transform
			for section: HullSection in schedule.structure_of(piece).sections:
				var half := section.length * 0.5
				for x: float in [section.x - half, section.x + half]:
					for point: Vector2 in section.outline:
						lowest = minf(lowest, (to_world * Vector3(x, point.y, point.x)).y)
		if tick == end:
			break
		tick = mini(tick + EVERY, end)
	return lowest


## Checks the floor of a free camera round [param config]'s ship against her sinking, and
## gives how low her hull went.
func _check_floor(config: MatchConfig) -> float:
	var sea := SeaPhysics.load_default()
	var ship := Fleet.name_of(config.ship)
	var reach := FreeCamera.reach_of(config.ship.structure, sea.gone_depth)
	var lowest := _lowest(config.schedule())
	assert_gt(lowest, -reach - LAST_STEP, "%s: never deeper than her reach" % ship)
	var bottom := FreeCamera.floor_under(reach, config.scenario.sea_depth)
	assert_lt(bottom, lowest, "%s: its floor under her lowest point, all the way down" % ship)
	return lowest


## How far her keel lies under her highest point, level, with that point as deep as the
## bake follows it: what a hull that never went down on end would reach.
func _level(structure: ShipStructure) -> float:
	var top := -INF
	for section: HullSection in structure.sections:
		for point: Vector2 in section.outline:
			top = maxf(top, point.y)
	return SeaPhysics.load_default().gone_depth + top - structure.keel_y


func test_its_floor_is_under_the_steamer_going_down_on_end() -> void:
	var config := _config(&"steamer")
	var lowest := _check_floor(config)
	assert_lt(lowest, -2.0 * _level(config.ship.structure), "on end: twice as deep as level")


func test_its_floor_is_under_the_freighter_her_length_hanging_under_her() -> void:
	var config := _config(&"freighter")
	var lowest := _check_floor(config)
	assert_lt(lowest, -100.0, "a long hull, most of her length under her")


func test_its_floor_is_under_every_piece_of_a_hull_that_breaks() -> void:
	var config := SimFixtures.breaking(1, null)
	assert_gt(config.schedule().piece_count(), 1, "she breaks")
	_check_floor(config)


func test_the_match_s_free_camera_has_that_floor() -> void:
	var config := SimFixtures.breaking(1, null)
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.start(config, true, false, MatchScene.LOCAL_SEAT, INF, true)
	var reach := FreeCamera.reach_of(config.ship.structure, SeaPhysics.load_default().gone_depth)
	var bottom := FreeCamera.floor_under(reach, config.scenario.sea_depth)
	assert_lt(bottom, -reach, "under the deepest she goes")
	assert_almost_eq(scene._free.bounds.position.y, bottom, 1e-4)
