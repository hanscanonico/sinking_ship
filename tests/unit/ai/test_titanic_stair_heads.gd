extends GutTest
## Bots onto the Titanic's stairs from off their line (#543): a body walking to a stair's
## head turns onto it and goes down; it does not pace there. Its view lags its walk by its
## reaction time, and in a turn at a head the velocity it was seen at still carries on the
## walk it turned from. On main it followed its route from there: reckoned through the berth
## that had stopped it at the end of the railing it had to round, or short of the head it
## was turning onto, it walked back and forth for seconds on end; and between a doorway and
## the head of the stair beyond it, on a strip of floor no room holds, it went round by
## another stair 22 m forward.

const TITANIC := "res://data/ships/titanic.tres"
const TITANIC_SINKING := "res://data/sinking/titanic_open_sea.tres"
const F_DECK := -8.5625
const E_DECK := -5.9375
## F deck's ten-berth third-class room: the lane between the starboard railing of the
## stair down to her tank top and the room's wall, from its forward end; walked aft down it
## at a walk, a bot is handed its stick at each of these distances aft (z) — the railing
## ends at z -10.69, a hand short of the berth across the stair's head — going for the
## bonus in boiler room 6. Its feet below the stair's top are down it.
const LANE: Array[float] = [66.98, 67.08, 67.18]
const LANE_FROM := -8.8
const HANDED_IN_THE_LANE: Array[float] = [-9.6, -9.9, -10.2]
const BOILER_ROOM_6 := Vector3(62.2812, -18.1875, 0.2)
const DOWN_FROM_F_DECK := -10.0
## E deck aft of C, where a bot sets out at rest for the first- and second-class baggage
## room on the orlop: down the stair to F deck, off its foot and round onto the head of the
## next, in the passage beside it, on down. Its feet below F deck's are down that one.
const OVER_THE_PASSAGE: Array[Vector3] = [
	Vector3(79.5, E_DECK, -7.0),
	Vector3(80.0, E_DECK, -7.1),
	Vector3(81.0, E_DECK, -7.1),
	Vector3(80.5, E_DECK, -6.6),
]
const BAGGAGE_ROOM := Vector3(75.3789, -12.9375, -4.875)
const DOWN_FROM_THE_PASSAGE := -10.9
## E deck aft of J: the passage down to the doorway beside the head of the stair to F deck;
## walked aft down it at a walk, a bot is handed its stick at each of these distances aft
## (z), going for the bonus in boiler room 2: through the doorway, it turns onto the stair.
const PASSAGE: Array[float] = [-22.9, -22.8, -22.7]
const PASSAGE_FROM := -4.8
const HANDED_IN_THE_PASSAGE: Array[float] = [-6.2, -6.4]
const BOILER_ROOM_2 := Vector3(-8.1562, -18.1875, 2.65)
const DOWN_FROM_E_DECK := -7.0

static var _layout: ShipLayout
static var _floors: BotFloors
var _climbed := 0.0


func before_all() -> void:
	_layout = load(TITANIC)


func _profile() -> BotProfile:
	var profile: BotProfile = BotProfile.for_tier(&"normal").duplicate()
	profile.mistake_rate = 0.0
	return profile


## A match of three on her as she floats before any hit, and so for good, the bonus at
## [param spot_at] aboard; seat 0 placed at [param at], the others standing where they are.
func _sim(spot_at: Vector3, at: Vector3) -> MatchSim:
	var sinking: SinkScenario = load(TITANIC_SINKING).duplicate()
	sinking.hit = null
	sinking.explicit_hit = null
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 3, _layout, sinking)
	var spot := -1
	for index in _layout.bonus_spots.size():
		if _layout.bonus_spots[index].point.is_equal_approx(spot_at):
			spot = index
	assert_ne(spot, -1, "a spot at %s" % spot_at)
	SimFixtures.bring_aboard(sim, spot)
	SimFixtures.place(sim, 0, at, 0.0)
	return sim


## Seat 0's bot over [param sim]'s floors, built once for her: they answer only for the
## pose they are handed.
func _bot(sim: MatchSim) -> BotInputSource:
	if _floors == null:
		_floors = BotInputSource.floors_of(sim.config)
	return BotInputSource.new(0, _profile(), sim.config, _floors)


## Seat 0's stick, walking it the way [param walk] points — its look along it — until it
## stands [param past] along that way; from then on its bot's.
class Walked:
	extends InputSource
	var bot: BotInputSource
	var body: PlayerState
	var walk: Vector2
	var past: float
	var handed := false

	func next_frame(tick: int) -> InputFrame:
		handed = handed or Vector2(body.pos.x, body.pos.z).dot(walk) >= past
		if handed:
			return bot.next_frame(tick)
		var stick := InputFrame.quantize(walk)
		return InputFrame.new(0, tick, stick, 0, InputFrame.quantize_yaw(walk.angle()))

	func observe(snapshot: Dictionary, pose: ShipPose) -> void:
		bot.observe(snapshot, pose)


