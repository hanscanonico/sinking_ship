extends GutTest
## §5b.4 layer 3, the tug (SH36): her signature, how fast she goes by the stern once the
## sea stands on her low towing deck — the explicit hit casing_door, a gash in her aft
## peak with the casing door left open onto the towing deck, and the same hit with it
## shut — light_hit, a scrape over her waterline, and her sure hit on her coast. Each of
## the first three baked alone and again with its holes' area × 0.9 and × 1.1 to the same
## outcome, so they sit far from every threshold and a Mac and Linux agree (R21).
## Outcomes are labels and bands, never exact times.

const TUG := "res://data/ships/tug.tres"
const TUG_SINKING := "res://data/sinking/tug_open_sea.tres"
const TUG_COAST := "res://data/sinking/tug_coast.tres"
const CASING_DOOR := "res://tests/fixtures/sinking/hits/tug_casing_door.tres"
const CASING_DOOR_SHUT := "res://tests/fixtures/sinking/hits/tug_casing_door_shut.tres"
const LIGHT := "res://tests/fixtures/sinking/hits/tug_light.tres"
const MARGINS: Array[float] = [0.9, 1.0, 1.1]
## casing_door: open, she is gone within this many seconds of the hit, and at least
## SOONER_BY sooner than with it shut.
const GONE_WITHIN := 1200.0
const SOONER_BY := 1800.0
## casing_door shut: she survives the hit, or goes no sooner than this after it.
const SHUT_HOLDS := 1800.0

var _structure: ShipStructure
var _sea: SeaPhysics
var _scenario: SinkScenario


func before_all() -> void:
	_structure = (load(TUG) as ShipLayout).structure
	_sea = SeaPhysics.load_default()
	_scenario = load(TUG_SINKING)


## [param hit] on her, as her open sea maps it in the roughest sea it draws, baked with
## every hole of its gash [param scale] times as big, every state the physics stepped
## through kept.
func _bake(hit: IcebergHit, scale: float) -> SinkTimeline:
	var damage := HitMapper.map_explicit(hit, _structure, _scenario.hit)
	var scaled := HitDamage.new()
	scaled.wave_height = _scenario.wave_height.y
	scaled.jammed = damage.jammed
	scaled.left_open = damage.left_open
	scaled.weakened = damage.weakened
	scaled.weakened_to = damage.weakened_to
	for opening: ShipOpening in damage.openings:
		var hole: ShipOpening = opening.duplicate()
		hole.area = opening.area * scale
		scaled.openings.append(hole)
	var stepper := SinkStepper.new(_structure, scaled, _sea)
	return SinkBake.new(stepper, _sea, _scenario.bake_cap).uncompacted()


## How far the sea stands under the lowest corner of [param room_name]'s floor at
## [param frame] of [param timeline], in metres: below 0, the floor is under.
func _clear_of_sea(timeline: SinkTimeline, frame: int, room_name: StringName) -> float:
	var layout: ShipLayout = load(TUG)
	var r := timeline.rotations
	var lowest := INF
	for room: ShipRoom in layout.rooms:
		if room.name != room_name:
			continue
		for corner: Vector2 in [
			room.area.position,
			room.area.end,
			Vector2(room.area.position.x, room.area.end.y),
			Vector2(room.area.end.x, room.area.position.y)
		]:
			var point := Vector3(corner.x, room.floor_height, corner.y)
			var up := (
				r[frame * 9 + 3] * point.x + r[frame * 9 + 4] * point.y + r[frame * 9 + 5] * point.z
			)
			lowest = minf(lowest, up)
	return lowest - timeline.seas[frame]


func test_her_casing_door_left_open_takes_her_down_by_the_stern_in_minutes() -> void:
	# The gash floods her aft peak: she settles by the stern until the sea stands on her
	# towing deck, its bulwarks no help with so little freeboard. Left open, her casing door
	# lets that water in and down the casing's stair into her engine room — the one big
	# space that holds her up — and she goes by the stern in minutes; shut, her towing
	# deck awash is all the hit does, and she floats on.
	for scale: float in MARGINS:
		var what := "× %s" % scale
		var opened := _bake(load(CASING_DOOR), scale)
		var shut := _bake(load(CASING_DOOR_SHUT), scale)
		gut.p(
			(
				"%s: open, gone at %.0f s; shut, %s at %.0f s"
				% [what, opened.gone_at, SinkTimeline.End.keys()[shut.end], shut.length()]
			)
		)
		assert_true(opened.is_gone(), what + ": open, gone")
		assert_has(
			OutcomeClassifier.labels(opened),
			OutcomeClassifier.Outcome.BY_THE_STERN,
			what + ": by the stern"
		)
		assert_lt(opened.gone_at, GONE_WITHIN, what + ": open, gone within 20 min")
		var shut_gone := shut.gone_at if shut.is_gone() else INF
		assert_lt(opened.gone_at + SOONER_BY, shut_gone, what + ": open, half an hour sooner")


func test_her_casing_door_shut_she_survives_or_goes_slowly() -> void:
	# Validation only: casing_door's hit with every opening shut leaves her afloat, or
	# going after half an hour (§5b.4, the research's small-boat pair).
	for scale: float in MARGINS:
		var timeline := _bake(load(CASING_DOOR_SHUT), scale)
		assert_true(
			not timeline.is_gone() or timeline.gone_at >= SHUT_HOLDS,
			"× %s: afloat, or gone after 30 min (gone at %.0f s)" % [scale, timeline.gone_at]
		)


func test_light_hit_ends_afloat() -> void:
	# Validation only: no match draws it (the must-sink rule throws it out). A scrape
	# along her bow over her waterline, in the roughest sea her matches draw: it opens her
	# fore peak, and the sea never reaches it.
	for scale: float in MARGINS:
		var timeline := _bake(load(LIGHT), scale)
		assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "afloat, × %s" % scale)
		var last := timeline.count() - 1
		var heel := rad_to_deg(asin(timeline.rotations[last * 9 + 7]))
		assert_lt(absf(heel), 7.0, "listing under 7°, × %s" % scale)
		assert_lt(timeline.seas[last], SinkTimeline.MAIN_DECK, "her deck clear, × %s" % scale)


func test_on_her_coast_her_sure_hit_rests_her_on_the_bottom_her_wheelhouse_dry() -> void:
	# Her coast is shallow for her draught, and her wheelhouse stands high for her size:
	# her sure hit sets her down on the bottom with its floor still out of the sea.
	var coast: SinkScenario = load(TUG_COAST)
	var damage := HitMapper.map_explicit(_structure.sure_hit, _structure, coast.hit)
	damage.sea_depth = coast.sea_depth
	var stepper := SinkStepper.new(_structure, damage, _sea)
	var timeline := SinkBake.new(stepper, _sea, coast.bake_cap).uncompacted()
	assert_eq(timeline.end, SinkTimeline.End.AGROUND, "at rest on the bottom")
	var dry := _clear_of_sea(timeline, timeline.count() - 1, &"wheelhouse")
	gut.p("her wheelhouse's floor %.2f m over the sea at rest" % dry)
	assert_gt(dry, 0.0, "her wheelhouse's floor out of the sea")
