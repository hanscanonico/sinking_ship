extends SceneTree
## `make flood-invariants [SHIP=] [SCENARIO=open_sea|coast|all] [SEEDS=5] [HIT=sure|night|N]
## [STEPS=1]`: the flooding's invariants (FloodWatch, #619) checked at every step of a
## ship's bakes — her scenario's sure hit and seeds 1…SEEDS' hits, chosen by the
## must-sink rule as a match on that seed chooses them (MustSink) — one line per
## invariant per bake; then, for a bake that ends afloat, whether each cell open to the
## sea stands at it (keep_level); and with STEPS=1 whether the step decides the outcome:
## the sure hit and seed 1's baked at step_max and at a quarter of it — when she is gone,
## her trim half way, and the order her cells first take water. The Titanic's night
## (tests/fixtures/sinking/hits/titanic_night.tres) is HIT=night. Headless; no match is
## played. Every ship of the fleet by default; the Titanic's bakes take minutes each.
##
##   godot --headless --path . -s res://tools/flood_invariants.gd -- --ship=steamer

const NIGHT := "res://tests/fixtures/sinking/hits/titanic_night.tres"
const DEFAULT_SEEDS := 5
## How many cells of each first-water order the step check prints.
const ORDER_SHOWN := 6
## The share of her life two bakes' first water in a cell may stand apart by, under which
## the step check counts them the same flooding.
const APART_SHARE := 0.05


func _initialize() -> void:
	var ships := Fleet.names()
	var settings := PackedStringArray(["open_sea"])
	var seeds := DEFAULT_SEEDS
	var only := ""
	var steps := false
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--ship":
				if not value.is_empty():
					ships = PackedStringArray([value])
			"--scenario":
				if value == "all":
					settings = PackedStringArray(["open_sea", "coast"])
				elif not value.is_empty():
					settings = PackedStringArray([value])
			"--seeds":
				seeds = value.to_int()
			"--hit":
				only = value
			"--steps":
				steps = value == "1"
	var sea := SeaPhysics.load_default()
	for ship: String in ships:
		var layout := Fleet.layout(ship)
		if layout == null or layout.structure == null:
			printerr("flood-invariants: no ship called %s" % ship)
			quit(1)
			return
		for setting: String in settings:
			var scenario := Fleet.setting(StringName("%s_%s" % [ship, setting]))
			if scenario == null or scenario.hit == null:
				continue
			for hit: String in _hits(ship, seeds, only):
				_check(ship, setting, hit, layout.structure, scenario, sea)
			if steps and only.is_empty():
				for hit: String in ["sure", "1"]:
					_steps(ship, setting, hit, layout.structure, scenario, sea)
	quit()


## The hits to bake for [param ship]: the sure hit, seeds 1…[param seeds], and her night
## for the Titanic — or [param only].
static func _hits(ship: String, seeds: int, only: String) -> PackedStringArray:
	if not only.is_empty():
		return PackedStringArray([only])
	var found := PackedStringArray(["sure"])
	if ship == "titanic":
		found.append("night")
	for seed_value in range(1, seeds + 1):
		found.append(str(seed_value))
	return found


## The damage [param hit] does to [param structure] under [param scenario]: the sure hit
## or the night as given, or the hit a match on that seed plays.
static func _damage(
	hit: String, structure: ShipStructure, scenario: SinkScenario, sea: SeaPhysics
) -> HitDamage:
	var damage: HitDamage
	if hit == "sure":
		damage = HitMapper.map_explicit(structure.sure_hit, structure, scenario.hit)
	elif hit == "night":
		damage = HitMapper.map_explicit(load(NIGHT), structure, scenario.hit)
	else:
		var stream := SeedStreams.derive(hit.to_int(), "sink")
		damage = MustSink.choose(structure, scenario, stream, sea).damage
	damage.sea_depth = scenario.sea_depth
	return damage


func _check(
	ship: String,
	setting: String,
	hit: String,
	structure: ShipStructure,
	scenario: SinkScenario,
	sea: SeaPhysics
) -> void:
	var started := Time.get_ticks_msec()
	var damage := _damage(hit, structure, scenario, sea)
	# Baked to the scenario's cap, every step watched.
	var stepper := WatchedStepper.new(structure, damage, sea)
	var bake := SinkBake.new(stepper, sea, scenario.bake_cap, HullBreak.of(structure, damage, sea))
	bake.run(1 << 62)
	var watch := stepper.watch
	var prefix := "%s %s %s:" % [ship, setting, hit]
	var end: String = SinkTimeline.End.keys()[bake.end()]
	print(
		(
			"%s %s at %.0f s, %d steps, %.1f s to bake"
			% [
				prefix,
				end.to_lower(),
				bake.seconds(),
				bake.steps(),
				(Time.get_ticks_msec() - started) / 1000.0
			]
		)
	)
	for line: String in watch.report(prefix):
		print(line)
	for law in FloodWatch.NAMES.size():
		for words: String in watch.breaches(law as FloodWatch.Law):
			print("%s   %s %s" % [prefix, FloodWatch.NAMES[law], words])
	if bake.end() == SinkTimeline.End.AFLOAT:
		for line: String in watch.at_rest(sea.keep_level):
			print("%s %s" % [prefix, line])


