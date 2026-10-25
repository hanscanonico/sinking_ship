extends GutTest
## The sea decides (#307, #311). A bonus aboard is lost when water stands at its spot, when
## she turns past the floor it lies on, or when the piece of her it lies in is gone: gone
## from the snapshot, the sim saying so and the transcript telling it. A planned bonus comes
## only to an open spot — none lying there, and no water standing anywhere on its room's
## floor as the water stands now, never as the timeline has it next (D10) — so nothing
## brings a lost one back: its spot opens again only for a later planned bonus, and only
## while its room is dry. below_decks' holds flood as SimFixtures.flooding sinks her.

## When below_decks' hold floods (SimFixtures.flooding): its floor level with the sea on
## this tick, under it from the next.
const FLOODS := 2.0
## Trimmed this far by the stern, below_decks' first hold has the sea over its after end
## and short of its spot (_trimmed).
const BY_THE_STERN := -5.0
## The weak hull's room (test_breaking) whose bonus spot _broken keeps: just fore of the cut
## she parts at on her pinned seed, in a room astride it.
const ASTRIDE := &"middle port cabin"

## The weak hull's match (_broken), made once — it bakes her sinking — and the first tick
## it stands in two pieces of her.
static var _weak: MatchConfig
static var _parted := -1


## Her sinking with every piece of her gone — wholly under the sea and going down — on
## [member gone], as a physical sinking's timeline tells it: an authored one never has her
## go (SinkSchedule.piece_gone_tick).
class GoneAt:
	extends SinkSchedule
	var gone := -1

	func piece_gone_tick(_piece: int) -> int:
		return gone


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## The ticks events of [param kind] came on among [param events].
func _ticks(events: Array[SimEvent], kind: SimEvent.Kind) -> Array:
	return _of(events, kind).map(func(event: SimEvent) -> int: return event.tick)


## `make match` tells [param events] of [param sim]'s match with a line for the Double
## life lost at below_decks' first hold's spot on [param tick].
func _assert_told_lost(sim: MatchSim, events: Array[SimEvent], tick: int) -> void:
	var told := MatchTranscript.new()
	told.bonuses(sim.config)
	told.add(events)
	var line := "%s Double life lost · spot 0" % MatchTranscript.clock(tick)
	assert_has(Array(told.text().split("\n")), line, "the transcript tells it")


## below_decks' hold flooding as SimFixtures.flooding has it, FLOODS seconds in, and dry
## again by 6.5 s: the sea falling back off its floor from 6 s.
func _ebbing() -> SinkScenario:
	var floors := SimFixtures.deck().freeboard + SimFixtures.HOLD_FLOOR
	var rows := [
		[0.0, 0.0, 0.0, 0.0],
		[FLOODS, floors, 0.0, 0.0],
		[FLOODS + 1.0, floors + 1.0, 0.0, 0.0],
		[6.0, floors + 1.0, 0.0, 0.0],
		[6.5, floors - 0.5, 0.0, 0.0],
		[600.0, floors - 0.5, 0.0, 0.0],
	]
	return SimFixtures.scenario(rows)


## Calm, trimmed BY_THE_STERN: below_decks' first hold has the sea over its after end and
## short of its spot, the second hold none.
func _trimmed() -> SinkScenario:
	return SimFixtures.scenario([[0.0, 0.0, BY_THE_STERN, 0.0], [600.0, 0.0, BY_THE_STERN, 0.0]])


## The weak hull's match on her pinned breaks_in_two seed, which parts her in two
## (test_breaking), played with [param rules] and two bonus spots alone: ASTRIDE's, then one
## of the test's own on her main deck on the cut she parts at, clear of the sea as she
## parts. Her sinking is baked once for the suite.
func _broken(rules: BonusRules) -> MatchConfig:
	if _weak == null:
		_weak = MatchConfig.from_rules(
			load("res://data/match/default.tres"),
			PinnedSeeds.seed_named(&"breaks_in_two"),
			2,
			&"steamer_weak"
		)
		_weak.countdown_ticks = 0
		var schedule := _weak.schedule()
		_parted = _parting(schedule)
		var layout: ShipLayout = _weak.ship.duplicate()
		var kept: Array[ShipBonusSpot] = []
		for spot: ShipBonusSpot in layout.bonus_spots:
			if layout.rooms[spot.room].name == ASTRIDE:
				kept.append(spot)
		var on_the_cut := ShipBonusSpot.new()
		var fore := schedule.pose_at(_parted).standing[1]
		on_the_cut.point = Vector3(schedule.span_of(fore).x, 0.0, 0.0)
		on_the_cut.room = kept[0].room
		kept.append(on_the_cut)
		layout.bonus_spots = kept
		_weak.ship = layout
	_weak.bonus_rules = rules
	return _weak


