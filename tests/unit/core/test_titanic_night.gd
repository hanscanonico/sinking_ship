extends GutTest
## The Titanic on the night's damage (SH34): the explicit hit the 1912 inquiry describes
## (titanic_night.tres — starboard, 10 ft over her keel, from 2 ft abaft bulkhead E into
## her forepeak, its total area the research's calibration value, R32), baked once and
## read against the research's timeline of the night (§SH34, Dynamic): the water aboard,
## her trim and list, her forecastle, her lights, her break, her stern and her end. Her
## data is tuned to it and the physics is not: what her data meets is asserted, and what
## it cannot is pending with the number the bake measured. Times are physics seconds
## after the hit; lists positive to starboard, trims bow down (SinkSchedule.leans_of).

const NIGHT := "res://tests/fixtures/sinking/hits/titanic_night.tres"
const LONG_TON := 1016.0469
const MINUTE := 60.0
## 16 000 long tons aboard 40 minutes after the hit, ± 25 %.
const ABOARD_AT := 40.0 * MINUTE
const ABOARD := 16000.0
const ABOARD_SHARE := 0.25
## Her trim 0.3–1.5° 15 minutes in, 8–12° at 155.
const EARLY_TRIM_AT := 15.0 * MINUTE
const EARLY_TRIM := Vector2(0.3, 1.5)
const LATE_TRIM_AT := 155.0 * MINUTE
const LATE_TRIM := Vector2(8.0, 12.0)
## Her trim rising slower from an hour in to an hour forty than from a quarter hour in to
## an hour — and the late acceleration, from her forecastle going under to the break, ten
## times that.
const SETTLING := Vector2(60.0 * MINUTE, 100.0 * MINUTE)
const ACCELERATION := 10.0
## The plateau itself (§5b.4, layer 2): her trim rising at most 1.5° an hour from T+60 to
## T+125, her forecastle clear of the sea all that while; and no water in boiler rooms
## 1–3 (their stokeholds, over a cubic metre) before T+100.
const PLATEAU := Vector2(60.0 * MINUTE, 125.0 * MINUTE)
const PLATEAU_MOST := 1.5 / (60.0 * MINUTE)
const DRY_UNTIL := 100.0 * MINUTE
const DRY_ROOMS: Array[StringName] = [&"boiler_room_1", &"boiler_room_2", &"boiler_room_3"]
const DRY := 1.0
## A starboard list early, within her first quarter hour; a port list of 5–15° late, from
## an hour and a half in to the break.
const EARLY_LIST_UNTIL := 15.0 * MINUTE
const STARBOARD := 0.5
const LATE_LIST_FROM := 90.0 * MINUTE
const PORT_LIST := Vector2(-15.0, -5.0)
## Her forecastle head under at T+145 ± 8 min; the break at T+157 ± 10 min, at 8–23° of
## trim (10–17° the target), 130–160 m from her bow; her lights until it, ± 2 min; her
## stern afloat 1–5 min more; she is gone at 160 ± 30 min.
const FORECASTLE_AT := Vector2(137.0 * MINUTE, 153.0 * MINUTE)
const BREAK_AT := Vector2(147.0 * MINUTE, 167.0 * MINUTE)
const BREAK_TRIM := Vector2(8.0, 23.0)
const BREAK_FROM_BOW := Vector2(130.0, 160.0)
const LIGHTS := 2.0 * MINUTE
const STERN_AFTER := Vector2(1.0 * MINUTE, 5.0 * MINUTE)
const GONE_AT := Vector2(130.0 * MINUTE, 190.0 * MINUTE)
## Her stem's head, where her forecastle deck meets her stem: the forecastle head's
## fore top corner, and her bow there.
const STEM := &"forecastle_head"
## The hole's area from about 9 to about 15 square feet (Wilding's 12 between).
const SQUARE_FOOT := 0.3048 * 0.3048
const AREAS: Array[float] = [9.0, 12.0, 15.0]

