class_name SinkingFx
extends Node3D
## The sinking as seen (D12). Every step the SimDriver takes, FxPlanner turns the two
## snapshots and the pose into cues, and they play here where the ship is drawn
## (MatchView.ship_to_world), the sea being the world plane y = 0 (D7): white water
## where the sea meets and climbs the decks — streaks thrown up and downwind, lace
## lying on the planks — splashes, air blown out of flooding rooms, billows of steam
## from the machinery and the funnel's smoke thickening, dust and splinters as a deck
## gives way and its bits raining on the decks round (DeckDebris), wreckage floating
## off (Flotsam), soaked planks drying (DeckWetness), and what shows round the eye
## wherever it looks (FxAroundEye).
##
## Near the eye an effect never stands between the player and a fight: within HUSHED
## of it, it is low, small and see-through — a thin line of foam at the feet tells the
## sea is there; past HUSHED it eases into its full self. Every effect comes from a
## pool of fixed size, so a storm of events never grows the tree; a burst beyond FAR,
## or well behind the eye, is not played. At the match's end nothing new starts and
## what runs winds down; a new match clears it all. Nothing it does reaches the sim.

## How many emitters of each kind, and how many grains each draws at most.
const BURSTS := 10
const WASHES := 3
const FOAMS := 2
const DUSTS := 4
const SPLINTER_BURSTS := 3
const CHUNK_FALLS := 2
const PLUMES := 3
const BOILS := 3
const BURST_GRAINS := 20
const WASH_GRAINS := 40
const FOAM_GRAINS := 40
const DUST_GRAINS := 22
const CLOUD_GRAINS := 44
const SIFT_GRAINS := 72
const SPLINTER_GRAINS := 16
const CHUNK_GRAINS := 10
const PLUME_GRAINS := 10
const BOIL_GRAINS := 32
const SMOKE_GRAINS := 28
const BELCH_GRAINS := 16
## Every grain the pools can draw at once.
const GRAIN_BUDGET := (
	BURSTS * BURST_GRAINS
	+ WASHES * WASH_GRAINS
	+ FOAMS * FOAM_GRAINS
	+ DUSTS * DUST_GRAINS
	+ CLOUD_GRAINS
	+ SIFT_GRAINS
	+ SPLINTER_BURSTS * SPLINTER_GRAINS
	+ CHUNK_FALLS * CHUNK_GRAINS
	+ PLUMES * PLUME_GRAINS
	+ BOILS * BOIL_GRAINS
	+ SMOKE_GRAINS
	+ BELCH_GRAINS
	+ FxAroundEye.GRAINS
)
## A burst further than FAR from the eye is not played, nor one further than BEHIND
## behind it; nor one within NEAR of it, which would fill the view.
const FAR := 90.0
const BEHIND := 12.0
const NEAR := 1.0
## Within HUSHED of the eye white water climbs no higher than KNEE over the floor
## under the eye (FirstPersonCamera.EYE_HEIGHT below it) — to LEAST_TOP over the sea,
## for an eye in the sea — and its grains are specks covering at most a SPECK-sided
## square, a streak no longer than SPECK end to end; any grain bigger than that is
## at most HUSHED_ALPHA as opaque as it would be. Past HUSHED an effect eases into
## its full self over HUSH_EASE.
const HUSHED := 8.0
const HUSH_EASE := 2.0
const KNEE := 0.45
const LEAST_TOP := 0.3
const SPECK := 0.25
const HUSHED_ALPHA := 0.35
## A speck of white water near the eye, small enough to stand in no one's way, is
## drawn this opaque at most.
const SPECK_ALPHA := 0.7
## A collapse rains its bits before an eye this near it.
const RAIN_SEEN := 30.0
## A room shaken by a lurch sifts its dust down for an eye that comes into it this
## long after.
const SHAKEN := 3.0
## A waterline's white water goes on this long after the last step that asked for
## it: none once the match is over. A piece of a line shorter than SHORTEST is not
## drawn.
const WASH_HOLD := 0.25
const SHORTEST := 0.3
## Steam and a boil die down to wisps for this long once their time at full is up.
const WISP_SECONDS := 6.0
## Spray soaks the decks this far round where it bursts, at full, in metres.
const SOAK := 2.5
## The wet decks' overlay stands this far over the planks.
const WET_LIFT := 0.004
## Grain sizes, in metres: a streak of white water's, the side of a square as big as
## it, STREAK_ASPECT times as long as it is wide; a patch of lace foam's, across and
## along.
const DROPLET := 0.22
const WASH_DROPLET := 0.2
const STREAK_ASPECT := 5.0
const LACE := Vector2(0.5, 0.5)
const DUST_PUFF := 0.9
const CLOUD_PUFF := 2.0
## A streak of dust sifting down, across and along: thin enough that, grown, it
## covers no more than a SPECK would.
const MOTE := Vector2(0.036, 0.32)
const STEAM_PUFF := 2.0
const SMOKE_PUFF := 1.8
const BUBBLE := 0.16
const SPLINTER := Vector3(0.025, 0.025, 0.2)
const CHUNK := Vector3(1.2, 0.1, 0.22)
## How far foam rides over the planks.
const FOAM_LIFT := 0.05
## The funnel's smoke, bent over in the plunge, is blown this much harder along the
## way it leaves the funnel.
const BENT_WIND := 4.5
## Rising white water leans up the deck the sea climbs this much, and spreads over
## this much of it, either side of the waterline, at least and at most.
const CLIMB_LEAN := 0.4
const WASH_BREADTH := Vector2(0.18, 0.68)
## The most shafts a room's ceiling sifts its dust down in.
const SHAFTS := 8
## Water streams down a deck for as long as the plunge goes on sending gear sliding,
## down a run this long at least, in metres.
const RUNNEL_LEAST := 1.0
const RUNNEL_HOLD := FxPlanner.SLIDE_TICKS * Ticks.SECONDS_PER_TICK

