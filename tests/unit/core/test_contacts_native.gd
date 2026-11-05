extends GutTest
## The floating furniture's contacts natively (#410: NativeStands, NativeSurfaces,
## NativeCrates) against the GDScript they stand in for, bit for bit: on a made-up deck
## dense with edge cases — boxes, rounds and a wall flush with a deck over it, decks
## touching, a slab over a crawlway, ramps up and down either way, a spent railing and
## crates touching, stacked on lids and astride the grids' cells — and on her real ships,
## their doors half shut and a funnel down, every obstacle, railing and airborne-railing
## contact and every crate near a point, asked at corners, edges and a hair either side
## of them, at ±0 and from heights a step either side of every surface; then matches
## stepped tick by tick, one natively and one in GDScript, their snapshots byte for byte —
## a saloon's tables and chairs afloat as she settles and heels, and the steamer's crates
## sliding hard into railings that break. Where the extension is not loaded there is
## nothing to hold it to; CI sets SINKING_NATIVE_REQUIRED, so a missing library there
## fails.

const STEAMER := "res://data/ships/steamer.tres"
const SMALL_TITANIC := "res://data/ships/small_titanic.tres"
## How far either side of an edge a point is asked: float32's own step at her size, and
## more.
const HAIRS: Array[float] = [0.0, 1e-6, -1e-6, 1e-4, -1e-4, 0.05, -0.05]
## How many of a real ship's surfaces and crates are asked about.
const SURFACES_ASKED := 160
const CRATES_ASKED := 80
## Ticks the afloat saloons and the sliding crates are stepped.
const SALOON_TICKS := 150
const SLIDE_TICKS := 240

var _rng := RandomNumberGenerator.new()
var _differences: Array[String] = []
var _asked := 0


func before_each() -> void:
	_rng.seed = 410
	_differences.clear()
	_asked = 0
	ContactsNative.off = false


func after_each() -> void:
	ContactsNative.off = false


func test_a_made_up_deck_dense_with_edges_answers_alike() -> void:
	if not _loaded():
		return
	var layout := _made_up()
	var props := _standing(layout)
	# Crates touching side by side, one on another's lid, one astride a cell's corner.
	props[1].pos = props[0].pos + Vector3(layout.props[0].radius + layout.props[1].radius, 0, 0)
	props[2].pos = props[0].pos + Vector3(0, layout.props[0].height, 0)
	props[3].pos = Vector3(-0.0, 0.0, 2.0)
	props[4].body = PropState.Body.LOST
	var pose := _pose(0)
	pose.broken_railings = PackedInt32Array([1])
	_ask_all(layout, pose, props, range(_surface_count(layout)), range(props.size()))
	_assert_none("the made-up deck")


func test_a_collapsed_deck_and_its_railings_answer_alike() -> void:
	if not _loaded():
		return
	var layout := _made_up()
	var pose := _pose(0)
	pose.collapsed = [&"upper"] as Array[StringName]
	var props := _standing(layout)
	_ask_all(layout, pose, props, range(_surface_count(layout)), range(props.size()))
	_assert_none("the made-up deck, its upper deck gone")


func test_her_ships_answer_alike_doors_half_shut_and_a_funnel_down() -> void:
	if not _loaded():
		return
	for path: String in [STEAMER, SMALL_TITANIC]:
		var layout: ShipLayout = load(path)
		var pose := _pose(0)
		if layout.structure != null:
			for opening: ShipOpening in layout.structure.openings:
				if opening.shuts_at_hit:
					pose.doors_shut[opening.name] = _rng.randf_range(0.2, 1.0)
			for fitting: ShipFitting in layout.structure.fittings:
				if fitting.kind == ShipFitting.Kind.FUNNEL:
					var way := Vector2.from_angle(_rng.randf_range(0.0, TAU))
					pose.felled.append(FunnelFall.new(fitting, way, 0, 0, 0))
					break
		var props := _standing(layout)
		var surfaces := PackedInt32Array()
		for _pick in SURFACES_ASKED:
			surfaces.append(_rng.randi_range(0, _surface_count(layout) - 1))
		var crates := PackedInt32Array()
		for _pick in mini(CRATES_ASKED, props.size()):
			crates.append(_rng.randi_range(0, props.size() - 1))
		_ask_all(layout, pose, props, surfaces, crates)
		_assert_none(path)


func test_a_saloon_afloat_steps_alike_tick_by_tick() -> void:
	if not _loaded():
		return
	var layout: ShipLayout = load(SMALL_TITANIC)
	var lowest := INF
	for prop: ShipProp in layout.props:
		if prop.kind == &"dining_table":
			lowest = minf(lowest, prop.pos.y)
	# The sea up to her lowest saloon's tables' tops and rising, as she heels and trims: a
	# sink of her freeboard brings it to her deck's own height.
	var sea := layout.freeboard + lowest
	var scenario := (
		SimFixtures
		. scenario(
			[
				[0.0, sea + 0.6, 0.0, 0.0],
				[2.0, sea + 1.2, 1.0, 4.0],
				[6.0, sea + 2.5, 2.5, 9.0],
			]
		)
	)
	var afloat := _step_alike(layout, scenario, SALOON_TICKS, "the afloat saloon")
	assert_gt(afloat, 40, "most of a saloon's furniture afloat and moving")