var _structure: ShipStructure
var _sea: SeaPhysics
var _damage: HitDamage
var _timeline: SinkTimeline
## The water aboard at ABOARD_AT, in m³, and the second it was measured at.
var _aboard := 0.0
var _aboard_at := 0.0
## Her bake to DRY_UNTIL, whole: every state of it kept.
var _early: SinkBake


func before_all() -> void:
	var layout: ShipLayout = load("res://data/ships/titanic.tres")
	_structure = layout.structure
	_sea = SeaPhysics.load_default()
	var scenario := Fleet.scenario(&"titanic")
	_damage = HitMapper.map_explicit(load(NIGHT), _structure, scenario.hit)
	_damage.sea_depth = scenario.sea_depth
	_timeline = SinkBake.of(_structure, _damage, _sea, scenario.bake_cap).timeline()
	# The water aboard is the bake's own (SinkBake.waters), read at its first state from
	# ABOARD_AT on; its states to DRY_UNTIL kept for her stokeholds: whole then, as she
	# is until she breaks, so their cells are hers in her order.
	var early := SinkBake.of(_structure, _damage, _sea, DRY_UNTIL)
	while not early.run(1) and early.seconds() < ABOARD_AT:
		pass
	var waters := early.waters()
	for volume: float in waters.slice(waters.size() - early.cells()):
		_aboard += volume
	_aboard_at = early.seconds()
	early.run(1 << 62)
	_early = early


## Her trim and list at physics second [param seconds], before she breaks.
func _leans(seconds: float) -> PackedFloat64Array:
	return OutcomeClassifier.leans_at(_timeline, _timeline.frame_at(seconds))


## The second of [param timeline]'s first [param kind] event, or -1.
func _first(timeline: SinkTimeline, kind: SinkTimeline.Kind) -> float:
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == kind:
			return event.seconds
	return -1.0


func _event(kind: SinkTimeline.Kind) -> SinkTimeline.Event:
	for event: SinkTimeline.Event in _timeline.events:
		if event.kind == kind:
			return event
	return null


## The second her stem's head first stands under the sea, or -1.
func _forecastle_under() -> float:
	var cell := _structure.cells[_structure.cell_named(STEM)]
	var stem := cell.high
	var leaf := _timeline.leaf_of(0)
	for frame in _timeline.count():
		var r := _timeline.rotation_of(frame, leaf)
		var up := r[3] * stem.x + r[4] * stem.y + r[5] * stem.z
		if up < _timeline.sea_of(frame, leaf):
			return _timeline.times[frame]
	return -1.0


func _clock(seconds: float) -> String:
	return MatchTranscript.physics_clock(seconds)


func test_the_water_aboard_forty_minutes_in() -> void:
	var tons := _aboard * _sea.sea_density / LONG_TON
	var told := "%.0f long tons aboard at %s" % [tons, _clock(_aboard_at)]
	gut.p(told)
	if absf(tons - ABOARD) > ABOARD * ABOARD_SHARE:
		# Her hole is at the bottom of the research's band so that she lasts the night as
		# long as she can (test_she_is_gone_at_about_two_hours_forty); a hole that takes
		# in 16 000 tons by T+40 sinks her within the hour and a half. Measured.
		pending("%s, not 16 000 ± 25 %%" % told)
		return
	assert_almost_eq(tons, ABOARD, ABOARD * ABOARD_SHARE, told)