const WET_SHADER := preload("res://scenes/match/wet_deck.gdshader")

var _driver: SimDriver
var _view: MatchView
## The ship's layout, and the step a room's floor is told from the deck by.
var _layout: ShipLayout
var _step := 0.0
var _planner: FxPlanner
var _wetness: DeckWetness
var _flotsam: Flotsam
var _debris: DeckDebris
var _around: FxAroundEye
## The billows' materials, lit by the scene's sun.
var _billows: Array[ShaderMaterial] = []
var _bursts: Array[CPUParticles3D] = []
var _next_burst := 0
## White water along the waterlines: WASHES rising, then FOAMS low; and the seconds
## each goes on without another step asking.
var _white: Array[CPUParticles3D] = []
var _white_left := PackedFloat32Array()
## The waterlines this step offered, nearest the eye first: WASHES places for rising
## white water, then FOAMS for low foam, each the cue's index, the share of its line
## from and to, and how far it lies from the eye; and how many of each were offered.
var _offers := PackedVector4Array()
var _offered := PackedInt32Array([0, 0])
var _dusts: Array[CPUParticles3D] = []
var _next_dust := 0
var _billow: CPUParticles3D
var _sift: CPUParticles3D
var _shafts := PackedVector3Array()
## Per room, by index in the layout: the last lurch's dust for it, how long it goes
## on sifting for an eye coming in, and the room the dust sifts in now, or -1.
var _shaken: Array[FxCue] = []
var _shaken_left := PackedFloat32Array()
var _sifting := -1
## Whether the eye stands in a room this step: what falls round it out on deck does
## not fall through the decks over it.
var _eye_indoors := false
var _splinters: Array[CPUParticles3D] = []
var _next_splinters := 0
var _chunks: Array[CPUParticles3D] = []
var _next_chunks := 0
## Steam plumes and boils: each one's emitter, where it stands — ship-local, or on
## the sea under it — and its seconds at full and of wisps left.
var _plumes: Array[CPUParticles3D] = []
var _boils: Array[CPUParticles3D] = []
var _plume_at := PackedVector3Array()
var _plume_on_sea := PackedByteArray()
var _plume_full := PackedFloat32Array()
var _plume_wisps := PackedFloat32Array()
var _boil_full := PackedFloat32Array()
var _boil_wisps := PackedFloat32Array()
var _smoke: CPUParticles3D
var _belch: CPUParticles3D
## The funnel's top, ship-local, how thick its smoke is, 0…1, and the way it leaves
## the funnel, ship-local.
var _funnel := Vector3(NAN, NAN, NAN)
var _smoke_level := 0.0
var _smoke_way := Vector3.UP
## Follows the ship as drawn: the wet decks' overlays and the debris hang from it.
var _decks: Node3D
var _wet_textures: Array[ImageTexture] = []
var _wet_overlays: Array[MeshInstance3D] = []
## The deck whose wetness the next step brings up to date.
var _next_wet := 0


# Built as it joins the tree: a scene instanced and freed unshown builds none of it.
func _ready() -> void:
	var streak := FxGrains.streak()
	var droplet := FxGrains.streaks(DROPLET, STREAK_ASPECT, streak)
	for index in BURSTS:
		var burst := _emitter(BURST_GRAINS, droplet, true, "Burst%d" % index)
		FxGrains.water(burst, 1.0)
		_bursts.append(burst)
	var wash_droplet := FxGrains.streaks(WASH_DROPLET, STREAK_ASPECT, streak)
	for index in WASHES:
		var wash := _emitter(WASH_GRAINS, wash_droplet, false, "Wash%d" % index)
		FxGrains.water(wash, 0.7)
		wash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		wash.direction = Vector3(0.0, 1.0, CLIMB_LEAN).normalized()
		wash.spread = 20.0
		_white.append(wash)
	var lace := FxGrains.lace()
	var patch := FxGrains.laces(LACE, lace)
	for index in FOAMS:
		var foam := _emitter(FOAM_GRAINS, patch, false, "Foam%d" % index)
		FxGrains.foam(foam)
		_white.append(foam)
	_white_left.resize(WASHES + FOAMS)
	_offers.resize(WASHES + FOAMS)
	var puff := FxGrains.billboard(DUST_PUFF, FxGrains.puff())
	for index in DUSTS:
		var dust := _emitter(DUST_GRAINS, puff, true, "Dust%d" % index)
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		dust.direction = Vector3.UP
		dust.spread = 180.0
		dust.gravity = Vector3(FxGrains.WIND.x, -0.25, FxGrains.WIND.z)
		dust.damping_min = 1.0
		dust.damping_max = 1.8
		dust.scale_amount_curve = FxGrains.growth(0.6, 2.2)
		dust.color_ramp = FxGrains.fade(ArtPalette.DUST, 0.12)
		_dusts.append(dust)
	var cloud := FxGrains.billboard(CLOUD_PUFF, FxGrains.puff())
	_billow = _emitter(CLOUD_GRAINS, cloud, true, "Cloud")
	FxGrains.cloud(_billow)
	var mote := FxGrains.billboard(MOTE.x, FxGrains.puff(), FxGrains.SPECK_CLEAR)
	mote.size = MOTE
	_sift = _emitter(SIFT_GRAINS, mote, true, "Sift")
	FxGrains.sifting(_sift)
	_shafts.resize(SHAFTS)
	var splinter := FxGrains.shaded(SPLINTER, ArtPalette.SPLINTER)
	for index in SPLINTER_BURSTS:
		_splinters.append(_emitter(SPLINTER_GRAINS, splinter, true, "Splinters%d" % index))
	var chunk := FxGrains.shaded(CHUNK, ArtPalette.DECK)
	for index in CHUNK_FALLS:
		var falling := _emitter(CHUNK_GRAINS, chunk, true, "Chunks%d" % index)
		# Wreckage coming down throws a shadow a body under it, looking away, sees.
		falling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_chunks.append(falling)
	var billow := FxGrains.shape(FxGrains.BILLOW_SIZE, FxGrains.BILLOW_BLOBS)
	var steam := FxGrains.billows(
		STEAM_PUFF,
		billow,
		ArtPalette.STEAM,
		ArtPalette.STEAM_SHADE,
		FxGrains.STEAM_GLOW,
		FxGrains.STEAM_CLEAR
	)
	for index in PLUMES:
		var plume := _emitter(PLUME_GRAINS, steam, false, "Steam%d" % index)
		FxGrains.plume(plume)
		_plumes.append(plume)
	var bubble := FxGrains.billboard(BUBBLE, FxGrains.blob(), FxGrains.CLEAR, FxGrains.BUBBLE_GLOW)
	for index in BOILS:
		var boil := _emitter(BOIL_GRAINS, bubble, false, "Boil%d" % index)
		FxGrains.boil(boil)
		_boils.append(boil)
	_plume_at.resize(PLUMES)
	_plume_on_sea.resize(PLUMES)
	_plume_full.resize(PLUMES)
	_plume_wisps.resize(PLUMES)
	_boil_full.resize(BOILS)
	_boil_wisps.resize(BOILS)
	var smoke := FxGrains.billows(
		SMOKE_PUFF, billow, ArtPalette.SMOKE_LIT, ArtPalette.SMOKE_SHADE, 1.0, FxGrains.CLEAR
	)
	_billows.append(steam.material)
	_billows.append(smoke.material)
	_smoke = _emitter(SMOKE_GRAINS, smoke, false, "Smoke")
	FxGrains.funnel_smoke(_smoke)
	_belch = _emitter(BELCH_GRAINS, smoke, true, "Belch")
	FxGrains.funnel_smoke(_belch)
	_around = FxAroundEye.new(streak)
	_around.name = "AroundEye"
	add_child(_around)
	_flotsam = Flotsam.new()
	_flotsam.name = "Flotsam"
	add_child(_flotsam)
	_flotsam.landed.connect(_on_landed)
	_decks = Node3D.new()
	_decks.name = "WetDecks"
	add_child(_decks)
	_debris = DeckDebris.new()
	_debris.name = "Debris"
	_decks.add_child(_debris)


