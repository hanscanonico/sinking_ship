class_name TitanicSisters
extends RefCounted
## The Titanic's sisters as test_titanic_olympic and test_titanic_britannic bake them
## (SH34): the test-only hulls tools/gen_titanic.py writes, struck by fixture hits.

const OLYMPIC := &"titanic_olympic_1913"
const BRITANNIC := &"titanic_britannic"
const HITS := "res://tests/fixtures/sinking/hits/%s.tres"


## [param sister] struck by the fixture hit [param hit_name] in [param scenario], baked.
static func bake(sister: StringName, hit_name: String, scenario: SinkScenario) -> SinkTimeline:
	var structure := Fleet.layout(sister).structure
	var damage := HitMapper.map_explicit(load(HITS % hit_name), structure, scenario.hit)
	damage.sea_depth = scenario.sea_depth
	return SinkBake.of(structure, damage, SeaPhysics.load_default(), scenario.bake_cap).timeline()


## The second of [param timeline]'s first [param kind] event, or -1.
static func first(timeline: SinkTimeline, kind: SinkTimeline.Kind) -> float:
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == kind:
			return event.seconds
	return -1.0


static func told(timeline: SinkTimeline) -> String:
	return (
		"first gone at %s, ends %s at %s: %s"
		% [
			MatchTranscript.physics_clock(first(timeline, SinkTimeline.Kind.GONE)),
			SinkTimeline.End.keys()[timeline.end],
			MatchTranscript.physics_clock(timeline.length()),
			OutcomeClassifier.told(OutcomeClassifier.labels(timeline)),
		]
	)