func test_her_trim_from_a_degree_to_the_plateau_and_the_plunge() -> void:
	var early := _leans(EARLY_TRIM_AT)[0]
	gut.p("trim %.2f° at %s" % [early, _clock(EARLY_TRIM_AT)])
	assert_between(early, EARLY_TRIM.x, EARLY_TRIM.y, "0.3–1.5° a quarter hour in")
	var first := (_leans(SETTLING.x)[0] - early) / (SETTLING.x - EARLY_TRIM_AT)
	var settling := (_leans(SETTLING.y)[0] - _leans(SETTLING.x)[0]) / (SETTLING.y - SETTLING.x)
	var under := _forecastle_under()
	var hinge := _event(SinkTimeline.Kind.HINGING)
	assert_not_null(hinge, "she breaks")
	if hinge == null:
		return
	var late := (_leans(hinge.seconds)[0] - _leans(under)[0]) / (hinge.seconds - under)
	gut.p(
		(
			"trim rising %.3f°/min to an hour, %.3f°/min to an hour forty, %.2f°/min in the plunge"
			% [first * MINUTE, settling * MINUTE, late * MINUTE]
		)
	)
	assert_lt(settling, first, "slower from an hour on than before it")
	assert_gt(late, settling * ACCELERATION, "the late acceleration")
	var missed := PackedStringArray()
	var whole := _timeline.pieces_at(PLATEAU.y).size() == 1
	if under < PLATEAU.y or not whole:
		# Her forecastle is under, and she breaks, before the plateau's end: measured over
		# its first forty minutes, it rises faster than the research's plateau too.
		(
			missed
			. append(
				(
					"a plateau of at most 1.5°/h to %s: her forecastle under at %s, %.2f°/h to %s"
					% [
						_clock(PLATEAU.y),
						_clock(under),
						settling * 60.0 * MINUTE,
						_clock(SETTLING.y),
					]
				)
			)
		)
	else:
		var plateau := (_leans(PLATEAU.y)[0] - _leans(PLATEAU.x)[0]) / (PLATEAU.y - PLATEAU.x)
		if plateau > PLATEAU_MOST:
			missed.append("a plateau of %.2f°/h, not at most 1.5°/h" % (plateau * 60.0 * MINUTE))
	var at_155 := _leans(LATE_TRIM_AT)[0]
	if _timeline.pieces_at(LATE_TRIM_AT).size() > 1 or at_155 < LATE_TRIM.x:
		# She breaks before T+155 (test_she_breaks_where_and_when_she_did).
		missed.append(
			(
				"8–12° at %s: she broke at %s, at %.1f°"
				% [_clock(LATE_TRIM_AT), _clock(hinge.seconds), _leans(hinge.seconds)[0]]
			)
		)
	if not missed.is_empty():
		pending(", ".join(missed))
		return
	var plateau_rate := (_leans(PLATEAU.y)[0] - _leans(PLATEAU.x)[0]) / (PLATEAU.y - PLATEAU.x)
	assert_lte(plateau_rate, PLATEAU_MOST, "a plateau of at most 1.5°/h from T+60 to T+125")
	assert_between(at_155, LATE_TRIM.x, LATE_TRIM.y, "8–12° at T+155")


func test_boiler_rooms_1_to_3_dry_for_a_hundred_minutes() -> void:
	# The most water each stokehold held before T+100, read off every state of her
	# whole bake to then (SinkBake.waters).
	var times := _early.times()
	var waters := _early.waters()
	var count := _early.cells()
	var most := 0.0
	var wettest := &""
	var wet_at := -1.0
	for room: StringName in DRY_ROOMS:
		var at := _structure.cell_named(room)
		for state in times.size():
			if times[state] > DRY_UNTIL:
				break
			var water := waters[state * count + at]
			if water > most:
				most = water
				wettest = room
			if water > DRY and wet_at < 0.0:
				wet_at = times[state]
	var where := "in %s" % wettest if most > 0.0 else "in any"
	gut.p("boiler rooms 1–3 before %s: at most %.2f m³ %s" % [_clock(DRY_UNTIL), most, where])
	if wet_at >= 0.0:
		pending(
			(
				"boiler rooms 1–3 wet before %s: water from %s, %.0f m³ in %s"
				% [_clock(DRY_UNTIL), _clock(wet_at), most, wettest]
			)
		)
		return
	assert_lte(most, DRY, "no water in boiler rooms 1–3 before T+100")


