extends GutTest
## Every match's hit sinks her (§5b.1, your answer to Q18): the must-sink rule draws,
## quick-checks, bakes, draws again within its bounds and falls back on heavier hits and
## her sure hit — bakes alone, no match played (§5b.4). Explicit hits bypass it.

## The match hits the gate bakes; `make census` bakes 200, in every PR that changes the
## physics or a ship's data (§5b.4).
const SEEDS := 40
## The raw census's seeds the quick check is held to: each hit it throws out is baked
## to show she floats on it.
const RAW_SEEDS := 60
## A seed whose first draw the quick check throws out: with one throw allowed and no
## rung, the rule falls straight to the sure hit.
const SURE_SEED := 6
## Explicit hits the bake sinks her on: her sure hit (empty) and the fixtures'.
const SINKING_HITS: Array[String] = [
	"",
	"res://tests/fixtures/sinking/hits/fast.tres",
	"res://tests/fixtures/sinking/hits/show.tres",
	"res://tests/fixtures/sinking/hits/late.tres",
]

var _structure: ShipStructure
var _scenario: SinkScenario
var _sea: SeaPhysics
var _hull: LevelHull


func before_all() -> void:
	_structure = SimFixtures.steamer().structure
	_scenario = load(SimFixtures.STEAMER_SINKING)
	_sea = SeaPhysics.load_default()
	_hull = LevelHull.new(_structure.sections)


func _founders(damage: HitDamage) -> bool:
	var failing := _scenario.quick_failing
	return MustSink.founders(_structure, damage, _hull, _sea, _scenario.spare_deck, failing)


## A light hit: a short slit into the hold's starboard side void alone.
func _light() -> IcebergHit:
	return SimFixtures.explicit_hit(1, 6.0, 9.0, 0.5, 0.01, 0.4)


func test_every_match_hit_founders_within_the_cap() -> void:
	var afloat := PackedStringArray()
	for index in SEEDS:
		var choice: MustSink.Choice = SimFixtures.match_hits(SEEDS)[index]
		var timeline := choice.timeline
		if not timeline.is_gone() or timeline.gone_at > _scenario.bake_cap:
			afloat.append("seed %d: %s" % [index + 1, SinkTimeline.End.keys()[timeline.end]])
	assert_eq(afloat, PackedStringArray(), "every match hit of %d sinks her" % SEEDS)


func test_quick_check_throws_out_a_hit_she_floats_on() -> void:
	var damage := HitMapper.map_explicit(_light(), _structure, _scenario.hit)
	assert_false(damage.openings.is_empty(), "the light hit holes her")
	assert_false(_founders(damage), "thrown out at once")
	assert_eq(SimFixtures.bake(_light()).end, SinkTimeline.End.AFLOAT, "and she floats on it")


func test_quick_check_never_throws_out_a_hit_the_bake_sinks() -> void:
	var thrown := 0
	var sunk := PackedStringArray()
	for seed_value in range(1, RAW_SEEDS + 1):
		var stream := SeedStreams.derive(seed_value, "sink")
		var hit := IcebergHit.draw(_scenario.hit, stream)
		var damage := HitMapper.map(hit, _structure, _scenario.hit, stream)
		if _founders(damage):
			continue
		thrown += 1
		var stepper := SinkStepper.new(_structure, damage, _sea)
		if SinkTimeline.bake(stepper, _sea, _scenario.bake_cap).is_gone():
			sunk.append("seed %d" % seed_value)
	assert_gt(thrown, 0, "the quick check throws hits out")
	assert_eq(sunk, PackedStringArray(), "and never one the bake sinks")
	# A level ship sinks on almost no raw draw, so the census alone would pass a quick
	# check that threw out every hit: hits the bake is known to sink must pass it too.
	for path: String in SINKING_HITS:
		var hit: IcebergHit = load(path) if not path.is_empty() else _structure.sure_hit
		assert_true(SimFixtures.bake(hit).is_gone(), "%s: the bake sinks her" % path)
		var damage := HitMapper.map_explicit(hit, _structure, _scenario.hit)
		assert_true(_founders(damage), "%s: and the quick check keeps it" % path)


func test_redraws_stay_within_their_bound() -> void:
	var most := _scenario.bakes + 2
	var strays := PackedStringArray()
	for index in SEEDS:
		var choice: MustSink.Choice = SimFixtures.match_hits(SEEDS)[index]
		if choice.thrown > _scenario.quick_redraws or choice.bakes > most:
			strays.append("seed %d: %d thrown, %d bakes" % [index + 1, choice.thrown, choice.bakes])
		if choice.rung > _scenario.rungs:
			strays.append("seed %d: rung %d" % [index + 1, choice.rung])
	assert_eq(strays, PackedStringArray(), "at most 8 thrown out and five bakes in all")


