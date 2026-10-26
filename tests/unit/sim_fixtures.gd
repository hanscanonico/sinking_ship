class_name SimFixtures
extends RefCounted
## Shared setup for the sim's suites: the shipped data, hand-made scenarios, and
## matches with bodies placed by hand.

const RULES := "res://data/rules/brawl.tres"
const FLAT_DECK := "res://data/ships/flat_deck.tres"
const FLAT_SINKING := "res://tests/fixtures/sinking/flat.tres"
const STEAMER := "res://data/ships/steamer.tres"
## The steamer's sinking a match plays: the physics, from a drawn hit.
const STEAMER_SINKING := "res://data/sinking/steamer_open_sea.tres"
## The script SH6 sank her on, kept as a fixture for the mechanics it exercises —
## lurches, collapses, slides — which the physics does not yet make (§5b.4).
const STEAMER_SCRIPT := "res://tests/fixtures/sinking/steamer.tres"
const NORMAL_BOT := "res://data/bots/normal.tres"
## A frame's look when none is given: step() sends the seat's own look instead.
const KEEP_LOOK := -1
const DOUBLE_LIFE := "res://data/bonuses/double_life.tres"
## Where below_decks' holds start aft, how long each is, and how far under the main deck
## their floors stand: under the deck, over the sea a freeboard down.
const HOLD_AFT := -12.0
const HOLD_LENGTH := 5.0
const HOLD_FLOOR := -2.0

## The steamer's match hits on seeds 1, 2, …, as the must-sink rule chose them: worked
## out once for every suite that reads them (match_hits).
static var _match_hits: Array[MustSink.Choice] = []
## Those past the last match_hits has worked out, by seed: one asked alone.
static var _lone_hits: Dictionary[int, MustSink.Choice] = {}


## The steamer's match hits on seeds 1…[param count], as her matches choose them
## (MustSink) — bakes alone, no match played (§5b.4).
static func match_hits(count: int) -> Array[MustSink.Choice]:
	var scenario: SinkScenario = load(STEAMER_SINKING)
	var structure := steamer().structure
	var sea := SeaPhysics.load_default()
	while _match_hits.size() < count:
		var stream := SeedStreams.derive(_match_hits.size() + 1, "sink")
		_match_hits.append(MustSink.choose(structure, scenario, stream, sea))
	return _match_hits.slice(0, count)


## The steamer's match hit on seed [param seed_value], as match_hits has it — worked out
## alone, not with every seed before it, where match_hits has not reached it.
static func match_hit(seed_value: int) -> MustSink.Choice:
	if seed_value <= _match_hits.size():
		return _match_hits[seed_value - 1]
	if not _lone_hits.has(seed_value):
		var scenario: SinkScenario = load(STEAMER_SINKING)
		var stream := SeedStreams.derive(seed_value, "sink")
		_lone_hits[seed_value] = MustSink.choose(
			steamer().structure, scenario, stream, SeaPhysics.load_default()
		)
	return _lone_hits[seed_value]


## The explicit hit on the steamer's [param side] side from [param from] to [param to]
## along her, [param depth] under her waterline, [param width] as one even slit, biting
## [param bite] in, with the doors [param jammed] and the openings [param left_open].
static func explicit_hit(
	side: int,
	from: float,
	to: float,
	depth: float,
	width: float,
	bite: float,
	jammed: Array[StringName] = [],
	left_open: Array[StringName] = []
) -> IcebergHit:
	var hit := IcebergHit.new()
	hit.side = side
	hit.start_x = from
	hit.length = to - from
	hit.depth_start = depth
	hit.depth_end = depth
	hit.width = width
	hit.bite = bite
	hit.jammed = jammed
	hit.left_open = left_open
	return hit


## The bake of explicit [param hit] on the steamer, its area scaled by [param scale].
static func bake(hit: IcebergHit, scale: float = 1.0) -> SinkTimeline:
	var struck: IcebergHit = hit.duplicate()
	struck.width = hit.width * scale
	var structure := steamer().structure
	var scenario: SinkScenario = load(STEAMER_SINKING)
	var sea := SeaPhysics.load_default()
	var damage := HitMapper.map_explicit(struck, structure, scenario.hit)
	return SinkTimeline.bake(SinkStepper.new(structure, damage, sea), sea, scenario.bake_cap)


## The sea's constants with the physics held to a step of [param seconds].
static func held_at(seconds: float) -> SeaPhysics:
	var held: SeaPhysics = SeaPhysics.load_default().duplicate()
	held.step_min = seconds
	held.step_max = seconds
	return held


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


