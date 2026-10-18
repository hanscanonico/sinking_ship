extends GutTest
## The breach as seen from inside her (BreachFx, through SinkingFx): seeing it is the
## point (#148), so the jet hushes only right by the eye or where it is thrown at it and
## the boil never; the jet's drops get as far across the room as it is thrown; the boil
## domes up over the gash; and the welling, as every other effect, stays low, small and
## faint near the eye.

const EPSILON := 0.001


func test_the_breach_is_not_hushed_a_few_metres_from_the_eye() -> void:
	# Seeing the breach is the point (#148): a few metres off — anywhere in a room the size
	# of a stokehold — the jet and the boil stand out whole, in drops, not specks.
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	for kind: FxCue.Kind in [FxCue.Kind.JET, FxCue.Kind.BOIL]:
		for distance: float in [3.0, 5.0, 7.5]:
			# Thrown away from the eye, across the room.
			var cue := _breach_cue(kind, Vector3(-1.0, 0.3, -distance))
			var played := _played(fx, [cue], camera)
			var name := "%s %.1f m off" % [FxCue.Kind.keys()[kind], distance]
			assert_eq(played.size(), 1, name + " plays")
			assert_almost_eq(played[0].color.a, 1.0, EPSILON, name + ": whole")
			assert_gt(_grain(played[0]), SinkingFx.SPECK, name + ": drops, not specks")


func test_the_jet_hushes_only_right_by_the_eye_or_thrown_at_it() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	var near := _breach_cue(FxCue.Kind.JET, Vector3(-1.0, 0.3, -1.2))
	var at_the_eye := _breach_cue(FxCue.Kind.JET, Vector3(-1.0, 0.3, -5.0))
	at_the_eye.toward = Vector3.BACK
	at_the_eye.rise = 6.0
	for jet: FxCue in [near, at_the_eye]:
		var played := _played(fx, [jet], camera)
		assert_eq(played.size(), 1)
		var faint := _near_opacity(played[0]) <= SinkingFx.HUSHED_ALPHA + EPSILON
		assert_true(_grain(played[0]) <= SinkingFx.SPECK + EPSILON or faint, "hushed")
	var boil := _played(fx, [_breach_cue(FxCue.Kind.BOIL, Vector3(-1.0, 0.3, -1.2))], camera)
	assert_almost_eq(boil[0].color.a, 1.0, EPSILON, "the boil never hushes")


func test_the_jet_s_drops_cross_as_far_as_it_is_thrown() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	for strength: float in [0.1, 0.5, 1.0]:
		for rise: float in [1.5, 3.0, 8.0]:
			var cue := _breach_cue(FxCue.Kind.JET, Vector3(-1.0, 0.3, -20.0))
			cue.strength = strength
			cue.rise = rise
			cue.drop = 0.8
			var jet := _played(fx, [cue], null)[0]
			var name := "strength %.1f thrown %.1f m" % [strength, rise]
			var slowest := jet.lifetime * jet.initial_velocity_min
			assert_gte(slowest, rise - EPSILON, name + ": its slowest drops get across")
			var crossing := rise / jet.initial_velocity_max
			var fallen := 0.5 * -jet.gravity.y * crossing * crossing
			assert_almost_eq(fallen, cue.drop, 0.01, name + ": falling as far as it says")


func test_the_boil_domes_up_over_the_gash() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	var weak := _breach_cue(FxCue.Kind.BOIL, Vector3(-1.0, 0.3, -5.0))
	weak.strength = 0.1
	var hard := _breach_cue(FxCue.Kind.BOIL, Vector3(-1.0, 0.3, -5.0))
	var low := _climb(_played(fx, [weak], camera)[0])
	var high := _climb(_played(fx, [hard], camera)[0])
	assert_gt(low, 0.1, "a dome of white water even as the head goes")
	assert_gt(high, low, "standing higher the harder the sea comes in")
	assert_gt(high, 0.4, "seen across a room")


func test_welling_near_the_eye_is_low_small_and_faint() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	for distance: float in [1.6, 3.0, 5.0, 7.5]:
		var cue := _breach_cue(FxCue.Kind.WELL, Vector3(-1.0, 0.3, -distance))
		var played := _played(fx, [cue], camera)
		var name := "WELL %.1f m off" % distance
		assert_eq(played.size(), 1, name + " plays")
		var faint := _near_opacity(played[0]) <= SinkingFx.HUSHED_ALPHA + EPSILON
		assert_true(_grain(played[0]) <= SinkingFx.SPECK + EPSILON or faint, name)
		assert_lte(_climb(played[0]), SinkingFx.LEAST_TOP + EPSILON, name + ": low")


func test_the_sea_jets_in_while_its_cues_keep_it_up_and_the_rent_stays() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var ship := Transform3D(Basis(), Vector3.UP * 3.0)
	var rent := _breach_cue(FxCue.Kind.RENT, Vector3(-1.0, 0.3, -2.0))
	rent.radius = 0.2
	rent.toward = Vector3.FORWARD
	fx.play([rent, _breach_cue(FxCue.Kind.JET, Vector3(-1.0, 0.3, -2.0))], ship, null)
	var jets := _going(fx, "BreachJet")
	assert_eq(jets.size(), 1, "the sea jets in")
	var placed := jets[0].global_transform
	for beat in 4:
		await get_tree().process_frame
		fx.play([_breach_cue(FxCue.Kind.JET, Vector3(-1.0, 0.3, -2.0))], ship, null)
	assert_eq(_going(fx, "BreachJet").size(), 1, "the same jet goes on, its source's")
	assert_eq(_going(fx, "BreachJet")[0].global_transform, placed, "where it was")
	fx._breach.advance(ship, BreachFx.HOLD + 0.1)
	assert_eq(_going(fx, "BreachJet").size(), 0, "it stops once nothing keeps it up")
	assert_eq(fx._breach.rent_count(), 1, "the rent stays")
	fx.clear()
	assert_eq(fx._breach.rent_count(), 0, "a new match has none")


## A cue of the breach inside her, of [param kind], along 2 m of her side from
## [param at], at its hardest: the sea jetting in across, toward -z.
func _breach_cue(kind: FxCue.Kind, at: Vector3) -> FxCue:
	var cue := FxCue.new(kind, 0, at)
	cue.end = at + Vector3(2.0, 0.0, 0.0)
	cue.toward = Vector3(0.0, 0.0, -1.0)
	cue.radius = GashPlanner.JET_SHEET.y
	cue.rise = 3.0
	cue.source = 0
	return cue


func _played(
	fx: SinkingFx, cues: Array[FxCue], camera: Camera3D, eye_room := -1
) -> Array[CPUParticles3D]:
	return FxProbe.played(fx, cues, camera, eye_room)


func _climb(emitter: CPUParticles3D) -> float:
	return FxProbe.climb(emitter)


func _grain(emitter: CPUParticles3D) -> float:
	return FxProbe.grain(emitter)


func _near_opacity(emitter: CPUParticles3D) -> float:
	return FxProbe.near_opacity(emitter)


func _going(fx: SinkingFx, called: String) -> Array[CPUParticles3D]:
	return FxProbe.going(fx, called)
