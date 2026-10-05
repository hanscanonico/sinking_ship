extends GutTest
## A brace's scuffs (BrawlMarks): soft to every edge — nothing of them a hard-edged
## sticker — over its brace's arc, reaching past the body where the floor runs on
## and shrinking back toward its own edge rather than through a wall or over a
## railing; drawn only on a flat floor out of the sea, never on a stair or under the
## water.


func test_the_scuffs_fade_out_to_every_edge_within_their_reach_and_arc() -> void:
	var rules := SimFixtures.rules()
	var half_arc := deg_to_rad(rules.brace_arc_deg)
	var mesh := BrawlMarks.scuffs(BrawlMarks.SCUFF_REACH, half_arc)
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var darkest := 0.0
	for index in points.size():
		var point := points[index]
		var alpha := colours[index].a
		darkest = maxf(darkest, alpha)
		assert_eq(point.y, 0.0, "flat on the floor")
		var reach := Vector2(point.x, point.z).length()
		assert_lte(reach, BrawlMarks.SCUFF_REACH + 0.0001, "never past their reach")
		var angle := absf(atan2(point.z, point.x))
		assert_lte(angle, half_arc + 0.0001, "over the brace's arc")
		if is_equal_approx(reach, BrawlMarks.SCUFF_REACH) or is_equal_approx(angle, half_arc):
			assert_eq(alpha, 0.0, "its edges fade out: %s" % point)
	assert_gt(darkest, 0.3, "and it shows")


func test_a_brace_scuffs_a_flat_dry_floor_alone() -> void:
	var sim := SimFixtures.sim(1, null, SimFixtures.steamer())
	var pose := sim.schedule.pose_at(0)
	var surfaces := sim.surfaces
	var feet := Vector3(-9.0, 0.0, -4.2)
	var entry: Dictionary = sim.snapshot()["seats"][0]
	entry["bracing"] = true
	entry["state"] = PlayerState.Body.GROUNDED
	entry["surface"] = surfaces.landing(feet)
	assert_true(BrawlMarks.scuffed(entry, feet, surfaces, pose), "on the main deck")
	var stair := entry.duplicate()
	stair["surface"] = surfaces.ramp_surface(0)
	assert_false(BrawlMarks.scuffed(stair, feet, surfaces, pose), "never on a stair")
	var unbraced := entry.duplicate()
	unbraced["bracing"] = false
	assert_false(BrawlMarks.scuffed(unbraced, feet, surfaces, pose))
	var swimming := entry.duplicate()
	swimming["state"] = PlayerState.Body.SWIMMING
	assert_false(BrawlMarks.scuffed(swimming, feet, surfaces, pose))
	var sunk := SimFixtures.scenario([[0.0, SimFixtures.steamer().freeboard + 0.4, 0.0, 0.0]])
	var awash := SimFixtures.sim(1, sunk, SimFixtures.steamer())
	assert_false(
		BrawlMarks.scuffed(entry, feet, awash.surfaces, awash.schedule.pose_at(0)),
		"never under the sea, however shallow"
	)


## On open deck the scuffs reach their full length; braced facing the deckhouse's
## wall, the railing at the deck's edge or the drop off the poop deck, they stop short
## of it, never shorter than the body's own radius.
func test_the_scuffs_stop_short_of_a_wall_and_a_railing() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1, null, SimFixtures.steamer())
	var surfaces := sim.surfaces
	var open := Vector3(-9.0, 0.0, 1.2)
	assert_eq(BrawlMarks.fitted(open, 0.0, surfaces.landing(open), surfaces, rules), 1.0)
	var walls := {
		"the deckhouse's aft wall": [Vector3(-7.35, 0.0, 1.2), 0.0, 0.45],
		"the port railing": [Vector3(-9.0, 0.0, -4.55), -PI * 0.5, 0.45],
		"the poop deck's forward edge": [Vector3(-14.45, 1.2, 0.0), 0.0, 0.45],
	}
	for wall: String in walls:
		var feet: Vector3 = walls[wall][0]
		var facing: float = walls[wall][1]
		var room: float = walls[wall][2]
		var fit := BrawlMarks.fitted(feet, facing, surfaces.landing(feet), surfaces, rules)
		assert_lt(fit * BrawlMarks.SCUFF_REACH, room, "short of %s" % wall)
		assert_gte(fit * BrawlMarks.SCUFF_REACH, rules.body_radius - 0.0001)