## A crate as the steamer carries them, its underside at [param at].
static func crate(at: Vector3) -> ShipProp:
	var made: ShipProp = steamer().props[0].duplicate()
	made.pos = at
	return made


## A lifebuoy (#273) at [param at] — its underside on the deck, or, hung on the railing
## span [param railing], the point of the span it hangs from at its deck's height — of
## its kind's size, as the ships carry them.
static func lifebuoy(at: Vector3, railing := -1) -> ShipProp:
	var kind := PropKind.named(&"lifebuoy")
	var made := ShipProp.new()
	made.kind = &"lifebuoy"
	made.railing = railing
	made.pos = at
	made.radius = kind.radius
	made.height = kind.height
	made.mass = 2.5
	made.grip_angle_deg = 20.0
	made.friction = 3.0
	return made


## [param layout] — the flat deck, when none is given — carrying [param crates] and
## no other.
## A dining table (data/props/dining_table.tres) or chair, facing [param facing_deg],
## standing at [param at], of its kind's size and the mass, grip and friction her saloons'
## carry (tools/gen_titanic.py).
static func table(at: Vector3) -> ShipProp:
	return _furniture(&"dining_table", at, 45.0, 22.0, 7.0)


static func chair(at: Vector3, facing_deg := 0.0) -> ShipProp:
	var made := _furniture(&"dining_chair", at, 6.0, 20.0, 6.5)
	made.facing_deg = facing_deg
	return made


static func _furniture(
	kind_name: StringName, at: Vector3, mass: float, grip_deg: float, friction: float
) -> ShipProp:
	var kind := PropKind.named(kind_name)
	var made := ShipProp.new()
	made.kind = kind_name
	made.pos = at
	made.radius = kind.radius
	made.height = kind.height
	made.mass = mass
	made.grip_angle_deg = grip_deg
	made.friction = friction
	return made


static func crated(crates: Array[ShipProp], layout: ShipLayout = null) -> ShipLayout:
	var loaded: ShipLayout = (layout if layout != null else deck()).duplicate()
	loaded.props = crates
	return loaded


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


## [param scenario] with [param events].
static func with_events(scenario: SinkScenario, events: Array[SinkEvent]) -> SinkScenario:
	scenario.events = events
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


## A ship that never moves, her sinking over at [param seconds]: a plan of bonuses
## (BonusPlan) runs until then.
static func calm_until(seconds: float) -> SinkScenario:
	return scenario([[0.0, 0.0, 0.0, 0.0], [seconds, 0.0, 0.0, 0.0]])


## A sinking that floods below_decks' holds (#311): settling on an even keel from the start,
## the sea level with their floors [param floods] seconds in — still dry — and over them
## from the next tick on, a metre deep a second later and so until 600 s.
static func flooding(floods: float) -> SinkScenario:
	var floors := deck().freeboard + HOLD_FLOOR
	return scenario(
		[
			[0.0, 0.0, 0.0, 0.0],
			[floods, floors, 0.0, 0.0],
			[floods + 1.0, floors + 1.0, 0.0, 0.0],
			[600.0, floors + 1.0, 0.0, 0.0],
		]
	)


## The flat deck with [param holds] holds under it (#307): rooms below her main deck,
## HOLD_FLOOR down, side by side aft to fore from the deck's after end, HOLD_LENGTH long
## and a gap apart, each its own floor and one bonus spot in its middle — where hold i's
## spot is, hold_spot(i).
static func below_decks(holds := 1) -> ShipLayout:
	var layout: ShipLayout = deck().duplicate()
	var platforms := layout.platforms.duplicate()
	var rooms: Array[ShipRoom] = []
	var spots: Array[ShipBonusSpot] = []
	for index in holds:
		var bottom := ShipPlatform.new()
		bottom.name = &"hold"
		bottom.area = Rect2(HOLD_AFT + index * (HOLD_LENGTH + 1.0), -3.0, HOLD_LENGTH, 6.0)
		bottom.height = HOLD_FLOOR
		platforms.append(bottom)
		var hold := ShipRoom.new()
		hold.name = &"hold"
		hold.area = bottom.area
		hold.floor_height = HOLD_FLOOR
		rooms.append(hold)
		var spot := ShipBonusSpot.new()
		spot.point = hold_spot(index)
		spot.room = index
		spots.append(spot)
	layout.platforms = platforms
	layout.rooms = rooms
	layout.bonus_spots = spots
	return layout