func test_crates_sliding_into_railings_step_alike_as_they_break_them() -> void:
	if not _loaded():
		return
	var layout: ShipLayout = load(STEAMER)
	var scenario := SimFixtures.scenario([[0.0, -10.0, 0.0, 0.0], [1.0, -10.0, 6.0, 32.0]])
	_step_alike(layout, scenario, SLIDE_TICKS, "the steamer's sliding crates", true)


## Steps a match of 2 seats on [param layout] sunk as [param scenario] has her for
## [param ticks], natively and in GDScript, and notes any tick whose snapshots differ by a
## byte; the most crates it stepped in a tick. With [param breaks], a crate breaking a
## railing must happen.
func _step_alike(
	layout: ShipLayout, scenario: SinkScenario, ticks: int, what: String, breaks := false
) -> int:
	var native := SimFixtures.sim(2, scenario, layout)
	ContactsNative.off = true
	var reference := SimFixtures.sim(2, scenario, layout)
	ContactsNative.off = false
	assert_not_null(native._hazards._native_passes(), "%s steps natively" % what)
	assert_null(reference._hazards._native_passes(), "its twin in GDScript")
	var most := 0
	var broke := 0
	for tick in ticks:
		var events := SimFixtures.step(native)
		ContactsNative.off = true
		var twin := SimFixtures.step(reference)
		ContactsNative.off = false
		for event: SimEvent in events:
			if event.kind == SimEvent.Kind.RAILING_BROKE and event.prop != -1:
				broke += 1
		var moving := 0
		for crate: PropState in native.state.props:
			if crate.is_loose() and crate.vel != Vector3.ZERO:
				moving += 1
		most = maxi(most, moving)
		if var_to_bytes(_bare(native.snapshot())) != var_to_bytes(_bare(reference.snapshot())):
			fail_test("%s: tick %d differs natively" % [what, tick])
			return most
		if events.size() != twin.size():
			fail_test("%s: tick %d's events differ natively" % [what, tick])
			return most
	assert_gt(most, 0, "%s: crates moved" % what)
	if breaks:
		assert_gt(broke, 0, "%s: a crate broke a railing" % what)
	return most


## [param snapshot] with nothing but the match's state in it.
static func _bare(snapshot: Dictionary) -> Dictionary:
	var bare := snapshot.duplicate()
	bare.erase("events")
	return bare


## Asks the native Surfaces of [param layout] and its GDScript twin, both honouring
## [param pose] with [param props] standing, about the points round each of
## [param surfaces] and [param crates], noting every difference.
func _ask_all(
	layout: ShipLayout, pose: ShipPose, props: Array[PropState], surfaces: Array, crates: Array
) -> void:
	var native := Surfaces.new(layout)
	ContactsNative.off = true
	var reference := Surfaces.new(layout)
	ContactsNative.off = false
	assert_not_null(native.native, "the native Surfaces asks the extension")
	assert_null(reference.native, "its twin answers in GDScript")
	native.honour(pose, PackedInt32Array(), props)
	reference.honour(pose, PackedInt32Array(), props)
	var points: Array[Vector3] = []
	for surface: int in surfaces:
		_round_surface(native, surface, points)
	for prop: int in crates:
		if props[prop].is_loose():
			_round_crate(layout, props[prop], points)
	var rules := SimFixtures.rules()
	var shapes: Array[Vector2] = [
		Vector2(rules.body_radius, rules.body_height),
		Vector2(0.24, 0.9),
	]
	for point: Vector3 in points:
		for shape: Vector2 in shapes:
			var except := _rng.randi_range(-1, props.size() - 1)
			_obstacles(native, reference, point, shape, rules.step_height, except, INF, -1.0)
			_obstacles(
				native, reference, point, shape, rules.step_height, -1, rules.crawl_height, -1.0
			)
			_obstacles(
				native, reference, point, shape, rules.step_height, -1, rules.crawl_height, 0.1
			)
			_rails(native, reference, point, shape, rules)
		for reach: float in [0.0, rules.body_radius, 1.9]:
			_near(native.stands, reference.stands, point, reach, -1)
		_near(native.stands, reference.stands, point, 0.3, _rng.randi_range(0, props.size() - 1))
	assert_gt(_asked, 0, "asked something")


