extends GutTest
## Her flights narrower than a body (#566). Four of the Titanic's flights are 0.75 m wide and a
## body is 0.8 m across, so a body on one is pressed against both its sides at once: the decks'
## edges either side stand over its feet. On ramp 52, the engineers' ladder from E deck down to
## F, E deck's side is two pieces meeting at x -46.6875, and the end of one held a body against
## the flight as a corner would: a bot pressing down it stayed there for the whole of #491's
## sample's row 9, and most bodies pressing along it either way, or along the flight from F deck
## down to G at x 72.4, stopped at such a seam. A body pressing along every flight narrower than
## itself, down or up, from off its end, square or to one side, its stick a little across, comes
## off the far end.

const TITANIC := "res://data/ships/titanic.tres"
const TITANIC_SINKING := "res://data/sinking/titanic_open_sea.tres"
## How far off a flight's end a body sets out, how far to one side of its middle line, and how
## far across its stick presses for each metre along.
const SET_OUT := 0.6
const ASIDE: Array[float] = [-0.2, 0.0, 0.2]
const PRESSED_ACROSS: Array[float] = [-0.05, 0.0, 0.05]
## Off the far end: its middle this far past the end, its feet at that end's height, within
## this many seconds of setting out.
const PAST := 0.45
const SECONDS := 3.0
## Ramp 52's side where the bot stood (#566): pressed south of its middle by the squeeze, just
## down from the seam, pressing down the flight.
const BY_THE_SEAM := Vector2(-46.87, -10.01)
const DOWN_RAMP_52 := Vector2(0.99, 0.01)
const SEAM_PROBE := Vector3(-46.9, -6.45, -9.95)

static var _layout: ShipLayout
static var _sim: MatchSim


func before_all() -> void:
	_layout = load(TITANIC)
	var sinking: SinkScenario = load(TITANIC_SINKING).duplicate()
	sinking.hit = null
	sinking.explicit_hit = null
	var config := SimFixtures.config(1, sinking, 1, _layout)
	config.countdown_ticks = 0
	_sim = MatchSim.create(config)


## Seconds a body set at [param at], pressing [param stick], takes to stand [param past] beyond
## [param finish] along [param along], its feet at that end's height; INF if not within SECONDS.
func _through(at: Vector3, stick: Vector2, finish: Vector3, along: Vector2) -> float:
	SimFixtures.place(_sim, 0, at, 0.0)
	var body := _sim.state.seats[0]
	var frame := SimFixtures.frame(0, stick, 0, rad_to_deg(stick.angle()))
	for tick in Ticks.from_seconds(SECONDS):
		SimFixtures.step(_sim, {0: frame})
		var beyond := (Vector2(body.pos.x, body.pos.z) - Vector2(finish.x, finish.z)).dot(along)
		if beyond > PAST and absf(body.pos.y - finish.y) < 0.05:
			return (tick + 1) * Ticks.SECONDS_PER_TICK
	return INF


func test_a_body_presses_along_every_flight_narrower_than_itself_both_ways() -> void:
	var rules := SimFixtures.rules()
	var narrow := 0
	var stuck: Array[String] = []
	for index in _layout.ramps.size():
		var ramp := _layout.ramps[index]
		var x_axis := ramp.axis == ShipRamp.Axis.X
		var width := ramp.area.size.y if x_axis else ramp.area.size.x
		if width >= rules.body_radius * 2.0:
			continue
		narrow += 1
		var across := Vector2.DOWN if x_axis else Vector2.RIGHT
		var high := 0 if ramp.start_height > ramp.end_height else 1
		for from: int in [high, 1 - high]:
			var start := ramp.end_point(from)
			var finish := ramp.end_point(1 - from)
			var along := Vector2(finish.x - start.x, finish.z - start.z).normalized()
			for aside: float in ASIDE:
				for pressed: float in PRESSED_ACROSS:
					var off := Vector2(start.x, start.z) - along * SET_OUT + across * aside
					var stick := (along + across * pressed).normalized()
					var took := _through(Vector3(off.x, start.y, off.y), stick, finish, along)
					if took == INF:
						stuck.append(
							(
								"ramp %d %s from %s, pressing %s: held at %s"
								% [
									index,
									"down" if from == high else "up",
									off,
									stick,
									_sim.state.seats[0].pos
								]
							)
						)
	assert_eq(narrow, 4, "her flights narrower than a body")
	assert_eq(stuck, [] as Array[String], "every one passed both ways")


func test_a_body_pressed_against_ramp_52s_side_by_its_seam_goes_on_down() -> void:
	var ramp := _layout.ramps[52]
	assert_true(ramp.area.has_point(BY_THE_SEAM), "ramp 52 is the engineers' ladder")
	var at := Vector3(BY_THE_SEAM.x, ramp.height_at(BY_THE_SEAM.x, BY_THE_SEAM.y), BY_THE_SEAM.y)
	var finish := ramp.end_point(1)
	var took := _through(at, DOWN_RAMP_52.normalized(), finish, Vector2.RIGHT)
	assert_lt(took, 1.5, "down onto F deck")
	# E deck's two pieces beside the flight hold it square off their one edge.
	var rules := SimFixtures.rules()
	var held := _sim.surfaces.obstacle_contacts(
		SEAM_PROBE, rules.body_radius, rules.body_height, rules.step_height
	)
	assert_eq(held.size(), 1, "held once")
	if held.size() == 1:
		assert_true(held[0].normal.is_equal_approx(Vector2(0, 1)), "square off the side")
