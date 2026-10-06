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
## open_hatch: she goes at least this many seconds sooner than with her hatch shut.
const SOONER_BY := 60.0
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
	scaled.wave_height = damage.wave_height
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


## [param damage] with [param opening_name] shut as her data has it, not left open.
func _with_shut(damage: HitDamage, opening_name: StringName) -> HitDamage:
	var shut := HitDamage.new()
	shut.wave_height = damage.wave_height
	shut.jammed = damage.jammed
	shut.weakened = damage.weakened
	shut.weakened_to = damage.weakened_to
	shut.left_open = damage.left_open.duplicate()
	shut.left_open.erase(opening_name)
	shut.openings = damage.openings
	return shut


func test_open_hatch_takes_her_down_by_the_head_and_sooner() -> void:
	# Her fish hatch left open: once water stands over it, the hold under it fills from
	# the well, and its weight forward takes her down by the head, sooner than the same
	# hit with only the hatch shut, which lays her on her side. What her seaway ships over
	# her low bulwark (ShippedWater) the hatch lets down into the hold, low and amidships,
	# rather than leaving it loose on the low side of her deck — so she founders rather
	# than capsizes.
	var choice := _match_hit(&"open_hatch")
	assert_has(choice.damage.left_open, &"fish_hatch", "her fish hatch left open")
	var battened := _with_shut(choice.damage, &"fish_hatch")
	var hatch := _opening(&"fish_hatch")
	for scale: float in MARGINS:
		var opened := _bake(choice.damage, scale)
		var shut := _bake(battened, scale)
		var what := "× %s" % scale
		var labels := OutcomeClassifier.labels(opened)
		assert_has(labels, OutcomeClassifier.Outcome.BY_THE_HEAD, what + ": open, by the head")
		assert_does_not_have(labels, OutcomeClassifier.Outcome.CAPSIZED, what)
		assert_lt(_under(opened, hatch), opened.gone_at, what + ": her hatch goes under first")
		assert_has(
			OutcomeClassifier.labels(shut),
			OutcomeClassifier.Outcome.ONTO_HER_SIDE,
			what + ": shut, onto her side"
		)
		assert_lt(opened.gone_at + SOONER_BY, shut.gone_at, what + ": open, gone sooner than shut")


func test_everything_shut_she_survives_or_goes_slowly() -> void:
	# Validation only: open_hatch's hit with every opening shut — her hatch battened, her
	# portholes shut and her watertight door shut at the hit — in the same sea leaves her
	# afloat, or going after half an hour (§5b.4, the research's small-boat pair).
	var choice := _match_hit(&"open_hatch")
	var shut: IcebergHit = choice.hit.duplicate()
	shut.jammed = []
	shut.left_open = []
	var damage := HitMapper.map_explicit(shut, _structure, _scenario.hit)
	damage.wave_height = choice.damage.wave_height
	for scale: float in MARGINS:
		var timeline := _bake(damage, scale)
		assert_true(
			not timeline.is_gone() or timeline.gone_at >= SHUT_HOLDS,
			"× %s: afloat, or gone after 30 min (gone at %.0f s)" % [scale, timeline.gone_at]
		)


func test_light_hit_ends_afloat() -> void:
	# Validation only: no match draws it (the must-sink rule throws it out). A scrape
	# along her fo'c'sle over her waterline, in the roughest sea her matches draw: it
	# opens her, and the sea never reaches it.
	var damage := HitMapper.map_explicit(load(LIGHT), _structure, _scenario.hit)
	damage.wave_height = _scenario.wave_height.y
	for scale: float in MARGINS:
		var timeline := _bake(damage, scale)
		assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "afloat, × %s" % scale)
		var last := timeline.count() - 1
		var heel := rad_to_deg(asin(timeline.rotations[last * 9 + 7]))
		assert_lt(absf(heel), 7.0, "listing under 7°, × %s" % scale)
		assert_lt(timeline.seas[last], SinkTimeline.MAIN_DECK, "her deck clear, × %s" % scale)
