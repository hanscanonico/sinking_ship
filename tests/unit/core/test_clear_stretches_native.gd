extends GutTest
## Surfaces.clear_stretches natively (NativeSurfaces.clear_stretches) against the GDScript
## it stands in for, bit for bit: along the four sides of every room of her real ships, for
## a body crawling and one standing, a hair either side of each side; along every
## blocker's sides and across its corners; and between points picked about her decks, near
## and far, so a line runs past many cells. With a funnel down the GDScript answers, and
## still alike. Where the extension is not loaded there is nothing to hold it to; CI sets
## SINKING_NATIVE_REQUIRED, so a missing library there fails.

const STEAMER := "res://data/ships/steamer.tres"
const SMALL_TITANIC := "res://data/ships/small_titanic.tres"
## How far a line is moved off a side: none, float32's own step at her size, and more.
const HAIRS: Array[float] = [0.0, 1e-6, -1e-4, 0.05]
## How many lines are asked between points picked about her decks.
const LINES_ASKED := 400

var _rng := RandomNumberGenerator.new()
var _differences: Array[String] = []
var _asked := 0
var _stretches := 0


func before_each() -> void:
	_rng.seed = 593
	_differences.clear()
	_asked = 0
	_stretches = 0
	ContactsNative.off = false


func after_each() -> void:
	ContactsNative.off = false


func test_her_rooms_sides_answer_alike() -> void:
	if not _loaded():
		return
	var rules := SimFixtures.rules()
	var ships: Array[ShipLayout] = [load(STEAMER), load(SMALL_TITANIC)]
	for layout: ShipLayout in ships:
		var path := layout.resource_path
		var pair := _pair(layout)
		assert_not_null(pair[0].native, "%s asks the extension" % path)
		for room: ShipRoom in layout.rooms:
			var low := room.area.position
			var high := room.area.end
			var corners: Array[Vector2] = [
				low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)
			]
			for hair: float in HAIRS:
				for side in 4:
					var start := corners[side] + Vector2(hair, -hair)
					var end := corners[(side + 1) % 4] + Vector2(hair, -hair)
					for height: float in [rules.crawl_height, rules.body_height]:
						_ask(
							pair,
							Vector3(start.x, room.floor_height, start.y),
							Vector3(end.x, room.floor_height, end.y),
							height,
							rules.step_height
						)
	assert_gt(_stretches, 1000, "rooms' sides have gaps to compare")
	_assert_none("her rooms' sides")


func test_her_blockers_and_decks_answer_alike() -> void:
	if not _loaded():
		return
	var rules := SimFixtures.rules()
	var ships: Array[ShipLayout] = [load(STEAMER), load(SMALL_TITANIC)]
	for layout: ShipLayout in ships:
		var pair := _pair(layout)
		var points: Array[Vector3] = []
		for blocker: ShipBlocker in layout.blockers:
			var area := blocker.area
			if blocker.shape != ShipBlocker.Shape.BOX:
				var corner := blocker.centre - Vector2(blocker.radius, blocker.radius)
				area = Rect2(corner, Vector2(blocker.radius, blocker.radius) * 2.0)
			var feet := blocker.bottom
			var corners: Array[Vector2] = [
				area.position,
				Vector2(area.end.x, area.position.y),
				area.end,
				Vector2(area.position.x, area.end.y)
			]
			for side in 4:
				var start := corners[side]
				var end := corners[(side + 1) % 4]
				_ask(
					pair,
					Vector3(start.x, feet, start.y),
					Vector3(end.x, feet, end.y),
					rules.body_height,
					rules.step_height
				)
				points.append(Vector3(start.x, feet, start.y))
			_ask(
				pair,
				Vector3(corners[0].x, feet, corners[0].y),
				Vector3(corners[2].x, feet, corners[2].y),
				rules.body_height,
				rules.step_height
			)
		for _pick in LINES_ASKED:
			var from := points[_rng.randi_range(0, points.size() - 1)]
			var to := points[_rng.randi_range(0, points.size() - 1)]
			var near := from + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
			for end: Vector3 in [Vector3(to.x, from.y, to.z), near]:
				_ask(pair, from, end, rules.crawl_height, rules.step_height)
	_assert_none("her blockers and decks")


func test_a_funnel_down_answers_alike_in_gdscript() -> void:
	if not _loaded():
		return
	var rules := SimFixtures.rules()
	var layout: ShipLayout = load(STEAMER)
	var pair := _pair(layout)
	var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	for fitting: ShipFitting in layout.structure.fittings:
		if fitting.kind == ShipFitting.Kind.FUNNEL:
			pose.felled.append(FunnelFall.new(fitting, Vector2.RIGHT, 0, 0, 0))
	assert_false(pose.felled.is_empty(), "the steamer has a funnel to fell")
	for surfaces: Surfaces in pair:
		surfaces.honour(pose)
	for fall: FunnelFall in pose.felled:
		var base := fall.fitting.base
		for way: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1).normalized()]:
			var start := Vector2(base.x, base.z) - way * 8.0
			var end := Vector2(base.x, base.z) + way * 8.0
			for feet: float in [base.y, base.y + 2.0]:
				_ask(
					pair,
					Vector3(start.x, feet, start.y),
					Vector3(end.x, feet, end.y),
					rules.body_height,
					rules.step_height
				)
	_assert_none("the steamer with her funnel down")


## [param layout]'s surfaces twice: one asking the extension, one in GDScript.
func _pair(layout: ShipLayout) -> Array[Surfaces]:
	var native := Surfaces.new(layout)
	ContactsNative.off = true
	var reference := Surfaces.new(layout)
	ContactsNative.off = false
	assert_null(reference.native, "its twin works in GDScript")
	return [native, reference]


func _ask(pair: Array[Surfaces], from: Vector3, to: Vector3, height: float, step: float) -> void:
	_asked += 1
	var mine := pair[0].clear_stretches(from, to, height, step)
	var theirs := pair[1].clear_stretches(from, to, height, step)
	_stretches += theirs.size()
	if var_to_bytes(mine) != var_to_bytes(theirs):
		_note("from %s to %s, %s tall: %s, not %s" % [from, to, height, mine, theirs])


func _note(difference: String) -> void:
	if _differences.size() < 8:
		_differences.append(difference)
	elif _differences.size() == 8:
		_differences.append("…")


func _assert_none(what: String) -> void:
	assert_eq(_differences, [] as Array[String], "%s answers alike (%d asked)" % [what, _asked])


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeCrates"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