## Seconds [param source], seat 0 of [param sim], takes from its hand-over — at once if it
## was never walked — to put its feet below [param below]; INF if not within
## [param seconds]. How far its feet climbed back up once on a stair, in _climbed.
func _down(sim: MatchSim, source: InputSource, below: float, seconds: float) -> float:
	var sources: Array[InputSource] = [source, InputSource.new(), InputSource.new()]
	var runner := MatchRunner.new(sim, sources)
	var body := sim.state.seats[0]
	var walked := source as Walked
	while walked != null and not walked.handed and sim.state.tick < Ticks.from_seconds(3.0):
		runner.step()
	assert_true(walked == null or walked.handed, "walked there")
	var from := sim.state.tick
	var stairs := sim.surfaces
	var lowest := INF
	_climbed = 0.0
	while sim.state.tick - from < Ticks.from_seconds(seconds):
		runner.step()
		if lowest != INF or stairs.is_ramp(body.surface):
			lowest = minf(lowest, body.pos.y)
			_climbed = maxf(_climbed, body.pos.y - lowest)
		if body.pos.y < below:
			return (sim.state.tick - from) * Ticks.SECONDS_PER_TICK
	return INF


## A walk from [param from] the way [param walk] points, handed to the bot going for the
## bonus at [param spot_at] once it stands at [param handed] along it.
func _walked(spot_at: Vector3, from: Vector3, walk: Vector2, handed: float) -> Array:
	var sim := _sim(spot_at, from)
	var source := Walked.new()
	source.bot = _bot(sim)
	source.body = sim.state.seats[0]
	source.walk = walk
	source.past = handed
	return [sim, source]


## Walked aft down the lane beside the ten-berth room's stair at a walk, a bot turns round
## the end of its railing onto it and goes down within 5 s of its hand-over, from wherever
## in the lane and however far aft it is handed its stick. On main it reckoned itself
## through the berth across the head, where the berth had stopped it, and walked back up
## the lane: four of these walks were not down in 5 s.
func test_a_bot_walking_down_a_lane_turns_round_its_railing_onto_the_stair() -> void:
	for x: float in LANE:
		for handed: float in HANDED_IN_THE_LANE:
			var walk: Array = _walked(
				BOILER_ROOM_6, Vector3(x, F_DECK, LANE_FROM), Vector2(0.0, -1.0), -handed
			)
			var down := _down(walk[0], walk[1], DOWN_FROM_F_DECK, 5.0)
			assert_lt(down, 5.0, "from x %.2f, handed at z %.1f: %.1f s" % [x, handed, down])


## Down off the foot of E deck's stair aft of C, a bot turns round onto the head of the
## next, in the passage beside it, and goes down within 5 s of setting out, its feet never
## back up a stair once on one. On main, turning, it reckoned itself short of the head by
## its velocity a lag before, went on past it, and walked back and forth beside the stair's
## railing: from one of these spots it was not down in 5 s. Followed from where its walks
## had stepped it, it turned onto the head, but the way round over the floor to the head it
## still held took it back up the stair, 1.59 m from the first spot (#550).
func test_a_bot_off_a_stair_s_foot_turns_onto_the_next_one_s_head() -> void:
	for from: Vector3 in OVER_THE_PASSAGE:
		var sim := _sim(BAGGAGE_ROOM, from)
		var down := _down(sim, _bot(sim), DOWN_FROM_THE_PASSAGE, 5.0)
		assert_lt(down, 5.0, "from %s: %.1f s" % [from, down])
		assert_lt(_climbed, 0.1, "from %s: back up %.2f m" % [from, _climbed])


## Walked aft down E deck's passage aft of J, a bot handed its stick by the doorway beside
## the head of the stair to F deck goes through it, turns onto the stair and goes down
## within 2 s. Between the doorway and the head lies a strip of floor no room holds: on main,
## there, it was off its leg and in another zone, whose route ran to another stair 22 m
## forward, and four of these walks went that way: none of them down in 2 s.
func test_a_bot_through_a_doorway_turns_onto_the_stair_beside_it() -> void:
	for x: float in PASSAGE:
		for handed: float in HANDED_IN_THE_PASSAGE:
			var walk: Array = _walked(
				BOILER_ROOM_2, Vector3(x, E_DECK, PASSAGE_FROM), Vector2(0.0, -1.0), -handed
			)
			var down := _down(walk[0], walk[1], DOWN_FROM_E_DECK, 2.0)
			assert_lt(down, 2.0, "from x %.2f, handed at z %.1f: %.1f s" % [x, handed, down])
