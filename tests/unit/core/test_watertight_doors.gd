extends GutTest
## The watertight doors (§5b.2, SH26): the ship slides them shut at the hit over
## their shut time, a jammed one stays open, and a shutting door is a sliding blocker
## that pushes anyone in its gap to the side their centre is on — then holds them
## there, as a wall does.

const FAST := "res://tests/fixtures/sinking/hits/fast.tres"
## The doorway in the engine room's after bulkhead: x of its wall, and its jamb's z.
const WALL_X := -3.0


## A steamer match of [param seats] struck by the fast hit, with [param jammed] doors
## jammed open.
func _sim(seats: int, jammed: Array[StringName] = []) -> MatchSim:
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	var hit: IcebergHit = (load(FAST) as IcebergHit).duplicate()
	hit.jammed = jammed
	scenario.explicit_hit = hit
	return SimFixtures.sim(seats, scenario, SimFixtures.steamer())


func test_doors_shut_over_their_shut_time_and_a_jammed_one_stays_open() -> void:
	var sim := _sim(1)
	var hit := sim.schedule.hit_tick()
	var shut_time := Ticks.from_seconds(20.0)
	assert_true(sim.schedule.pose_at(hit - 1).doors_shut.is_empty(), "open until the hit")
	var half := sim.schedule.pose_at(hit + shut_time / 2).doors_shut
	assert_almost_eq(half.get(&"wtd_engine", 0.0), 0.5, 0.01, "half shut halfway")
	assert_eq(sim.schedule.pose_at(hit + shut_time).doors_shut.get(&"wtd_engine", 0.0), 1.0)
	var jammed := _sim(1, [&"wtd_engine"] as Array[StringName])
	var later := jammed.schedule.pose_at(hit + shut_time).doors_shut
	assert_false(later.has(&"wtd_engine"), "jammed, it never moves")
	assert_eq(later.get(&"wtd_hold", 0.0), 1.0, "the other shuts")


func test_a_shutting_door_pushes_a_body_to_the_side_its_centre_is_on() -> void:
	var rules := SimFixtures.rules()
	for side: float in [1.0, -1.0]:
		var sim := _sim(2)
		var hit := sim.schedule.hit_tick()
		sim.state.tick = hit
		sim.state.phase = MatchState.Phase.LIVE
		# In the doorway, a hair to one side of the wall's line, in the leaf's path.
		var at := Vector3(WALL_X + side * 0.05, -2.6, -0.3)
		SimFixtures.place(sim, 0, at)
		SimFixtures.place(sim, 1, Vector3(-17.0, 1.2, 0.0))
		SimFixtures.step(sim, {}, Ticks.from_seconds(20.0) + 1)
		var body := sim.state.seats[0]
		# Pushed out of the leaf's path to its own side — and, the deck trimming as she
		# floods (SH27), free to slide on along it.
		assert_gte(
			(body.pos.x - WALL_X) * side, rules.body_radius - 0.02, "side %s: out of its way" % side
		)
		# Shut, it holds: walking at it, the body stays on its side.
		var through := SimFixtures.frame(0, Vector2(-side, 0.0))
		SimFixtures.step(sim, {0: through}, Ticks.RATE)
		assert_gte((body.pos.x - WALL_X) * side, rules.body_radius - 0.02, "side %s: held" % side)


func test_a_shut_door_hides_and_stops_a_shove() -> void:
	var sim := _sim(2)
	var rules := SimFixtures.rules()
	var before := Vector3(WALL_X - 0.6, -2.6, 0.0)
	var behind := Vector3(WALL_X + 0.6, -2.6, 0.0)
	sim.surfaces.honour(sim.schedule.pose_at(0))
	assert_false(sim.surfaces.blocked(before, behind, rules.body_height, rules.step_height))
	var eyes := Vector3.UP * 1.6
	assert_true(sim.surfaces.line_of_sight(before + eyes, behind + eyes, sim.pose()))
	var shut := sim.schedule.pose_at(sim.schedule.hit_tick() + Ticks.from_seconds(30.0))
	sim.surfaces.honour(shut)
	assert_true(sim.surfaces.blocked(before, behind, rules.body_height, rules.step_height))
	assert_false(sim.surfaces.line_of_sight(before + eyes, behind + eyes, shut))
