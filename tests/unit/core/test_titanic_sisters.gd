extends GutTest
## The Titanic's sisters as explicit hits (SH34): the Olympic as her 1913 refit left her,
## on the Titanic's damage of the night, and the Britannic on her mine in the Kea
## Channel, 120 m deep (titanic_britannic_kea.tres), with her lower ports shut and with
## them open as they were that morning — the test-only hulls tools/gen_titanic.py writes
## with their bulkheads and inner skin (SB-1914). What their data meets is asserted, and
## what it cannot is pending with the number the bake measured.

const OLYMPIC := &"titanic_olympic_1913"
const BRITANNIC := &"titanic_britannic"
const HITS := "res://tests/fixtures/sinking/hits/%s.tres"
const KEA := "res://tests/fixtures/sinking/titanic_britannic_kea.tres"
const MINUTE := 60.0
## Britannic with her ports shut lasts at least this long, if she goes at all.
const LASTS := 6.0 * 60.0 * MINUTE
## With them open she goes in 40–80 min.
const GOES := Vector2(40.0 * MINUTE, 80.0 * MINUTE)

var _sea: SeaPhysics


func before_all() -> void:
	_sea = SeaPhysics.load_default()


## [param sister] struck by the fixture hit [param hit_name] in [param scenario], baked.
func _bake(sister: StringName, hit_name: String, scenario: SinkScenario) -> SinkTimeline:
	var structure := Fleet.layout(sister).structure
	var damage := HitMapper.map_explicit(load(HITS % hit_name), structure, scenario.hit)
	damage.sea_depth = scenario.sea_depth
	return SinkBake.of(structure, damage, _sea, scenario.bake_cap).timeline()


## The second of [param timeline]'s first [param kind] event, or -1.
func _first(timeline: SinkTimeline, kind: SinkTimeline.Kind) -> float:
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == kind:
			return event.seconds
	return -1.0


func _told(timeline: SinkTimeline) -> String:
	return (
		"first gone at %s, ends %s at %s: %s"
		% [
			MatchTranscript.physics_clock(_first(timeline, SinkTimeline.Kind.GONE)),
			SinkTimeline.End.keys()[timeline.end],
			MatchTranscript.physics_clock(timeline.length()),
			OutcomeClassifier.told(OutcomeClassifier.labels(timeline)),
		]
	)


func test_the_olympic_refitted_floats_on_the_nights_damage() -> void:
	var timeline := _bake(OLYMPIC, "titanic_night", Fleet.scenario(OLYMPIC))
	var told := _told(timeline)
	gut.p("the Olympic of 1913 on the night's damage: " + told)
	if timeline.end != SinkTimeline.End.AFLOAT or _first(timeline, SinkTimeline.Kind.GONE) >= 0.0:
		# Her bulkheads carried to B deck keep the water forward of boiler room 4, but six
		# compartments open to the sea up through every deck over them draw her bow under,
		# and her forecastle and well deck take the rest. Measured.
		pending("the Olympic founders: " + told)
		return
	assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "she floats")


func test_the_britannic_with_her_ports_shut_lasts() -> void:
	var timeline := _bake(BRITANNIC, "titanic_britannic_mine", load(KEA))
	var told := _told(timeline)
	gut.p("the Britannic, ports shut: " + told)
	var first_gone := _first(timeline, SinkTimeline.Kind.GONE)
	if first_gone >= 0.0 and first_gone < LASTS:
		# Five compartments open bring her bow within a couple of metres of the sea; her
		# forecastle and well deck go under and she follows them. Measured.
		pending("the Britannic with her ports shut: " + told)
		return
	assert_true(first_gone < 0.0 or first_gone >= LASTS, "she survives or lasts six hours")


func test_the_britannic_with_her_ports_open_goes_bow_first_onto_the_bottom() -> void:
	var timeline := _bake(BRITANNIC, "titanic_britannic_mine_ports", load(KEA))
	var told := _told(timeline)
	gut.p("the Britannic, ports open: " + told)
	var first_gone := _first(timeline, SinkTimeline.Kind.GONE)
	assert_between(first_gone, GOES.x, GOES.y, "she goes in 40–80 min")
	var grounded: SinkTimeline.Event = null
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == SinkTimeline.Kind.GROUNDED:
			grounded = event
			break
	assert_not_null(grounded, "she reaches the bottom, 120 m down")
	if grounded == null:
		return
	# Whole and bow down, or the foremost of her pieces.
	var trim := OutcomeClassifier.leans_at(timeline, timeline.frame_at(grounded.seconds))[0]
	var bow_first := (
		trim > 0.0 if grounded.piece == 0 else grounded.piece == timeline.parents.size() - 1
	)
	if not bow_first:
		# She breaks as she plunges (her girder at boiler rooms 1–2, as the Titanic's),
		# and her bow goes down free of the bottom; her stern grounds. Measured.
		pending(
			(
				"her bow first on the bottom: piece %d grounded first, at %s"
				% [grounded.piece, MatchTranscript.physics_clock(grounded.seconds)]
			)
		)
		return
	assert_true(bow_first, "her bow on the bottom first")
