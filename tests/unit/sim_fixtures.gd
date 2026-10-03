class_name SimFixtures
extends RefCounted
## Shared setup for the sim's suites: the shipped data, hand-made scenarios, and
## matches with bodies placed by hand.

const RULES := "res://data/rules/brawl.tres"
const FLAT_DECK := "res://data/ships/flat_deck.tres"
const FLAT_SINKING := "res://data/sinking/flat.tres"
const STEAMER := "res://data/ships/steamer.tres"
const STEAMER_SINKING := "res://data/sinking/steamer.tres"
const NORMAL_BOT := "res://data/bots/normal.tres"


static func rules() -> BrawlRules:
	return load(RULES)


static func deck() -> ShipLayout:
	return load(FLAT_DECK)


static func steamer() -> ShipLayout:
	return load(STEAMER)


## The index of [param layout]'s platform called [param platform_name].
static func platform_named(layout: ShipLayout, platform_name: StringName) -> int:
	for index in layout.platforms.size():
		if layout.platforms[index].name == platform_name:
			return index
	return Surfaces.NONE


## A scenario from rows of [at, sink, trim_deg, heel_deg].
static func scenario(rows: Array, starts_at: float = 0.0) -> SinkScenario:
	var made := SinkScenario.new()
	made.starts_at = starts_at
	var keyframes: Array[SinkKeyframe] = []
	for row: Array in rows:
		var keyframe := SinkKeyframe.new()
		keyframe.at = row[0]
		keyframe.sink = row[1]
		keyframe.trim_deg = row[2]
		keyframe.heel_deg = row[3]
		keyframes.append(keyframe)
	made.keyframes = keyframes
	return made


## A ship that never moves.
static func calm() -> SinkScenario:
	return scenario([[0.0, 0.0, 0.0, 0.0]])


## A ship held at [param trim_deg] and [param heel_deg], lifted well clear of the
## sea so that only the tilt matters.
static func tilted(trim_deg: float, heel_deg: float) -> SinkScenario:
	return scenario([[0.0, -10.0, trim_deg, heel_deg]])


## The middle of the gap in the flat deck's railing along its edge at
## [param edge_z], in the ship's x/z plane: the hole between that edge's spans.
static func rail_gap(edge_z: float) -> Vector2:
	var ends: Array[float] = []
	for railing: ShipRailing in deck().railings:
		if is_equal_approx(railing.from.y, edge_z):
			ends.append_array([railing.from.x, railing.to.x])
	ends.sort()
	return Vector2((ends[1] + ends[2]) * 0.5, edge_z)


## A match on the flat deck, or on [param layout] when one is given.
static func config(
	seats: int, sinking: SinkScenario = null, seed_value: int = 1, layout: ShipLayout = null
) -> MatchConfig:
	return MatchConfig.new(
		seed_value,
		seats,
		rules(),
		layout if layout != null else deck(),
		sinking if sinking != null else calm()
	)


static func sim(seats: int, sinking: SinkScenario = null, layout: ShipLayout = null) -> MatchSim:
	return MatchSim.create(config(seats, sinking, 1, layout))


## Puts [param seat] standing at [param pos] (ship-local), looking
## [param facing_deg] from the bow toward starboard, at rest.
static func place(match_sim: MatchSim, seat: int, pos: Vector3, facing_deg: float = 0.0) -> void:
	var player := match_sim.state.seats[seat]
	player.pos = pos
	player.vel = Vector3.ZERO
	player.last_look = InputFrame.quantize_yaw(deg_to_rad(facing_deg))
	player.facing = InputFrame.yaw_angle(player.last_look)
	player.body = PlayerState.Body.GROUNDED
	player.surface = match_sim.surfaces.under(pos, match_sim.config.rules.step_height)


## A frame looking [param look_deg] from the bow toward starboard.
static func frame(
	seat: int, move: Vector2 = Vector2.ZERO, buttons: int = 0, look_deg: float = 0.0
) -> InputFrame:
	return InputFrame.new(
		seat, 0, InputFrame.quantize(move), buttons, InputFrame.quantize_yaw(deg_to_rad(look_deg))
	)


## Steps [param ticks] ticks; [param frames] maps a seat to the frame it sends
## every one of them, and the others repeat their last.
static func step(match_sim: MatchSim, frames: Dictionary = {}, ticks: int = 1) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for _tick in ticks:
		var row: Array[InputFrame] = []
		row.resize(match_sim.config.seats)
		for seat: int in frames:
			row[seat] = frames[seat]
		events.append_array(match_sim.step(row))
	return events
