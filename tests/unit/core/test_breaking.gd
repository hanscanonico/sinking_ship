extends GutTest
## Breaking (§5b.1, §5b.3; SH33): a weak spot whose bending reaches its strength hinges
## and the hull parts there into pieces (HullBreak), each its own stepper over its own cut
## of her structure (PieceStructure), and a body belongs to the piece under it (Pieces).
## The barge is a box 40 m long whose bow compartment floods through a hole and holds her
## by the head: her hull hogs, most a third of her length from the bow — her weak spots
## stand along her where the test needs them.

const LENGTH := 40.0
const WEAK_HULL := "res://tests/fixtures/ships/steamer_weak.tres"
## A share of her strength this close to a threshold is on it (HullBreak.REACHED).
const REACHED := 1e-3

## The weak hull's match the tests that play one share (_weak_match).
static var _weak: MatchConfig


## The barge: three cells end to end — aft, middle, the bow's that floods through a 1 m²
## hole — and [param spots] weak spots of hers, each [name, x, share], against a strength
## of [param strength] N·m hogging and sagging.
func _barge(spots: Array, strength: float) -> ShipStructure:
	var barge := BoxBarge.new(LENGTH, 10.0, 8.0, 4.0, 3.0)
	barge.section_length = 2.0
	barge.cell(&"aft", Vector3(-20.0, -4.0, -5.0), Vector3(-4.0, 4.0, 5.0))
	barge.cell(&"middle", Vector3(-4.0, -4.0, -5.0), Vector3(12.0, 4.0, 5.0))
	barge.cell(&"bow", Vector3(12.0, -4.0, -5.0), Vector3(20.0, 4.0, 5.0))
	barge.hole(&"bow", Vector3(16.0, -3.0, 5.0), 1.0)
	var structure := barge.structure()
	structure.strength = GirderStrength.new()
	structure.strength.hog = strength
	structure.strength.sag = strength
	var weak: Array[WeakSpot] = []
	for spot: Array in spots:
		var made := WeakSpot.new()
		made.name = spot[0]
		made.x = spot[1]
		made.share = spot[2]
		weak.append(made)
	structure.strength.weak = weak
	return structure


## The barge's bake, to [param cap] seconds, its hull breaking as [param sea] says.
func _baked(structure: ShipStructure, sea: SeaPhysics, cap := 600.0) -> SinkBake:
	var bake := SinkBake.of(structure, HitDamage.new(), sea, cap)
	bake.run(1 << 62)
	return bake


## The sea's physics, its breaking stage on or off.
func _sea(breaking: bool) -> SeaPhysics:
	var sea := SeaPhysics.load_default().duplicate() as SeaPhysics
	sea.breaking = breaking
	return sea


## Per kept state of the barge's bake with breaking off, her bending moment at each x of
## [param xs] — as a share of [param strength], none of it kept back — and the state's
## second: [seconds, share at xs[0], share at xs[1], …].
func _moments(structure: ShipStructure, xs: Array) -> Array[PackedFloat64Array]:
	var sea := _sea(false)
	var stepper := SinkStepper.new(structure, HitDamage.new(), sea)
	var bake := SinkBake.new(stepper, sea, 600.0)
	var girder := stepper.failures().girder()
	var found: Array[PackedFloat64Array] = []
	while not bake.run(1):
		var row := PackedFloat64Array([bake.seconds()])
		for x: float in xs:
			row.append(girder.share_at(x, 1.0))
		found.append(row)
	return found


## The most her bending comes to at [param x] over the bake with breaking off, as a share
## of [param strength].
func _peak(structure: ShipStructure, x: float) -> float:
	var most := 0.0
	for row: PackedFloat64Array in _moments(structure, [x]):
		most = maxf(most, absf(row[1]))
	return most


func _events_of(timeline: SinkTimeline, kind: SinkTimeline.Kind) -> Array[SinkTimeline.Event]:
	var found: Array[SinkTimeline.Event] = []
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == kind:
			found.append(event)
	return found