func _obstacles(
	native: Surfaces,
	reference: Surfaces,
	point: Vector3,
	shape: Vector2,
	step: float,
	except: int,
	crawl_height: float,
	crawl_reach: float
) -> void:
	_asked += 1
	var mine := native.obstacle_contacts(
		point, shape.x, shape.y, step, except, crawl_height, crawl_reach
	)
	var theirs := reference.obstacle_contacts(
		point, shape.x, shape.y, step, except, crawl_height, crawl_reach
	)
	_same_contacts(mine, theirs, "obstacles at %s of %s" % [point, shape])


func _rails(
	native: Surfaces, reference: Surfaces, point: Vector3, shape: Vector2, rules: BrawlRules
) -> void:
	var asked: Object = native.native
	var surface := reference.under(point, rules.step_height)
	_asked += 2
	_same_contacts(
		ContactsNative.contacts_of(asked.rail_contacts(point, shape.x, surface)),
		reference.rail_contacts(point, shape.x, surface),
		"railings at %s on %d" % [point, surface]
	)
	var came := Vector2(point.x, point.z) + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * 0.4
	_same_contacts(
		ContactsNative.contacts_of(
			asked.airborne_rail_contacts(point, came, shape.x, shape.y, rules.railing_height)
		),
		reference.airborne_rail_contacts(point, came, shape.x, shape.y, rules.railing_height),
		"airborne railings at %s from %s" % [point, came]
	)


func _near(
	native: PropStands, reference: PropStands, point: Vector3, reach: float, except: int
) -> void:
	_asked += 1
	var mine := native.near(point.x, point.z, reach, except)
	var theirs := reference.near(point.x, point.z, reach, except)
	if mine != theirs:
		_note("near %s within %s: %s, not %s" % [point, reach, mine, theirs])


func _same_contacts(
	mine: Array[Surfaces.Contact], theirs: Array[Surfaces.Contact], what: String
) -> void:
	if var_to_bytes(_flat(mine)) != var_to_bytes(_flat(theirs)):
		_note("%s: %s, not %s" % [what, _flat(mine), _flat(theirs)])


static func _flat(contacts: Array[Surfaces.Contact]) -> PackedFloat64Array:
	var flat := PackedFloat64Array()
	for contact: Surfaces.Contact in contacts:
		flat.append_array(
			[contact.normal.x, contact.normal.y, contact.depth, contact.railing, contact.prop]
		)
	return flat


func _note(difference: String) -> void:
	if _differences.size() < 8:
		_differences.append(difference)
	elif _differences.size() == 8:
		_differences.append("…")


func _assert_none(what: String) -> void:
	assert_eq(_differences, [] as Array[String], "%s answers alike (%d asked)" % [what, _asked])


## Points about [param surface] of [param surfaces]: its corners, the middles of its
## edges and its middle, each a hair either side, at its height and a step either side.
func _round_surface(surfaces: Surfaces, surface: int, points: Array[Vector3]) -> void:
	var area := surfaces._areas[surface]
	var height := surfaces._tops[surface]
	var low := surfaces._bottoms[surface]
	var step := SimFixtures.rules().step_height
	var heights: Array[float] = [
		height, height - step, height - step + 1e-6, height - step - 1e-6, height + 0.3
	]
	if is_finite(low):
		heights.append_array([low, low - 0.5])
	var spots: Array[Vector2] = [
		area.position,
		area.end,
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.position.y),
		area.get_center(),
		Vector2(area.get_center().x, area.position.y),
		Vector2(area.position.x, area.get_center().y),
	]
	for spot: Vector2 in spots:
		var hair: float = HAIRS[_rng.randi_range(0, HAIRS.size() - 1)]
		var other: float = HAIRS[_rng.randi_range(0, HAIRS.size() - 1)]
		var feet: float = heights[_rng.randi_range(0, heights.size() - 1)]
		points.append(Vector3(spot.x + hair, feet, spot.y + other))
		points.append(Vector3(spot.x - hair, feet, spot.y))


## Points about [param crate]: on its circle's edge, touching a body there and a hair
## either side, at its underside, on its lid and a step under.
func _round_crate(layout: ShipLayout, crate: PropState, points: Array[Vector3]) -> void:
	var prop := layout.props[crate.prop]
	var reach := prop.radius + SimFixtures.rules().body_radius
	for at: float in [0.0, prop.radius, reach, reach - 1e-6, reach + 1e-6]:
		var way := Vector2.from_angle(_rng.randf_range(0.0, TAU))
		var spot := Vector2(crate.pos.x, crate.pos.z) + way * at
		for feet: float in [crate.pos.y, crate.pos.y + prop.height, crate.pos.y - 0.2]:
			points.append(Vector3(spot.x, feet, spot.y))
	points.append(Vector3(crate.pos.x, -0.0, crate.pos.z))


