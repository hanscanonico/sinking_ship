extends GutTest
## The sinking's effects stay bounded (SinkingFx): whatever storm of cues comes, the
## pools never grow; wreckage floats on the sea and drifts off, and lands and slides
## on open decks only; a soaked deck dries. And near the eye no effect stands between
## the player and a fight: low, small and faint.

const RunMatch := preload("res://tools/run_match.gd")

const STORM_STEPS := 40
const CUES_PER_KIND := 30
## The match whose waterlines are walked, every this many seconds, by an eye on every
## deck the sea crosses, standing every this many metres.
const WALKED_SEED := 42
const WALK_EVERY := 4.0
const WALK_STRIDE := 2.0
## An eye in the sea looks out from this high over it.
const SWIMMING_EYE := 0.4
const EPSILON := 0.001


## [param count] cues of every kind, strewn round the ship.
func _storm(count: int, tick: int) -> Array[FxCue]:
	var cues: Array[FxCue] = []
	for kind: int in FxCue.Kind.size():
		for index in count:
			var at := Vector3(index * 0.7 - 10.0, 2.0, (index % 5) - 2.0)
			var cue := FxCue.new(kind as FxCue.Kind, tick, at)
			cue.end = at + Vector3(0.0, -2.0, 8.0)
			cue.radius = 2.0
			cue.seconds = 3.0
			cue.toward = Vector3.BACK
			cue.piece = (index % FxCue.Piece.size()) as FxCue.Piece
			cues.append(cue)
	return cues


func test_a_storm_of_cues_never_grows_the_pools() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var nodes := fx.find_children("*", "", true, false).size()
	var emitters := fx.emitters()
	var grains := 0
	for emitter: CPUParticles3D in emitters:
		grains += emitter.amount
	assert_lte(grains, SinkingFx.GRAIN_BUDGET, "every grain is in the budget")
	for step in STORM_STEPS:
		fx.play(_storm(CUES_PER_KIND, step), Transform3D(), null)
		await get_tree().process_frame
	assert_eq(fx.find_children("*", "", true, false).size(), nodes, "no node was added")
	assert_eq(fx.emitters().size(), emitters.size())
	var drawn := 0
	for emitter: CPUParticles3D in fx.emitters():
		drawn += emitter.amount
	assert_eq(drawn, grains, "no emitter draws more grains than it did")
	assert_lte(fx.flotsam_count(), Flotsam.CAP)
	assert_eq(fx.flotsam_count(), Flotsam.CAP, "the storm filled every piece")
	assert_lte(fx.debris_count(), DeckDebris.CAP)
	var washing := fx.emitters().filter(
		func(emitter: CPUParticles3D) -> bool: return emitter.emitting
	)
	assert_gt(washing.size(), 0, "the storm plays")

	fx.clear()
	assert_eq(fx.flotsam_count(), 0, "a new match starts with none")
	for emitter: CPUParticles3D in fx.emitters():
		assert_false(emitter.emitting, "and nothing going")


func test_wreckage_comes_down_on_the_sea_and_drifts_away() -> void:
	var flotsam: Flotsam = add_child_autofree(Flotsam.new())
	var splashes: Array[Vector3] = []
	flotsam.landed.connect(func(at: Vector3, _strength: float) -> void: splashes.append(at))
	flotsam.throw(FxCue.Piece.PLANK, Vector3(0.0, 5.0, 0.0), Vector3(0.0, 0.0, 6.0), Vector2.DOWN)
	assert_eq(flotsam.afloat().size(), 0, "in the air at first")
	for _frame in 60:
		flotsam.advance(1.0 / 30.0)
	assert_eq(splashes.size(), 1, "one splash as it lands")
	assert_almost_eq(splashes[0], Vector3(0.0, 0.0, 6.0), Vector3.ONE * 0.05, "where it was sent")
	var afloat := flotsam.afloat()
	assert_eq(afloat.size(), 1)
	assert_eq(afloat[0].y, 0.0, "on the sea plane")
	var landed_at := afloat[0]
	for _frame in 300:
		flotsam.advance(1.0 / 30.0)
	var drifted := flotsam.afloat()[0]
	assert_gt(drifted.z, landed_at.z + 0.5, "drifting on away from the hull")
	assert_lt(drifted.z, landed_at.z + Flotsam.DRIFT * 10.0, "slowly")

	for index in Flotsam.CAP * 3:
		flotsam.throw(FxCue.Piece.CRATE, Vector3.UP, Vector3(index, 0.0, 8.0), Vector2.DOWN)
	assert_eq(flotsam.count(), Flotsam.CAP, "never more than its pieces")
	flotsam.clear()
	assert_eq(flotsam.count(), 0)