## Shows the sinking of [param sim]'s match as [param driver] steps it, where
## [param view] draws the ship, lit from [param sun] (toward it, in the world), from
## a clean start.
func setup(driver: SimDriver, view: MatchView, sim: MatchSim, sun: Vector3) -> void:
	for material: ShaderMaterial in _billows:
		material.set_shader_parameter(&"sun", sun)
	if _driver != null:
		_driver.stepped.disconnect(_on_stepped)
	_driver = driver
	_view = view
	_layout = sim.config.ship
	_step = sim.config.rules.step_height
	_planner = FxPlanner.new(sim.config, sim.surfaces, sim.schedule)
	var falls: Array[StringName] = []
	for event: SinkEvent in sim.config.scenario.events:
		if event.kind == SinkEvent.Kind.COLLAPSE:
			falls.append(event.platform)
	_wetness = DeckWetness.new(sim.config.ship, falls)
	_build_decks(sim.config.ship)
	_debris.setup(sim.config.ship)
	clear()
	_driver.stepped.connect(_on_stepped)


## Stops every effect and takes away everything drawn.
func clear() -> void:
	for emitter: CPUParticles3D in _emitters():
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = false
	_white_left.fill(0.0)
	_shaken_left.fill(0.0)
	_sifting = -1
	_plume_full.fill(0.0)
	_plume_wisps.fill(0.0)
	_boil_full.fill(0.0)
	_boil_wisps.fill(0.0)
	_smoke_level = 0.0
	_smoke_way = Vector3.UP
	_funnel = Vector3(NAN, NAN, NAN)
	_next_wet = 0
	_flotsam.clear()
	_debris.clear()
	_around.clear()


## Plays [param cues] — FxPlanner's — with the ship drawn at [param ship], as seen
## by [param camera] (none: seen from everywhere) from the room [param eye_room], by
## index in the layout, or from none.
func play(cues: Array[FxCue], ship: Transform3D, camera: Camera3D, eye_room := -1) -> void:
	_decks.transform = ship
	_eye_indoors = eye_room >= 0
	_offered.fill(0)
	for index in cues.size():
		var cue := cues[index]
		if cue.kind == FxCue.Kind.WASH:
			_offer_wash(index, cue, ship, camera)
		elif cue.kind == FxCue.Kind.SIFT:
			_shake(cue)
		else:
			_play(cue, ship, camera)
	if eye_room >= 0 and eye_room < _shaken.size() and eye_room != _sifting:
		if _shaken_left[eye_room] > 0.0:
			_sifting = eye_room
			_sift_room(_shaken[eye_room], ship)
	if _sifting >= 0 and _sift.emitting:
		# Shaken down from a ceiling that heels on through the lurch.
		_place_sift(_shaken[_sifting], ship)
	for slot in _offered[0]:
		_lay_wash(_white[slot], _offers[slot], cues, ship)
		_white_left[slot] = WASH_HOLD
	for slot in _offered[1]:
		_lay_foam(_white[WASHES + slot], _offers[WASHES + slot], cues, ship)
		_white_left[WASHES + slot] = WASH_HOLD


## How much of itself an effect [param distance] from the eye shows: none of its
## height, size and opacity within HUSHED, all of it from HUSHED + HUSH_EASE on.
static func shown(distance: float) -> float:
	return clampf((distance - HUSHED) / HUSH_EASE, 0.0, 1.0)


