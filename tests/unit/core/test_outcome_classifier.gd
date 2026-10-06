extends GutTest
## Outcomes are labels read off a finished timeline (§5b.4): every label from a timeline
## made by hand — her leans at a few seconds, how it ends, the events it carries — so
## each is the classifier's reading alone, no physics behind it.


## A timeline by hand: [param rows] of [seconds, trim_deg, heel_deg], ending as
## [param end] — gone at the last row's second, when GONE — carrying [param events].
func _timeline(
	rows: Array, end: SinkTimeline.End, events: Array[SinkTimeline.Event] = []
) -> SinkTimeline:
	var made := SinkTimeline.new()
	for row: Array in rows:
		made.times.append(row[0])
		made.seas.append(0.0)
		var turn := (
			Basis(Vector3.BACK, -deg_to_rad(row[1])) * Basis(Vector3.RIGHT, deg_to_rad(row[2]))
		)
		(
			made
			. rotations
			. append_array(
				PackedFloat64Array(
					[
						turn.x.x,
						turn.y.x,
						turn.z.x,
						turn.x.y,
						turn.y.y,
						turn.z.y,
						turn.x.z,
						turn.y.z,
						turn.z.z,
					]
				)
			)
		)
	made.end = end
	made.events = events
	if end == SinkTimeline.End.GONE:
		made.gone_at = rows[-1][0]
	return made


func test_leans_are_read_as_the_schedule_reads_them() -> void:
	var timeline := _timeline([[0.0, 12.0, -7.0]], SinkTimeline.End.AFLOAT)
	var leans := OutcomeClassifier.leans_at(timeline, 0)
	assert_almost_eq(leans[0], 12.0, 1e-4, "trim, bow down")
	assert_almost_eq(leans[1], -7.0, 1e-4, "heel, port down")


func test_a_hull_still_afloat_survives() -> void:
	var still := _timeline([[0.0, 0.0, 0.0], [900.0, 1.0, 4.0]], SinkTimeline.End.AFLOAT)
	assert_eq(
		OutcomeClassifier.labels(still),
		[OutcomeClassifier.Outcome.AFLOAT] as Array[OutcomeClassifier.Outcome]
	)
	var capped := _timeline([[0.0, 0.0, 0.0], [19800.0, 3.0, 2.0]], SinkTimeline.End.CAPPED)
	assert_eq(
		OutcomeClassifier.labels(capped),
		[OutcomeClassifier.Outcome.AFLOAT] as Array[OutcomeClassifier.Outcome],
		"afloat at the cap"
	)


func test_she_founders_by_the_end_she_goes_with() -> void:
	var head := _timeline([[0.0, 0.0, 0.0], [900.0, 31.0, 5.0]], SinkTimeline.End.GONE)
	assert_eq(
		OutcomeClassifier.labels(head),
		(
			[OutcomeClassifier.Outcome.BY_THE_HEAD, OutcomeClassifier.Outcome.FAST]
			as Array[OutcomeClassifier.Outcome]
		)
	)
	var stern := _timeline([[0.0, 0.0, 0.0], [5000.0, -42.0, -3.0]], SinkTimeline.End.GONE)
	assert_eq(
		OutcomeClassifier.labels(stern),
		[OutcomeClassifier.Outcome.BY_THE_STERN] as Array[OutcomeClassifier.Outcome],
		"and slow"
	)
	var side := _timeline(
		[[0.0, 0.0, 0.0], [2950.0, 2.0, 5.0], [3000.0, 8.0, 64.0]], SinkTimeline.End.GONE
	)
	assert_eq(
		OutcomeClassifier.labels(side),
		[OutcomeClassifier.Outcome.ONTO_HER_SIDE] as Array[OutcomeClassifier.Outcome]
	)


func test_a_fast_sinking_is_gone_within_twenty_minutes() -> void:
	var on_the_mark := _timeline([[0.0, 0.0, 0.0], [1200.0, 20.0, 0.0]], SinkTimeline.End.GONE)
	assert_true(
		OutcomeClassifier.Outcome.FAST in OutcomeClassifier.labels(on_the_mark), "at 20 min"
	)
	var past := _timeline([[0.0, 0.0, 0.0], [1201.0, 20.0, 0.0]], SinkTimeline.End.GONE)
	assert_false(
		OutcomeClassifier.Outcome.FAST in OutcomeClassifier.labels(past), "a second past it"
	)


