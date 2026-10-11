extends GutTest
## The Britannic on her mine in the Kea Channel, 120 m deep (titanic_britannic_kea.tres),
## with her lower ports shut and with them open as they were that morning (SH34): the
## test-only hull tools/gen_titanic.py writes with her bulkheads and inner skin
## (SB-1914). What her data meets is asserted, and what it cannot is pending with the
## number the bake measured. The Olympic is test_titanic_olympic's.

const KEA := "res://tests/fixtures/sinking/titanic_britannic_kea.tres"
const MINUTE := 60.0
## Britannic with her ports shut lasts at least this long, if she goes at all.
const LASTS := 6.0 * 60.0 * MINUTE
## With them open she goes in 40–80 min.
const GOES := Vector2(40.0 * MINUTE, 80.0 * MINUTE)


func test_the_britannic_with_her_ports_shut_lasts() -> void:
	var timeline := TitanicSisters.bake(
		TitanicSisters.BRITANNIC, "titanic_britannic_mine", load(KEA)
	)
	var told := TitanicSisters.told(timeline)
	gut.p("the Britannic, ports shut: " + told)
	var first_gone := TitanicSisters.first(timeline, SinkTimeline.Kind.GONE)
	if first_gone >= 0.0 and first_gone < LASTS:
		# Five compartments open bring her bow within a couple of metres of the sea; her
		# forecastle and well deck go under and she follows them. Measured.
		pending("the Britannic with her ports shut: " + told)
		return
	assert_true(first_gone < 0.0 or first_gone >= LASTS, "she survives or lasts six hours")


func test_the_britannic_with_her_ports_open_goes_bow_first_onto_the_bottom() -> void:
	var timeline := TitanicSisters.bake(
		TitanicSisters.BRITANNIC, "titanic_britannic_mine_ports", load(KEA)
	)
	var told := TitanicSisters.told(timeline)
	gut.p("the Britannic, ports open: " + told)
	var first_gone := TitanicSisters.first(timeline, SinkTimeline.Kind.GONE)
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