## The height of the knees of an eye at [param eye], in the world.
static func knee(eye: Vector3) -> float:
	return eye.y - FirstPersonCamera.EYE_HEIGHT + KNEE


## The share, from and to, of the line [param from]–[param to] that lies within
## [param reach] of [param eye]; from past to when none does.
static func near_share(from: Vector3, to: Vector3, eye: Vector3, reach: float) -> Vector2:
	var along := to - from
	var off := from - eye
	var square := along.length_squared()
	if square < 0.0001:
		return Vector2(0.0, 1.0) if off.length() < reach else Vector2(1.0, 0.0)
	var half := along.dot(off)
	var gap := half * half - square * (off.length_squared() - reach * reach)
	if gap <= 0.0:
		return Vector2(1.0, 0.0)
	var root := sqrt(gap)
	return Vector2(maxf((-half - root) / square, 0.0), minf((-half + root) / square, 1.0))


## The point of the line [param from]–[param to] nearest [param eye].
static func nearest_on(from: Vector3, to: Vector3, eye: Vector3) -> Vector3:
	var along := to - from
	var square := along.length_squared()
	if square < 0.0001:
		return from
	return from + along * clampf((eye - from).dot(along) / square, 0.0, 1.0)


## Every emitter in the pools, the funnel's two among them.
func emitters() -> Array[CPUParticles3D]:
	return _emitters()


## Where every piece of wreckage afloat is, in the world.
func afloat() -> PackedVector3Array:
	return _flotsam.afloat()


## How many pieces of wreckage are out.
func flotsam_count() -> int:
	return _flotsam.count()


## How many bits of wreckage are out on the decks.
func debris_count() -> int:
	return _debris.count()


func _on_stepped(_events: Array[SimEvent]) -> void:
	var ship := _view.ship_to_world()
	var cues := _planner.plan(_driver.previous, _driver.current)
	# The room the eye is in, as the HUD names it: where its seat's feet stand.
	var eye_room := -1
	if _view.eye_seat() >= 0:
		var feet: Vector3 = _driver.current["seats"][_view.eye_seat()]["pos"]
		eye_room = _layout.room_at(feet, _step)
	play(cues, ship, get_viewport().get_camera_3d(), eye_room)
	if _wet_overlays.is_empty():
		return
	# One deck a step, round them all in turn, so no step pays for them all.
	var slot := _next_wet
	_next_wet = (_next_wet + 1) % _wet_overlays.size()
	var seconds := _wet_overlays.size() * Ticks.SECONDS_PER_TICK
	if _wetness.update_one(slot, ship, seconds):
		_wet_textures[slot].update(_wetness.picture(slot))
	_wet_overlays[slot].visible = _wetness.shows(slot)


func _process(delta: float) -> void:
	if _driver == null or _driver.current.is_empty():
		return
	var ship := _view.ship_to_world()
	_decks.transform = ship
	_flotsam.advance(delta)
	_debris.advance(delta)
	for index in _white.size():
		_white_left[index] -= delta
		if _white_left[index] <= 0.0 and _white[index].emitting:
			_white[index].emitting = false
	for room in _shaken_left.size():
		_shaken_left[room] -= delta
	_around.advance(delta)
	_advance_plumes(ship, delta, get_viewport().get_camera_3d())
	_advance_boils(delta)
	if not is_nan(_funnel.x):
		var top := ship * _funnel
		_smoke.global_position = top + Vector3.UP * 0.3
		_smoke.direction = ship.basis * _smoke_way
		_smoke.emitting = _smoke_level > 0.0 and top.y > 0.3


func _play(cue: FxCue, ship: Transform3D, camera: Camera3D) -> void:
	var at := ship * cue.position
	if cue.on_sea:
		at.y = 0.0
	var toward := (ship.basis * cue.toward).normalized()
	match cue.kind:
		FxCue.Kind.SPRAY, FxCue.Kind.SPLASH, FxCue.Kind.VENT:
			if cue.seat >= 0 and cue.seat == _view.eye_seat():
				return
			if cue.kind == FxCue.Kind.SPRAY and _wetness != null:
				_wetness.soak(cue.position, SOAK * cue.strength)
			var to := ship * cue.end
			if cue.on_sea:
				to.y = 0.0
			if _seen((at + to) * 0.5, maxf(at.distance_to(to) * 0.5, 1.0), camera):
				_water_burst(cue.kind, at, to, toward, cue.strength, cue.rise, camera)
		FxCue.Kind.DUST:
			if _seen(at, cue.radius * 2.0, camera):
				_dust(at, cue.radius, cue.strength, camera)
		FxCue.Kind.CLOUD:
			# It hangs for seconds: one behind the eye is there when it turns round.
			if _seen(at, cue.radius * 2.0, camera, FAR, FAR):
				_billow.global_position = at
				_billow.emission_sphere_radius = maxf(cue.radius * 0.5, 0.5)
				_billow.restart()
				_billow.emitting = true
		FxCue.Kind.DEBRIS:
			var eye := Vector3(NAN, NAN, NAN)
			var looking := Vector2.ZERO
			if camera != null and at.distance_to(camera.global_position) < RAIN_SEEN:
				eye = ship.affine_inverse() * camera.global_position
				looking = _looking(ship, camera)
				if not _eye_indoors:
					_around.drift(at, camera)
			_debris.rain(cue.position, cue.radius, eye, looking)
		FxCue.Kind.SLIDE:
			if camera != null:
				var eye := ship.affine_inverse() * camera.global_position
				var half := Vector2(cue.end.x, cue.end.z)
				var deck := Rect2(Vector2(cue.position.x, cue.position.z) - half, half * 2.0)
				var feet := eye.y - FirstPersonCamera.EYE_HEIGHT
				if deck.has_point(Vector2(eye.x, eye.z)) and absf(feet - cue.position.y) < 0.6:
					var downhill := Vector2(cue.toward.x, cue.toward.z)
					var looking := _looking(ship, camera)
					var run := _debris.slide(deck, cue.position.y, downhill, eye, looking)
					_stream(run, cue.position.y, downhill, ship)
		FxCue.Kind.SPLINTERS:
			if _seen(at, 2.0, camera):
				_splinter(at, cue.strength)
		FxCue.Kind.CHUNKS:
			if _seen(at, cue.end.length(), camera):
				_fall(at, ship.basis, cue.end, cue.radius)
		FxCue.Kind.FLOTSAM:
			# A piece from under the sea starts from the sea.
			var from := ship * cue.position
			from.y = maxf(from.y, 0.0)
			_flotsam.throw(cue.piece, from, ship * cue.end, Vector2(toward.x, toward.z))
		FxCue.Kind.STEAM:
			_start_plume(cue, ship, camera)
		FxCue.Kind.BUBBLES:
			_start_boil(at, cue.radius, cue.seconds)
		FxCue.Kind.SMOKE:
			_funnel = cue.position
			_smoke_way = cue.toward
			_show_smoke(cue.strength, toward)
		FxCue.Kind.BELCH:
			_belch.global_position = at + Vector3.UP * 0.3
			_belch.restart()
			_belch.emitting = true
		FxCue.Kind.RAIN:
			# Round a first-person eye out on deck only: the observer looks on from
			# outside.
			var first_person := _view == null or _view.eye_seat() >= 0
			if camera != null and first_person and not _eye_indoors:
				_around.rain(camera, cue.strength, WASH_HOLD)