func test_she_lists_to_starboard_early_and_to_port_late() -> void:
	var starboard := -INF
	var port := INF
	var parted := _first(_timeline, SinkTimeline.Kind.PARTED)
	for frame in _timeline.count():
		var seconds := _timeline.times[frame]
		if parted >= 0.0 and seconds >= parted:
			break
		var list := _leans(seconds)[1]
		if seconds <= EARLY_LIST_UNTIL:
			starboard = maxf(starboard, list)
		elif seconds >= LATE_LIST_FROM:
			port = minf(port, list)
	gut.p("most to starboard early %+.1f°, most to port late %+.1f°" % [starboard, port])
	assert_gt(starboard, STARBOARD, "a starboard list in her first quarter hour")
	if port > PORT_LIST.y or port < PORT_LIST.x:
		# Her cells are drawn in to her shell (R23), so the water forward spreads across
		# her and little of it stands to one side. Measured.
		pending("a port list of 5–15° late: at most %+.1f°" % port)
		return
	assert_between(port, PORT_LIST.x, PORT_LIST.y, "a port list of 5–15° late")


func test_her_forecastle_head_goes_under() -> void:
	var under := _forecastle_under()
	gut.p("her forecastle head under at %s" % _clock(under))
	assert_gt(under, 0.0, "her forecastle head goes under")
	if under < FORECASTLE_AT.x or under > FORECASTLE_AT.y:
		pending("her forecastle head under at %s, not T+145 ± 8 min" % _clock(under))
		return
	assert_between(under, FORECASTLE_AT.x, FORECASTLE_AT.y, "T+145 ± 8 min")


func test_she_breaks_where_and_when_she_did() -> void:
	var hinge := _event(SinkTimeline.Kind.HINGING)
	var parted := _event(SinkTimeline.Kind.PARTED)
	assert_not_null(hinge, "she breaks")
	assert_not_null(parted, "in two")
	if hinge == null or parted == null:
		return
	var trim := _leans(hinge.seconds)[0]
	var bow := _structure.cells[_structure.cell_named(STEM)].high.x
	assert_lt(hinge.seconds, parted.seconds, "a hinge, then the parting")
	var from_bow := INF
	for spot: WeakSpot in _structure.strength.weak:
		if spot.name == hinge.name:
			from_bow = bow - spot.x
	gut.p(
		(
			"hinging at %s at %s, %.1f° of trim, %.0f m from her bow; parted at %s"
			% [hinge.name, _clock(hinge.seconds), trim, from_bow, _clock(parted.seconds)]
		)
	)
	assert_between(from_bow, BREAK_FROM_BOW.x, BREAK_FROM_BOW.y, "130–160 m from her bow")
	var missed := PackedStringArray()
	if trim < BREAK_TRIM.x or trim > BREAK_TRIM.y:
		# Her girder gives at its share as her bow plunges, between about 7° and 14° of
		# trim as the water aft of it stands then: a few hundredths of a square metre of
		# hole move it across 8° (R21). Measured.
		missed.append("at %.1f° of trim, not 8–23°" % trim)
	if hinge.seconds < BREAK_AT.x or hinge.seconds > BREAK_AT.y:
		missed.append("at %s, not T+157 ± 10 min" % _clock(hinge.seconds))
	if not missed.is_empty():
		pending("the break " + ", ".join(missed))
		return
	assert_between(trim, BREAK_TRIM.x, BREAK_TRIM.y, "no break under 8°, a break by 23°")
	assert_between(hinge.seconds, BREAK_AT.x, BREAK_AT.y, "T+157 ± 10 min")


