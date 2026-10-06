class_name OutcomeClassifier
extends RefCounted
## How a sinking came out (§5b.4): labels read off a finished timeline — one sinking can
## carry several — and nothing else. A label drives nothing: no rule, no bot and no
## scene asks one (D7, D13); the tools print them and the census counts them (R24).
## Her leans are read as SinkSchedule reads them (leans_of), at the states the timeline
## kept.

## AFLOAT: the water stopped, or the cap came, with her afloat (survives) — or
## AFLOAT_UPSIDE_DOWN, past her beam ends and held up by the air she trapped, which is
## still leaking (§5b.1: she counts as gone only once it has leaked and she is under; a
## match draws such a hit again). Gone, she
## founders BY_THE_HEAD or BY_THE_STERN as the trim she goes with is the larger lean, or
## ONTO_HER_SIDE as the list is; CAPSIZED: she rolled past her beam ends on the way.
## Stood further on end than ON_END_DEG of trim she has no list to speak of — the lurch
## rule's reading (§5b.4) — so a roll then is neither a list nor a capsize, and she goes
## by an end. HEAVY_LIST: listed HEAVY_LIST_DEG or more for HEAVY_LIST_SECONDS together
## while afloat. FAST: gone within FAST_SECONDS of physics. PORT_BOATS_USELESS,
## STARBOARD_BOATS_USELESS: that side's lifeboats past their list limit.
enum Outcome {
	AFLOAT,
	BY_THE_HEAD,
	BY_THE_STERN,
	ONTO_HER_SIDE,
	CAPSIZED,
	HEAVY_LIST,
	FAST,
	PORT_BOATS_USELESS,
	STARBOARD_BOATS_USELESS,
	AFLOAT_UPSIDE_DOWN,
}

## The census's own marks (§5b.4's table, est.): a heavy list, and a fast sinking.
const HEAVY_LIST_DEG := 15.0
const HEAVY_LIST_SECONDS := 300.0
const FAST_SECONDS := 1200.0
const CAPSIZED_DEG := 90.0
const ON_END_DEG := 45.0
const NAMES := {
	Outcome.AFLOAT: "survives",
	Outcome.BY_THE_HEAD: "founders by the head",
	Outcome.BY_THE_STERN: "founders by the stern",
	Outcome.ONTO_HER_SIDE: "founders onto her side",
	Outcome.CAPSIZED: "capsized",
	Outcome.HEAVY_LIST: "heavy list",
	Outcome.FAST: "fast",
	Outcome.PORT_BOATS_USELESS: "port boats useless",
	Outcome.STARBOARD_BOATS_USELESS: "starboard boats useless",
	Outcome.AFLOAT_UPSIDE_DOWN: "afloat upside down",
}


## Every label [param timeline] earns, in Outcome's order.
static func labels(timeline: SinkTimeline) -> Array[Outcome]:
	var found := {}
	var gone_at := timeline.gone_at if timeline.is_gone() else INF
	var heels := PackedFloat64Array()
	for frame in timeline.count():
		var leans := leans_at(timeline, frame)
		var heel := absf(leans[1]) if absf(leans[0]) < ON_END_DEG else 0.0
		heels.append(heel)
		if heel > CAPSIZED_DEG and timeline.times[frame] <= gone_at:
			found[Outcome.CAPSIZED] = true
	if _longest_list(timeline, heels, gone_at) >= HEAVY_LIST_SECONDS:
		found[Outcome.HEAVY_LIST] = true
	if timeline.is_gone():
		var leans := leans_at(timeline, timeline.frame_at(timeline.gone_at))
		if absf(leans[0]) < ON_END_DEG and absf(leans[1]) > absf(leans[0]):
			found[Outcome.ONTO_HER_SIDE] = true
		else:
			found[Outcome.BY_THE_HEAD if leans[0] > 0.0 else Outcome.BY_THE_STERN] = true
		if timeline.gone_at <= FAST_SECONDS:
			found[Outcome.FAST] = true
	elif timeline.rotations[(timeline.count() - 1) * 9 + 4] < 0.0:
		found[Outcome.AFLOAT_UPSIDE_DOWN] = true
	else:
		found[Outcome.AFLOAT] = true
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == SinkTimeline.Kind.BOATS_USELESS:
			var port := event.name == &"port"
			found[Outcome.PORT_BOATS_USELESS if port else Outcome.STARBOARD_BOATS_USELESS] = true
	var made: Array[Outcome] = []
	for label: Outcome in Outcome.values():
		if found.has(label):
			made.append(label)
	return made


## The longest she lay listed HEAVY_LIST_DEG or more without a break before
## [param gone_at], in seconds: her list, [param heels] at each kept state, carried
## straight between them, so a list that rises and falls between two states is timed
## from where it crosses the mark.
static func _longest_list(
	timeline: SinkTimeline, heels: PackedFloat64Array, gone_at: float
) -> float:
	var longest := 0.0
	var run := 0.0
	for frame in range(1, timeline.count()):
		var from := timeline.times[frame - 1]
		if from >= gone_at:
			break
		var span := minf(timeline.times[frame], gone_at) - from
		var before := heels[frame - 1] - HEAVY_LIST_DEG
		var after := heels[frame] - HEAVY_LIST_DEG
		if before >= 0.0 and after >= 0.0:
			run += span
		elif before >= 0.0:
			run += span * before / (before - after)
		elif after >= 0.0:
			run = span * after / (after - before)
		else:
			run = 0.0
		longest = maxf(longest, run)
		if after < 0.0:
			run = 0.0
	return longest


## [param labels] as words, in their order: "founders by the head · heavy list".
static func told(labels_of: Array[Outcome]) -> String:
	var words := PackedStringArray()
	for label: Outcome in labels_of:
		words.append(NAMES[label])
	return " · ".join(words)


## Her trim and heel at kept state [param frame], in degrees (SinkSchedule.leans_of).
static func leans_at(timeline: SinkTimeline, frame: int) -> PackedFloat64Array:
	var r := timeline.rotations.slice(frame * 9, frame * 9 + 9)
	var turn := Basis(
		Vector3(r[0], r[3], r[6]), Vector3(r[1], r[4], r[7]), Vector3(r[2], r[5], r[8])
	)
	return SinkSchedule.leans_of(turn)