func test_a_deck_the_sea_reaches_is_soaked_then_dries() -> void:
	var layout := SimFixtures.steamer()
	var wetness := DeckWetness.new(layout, [&"bridge"])
	assert_false(&"bridge" in _names(layout, wetness.platforms), "a deck that falls is not tracked")
	var main_deck := wetness.platforms.find(0)
	# Heeled to port with the port edge of the main deck (z = -5) just under the sea.
	var heel := Basis(Vector3.RIGHT, deg_to_rad(-10.0))
	var dipped := Transform3D(heel, Vector3(0.0, 5.0 * sin(deg_to_rad(10.0)) - 0.05, 0.0))
	var changed := wetness.update(dipped, 0.2)
	assert_has(changed, main_deck)
	assert_true(wetness.shows(main_deck))
	assert_eq(wetness.wetness(main_deck, 0.0, -4.6), 1.0, "the low edge is soaked")
	assert_eq(wetness.wetness(main_deck, 0.0, -1.0), 0.0, "the deck up the slope is dry")
	assert_eq(wetness.picture(main_deck).get_pixel(28, 0).r, 1.0, "and drawn so")

	var level := Transform3D(Basis(), Vector3(0.0, 3.4, 0.0))
	wetness.update(level, DeckWetness.DRY_SECONDS * 0.5)
	assert_almost_eq(wetness.wetness(main_deck, 0.0, -4.6), 0.5, 0.001, "drying")
	wetness.update(level, DeckWetness.DRY_SECONDS)
	assert_eq(wetness.wetness(main_deck, 0.0, -4.6), 0.0, "dry again")
	assert_false(wetness.shows(main_deck), "nothing to draw")


func _names(layout: ShipLayout, platforms: PackedInt32Array) -> Array[StringName]:
	var names: Array[StringName] = []
	for index: int in platforms:
		names.append(layout.platforms[index].name)
	return names


func test_spray_soaks_the_deck_round_where_it_bursts() -> void:
	var layout := SimFixtures.steamer()
	var wetness := DeckWetness.new(layout)
	var main_deck := wetness.platforms.find(0)
	wetness.soak(Vector3(0.0, 0.0, -5.0), 1.0)
	var level := Transform3D(Basis(), Vector3(0.0, 3.4, 0.0))
	assert_true(wetness.update_one(main_deck, level, 0.0), "drawn as it next updates")
	assert_eq(wetness.wetness(main_deck, 0.2, -4.7), 1.0, "soaked where it came down")
	assert_eq(wetness.wetness(main_deck, 3.0, -4.7), 0.0, "dry a few metres off")
	assert_eq(wetness.wetness(wetness.platforms.find(3), 0.0, 0.0), 0.0, "and on no deck above")


func test_a_waterline_is_split_where_it_passes_near_the_eye() -> void:
	var eye := Vector3(0.0, 1.6, 0.0)
	var reach := SinkingFx.HUSHED
	var past := SinkingFx.near_share(Vector3(-20.0, 0.0, 2.0), Vector3(20.0, 0.0, 2.0), eye, reach)
	var half := sqrt(reach * reach - 1.6 * 1.6 - 2.0 * 2.0)
	assert_almost_eq(past.x, (20.0 - half) / 40.0, EPSILON, "near from where it comes within reach")
	assert_almost_eq(past.y, (20.0 + half) / 40.0, EPSILON, "to where it leaves it")
	var far := SinkingFx.near_share(Vector3(-5.0, 0.0, 9.0), Vector3(5.0, 0.0, 9.0), eye, reach)
	assert_gte(far.x, far.y, "none of a line out of reach")
	var near := SinkingFx.near_share(Vector3(-2.0, 0.0, 1.0), Vector3(2.0, 0.0, 1.0), eye, reach)
	assert_eq(near, Vector2(0.0, 1.0), "all of a line within it")


