class_name SinkingFxCheck
extends RefCounted
## `make art-lint`'s check of the sinking's effects (SinkingFx), through a whole
## match: their pools never grow, nothing they place is ever off the map, and no
## wreckage ever floats over a deck shallow enough to wade on — nothing afloat reads
## as a raft where the rules have a floor.

const RunMatch := preload("res://tools/run_match.gd")
const MATCH_SCENE := "res://scenes/match/match.tscn"
## The ticks stepped a frame as the sinking's effects are watched through the
## collapse check's match, which runs on through the plunge, to its end.
const EFFECTS_TICKS_PER_FRAME := 4


## The match of [param match_seed] with [param seats] seats, in the match scene under
## [param root], stepped to its end: [problems found, checks made].
static func check(root: Window, match_seed: int, seats: int) -> Array:
	var problems := PackedStringArray()
	var checks := 0
	var scene: MatchScene = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	scene.start(RunMatch.default_config(match_seed, seats), true, true)
	scene.set_paused(true)
	var driver: SimDriver = scene.get_node("SimDriver")
	var view: MatchView = scene.get_node("MatchView")
	var fx: SinkingFx = null
	for child: Node in scene.get_children():
		if child is SinkingFx:
			fx = child
	var sim := driver.client.sim
	var layout := sim.config.ship
	var wade := sim.config.rules.wade_depth
	var nodes := fx.find_children("*", "", true, false).size()
	var afloat := 0
	var rafts := {}
	var lost := {}
	while not driver.client.is_over():
		for _tick in EFFECTS_TICKS_PER_FRAME:
			driver.step()
		await root.get_tree().process_frame
		for emitter: CPUParticles3D in fx.emitters():
			if not emitter.global_position.is_finite() and not lost.has(emitter.name):
				lost[emitter.name] = driver.current["tick"]
		var pose := sim.schedule.pose_at(driver.current["tick"])
		var to_ship := view.ship_to_world().affine_inverse()
		for piece: Vector3 in fx.afloat():
			afloat += 1
			var on_ship := to_ship * piece
			for index in layout.platforms.size():
				var platform := layout.platforms[index]
				if not platform.area.has_point(Vector2(on_ship.x, on_ship.z)):
					continue
				var deck := Vector3(on_ship.x, platform.height, on_ship.z)
				if pose.world_height(deck) > -wade and not rafts.has(index):
					rafts[index] = driver.current["tick"]
	checks += 1
	if fx.find_children("*", "", true, false).size() != nodes:
		problems.append("art-lint: the sinking's effects grew their pools through a match")
	checks += 1
	if afloat == 0:
		problems.append("art-lint: no wreckage floated in seed %d" % match_seed)
	for index: int in rafts:
		checks += 1
		problems.append(
			(
				"art-lint: wreckage afloat over platform %d, a wadeable deck, at tick %d"
				% [index, rafts[index]]
			)
		)
	for emitter_name: String in lost:
		checks += 1
		problems.append(
			"art-lint: effect %s placed off the map at tick %d" % [emitter_name, lost[emitter_name]]
		)
	scene.queue_free()
	# The last check: the scene goes before the lint quits, or its pools leak.
	await root.get_tree().process_frame
	return [problems, checks]
