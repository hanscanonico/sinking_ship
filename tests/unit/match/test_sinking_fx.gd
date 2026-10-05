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
	# Bits of wreckage land on the steamer's decks, drawn afloat.
	var layout := SimFixtures.steamer()
	fx._debris.setup(layout)
	var afloat := Transform3D(Basis(), Vector3.UP * layout.freeboard)
	var nodes := fx.find_children("*", "", true, false).size()
	var emitters := fx.emitters()
	var grains := 0
	for emitter: CPUParticles3D in emitters:
		grains += emitter.amount
	assert_lte(grains, SinkingFx.GRAIN_BUDGET, "every grain is in the budget")
	for step in STORM_STEPS:
		fx.play(_storm(CUES_PER_KIND, step), afloat, null)
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
	assert_eq(fx.debris_count(), DeckDebris.CAP, "the storm filled every bit of wreckage")
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


func test_wreckage_afloat_over_a_deck_shallow_enough_to_wade_on_is_caught() -> void:
	var layout := SimFixtures.steamer()
	var wade := 0.3
	var main_deck := layout.platforms[0]
	var middle := main_deck.area.get_center()
	# The ship settled level until its main deck is awash, then deeper.
	var awash := Transform3D(Basis(), Vector3.DOWN * 0.1)
	var drowned := Transform3D(Basis(), Vector3.DOWN * 3.0)
	var beam := 0.0
	for platform: ShipPlatform in layout.platforms:
		beam = maxf(beam, platform.area.end.y)
	var over_deck := PackedVector3Array([Vector3(middle.x, 0.0, middle.y)])
	var outboard := PackedVector3Array([Vector3(middle.x, 0.0, beam + 2.0)])
	var raft := SinkingFxCheck.rafts_over(
		over_deck, awash, layout, ShipPose.new(0.1, 0.0, 0.0, awash), wade
	)
	assert_has(raft, 0, "a piece afloat over a deck the sea hardly covers reads as a raft")
	var deep := SinkingFxCheck.rafts_over(
		over_deck, drowned, layout, ShipPose.new(3.0, 0.0, 0.0, drowned), wade
	)
	assert_does_not_have(deep, 0, "over a deck well under the sea it is wreckage")
	var off := SinkingFxCheck.rafts_over(
		outboard, awash, layout, ShipPose.new(0.1, 0.0, 0.0, awash), wade
	)
	assert_eq(off.size(), 0, "and outboard of every deck, nothing to stand on")


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
					foamed += _assert_hushed(fx, eye, pose.transform.basis.y.normalized())
	assert_gt(foamed, 0, "the sea at the feet still shows, as low foam")


func test_effects_near_the_eye_are_low_small_and_faint() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	var eye := camera.global_position
	for kind: FxCue.Kind in [
		FxCue.Kind.SPRAY,
		FxCue.Kind.SPLASH,
		FxCue.Kind.VENT,
		FxCue.Kind.DUST,
		FxCue.Kind.STEAM,
		FxCue.Kind.RAIN,
		FxCue.Kind.DEBRIS,
	]:
		for distance: float in [1.6, 3.0, 5.0, 7.5]:
			var cue := FxCue.new(kind, 0, Vector3(0.4, 0.0, -distance))
			cue.on_sea = kind == FxCue.Kind.SPRAY or kind == FxCue.Kind.SPLASH
			cue.rise = FxPlanner.PLUNGE_RISE
			cue.radius = 0.6
			cue.seconds = 3.0
			cue.toward = Vector3(0.0, 2.0, 1.0).normalized()
			if kind == FxCue.Kind.VENT or kind == FxCue.Kind.DEBRIS:
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
				var faint := _near_opacity(emitter) <= SinkingFx.HUSHED_ALPHA + EPSILON
				assert_true(_grain(emitter) <= SinkingFx.SPECK + EPSILON or faint, name)
				if kind == FxCue.Kind.RAIN:
					assert_gt(_crosshair(emitter), 0.0, name + ": clear of the crosshair")
	# Dust shaken down from the ceiling of the room the eye is in, all across it.
	var sift := FxCue.new(FxCue.Kind.SIFT, 0, Vector3(0.0, 2.6, 0.0))
	sift.end = Vector3(1.7, 0.0, 3.3)
	sift.radius = 2.6
	sift.room = 4
	var sifting := _played(fx, [sift], camera, 4)
	assert_eq(sifting.size(), 1, "dust sifts down in the eye's room")
	for emitter: CPUParticles3D in sifting:
		var faint := _near_opacity(emitter) <= SinkingFx.HUSHED_ALPHA + EPSILON
		assert_true(_grain(emitter) <= SinkingFx.SPECK + EPSILON or faint, "in specks")
	assert_eq(_played(fx, [sift], camera, 5).size(), 0, "none from a room the eye is not in")
	var rain := FxCue.new(FxCue.Kind.RAIN, 0)
	assert_eq(
		_played(fx, [rain], camera, 4).size(), 0, "no spray rains through the deck over a room"
	)


