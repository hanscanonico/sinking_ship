extends GutTest
## A ship lamp sleeps — stops processing — once it is done fading, steady and hanging
## plumb (ShipLamp.still), and wakes as anything it shows changes, or as ShipArt tells
## it a new tick has come (wake): asleep or awake, it hangs as it would have.

const STEP := 1.0 / 60.0
## Seconds enough for a lamp to fade out and a swing to die away.
const SETTLE := 20.0

var _ship: Node3D
var _lamp: ShipLamp


func before_each() -> void:
	_ship = Node3D.new()
	add_child_autofree(_ship)


func _hang(kind := ShipLamp.Kind.PENDANT) -> void:
	_lamp = ShipLamp.new()
	_ship.add_child(_lamp)
	var facing := Vector3.FORWARD if kind == ShipLamp.Kind.FIRE else Vector3.DOWN
	_lamp.setup(0.0, StandardMaterial3D.new(), StandardMaterial3D.new(), kind, facing)


## Runs the lamp's frames for up to [param seconds], as long as it processes.
func _run(seconds: float) -> void:
	for _frame in roundi(seconds / STEP):
		if not _lamp.is_processing():
			return
		_lamp._process(STEP)


## Where the lamp's cord points, world space.
func _cord() -> Vector3:
	return _lamp.global_basis * Vector3.DOWN


func test_a_lamp_faded_out_and_still_sleeps() -> void:
	_hang()
	_lamp.wanted = false
	_run(SETTLE)
	assert_false(_lamp.is_processing())


func test_a_lamp_faded_in_and_still_sleeps_too() -> void:
	_hang()
	_lamp.wanted = false
	_run(SETTLE)
	_lamp.wanted = true
	_run(ShipLamp.FADE / 2.0)
	assert_true(_lamp.is_processing(), "awake while it fades in")
	_run(SETTLE)
	assert_false(_lamp.is_processing(), "asleep once lit")


func test_what_it_shows_changing_wakes_it() -> void:
	_hang()
	_lamp.wanted = false
	_run(SETTLE)
	_lamp.wanted = false
	assert_false(_lamp.is_processing(), "told what it already shows: still asleep")
	_lamp.power = ShipPower.Power.EMERGENCY
	assert_true(_lamp.is_processing(), "its power")
	_run(SETTLE)
	_lamp.wanted = true
	assert_true(_lamp.is_processing(), "the eye wanting it lit")
	_lamp.wanted = false
	_run(SETTLE)
	_lamp.burning = false
	assert_true(_lamp.is_processing(), "wrecked")


func test_a_new_tick_wakes_it_to_swing_plumb_again() -> void:
	_hang()
	_lamp.wanted = false
	_run(SETTLE)
	_ship.basis = Basis(Vector3.RIGHT, 0.3)
	_lamp.wake()
	_run(STEP)
	assert_true(_lamp.is_processing(), "swinging toward plumb")
	_run(SETTLE)
	assert_false(_lamp.is_processing(), "asleep again once still")
	assert_almost_eq(_cord(), Vector3.DOWN, Vector3.ONE * 0.00001, "and hanging plumb")


func test_a_fire_sleeps_only_once_out() -> void:
	_hang(ShipLamp.Kind.FIRE)
	_lamp.wanted = false
	_run(SETTLE)
	assert_true(_lamp.is_processing(), "its glow wavers while it burns")
	_lamp.drowned = true
	_run(SETTLE)
	assert_false(_lamp.is_processing(), "drowned")
	_lamp.drowned = false
	_run(SETTLE)
	_lamp.burning = false
	_run(SETTLE)
	assert_false(_lamp.is_processing(), "wrecked")


func test_a_lamp_is_still_only_done_fading_steady_and_plumb() -> void:
	var lamp := ShipLamp.Kind.PENDANT
	var none := Vector3.ZERO
	var swinging := Vector3.RIGHT * 0.01
	assert_true(ShipLamp.still(lamp, true, 1.0, INF, none, none))
	assert_false(ShipLamp.still(lamp, false, 1.0, INF, none, none), "fading")
	assert_false(ShipLamp.still(lamp, true, 1.0, 0.1, none, none), "flickering")
	assert_false(ShipLamp.still(lamp, true, 1.0, INF, swinging, none), "swinging")
	assert_false(ShipLamp.still(lamp, true, 1.0, INF, none, swinging), "off plumb")
	var fire := ShipLamp.Kind.FIRE
	assert_false(ShipLamp.still(fire, true, 0.8, INF, none, none), "a fire burning")
	assert_true(ShipLamp.still(fire, true, 0.0, INF, none, none), "a fire out")