func test_ratio_under_one_never_breaks() -> void:
	# Her weak spot where she bends most, her strength set so the most her bending comes
	# to there is 0.9 of it: no hinge, no break, one piece to the end.
	var probe := _barge([[&"joint", 6.0, 1.0]], 1e9)
	var strength := 1e9 * _peak(probe, 6.0) / 0.9
	var weak := _barge([[&"joint", 6.0, 1.0]], strength)
	assert_almost_eq(_peak(weak, 6.0), 0.9, 1e-6, "she bends to 0.9 of its strength there")
	var timeline := _baked(weak, _sea(true)).timeline()
	assert_lt(absf(timeline.bending), 1.0, "and under her strength everywhere")
	assert_eq(_events_of(timeline, SinkTimeline.Kind.HINGING).size(), 0, "no hinge starts")
	assert_eq(_events_of(timeline, SinkTimeline.Kind.PARTED).size(), 0, "she never parts")
	assert_eq(timeline.leaves.size(), 1, "she is one piece to the end")
	assert_false(OutcomeClassifier.labels(timeline).has(OutcomeClassifier.Outcome.BROKE_IN_TWO))


func test_the_first_station_past_one_is_where_she_breaks() -> void:
	# Two weak spots: amidships, keeping less of her strength, and a third of her length
	# from her bow, where she bends most. Read with breaking off, the one whose bending
	# reaches its strength first is where the hinge starts, then, and where she parts.
	var spots := [[&"amidships", 0.0, 0.55], [&"forward", 6.0, 1.0]]
	var probe := _barge(spots, 1e9)
	var peak := _peak(probe, 6.0)
	var strength := 1e9 * peak / 1.6
	var rows := _moments(probe, [0.0, 6.0])
	var first := ""
	var first_at := INF
	for row: PackedFloat64Array in rows:
		for spot in 2:
			var share: float = absf(row[1 + spot]) * 1e9 / strength / spots[spot][2]
			if share >= 1.0 - REACHED and row[0] < first_at:
				first_at = row[0]
				first = spots[spot][0]
	assert_ne(first, "", "one of them is overloaded")
	var timeline := _baked(_barge(spots, strength), _sea(true)).timeline()
	var hinges := _events_of(timeline, SinkTimeline.Kind.HINGING)
	var parts := _events_of(timeline, SinkTimeline.Kind.PARTED)
	assert_gt(hinges.size(), 0, "a hinge starts")
	assert_eq(String(hinges[0].name), first, "at the spot overloaded first")
	assert_almost_eq(hinges[0].seconds, first_at, SeaPhysics.load_default().step_max, "when it is")
	assert_eq(String(parts[0].name), first, "and she parts there")
	var x: float = spots[0][1] if first == "amidships" else spots[1][1]
	assert_almost_eq(timeline.span_of(1).y, x, 1e-6, "her aft piece runs to it")
	assert_almost_eq(timeline.span_of(2).x, x, 1e-6, "her fore piece from it")
	assert_almost_eq(
		parts[0].seconds - hinges[0].seconds,
		SeaPhysics.load_default().hinge_seconds,
		2.0,
		"the hinge runs its time"
	)


