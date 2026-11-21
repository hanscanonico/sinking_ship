extends GutTest
## A seat's eye, leaning off its body's upright on a listing ship, stays short of the wall
## the body stands against (EyeHold).

const EYE := 1.6
const WALL := 2.0


## A deck with one wall along z, its near face at x = WALL.
func _walled() -> Surfaces:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var deck := ShipPlatform.new()
	deck.area = Rect2(-10.0, -6.0, 20.0, 12.0)
	layout.platforms = [deck]
	var wall := ShipBlocker.new()
	wall.area = Rect2(WALL, -6.0, 0.2, 12.0)
	wall.top = 2.5
	layout.blockers = [wall]
	layout.spawns = [Vector3.ZERO]
	return Surfaces.new(layout)


## The eye of feet at [param feet] on a ship heeled [param heel_deg] toward -x, in her
## ship space: EYE over the feet along the world's up, which leans toward +x in hers.
func _leaning(feet: Vector3, heel_deg: float) -> Vector3:
	var heel := deg_to_rad(heel_deg)
	return feet + Vector3(sin(heel), cos(heel), 0.0) * EYE


func test_the_eye_of_a_body_against_a_wall_stays_this_side_of_it() -> void:
	var rules := SimFixtures.rules()
	var pose := SimFixtures.sim(1).pose()
	var feet := Vector3(WALL - rules.body_radius, 0.0, 0.0)
	var wanted := _leaning(feet, 17.0)
	assert_gt(wanted.x, WALL, "at 17° the eye leans past the body's radius, into the wall")
	var held := EyeHold.held(_walled(), pose, feet, wanted)
	assert_lt(held.x, WALL - EyeHold.CLEARANCE + 0.001, "held short of the wall")
	assert_gt(held.x, WALL - EyeHold.CLEARANCE - 0.02, "and no shorter than it must be")
	assert_almost_eq(held.y, wanted.y, 0.0001, "as high as it stood")
	assert_almost_eq(held.z, wanted.z, 0.0001, "along its lean only")


func test_an_eye_just_short_of_a_wall_keeps_the_near_plane_out_of_it() -> void:
	var pose := SimFixtures.sim(1).pose()
	var feet := Vector3(WALL - 0.5, 0.0, 0.0)
	var wanted := _leaning(feet, 17.0)
	assert_lt(wanted.x, WALL, "this side of the wall")
	assert_gt(wanted.x, WALL - EyeHold.CLEARANCE, "but nearer than the clearance")
	var held := EyeHold.held(_walled(), pose, feet, wanted)
	assert_lt(held.x, WALL - EyeHold.CLEARANCE + 0.001)


func test_an_eye_with_nothing_near_stands_where_it_leans() -> void:
	var pose := SimFixtures.sim(1).pose()
	var walled := _walled()
	var open := Vector3(-3.0, 0.0, 0.0)
	assert_eq(EyeHold.held(walled, pose, open, _leaning(open, 17.0)), _leaning(open, 17.0))
	# Leaning away from the wall it stands against.
	var feet := Vector3(WALL - 0.4, 0.0, 0.0)
	assert_eq(EyeHold.held(walled, pose, feet, _leaning(feet, -17.0)), _leaning(feet, -17.0))
	# Upright, on a level ship.
	assert_eq(EyeHold.held(walled, pose, feet, _leaning(feet, 0.0)), _leaning(feet, 0.0))


func test_an_eye_over_the_wall_s_top_leans_over_it() -> void:
	var pose := SimFixtures.sim(1).pose()
	var feet := Vector3(WALL - 0.4, 1.5, 0.0)
	var wanted := _leaning(feet, 17.0)
	assert_eq(EyeHold.held(_walled(), pose, feet, wanted), wanted)