## The first tick [param schedule]'s match stands in more than one piece of her.
static func _parting(schedule: SinkSchedule) -> int:
	for event: SinkTimeline.Event in schedule.timeline().events:
		if event.kind == SinkTimeline.Kind.PARTED:
			var tick := schedule.physics_tick(event.seconds) - Ticks.RATE
			while schedule.pose_at(tick).standing.size() < 2:
				tick += 1
			return tick
	return -1


## The spots bonuses came to, in order, over the first 1.5 s of a match on below_decks' two
## holds sunk as [param sinking] has her, seed by seed: the plan's first coming 1 s in.
func _landed(sinking: SinkScenario) -> Array:
	var landed := {}
	for seed_value in range(1, 13):
		var config := SimFixtures.config(1, sinking, seed_value, SimFixtures.below_decks(2))
		config.bonus_rules = SimFixtures.bonus_rules()
		var sim := MatchSim.create(config)
		for event: SimEvent in SimFixtures.step(sim, {}, Ticks.from_seconds(1.5)):
			if event.kind == SimEvent.Kind.BONUS_CAME:
				landed[event.spot] = true
	var spots := landed.keys()
	spots.sort()
	return spots


## Water standing at its spot takes a bonus aboard on the tick it reaches it, not before:
## lost — gone from the snapshot — and the sim says which, and where.
func test_a_bonus_is_lost_once_water_stands_at_its_spot() -> void:
	var sim := SimFixtures.bonus_sim(
		SimFixtures.bonus_rules(600.0), 1, null, SimFixtures.flooding(FLOODS)
	)
	SimFixtures.bring_aboard(sim, 0)
	var floods := Ticks.from_seconds(FLOODS)
	var events := SimFixtures.step(sim, {}, floods + 1)
	assert_eq(sim.state.bonuses.size(), 1, "aboard while the sea stands short of its spot")
	assert_true(_of(events, SimEvent.Kind.BONUS_LOST).is_empty())
	events = SimFixtures.step(sim)
	assert_true(sim.state.bonuses.is_empty(), "lost once it stands there")
	assert_eq(sim.snapshot()["bonuses"], [], "gone from the snapshot")
	var lost := _of(events, SimEvent.Kind.BONUS_LOST)
	assert_eq(lost.size(), 1, "and the sim says so")
	if lost.size() == 1:
		assert_eq([lost[0].tick, lost[0].bonus, lost[0].spot], [floods + 1, 0, 0])
	_assert_told_lost(sim, events, floods + 1)


## What a press takes is what the snapshot before it showed (D13): a bonus aboard as a tick
## leaves it is there for the next tick's presses, the sea taking it only once they are done
## — a press on the tick the water reaches its spot takes it.
func test_a_press_on_the_tick_the_sea_reaches_a_bonus_takes_it() -> void:
	var sim := SimFixtures.bonus_sim(
		SimFixtures.bonus_rules(600.0), 1, null, SimFixtures.flooding(FLOODS)
	)
	SimFixtures.bring_aboard(sim, 0)
	SimFixtures.place(sim, 0, SimFixtures.by_hold_spot(), 0.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.from_seconds(FLOODS) + 1)
	assert_eq(sim.snapshot()["bonuses"].size(), 1, "aboard as the last dry tick leaves it")
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.GRAB)})
	assert_eq(sim.state.seats[0].bonus, 0, "the press takes it")
	assert_true(_of(events, SimEvent.Kind.BONUS_LOST).is_empty(), "before the sea can")