## Whether a burst of [param radius] at [param at] is worth playing to
## [param camera]'s eye: not past [param far], not further than [param behind]
## behind it, not in its face.
func _seen(
	at: Vector3, radius: float, camera: Camera3D, far: float = FAR, behind: float = BEHIND
) -> bool:
	if camera == null:
		return true
	var from_eye := at - camera.global_position
	var distance := from_eye.length()
	if distance - radius > far or distance + radius < NEAR:
		return false
	var ahead := from_eye.dot(-camera.global_basis.z)
	return ahead >= 0.0 or distance - radius <= behind


## The way [param camera] looks, in the ship plane of a ship drawn at [param ship]:
## looking straight up or down, toward the bow (+x).
static func _looking(ship: Transform3D, camera: Camera3D) -> Vector2:
	var ahead := ship.basis.inverse() * -camera.global_basis.z
	var level := Vector2(ahead.x, ahead.z)
	return level.normalized() if level.length_squared() > 0.0001 else Vector2.RIGHT


## Water streaming down the clear [param run] gear slides down (DeckDebris.slide)
## the deck at [param height], along [param downhill] (ship plane, unit), on a ship
## drawn at [param ship]; and the planks it runs over soaked.
func _stream(run: Vector3, height: float, downhill: Vector2, ship: Transform3D) -> void:
	if run.z < RUNNEL_LEAST:
		return
	var start := Vector3(run.x, height + FOAM_LIFT, run.y)
	var way := Vector3(downhill.x, 0.0, downhill.y)
	var planks := ship.basis.y.normalized()
	_around.runnel(ship * start, ship.basis * way, planks, run.z, RUNNEL_HOLD)
	if _wetness != null:
		_wetness.soak(start + way * run.z * 0.5, run.z * 0.5)


## White water or air thrown out from [param at] — or along to [param to], a sheet —
## [param toward], climbing [param rise] over where it starts; near the eye low,
## small and faint.
func _water_burst(
	kind: FxCue.Kind,
	at: Vector3,
	to: Vector3,
	toward: Vector3,
	strength: float,
	rise: float,
	camera: Camera3D
) -> void:
	var burst := _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % BURSTS
	var shows := 1.0
	var top := rise
	if camera != null:
		var eye := camera.global_position
		shows = shown(nearest_on(at, to, eye).distance_to(eye))
		top = lerpf(minf(rise, maxf(knee(eye) - at.y, LEAST_TOP)), rise, shows)
	var depth := lerpf(0.08, 0.35, shows)
	# A grain is a streak along its flight, measured end to end: a grown one's length.
	var streak := DROPLET * sqrt(STREAK_ASPECT) * FxGrains.WATER_GROWN
	var grain := lerpf(SPECK, streak * (1.2 + strength), shows)
	var direction := toward
	burst.gravity = Vector3.DOWN * Flotsam.GRAVITY + FxGrains.downwind()
	if kind == FxCue.Kind.VENT:
		var force := lerpf(0.4, 1.0, strength) * lerpf(0.4, 1.0, shows)
		grain = lerpf(SPECK, streak * (1.3 + strength * 0.6), shows)
		burst.lifetime = 0.75
		direction = (toward + Vector3.UP * 0.35).normalized()
		burst.spread = 16.0
		burst.initial_velocity_min = 3.0 * force
		burst.initial_velocity_max = 6.5 * force
	else:
		if kind == FxCue.Kind.SPLASH:
			direction = Vector3.UP
		# Its highest grain's top no higher than top: the depth it starts from, its
		# climb and the grain's half together, the grain no bigger than a low top lets.
		top = maxf(top, 0.05)
		depth = minf(depth, top * 0.3)
		grain = minf(grain, top * 0.6)
		var speed := sqrt(2.0 * Flotsam.GRAVITY * (top - depth - grain * 0.5))
		burst.initial_velocity_min = speed * 0.45
		burst.initial_velocity_max = speed
		burst.lifetime = clampf(2.0 * speed / Flotsam.GRAVITY, 0.5, 2.0)
		burst.spread = 22.0 if kind == FxCue.Kind.SPRAY else 30.0
	var length := at.distance_to(to)
	var basis := Basis()
	if length > 0.05:
		var along := (to - at) / length
		basis = Basis(along, Vector3.UP, along.cross(Vector3.UP))
		burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		burst.emission_box_extents = Vector3(length * 0.5, depth, depth)
	else:
		burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		burst.emission_sphere_radius = depth
	burst.global_transform = Transform3D(basis, (at + to) * 0.5)
	burst.color = Color(1.0, 1.0, 1.0, lerpf(SPECK_ALPHA, 1.0, shows))
	burst.direction = basis.transposed() * direction
	burst.scale_amount_max = grain / streak
	burst.scale_amount_min = minf(0.6, burst.scale_amount_max)
	burst.restart()
	burst.emitting = true


