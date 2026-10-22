extends GutTest
## §5b.4 layer 3, the ore freighter (SH38): her signature, breaking in two — the
## explicit hit hold, a gash in her starboard side amidships through her wing tanks into
## her middle hold, whose water sags her long, shallow girder past what her hatch row
## keeps until she parts there —, her sure hit founding her in both her scenarios, and
## light_hit, a scrape at her bow over her waterline that leaves her afloat and whole.
## The signature baked alone and again with its holes' area × 0.9 and × 1.1 to the same
## outcome, so it sits far from every threshold and a Mac and Linux agree (R21).
## Outcomes are labels and bands, never exact times.

const FREIGHTER := "res://data/ships/freighter.tres"
const OPEN_SEA := "res://data/sinking/freighter_open_sea.tres"
const COAST := "res://data/sinking/freighter_coast.tres"
const HOLD := "res://tests/fixtures/sinking/hits/freighter_hold.tres"
const LIGHT := "res://tests/fixtures/sinking/hits/freighter_light.tres"
const MARGINS: Array[float] = [0.9, 1.0, 1.1]
## hold: she parts within this many seconds of the hit, and at least BEFORE_GONE before
## the last of her is gone.
const PARTS_WITHIN := 1800.0
const BEFORE_GONE := 10.0

var _structure: ShipStructure
var _sea: SeaPhysics
## Her open sea, then her coast.
var _scenarios: Array[SinkScenario] = []


func before_all() -> void:
	_structure = (load(FREIGHTER) as ShipLayout).structure
	_sea = SeaPhysics.load_default()
	_scenarios.assign([load(OPEN_SEA), load(COAST)])


## [param hit] on her, as [param scenario] maps it, baked with every hole of its gash
## [param scale] times as big, her hull breaking as the sea's physics has it.
func _bake(hit: IcebergHit, scenario: SinkScenario, scale := 1.0) -> SinkTimeline:
	var damage := HitMapper.map_explicit(hit, _structure, scenario.hit)
	var scaled := HitDamage.new()
	scaled.sea_depth = scenario.sea_depth
	scaled.wave_height = scenario.wave_height.y
	scaled.jammed = damage.jammed
	scaled.left_open = damage.left_open
	scaled.weakened = damage.weakened
	scaled.weakened_to = damage.weakened_to
	for opening: ShipOpening in damage.openings:
		var hole: ShipOpening = opening.duplicate()
		hole.area = opening.area * scale
		scaled.openings.append(hole)
	return SinkBake.of(_structure, scaled, _sea, scenario.bake_cap).timeline()


## The moment [param timeline] first parts, in seconds; INF for never.
func _parted_at(timeline: SinkTimeline) -> float:
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == SinkTimeline.Kind.PARTED:
			return event.seconds
	return INF


func test_her_hold_flooded_breaks_her_in_two() -> void:
	# The gash floods her middle hold faster than its screen bulkheads let the water on
	# into the holds either side: its weight on top of her ore's sags her amidships past
	# what her hatch row keeps there, the hinge runs, and she parts — two pieces, each
	# going down on its own.
	for scale: float in MARGINS:
		var what := "× %s" % scale
		var timeline := _bake(load(HOLD), _scenarios[0], scale)
		var parted := _parted_at(timeline)
		gut.p("%s: parted at %.0f s, gone at %.0f s" % [what, parted, timeline.gone_at])
		assert_eq(timeline.leaves.size(), 2, what + ": in two pieces")
		assert_has(
			OutcomeClassifier.labels(timeline),
			OutcomeClassifier.Outcome.BROKE_IN_TWO,
			what + ": broke in two"
		)
		assert_eq(timeline.end, SinkTimeline.End.GONE, what + ": every piece gone")
		assert_lt(parted, PARTS_WITHIN, what + ": parted within 30 min")
		assert_lt(parted + BEFORE_GONE, timeline.gone_at, what + ": parted before she went")


func test_she_founders_on_her_sure_hit_in_both_scenarios() -> void:
	# The must-sink rule's last rung, her hull breaking as it may: gone in the open sea,
	# gone or aground with part of her dry on the coast — what a match plays.
	for scenario: SinkScenario in _scenarios:
		var timeline := _bake(_structure.sure_hit, scenario)
		var path := scenario.resource_path
		gut.p(
			(
				"%s: %s at %.0f s, %d pieces"
				% [
					path,
					SinkTimeline.End.keys()[timeline.end],
					timeline.length(),
					timeline.leaves.size()
				]
			)
		)
		assert_true(MustSink.played(timeline.end), "%s: she founders" % path)


func test_light_hit_ends_afloat_and_whole() -> void:
	# Validation only: no match draws it (the must-sink rule throws it out). A scrape
	# along her bow over her waterline, in the roughest sea her matches draw: it opens her
	# fore peak, the sea never reaches it, and her own ore's sag never parts her.
	var timeline := _bake(load(LIGHT), _scenarios[0])
	assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "afloat")
	assert_eq(timeline.leaves.size(), 1, "whole")
	var last := timeline.count() - 1
	var heel := rad_to_deg(asin(timeline.rotations[last * 9 + 7]))
	assert_lt(absf(heel), 7.0, "listing under 7°")
	assert_lt(timeline.seas[last], SinkTimeline.MAIN_DECK, "her spar deck clear")