func test_the_strike_near_the_eye_is_low_small_and_faint() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	var eye := camera.global_position
	var gash: Array[FxCue.Kind] = [
		FxCue.Kind.STRIKE, FxCue.Kind.SPURT, FxCue.Kind.MIST, FxCue.Kind.FROTH
	]
	for kind: FxCue.Kind in gash:
		for distance: float in [1.6, 3.0, 5.0, 7.5]:
			var cue := _gash_cue(kind, Vector3(0.4, 0.0, -distance))
			var played := _played(fx, [cue], camera)
			var name := "%s %.1f m off" % [FxCue.Kind.keys()[kind], distance]
			assert_eq(played.size(), 1, name + " plays")
			var emitter := played[0]
			var faint := _near_opacity(emitter) <= SinkingFx.HUSHED_ALPHA + EPSILON
			if kind == FxCue.Kind.STRIKE or kind == FxCue.Kind.SPURT:
				var top := emitter.global_position.y + _climb(emitter)
				var under := maxf(SinkingFx.knee(eye), SinkingFx.LEAST_TOP)
				assert_lte(top, under + EPSILON, name + ": under the knees")
				assert_true(_grain(emitter) <= SinkingFx.SPECK + EPSILON or faint, name)
			elif kind == FxCue.Kind.MIST:
				assert_true(faint, name + ": see-through")
			else:
				assert_true(_lying(emitter), name + ": lying on the sea")
				assert_almost_eq(emitter.global_basis.y, Vector3.UP, Vector3.ONE * EPSILON, name)
				assert_lte(emitter.global_position.y + _climb(emitter), SinkingFx.KNEE, name)
				assert_lte(_opacity(emitter), SinkingFx.SPECK_ALPHA + EPSILON, name)
	# Away from the eye, all of itself.
	var off := _played(fx, [_gash_cue(FxCue.Kind.MIST, Vector3(0.4, 0.0, -20.0))], camera)
	assert_eq(off[0].color.a, 1.0, "a mist out of reach of a fight stands out whole")


func test_the_strike_throws_from_emitters_the_bursts_after_it_never_take() -> void:
	var sim := MatchSim.create(RunMatch.default_config(38))
	var planner := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var afloat := Transform3D(Basis(), Vector3.UP * sim.config.ship.freeboard)
	var struck := sim.schedule.hit_tick()
	var strike := planner.plan(_at(sim, struck), _holed(sim, struck))
	fx.play(strike, afloat, null)
	var sheets := _going(fx, "Strike")
	var thrown := strike.filter(func(cue: FxCue) -> bool: return cue.kind == FxCue.Kind.STRIKE)
	assert_gt(thrown.size(), 1)
	assert_eq(sheets.size(), thrown.size(), "a sheet of the strike from each of its own")
	var placed: Array[Transform3D] = []
	for sheet: CPUParticles3D in sheets:
		placed.append(sheet.global_transform)
	var previous := _at(sim, struck + 1)
	for tick in range(struck + 2, struck + Ticks.from_seconds(GashPlanner.GASH_SECONDS)):
		var current := _at(sim, tick)
		var cues := planner.plan(previous, current)
		previous = current
		# And a storm of spray on top of the bursts after it, round the ship.
		for index in 3:
			var spray := FxCue.new(FxCue.Kind.SPRAY, tick, Vector3(tick % 20 - 10.0, 0.0, index))
			spray.on_sea = true
			spray.rise = 1.0
			cues.append(spray)
		fx.play(cues, afloat, null)
	for index in sheets.size():
		assert_true(sheets[index].emitting, "still going")
		assert_eq(sheets[index].global_transform, placed[index], "never thrown again")