## Where below_decks' hold [param index] has its bonus spot: the middle of its floor.
static func hold_spot(index: int) -> Vector3:
	return Vector3(HOLD_AFT + index * (HOLD_LENGTH + 1.0) + HOLD_LENGTH * 0.5, HOLD_FLOOR, 0.0)


## Where a body stands to take the bonus at below_decks' hold [param index]'s spot: aft of
## it, its edge within grab reach of the bonus's facing the bow (0°).
static func by_hold_spot(index := 0) -> Vector3:
	return hold_spot(index) - Vector3(0.9, 0.0, 0.0)


## Bonus rules (#307) of [param kinds] — Double life alone when none are given, every one
## as likely — the first coming [param first] seconds in, then every [param interval]
## give or take [param jitter], at most [param most] aboard at once.
static func bonus_rules(
	first := 1.0, interval := 45.0, jitter := 0.0, most := 2, kinds: Array[BonusKind] = []
) -> BonusRules:
	var made := BonusRules.new()
	var playing: Array[BonusKind] = [double_life()]
	if not kinds.is_empty():
		playing = kinds
	made.kinds = playing
	made.odds.resize(made.kinds.size())
	made.odds.fill(1.0)
	made.first = first
	made.interval = interval
	made.jitter = jitter
	made.most_aboard = most
	return made


## A copy of [param rules] and of each of their kinds, for a test to change without
## changing the loaded data every other test reads.
static func bonus_rules_copy(rules: BonusRules) -> BonusRules:
	var copy: BonusRules = rules.duplicate()
	var kinds: Array[BonusKind] = []
	for kind: BonusKind in rules.kinds:
		kinds.append(kind.duplicate())
	copy.kinds = kinds
	return copy


static func double_life() -> BonusKind:
	return load(DOUBLE_LIFE)


## A kind of bonus of Double life's size that gives nothing: a test's second kind.
static func plain_kind() -> BonusKind:
	var made := BonusKind.new()
	made.title = "Plain"
	made.radius = double_life().radius
	made.height = double_life().height
	return made


## A match of [param seats] on [param layout] — below_decks' one hold when none is given —
## played with [param rules], sunk as [param sinking] has her: calm until 600 s when none
## is given.
static func bonus_sim(
	rules: BonusRules, seats := 1, layout: ShipLayout = null, sinking: SinkScenario = null
) -> MatchSim:
	var made := config(
		seats,
		sinking if sinking != null else calm_until(600.0),
		1,
		layout if layout != null else below_decks()
	)
	made.bonus_rules = rules
	return MatchSim.create(made)


## A bonus of [param kind] — by its index among the match's bonus rules' kinds — lying at
## bonus spot [param spot], as the plan would bring it aboard: of none of the plan's.
static func bring_aboard(match_sim: MatchSim, spot: int, kind := 0) -> void:
	match_sim.state.bonuses.append(BonusState.new(-1, kind, spot))


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


## A pose of the test's own holding [param pose]'s values, for a test to change: the
## schedule's poses are shared and nobody changes them (ShipPose). Its doors, failures,
## falls and collapses are its own lists; a piece's pose is the one it was handed.
static func copy_of(pose: ShipPose) -> ShipPose:
	var made := ShipPose.new(pose.sink, pose.trim_deg, pose.heel_deg, pose.transform)
	made.levels = pose.levels
	made.pockets = pose.pockets
	made.cells = pose.cells
	made.lit = pose.lit
	made.doors_shut = pose.doors_shut.duplicate()
	made.opened = pose.opened.duplicate()
	made.falls = pose.falls.duplicate()
	made.felled = pose.felled.duplicate()
	made.collapsed = pose.collapsed.duplicate()
	made.collapsing = pose.collapsing.duplicate()
	made.broken_railings = pose.broken_railings
	made.lurch_warning = pose.lurch_warning
	made.lurch = pose.lurch
	for piece: ShipPose in pose.pieces:
		made.pieces.append(made if piece == pose else piece)
	made.standing = pose.standing
	return made


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


## Puts prop [param prop] in [param seat]'s hands, as a Grab press would (#273).
static func hand(match_sim: MatchSim, seat: int, prop: int) -> void:
	var held := match_sim.state.props[prop]
	held.body = PropState.Body.HELD
	held.holder = seat
	held.pos = match_sim.state.seats[seat].pos
	held.vel = Vector3.ZERO
	held.surface = Surfaces.NONE


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
	var sea := match_sim.pose().water_height(pos)
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
