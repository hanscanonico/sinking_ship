extends GutTest
## The first-person HUD asks each snapshot once (#410): a snapshot is shown frame after
## frame until the next tick's, and what it answers — her pose, the eyes' entry, the
## bodies seen from their piece, the Surfaces honoured with it — is the same every frame
## of it, so the dials, the plate, the crosshair and the prompts are drawn from it once,
## and only what moves with the eye is drawn every frame.


func test_a_snapshot_is_asked_once_and_again_only_once_it_changes() -> void:
	var sim := SimFixtures.sim(2)
	var answers := HudAnswers.new(sim)
	var snapshot := sim.snapshot()
	assert_true(answers.ask(snapshot, 0, [false]), "the first snapshot is asked")
	assert_false(answers.ask(snapshot, 0, [false]), "shown again, it is not")
	assert_true(answers.ask(snapshot, 1, [false]), "for another seat's eyes it is")
	assert_true(answers.ask(snapshot, 1, [true]), "and with anything else it was asked with")
	assert_false(answers.ask(snapshot, 1, [true]))
	snapshot["tick"] += 1
	assert_true(answers.ask(snapshot, 1, [true]), "the same dictionary a tick on is a new one")
	sim.step(_idle(sim))
	assert_true(answers.ask(sim.snapshot(), 1, [true]), "and so is the next tick's")


func test_its_answers_are_what_the_snapshot_says() -> void:
	var sim := SimFixtures.sim(2)
	var answers := HudAnswers.new(sim)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(3.0, 0.0, 0.0), 180.0)
	var snapshot := sim.snapshot()
	answers.ask(snapshot, 1)
	assert_true(answers.is_in)
	assert_same(answers.me, MatchState.entry_of(snapshot["seats"], 1), "the eyes' own entry")
	assert_same(answers.whole, sim.schedule.pose_at(snapshot["tick"]), "her pose at its tick")
	assert_same(answers.pose, answers.whole.of_piece(0))
	assert_eq(answers.framed["seats"][0]["pos"], Vector3.ZERO, "the bodies as it has them")
	var eye := Vector3.UP * 1.6
	var sees := sim.surfaces.line_of_sight(Vector3(3.0, 0.0, 0.0) + eye, eye, answers.pose)
	assert_eq(answers.sees(0, Vector3(3.0, 0.0, 0.0) + eye, eye, 1.6), sees)
	assert_eq(answers.ask({}, 1), true, "no snapshot is asked too")
	assert_false(answers.is_in, "and has no eyes in it")


func test_the_hud_draws_a_snapshot_once_and_the_eye_s_view_every_frame() -> void:
	var sim := SimFixtures.sim(2)
	var prompts := InputPrompts.new()
	add_child_autofree(prompts)
	var hud := FirstPersonHud.new()
	add_child_autofree(hud)
	hud.setup(sim, PackedStringArray(["A", "B"]), false, prompts)
	var drawn := [0, 0]
	(hud.get_node("Canvas") as Control).draw.connect(func() -> void: drawn[0] += 1)
	(hud.get_node("Live") as Control).draw.connect(func() -> void: drawn[1] += 1)
	var snapshot := sim.snapshot()
	for _frame in 3:
		hud.show_view(snapshot, 0, 0.0, null, null)
		await get_tree().process_frame
	assert_eq(drawn[0], 1, "one snapshot's dials and plate are drawn once")
	assert_eq(drawn[1], 3, "what moves with the eye, every frame")
	sim.step(_idle(sim))
	hud.show_view(sim.snapshot(), 0, 0.0, null, null)
	await get_tree().process_frame
	assert_eq(drawn[0], 2, "the next tick's snapshot is drawn anew")


func _idle(sim: MatchSim) -> Array[InputFrame]:
	var idle: Array[InputFrame] = []
	for seat in sim.config.seats:
		idle.append(InputFrame.new(seat, 0))
	return idle
