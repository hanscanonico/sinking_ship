extends GutTest
## §5b.4 layer 3, the trawler (SH30): her pinned seed's match hit — open_hatch — and the
## explicit hits light_hit and everything_shut, the research's small-boat pair, each
## baked alone and again with its holes' area × 0.9 and × 1.1 to the same outcome, so
## the seed sits far from every threshold and a Mac and Linux agree (R21). Outcomes are
## labels and bands, never exact times.

const TRAWLER := "res://data/ships/trawler.tres"
const TRAWLER_SINKING := "res://data/sinking/trawler_open_sea.tres"
const LIGHT := "res://tests/fixtures/sinking/hits/trawler_light.tres"
const MARGINS: Array[float] = [0.9, 1.0, 1.1]
## open_hatch: she capsizes within this many seconds of her fish hatch going under.
const CAPSIZED_WITHIN := 300.0
## everything_shut: she survives the hit, or goes no sooner than this after it.
const SHUT_HOLDS := 1800.0

var _structure: ShipStructure
var _sea: SeaPhysics
var _scenario: SinkScenario


func before_all() -> void:
	_structure = (load(TRAWLER) as ShipLayout).structure
	_sea = SeaPhysics.load_default()
	_scenario = load(TRAWLER_SINKING)


## [param seed_name]'s match hit on her, as the must-sink rule chooses it.
func _match_hit(seed_name: StringName) -> MustSink.Choice:
	var stream := SeedStreams.derive(PinnedSeeds.seed_named(seed_name), "sink")
	return MustSink.choose(_structure, _scenario, stream, _sea)


## [param damage] baked with every hole of its gash [param scale] times as big, every
## state the physics stepped through kept.
func _bake(damage: HitDamage, scale: float) -> SinkTimeline:
	var scaled := HitDamage.new()
	scaled.jammed = damage.jammed
	scaled.left_open = damage.left_open
	for opening: ShipOpening in damage.openings:
		var hole: ShipOpening = opening.duplicate()
		hole.area = opening.area * scale
		scaled.openings.append(hole)
	var stepper := SinkStepper.new(_structure, scaled, _sea)
	return SinkBake.new(stepper, _sea, _scenario.bake_cap).uncompacted()


## The opening of hers called [param opening_name].
func _opening(opening_name: StringName) -> ShipOpening:
	for opening: ShipOpening in _structure.openings:
		if opening.name == opening_name:
			return opening
	return null


## The first moment the sea stands over the lowest corner of [param opening] in
## [param timeline]; INF for never.
func _under(timeline: SinkTimeline, opening: ShipOpening) -> float:
	for frame in timeline.count():
		var r := timeline.rotations
		var lowest := INF
		for corner in 8:
			var point := opening.centre
			for axis in 3:
				point[axis] += opening.size[axis] * (0.5 if corner & (1 << axis) else -0.5)
			var up := (
				r[frame * 9 + 3] * point.x + r[frame * 9 + 4] * point.y + r[frame * 9 + 5] * point.z
			)
			lowest = minf(lowest, up)
		if timeline.seas[frame] > lowest:
			return timeline.times[frame]
	return INF


## The first moment [param timeline] has her rolled past her beam ends, as
## OutcomeClassifier reads a capsize; INF for never.
func _capsized(timeline: SinkTimeline) -> float:
	for frame in timeline.count():
		var leans := OutcomeClassifier.leans_at(timeline, frame)
		if (
			absf(leans[0]) < OutcomeClassifier.ON_END_DEG
			and absf(leans[1]) > OutcomeClassifier.CAPSIZED_DEG
		):
			return timeline.times[frame]
	return INF


func test_open_hatch_capsizes_within_5_minutes_of_the_hatch_going_under() -> void:
	# Her fish hatch left open: once the sea has the well and the hatch under it, the hold
	# under it fills from the deck, its loose water and the well's roll her over (§5b.4).
	var choice := _match_hit(&"open_hatch")
	assert_has(choice.damage.left_open, &"fish_hatch", "her fish hatch left open")
	var hatch := _opening(&"fish_hatch")
	for scale: float in MARGINS:
		var timeline := _bake(choice.damage, scale)
		var what := "× %s" % scale
		assert_has(OutcomeClassifier.labels(timeline), OutcomeClassifier.Outcome.CAPSIZED, what)
		var under := _under(timeline, hatch)
		var capsized := _capsized(timeline)
		assert_lt(under, INF, what + ": her hatch goes under")
		assert_between(
			capsized - under, 0.0, CAPSIZED_WITHIN, what + ": she capsizes within 5 min of it"
		)


func test_everything_shut_she_survives_or_goes_slowly() -> void:
	# Validation only: open_hatch's hit with every opening shut — her hatch battened, her
	# portholes shut and her watertight door shut at the hit — leaves her afloat, or
	# going after half an hour (§5b.4, the research's small-boat pair).
	var shut: IcebergHit = _match_hit(&"open_hatch").hit.duplicate()
	shut.jammed = []
	shut.left_open = []
	var damage := HitMapper.map_explicit(shut, _structure, _scenario.hit)
	for scale: float in MARGINS:
		var timeline := _bake(damage, scale)
		assert_true(
			not timeline.is_gone() or timeline.gone_at >= SHUT_HOLDS,
			"× %s: afloat, or gone after 30 min (gone at %.0f s)" % [scale, timeline.gone_at]
		)


func test_light_hit_ends_afloat() -> void:
	# Validation only: no match draws it (the must-sink rule throws it out). A scrape
	# along her fo'c'sle over her waterline: it opens her, and the sea never reaches it.
	var damage := HitMapper.map_explicit(load(LIGHT), _structure, _scenario.hit)
	for scale: float in MARGINS:
		var timeline := _bake(damage, scale)
		assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "afloat, × %s" % scale)
		var last := timeline.count() - 1
		var heel := rad_to_deg(asin(timeline.rotations[last * 9 + 7]))
		assert_lt(absf(heel), 7.0, "listing under 7°, × %s" % scale)
		assert_lt(timeline.seas[last], SinkTimeline.MAIN_DECK, "her deck clear, × %s" % scale)
