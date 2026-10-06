class_name MatchTranscript
extends RefCounted
## A match told as text: first its iceberg hit — when, which side, along where and
## the area it opens — and how the must-sink rule came to it; then one line per exit,
## per sinking event — the physics' flooding, filling and spilling cells and her going —
## per railing broken and per crate lost; one for the end; and where her sinking stood
## then, in physics time, and how its bake ends:
##   hit 00:21.4 · starboard · x 5.2…9.0 m · 0.034 m²
##   must 8 thrown · 2 bakes · rung 3
##   00:52.3 seat 4 out · cold · place 6
##   01:02.1 hold_bilge flooding
##   01:31.0 seat 1 out · cold · place 5 · credit crate 2
##   winner seat 2 at 02:21.0 · digest 9f3c…
##   sinking at the end: physics 0:02:18 · sea 1.21 m up her · trim +2.1° · list -0.4° ·
##     hold_bilge full · hold 0.3 m
##   bake: gone at 0:09:12 · trim +31.0° · list +3.2°
## What `make match` prints and what the golden files hold. Seats are sim seat ids.

const CAUSES := {PlayerState.Cause.NONE: "none", PlayerState.Cause.COLD: "cold"}
const DIGEST_LENGTH := 16

var _lines := PackedStringArray()
var _ended: SimEvent


## Match time as mm:ss.t, from the tick count — tenths rounded down.
static func clock(tick: int) -> String:
	var tenths := tick * 10 / Ticks.RATE
	return "%02d:%02d.%d" % [tenths / 600, tenths / 10 % 60, tenths % 10]


## The hit [param schedule] strikes, as the first line; none for a match without one.
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
			"hit %s · %s · x %.1f…%.1f m · %.3f m²"
			% [
				clock(schedule.hit_tick()),
				schedule.hit().side_name(),
				damage.from_x,
				damage.to_x,
				damage.area()
			]
		)
	)


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
			SimEvent.Kind.CRATE_LOST:
				_lines.append("%s crate %d lost" % [clock(event.tick), event.prop])
			SimEvent.Kind.PLUNGE_BEGAN:
				_lines.append("%s the plunge" % clock(event.tick))
			SimEvent.Kind.CELL_FLOODING:
				_lines.append("%s %s flooding" % [clock(event.tick), event.cell])
			SimEvent.Kind.CELL_FULL:
				_lines.append("%s %s full" % [clock(event.tick), event.cell])
			SimEvent.Kind.WATER_SPILLING:
				_lines.append("%s water through %s" % [clock(event.tick), event.cell])
			SimEvent.Kind.SHIP_GONE:
				_lines.append("%s she is gone" % clock(event.tick))
			SimEvent.Kind.BOATS_USELESS:
				_lines.append("%s %s boats useless" % [clock(event.tick), event.cell])


## " · credit crate n" for an exit a crate is credited with — " shoved by seat s"
## when a seat's shove sent it — and nothing for any other.
static func _crate_credit(event: SimEvent) -> String:
	if event.prop == -1:
		return ""
	var line := " · credit crate %d" % event.prop
	if event.credit != -1:
		line += " shoved by seat %d" % event.credit
	return line


## The closing line: the verdict, or where the match was stopped, and the digest — told
## first, for a match that ended as she leaned past what a match follows (§5b.3's
## interim rule), how far over she lay then.
func finish(runner: MatchRunner) -> void:
	var digest := runner.digest.hex().substr(0, DIGEST_LENGTH)
	var schedule := runner.sim.schedule
	if _ended != null and _ended.tick == schedule.unsupported_tick():
		var up := schedule.pose_at(_ended.tick).transform.basis.y.y
		_lines.append(
			(
				"%s she lies %.0f° over · the match follows her no further"
				% [clock(_ended.tick), rad_to_deg(acos(clampf(up, -1.0, 1.0)))]
			)
		)
	if _ended == null:
		_lines.append("unfinished at %s · digest %s" % [clock(runner.tick()), digest])
	elif _ended.seat == -1:
		_lines.append("draw at %s · digest %s" % [clock(_ended.tick), digest])
	else:
		_lines.append(
			"winner seat %d at %s · digest %s" % [_ended.seat, clock(_ended.tick), digest]
		)
	_sinking(runner.sim)


## Physics time as h:mm:ss, from whole seconds.
static func physics_clock(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d:%02d" % [whole / 3600, whole / 60 % 60, whole % 60]


## Where [param sim]'s sinking stood when the match ended or stopped — how long the
## physics had run, how far the sea had risen up her and the water over each wet cell's
## lowest corner, level with the world — and how its bake ends, past what the match
## played.
func _sinking(sim: MatchSim) -> void:
	var timeline := sim.schedule.timeline()
	if timeline == null:
		return
	var tick := _ended.tick if _ended != null else sim.state.tick
	var since := (
		Ticks.to_seconds(maxi(tick - sim.schedule.hit_tick(), 0)) * sim.config.scenario.clock
	)
	var pose := sim.schedule.pose_at(tick)
	var line := (
		"sinking at the end: physics %s · sea %.2f m up her · trim %+.1f° · list %+.1f°"
		% [physics_clock(since), pose.sink, pose.trim_deg, pose.heel_deg]
	)
	var structure := sim.config.ship.structure
	for index in structure.cells.size():
		var cell := structure.cells[index]
		var lowest := INF
		var highest := -INF
		for corner in 8:
			var point := Vector3(
				cell.high.x if corner & 1 else cell.low.x,
				cell.high.y if corner & 2 else cell.low.y,
				cell.high.z if corner & 4 else cell.low.z
			)
			lowest = minf(lowest, pose.world_height(point))
			highest = maxf(highest, pose.world_height(point))
		var level := pose.levels[index]
		if level >= highest:
			line += " · %s full" % cell.name
		elif level - lowest >= SinkTimeline.FIRST_WATER:
			line += " · %s %.2f m" % [cell.name, level - lowest]
	_lines.append(line)
	var ends := {
		SinkTimeline.End.GONE: "gone at %s" % physics_clock(timeline.gone_at),
		SinkTimeline.End.AFLOAT: "afloat from %s" % physics_clock(timeline.length()),
		SinkTimeline.End.CAPPED: "afloat at the cap, %s" % physics_clock(timeline.length()),
	}
	# How she stood as she went — or as the bake ended — read off her pose then.
	var last := sim.schedule.gone_tick() if timeline.is_gone() else sim.schedule.end_tick()
	var going := sim.schedule.pose_at(last)
	_lines.append(
		(
			"bake: %s · trim %+.1f° · list %+.1f°"
			% [ends[timeline.end], going.trim_deg, going.heel_deg]
		)
	)


func text() -> String:
	return "\n".join(_lines) + "\n"