func test_white_water_near_the_eye_stays_under_the_knees() -> void:
	var sim := MatchSim.create(RunMatch.default_config(WALKED_SEED))
	var planner := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	var layout := sim.config.ship
	var foamed := 0
	var stride := Ticks.from_seconds(WALK_EVERY)
	for tick in range(Ticks.from_seconds(60.0), sim.schedule.cap_tick(), stride):
		var cues := planner.plan(_at(sim, tick - 1), _at(sim, tick))
		var pose := sim.schedule.pose_at(tick)
		for wash: FxCue in cues.filter(
			func(cue: FxCue) -> bool: return cue.kind == FxCue.Kind.WASH
		):
			var platform := _platform_at(layout, wash.position)
			var area := platform.area
			for x in range(ceili(area.size.x / WALK_STRIDE) + 1):
				for z in range(ceili(area.size.y / WALK_STRIDE) + 1):
					var feet := Vector3(
						minf(area.position.x + x * WALK_STRIDE, area.end.x),
						platform.height,
						minf(area.position.y + z * WALK_STRIDE, area.end.y)
					)
					var eye := pose.transform * (feet + Vector3.UP * FirstPersonCamera.EYE_HEIGHT)
					if pose.world_height(feet) < 0.0:
						eye.y = SWIMMING_EYE
					camera.global_position = eye
					fx.clear()
					fx.play(cues, pose.transform, camera)
					foamed += _assert_hushed(fx, eye)
	assert_gt(foamed, 0, "the sea at the feet still shows, as low foam")


func test_effects_near_the_eye_are_low_small_and_faint() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	var eye := camera.global_position
	for kind: FxCue.Kind in [
		FxCue.Kind.SPRAY, FxCue.Kind.SPLASH, FxCue.Kind.VENT, FxCue.Kind.DUST, FxCue.Kind.STEAM
	]:
		for distance: float in [1.6, 3.0, 5.0, 7.5]:
			var cue := FxCue.new(kind, 0, Vector3(0.4, 0.0, -distance))
			cue.on_sea = kind == FxCue.Kind.SPRAY or kind == FxCue.Kind.SPLASH
			cue.rise = FxPlanner.PLUNGE_RISE
			cue.radius = 0.6
			cue.seconds = 3.0
			cue.toward = Vector3(0.0, 2.0, 1.0).normalized()
			if kind == FxCue.Kind.VENT:
				cue.position.y = 1.0
				cue.toward = Vector3.BACK
			var played := _played(fx, [cue], camera)
			var name := "%s %.1f m off" % [FxCue.Kind.keys()[kind], distance]
			assert_eq(played.size(), 1, name + " plays")
			for emitter: CPUParticles3D in played:
				if cue.on_sea:
					var top := emitter.global_position.y + _climb(emitter)
					var under := maxf(SinkingFx.knee(eye), SinkingFx.LEAST_TOP)
					assert_lte(top, under + EPSILON, name + ": under the knees")
				var faint := _opacity(emitter) <= SinkingFx.HUSHED_ALPHA + EPSILON
				assert_true(_grain(emitter) <= SinkingFx.SPECK + EPSILON or faint, name)
	# Dust shaken down from the ceiling of the room the eye is in, all across it.
	var sift := FxCue.new(FxCue.Kind.SIFT, 0, Vector3(0.0, 2.6, 0.0))
	sift.end = Vector3(1.7, 0.0, 3.3)
	sift.radius = 2.6
	sift.room = 4
	var sifting := _played(fx, [sift], camera, 4)
	assert_eq(sifting.size(), 1, "dust sifts down in the eye's room")
	for emitter: CPUParticles3D in sifting:
		var faint := _opacity(emitter) <= SinkingFx.HUSHED_ALPHA + EPSILON
		assert_true(_grain(emitter) <= SinkingFx.SPECK + EPSILON or faint, "in specks")
	assert_eq(_played(fx, [sift], camera, 5).size(), 0, "none from a room the eye is not in")