## Her decks stop being floors once she turns past brace_holds_to (Faces): a bonus aboard
## is lost on the tick the match turns onto her side, and none comes while it stands there
## — the hold dry all the while, lifted clear of the sea.
func test_a_bonus_is_lost_as_she_turns_past_its_floor() -> void:
	var rolling := SimFixtures.scenario(
		[[0.0, -10.0, 0.0, 0.0], [3.0, -10.0, 0.0, 80.0], [600.0, -10.0, 0.0, 80.0]]
	)
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(1.0, 2.0, 0.0, 2), 1, null, rolling)
	var events: Array[SimEvent] = []
	var turned := -1
	for tick in Ticks.from_seconds(5.0):
		events.append_array(SimFixtures.step(sim))
		if turned == -1 and sim.state.up[0] != Faces.Up.DECK:
			turned = tick
	assert_ne(turned, -1, "she turned onto her side")
	var spot := SimFixtures.hold_spot(0)
	for tick: int in [turned, Ticks.from_seconds(5.0)]:
		assert_false(sim.surfaces.wet(spot, sim.schedule.pose_at(tick)), "dry at %d" % tick)
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_CAME), [Ticks.RATE], "one at 1 s, none at 3 s")
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_LOST), [turned], "lost as she turned past it")
	_assert_told_lost(sim, events, turned)


## A bonus aboard goes with the piece of her it lies in: lost on the tick that piece is gone,
## its hold dry all the same, and none comes to it after.
func test_a_bonus_is_lost_with_the_piece_of_her_it_lies_in() -> void:
	var config := SimFixtures.config(1, SimFixtures.calm_until(600.0), 1, SimFixtures.below_decks())
	config.bonus_rules = SimFixtures.bonus_rules(1.0, 2.0, 0.0, 2)
	var going: GoneAt = config.schedule_as(GoneAt)
	var gone := Ticks.from_seconds(2.0)
	going.gone = gone
	var sim := MatchSim.create(config)
	assert_false(sim.surfaces.wet(SimFixtures.hold_spot(0), sim.schedule.pose_at(gone)), "dry")
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(4.0))
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_CAME), [Ticks.RATE], "one at 1 s, none at 3 s")
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_LOST), [gone], "lost as she went")
	_assert_told_lost(sim, events, gone)


## Her floor torn away between two pieces of her takes a bonus lying on it: on the weak
## hull, a Double life at the spot on her main deck on the cut she parts at — clear of the
## sea under either piece's pose — is lost on the first tick she stands in two pieces.
func test_a_bonus_is_lost_where_she_parts_under_it() -> void:
	var config := _broken(SimFixtures.bonus_rules(600.0))
	var sim := MatchSim.from_snapshot(MatchJump.snapshot(config, _parted - 1), config)
	SimFixtures.bring_aboard(sim, 1)
	var spot := config.ship.bonus_spots[1].point
	var parted := sim.schedule.pose_at(_parted)
	assert_eq(sim.pieces.piece_at(parted.standing, spot.x), -1, "between her pieces as she parts")
	for piece: int in parted.standing:
		assert_false(sim.surfaces.wet(spot, parted.of_piece(piece)), "dry in piece %d" % piece)
	var events := SimFixtures.step(sim, {}, 2)
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_LOST), [_parted], "lost as she parts")


## Once she has parted, a spot on a piece of her opens by the part of its room on that piece,
## in that piece's water — the rest went with another piece of her. On the weak hull, her
## middle port cabin, astride the cut, has its floor read wet whole under its fore piece's
## pose, yet dry on that piece, with no water at its spot: a Double life planned then comes
## to it — the spot on the cut, between her pieces, never open.
func test_a_room_astride_her_parting_opens_by_its_part_on_the_spot_s_piece() -> void:
	var config := _broken(SimFixtures.bonus_rules(600.0))
	var sim := MatchSim.new(config)
	var at := config.ship.bonus_spots[0]
	var room := config.ship.rooms[at.room]
	var astride := -1
	for tick in range(_parted, _parted + 10 * Ticks.RATE):
		var pose := sim.schedule.pose_at(tick)
		var piece := sim.pieces.piece_at(pose.standing, at.point.x)
		var posed := pose.of_piece(piece)
		var part := sim.pieces.on_piece(room.area, piece)
		if (
			sim.surfaces.floor_wet(room.area, room.floor_height, posed)
			and not sim.surfaces.floor_wet(part, room.floor_height, posed)
			and not sim.surfaces.wet(at.point, posed)
		):
			astride = tick
			break
	assert_ne(astride, -1, "a tick its floor reads wet whole, dry on its piece")
	if astride == -1:
		return
	var first := Ticks.to_seconds(astride) * config.scenario.clock
	config = _broken(SimFixtures.bonus_rules(first))
	sim = MatchSim.from_snapshot(MatchJump.snapshot(config, astride), config)
	var came := _of(SimFixtures.step(sim), SimEvent.Kind.BONUS_CAME)
	assert_eq(came.size(), 1, "it came")
	if came.size() == 1:
		assert_eq([came[0].tick, came[0].spot], [astride, 0], "to the cabin's spot")