func test_each_piece_keeps_its_cells_and_mass() -> void:
	# Cut at a weak spot, each piece has the part of every cell and of her mass on its side
	# of the cut — together hers — its own stepper over them, and its own pose.
	var structure: ShipStructure = load(WEAK_HULL).structure
	var ends := PieceStructure.span_of(structure)
	var cut := 2.0
	var aft := PieceStructure.cut(structure, ends.x, cut)
	var fore := PieceStructure.cut(structure, cut, ends.y)
	assert_almost_eq(
		aft.total_mass() + fore.total_mass(), structure.total_mass(), 1e-6, "her mass, all of it"
	)
	for cell: FloodCell in structure.cells:
		var parts := 0.0
		for piece: ShipStructure in [aft, fore]:
			var named := piece.cell_named(cell.name)
			if named != -1:
				parts += piece.cells[named].volume()
		assert_almost_eq(parts, cell.volume(), 1e-9, "every part of %s" % cell.name)
	for piece: ShipStructure in [aft, fore]:
		var span := PieceStructure.span_of(piece)
		for cell: FloodCell in piece.cells:
			assert_true(cell.low.x >= span.x - 1e-9 and cell.high.x <= span.y + 1e-9)
		var centre := piece.mass_centre()
		assert_true(centre[0] > span.x and centre[0] < span.y, "its mass on its own stretch")
		assert_eq(piece.problems(), PackedStringArray(), "a structure the physics reads")
	var torn := 0
	for opening: ShipOpening in aft.openings:
		if opening.kind == ShipOpening.Kind.TORN:
			torn += 1
			assert_almost_eq(opening.centre.x, cut, 1e-9, "on the cut")
	assert_gt(torn, 0, "the cut face is open to the sea")
	# The barge broken: each piece's cells are its cut's, and its pose its own.
	var spots := [[&"joint", 6.0, 1.0]]
	var barge := _barge(spots, 1e9 * _peak(_barge(spots, 1e9), 6.0) / 1.5)
	var timeline := _baked(barge, _sea(true)).timeline()
	assert_eq(timeline.leaves.size(), 2, "she broke in two")
	for leaf in timeline.leaves.size():
		var span := timeline.span_of(timeline.leaves[leaf])
		var piece := PieceStructure.cut(barge, span.x, span.y)
		assert_eq(timeline.leaf_cells[leaf], piece.cells.size(), "the leaf's cells its cut's")
	var last := timeline.count() - 1
	assert_ne(timeline.rotation_of(last, 0), timeline.rotation_of(last, 1), "a pose each")


func test_a_cut_cell_splits_its_water_by_volume() -> void:
	# One cell from -10 to 10 holding water, a weak spot at -2: cut there level, its aft
	# part keeps 40% of the water, its fore part 60% — all of it — and trimmed by the head
	# the aft part keeps what lies aft of the cut at the level.
	var barge := BoxBarge.new(LENGTH, 10.0, 8.0, 4.0, 3.0)
	barge.section_length = 2.0
	barge.cell(&"hold", Vector3(-10.0, -4.0, -5.0), Vector3(10.0, 2.0, 5.0))
	var structure := barge.structure()
	structure.strength = GirderStrength.new()
	structure.strength.hog = 1e9
	structure.strength.sag = 1e9
	var spot := WeakSpot.new()
	spot.name = &"joint"
	spot.x = -2.0
	var weak: Array[WeakSpot] = [spot]
	structure.strength.weak = weak
	var sea := SeaPhysics.load_default()
	for pitched_deg: float in [0.0, -4.0]:
		var stepper := SinkStepper.new(structure, HitDamage.new(), sea)
		var state := stepper.start()
		state.rotation = Attitude.pitched(state.rotation, deg_to_rad(pitched_deg))
		stepper.pressures(state)
		var water := 300.0
		state.water[0] = water
		state.heads[0] = stepper.head(0, water)
		var piece := BakePiece.new(stepper, sea, state, 0)
		piece.hinge = 0
		var breaking := HullBreak.of(structure, HitDamage.new(), sea)
		var parts := breaking.split(piece, PieceStructure.span_of(structure), 1)
		var aft := parts[0].state.water[0]
		var fore := parts[1].state.water[0]
		assert_almost_eq(aft + fore, water, 1e-9, "none made or lost, at %s°" % pitched_deg)
		if pitched_deg == 0.0:
			assert_almost_eq(aft / water, 0.4, 1e-9, "level, by the halves' volumes")
		else:
			assert_lt(aft / water, 0.4, "by the head, less aft of the cut")
		assert_almost_eq(parts[0].state.heads[0], state.heads[0], 1e-6, "at its own level")


