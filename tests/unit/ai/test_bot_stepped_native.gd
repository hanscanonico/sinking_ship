extends GutTest
## A bot's reckoning by the walks it has sent, natively (NativeSurfaces.stepped) against
## the GDScript it stands in for (BotReckoning._walked), bit for bit: on the steamer and
## the small Titanic, her crates standing and her doors half shut, bots seen at rest or
## moving on her decks, her stairs and their railings' either side, a hair to a body's
## width off each, pressing every way — walks turning, stopping and gone unsent — each
## reckoned by_steps and by_walks. Where the extension is not loaded there is nothing to
## hold it to; CI sets SINKING_NATIVE_REQUIRED, so a missing library there fails.

const STEAMER := "res://data/ships/steamer.tres"
const SMALL_TITANIC := "res://data/ships/small_titanic.tres"
## How many bots are seen on a ship's surfaces at random, and by each of her railings.
const SEEN_ON_SURFACES := 300
const SEEN_BY_RAILINGS := 300
## How far off a railing's line a bot is seen, either side.
const OFF_RAILING: Array[float] = [0.0, 1e-4, 0.1, 0.25, 0.4]
const SEEN_TICK := 300

var _rng := RandomNumberGenerator.new()
var _differences: Array[String] = []
var _asked := 0
## How many reckonings ended other than where the walks summed would take the bot: held by
## a railing, a floor or a wall.
var _held := 0


func before_each() -> void:
	_rng.seed = 680
	_differences.clear()
	_asked = 0
	_held = 0
	ContactsNative.off = false


func after_each() -> void:
	ContactsNative.off = false


func test_her_ships_reckon_alike() -> void:
	if not _loaded():
		return
	var ships: Array[ShipLayout] = [load(STEAMER), load(SMALL_TITANIC)]
	for layout: ShipLayout in ships:
		var path := layout.resource_path
		var native := Surfaces.new(layout)
		ContactsNative.off = true
		var reference := Surfaces.new(layout)
		ContactsNative.off = false
		assert_not_null(native.native, "the native Surfaces asks the extension")
		assert_null(reference.native, "its twin answers in GDScript")
		var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
		if layout.structure != null:
			for opening: ShipOpening in layout.structure.openings:
				if opening.shuts_at_hit:
					pose.doors_shut[opening.name] = _rng.randf_range(0.2, 1.0)
		var props := _standing(layout)
		native.honour(pose, PackedInt32Array(), props)
		reference.honour(pose, PackedInt32Array(), props)
		var walkable := layout.platforms.size() + layout.ramps.size()
		for _seen in SEEN_ON_SURFACES:
			var surface := _rng.randi_range(0, walkable - 1)
			var area: Rect2 = reference._areas[surface]
			var at := Vector3(
				_rng.randf_range(area.position.x, area.end.x),
				0.0,
				_rng.randf_range(area.position.y, area.end.y)
			)
			at.y = reference.height_at(surface, at)
			_reckon(native, reference, at, surface)
		for _seen in SEEN_BY_RAILINGS:
			var railing: ShipRailing = layout.railings[_rng.randi_range(
				0, layout.railings.size() - 1
			)]
			var way := railing.to - railing.from
			var across := way.orthogonal().normalized()
			var off: float = OFF_RAILING[_rng.randi_range(0, OFF_RAILING.size() - 1)]
			var on := (
				railing.from + way * _rng.randf() + across * off * (1 if _rng.randf() < 0.5 else -1)
			)
			var feet := layout.platforms[railing.platform].height
			var at := Vector3(on.x, feet, on.y)
			var surface := reference.under(at, SimFixtures.rules().step_height)
			if surface == Surfaces.NONE:
				continue
			at.y = reference.height_at(surface, at)
			_reckon(native, reference, at, surface)
		assert_eq(_differences, [] as Array[String], "%s reckons alike" % path)
	assert_gt(_asked, 1000, "asked of many walks")
	assert_gt(_held, 50, "many held on the way (%d of %d)" % [_held, _asked])


## Reckons a bot seen at [param at] on [param surface] by walks at random, natively over
## [param native] and in GDScript over [param reference], noting every difference.
func _reckon(native: Surfaces, reference: Surfaces, at: Vector3, surface: int) -> void:
	var rules := SimFixtures.rules()
	var profile := BotProfile.for_tier(&"normal")
	var mine := BotReckoning.new(profile, rules)
	mine.stand_on(null, native)
	var theirs := BotReckoning.new(profile, rules)
	theirs.stand_on(null, reference)
	var walk := Vector2.from_angle(_rng.randf_range(0.0, TAU))
	var sent := Vector2.ZERO
	for tick in range(SEEN_TICK, SEEN_TICK + profile.reaction_ticks):
		var roll := _rng.randf()
		if roll < 0.05 and tick > SEEN_TICK:
			continue
		if roll < 0.25:
			walk = Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(0.0, 1.0)
		elif roll < 0.3:
			walk = Vector2.ZERO
		var frame := InputFrame.new(0, tick, InputFrame.quantize(walk), 0, 0)
		mine.sent(frame)
		theirs.sent(frame)
		sent += frame.move_vector()
	var speed := _rng.randf_range(0.0, rules.walk_speed)
	var me := {
		"pos": at,
		"vel": Vector3(_rng.randf_range(-speed, speed), 0.0, _rng.randf_range(-speed, speed)),
		"surface": surface,
		"state": PlayerState.Body.GROUNDED,
		"stagger": 0,
		"hitstop": 0,
	}
	var reckoned := at + Vector3(0.0, 0.0, 1.0)
	for eased: bool in [true, false]:
		_asked += 1
		var got := mine._stepped(me, SEEN_TICK, reckoned, eased)
		var want := theirs._stepped(me, SEEN_TICK, reckoned, eased)
		if got != want:
			_differences.append(
				"seen at %s on %d, eased %s: %s, not %s" % [at, surface, eased, got, want]
			)
		var summed := Vector2(at.x, at.z) + sent * rules.walk_speed * Ticks.SECONDS_PER_TICK
		if not eased and Vector2(got.x, got.z).distance_to(summed) > 1e-3:
			_held += 1


static func _standing(layout: ShipLayout) -> Array[PropState]:
	var props: Array[PropState] = []
	for index in layout.props.size():
		var crate := PropState.new(index)
		crate.pos = layout.props[index].pos
		crate.body = PropState.Body.GROUNDED
		props.append(crate)
	return props


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeCrates"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
