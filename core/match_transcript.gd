class_name MatchTranscript
extends RefCounted
## A match told as text: first its iceberg hit — when, which side, along where and
## the area it opens — and how the must-sink rule came to it; then one line per exit,
## per sinking event — the physics' flooding, filling and spilling cells and her going —
## per railing broken, per prop afloat and per prop lost, per prop grabbed, let go of or
## knocked loose (#273), and per seat a falling funnel knocks down; one for the end; and
## where her sinking stood then, in physics time, how its bake ends and the worst her
## bending came to:
##   hit 00:21.4 · starboard · x 5.2…9.0 m · 0.034 m²
##   must 8 thrown · 2 bakes · rung 3
##   00:52.3 seat 4 out · cold · place 6
##   01:02.1 hold_bilge flooding
##   01:31.0 seat 1 out · cold · place 5 · credit crate 2
##   02:21.0 seat 3 out · with her · place 2
##   winner seat 2 at 02:21.0 · digest 9f3c…
##   sinking at the end of the match: physics 0:02:18 (on the paced clock, Q20) ·
##     seen 25% · sea 1.21 m up her · trim +2.1° · list -0.4° · hold_bilge full · hold 0.3 m
##   not played: gone at 0:09:12 · trim +31.0° · list +3.2° · founders by the head · fast
##   bending peak 0.05 of strength, x +1.5 m, sagging
## A survival match (MatchRules.Goal) says so first — "goal survival" — and after its
## verdict how many seats were still in at the plunge:
##   3 of 8 seats in at the plunge 04:12.0
## What `make match` prints and what the golden files hold. Seats are sim seat ids.

const CAUSES := {
	PlayerState.Cause.NONE: "none",
	PlayerState.Cause.COLD: "cold",
	PlayerState.Cause.WITH_HER: "with her",
}
const DIGEST_LENGTH := 16
## How the results word her end (founders), by the label that tells it, the first
## found first.
const FOUNDERS := {
	OutcomeClassifier.Outcome.BROKE_IN_THREE: "breaks in three",
	OutcomeClassifier.Outcome.BROKE_IN_TWO: "breaks in two",
	OutcomeClassifier.Outcome.BY_THE_HEAD: "down by the head",
	OutcomeClassifier.Outcome.BY_THE_STERN: "down by the stern",
	OutcomeClassifier.Outcome.ONTO_HER_SIDE: "over on her side",
	OutcomeClassifier.Outcome.AFLOAT_UPSIDE_DOWN: "afloat upside down",
	OutcomeClassifier.Outcome.AGROUND: "aground",
	OutcomeClassifier.Outcome.AFLOAT: "stays afloat",
}

var _lines := PackedStringArray()
var _ended: SimEvent
var _survival := false


## Match time as mm:ss.t, from the tick count — tenths rounded down.
static func clock(tick: int) -> String:
	var tenths := tick * 10 / Ticks.RATE
	return "%02d:%02d.%d" % [tenths / 600, tenths / 10 % 60, tenths % 10]


## The hit [param schedule] strikes, as the first line — and the sea's waves, where it
## has them; none for a match without one.
func hit(schedule: SinkSchedule) -> void:
	if schedule.hit() == null:
		return
	var damage := schedule.damage()
	var choice := schedule.choice()
	var came := (
		"sure hit" if choice.sure else ("rung %d" % choice.rung if choice.rung > 0 else "drawn")
	)
	_lines.insert(0, "must %d thrown · %d bakes · %s" % [choice.thrown, choice.bakes, came])
	_lines.insert(
		0,
		(
			"hit %s · %s · x %.1f…%.1f m · %.3f m²%s"
			% [
				clock(schedule.hit_tick()),
				schedule.hit().side_name(),
				damage.from_x,
				damage.to_x,
				damage.area(),
				sea_state(damage)
			]
		)
	)


## The goal [param config] plays, as the first line, for a survival match; nothing for
## the battle royale, whose transcripts stay as they were.
func goal(config: MatchConfig) -> void:
	_survival = config.goal == MatchRules.Goal.SURVIVAL
	if _survival:
		_lines.insert(0, "goal survival")


## " · sea 1.1 m" for a hit struck in waves 1.1 m high; nothing for a still sea.
static func sea_state(damage: HitDamage) -> String:
	return " · sea %.1f m" % damage.wave_height if damage.wave_height > 0.0 else ""


