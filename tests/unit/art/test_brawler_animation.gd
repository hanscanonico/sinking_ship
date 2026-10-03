extends GutTest

const IDLE := BrawlerAnimation.Move.IDLE
const WALK := BrawlerAnimation.Move.WALK
const RUN := BrawlerAnimation.Move.RUN
const WINDUP := BrawlerAnimation.Move.WINDUP
const SHOVE := BrawlerAnimation.Move.SHOVE
const RECOVER := BrawlerAnimation.Move.RECOVER
const STAGGER := BrawlerAnimation.Move.STAGGER
const FALL := BrawlerAnimation.Move.FALL
const BRACE := BrawlerAnimation.Move.BRACE
const CHARGE := BrawlerAnimation.Move.CHARGE
const JUMP := BrawlerAnimation.Move.JUMP


func _entry(sim: MatchSim, seat: int = 0) -> Dictionary:
	return sim.snapshot()["seats"][seat]


func _move(entry: Dictionary, speed: float = 0.0) -> BrawlerAnimation.Move:
	return BrawlerAnimation.move_for(entry, speed)


func test_a_shove_poses_windup_shove_then_recovery_off_the_snapshot() -> void:
	var sim := SimFixtures.sim(1)
	var rules := sim.config.rules
	var windup := Ticks.from_seconds(rules.shove_windup)
	var active := Ticks.from_seconds(rules.shove_active)
	var recovery := Ticks.from_seconds(rules.shove_recovery)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	assert_eq(_move(_entry(sim)), IDLE)
	var moves: Array[BrawlerAnimation.Move] = []
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
	moves.append(_move(_entry(sim)))
	for _tick in windup + active + recovery:
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
		moves.append(_move(_entry(sim)))
	assert_eq(moves.count(WINDUP), windup)
	assert_eq(moves.count(SHOVE), active)
	assert_eq(moves.count(RECOVER), recovery)
	assert_eq(moves.back(), IDLE)


func test_a_landed_shove_flinches_the_shoved_for_its_stagger() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(0.9, 0.0, 0.0), 180.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3)
	var shoved := _entry(sim, 1)
	assert_gt(shoved["stagger"], 0, "the shove landed")
	var vel: Vector3 = shoved["vel"]
	assert_eq(_move(shoved, Vector2(vel.x, vel.z).length()), STAGGER, "not a run, though flung")
	while _entry(sim, 1)["stagger"] > 0:
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_ne(_move(_entry(sim, 1)), STAGGER)


func test_a_charge_and_a_brace_pose_off_the_snapshot() -> void:
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	SimFixtures.place(sim, 1, Vector3(-5.0, 0.0, 0.0))
	var frames := {
		0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE),
		1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.BRACE),
	}
	SimFixtures.step(sim, frames, Ticks.from_seconds(rules.charge_threshold) + 1)
	assert_eq(_move(_entry(sim, 0)), CHARGE, "held past the threshold")
	assert_eq(_move(_entry(sim, 1)), BRACE)
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)})
	assert_eq(_move(_entry(sim, 0)), SHOVE, "let go")
	assert_eq(_move(_entry(sim, 1)), IDLE)


func test_airborne_falls_whatever_else_holds() -> void:
	var entry := {
		"state": PlayerState.Body.AIRBORNE,
		"stagger": 5,
		"action": PlayerState.Action.ACTIVE,
		"jumped": false,
		"vel": Vector3(6.0, 1.0, 0.0),
	}
	assert_eq(_move(entry, 6.0), FALL)


func test_a_jump_springs_up_then_falls_then_lands() -> void:
	var sim := SimFixtures.sim(1)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
	var moves: Array[BrawlerAnimation.Move] = [_move(_entry(sim))]
	while _entry(sim)["state"] == PlayerState.Body.AIRBORNE:
		SimFixtures.step(sim, {0: SimFixtures.frame(0)})
		moves.append(_move(_entry(sim)))
	var top := moves.find(FALL)
	assert_eq(moves[0], JUMP, "off the ground")
	assert_gt(top, 1, "rising for a while")
	assert_eq(moves.slice(0, top).count(JUMP), top, "rising is the jump's own pose")
	assert_eq(moves.slice(top, moves.size() - 1).count(FALL), moves.size() - 1 - top, "then falls")
	assert_eq(moves.back(), IDLE, "and lands on its feet")


func test_feet_walk_then_run_with_speed() -> void:
	var entry := _entry(SimFixtures.sim(1))
	assert_eq(_move(entry, BrawlerAnimation.WALK_FROM * 0.5), IDLE)
	assert_eq(_move(entry, BrawlerAnimation.WALK_FROM), WALK)
	assert_eq(_move(entry, BrawlerAnimation.RUN_FROM), RUN)
	assert_almost_eq(BrawlerAnimation.rate(RUN, BrawlerAnimation.RUN_CLIP_SPEED), 1.0, 0.0001)
	assert_eq(BrawlerAnimation.rate(STAGGER, 9.0), 1.0, "only strides follow speed")


func test_every_move_names_a_clip_the_model_has() -> void:
	var model: Node = Brawler.MODEL.instantiate()
	var player: AnimationPlayer = model.get_node("AnimationPlayer")
	for move: BrawlerAnimation.Move in BrawlerAnimation.Move.values():
		var named: String = BrawlerAnimation.Move.keys()[move]
		assert_true(BrawlerAnimation.CLIPS.has(move), "a clip for %s" % named)
		assert_true(BrawlerAnimation.BLEND.has(move), "a blend for %s" % named)
		assert_true(player.has_animation(BrawlerAnimation.CLIPS[move]), "%s's clip" % named)
	model.free()


func test_a_hit_stop_squashes_and_springs_back() -> void:
	var held := BrawlerAnimation.squash(0.0)
	assert_lt(held.y, 1.0, "shorter while the stop holds")
	assert_gt(held.x, 1.0, "and wider")
	assert_eq(held.x, held.z)
	var halfway := BrawlerAnimation.squash(BrawlerAnimation.SQUASH_SECONDS * 0.5)
	assert_between(halfway.y, held.y, 1.0, "springing back")
	assert_eq(BrawlerAnimation.squash(BrawlerAnimation.SQUASH_SECONDS), Vector3.ONE, "and back")
	assert_eq(BrawlerAnimation.squash(INF), Vector3.ONE, "never stopped, never squashed")