## Puts the waterline of [param cue], this step's [param index]th, in the running
## for this step's white water: the part of it within HUSHED of the eye for low
## foam, the rest for rising white water; the nearest the eye of each, within FAR,
## are drawn.
func _offer_wash(index: int, cue: FxCue, ship: Transform3D, camera: Camera3D) -> void:
	if camera == null:
		_offer(false, Vector4(index, 0.0, 1.0, 0.0))
		return
	var from := _on_sea(ship * cue.position)
	var to := _on_sea(ship * cue.end)
	var eye := camera.global_position
	# Clipped so none of its breadth comes within HUSHED either.
	var near := near_share(from, to, eye, HUSHED + WASH_BREADTH.y)
	if near.x >= near.y:
		_offer(false, Vector4(index, 0.0, 1.0, nearest_on(from, to, eye).distance_to(eye)))
		return
	var into := from.lerp(to, near.x)
	var out_of := from.lerp(to, near.y)
	_offer(true, Vector4(index, near.x, near.y, nearest_on(into, out_of, eye).distance_to(eye)))
	if near.x > 0.0:
		_offer(false, Vector4(index, 0.0, near.x, into.distance_to(eye)))
	if near.y < 1.0:
		_offer(false, Vector4(index, near.y, 1.0, out_of.distance_to(eye)))


## Keeps [param entry] among the nearest offered for low foam ([param foam]) or for
## rising white water, as many as there are emitters for it.
func _offer(foam: bool, entry: Vector4) -> void:
	if entry.w > FAR:
		return
	var pool := 1 if foam else 0
	var base := WASHES if foam else 0
	var room := FOAMS if foam else WASHES
	var count := _offered[pool]
	var place := count
	while place > 0 and _offers[base + place - 1].w > entry.w:
		place -= 1
	if place >= room:
		return
	for index in range(mini(count, room - 1), place, -1):
		_offers[base + index] = _offers[base + index - 1]
	_offers[base + place] = entry
	_offered[pool] = mini(count + 1, room)