func test_rolling_past_her_beam_ends_capsizes_her() -> void:
	var rows := [[0.0, 0.0, 0.0], [290.0, 0.0, 2.0], [300.0, 2.0, 60.0], [330.0, 4.0, 130.0]]
	rows.append([400.0, 5.0, 170.0])
	var labels := OutcomeClassifier.labels(_timeline(rows, SinkTimeline.End.GONE))
	assert_eq(
		labels,
		(
			[
				OutcomeClassifier.Outcome.ONTO_HER_SIDE,
				OutcomeClassifier.Outcome.CAPSIZED,
				OutcomeClassifier.Outcome.FAST
			]
			as Array[OutcomeClassifier.Outcome]
		)
	)
	# Capped floating bottom up: held up by the air she trapped, still leaking (§5b.1) —
	# not a survival a match keeps, but its own label.
	var afloat := _timeline([[0.0, 0.0, 0.0], [300.0, 0.0, -150.0]], SinkTimeline.End.CAPPED)
	assert_eq(
		OutcomeClassifier.labels(afloat),
		(
			[OutcomeClassifier.Outcome.CAPSIZED, OutcomeClassifier.Outcome.AFLOAT_UPSIDE_DOWN]
			as Array[OutcomeClassifier.Outcome]
		),
		"upside down"
	)


func test_a_heavy_list_lasts_five_minutes_afloat() -> void:
	# 0 → 20° over 100 s, held, back to 0 over 100 s: listed 15° or more from 75 s to 525 s.
	var long := [[0.0, 0.0, 0.0], [100.0, 0.0, -20.0], [500.0, 0.0, -20.0], [600.0, 0.0, 0.0]]
	long.append([5000.0, 25.0, 0.0])
	assert_eq(
		OutcomeClassifier.labels(_timeline(long, SinkTimeline.End.GONE)),
		(
			[OutcomeClassifier.Outcome.BY_THE_HEAD, OutcomeClassifier.Outcome.HEAVY_LIST]
			as Array[OutcomeClassifier.Outcome]
		)
	)
	var short := [[0.0, 0.0, 0.0], [100.0, 0.0, 20.0], [300.0, 0.0, 20.0], [400.0, 0.0, 0.0]]
	short.append([5000.0, 25.0, 0.0])
	assert_eq(
		OutcomeClassifier.labels(_timeline(short, SinkTimeline.End.GONE)),
		[OutcomeClassifier.Outcome.BY_THE_HEAD] as Array[OutcomeClassifier.Outcome],
		"250 s listed is no heavy list"
	)
	# Listed only as she goes: not afloat.
	var going := [[0.0, 0.0, 0.0], [1000.0, 0.0, 2.0], [1400.0, 10.0, 20.0]]
	assert_false(
		(
			OutcomeClassifier.Outcome.HEAVY_LIST
			in OutcomeClassifier.labels(_timeline(going, SinkTimeline.End.GONE))
		),
		"a list she goes with is no heavy list afloat"
	)


func test_a_side_s_boats_are_useless_as_the_timeline_says() -> void:
	var events: Array[SinkTimeline.Event] = [
		SinkTimeline.Event.new(400.0, SinkTimeline.Kind.BOATS_USELESS, &"port"),
		SinkTimeline.Event.new(900.0, SinkTimeline.Kind.BOATS_USELESS, &"starboard"),
	]
	var rows := [[0.0, 0.0, 0.0], [900.0, 0.0, 18.0], [1500.0, 30.0, 18.0]]
	var labels := OutcomeClassifier.labels(_timeline(rows, SinkTimeline.End.GONE, events))
	assert_eq(
		labels,
		(
			[
				OutcomeClassifier.Outcome.BY_THE_HEAD,
				OutcomeClassifier.Outcome.HEAVY_LIST,
				OutcomeClassifier.Outcome.PORT_BOATS_USELESS,
				OutcomeClassifier.Outcome.STARBOARD_BOATS_USELESS
			]
			as Array[OutcomeClassifier.Outcome]
		)
	)
	assert_eq(
		OutcomeClassifier.told(labels),
		"founders by the head · heavy list · port boats useless · starboard boats useless"
	)


func test_a_hull_stood_on_end_has_no_list() -> void:
	# On end by the head, she turns about her length as she goes: no capsize, no list.
	var rows := [[0.0, 0.0, 0.0], [3000.0, 30.0, 4.0], [3060.0, 70.0, 60.0]]
	rows.append([3100.0, 85.0, 140.0])
	rows.append([3400.0, 89.0, -170.0])
	assert_eq(
		OutcomeClassifier.labels(_timeline(rows, SinkTimeline.End.GONE)),
		[OutcomeClassifier.Outcome.BY_THE_HEAD] as Array[OutcomeClassifier.Outcome]
	)