func test_three_pieces_at_most() -> void:
	# Four weak spots keeping almost nothing, and hinges quick enough to part before the
	# barge's pieces go under: she breaks — but into three pieces at most, none shorter
	# than shortest_piece of her length.
	var spots := [[&"a", -12.0, 1e-4], [&"b", -4.0, 1e-4], [&"c", 3.0, 1e-4], [&"d", 10.0, 1e-4]]
	var sea := _sea(true)
	sea.hinge_seconds = 2.0
	var timeline := _baked(_barge(spots, 1e9), sea, 1200.0).timeline()
	assert_eq(timeline.leaves.size(), sea.most_pieces, "three pieces, no more")
	assert_eq(_events_of(timeline, SinkTimeline.Kind.PARTED).size(), sea.most_pieces - 1)
	for piece: int in timeline.leaves:
		var span := timeline.span_of(piece)
		var stretch := minf(span.y, LENGTH * 0.5) - maxf(span.x, -LENGTH * 0.5)
		assert_gte(stretch, sea.shortest_piece * LENGTH, "none shorter than its share")
	assert_true(OutcomeClassifier.labels(timeline).has(OutcomeClassifier.Outcome.BROKE_IN_THREE))


func test_body_belongs_to_the_piece_under_it() -> void:
	# The weak hull's match, jumped to just before she parts: once she has, every body is on
	# the piece under it, its points in that piece's space; one in the air past its piece's
	# torn end, over the other's stretch, is carried there through the world.
	var config := _weak_match()
	var timeline := config.schedule().timeline()
	var parted := _events_of(timeline, SinkTimeline.Kind.PARTED)[0]
	var tick := config.schedule().physics_tick(parted.seconds)
	var sim := MatchSim.from_snapshot(MatchJump.snapshot(config, tick - Ticks.RATE), config)
	var idle: Array[InputFrame] = []
	for seat in config.seats:
		idle.append(InputFrame.new(seat, 0))
	# Through the first tick she stands in two pieces.
	while sim.pose().standing.size() < 2:
		sim.step(idle)
	sim.step(idle)
	var pose := sim.pose()
	assert_eq(pose.standing.size(), 2, "she is in two pieces")
	for player: PlayerState in sim.state.seats:
		assert_true(player.piece in pose.standing, "seat %d on a piece she is in" % player.seat)
		if player.body == PlayerState.Body.GROUNDED:
			var over := sim.pieces.piece_at(pose.standing, player.pos.x)
			assert_eq(player.piece, over, "seat %d on the piece under it" % player.seat)
	# Seat 0 in the air just past the aft piece's torn end, over the fore piece's stretch.
	var aft := pose.standing[0]
	var fore := pose.standing[1]
	var player := sim.state.seats[0]
	player.piece = aft
	player.body = PlayerState.Body.AIRBORNE
	player.surface = Surfaces.NONE
	player.pos = Vector3(timeline.span_of(aft).y + 1.5, 3.0, 0.0)
	player.vel = Vector3.ZERO
	player.fall_from = player.pos.y
	var world := pose.of_piece(aft).transform * player.pos
	sim.step(idle)
	assert_eq(player.piece, fore, "carried onto the fore piece")
	var now := sim.pose().of_piece(fore).transform * player.pos
	assert_lt(now.distance_to(world), 0.2, "where it was in the world, a tick's fall on")


func test_bots_find_no_way_across_the_gap() -> void:
	# D10: once she has broken, the way a bot finds on a piece of her is that piece's walk
	# graph alone (BotFloors.footing): every doorway and stair it leads through stands on
	# the piece's own stretch, none across the gap to another.
	var config := _weak_match()
	var schedule := config.schedule()
	var parted := _events_of(schedule.timeline(), SinkTimeline.Kind.PARTED)[0]
	var pose := schedule.pose_at(schedule.physics_tick(parted.seconds) + Ticks.RATE)
	var floors := BotInputSource.floors_of(config)
	assert_eq(pose.standing.size(), 2, "she is in two pieces")
	for piece: int in pose.standing:
		var span := schedule.span_of(piece)
		var graph := floors.graph(BotFloors.footing(piece, Faces.Up.DECK))
		assert_gt(graph.zone_count(), 0, "piece %d has floors to walk" % piece)
		for portal: WalkGraph.Portal in graph.portals():
			for at: Vector3 in [portal.entry, portal.exit]:
				assert_true(
					at.x >= span.x - 1e-3 and at.x <= span.y + 1e-3,
					"piece %d's way at x %.2f stays on it" % [piece, at.x]
				)