## A spot is open only while no water stands anywhere on its room's floor: the sea over the
## first hold's after end, every bonus planned comes to the second hold's spot, whatever its
## pick — on an even keel the picks land on both. A bonus lying at the first hold's spot
## stays, the water short of it.
func test_a_spot_opens_only_while_its_room_s_floor_is_dry() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 1, null, _trimmed())
	var pose := sim.pose()
	var aft := Vector3(SimFixtures.HOLD_AFT, SimFixtures.HOLD_FLOOR, -3.0)
	assert_true(sim.surfaces.wet(aft, pose), "the sea over the first hold's after end")
	assert_false(sim.surfaces.wet(SimFixtures.hold_spot(0), pose), "short of its spot")
	var second_aft := aft + Vector3(SimFixtures.HOLD_LENGTH + 1.0, 0.0, 0.0)
	assert_false(sim.surfaces.wet(second_aft, pose), "and of the second hold")
	assert_eq(_landed(SimFixtures.calm_until(600.0)), [0, 1], "on an even keel: both")
	assert_eq(_landed(_trimmed()), [1], "by the stern: the second alone")
	SimFixtures.bring_aboard(sim, 0)
	var events := SimFixtures.step(sim, {}, Ticks.RATE)
	assert_eq(sim.state.bonuses.size(), 1, "one lying at the first hold's spot stays")
	assert_true(_of(events, SimEvent.Kind.BONUS_LOST).is_empty())


## The open check reads the water as it stands now, never as the timeline has it next
## (D10): the sea level with the hold's floor on the planned tick and over it on the next,
## its spot opens all the same — and the bonus that came is lost a tick later.
func test_a_room_the_sea_floods_on_the_next_tick_still_opens() -> void:
	var sim := SimFixtures.bonus_sim(
		SimFixtures.bonus_rules(FLOODS), 1, null, SimFixtures.flooding(FLOODS)
	)
	var floods := Ticks.from_seconds(FLOODS)
	var spot := SimFixtures.hold_spot(0)
	assert_false(sim.surfaces.wet(spot, sim.schedule.pose_at(floods)), "dry on its tick")
	assert_true(sim.surfaces.wet(spot, sim.schedule.pose_at(floods + 1)), "flooded on the next")
	var events := SimFixtures.step(sim, {}, floods + 2)
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_CAME), [floods], "it came on its tick")
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_LOST), [floods + 1], "and was lost on the next")


## With no room's floor dry, no spot is open: every bonus planned while the sea stands in
## the one hold never comes.
func test_no_bonus_comes_while_every_room_is_flooded() -> void:
	var rules := SimFixtures.bonus_rules(FLOODS + 1.0, 2.0, 0.0, 2)
	var sim := SimFixtures.bonus_sim(rules, 1, null, SimFixtures.flooding(FLOODS))
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(10.0))
	assert_true(_of(events, SimEvent.Kind.BONUS_CAME).is_empty(), "none of the four planned")
	assert_true(sim.state.bonuses.is_empty())


## A lost bonus is gone for good: its spot opens again only for a later planned bonus, and
## only while its room is dry — none planned while the sea stands there comes, none comes
## as it falls back, and the next planned after comes to it.
func test_a_lost_bonus_s_spot_opens_again_only_for_a_later_planned_one_while_dry() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(1.0, 3.0, 0.0, 2), 1, null, _ebbing())
	var spot := SimFixtures.hold_spot(0)
	var dry_at := Ticks.from_seconds(6.4)
	assert_false(sim.surfaces.wet(spot, sim.schedule.pose_at(dry_at)), "dry again by 6.4 s")
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(8.0))
	var came := [Ticks.from_seconds(1.0), Ticks.from_seconds(7.0)]
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_CAME), came, "at 1 s and 7 s, never at 4 s")
	var floods := Ticks.from_seconds(FLOODS)
	assert_eq(_ticks(events, SimEvent.Kind.BONUS_LOST), [floods + 1], "the first lost to it")
	assert_eq(_of(events, SimEvent.Kind.BONUS_CAME)[-1].spot, 0, "the second at its spot")