func test_a_splash_climbs_no_higher_than_its_cue_lets_it() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var splash := FxCue.new(FxCue.Kind.SPLASH, 0, Vector3(3.0, -1.0, 2.0))
	splash.on_sea = true
	splash.strength = 1.0
	splash.rise = 0.6
	var played := _played(fx, [splash], null)
	assert_eq(played.size(), 1)
	var emitter := played[0]
	assert_lte(emitter.global_position.y + _climb(emitter), splash.rise + EPSILON, "under the deck")


func test_wreckage_rains_on_open_decks_and_before_the_eye() -> void:
	var layout := SimFixtures.steamer()
	var space := ShipSpace.new(layout)
	var debris: DeckDebris = add_child_autofree(DeckDebris.new())
	debris.setup(layout)
	var bridge := Vector3(-2.5, 4.7, 0.0)
	# On the poop deck, looking aft, away from the bridge.
	var eye := Vector3(-16.0, 1.2 + FirstPersonCamera.EYE_HEIGHT, 0.0)
	debris.rain(bridge, FxPlanner.DEBRIS_REACH, eye, Vector2.LEFT)
	assert_gt(debris.count(), DeckDebris.RAIN_ON_EYE, "a shower of it")
	var thrown := debris.count()
	for _frame in 120:
		debris.advance(1.0 / 30.0)
	var lying := debris.lying()
	assert_eq(lying.size(), thrown, "all of it down")
	var before_eye := 0
	for piece: Vector3 in lying:
		var deck := space.deck_under(Vector2(piece.x, piece.z), piece.y)
		assert_almost_eq(piece.y, deck + DeckDebris.PIECE.y * 0.5, EPSILON, "on the planks")
		assert_true(space.outdoors(piece + Vector3.UP * 0.3), "under the open sky")
		var off := Vector2(piece.x - eye.x, piece.z - eye.z)
		if off.dot(Vector2.LEFT) > 0.0 and off.length() < DeckDebris.BEFORE_EYE.y + 0.5:
			before_eye += 1
	assert_gt(before_eye, 0, "some before an eye looking away")
	for _frame in roundi((DeckDebris.REST + DeckDebris.SHRINK) * 30.0) + 2:
		debris.advance(1.0 / 30.0)
	assert_eq(debris.count(), 0, "then gone")


func test_loose_gear_slides_down_the_deck_clear_of_what_stands_on_it() -> void:
	var layout := SimFixtures.steamer()
	var space := ShipSpace.new(layout)
	var debris: DeckDebris = add_child_autofree(DeckDebris.new())
	debris.setup(layout)
	# The ship drawn afloat, its main deck its freeboard over the sea.
	debris.position = Vector3.UP * layout.freeboard
	var promenade := layout.platforms[0]
	var eye := Vector3(-10.0, FirstPersonCamera.EYE_HEIGHT, -4.0)
	debris.slide(promenade.area, promenade.height, Vector2.UP, eye, Vector2.RIGHT)
	assert_gt(debris.count(), 0, "gear sliding toward the low side")
	for _frame in roundi(DeckDebris.SLIDE_SECONDS * 30.0) + 2:
		debris.advance(1.0 / 30.0)
	for piece: Vector3 in debris.lying():
		assert_true(promenade.contains(piece.x, piece.z), "still on its deck")
		assert_true(space.outdoors(piece + Vector3.UP * 0.3), "never through a wall")


## [param sim]'s snapshot moved to [param tick], with no events.
func _at(sim: MatchSim, tick: int) -> Dictionary:
	var snapshot := sim.snapshot().duplicate()
	snapshot["tick"] = tick
	snapshot["phase"] = MatchState.Phase.LIVE
	snapshot["events"] = []
	return snapshot


## The platform whose edge ship point [param point] stands on.
func _platform_at(layout: ShipLayout, point: Vector3) -> ShipPlatform:
	for platform: ShipPlatform in layout.platforms:
		var edge := platform.area.grow(0.01)
		if absf(platform.height - point.y) < 0.01 and edge.has_point(Vector2(point.x, point.z)):
			return platform
	return null