## Whether the step decides [param hit]'s outcome: baked at step_max and a quarter of it.
func _steps(
	ship: String,
	setting: String,
	hit: String,
	structure: ShipStructure,
	scenario: SinkScenario,
	sea: SeaPhysics
) -> void:
	var damage := _damage(hit, structure, scenario, sea)
	var fine: SeaPhysics = sea.duplicate()
	fine.step_max = sea.step_max / 4.0
	var coarse := SinkBake.of(structure, damage, sea, scenario.bake_cap).timeline()
	var short := SinkBake.of(structure, damage, fine, scenario.bake_cap).timeline()
	var prefix := "%s %s %s: step" % [ship, setting, hit]
	var halfway := (coarse.gone_at if coarse.gone_at >= 0.0 else coarse.length()) * 0.5
	print(
		(
			(
				"%s gone at %.0f s / %.0f s (step_max %.1f / %.2f); at %.0f s trim %.2f° / %.2f°,"
				+ " list %.2f° / %.2f°"
			)
			% [
				prefix,
				coarse.gone_at,
				short.gone_at,
				sea.step_max,
				fine.step_max,
				halfway,
				_trim(coarse, halfway),
				_trim(short, halfway),
				_list(coarse, halfway),
				_list(short, halfway),
			]
		)
	)
	var first := _wetted(coarse)
	var second := _wetted(short)
	var moved := 0
	for at in first.size():
		if at >= second.size() or second[at] != first[at]:
			moved += 1
	print(
		(
			"%s first water: %d / %d cells, %d placed apart; %s / %s"
			% [
				prefix,
				first.size(),
				second.size(),
				moved,
				", ".join(first.slice(0, ORDER_SHOWN)),
				", ".join(second.slice(0, ORDER_SHOWN)),
			]
		)
	)
	# One cell's place moved shifts every place after it, and cells first wet seconds
	# apart trade places at any step: the seconds each cell first takes water at, apart
	# by more than a share of her life, tell a different flooding from a reordered one.
	var life := coarse.gone_at if coarse.gone_at >= 0.0 else coarse.length()
	var at_first := _wetted_at(coarse)
	var at_second := _wetted_at(short)
	var apart := PackedStringArray()
	var most := ""
	var most_by := 0.0
	for named: String in at_first:
		var by := absf(float(at_first[named]) - float(at_second.get(named, life)))
		if by > APART_SHARE * life:
			apart.append(named)
		if by > most_by:
			most_by = by
			most = named
	for named: String in at_second:
		if not at_first.has(named) and absf(float(at_second[named]) - life) > APART_SHARE * life:
			apart.append(named)
	print(
		(
			"%s first water: %d cells first wet over %.0f%% of her life apart%s; most %s by %.0f s"
			% [
				prefix,
				apart.size(),
				APART_SHARE * 100.0,
				" (%s)" % ", ".join(apart.slice(0, ORDER_SHOWN)) if not apart.is_empty() else "",
				most if not most.is_empty() else "none",
				most_by,
			]
		)
	)


## Her trim at [param seconds] of [param timeline], degrees, bow down: of her first piece.
static func _trim(timeline: SinkTimeline, seconds: float) -> float:
	var up := Attitude.up(timeline.rotation_of(timeline.frame_at(seconds)))
	return rad_to_deg(asin(clampf(up[0], -1.0, 1.0)))


## Her list at [param seconds] of [param timeline], degrees, as Attitude.up's athwartships
## part leans: one that lolls goes either way, and a list of the other sign says so.
static func _list(timeline: SinkTimeline, seconds: float) -> float:
	var up := Attitude.up(timeline.rotation_of(timeline.frame_at(seconds)))
	return rad_to_deg(asin(clampf(up[2], -1.0, 1.0)))


## Her cells in the order they first took water (SinkTimeline.Kind.FLOODING).
static func _wetted(timeline: SinkTimeline) -> PackedStringArray:
	var found := PackedStringArray()
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == SinkTimeline.Kind.FLOODING and not found.has(String(event.name)):
			found.append(String(event.name))
	return found


## Her cells by the second they first took water (SinkTimeline.Kind.FLOODING).
static func _wetted_at(timeline: SinkTimeline) -> Dictionary:
	var found := {}
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == SinkTimeline.Kind.FLOODING and not found.has(String(event.name)):
			found[String(event.name)] = event.seconds
	return found
