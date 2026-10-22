extends GutTest
## The Titanic's boarding ladders (SH5): her well decks stand ten metres out of the
## sea, past any edge's climb_reach, so a body shoved over her rail there climbs back
## aboard up a ladder down her side — one each side of both wells — or not at all.

const WELLS: Array[StringName] = [&"after well deck", &"forward well deck"]

var _layout: ShipLayout


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")


## Her ladder up to [param well] on her port side (z < 0) when [param port], else on her
## starboard side; null when she has none there.
func _ladder(well: StringName, port: bool) -> ShipLadder:
	for ladder: ShipLadder in _layout.ladders:
		if _layout.platforms[ladder.platform].name == well and (ladder.from.y < 0.0) == port:
			return ladder
	return null


## A two-seat match on her, held level at her freeboard: seat 1 standing on the
## forward well deck, out of the way.
func _sim() -> MatchSim:
	var sim := SimFixtures.sim(2, SimFixtures.calm(), _layout)
	SimFixtures.place(sim, 1, Vector3(82.0, 0.0, 0.0))
	return sim


func test_each_well_deck_has_a_ladder_down_either_side() -> void:
	for well in WELLS:
		for port: bool in [true, false]:
			var ladder := _ladder(well, port)
			assert_not_null(ladder, "%s, %s" % [well, "port" if port else "starboard"])
			if ladder == null:
				continue
			var deck := _layout.platforms[ladder.platform]
			assert_true(deck.edge_holds(ladder.from, ladder.to), "along its deck's edge")
			var side := deck.area.position.y if port else deck.area.end.y
			assert_eq(ladder.from.y, side, "down her side, not into a hole")
	assert_eq(_layout.problems(_layout.min_seats), PackedStringArray(), "she lints clean")


func test_a_swimmer_climbs_back_aboard_up_a_ladder() -> void:
	# Over the after well deck's port rail, where a body shoved over her side comes
	# down, ten metres under the deck: up the ladder, before the cold takes it.
	var rules := SimFixtures.rules()
	var ladder := _ladder(&"after well deck", true)
	assert_not_null(ladder, "the ladder")
	if ladder == null:
		return
	var sim := _sim()
	var middle := (ladder.from + ladder.to) * 0.5
	SimFixtures.swim(sim, 0, Vector3(middle.x, 0.0, middle.y - rules.body_radius - 0.2))
	var swimmer := sim.state.seats[0]
	var starboard := {0: SimFixtures.frame(0, Vector2(0.0, 1.0))}
	var climbed: Array[SimEvent] = []
	for _tick in Ticks.from_seconds(rules.cold_meter + 10.0):
		for event: SimEvent in SimFixtures.step(sim, starboard):
			if event.kind == SimEvent.Kind.CLIMBED_OUT:
				climbed.append(event)
		if not climbed.is_empty() or swimmer.is_out():
			break
	assert_false(swimmer.is_out(), "the cold did not take it")
	assert_eq(climbed.size(), 1, "it climbed out")
	assert_eq(swimmer.body, PlayerState.Body.GROUNDED)
	assert_eq(SimFixtures.name_of(_layout, swimmer.surface), &"after well deck", "up the ladder")
	assert_eq(swimmer.pos.y, 0.0, "standing on the deck")


func test_a_swimming_bot_finds_the_ladder_along_her_side() -> void:
	# Four metres forward of the after well's starboard ladder, where seat 0 came to
	# rest after its fall in seed 3's match: a bot swims to it and climbs.
	var ladder := _ladder(&"after well deck", false)
	assert_not_null(ladder, "the ladder")
	if ladder == null:
		return
	var config := SimFixtures.config(2, SimFixtures.calm(), 3, _layout)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 1, Vector3(82.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(ladder.from.x + 4.0, 0.0, ladder.from.y + 1.5))
	var sources: Array[InputSource] = [
		BotInputSource.new(0, load(SimFixtures.NORMAL_BOT), config), InputSource.new()
	]
	var events := MatchRunner.new(sim, sources).run(
		Ticks.from_seconds(config.rules.cold_meter + 10.0)
	)
	var bot := sim.state.seats[0]
	assert_false(bot.is_out(), "the cold did not take it")
	var climbed := events.filter(
		func(event: SimEvent) -> bool: return event.kind == SimEvent.Kind.CLIMBED_OUT
	)
	assert_eq(climbed.size(), 1, "it climbed out once")
	if not climbed.is_empty():
		assert_eq(
			SimFixtures.name_of(_layout, climbed[0].surface), &"after well deck", "up the ladder"
		)