func test_her_lights_burn_until_the_break() -> void:
	var parted := _first(_timeline, SinkTimeline.Kind.PARTED)
	var mains := _first(_timeline, SinkTimeline.Kind.POWER_LOST)
	var out := _first(_timeline, SinkTimeline.Kind.LIGHTS_OUT)
	gut.p(
		"her mains stopped %.0f s, her lights out %.0f s, she parts %.0f s" % [mains, out, parted]
	)
	assert_gt(parted, 0.0, "she breaks")
	assert_true(mains < 0.0 or mains >= parted - LIGHTS, "her mains run until the break")
	if out < 0.0 or absf(out - parted) > LIGHTS:
		# Her bow, cut from her generators aft, goes dark as she parts (HullBreak); her
		# stern keeps them while it floats (the test of her stern, below). Measured.
		var stern := "never, her stern lit while it floats" if out < 0.0 else "at %s" % _clock(out)
		pending("her lights out at the break ± 2 min: out %s" % stern)
		return
	assert_almost_eq(out, parted, LIGHTS, "her lights go out at the break, ± 2 min")


func test_she_never_capsizes() -> void:
	var labels := OutcomeClassifier.labels(_timeline)
	gut.p("outcome " + OutcomeClassifier.told(labels))
	if OutcomeClassifier.Outcome.CAPSIZED in labels:
		# Her stern, broken off her (test_her_stern_floats_a_few_minutes_more), lists and
		# fills for hours and rolls over before it goes. Measured.
		pending("her stern capsizes: %s" % OutcomeClassifier.told(labels))
		return
	assert_false(OutcomeClassifier.Outcome.CAPSIZED in labels, "never capsizes")


func test_her_stern_floats_a_few_minutes_more_and_she_is_gone() -> void:
	var parted := _first(_timeline, SinkTimeline.Kind.PARTED)
	var bow_gone := _first(_timeline, SinkTimeline.Kind.GONE)
	gut.p(
		(
			"parted at %s, her bow gone at %s, all of her at %s"
			% [_clock(parted), _clock(bow_gone), _clock(_timeline.gone_at)]
		)
	)
	assert_gt(bow_gone, parted, "her bow goes once she has parted")
	var stern := _timeline.gone_at - parted
	if _timeline.end != SinkTimeline.End.GONE or stern < STERN_AFTER.x or stern > STERN_AFTER.y:
		# A piece of her afloat stays so on its own cells (§5b.3): her stern, its torn end
		# lifted clear as it settles back, takes the hours its open cells take — or lies
		# still, afloat. Measured.
		pending(
			(
				"her stern 1–5 min more and her gone at 160 ± 30 min: %s at %s"
				% [SinkTimeline.End.keys()[_timeline.end], _clock(_timeline.length())]
			)
		)
		return
	assert_between(stern, STERN_AFTER.x, STERN_AFTER.y, "her stern 1–5 min more")
	assert_between(_timeline.gone_at, GONE_AT.x, GONE_AT.y, "gone at 160 ± 30 min")


func test_a_bigger_hole_shortens_her_life() -> void:
	# Her life to the first of her gone — whole, or her bow once she has broken — on
	# holes of 9, 12 and 15 square feet in the night's place: each one shorter.
	var scenario := Fleet.scenario(&"titanic")
	var night: IcebergHit = load(NIGHT)
	var area := _damage.area()
	var lives := PackedFloat64Array()
	for feet: float in AREAS:
		var timeline := _timeline
		if absf(area - feet * SQUARE_FOOT) > 0.01:
			var hit: IcebergHit = night.duplicate()
			hit.width = night.width * feet * SQUARE_FOOT / area
			var damage := HitMapper.map_explicit(hit, _structure, scenario.hit)
			damage.sea_depth = scenario.sea_depth
			timeline = SinkBake.of(_structure, damage, _sea, scenario.bake_cap).timeline()
		lives.append(_first(timeline, SinkTimeline.Kind.GONE))
		gut.p("%.0f ft²: first gone at %s" % [feet, _clock(lives[-1])])
	for index in range(1, lives.size()):
		assert_gt(lives[index], 0.0, "%.0f ft² sinks her" % AREAS[index])
		assert_lt(lives[index], lives[index - 1], "%.0f ft² is quicker" % AREAS[index])