func test_fallback_makes_the_last_hit_heavier_until_she_founders() -> void:
	var found := 0
	for index in SEEDS:
		var choice: MustSink.Choice = SimFixtures.match_hits(SEEDS)[index]
		if choice.rung == 0:
			continue
		found += 1
		# Its last draw, as drawn, then heavier rung by rung: twice the width each, its
		# reach one cell further, and only the rung it took passes the quick check.
		var stream := SeedStreams.derive(index + 1, "sink")
		var drawn: IcebergHit = null
		for _draw in choice.draws:
			drawn = IcebergHit.draw(_scenario.hit, stream)
			HitMapper.map(drawn, _structure, _scenario.hit, stream)
		var heavier := drawn
		for rung in range(1, choice.rung + 1):
			var next := MustSink.heavier(heavier, _structure, rung)
			assert_almost_eq(next.width, heavier.width * 2.0, 1e-12, "twice as wide")
			assert_gt(next.length, heavier.length, "and longer")
			heavier = next
			heavier.jammed = choice.damage.jammed
			heavier.left_open = choice.damage.left_open
			var damage := HitMapper.map_explicit(heavier, _structure, _scenario.hit)
			assert_eq(_founders(damage), rung == choice.rung, "seed %d rung %d" % [index + 1, rung])
		assert_almost_eq(choice.hit.width, heavier.width, 1e-12, "the rung it took is baked")
		if found >= 3:
			break
	assert_gt(found, 0, "some match leans on the fallback")


func test_sure_hit_sinks_her() -> void:
	var sure := _structure.sure_hit
	assert_true(sure.jammed.is_empty() and sure.left_open.is_empty(), "every door and port shut")
	var timeline := SimFixtures.bake(sure)
	assert_true(timeline.is_gone(), "she founders on her sure hit")
	assert_lte(timeline.gone_at, _scenario.bake_cap, "within the cap")


func test_explicit_hits_bypass_the_rule() -> void:
	var given: SinkScenario = _scenario.duplicate()
	given.explicit_hit = _light()
	var layout := SimFixtures.steamer()
	var schedule := SinkSchedule.new(
		given, layout.freeboard, SeedStreams.derive(1, "sink"), _structure
	)
	assert_same(schedule.hit(), given.explicit_hit, "struck as given")
	assert_eq(schedule.choice().thrown, 0, "nothing drawn")
	assert_eq(schedule.choice().bakes, 1, "baked once")
	assert_eq(schedule.timeline().end, SinkTimeline.End.AFLOAT, "and she stays afloat")
	assert_eq(schedule.gone_tick(), -1, "never gone")


func test_the_choice_is_pure_in_ship_scenario_and_seed() -> void:
	for seed_value: int in [3, 1701]:
		var told := PackedStringArray()
		for _round in 2:
			# Whatever else drew first, the sinking stream is its own.
			var other := SeedStreams.derive(seed_value, "match")
			other.randf()
			var stream := SeedStreams.derive(seed_value, "sink")
			var choice := MustSink.choose(_structure, _scenario, stream, _sea)
			told.append(
				(
					"%s %s %s %s %d %d %d"
					% [
						choice.hit.start_x,
						choice.hit.length,
						choice.hit.width,
						choice.timeline.digest(),
						choice.thrown,
						choice.bakes,
						choice.rung
					]
				)
			)
		assert_eq(told[0], told[1], "seed %d chooses alike twice" % seed_value)


## [param choice]'s hit and damage as a client compares them: where, how wide, how
## hard, and which doors jam and which ports stand open.
func _struck(choice: MustSink.Choice) -> Array:
	var hit := choice.hit
	return [
		hit.moment,
		hit.side,
		hit.start_x,
		hit.length,
		hit.width,
		choice.damage.area(),
		choice.damage.jammed,
		choice.damage.left_open,
		choice.rung,
		choice.sure,
	]


func test_a_client_draws_the_hosts_hit_again_from_its_origin() -> void:
	# The match hits as drawn, a fallback's rung among them, then a rule left no draw
	# but the sure hit: each drawn again from its timeline's origin alone, never baked.
	var chosen: Array[MustSink.Choice] = SimFixtures.match_hits(SEEDS)
	var seeds := range(1, SEEDS + 1)
	var bare: SinkScenario = _scenario.duplicate()
	bare.quick_redraws = 1
	bare.rungs = 0
	var sure := MustSink.choose(_structure, bare, SeedStreams.derive(SURE_SEED, "sink"), _sea)
	assert_true(sure.sure, "seed %d: the sure hit, with no rung to take" % SURE_SEED)
	var scenarios: Array[SinkScenario] = []
	for _seed in SEEDS:
		scenarios.append(_scenario)
	chosen.append(sure)
	seeds.append(SURE_SEED)
	scenarios.append(bare)
	var rungs := 0
	for index in chosen.size():
		var host := chosen[index]
		var stream := SeedStreams.derive(seeds[index], "sink")
		var client := MustSink.replay(_structure, scenarios[index], stream, host.timeline)
		assert_not_null(client, "seed %d: drawn again" % seeds[index])
		if client == null:
			continue
		assert_true(client.received, "received, not baked")
		assert_same(client.timeline, host.timeline, "playing the host's timeline")
		assert_eq(_struck(client), _struck(host), "seed %d: the host's hit" % seeds[index])
		if host.rung > 0:
			rungs += 1
	assert_gt(rungs, 0, "a fallback's rung among them")
	# A timeline whose origin names a hit this end does not draw is refused.
	var forged := SinkTimeline.from_bytes(chosen[0].timeline.to_bytes())
	forged.origin[MustSink.Origin.DRAWS] += 1
	var stream := SeedStreams.derive(seeds[0], "sink")
	assert_null(MustSink.replay(_structure, _scenario, stream, forged), "another hit: refused")