## Every prop of [param layout] standing loose where it lies.
static func _standing(layout: ShipLayout) -> Array[PropState]:
	var props: Array[PropState] = []
	for index in layout.props.size():
		var crate := PropState.new(index)
		crate.pos = layout.props[index].pos
		crate.body = PropState.Body.GROUNDED
		props.append(crate)
	return props


static func _surface_count(layout: ShipLayout) -> int:
	return layout.platforms.size() + layout.ramps.size() + layout.blockers.size()


## A level pose at sink [param sink], keeping no cells.
static func _pose(sink: float) -> ShipPose:
	return ShipPose.new(sink, 0.0, 0.0, Transform3D(Basis.IDENTITY, Vector3.DOWN * sink))


## The made-up deck: a main deck of two platforms touching, an upper deck as a slab over
## its after part with a crawlway under its edge, a deck at -0, ramps rising and falling
## along x and z, a wall whose top is flush with the upper deck, a box, a round, railings
## end to end on the deck's edge, and crates of every kind laid close.
static func _made_up() -> ShipLayout:
	var layout := ShipLayout.new()
	var platforms: Array[ShipPlatform] = []
	for row: Array in [
		[&"main", Rect2(-10, -5, 10, 10), 0.0, false],
		[&"main", Rect2(0, -5, 10, 10), 0.0, false],
		[&"upper", Rect2(-10, -5, 6, 10), 2.5, true],
		[&"low", Rect2(4, -5, 3, 4), 1.0, true],
		[&"zero", Rect2(-14, -5, 4, 10), -0.0, false],
	]:
		var platform := ShipPlatform.new()
		platform.name = row[0]
		platform.area = row[1]
		platform.height = row[2]
		platform.slab = row[3]
		platforms.append(platform)
	layout.platforms = platforms
	var ramps: Array[ShipRamp] = []
	for row: Array in [
		[Rect2(-4, 1, 3, 1.2), ShipRamp.Axis.X, 2.5, 0.0],
		[Rect2(1, -4.8, 1.2, 3), ShipRamp.Axis.Z, 0.0, 1.0],
		[Rect2(7, 2, 2, 1), ShipRamp.Axis.X, 0.0, 0.2],
	]:
		var ramp := ShipRamp.new()
		ramp.area = row[0]
		ramp.axis = row[1]
		ramp.start_height = row[2]
		ramp.end_height = row[3]
		ramps.append(ramp)
	layout.ramps = ramps
	var blockers: Array[ShipBlocker] = []
	for row: Array in [
		[ShipBlocker.Shape.BOX, Rect2(-4.05, -5, 0.1, 5.8), Vector2.ZERO, 0.0, 0.0, 2.5],
		[ShipBlocker.Shape.BOX, Rect2(3, 2, 1, 1), Vector2.ZERO, 0.0, 0.0, 1.2],
		[ShipBlocker.Shape.CYLINDER, Rect2(), Vector2(5, 3.5), 0.6, 0.0, 6.0],
		[ShipBlocker.Shape.BOX, Rect2(6, -1, 2, 0.02), Vector2.ZERO, 0.0, 0.0, 0.3],
	]:
		var blocker := ShipBlocker.new()
		blocker.shape = row[0]
		blocker.area = row[1]
		blocker.centre = row[2]
		blocker.radius = row[3]
		blocker.bottom = row[4]
		blocker.top = row[5]
		blockers.append(blocker)
	layout.blockers = blockers
	var railings: Array[ShipRailing] = []
	for row: Array in [
		[0, Vector2(-10, 5), Vector2(0, 5)],
		[1, Vector2(0, 5), Vector2(10, 5)],
		[1, Vector2(10, -5), Vector2(10, 5)],
		[0, Vector2(-10, -5), Vector2(0, -5)],
	]:
		var railing := ShipRailing.new()
		railing.platform = row[0]
		railing.from = row[1]
		railing.to = row[2]
		railings.append(railing)
	layout.railings = railings
	var props: Array[ShipProp] = []
	props.append(SimFixtures.crate(Vector3(2.0, 0.0, 0.0)))
	props.append(SimFixtures.crate(Vector3(3.0, 0.0, 0.0)))
	props.append(SimFixtures.crate(Vector3(2.0, 1.0, 0.0)))
	props.append(SimFixtures.table(Vector3(-0.0, 0.0, 2.0)))
	props.append(SimFixtures.chair(Vector3(4.0, 0.0, -2.0)))
	for index in 12:
		var at := Vector3(-2.0 + (index % 4) * 0.5, 0.0, -3.0 + (index / 4) * 0.5)
		props.append(SimFixtures.chair(at) if index % 2 == 0 else SimFixtures.table(at))
	props.append(SimFixtures.crate(Vector3(9.6, 0.0, 4.6)))
	props.append(SimFixtures.lifebuoy(Vector3(-5.0, 0.0, 4.8)))
	layout.props = props
	return layout


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeCrates"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
