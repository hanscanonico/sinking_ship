extends GutTest
## §5b.4 layer 2: real wrecks as test-only hulls (WreckHull, tests/fixtures/wrecks/),
## each baked alone and again with its holes' area × 0.9 and × 1.1, against bands as
## wide as the sources disagree. Their unverified numbers are marked est. in the data.

const ANDREA_DORIA := "res://tests/fixtures/wrecks/andrea_doria.tres"
const LUSITANIA := "res://tests/fixtures/wrecks/lusitania.tres"
const STOCKHOLM := "res://tests/fixtures/wrecks/stockholm.tres"
const MARGINS: Array[float] = [0.9, 1.0, 1.1]
## Bakes run this long at most, in physics seconds.
const CAP := 7200.0


## [param path]'s wreck baked alone, every hole [param scale] times as big.
func _bake(path: String, scale: float) -> SinkTimeline:
	var wreck: WreckHull = load(path)
	var structure := wreck.structure()
	for opening: ShipOpening in structure.openings:
		if opening.kind == ShipOpening.Kind.GASH:
			opening.area *= scale
	var sea := SeaPhysics.load_default()
	return SinkTimeline.bake(SinkStepper.new(structure, HitDamage.new(), sea), sea, CAP)


func _rotation(timeline: SinkTimeline, frame: int) -> PackedFloat64Array:
	return timeline.rotations.slice(frame * 9, frame * 9 + 9)


func _first(timeline: SinkTimeline, kind: SinkTimeline.Kind, named: StringName) -> float:
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == kind and event.name == named:
			return event.seconds
	return -1.0


func test_andrea_doria_lists_18_to_22_by_5_min() -> void:
	# Her empty starboard tanks flood: she lists to starboard, 18–22° five minutes on,
	# hardly trimmed, her port boats useless from the moment she passes 15°.
	for scale: float in MARGINS:
		var timeline := _bake(ANDREA_DORIA, scale)
		var at := timeline.frame_at(300.0)
		var heel := BoxBarge.heel_deg(_rotation(timeline, at))
		assert_between(heel, 18.0, 22.0, "× %s: listed 18–22° at 5 min" % scale)
		var steepest := 0.0
		for frame in at + 1:
			steepest = maxf(steepest, absf(BoxBarge.trim_deg(_rotation(timeline, frame))))
		assert_lt(steepest, 3.0, "× %s: trimmed under 3°" % scale)
		var useless := _first(timeline, SinkTimeline.Kind.BOATS_USELESS, &"port")
		assert_between(useless, 0.0, 300.0, "× %s: her port boats useless by then" % scale)
		assert_eq(
			_first(timeline, SinkTimeline.Kind.BOATS_USELESS, &"starboard"),
			-1.0,
			"× %s: and her starboard boats not" % scale
		)


func test_lusitania_lists_12_within_2_min() -> void:
	# Her starboard bunkers open to the sea: 12° of list or more within two minutes.
	for scale: float in MARGINS:
		var timeline := _bake(LUSITANIA, scale)
		var most := 0.0
		for frame in timeline.frame_at(120.0) + 1:
			most = maxf(most, BoxBarge.heel_deg(_rotation(timeline, frame)))
		assert_gte(most, 12.0, "× %s: 12° within 2 min" % scale)


func test_stockholm_bow_damage_survives() -> void:
	# Her bow crushed forward of her collision wall: she floats, trimmed by the head by
	# under 1.5 m of draught at her bow, with under 3° of list.
	var wreck: WreckHull = load(STOCKHOLM)
	for scale: float in MARGINS:
		var timeline := _bake(STOCKHOLM, scale)
		assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "× %s: afloat" % scale)
		var last := timeline.count() - 1
		var rotation := _rotation(timeline, last)
		var bow := BoxBarge.draught_at(
			rotation, timeline.seas[last], wreck.length * 0.5, -wreck.draught
		)
		assert_between(bow - wreck.draught, 0.0, 1.5, "× %s: by the head, under 1.5 m" % scale)
		assert_gt(BoxBarge.trim_deg(rotation), 0.0, "× %s: bow down" % scale)
		assert_lt(absf(BoxBarge.heel_deg(rotation)), 3.0, "× %s: under 3° of list" % scale)