func test_a_broken_timeline_round_trips_its_bytes() -> void:
	# FORMAT 5 (D11): a pose per piece — her pieces, where each runs and what it broke from,
	# each leaf's sea, attitude and cells, each event's piece — read back from the bytes as
	# the bake made them.
	var spots := [[&"joint", 6.0, 1.0]]
	var barge := _barge(spots, 1e9 * _peak(_barge(spots, 1e9), 6.0) / 1.5)
	var made := _baked(barge, _sea(true)).timeline()
	var read := SinkTimeline.from_bytes(made.to_bytes())
	assert_not_null(read, "the bytes read back")
	assert_eq(read.spans, made.spans, "where each piece runs")
	assert_eq(read.parents, made.parents, "what each broke from")
	assert_eq(read.born, made.born, "and when")
	assert_eq(read.leaves, made.leaves)
	assert_eq(read.leaf_cells, made.leaf_cells)
	assert_eq(read.seas, made.seas, "each leaf's sea")
	assert_eq(read.rotations, made.rotations, "each leaf's attitude")
	assert_eq(read.heads, made.heads)
	assert_eq(read.events.size(), made.events.size())
	for at in made.events.size():
		assert_eq(read.events[at].piece, made.events[at].piece, "each event's piece")
	assert_eq(read.digest(), made.digest(), "byte for byte")


func test_a_piece_left_afloat_is_no_sinking_a_match_plays() -> void:
	# §5b.1's must-sink rule with breaking: her aft end sealed, her bow holed, she parts
	# amidships — the bow goes, the aft piece floats on its sealed cell: she has not gone,
	# so a match draws such a hit again (MustSink.played).
	var barge := BoxBarge.new(LENGTH, 10.0, 8.0, 4.0, 3.0)
	barge.section_length = 2.0
	barge.cell(&"aft", Vector3(-20.0, -4.0, -5.0), Vector3(-6.0, 4.0, 5.0))
	barge.cell(&"middle", Vector3(-6.0, -4.0, -5.0), Vector3(12.0, 4.0, 5.0))
	barge.cell(&"bow", Vector3(12.0, -4.0, -5.0), Vector3(20.0, 4.0, 5.0))
	barge.hole(&"bow", Vector3(16.0, -3.0, 5.0), 1.0)
	var structure := barge.structure()
	structure.strength = GirderStrength.new()
	structure.strength.hog = 1e6
	structure.strength.sag = 1e6
	var spot := WeakSpot.new()
	spot.name = &"joint"
	spot.x = 0.0
	spot.share = 1e-3
	var weak: Array[WeakSpot] = [spot]
	structure.strength.weak = weak
	var bake := _baked(structure, _sea(true), 7200.0)
	var timeline := bake.timeline()
	assert_eq(timeline.leaves.size(), 2, "she parts")
	var gone := _events_of(timeline, SinkTimeline.Kind.GONE)
	assert_eq(gone.size(), 1, "one piece goes")
	assert_eq(gone[0].piece, timeline.leaves[1], "her bow")
	assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "her aft piece floats on")
	assert_eq(timeline.gone_at, -1.0, "she is not gone while a piece of her floats")
	assert_false(MustSink.played(timeline.end), "a match draws the hit again")


