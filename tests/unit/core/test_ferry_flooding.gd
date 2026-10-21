extends GutTest
## §5b.4 layer 3, the ferry (SH35): her signature, the open car deck's capsize — the
## explicit hit bow_door, a gash in her starboard wing tanks forward with her bow door
## left open as the Herald of Free Enterprise sailed, and the same hit with it shut —
## and light_hit, a scrape over her waterline. Each baked alone and again with its
## holes' area × 0.9 and × 1.1 to the same outcome, so they sit far from every
## threshold and a Mac and Linux agree (R21). Outcomes are labels and bands, never exact
## times.

const FERRY := "res://data/ships/ferry.tres"
const FERRY_SINKING := "res://data/sinking/ferry_open_sea.tres"
const BOW_DOOR := "res://tests/fixtures/sinking/hits/ferry_bow_door.tres"
const BOW_DOOR_SHUT := "res://tests/fixtures/sinking/hits/ferry_bow_door_shut.tres"
const LIGHT := "res://tests/fixtures/sinking/hits/ferry_light.tres"
const MARGINS: Array[float] = [0.9, 1.0, 1.1]
## bow_door: open, she rolls past her beam ends within this many seconds of the hit, and
## at least SOONER_BY sooner than with it shut.
const CAPSIZES_WITHIN := 1200.0
const SOONER_BY := 3600.0
## bow_door shut: she survives the hit, or goes no sooner than this after it.
const SHUT_HOLDS := 1800.0

var _structure: ShipStructure
var _sea: SeaPhysics
var _scenario: SinkScenario


func before_all() -> void:
	_structure = (load(FERRY) as ShipLayout).structure
	_sea = SeaPhysics.load_default()
	_scenario = load(FERRY_SINKING)


## [param hit] on her, as her open sea maps it, baked with every hole of its gash
## [param scale] times as big, every state the physics stepped through kept.
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


## The first moment [param timeline] rolls past her beam ends, in seconds; INF for never.
func _capsized_at(timeline: SinkTimeline) -> float:
	for frame in timeline.count():
		if absf(OutcomeClassifier.leans_at(timeline, frame)[1]) > OutcomeClassifier.CAPSIZED_DEG:
			return timeline.times[frame]
	return INF


func test_her_bow_door_left_open_rolls_her_over() -> void:
	# The gash floods her starboard wing tanks forward: she lists to starboard and goes
	# down by the head until her bow door is under. Left open, the sea pours onto her car
	# deck, runs to her low side across a deck no wall divides, and she rolls over in
	# minutes; shut, its seals weep and she holds for hours before the same water takes
	# her over.
	for scale: float in MARGINS:
		var what := "× %s" % scale
		var opened := _bake(load(BOW_DOOR), scale)
		var shut := _bake(load(BOW_DOOR_SHUT), scale)
		var over := _capsized_at(opened)
		gut.p(
			(
				"%s: open, over at %.0f s; shut, over at %.0f s, gone at %.0f s"
				% [what, over, _capsized_at(shut), shut.gone_at]
			)
		)
		assert_has(
			OutcomeClassifier.labels(opened), OutcomeClassifier.Outcome.CAPSIZED, what + ": over"
		)
		assert_lt(over, CAPSIZES_WITHIN, what + ": over within 20 min")
		assert_lt(over + SOONER_BY, _capsized_at(shut), what + ": open, over an hour sooner")


func test_her_bow_door_shut_she_survives_or_goes_slowly() -> void:
	# Validation only: bow_door's hit with every opening shut leaves her afloat, or going
	# after half an hour (§5b.4, the research's small-boat pair).
	for scale: float in MARGINS:
		var timeline := _bake(load(BOW_DOOR_SHUT), scale)
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
		assert_lt(timeline.seas[last], SinkTimeline.MAIN_DECK, "her car deck clear, × %s" % scale)
