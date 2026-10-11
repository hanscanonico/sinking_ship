extends GutTest
## The dusk's haze reaches as far as her length asks (SeaAndSky.HAZE_LENGTH): as the
## scene sets it on the steamer and the trawler, and on the Titanic far enough that her
## bow sees her stern and the observer, standing back to frame her whole, sees her as
## clear as a short ship.

const SCENE := preload("res://scenes/art/sea_and_sky.tscn")

var _sea: SeaAndSky
var _set: Environment


func before_each() -> void:
	_sea = SCENE.instantiate()
	add_child_autofree(_sea)
	var scene := SCENE.instantiate()
	_set = (scene.get_node("Environment") as WorldEnvironment).environment
	scene.free()


func _length(layout: ShipLayout) -> float:
	var bounds := layout.platforms[0].area
	for platform: ShipPlatform in layout.platforms:
		bounds = bounds.merge(platform.area)
	return bounds.size.x


func test_a_small_ship_keeps_the_haze_the_scene_sets() -> void:
	for ship: String in ["steamer", "trawler"]:
		_sea.setup(0, load("res://data/ships/%s.tres" % ship))
		assert_eq(_sea.dusk().fog_depth_begin, _set.fog_depth_begin, "%s's haze begins" % ship)
		assert_eq(_sea.dusk().fog_depth_end, _set.fog_depth_end, "%s's haze is whole" % ship)


func test_the_titanics_haze_lets_her_bow_see_her_stern() -> void:
	var titanic: ShipLayout = load("res://data/ships/titanic.tres")
	_sea.setup(0, titanic)
	var length := _length(titanic)
	assert_gt(_sea.dusk().fog_depth_begin, _set.fog_depth_begin, "her haze begins farther off")
	assert_gt(_sea.dusk().fog_depth_end, length, "her stern stands short of the whole haze")
	# The observer's rig: 24 m back from a short ship, LONG_HULL_DISTANCE of a long one.
	var short := _set.fog_depth_begin / 24.0
	var long := _sea.dusk().fog_depth_begin / (length * ObserverCamera.LONG_HULL_DISTANCE)
	assert_almost_eq(long, short, 0.01, "the observer sees her through as little haze")
