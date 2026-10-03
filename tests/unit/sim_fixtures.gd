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
## A frame's look when none is given: step() sends the seat's own look instead.
const KEEP_LOOK := -1


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


## The name of [param layout]'s platform [param surface], or &"" for a ramp, a
## blocker top or nothing: the main deck is several platforms of one name.
static func name_of(layout: ShipLayout, surface: int) -> StringName:
	if surface < 0 or surface >= layout.platforms.size():
		return &""
	return layout.platforms[surface].name


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


## A lurch at [param at] seconds swinging the heel by [param heel_deg] and back over
## [param duration], telegraphed [param warning] ahead, unjittered.
static func lurch(
	at: float, heel_deg: float, duration: float = 3.0, warning: float = 1.0
) -> SinkEvent:
	var event := SinkEvent.new()
	event.kind = SinkEvent.Kind.LURCH
	event.at = at
	event.heel_deg = heel_deg
	event.duration = duration
	event.warning = warning
	return event


## The platforms called [param platform] collapsing at [param at] seconds,
## telegraphed [param warning] ahead, unjittered.
static func collapse(at: float, platform: StringName, warning: float = 3.0) -> SinkEvent:
	var event := SinkEvent.new()
	event.kind = SinkEvent.Kind.COLLAPSE
	event.at = at
	event.platform = platform
	event.warning = warning
	return event


## [param scenario] with [param events] and a cap at [param cap] seconds.
static func with_events(
	scenario: SinkScenario, events: Array[SinkEvent], cap: float = 0.0
) -> SinkScenario:
	scenario.events = events
	scenario.cap = cap
	return scenario


## A point at every corner of every surface of [param layout] — platforms, the
## ends of ramps, blocker tops — at its height there.
static func surface_points(layout: ShipLayout) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var feet: Array[Rect2] = []
	var heights := PackedFloat64Array()
	for platform: ShipPlatform in layout.platforms:
		feet.append(platform.area)
		heights.append(platform.height)
	for blocker: ShipBlocker in layout.blockers:
		var reach := Vector2(blocker.radius, blocker.radius)
		var box := blocker.centre - reach
		feet.append(
			blocker.area if blocker.shape == ShipBlocker.Shape.BOX else Rect2(box, reach * 2.0)
		)
		heights.append(blocker.top)
	for index in feet.size():
		var area := feet[index]
		for corner: Vector2 in [
			area.position,
			area.end,
			Vector2(area.position.x, area.end.y),
			Vector2(area.end.x, area.position.y),
		]:
			points.append(Vector3(corner.x, heights[index], corner.y))
	for ramp: ShipRamp in layout.ramps:
		for end in 2:
			for corner: Vector2 in ramp.end_edge(end):
				points.append(Vector3(corner.x, ramp.end_point(end).y, corner.y))
	return points


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


## The ship-plane velocity [param player] moves at — or, frozen in a hit-stop, the
## one it moves at once the stop ends.
static func sent(player: PlayerState) -> Vector2:
	var moving := player.held_vel if player.is_frozen() else player.vel
	return Vector2(moving.x, moving.z)


## Puts [param seat] afloat in the sea at [param pos]'s x/z, at rest — its feet
## swim_depth under the sea there — looking [param facing_deg] from the bow toward
## starboard.
static func swim(match_sim: MatchSim, seat: int, pos: Vector3, facing_deg: float = 0.0) -> void:
	place(match_sim, seat, pos, facing_deg)
	var player := match_sim.state.seats[seat]
	var sea := match_sim.pose().sea_height(pos.x, pos.z)
	player.pos.y = sea - match_sim.config.rules.swim_depth
	player.body = PlayerState.Body.SWIMMING
	player.surface = Surfaces.NONE


## The flat deck standing [param freeboard] out of the sea, within a swimmer's reach
## when that is low.
static func low_deck(freeboard: float) -> ShipLayout:
	var layout: ShipLayout = deck().duplicate()
	layout.freeboard = freeboard
	return layout


## A frame looking [param look_deg] from the bow toward starboard; without one,
## step() keeps the seat looking where it does — where place() turned it, say.
static func frame(
	seat: int, move: Vector2 = Vector2.ZERO, buttons: int = 0, look_deg: float = NAN
) -> InputFrame:
	var look := KEEP_LOOK if is_nan(look_deg) else InputFrame.quantize_yaw(deg_to_rad(look_deg))
	return InputFrame.new(seat, 0, InputFrame.quantize(move), buttons, look)


## Steps [param ticks] ticks; [param frames] maps a seat to the frame it sends
## every one of them, and the others repeat their last.
static func step(match_sim: MatchSim, frames: Dictionary = {}, ticks: int = 1) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for _tick in ticks:
		var row: Array[InputFrame] = []
		row.resize(match_sim.config.seats)
		for seat: int in frames:
			var sent: InputFrame = frames[seat]
			if sent.look_yaw == KEEP_LOOK:
				var look := match_sim.state.seats[seat].last_look
				sent = InputFrame.new(seat, 0, sent.move, sent.buttons, look)
			row[seat] = sent
		events.append_array(match_sim.step(row))
	return events