func add(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		match event.kind:
			SimEvent.Kind.SEAT_OUT:
				_lines.append(
					(
						"%s seat %d out · %s · place %d%s"
						% [
							clock(event.tick),
							event.seat,
							CAUSES[event.cause],
							event.place,
							_crate_credit(event)
						]
					)
				)
			SimEvent.Kind.MATCH_ENDED:
				_ended = event
			SimEvent.Kind.SHIP_LURCHING:
				_lines.append("%s lurch coming · heel %+.0f°" % [clock(event.tick), event.heel_deg])
			SimEvent.Kind.SHIP_LURCHED:
				_lines.append("%s lurched · heel %+.0f°" % [clock(event.tick), event.heel_deg])
			SimEvent.Kind.PLATFORM_COLLAPSING:
				_lines.append("%s %s collapsing" % [clock(event.tick), event.platform])
			SimEvent.Kind.PLATFORM_COLLAPSED:
				_lines.append("%s %s collapsed" % [clock(event.tick), event.platform])
			SimEvent.Kind.RAILING_BROKE:
				_lines.append("%s railing %d broke" % [clock(event.tick), event.railing])
			SimEvent.Kind.PROP_AFLOAT:
				_lines.append("%s prop %d afloat" % [clock(event.tick), event.prop])
			SimEvent.Kind.PROP_LOST:
				_lines.append("%s prop %d lost" % [clock(event.tick), event.prop])
			SimEvent.Kind.PROP_GRABBED:
				_lines.append(
					"%s seat %d grabs prop %d" % [clock(event.tick), event.seat, event.prop]
				)
			SimEvent.Kind.PROP_LET_GO:
				var let_go := "%s seat %d lets go of prop %d"
				_lines.append(let_go % [clock(event.tick), event.seat, event.prop])
			SimEvent.Kind.KNOCKED_LOOSE:
				var loose := "%s seat %d's prop %d knocked loose by seat %d"
				_lines.append(loose % [clock(event.tick), event.seat, event.prop, event.credit])
			SimEvent.Kind.PLUNGE_BEGAN:
				_lines.append("%s the plunge%s" % [clock(event.tick), _of_piece(event)])
			SimEvent.Kind.CELL_FLOODING:
				_lines.append("%s %s flooding" % [clock(event.tick), event.cell])
			SimEvent.Kind.CELL_FULL:
				_lines.append("%s %s full" % [clock(event.tick), event.cell])
			SimEvent.Kind.WATER_SPILLING:
				_lines.append("%s water through %s" % [clock(event.tick), event.cell])
			SimEvent.Kind.SHIP_GONE:
				_lines.append("%s %s is gone" % [clock(event.tick), _gone_name(event)])
			SimEvent.Kind.BOATS_USELESS:
				_lines.append("%s %s boats useless" % [clock(event.tick), event.cell])
			SimEvent.Kind.AIR_TRAPPED:
				_lines.append("%s air trapped in %s" % [clock(event.tick), event.cell])
			SimEvent.Kind.AIR_VENTED:
				_lines.append("%s air let out of %s" % [clock(event.tick), event.cell])
			SimEvent.Kind.OPENING_LEAKING:
				_lines.append("%s %s leaking" % [clock(event.tick), event.cell])
			SimEvent.Kind.OPENING_GAVE_WAY:
				_lines.append("%s %s gave way" % [clock(event.tick), event.cell])
			SimEvent.Kind.FUNNEL_STRAINING:
				_lines.append("%s %s creaking" % [clock(event.tick), event.cell])
			SimEvent.Kind.FUNNEL_FALLING:
				_lines.append("%s %s falling" % [clock(event.tick), event.cell])
			SimEvent.Kind.POWER_LOST:
				_lines.append("%s %s stopped" % [clock(event.tick), event.cell])
			SimEvent.Kind.POWER_BACK:
				_lines.append("%s %s running again" % [clock(event.tick), event.cell])
			SimEvent.Kind.LIGHTS_OUT:
				_lines.append("%s lights out" % clock(event.tick))
			SimEvent.Kind.LAMPS_DROWNED:
				_lines.append("%s %s lamps drowned" % [clock(event.tick), event.cell])
			SimEvent.Kind.HULL_STRESSED:
				_lines.append("%s hull creaking" % clock(event.tick))
			SimEvent.Kind.KNOCKED_DOWN:
				_lines.append(
					(
						"%s seat %d knocked down by the %s"
						% [clock(event.tick), event.seat, event.cell]
					)
				)
			SimEvent.Kind.GROUNDED:
				_lines.append("%s she touches the bottom%s" % [clock(event.tick), _of_piece(event)])
			SimEvent.Kind.HULL_HINGING:
				_lines.append("%s her hull hinging at %s" % [clock(event.tick), event.cell])
			SimEvent.Kind.HULL_PARTED:
				_lines.append("%s her hull parts at %s" % [clock(event.tick), event.cell])


## Whose a physics event of the whole ship is once she has broken (SH33): " of piece n",
## or nothing for the whole ship; and who is gone, "she" or "piece n".
static func _of_piece(event: SimEvent) -> String:
	return "" if event.cell.is_empty() else " of %s" % event.cell


static func _gone_name(event: SimEvent) -> String:
	return "she" if event.cell.is_empty() else String(event.cell)


## " · credit crate n" for an exit a crate is credited with — " shoved by seat s"
## when a seat's shove sent it — and nothing for any other.
static func _crate_credit(event: SimEvent) -> String:
	if event.prop == -1:
		return ""
	var line := " · credit crate %d" % event.prop
	if event.credit != -1:
		line += " shoved by seat %d" % event.credit
	return line


## The closing line: the verdict, or where the match was stopped, and the digest.
func finish(runner: MatchRunner) -> void:
	var digest := runner.digest.hex().substr(0, DIGEST_LENGTH)
	if _ended == null:
		_lines.append("unfinished at %s · digest %s" % [clock(runner.tick()), digest])
	elif _ended.seat == -1:
		# Under survival everyone out is no draw: the last out places first.
		var verdict := "all out" if _survival else "draw"
		_lines.append("%s at %s · digest %s" % [verdict, clock(_ended.tick), digest])
	else:
		_lines.append(
			"winner seat %d at %s · digest %s" % [_ended.seat, clock(_ended.tick), digest]
		)
	if _survival:
		_lines.append(at_the_plunge(runner.sim))
	_sinking(runner.sim)


## How many of [param sim]'s seats were still in at her plunge (plunge_tick): those out
## on or after it, or never; or that she never plunged in what the match played.
static func at_the_plunge(sim: MatchSim) -> String:
	var plunge := sim.schedule.plunge_tick()
	if plunge < 0 or plunge >= sim.state.tick:
		return "no plunge while the match played"
	var still := 0
	for player: PlayerState in sim.state.seats:
		if not player.is_out() or player.out_tick >= plunge:
			still += 1
	return "%d of %d seats in at the plunge %s" % [still, sim.state.seats.size(), clock(plunge)]


## Physics time as h:mm:ss, from whole seconds.
static func physics_clock(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d:%02d" % [whole / 3600, whole / 60 % 60, whole % 60]


## Where [param sim]'s sinking stood when the match ended or stopped — how long the
## physics had run, and through her paced clock what share of the whole sinking
## the match saw (R33), how far the sea had risen up her and the water over each wet
## cell's lowest corner, level with the world, as the piece holding it has them — and
## how its bake ends, past what the match played, with the labels read off it
## (OutcomeClassifier).
func _sinking(sim: MatchSim) -> void:
	var timeline := sim.schedule.timeline()
	if timeline == null:
		return
	var tick := _ended.tick if _ended != null else sim.state.tick
	var since := sim.schedule.physics_at(maxi(tick, sim.schedule.hit_tick()))
	var pose := sim.schedule.pose_at(tick)
	var whole := timeline.gone_at if timeline.is_gone() else timeline.length()
	var clocked := (
		"on the paced clock, Q20"
		if sim.config.scenario.clock == 1.0
		else "on the paced clock × %s, Q20" % sim.config.scenario.clock
	)
	var line := (
		(
			"sinking at the end of the match: physics %s (%s) · seen %.0f%% · sea %.2f m up her"
			+ " · trim %+.1f° · list %+.1f°"
		)
		% [
			physics_clock(since),
			clocked,
			minf(since / whole, 1.0) * 100.0,
			pose.sink,
			pose.trim_deg,
			pose.heel_deg,
		]
	)
	var structure := sim.config.ship.structure
	for named: FloodCell in structure.cells:
		var leaf := _leaf_of(sim.schedule, named.name)
		var own := pose.of_piece(leaf)
		var index := sim.schedule.structure_of(leaf).cell_named(named.name)
		var cell := sim.schedule.structure_of(leaf).cells[index]
		var lowest := INF
		var highest := -INF
		for corner in 8:
			var point := Vector3(
				cell.high.x if corner & 1 else cell.low.x,
				cell.high.y if corner & 2 else cell.low.y,
				cell.high.z if corner & 4 else cell.low.z
			)
			lowest = minf(lowest, own.world_height(point))
			highest = maxf(highest, own.world_height(point))
		var level := own.levels[index]
		if level >= highest:
			line += " · %s full" % cell.name
		elif level - lowest >= SinkTimeline.FIRST_WATER:
			line += " · %s %.2f m" % [cell.name, level - lowest]
	_lines.append(line)
	var ends := {
		SinkTimeline.End.GONE: "gone at %s" % physics_clock(timeline.gone_at),
		SinkTimeline.End.AFLOAT: "afloat from %s" % physics_clock(timeline.length()),
		SinkTimeline.End.CAPPED: "afloat at the cap, %s" % physics_clock(timeline.length()),
		SinkTimeline.End.AGROUND: "aground from %s" % physics_clock(timeline.length()),
	}
	# How she stood as she went — or as the bake ended — read off her pose then.
	var last := sim.schedule.gone_tick() if timeline.is_gone() else sim.schedule.end_tick()
	var going := sim.schedule.pose_at(last)
	var played := "not played" if since < whole else "played to the end"
	var labels := OutcomeClassifier.told(OutcomeClassifier.labels(timeline))
	_lines.append(
		(
			"%s: %s · trim %+.1f° · list %+.1f° · %s"
			% [played, ends[timeline.end], going.trim_deg, going.heel_deg, labels]
		)
	)
	_lines.append(bending(timeline))


## The share of [param schedule]'s whole sinking — from the hit to her going, or to its
## bake's end when she does not go — the match had played by [param tick], 0…1, in
## match time: what a player sat through of it. Not the transcript's "seen", the
## physics' share, which her paced clock (Q20) runs far ahead, drawing her end out.
## Read off the baked schedule alone (D7); 0 for a match without a sinking.
static func share_played(schedule: SinkSchedule, tick: int) -> float:
	var timeline := schedule.timeline()
	if timeline == null:
		return 0.0
	var hit := schedule.hit_tick()
	var whole := schedule.gone_tick() if timeline.is_gone() else schedule.end_tick()
	return clampf(float(tick - hit) / float(maxi(whole - hit, 1)), 0.0, 1.0)


## How the results tell her fate in a line: [param ship_name], how her sinking ends
## (founders) and the share of it played by [param tick], the match's end
## (share_played) — "Steamer · down by the head · 27% of her sinking played". Empty for
## a match without a sinking. All of it is baked in [param schedule] (D7): nothing on a
## clock.
static func fate_line(ship_name: String, schedule: SinkSchedule, tick: int) -> String:
	var timeline := schedule.timeline()
	if timeline == null:
		return ""
	return fate_told(ship_name, OutcomeClassifier.labels(timeline), share_played(schedule, tick))


## The fate line of [param ship_name] whose sinking earns [param labels_of], with
## [param share] of it played (fate_line).
static func fate_told(
	ship_name: String, labels_of: Array[OutcomeClassifier.Outcome], share: float
) -> String:
	return (
		"%s · %s · %.0f%% of her sinking played"
		% [ship_name, founders(labels_of), clampf(share, 0.0, 1.0) * 100.0]
	)


## How a sinking that earns [param labels_of] ends, in a few words: her hull parting
## first, the most of what befalls her, then the way she goes, or that she does not.
static func founders(labels_of: Array[OutcomeClassifier.Outcome]) -> String:
	for label: OutcomeClassifier.Outcome in FOUNDERS:
		if labels_of.has(label):
			return FOUNDERS[label]
	return "her end untold"


## The first piece of [param schedule]'s sinking she ends in, aft to fore, that holds
## her cell [param cell] — the whole ship, while she does not break: the piece whose pose
## has the cell's water and where it stands.
static func _leaf_of(schedule: SinkSchedule, cell: StringName) -> int:
	if schedule.piece_count() == 1:
		return 0
	for leaf: int in schedule.timeline().pieces_at(INF):
		if schedule.structure_of(leaf).cell_named(cell) != -1:
			return leaf
	return 0


## How far [param timeline]'s bending came toward her strength at its worst, where along
## her, and which way it bent her (HullGirder).
static func bending(timeline: SinkTimeline) -> String:
	return (
		"bending peak %.2f of strength, x %+.1f m, %s"
		% [
			absf(timeline.bending),
			timeline.bending_x,
			"hogging" if timeline.bending >= 0.0 else "sagging",
		]
	)


func text() -> String:
	return "\n".join(_lines) + "\n"
