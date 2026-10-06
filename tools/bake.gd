extends SceneTree
## `make bake SEED=1701 [HIT=path.tres]`: the sinking of a seed's match alone, no match
## played (§5b.4) — the hit the must-sink rule chose for it (or the explicit one HIT=
## gives), the doors the ship shuts and the openings left open, how the rule came to
## it, then every event of the bake in physics time, h:mm:ss, how she ends and the
## labels read off it (OutcomeClassifier), and what the bake cost and the timeline
## weighs, compacted and with every state kept. Everything is asked of the match's
## config and schedule (D13); only the cost is this machine's.
##
##   godot --headless --path . -s res://tools/bake.gd -- --seed=1701

const RunMatch := preload("res://tools/run_match.gd")
## The events whose lines say how she leans then.
const LEANING: Array[SinkTimeline.Kind] = [
	SinkTimeline.Kind.LURCHED, SinkTimeline.Kind.PLUNGING, SinkTimeline.Kind.GONE
]


func _initialize() -> void:
	var args := MatchArgs.parse(OS.get_cmdline_user_args())
	var config := RunMatch.default_config(
		args.seed_value if args.seed_value >= 0 else RunMatch.DEFAULT_SEED
	)
	config.scenario = args.struck(config.scenario)
	var problems := config.problems()
	problems.append_array(args.problems())
	if config.ship.structure == null or not config.scenario.is_physical():
		problems.append("bake: the match's ship and scenario have no physics to bake")
	if not problems.is_empty():
		printerr("\n".join(problems))
		quit(1)
		return
	var started := Time.get_ticks_usec()
	var choice := config.sinking()
	var took := (Time.get_ticks_usec() - started) / 1e6
	var lines := _hit_lines(config, choice)
	lines.append_array(_event_lines(choice.timeline))
	lines.append_array(_cost_lines(config, choice, took))
	printraw("\n".join(lines) + "\n")
	quit()


static func _hit_lines(config: MatchConfig, choice: MustSink.Choice) -> PackedStringArray:
	var schedule := config.schedule()
	var hit := choice.hit
	var damage := choice.damage
	var structure := config.ship.structure
	var ship := config.ship.resource_path.get_file().get_basename()
	var lines := PackedStringArray()
	lines.append(
		(
			"%s · open sea (%.0f m) · hit at %s of the match"
			% [ship, config.scenario.sea_depth, MatchTranscript.clock(schedule.hit_tick())]
		)
	)
	(
		lines
		. append(
			(
				"hit %s · x %.1f…%.1f m · %.1f…%.1f m under · %.3f m² · bite %.1f m"
				% [
					hit.side_name(),
					damage.from_x,
					damage.to_x,
					hit.depth_start,
					hit.depth_end,
					damage.area(),
					hit.bite,
				]
			)
		)
	)
	var opens := PackedStringArray()
	for opening: ShipOpening in damage.openings:
		opens.append("%s %.3f m²" % [opening.joins[0], opening.area])
	lines.append("opens " + (", ".join(opens) if not opens.is_empty() else "nothing"))
	var shut := PackedStringArray()
	var last := 0.0
	for opening: ShipOpening in structure.openings:
		if opening.shuts_at_hit and not opening.name in damage.jammed:
			shut.append(opening.name)
			last = maxf(last, opening.shut_time)
	var jammed := ", ".join(damage.jammed) if not damage.jammed.is_empty() else "none"
	lines.append(
		(
			"doors %s shut by %s · jammed: %s"
			% [", ".join(shut), MatchTranscript.physics_clock(last), jammed]
		)
	)
	var open := ", ".join(damage.left_open) if not damage.left_open.is_empty() else "none"
	lines.append("left open: %s" % open)
	var came := "no fallback"
	if choice.sure:
		came = "her sure hit"
	elif choice.rung > 0:
		came = "fallback rung %d" % choice.rung
	elif choice.draws == 0:
		came = "given, past the rule"
	lines.append(
		(
			"must %d drawn · %d thrown at the quick check · %d bakes · %s"
			% [choice.draws, choice.thrown, choice.bakes, came]
		)
	)
	return lines


static func _event_lines(timeline: SinkTimeline) -> PackedStringArray:
	var lines := PackedStringArray(["0:00:00 holed"])
	for event: SinkTimeline.Event in timeline.events:
		var line := "%s %s" % [MatchTranscript.physics_clock(event.seconds), _told(event)]
		if event.kind in LEANING:
			var leans := OutcomeClassifier.leans_at(timeline, timeline.frame_at(event.seconds))
			line += " · trim %+.0f° · list %+.0f°" % [leans[0], leans[1]]
		lines.append(line)
	var ends := {
		SinkTimeline.End.GONE: "gone, followed down past where anything of her is seen",
		SinkTimeline.End.AFLOAT: "afloat, the water stopped",
		SinkTimeline.End.CAPPED: "afloat at the cap",
	}
	lines.append(
		(
			"bake ends at %s: %s"
			% [MatchTranscript.physics_clock(timeline.length()), ends[timeline.end]]
		)
	)
	lines.append("outcome " + OutcomeClassifier.told(OutcomeClassifier.labels(timeline)))
	return lines


static func _told(event: SinkTimeline.Event) -> String:
	match event.kind:
		SinkTimeline.Kind.FLOODING:
			return "%s flooding" % event.name
		SinkTimeline.Kind.FULL:
			return "%s full" % event.name
		SinkTimeline.Kind.SPILLING:
			return "water through %s" % event.name
		SinkTimeline.Kind.PLUNGING:
			return "the plunge: her main deck under"
		SinkTimeline.Kind.LURCHING:
			return "stability lost · lurch coming · %+.0f°" % event.heel_deg
		SinkTimeline.Kind.LURCHED:
			return "lurched %+.0f° over %.1f s" % [event.heel_deg, event.lasts]
		SinkTimeline.Kind.BOATS_USELESS:
			return "%s boats useless" % event.name
	return "she is gone"


## What the bake cost here, and what the timeline weighs: compacted, as it travels, and
## with every state kept — baked again for the count, no part of the match.
static func _cost_lines(
	config: MatchConfig, choice: MustSink.Choice, took: float
) -> PackedStringArray:
	var timeline := choice.timeline
	var sea := SeaPhysics.load_default()
	var stepper := SinkStepper.new(config.ship.structure, choice.damage, sea)
	var every := SinkBake.new(stepper, sea, config.scenario.bake_cap).uncompacted()
	return PackedStringArray(
		[
			(
				"bake %.2f s · %d steps · %d of %d states kept · %.1f kB (every state %.1f kB)"
				% [
					took,
					timeline.steps,
					timeline.count(),
					timeline.states,
					timeline.size() / 1000.0,
					every.size() / 1000.0,
				]
			),
			"digest %s" % timeline.digest().substr(0, 16),
		]
	)