func test_continuation_is_exact_across_a_break() -> void:
	# D5: the weak hull's match from a second before she parts to two after, two seats
	# walking fore and aft and shoving — resumed from a snapshot before, at and after the
	# break, every resumed match continues to the same snapshot.
	var config := _weak_match()
	var parted := _events_of(config.schedule().timeline(), SinkTimeline.Kind.PARTED)[0]
	var tick := config.schedule().physics_tick(parted.seconds)
	var sim := MatchSim.from_snapshot(MatchJump.snapshot(config, tick - Ticks.RATE), config)
	var scene := func(at: int) -> Array[InputFrame]:
		var shove := InputFrame.SHOVE if at % 40 == 20 else 0
		return [
			SimFixtures.frame(0, Vector2(1.0, 0.0), 0, 0.0),
			SimFixtures.frame(1, Vector2(-1.0, 0.0), shove, 180.0),
		]
	var played: Array[Dictionary] = [sim.snapshot()]
	for at in 3 * Ticks.RATE:
		sim.step(scene.call(at))
		played.append(sim.snapshot())
	assert_eq(sim.pose().standing.size(), 2, "she has parted by its end")
	for start: int in [0, Ticks.RATE - 1, Ticks.RATE, Ticks.RATE + 1, 2 * Ticks.RATE]:
		var resumed := MatchSim.from_snapshot(played[start], config)
		for at in range(start, played.size() - 1):
			resumed.step(scene.call(at))
		var got := resumed.snapshot()
		got.erase("events")
		var expected := played[played.size() - 1].duplicate()
		expected.erase("events")
		assert_eq(got, expected, "resumed %d ticks in" % start)


func test_the_weak_hull_breaks_in_two_on_her_pinned_seed() -> void:
	# §5b.4 layer 3: her match hit on breaks_in_two — after the must-sink rule — parts her
	# once, and every piece goes; with its holes × 0.9 and × 1.1 the same, so the seed sits
	# far from the threshold.
	_breaks_in(&"breaks_in_two", 2, OutcomeClassifier.Outcome.BROKE_IN_TWO)


func test_with_her_second_weak_spot_she_breaks_in_three() -> void:
	# The same on breaks_in_three: her second weak spot parts too — three pieces, all gone.
	_breaks_in(&"breaks_in_three", 3, OutcomeClassifier.Outcome.BROKE_IN_THREE)


## The weak hull's match hit on the pinned seed [param seed_name], baked with its holes
## × 0.9, × 1, × 1.1: in [param pieces] pieces every time, labelled [param label], every
## piece gone.
func _breaks_in(seed_name: StringName, pieces: int, label: OutcomeClassifier.Outcome) -> void:
	var weak: ShipLayout = load(WEAK_HULL)
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var sea := SeaPhysics.load_default()
	var stream := SeedStreams.derive(PinnedSeeds.seed_named(seed_name), "sink")
	var choice := MustSink.choose(weak.structure, scenario, stream, sea)
	for scale: float in [0.9, 1.0, 1.1]:
		var timeline := choice.timeline
		if scale != 1.0:
			var scaled := HitDamage.new()
			scaled.jammed = choice.damage.jammed
			scaled.left_open = choice.damage.left_open
			scaled.weakened = choice.damage.weakened
			scaled.weakened_to = choice.damage.weakened_to
			scaled.sea_depth = choice.damage.sea_depth
			scaled.wave_height = choice.damage.wave_height
			for opening: ShipOpening in choice.damage.openings:
				var hole: ShipOpening = opening.duplicate()
				hole.area = opening.area * scale
				scaled.openings.append(hole)
			timeline = SinkBake.of(weak.structure, scaled, sea, scenario.bake_cap).timeline()
		assert_eq(timeline.leaves.size(), pieces, "%d pieces, × %s" % [pieces, scale])
		assert_eq(timeline.end, SinkTimeline.End.GONE, "every piece gone, × %s" % scale)
		assert_true(OutcomeClassifier.labels(timeline).has(label), "labelled so, × %s" % scale)


## The weak hull's match on her pinned breaks_in_two seed, as config.schedule() bakes it:
## made once for the tests that play it.
func _weak_match() -> MatchConfig:
	if _weak == null:
		_weak = MatchConfig.from_rules(
			load("res://data/match/default.tres"),
			PinnedSeeds.seed_named(&"breaks_in_two"),
			2,
			&"steamer_weak"
		)
		_weak.countdown_ticks = 0
	return _weak