func test_a_spurt_falls_back_whole_before_its_emitter_spurts_again() -> void:
	# Seed 30's gash, the biggest there is, spurts highest and longest.
	var sim := MatchSim.create(RunMatch.default_config(30))
	var planner := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var afloat := Transform3D(Basis(), Vector3.UP * sim.config.ship.freeboard)
	var struck := sim.schedule.hit_tick()
	fx.play(planner.plan(_at(sim, struck), _holed(sim, struck)), afloat, null)
	# Each spurt emitter's place and the tick it last spurted from there, and for how long.
	var placed := {}
	var spurted := 0
	var previous := _at(sim, struck + 1)
	for tick in range(struck + 2, struck + Ticks.from_seconds(GashPlanner.GASH_SECONDS) + 2):
		var current := _at(sim, tick)
		fx.play(planner.plan(previous, current), afloat, null)
		previous = current
		for spurt: CPUParticles3D in _going(fx, "Spurt"):
			var was: Array = placed.get(spurt.name, [])
			if not was.is_empty() and was[0] == spurt.global_transform:
				continue
			if not was.is_empty():
				var aloft := Ticks.from_seconds(was[2])
				assert_gte(tick - was[1], aloft, "%s spurted again mid-air" % spurt.name)
			placed[spurt.name] = [spurt.global_transform, tick, spurt.lifetime]
			spurted += 1
	assert_gt(spurted, GashFx.SPURTS, "every spurt emitter was taken again")


func test_the_strike_s_mist_climbs_over_her_rail_and_its_foam_lies_on_the_sea_thinning() -> void:
	# Seed 37's gash runs 0.75 to 0.86 m under the sea all along.
	var sim := MatchSim.create(RunMatch.default_config(37))
	var planner := FxPlanner.new(sim.config, sim.surfaces, sim.schedule)
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var afloat := Transform3D(Basis(), Vector3.UP * sim.config.ship.freeboard)
	var damage := sim.schedule.damage()
	var struck := sim.schedule.hit_tick()
	fx.play(planner.plan(_at(sim, struck), _holed(sim, struck)), afloat, null)
	var rail := sim.config.ship.freeboard + sim.config.rules.railing_height
	var mists := _going(fx, "Mist")
	assert_gt(mists.size(), 1, "mist all along it")
	for mist: CPUParticles3D in mists:
		var on_ship := afloat.affine_inverse() * mist.global_position
		assert_between(on_ship.x, damage.from_x, damage.to_x, "off the gash")
		assert_between(mist.global_position.y, 0.0, 1.0, "from the sea")
		assert_gt(_billowing(mist), rail + 1.0, "billowing up well over her rail")
	var froths := _going(fx, "Froth")
	assert_gt(froths.size(), 0, "foam on the sea along it")
	var thick := PackedFloat32Array()
	for froth: CPUParticles3D in froths:
		assert_true(_lying(froth))
		assert_almost_eq(froth.global_basis.y, Vector3.UP, Vector3.ONE * EPSILON, "on the sea")
		assert_between(froth.global_position.y, 0.0, 0.1, "lying on it")
		var on_ship := afloat.affine_inverse() * froth.global_position
		assert_between(on_ship.x, damage.from_x, damage.to_x, "along the gash")
		thick.append(froth.color.a)
	fx._gash.advance(afloat, GashPlanner.GASH_SECONDS * 0.6)
	for index in froths.size():
		assert_true(froths[index].emitting, "lying there for the gash's seconds")
		assert_lt(froths[index].color.a, thick[index] * 0.8, "thinning out")
	fx._gash.advance(afloat, GashPlanner.GASH_SECONDS * 0.5)
	for froth: CPUParticles3D in froths:
		assert_false(froth.emitting, "and gone")


func test_dust_sifts_from_the_ceiling_as_it_heels() -> void:
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	var sift := FxCue.new(FxCue.Kind.SIFT, 0, Vector3(0.0, 2.6, 0.0))
	sift.end = Vector3(1.7, 0.0, 3.3)
	sift.radius = 2.6
	sift.room = 4
	fx.play([sift], Transform3D(), camera, 4)
	var heeled := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0.0, -0.4, 0.0))
	fx.play([], heeled, camera, 4)
	var sifting := fx.emitters().filter(
		func(emitter: CPUParticles3D) -> bool: return emitter.emitting
	)
	assert_eq(sifting.size(), 1)
	var emitter: CPUParticles3D = sifting[0]
	assert_almost_eq(emitter.global_position, heeled * sift.position, Vector3.ONE * EPSILON)
	assert_almost_eq(emitter.global_basis.y, heeled.basis.y, Vector3.ONE * EPSILON, "heeled")
	var down := emitter.global_basis * emitter.direction
	assert_almost_eq(down, Vector3.DOWN, Vector3.ONE * EPSILON, "and falling straight down")