## [param point] on the sea plane.
static func _on_sea(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


## The share of a waterline [param offer] holds of its cue among [param cues], on
## a ship drawn at [param ship]: its two ends in the world.
static func _line(offer: Vector4, cues: Array[FxCue], ship: Transform3D) -> PackedVector3Array:
	var cue := cues[int(offer.x)]
	var from := _on_sea(ship * cue.position)
	var to := _on_sea(ship * cue.end)
	return PackedVector3Array([from.lerp(to, offer.y), from.lerp(to, offer.z)])


## Rising white water along the share of a waterline [param offer] holds — all of it
## at least HUSHED from the eye — leaning up the deck the sea climbs.
func _lay_wash(wash: CPUParticles3D, offer: Vector4, cues: Array[FxCue], ship: Transform3D) -> void:
	var cue := cues[int(offer.x)]
	var line := _line(offer, cues, ship)
	var length := line[0].distance_to(line[1])
	if length < SHORTEST:
		return
	var along := (line[1] - line[0]) / length
	var across := along.cross(Vector3.UP)
	if across.dot(ship.basis * cue.toward) < 0.0:
		along = -along
		across = -across
	wash.global_transform = Transform3D(Basis(along, Vector3.UP, across), (line[0] + line[1]) * 0.5)
	var breadth := lerpf(WASH_BREADTH.x, WASH_BREADTH.y, cue.strength)
	wash.emission_box_extents = Vector3(length * 0.5, 0.02, breadth)
	# A churning band along the line: thrown up hardly a metre, the harder the sea
	# climbs the higher.
	wash.initial_velocity_min = 0.8 + cue.strength
	wash.initial_velocity_max = 1.5 + cue.strength * 2.0
	wash.scale_amount_max = 1.0 + cue.strength
	wash.emitting = true


## Low foam along the share of a waterline [param offer] holds, near the eye: lace
## lying flat on the planks, sliding up them the way the sea climbs — the broader and
## faster the harder the sea climbs.
func _lay_foam(foam: CPUParticles3D, offer: Vector4, cues: Array[FxCue], ship: Transform3D) -> void:
	var cue := cues[int(offer.x)]
	var line := _line(offer, cues, ship)
	var length := line[0].distance_to(line[1])
	if length < SHORTEST:
		return
	var planks := ship.basis.y.normalized()
	var along := (line[1] - line[0]) / length
	var across := along.cross(planks).normalized()
	if across.dot(ship.basis * cue.toward) < 0.0:
		along = -along
		across = -across
	var middle := (line[0] + line[1]) * 0.5 + planks * FOAM_LIFT
	foam.global_transform = Transform3D(Basis(along, planks, across), middle)
	foam.emission_box_extents = Vector3(length * 0.5, 0.01, 0.15 + cue.strength * 0.55)
	foam.initial_velocity_min = 0.15
	foam.initial_velocity_max = 0.3 + cue.strength * 0.6
	foam.emitting = true


func _dust(at: Vector3, radius: float, strength: float, camera: Camera3D) -> void:
	var dust := _dusts[_next_dust]
	_next_dust = (_next_dust + 1) % DUSTS
	var shows := 1.0
	if camera != null:
		shows = shown(at.distance_to(camera.global_position) - radius)
	dust.global_position = at
	dust.color = Color(1.0, 1.0, 1.0, lerpf(HUSHED_ALPHA, 1.0, shows))
	dust.emission_sphere_radius = maxf(radius * 0.4, 0.1)
	dust.lifetime = 1.2 + strength * strength * 4.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.6 + strength * 3.6
	dust.scale_amount_min = 0.5 + radius * 0.2
	dust.scale_amount_max = 0.9 + radius * 0.5 * strength + strength
	dust.restart()
	dust.emitting = true


## Keeps the dust a lurch shakes down in the room [param cue] names, to sift down
## for an eye in it now or coming into it within SHAKEN.
func _shake(cue: FxCue) -> void:
	if cue.room < 0:
		return
	if cue.room >= _shaken.size():
		_shaken.resize(cue.room + 1)
		_shaken_left.resize(cue.room + 1)
	_shaken[cue.room] = cue
	_shaken_left[cue.room] = SHAKEN
	_sifting = -1


## Dust shaken down from the ceiling of the room [param cue] names, in shafts across
## all of it.
func _sift_room(cue: FxCue, ship: Transform3D) -> void:
	# Shafts on a grid over the ceiling, about 2 m apart, each nudged off it.
	var columns := clampi(roundi(cue.end.x / 1.0), 1, 4)
	var rows := clampi(roundi(cue.end.z / 1.0), 1, SHAFTS / columns)
	var count := 0
	for row in rows:
		for column in columns:
			var nudge := Vector2(sin(count * 2.3), cos(count * 1.7)) * 0.25
			var x := cue.end.x * (((column + 0.5) / columns) * 2.0 - 1.0 + nudge.x / columns)
			var z := cue.end.z * (((row + 0.5) / rows) * 2.0 - 1.0 + nudge.y / rows)
			_shafts[count] = Vector3(x, -0.05, z)
			count += 1
	_sift.emission_points = _shafts.slice(0, count)
	_place_sift(cue, ship)
	_sift.lifetime = clampf(cue.radius / 0.7, 2.0, 5.0)
	_sift.restart()
	_sift.emitting = true


## The sifting dust under the ceiling [param cue] names, on a ship drawn at
## [param ship], falling straight down.
func _place_sift(cue: FxCue, ship: Transform3D) -> void:
	_sift.global_transform = Transform3D(ship.basis, ship * cue.position)
	_sift.direction = ship.basis.transposed() * Vector3.DOWN


func _splinter(at: Vector3, strength: float) -> void:
	var burst := _splinters[_next_splinters]
	_next_splinters = (_next_splinters + 1) % SPLINTER_BURSTS
	burst.global_position = at
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.lifetime = 1.1
	burst.initial_velocity_min = 2.0 * lerpf(0.4, 1.0, strength)
	burst.initial_velocity_max = 5.5 * lerpf(0.4, 1.0, strength)
	burst.gravity = Vector3.DOWN * Flotsam.GRAVITY
	burst.angular_velocity_min = 240.0
	burst.angular_velocity_max = 720.0
	burst.restart()
	burst.emitting = true


## Wreckage falling from the deck at [param top], its half-extent [param half] along
## the ship's [param basis], [param drop] metres to the floor beneath — where it is
## gone, as the deck itself lies wrecked there.
func _fall(top: Vector3, basis: Basis, half: Vector3, drop: float) -> void:
	var falling := _chunks[_next_chunks]
	_next_chunks = (_next_chunks + 1) % CHUNK_FALLS
	falling.global_transform = Transform3D(basis, top)
	falling.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	falling.emission_box_extents = Vector3(half.x, 0.05, half.z)
	falling.direction = Vector3.UP
	falling.spread = 60.0
	falling.initial_velocity_min = 0.4
	falling.initial_velocity_max = 2.0
	falling.gravity = Vector3.DOWN * Flotsam.GRAVITY
	falling.lifetime = clampf(sqrt(2.0 * maxf(drop, 0.2) / Flotsam.GRAVITY) + 0.15, 0.35, 1.6)
	falling.angular_velocity_min = 90.0
	falling.angular_velocity_max = 360.0
	falling.restart()
	falling.emitting = true


func _start_plume(cue: FxCue, ship: Transform3D, camera: Camera3D) -> void:
	var index := _quietest(_plume_full, _plume_wisps)
	_plume_at[index] = cue.position
	_plume_on_sea[index] = 1 if cue.on_sea else 0
	_plume_full[index] = cue.seconds
	_plume_wisps[index] = WISP_SECONDS
	var plume := _plumes[index]
	plume.initial_velocity_min = 0.8 + cue.strength * 0.5
	plume.initial_velocity_max = 1.3 + cue.strength * 0.8
	plume.scale_amount_max = 1.0 + cue.strength * 0.5
	plume.emitting = _place_plume(index, ship, camera)


func _advance_plumes(ship: Transform3D, delta: float, camera: Camera3D) -> void:
	for index in PLUMES:
		var plume := _plumes[index]
		if not plume.emitting:
			continue
		if not _place_plume(index, ship, camera):
			plume.emitting = false
			continue
		if _plume_full[index] > 0.0:
			_plume_full[index] -= delta
			if _plume_full[index] <= 0.0:
				plume.initial_velocity_min = 0.4
				plume.initial_velocity_max = 0.8
				plume.scale_amount_max = 0.8
			continue
		_plume_wisps[index] -= delta
		if _plume_wisps[index] <= 0.0:
			plume.emitting = false


## Puts plume [param index] where its vent is on a ship drawn at [param ship], faint
## near [param camera]'s eye; whether it is out of the sea to go on.
func _place_plume(index: int, ship: Transform3D, camera: Camera3D) -> bool:
	var plume := _plumes[index]
	var at := ship * _plume_at[index]
	if _plume_on_sea[index] == 1:
		at.y = 0.0
	elif at.y < 0.0:
		# Steam does not come up through the sea: a vent under it falls quiet.
		return false
	plume.global_position = at
	if camera != null:
		var faint := lerpf(HUSHED_ALPHA, 1.0, shown(at.distance_to(camera.global_position)))
		if absf(plume.color.a - faint) > 0.02:
			plume.color = Color(1.0, 1.0, 1.0, faint)
	return true


func _start_boil(at: Vector3, radius: float, seconds: float) -> void:
	var index := _quietest(_boil_full, _boil_wisps)
	var boil := _boils[index]
	boil.global_position = Vector3(at.x, 0.04, at.z)
	boil.emission_ring_radius = maxf(radius, 0.5)
	boil.scale_amount_max = 1.2 + radius * 0.12
	boil.initial_velocity_max = 0.3
	_boil_full[index] = seconds
	_boil_wisps[index] = WISP_SECONDS
	boil.emitting = true


func _advance_boils(delta: float) -> void:
	for index in BOILS:
		var boil := _boils[index]
		if not boil.emitting:
			continue
		if _boil_full[index] > 0.0:
			_boil_full[index] -= delta
			continue
		boil.initial_velocity_max = 0.1
		_boil_wisps[index] -= delta
		if _boil_wisps[index] <= 0.0:
			boil.emitting = false


## The plume or boil that has least of its time left: one not going, else the
## nearest its end.
static func _quietest(full: PackedFloat32Array, wisps: PackedFloat32Array) -> int:
	var quietest := 0
	for index in full.size():
		var left := maxf(full[index], 0.0) + maxf(wisps[index], 0.0)
		var least := maxf(full[quietest], 0.0) + maxf(wisps[quietest], 0.0)
		if left < least:
			quietest = index
	return quietest


## The funnel's smoke at [param level], 0…1: none before the sinking is under way,
## then thicker, darker, bigger, faster and higher — a thin wisp of small billows at
## first; leaving the funnel [param way] (world), and bent over along it when it
## leans.
func _show_smoke(level: float, way: Vector3) -> void:
	_smoke_level = level
	_smoke.gravity = FxGrains.WIND + Vector3(way.x, 0.0, way.z) * BENT_WIND
	_smoke.color = Color(1.0, 1.0, 1.0, clampf(level * 1.4, 0.0, 1.0))
	_smoke.initial_velocity_min = 1.3 + level * 1.2
	_smoke.initial_velocity_max = 2.0 + level * 2.0
	_smoke.scale_amount_min = 0.3 + level * 1.1
	_smoke.scale_amount_max = 0.5 + level * 1.9


func _on_landed(at: Vector3, strength: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if _seen(at, 1.0, camera):
		var rise := lerpf(FxPlanner.SPLASH_RISE.x, FxPlanner.SPLASH_RISE.y, strength) * 0.7
		_water_burst(FxCue.Kind.SPLASH, at, at, Vector3.UP, strength * 0.6, rise, camera)


## An overlay per deck DeckWetness tracks, just over its planks, in the deck's own
## picture of its wetness.
func _build_decks(layout: ShipLayout) -> void:
	for overlay: MeshInstance3D in _wet_overlays:
		overlay.queue_free()
	_wet_overlays.clear()
	_wet_textures.clear()
	for slot in _wetness.platforms.size():
		var platform := layout.platforms[_wetness.platforms[slot]]
		var texture := ImageTexture.create_from_image(_wetness.picture(slot))
		var material := ShaderMaterial.new()
		material.shader = WET_SHADER
		material.set_shader_parameter("wetness", texture)
		var overlay := MeshInstance3D.new()
		overlay.name = "Wet%d" % _wetness.platforms[slot]
		overlay.mesh = _overlay(platform, _wetness.extent(slot))
		overlay.material_override = material
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlay.visible = false
		_decks.add_child(overlay)
		_wet_overlays.append(overlay)
		_wet_textures.append(texture)


## [param platform]'s area as a quad WET_LIFT over it, its UV running over
## [param extent] metres from its least corner.
static func _overlay(platform: ShipPlatform, extent: Vector2) -> ArrayMesh:
	var area := platform.area
	var height := platform.height + WET_LIFT
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for corner: Vector2 in [area.position, Vector2(area.end.x, area.position.y), area.end]:
		points.append(Vector3(corner.x, height, corner.y))
		uvs.append((corner - area.position) / extent)
	for corner: Vector2 in [area.position, area.end, Vector2(area.position.x, area.end.y)]:
		points.append(Vector3(corner.x, height, corner.y))
		uvs.append((corner - area.position) / extent)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _emitters() -> Array[CPUParticles3D]:
	var all: Array[CPUParticles3D] = []
	all.append_array(_bursts)
	all.append_array(_white)
	all.append_array(_dusts)
	all.append(_billow)
	all.append(_sift)
	all.append_array(_splinters)
	all.append_array(_chunks)
	all.append_array(_plumes)
	all.append_array(_boils)
	all.append(_smoke)
	all.append(_belch)
	all.append_array(_around.emitters())
	return all


## A pool's emitter of [param grains] grains of [param mesh], in the world, named
## [param called].
func _emitter(grains: int, mesh: Mesh, one_shot: bool, called: String) -> CPUParticles3D:
	var emitter := FxGrains.emitter(grains, mesh, one_shot)
	emitter.name = called
	emitter.visibility_range_end = FAR + 30.0
	add_child(emitter)
	return emitter
