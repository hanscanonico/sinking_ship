extends GutTest
## A local match is served — its seats' bots and the loopback between its host and its
## client (MatchScene.serve) — on a thread ahead of its start, as a liner's take seconds
## to make: served there it plays bit for bit as one served as it starts (D4), and the
## match scene plays the very match served for it rather than serving it again.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
## How long serving on a thread may take here, in seconds, and the beats each is played.
const PATIENCE := 60.0
const BEATS := 90


func _config() -> MatchConfig:
	var config := SimFixtures.config(4)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	return config


func test_a_match_served_on_a_thread_plays_as_one_served_here() -> void:
	var config := _config()
	var threaded: Array[MatchScene.Served] = []
	var task := WorkerThreadPool.add_task(
		func() -> void: threaded.append(MatchScene.serve(config, null))
	)
	await wait_until(func() -> bool: return WorkerThreadPool.is_task_completed(task), PATIENCE)
	WorkerThreadPool.wait_for_task_completion(task)
	assert_eq(threaded.size(), 1, "served on its thread")
	var here := MatchScene.serve(config, null)
	for _beat in BEATS:
		threaded[0].loopback.step()
		here.loopback.step()
	assert_eq(
		threaded[0].loopback.host.runner.digest.hex(),
		here.loopback.host.runner.digest.hex(),
		"the same match, beat for beat"
	)


func test_a_match_plays_as_it_was_served() -> void:
	var config := _config()
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var serving := MatchScene.serve(config, null)
	scene.served = serving
	scene.start(config, true)
	assert_same(scene._loopback, serving.loopback, "the match served, not served again")
	assert_null(scene.served, "taken")
	var other := MatchScene.serve(_config(), null)
	scene.served = other
	scene.start(config, true)
	assert_ne(scene._loopback, other.loopback, "another match's serving is not played")
