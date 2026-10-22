extends GutTest
## §5b.4 layer 3, the barque (SH37): her signature, the knockdown — the explicit hit
## knockdown, a gash in her starboard side tank under her waterline with her four
## companionways and her main hatch left open, as the Marques sailed, and the same hit
## with them shut — and light_hit, a scrape over her waterline. Each baked alone and
## again with its holes' area × 0.9 and × 1.1 to the same outcome, so they sit far from
## every threshold and a Mac and Linux agree (R21). Outcomes are labels and bands, never
## exact times.

const BARQUE := "res://data/ships/barque.tres"
const BARQUE_SINKING := "res://data/sinking/barque_open_sea.tres"
const KNOCKDOWN := "res://tests/fixtures/sinking/hits/barque_knockdown.tres"
const KNOCKDOWN_SHUT := "res://tests/fixtures/sinking/hits/barque_knockdown_shut.tres"
const LIGHT := "res://tests/fixtures/sinking/hits/barque_light.tres"
const MARGINS: Array[float] = [0.9, 1.0, 1.1]
## knockdown: open, she is laid past her beam ends within this many seconds of the hit,
## and at least SOONER_BY sooner than with them shut.
const CAPSIZES_WITHIN := 600.0
const SOONER_BY := 3600.0
## knockdown shut: heeled by her flooded tank, she lies over between these lists, in
## degrees, from HANGS_FROM to HANGS_UNTIL seconds after the hit, neither righted nor over.
const HANGS_LIST := Vector2(20.0, 60.0)
const HANGS_FROM := 300.0
const HANGS_UNTIL := 1200.0

var _structure: ShipStructure
var _sea: SeaPhysics
var _scenario: SinkScenario


func before_all() -> void:
	_structure = (load(BARQUE) as ShipLayout).structure
	_sea = SeaPhysics.load_default()
	_scenario = load(BARQUE_SINKING)


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


## Her least and her most list, in degrees, from [param from] to [param until] seconds.
func _lists_within(timeline: SinkTimeline, from: float, until: float) -> Vector2:
	var lists := Vector2(INF, -INF)
	for frame in timeline.count():
		var at: float = timeline.times[frame]
		if at < from or at > until:
			continue
		var list := absf(OutcomeClassifier.leans_at(timeline, frame)[1])
		lists = Vector2(minf(lists.x, list), maxf(lists.y, list))
	return lists


func test_her_companionways_left_open_lay_her_over() -> void:
	# The gash floods her starboard side tank: her weight aloft and her small GM let it
	# heel her far, until her main deck's edge is under and the sea stands at her
	# companionways. Left open, it pours down them onto her 'tween deck, runs to her low
	# side across a deck no wall divides, and lays her on her side in minutes; shut, she
	# lies over on her tank's water and holds there before the leaks take her over.
	for scale: float in MARGINS:
		var what := "× %s" % scale
		var opened := _bake(load(KNOCKDOWN), scale)
		var shut := _bake(load(KNOCKDOWN_SHUT), scale)
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
		assert_lt(over, CAPSIZES_WITHIN, what + ": over within 10 min")
		assert_lt(over + SOONER_BY, _capsized_at(shut), what + ": open, over an hour sooner")


func test_her_companionways_shut_she_lies_over_and_holds() -> void:
	# Validation only: knockdown's hit with every opening shut heels her far over on her
	# flooded tank, and she lies there, neither righted nor laid over, for a quarter of an
	# hour.
	for scale: float in MARGINS:
		var lists := _lists_within(_bake(load(KNOCKDOWN_SHUT), scale), HANGS_FROM, HANGS_UNTIL)
		gut.p("× %s: lists %.1f°…%.1f° from 5 to 20 min" % [scale, lists.x, lists.y])
		assert_gt(lists.x, HANGS_LIST.x, "× %s: heeled past 20°" % scale)
		assert_lt(lists.y, HANGS_LIST.y, "× %s: not past 60°" % scale)


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
		assert_lt(timeline.seas[last], SinkTimeline.MAIN_DECK, "her main deck clear, × %s" % scale)