func test_an_eye_looking_straight_down_looks_along_the_ship() -> void:
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	camera.global_basis = Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	assert_eq(SinkingFx._looking(Transform3D(), camera), Vector2.RIGHT, "toward the bow")
	camera.global_basis = Basis(Vector3.RIGHT, deg_to_rad(90.0))
	assert_eq(SinkingFx._looking(Transform3D(), camera), Vector2.RIGHT, "and looking up")


func test_water_streams_down_the_deck_before_the_eye_lying_on_the_planks() -> void:
	var layout := SimFixtures.steamer()
	var fx: SinkingFx = add_child_autofree(SinkingFx.new())
	fx._debris.setup(layout)
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	var promenade := layout.platforms[0]
	# The ship drawn afloat, its main deck its freeboard over the sea; the eye on the
	# promenade by its inboard side, looking forward along it.
	var afloat := Transform3D(Basis(), Vector3.UP * layout.freeboard)
	camera.global_position = afloat * Vector3(-10.0, FirstPersonCamera.EYE_HEIGHT, -2.0)
	camera.look_at(camera.global_position + Vector3.RIGHT)
	var middle := promenade.area.get_center()
	var slide := FxCue.new(FxCue.Kind.SLIDE, 0, Vector3(middle.x, promenade.height, middle.y))
	slide.end = Vector3(promenade.area.size.x * 0.5, 0.0, promenade.area.size.y * 0.5)
	slide.toward = Vector3.FORWARD
	fx.play([slide], afloat, camera)
	var lying := fx.emitters().filter(
		func(emitter: CPUParticles3D) -> bool: return emitter.emitting and _lying(emitter)
	)
	assert_eq(lying.size(), 1, "a runnel down the planks")
	var runnel: CPUParticles3D = lying[0]
	var planks := afloat * Vector3(0.0, promenade.height, 0.0)
	assert_almost_eq(
		runnel.global_basis.y, Vector3.UP, Vector3.ONE * EPSILON, "in the deck's plane"
	)
	assert_between(runnel.global_position.y - planks.y, 0.0, SinkingFx.KNEE, "on the planks")
	assert_almost_eq(runnel.global_basis.z, Vector3.FORWARD, Vector3.ONE * EPSILON, "downhill")
	var on_ship := afloat.affine_inverse() * runnel.global_position
	assert_true(promenade.contains(on_ship.x, on_ship.z), "on the deck the eye stands on")


func test_every_grain_of_lace_shows_its_own_piece_of_one_sheet() -> void:
	var sheet := FxGrains.lace().get_image()
	var threads := _threads(sheet)
	var width := sheet.get_width()
	var height := sheet.get_height()
	# A sheet whose threads run on off every edge — no round patch cut out of a square.
	var edges := [0, 0, 0, 0]
	for along in width:
		edges[0] += threads[along]
		edges[1] += threads[(height - 1) * width + along]
	for down in height:
		edges[2] += threads[down * width]
		edges[3] += threads[down * width + width - 1]
	for edge: int in edges:
		assert_gt(edge, 0, "threads run off every edge of the sheet")
	var patch := FxGrains.laces(SinkingFx.LACE, FxGrains.lace())
	var window: Vector2 = (patch.material as ShaderMaterial).get_shader_parameter(&"window")
	assert_lt(window.x, 1.0, "a grain shows a piece of the sheet, not all of it")
	assert_lt(window.y, 1.0)


func test_water_streaming_down_the_planks_runs_in_threads_along_its_flow() -> void:
	var sheet := FxGrains.lace(FxAroundEye.RUNNEL_DRAWN).get_image()
	var threads := _threads(sheet)
	var width := sheet.get_width()
	var across := 0
	var along := 0
	for down in sheet.get_height():
		for at in width - 1:
			across += absi(threads[down * width + at + 1] - threads[down * width + at])
	for at in width:
		for down in sheet.get_height() - 1:
			along += absi(threads[(down + 1) * width + at] - threads[down * width + at])
	assert_gt(across, along * 2, "a line across the flow crosses far more threads")