## Checks every emitter of [param fx] going as seen from [param eye]: no rising
## white water within HUSHED of it, foam low on the planks, bursts near it under its
## knees; how many emitters of foam it checked.
func _assert_hushed(fx: SinkingFx, eye: Vector3) -> int:
	var foams := 0
	for emitter: CPUParticles3D in fx.emitters():
		if not emitter.emitting:
			continue
		var size := (emitter.mesh as QuadMesh).size.x if emitter.mesh is QuadMesh else 0.0
		var along := Vector3.ZERO
		if emitter.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX:
			along = emitter.global_basis.x * emitter.emission_box_extents.x
		var from := emitter.global_position - along
		var to := emitter.global_position + along
		var near := SinkingFx.nearest_on(from, to, eye).distance_to(eye) < SinkingFx.HUSHED
		if is_equal_approx(size, SinkingFx.WASH_DROPLET):
			assert_false(near, "no rising white water near the eye at %s" % eye)
		elif is_equal_approx(size, SinkingFx.FLECK):
			foams += 1
			var lift := emitter.global_position.y / emitter.global_basis.y.y
			assert_lte(lift + _climb(emitter), SinkingFx.KNEE + EPSILON, "foam lies low")
			assert_lte(_grain(emitter), SinkingFx.SPECK + EPSILON, "in flecks")
		elif is_equal_approx(size, SinkingFx.DROPLET) and near and _on_sea(emitter):
			var top := emitter.global_position.y + _climb(emitter)
			var under := maxf(SinkingFx.knee(eye), SinkingFx.LEAST_TOP)
			assert_lte(top, under + EPSILON, "spray near the eye under its knees")
	return foams


## Whether [param emitter] throws white water up off the sea, not air out of a door.
func _on_sea(emitter: CPUParticles3D) -> bool:
	return absf(emitter.global_position.y) < EPSILON


## The emitters of [param fx] that playing [param cues] to [param camera], in
## [param eye_room], set going.
func _played(
	fx: SinkingFx, cues: Array[FxCue], camera: Camera3D, eye_room := -1
) -> Array[CPUParticles3D]:
	fx.clear()
	fx.play(cues, Transform3D(), camera, eye_room)
	return fx.emitters().filter(func(emitter: CPUParticles3D) -> bool: return emitter.emitting)


## The most a grain of [param emitter] climbs over its emitter, in the emitter's own
## up: the depth it starts from, its flight, and its top edge.
func _climb(emitter: CPUParticles3D) -> float:
	var way := emitter.direction.normalized()
	var tilt := maxf(acos(clampf(way.y, -1.0, 1.0)) - deg_to_rad(emitter.spread), 0.0)
	var rising := maxf(cos(tilt), 0.0) * emitter.initial_velocity_max
	var pull := (emitter.global_basis.transposed() * emitter.gravity).y
	var life := emitter.lifetime
	var flight := rising * life + 0.5 * pull * life * life
	if pull < 0.0 and rising / -pull < life:
		flight = rising * rising / (-2.0 * pull)
	var start := 0.0
	if emitter.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX:
		start = emitter.emission_box_extents.y
	elif emitter.emission_shape == CPUParticles3D.EMISSION_SHAPE_SPHERE:
		start = emitter.emission_sphere_radius
	return start + maxf(flight, 0.0) + _grain(emitter) * 0.5


## How big a grain of [param emitter] grows, at most: the side of a square covering
## as much as it does, in metres.
func _grain(emitter: CPUParticles3D) -> float:
	var grown := 1.0
	if emitter.scale_amount_curve != null:
		grown = emitter.scale_amount_curve.sample(1.0)
	var size := (emitter.mesh as QuadMesh).size
	return sqrt(size.x * size.y) * emitter.scale_amount_max * grown


## How opaque a grain of [param emitter] is drawn at most, wherever it is.
func _opacity(emitter: CPUParticles3D) -> float:
	var peak := 0.0
	for colour: Color in emitter.color_ramp.colors:
		peak = maxf(peak, colour.a)
	return emitter.color.a * peak
