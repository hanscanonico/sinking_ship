extends GutTest

const SCENE := preload("res://scenes/art/sea_and_sky.tscn")
const STEAMER := "res://data/ships/steamer.tres"
const STEAMER_SINKING := "res://data/sinking/steamer.tres"

var _layout: ShipLayout
var _sea: SeaAndSky


func before_each() -> void:
	_layout = load(STEAMER)
	_sea = SCENE.instantiate()
	add_child_autofree(_sea)


## The ship at [param trim_deg] (bow down), dropped [param sink] metres from level.
func _pose(trim_deg: float, sink: float) -> Transform3D:
	var tilt := Basis(Vector3.BACK, -deg_to_rad(trim_deg))
	return Transform3D(tilt, Vector3(0.0, _layout.freeboard - sink, 0.0))


## What the sea's shader reads for [param parameter]: what it was handed, else its
## default in water.gdshader, zero for both of the churn's.
func _handed(parameter: StringName, unset: Variant) -> Variant:
	var value: Variant = _sea.water().get_shader_parameter(parameter)
	return unset if value == null else value


func _churn() -> float:
	return _handed(&"churn", 0.0)


func _centre() -> Vector2:
	return _handed(&"churn_centre", Vector2.ZERO)


func _axis() -> Vector2:
	return _handed(&"churn_axis", Vector2.RIGHT)


func _assert_finite_churn(context: String) -> void:
	var churn := _churn()
	var centre := _centre()
	var finite := is_finite(churn) and churn >= 0.0 and churn <= 1.0
	assert_true(finite, "%s: churn %s" % [context, churn])
	assert_true(centre.is_finite(), "%s: centre %s" % [context, centre])
	var axis := _axis()
	var unit := axis.is_finite() and is_equal_approx(axis.length(), 1.0)
	assert_true(unit, "%s: axis %s" % [context, axis])


func test_the_churn_is_finite_before_setup() -> void:
	_sea.show_sinking(0, _pose(12.0, 3.0))
	_assert_finite_churn("before setup")
	assert_eq(_churn(), 0.0)


func test_the_churn_is_finite_in_every_pose_and_stills_where_the_bow_misses_the_sea() -> void:
	_sea.setup(1000, _layout)
	var poses := {
		"level": _pose(0.0, 0.0),
		"bow under": _pose(12.0, 3.0),
		"wholly under": _pose(12.0, 80.0),
		"stern lifted": _pose(-25.0, 0.0),
	}
	for name: String in poses:
		_sea.show_sinking(500, poses[name])
		_assert_finite_churn(name)
	_sea.show_sinking(500, poses["bow under"])
	var centre := _centre()
	assert_gt(_churn(), 0.0, "the bow under churns")
	_sea.show_sinking(500, poses["wholly under"])
	assert_eq(_churn(), 0.0, "nothing churns over a sunk bow")
	assert_eq(_centre(), centre, "the centre stays put")


func test_the_churn_is_finite_over_the_whole_sinking() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701
	var schedule := SinkSchedule.new(load(STEAMER_SINKING), _layout.freeboard, rng)
	var end := schedule.cap_tick()
	_sea.setup(end, _layout)
	for tick in range(0, end + 60, 15):
		_sea.show_sinking(tick, schedule.pose_at(tick).transform)
		_assert_finite_churn("tick %d" % tick)