func test_the_eye_s_effects_stop_when_cleared() -> void:
	var around: FxAroundEye = add_child_autofree(FxAroundEye.new(FxGrains.streak()))
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	around.rain(camera, 1.0, 5.0)
	around.drift(Vector3(0.0, 0.0, -10.0), camera)
	around.runnel(Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 4.0, 5.0)
	around.clear()
	for emitter: CPUParticles3D in around.emitters():
		assert_false(emitter.emitting, emitter.name)


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


## [param sim]'s snapshot of the step after the iceberg struck at [param tick].
func _holed(sim: MatchSim, tick: int) -> Dictionary:
	var snapshot := _at(sim, tick + 1)
	snapshot["events"] = [SimEvent.holed(tick).to_dict()]
	return snapshot


## A cue of the iceberg's strike, of [param kind], along 2 m of the sea from
## [param at], at its biggest.
func _gash_cue(kind: FxCue.Kind, at: Vector3) -> FxCue:
	var cue := FxCue.new(kind, 0, at)
	cue.end = at + Vector3(2.0, 0.0, 0.0)
	cue.on_sea = true
	cue.rise = GashPlanner.MIST_RISE.y
	cue.seconds = GashPlanner.GASH_SECONDS
	cue.toward = Vector3(0.0, 2.0, 1.0).normalized()
	if kind == FxCue.Kind.FROTH:
		cue.toward = Vector3.BACK
	return cue


## The emitters of [param fx] going whose names begin [param called].
func _going(fx: SinkingFx, called: String) -> Array[CPUParticles3D]:
	return fx.emitters().filter(
		func(emitter: CPUParticles3D) -> bool:
			return emitter.emitting and emitter.name.begins_with(called)
	)


## The highest the top of a billow of [param emitter] climbs, in the world: its
## fastest one flown as CPUParticles3D flies it — pulled, and slowed by its damping
## over its life — swelling as it goes.
func _billowing(emitter: CPUParticles3D) -> float:
	var step := 1.0 / 60.0
	var where := emitter.global_position + Vector3.UP * emitter.emission_box_extents.y
	var velocity := emitter.global_basis * emitter.direction.normalized()
	velocity *= emitter.initial_velocity_max
	var size := (emitter.mesh as QuadMesh).size.y * emitter.scale_amount_max
	var top := 0.0
	for frame in roundi(emitter.lifetime / step):
		var age := frame * step / emitter.lifetime
		var damping := emitter.damping_min
		if emitter.damping_curve != null:
			damping *= emitter.damping_curve.sample(age)
		velocity += emitter.gravity * step
		var speed := maxf(velocity.length() - damping * step, 0.0)
		velocity = velocity.normalized() * speed
		where += velocity * step
		top = maxf(top, where.y + size * emitter.scale_amount_curve.sample(age) * 0.5)
	return top


## The platform whose edge ship point [param point] stands on.
func _platform_at(layout: ShipLayout, point: Vector3) -> ShipPlatform:
	for platform: ShipPlatform in layout.platforms:
		var edge := platform.area.grow(0.01)
		if absf(platform.height - point.y) < 0.01 and edge.has_point(Vector2(point.x, point.z)):
			return platform
	return null


## Checks every emitter of [param fx] going as seen from [param eye], on a ship
## whose up is [param planks]: no rising white water within HUSHED of it, foam lying
## flat and faint on the planks, bursts near it under its knees, spray raining round
## it in specks; how many emitters of foam it checked.
func _assert_hushed(fx: SinkingFx, eye: Vector3, planks: Vector3) -> int:
	var foams := 0
	for emitter: CPUParticles3D in fx.emitters():
		if not emitter.emitting:
			continue
		var along := Vector3.ZERO
		if emitter.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX:
			along = emitter.global_basis.x * emitter.emission_box_extents.x
		var from := emitter.global_position - along
		var to := emitter.global_position + along
		var near := SinkingFx.nearest_on(from, to, eye).distance_to(eye) < SinkingFx.HUSHED
		if emitter.name.begins_with("Wash"):
			assert_false(near, "no rising white water near the eye at %s" % eye)
		elif _lying(emitter):
			foams += 1
			var lift := emitter.global_position.y / emitter.global_basis.y.y
			assert_lte(lift + _climb(emitter), SinkingFx.KNEE + EPSILON, "foam lies low")
			var flat := absf(emitter.global_basis.y.normalized().dot(planks))
			assert_almost_eq(flat, 1.0, EPSILON, "flat on the planks")
			assert_lte(_opacity(emitter), SinkingFx.SPECK_ALPHA + EPSILON, "and see-through")
		elif _thrown_up(emitter):
			if near and _on_sea(emitter):
				var top := emitter.global_position.y + _climb(emitter)
				var under := maxf(SinkingFx.knee(eye), SinkingFx.LEAST_TOP)
				assert_lte(top, under + EPSILON, "spray near the eye under its knees")
		elif emitter.name == "Rain":
			var faint := _near_opacity(emitter) <= SinkingFx.HUSHED_ALPHA + EPSILON
			var specks := _grain(emitter) <= SinkingFx.SPECK + EPSILON
			assert_true(specks or faint, "spray rains near the eye in specks, or faint")
			assert_lte(_opacity(emitter), SinkingFx.SPECK_ALPHA + EPSILON, "see-through ones")
			assert_gt(_crosshair(emitter), 0.0, "clear of the crosshair")
	return foams


## Per pixel of the lace [param sheet], row by row, 1 where a thread is drawn whole.
func _threads(sheet: Image) -> PackedByteArray:
	var threads := PackedByteArray()
	for down in sheet.get_height():
		for along in sheet.get_width():
			threads.append(1 if sheet.get_pixel(along, down).a > 0.5 else 0)
	return threads


## Whether [param emitter] throws white water or air up: a burst, or the iceberg's.
func _thrown_up(emitter: CPUParticles3D) -> bool:
	var called := String(emitter.name)
	return (
		called.begins_with("Burst") or called.begins_with("Strike") or called.begins_with("Spurt")
	)


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
## up: the depth it starts from, its flight, and its top edge, if it stands up.
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
	# A grain lying flat stands no higher than its middle.
	var top := 0.0 if _lying(emitter) else _grain(emitter) * 0.5
	return start + maxf(flight, 0.0) + top


## How big a grain of [param emitter] grows, at most, in metres: a streak drawn out
## along its flight, end to end; any other, the side of a square covering as much as
## it does.
func _grain(emitter: CPUParticles3D) -> float:
	var grown := 1.0
	if emitter.scale_amount_curve != null:
		# Its biggest at any age: white water grows as it flies, the strike's dwindles.
		for age in 11:
			grown = maxf(grown, emitter.scale_amount_curve.sample(age / 10.0))
	var size := _side(emitter)
	if emitter.particle_flag_align_y and emitter.mesh is QuadMesh:
		size = (emitter.mesh as QuadMesh).size.y
	return size * emitter.scale_amount_max * grown


## How opaque a grain of [param emitter] is drawn at most anywhere within HUSHED of
## the eye, its material fading it out as it nears (fx_grain.gdshaderinc).
func _near_opacity(emitter: CPUParticles3D) -> float:
	var material := emitter.mesh.surface_get_material(0) as ShaderMaterial
	if material == null:
		return _opacity(emitter)
	var from: float = material.get_shader_parameter(&"clear_from")
	var to: float = material.get_shader_parameter(&"clear_to")
	return _opacity(emitter) * smoothstep(from, to, SinkingFx.HUSHED)


## How far round the crosshair [param emitter]'s grains keep clear, as a share of the
## screen's height; 0 for none.
func _crosshair(emitter: CPUParticles3D) -> float:
	var material := emitter.mesh.surface_get_material(0) as ShaderMaterial
	var clear: Variant = material.get_shader_parameter(&"crosshair") if material else null
	return clear if clear is float else 0.0


## Whether [param emitter]'s grains lie flat in its plane.
func _lying(emitter: CPUParticles3D) -> bool:
	return emitter.mesh is QuadMesh and (emitter.mesh as QuadMesh).orientation == PlaneMesh.FACE_Y


## The side of a square covering as much as a grain of [param emitter] does as it is
## born; 0 for one that is not a quad.
func _side(emitter: CPUParticles3D) -> float:
	if not emitter.mesh is QuadMesh:
		return 0.0
	var size := (emitter.mesh as QuadMesh).size
	return sqrt(size.x * size.y)


## How opaque a grain of [param emitter] is drawn at most, wherever it is.
func _opacity(emitter: CPUParticles3D) -> float:
	var peak := 0.0
	for colour: Color in emitter.color_ramp.colors:
		peak = maxf(peak, colour.a)
	return emitter.color.a * peak
