class_name MatchSim
extends RefCounted
## The match, as a Node-free fixed-tick simulation (D1, D2). step() with one
## InputFrame per seat is the only way anything happens (D3); snapshot() is the
## whole truth and from_snapshot() continues it exactly (D5).

const SNAPSHOT_VERSION := 8
## How many times a tick's contacts are resolved, at most. In one pass each contact
## is met where the body stood before it, so a body pushed two ways — into a corner,
## between a doorway's jambs, against a wall by a crowd — can end inside one wall or
## slip through a gap narrower than itself. Four passes settle a body wedged between
## two walls and another body; they stop as soon as nothing moves.
const CONTACT_PASSES := 4

var config: MatchConfig
var schedule: SinkSchedule
var surfaces: Surfaces
var state: MatchState

var _rules: BrawlRules
var _hazards: Hazards
var _windup_ticks: int
var _active_ticks: int
var _recovery_ticks: int
var _stagger_ticks: int
var _charge_threshold_ticks: int
var _charge_full_ticks: int
var _regen_delay_ticks: int
var _hitstop_ticks: int
var _hitstop_charged_ticks: int
var _hitstop_braced_ticks: int
var _climb_ticks: int
var _credit_window_ticks: int


func _init(match_config: MatchConfig) -> void:
	config = match_config
	_rules = config.rules
	schedule = SinkSchedule.for_match(config)
	surfaces = Surfaces.new(config.ship)
	_hazards = Hazards.new(config, surfaces)
	_windup_ticks = Ticks.from_seconds(_rules.shove_windup)
	_active_ticks = Ticks.from_seconds(_rules.shove_active)
	_recovery_ticks = Ticks.from_seconds(_rules.shove_recovery)
	_stagger_ticks = Ticks.from_seconds(_rules.stagger)
	_charge_threshold_ticks = Ticks.from_seconds(_rules.charge_threshold)
	_charge_full_ticks = Ticks.from_seconds(_rules.charge_full)
	_regen_delay_ticks = Ticks.from_seconds(_rules.stamina_regen_delay)
	_hitstop_ticks = Ticks.from_seconds(_rules.hitstop)
	_hitstop_charged_ticks = Ticks.from_seconds(_rules.hitstop_charged)
	_hitstop_braced_ticks = Ticks.from_seconds(_rules.hitstop_braced)
	_climb_ticks = Ticks.from_seconds(_rules.climb_time)
	_credit_window_ticks = Ticks.from_seconds(_rules.credit_window)


## A new match: seats shuffled onto the layout's spawns by the match stream, each
## facing amidships.
static func create(match_config: MatchConfig) -> MatchSim:
	var sim := MatchSim.new(match_config)
	var match_state := MatchState.new()
	match_state.match_seed = match_config.match_seed
	match_state.rng = SeedStreams.derive(match_config.match_seed, "match")
	match_state.phase = (
		MatchState.Phase.COUNTDOWN if match_config.countdown_ticks > 0 else MatchState.Phase.LIVE
	)
	var spawns := match_config.ship.spawns
	var order := range(spawns.size())
	for index in range(order.size() - 1, 0, -1):
		var other := match_state.rng.randi_range(0, index)
		var swap: int = order[index]
		order[index] = order[other]
		order[other] = swap
	for seat in match_config.seats:
		var player := PlayerState.new(seat)
		player.pos = spawns[order[seat]]
		player.last_look = InputFrame.quantize_yaw(Vector2(-player.pos.x, -player.pos.z).angle())
		player.facing = InputFrame.yaw_angle(player.last_look)
		player.surface = sim.surfaces.under(player.pos, match_config.rules.step_height)
		player.stamina = match_config.rules.stamina_max
		player.cold = match_config.rules.cold_meter
		match_state.seats.append(player)
	match_state.props = PropState.from_layout(match_config.ship)
	match_state.railing_hp.resize(match_config.ship.railings.size())
	match_state.railing_hp.fill(match_config.rules.railing_hp)
	sim.state = match_state
	return sim


## The match continued from [param snapshot], which [param match_config] started.
static func from_snapshot(snapshot: Dictionary, match_config: MatchConfig) -> MatchSim:
	var sim := MatchSim.new(match_config)
	sim.restore(snapshot)
	return sim


## Resets this match to [param snapshot], one of its own: what from_snapshot continues
## from, without building the ship again — a client predicting does it every snapshot.
func restore(snapshot: Dictionary) -> void:
	assert(snapshot["v"] == SNAPSHOT_VERSION, "snapshot version %s" % snapshot["v"])
	var match_state := MatchState.new()
	match_state.tick = snapshot["tick"]
	match_state.phase = snapshot["phase"]
	match_state.match_seed = snapshot["seed"]
	match_state.rng = SeedStreams.derive(match_state.match_seed, "match")
	match_state.rng.state = snapshot["rng"]
	for entry: Dictionary in snapshot["seats"]:
		match_state.seats.append(PlayerState.from_dict(entry))
	match_state.props = PropState.from_snapshot(snapshot)
	match_state.railing_hp = (snapshot["railing_hp"] as PackedFloat64Array).duplicate()
	state = match_state
	surfaces.honour(pose(), match_state.broken_railings(), match_state.props)


func snapshot() -> Dictionary:
	return state.to_dict(SNAPSHOT_VERSION)


## The ship's pose now, as SinkSchedule answers it for this match.
func pose() -> ShipPose:
	return schedule.pose_at(state.tick)


func is_over() -> bool:
	return state.phase == MatchState.Phase.ENDED


## One tick, in the fixed order of §4. [param frames] is indexed by seat; a
## missing (null) frame repeats that seat's last one.
func step(frames: Array[InputFrame]) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	state.events = events
	if is_over():
		return events
	var tick := state.tick
	# Nobody goes out before _water: one list of the seats still in serves until then.
	var live := _live_seats()
	_take_frames(frames, tick, live)
	var pose_now := schedule.pose_at(tick)
	_sinking_events(pose_now, tick, events)
	if tick < config.countdown_ticks:
		for player: PlayerState in state.seats:
			player.prev_buttons = player.last_buttons
	else:
		_intent(live, pose_now)
		_brace_and_stamina(live)
		_forces(live, pose_now)
		var feet_before := _move(live, pose_now, tick, events)
		_ground(live, tick, events, feet_before)
		_thaw(live)
		_hazards.step(state, pose_now, tick, events)
		_shoves(live, tick, events)
		var exits := _water(live, pose_now, tick, events, feet_before)
		_sea_settles(pose_now, tick, exits)
		_verdict(exits, tick, events)
	state.tick += 1
	if state.phase == MatchState.Phase.COUNTDOWN and state.tick >= config.countdown_ticks:
		state.phase = MatchState.Phase.LIVE
	return events


## The ship stands as the pose says from this tick on — a collapsed platform is no
## surface — with the railings the match has broken and its crates where they are,
## and the sinking's telegraphs and events for this tick go out.
func _sinking_events(pose_now: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	surfaces.honour(pose_now, state.broken_railings(), state.props)
	events.append_array(schedule.events_at(tick))


func _live_seats() -> Array[PlayerState]:
	var live: Array[PlayerState] = []
	for player: PlayerState in state.seats:
		if not player.is_out():
			live.append(player)
	return live


## The seats of [param live] that move as bodies do: all but the climbers.
func _moving_seats(live: Array[PlayerState]) -> Array[PlayerState]:
	var moving: Array[PlayerState] = []
	for player: PlayerState in live:
		if not player.is_climbing():
			moving.append(player)
	return moving


func _take_frames(frames: Array[InputFrame], tick: int, live: Array[PlayerState]) -> void:
	for player: PlayerState in live:
		var frame: InputFrame = frames[player.seat] if player.seat < frames.size() else null
		if frame == null:
			continue
		var valid := frame.validated(player.seat, tick)
		player.last_move = valid.move
		player.last_look = valid.look_yaw
		player.last_buttons = valid.buttons
		# A seat's facing is its look, by any amount, every tick (D14).
		player.facing = InputFrame.yaw_angle(valid.look_yaw)


## Button edges and shove phases. A seat frozen in a hit-stop advances nothing,
## its button edges included: the first tick after the stop reads its buttons
## against those it held before it, so a press made in the stop and still held
## counts then, and one let go inside the stop never happened.
func _intent(live: Array[PlayerState], pose_now: ShipPose) -> void:
	for player: PlayerState in live:
		if player.is_frozen():
			continue
		# A stagger — a hit's, or a hard landing's — takes the shove being readied,
		# and its buttons are not read (D3). A charge is paid on release, so nothing
		# was spent and nothing comes back.
		var readying := (
			player.action == PlayerState.Action.WINDUP or player.action == PlayerState.Action.CHARGE
		)
		if readying and player.is_staggered():
			_enter(player, PlayerState.Action.IDLE)
		if player.action != PlayerState.Action.IDLE:
			player.action_ticks += 1
			_advance_action(player, live)
		var pressed := player.last_buttons & ~player.prev_buttons
		player.prev_buttons = player.last_buttons
		if player.is_staggered():
			continue
		if (
			pressed & InputFrame.SHOVE
			and player.action == PlayerState.Action.IDLE
			and player.body == PlayerState.Body.GROUNDED
		):
			player.action = PlayerState.Action.WINDUP
			player.action_ticks = 0
			player.shove_spent = false
		if pressed & InputFrame.JUMP:
			_jump(player, pose_now)


## A jump is a press, never a hold, from the ground: idle, its brace let go, and
## with jump_cost of stamina to spend. It rises jump_height above where it left in
## ship space, whatever the deck's tilt — never over a railing — and gravity, the
## world's turned by the pose, brings it down, pulling it downhill as it falls.
func _jump(player: PlayerState, pose_now: ShipPose) -> void:
	if (
		player.body != PlayerState.Body.GROUNDED
		or player.action != PlayerState.Action.IDLE
		or player.last_buttons & InputFrame.BRACE
		or player.exhausted
		or player.stamina < _rules.jump_cost
	):
		return
	_spend(player, _rules.jump_cost)
	# The take-off speed whose apex, stepped tick by tick as _forces and _move step
	# it, is jump_height: v² − g·dt·v − 2·g·h = 0.
	var fall := -pose_now.ship_gravity(_rules.gravity).y
	var drop := fall * Ticks.SECONDS_PER_TICK
	player.vel.y = (drop + sqrt(drop * drop + 8.0 * fall * _rules.jump_height)) * 0.5
	player.body = PlayerState.Body.AIRBORNE
	player.surface = Surfaces.NONE
	player.fall_from = player.pos.y
	player.jumped = true


## Tap or hold is read here, from ticks held (D3): a shove released after its
## windup fires as a quick shove; one still held at charge_threshold becomes a
## charge, which fires, paid for, when it is let go.
func _advance_action(player: PlayerState, live: Array[PlayerState]) -> void:
	var held := player.last_buttons & InputFrame.SHOVE != 0
	match player.action:
		PlayerState.Action.WINDUP:
			if held and player.action_ticks >= _charge_threshold_ticks:
				if player.exhausted or player.stamina < _rules.charge_cost:
					_fire(player, live)
				else:
					player.charge = player.action_ticks
					_enter(player, PlayerState.Action.CHARGE)
			elif not held and player.action_ticks >= _windup_ticks:
				_fire(player, live)
		PlayerState.Action.CHARGE:
			player.charge = mini(player.charge + 1, _charge_full_ticks)
			if not held:
				_spend(player, _rules.charge_cost)
				_fire(player, live)
		PlayerState.Action.ACTIVE:
			if player.action_ticks >= _active_ticks:
				_enter(player, PlayerState.Action.RECOVERY)
		PlayerState.Action.RECOVERY:
			if player.action_ticks >= _recovery_ticks:
				_enter(player, PlayerState.Action.IDLE)


## A charge lasts until its shove's active window is over, or it is cut short.
func _enter(player: PlayerState, action: PlayerState.Action) -> void:
	player.action = action
	player.action_ticks = 0
	if action == PlayerState.Action.IDLE or action == PlayerState.Action.RECOVERY:
		player.charge = 0


## Every shove's active window starts here, quick or charged: it goes where its
## shover looks now, bent toward the nearest target the autoaim cone holds among
## [param live] — the shove, never the view (D14).
func _fire(player: PlayerState, live: Array[PlayerState]) -> void:
	_enter(player, PlayerState.Action.ACTIVE)
	player.shove_facing = ShoveResolver.autoaim(
		_candidate(player),
		player.facing,
		_candidates(live),
		_rules.shove_reach,
		_rules.autoaim_cone_deg,
		surfaces,
		_rules.step_height
	)


## Who is braced this tick, and stamina: a brace holds while its button is, on the
## ground, idle, unstaggered and not exhausted, and spends as it holds; after
## stamina_regen_delay without spending, stamina comes back. A hit-stop holds a
## seat's brace and stamina as they are.
func _brace_and_stamina(live: Array[PlayerState]) -> void:
	for player: PlayerState in live:
		if player.is_frozen():
			continue
		player.bracing = (
			player.last_buttons & InputFrame.BRACE != 0
			and player.action == PlayerState.Action.IDLE
			and player.body == PlayerState.Body.GROUNDED
			and not player.is_staggered()
			and not player.exhausted
		)
		if player.bracing:
			_spend(player, _rules.brace_drain * Ticks.SECONDS_PER_TICK)
			player.bracing = not player.exhausted
		elif player.stamina_wait > 0:
			player.stamina_wait -= 1
		else:
			player.stamina = minf(
				player.stamina + _rules.stamina_regen * Ticks.SECONDS_PER_TICK, _rules.stamina_max
			)
			if player.stamina == _rules.stamina_max:
				player.exhausted = false


## Takes [param amount] of stamina, never below zero — run dry, the seat is
## exhausted — and restarts the wait before it comes back.
func _spend(player: PlayerState, amount: float) -> void:
	player.stamina = maxf(player.stamina - amount, 0.0)
	player.stamina_wait = _regen_delay_ticks
	if player.stamina == 0.0:
		player.exhausted = true


## Walking, friction and gravity, as velocity. Gravity is the world's, turned
## into ship space by the pose; a grounded body feels its downhill part only once
## it has lost its grip — staggered, or idle on a deck steeper than the grip angle.
## Wading slows a walk; swimming is _swim's. A body frozen in a hit-stop feels none
## of it, and its stagger waits.
func _forces(live: Array[PlayerState], pose_now: ShipPose) -> void:
	var dt := Ticks.SECONDS_PER_TICK
	var gravity := pose_now.ship_gravity(_rules.gravity)
	var downhill := Vector2(gravity.x, gravity.z) * dt
	var steep := pose_now.slope_deg() > _rules.grip_angle_deg
	for player: PlayerState in live:
		if player.is_frozen():
			continue
		if player.body == PlayerState.Body.AIRBORNE:
			player.vel += gravity * dt
			_steer_in_air(player)
			continue
		if player.body == PlayerState.Body.SWIMMING:
			_swim(player, pose_now)
			continue
		var planar := Vector2(player.vel.x, player.vel.z)
		var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.walk_speed
		if player.action == PlayerState.Action.CHARGE:
			wish = wish.limit_length(_rules.charge_walk)
		elif player.bracing:
			wish = Vector2.ZERO
		if surfaces.wet(player.pos, pose_now):
			wish = wish.limit_length(_rules.wade_speed)
		# A brace is rooted: the deck past the grip angle does not pull it.
		var pulled := steep and not player.bracing
		if player.is_staggered():
			planar = (planar + downhill).move_toward(Vector2.ZERO, _rules.stagger_friction * dt)
			player.stagger_ticks -= 1
		elif wish == Vector2.ZERO and pulled:
			planar = (planar + downhill).move_toward(Vector2.ZERO, _rules.slide_friction * dt)
		else:
			if pulled:
				planar += downhill
			var rate := _rules.ground_accel if wish != Vector2.ZERO else _rules.ground_friction
			planar = planar.move_toward(wish, rate * dt)
			# The shove is spent once the body moves as its own input says; until then
			# a slide that outlasts the stagger is still the shover's.
			if planar == wish:
				player.forget_hit()
		player.vel = Vector3(planar.x, player.vel.y, planar.y)


## A jumper steers toward its input at air_control of ground_accel, and keeps its
## speed when it gives none; a fall, a vault or a jumper staggered by a shove flies
## where it was sent.
func _steer_in_air(player: PlayerState) -> void:
	if not player.jumped or player.is_staggered() or player.last_move == Vector2i.ZERO:
		return
	var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.walk_speed
	var rate := _rules.ground_accel * _rules.air_control * Ticks.SECONDS_PER_TICK
	var planar := Vector2(player.vel.x, player.vel.z).move_toward(wish, rate)
	player.vel = Vector3(planar.x, player.vel.y, planar.y)


## Integration, then contacts: blockers, then railings, then bodies pushing each
## other apart pair by pair in seat order, pass after pass until nothing moves.
## Walls and rails have the last word — the last pass stops before bodies push — so
## a crowd may end a tick pressed together, never inside a wall. A climber is where
## its climb has it, and takes no part. Returns each seat's feet height before it
## moved.
func _move(
	live_seats: Array[PlayerState], pose_now: ShipPose, tick: int, events: Array[SimEvent]
) -> PackedFloat64Array:
	var live := _moving_seats(live_seats)
	var feet_before := PackedFloat64Array()
	feet_before.resize(state.seats.size())
	var came_from := PackedVector2Array()
	came_from.resize(state.seats.size())
	# A body that would cross more than its own radius in one move could land past a
	# thin wall's middle and be pushed out of its far side — two shovers on one
	# staggered body reach twice the restagger knockback, two-thirds of a metre a tick.
	# So the tick's move is cut into as many equal steps as the fastest body needs to
	# cross at most its radius in each, every step met by the contacts; at walking and
	# single-shove speeds it is one step, the move exactly as it always was.
	var steps := 1
	for player: PlayerState in live:
		feet_before[player.seat] = player.pos.y
		came_from[player.seat] = Vector2(player.pos.x, player.pos.z)
		var reach := Vector2(player.vel.x, player.vel.z).length() * Ticks.SECONDS_PER_TICK
		steps = maxi(steps, ceili(reach / _rules.body_radius))
	var dt := Ticks.SECONDS_PER_TICK / steps
	# Where each body last met no blocker, and no railing: nothing that holds a body
	# moves while bodies do, and a railing only breaks, so a body still there meets
	# nothing again and is not asked.
	var clear_of_blockers: Dictionary[int, Vector3] = {}
	var clear_of_railings: Dictionary[int, Vector3] = {}
	for _step in steps:
		for player: PlayerState in live:
			player.pos += player.vel * dt
		for contact_pass in CONTACT_PASSES:
			var held := _blockers(live, feet_before, pose_now, clear_of_blockers)
			held = _railings(live, pose_now, tick, events, came_from, clear_of_railings) or held
			if contact_pass == CONTACT_PASSES - 1:
				break
			if not _bodies(live) and not held:
				break
	_ceilings(live, feet_before)
	return feet_before


## A rising body stops with its head against the lowest underside over it — a deck,
## a stair, a lintel — and loses its upward speed. It is looked for from where the
## feet stood before this tick's move, so a fast rise cannot pass through a deck.
func _ceilings(live: Array[PlayerState], feet_before: PackedFloat64Array) -> void:
	for player: PlayerState in live:
		if player.body != PlayerState.Body.AIRBORNE or player.vel.y <= 0.0:
			continue
		var feet := Vector3(player.pos.x, feet_before[player.seat], player.pos.z)
		var highest := surfaces.ceiling(feet, _rules.step_height) - _rules.body_height
		if player.pos.y > highest:
			player.pos.y = highest
			player.vel.y = 0.0


## Whatever stops a body — a blocker, a wall, a deck edge too high to step onto —
## pushes it back out in the deck plane and takes the velocity into it. It is met at
## the height the feet stood at before this tick's move, so a fall lands on a deck
## in _ground rather than being pushed off its edge. A swimmer steps as a swimmer
## does (_swim_step). A body still where [param clear] last found it held by nothing
## is not asked again. True when it moved anyone.
func _blockers(
	live: Array[PlayerState],
	feet_before: PackedFloat64Array,
	pose_now: ShipPose,
	clear: Dictionary[int, Vector3]
) -> bool:
	var moved := false
	for player: PlayerState in live:
		if clear.get(player.seat) == player.pos:
			continue
		var feet := Vector3(player.pos.x, feet_before[player.seat], player.pos.z)
		var step := _rules.step_height
		if player.body == PlayerState.Body.SWIMMING:
			step = _swim_step(feet, pose_now.sea_height(feet.x, feet.z))
		var contacts := surfaces.obstacle_contacts(
			feet, _rules.body_radius, _rules.body_height, step
		)
		if contacts.is_empty():
			clear[player.seat] = player.pos
		for contact: Surfaces.Contact in contacts:
			_hold(player, contact)
			moved = true
	return moved


## A railing stops a grounded body crossing it slower than vault_speed — it loses
## the velocity into the rail — and tips one at or above it over, into the air,
## damaging the span by vault_damage (Hazards.damage). In the air, a body that came
## from a rail's side with its feet below the rail's top is held the same way, unless
## it crosses at vault_speed or more: a vaulter is never pulled back. A body still
## where [param clear] last found it held by none is not asked again. True when it
## moved anyone.
func _railings(
	live: Array[PlayerState],
	pose_now: ShipPose,
	tick: int,
	events: Array[SimEvent],
	came_from: PackedVector2Array,
	clear: Dictionary[int, Vector3]
) -> bool:
	var moved := false
	for player: PlayerState in live:
		if clear.get(player.seat) == player.pos:
			continue
		var airborne := player.body == PlayerState.Body.AIRBORNE
		var contacts: Array[Surfaces.Contact]
		if airborne:
			contacts = surfaces.airborne_rail_contacts(
				player.pos,
				came_from[player.seat],
				_rules.body_radius,
				_rules.body_height,
				_rules.railing_height
			)
		elif player.body == PlayerState.Body.GROUNDED:
			contacts = surfaces.rail_contacts(player.pos, _rules.body_radius, player.surface)
		if contacts.is_empty():
			clear[player.seat] = player.pos
		for contact: Surfaces.Contact in contacts:
			var planar := Vector2(player.vel.x, player.vel.z)
			var into := -planar.dot(contact.normal)
			if into >= _rules.vault_speed:
				if airborne:
					continue
				player.body = PlayerState.Body.AIRBORNE
				player.surface = Surfaces.NONE
				player.fall_from = player.pos.y
				player.vel.y = _rules.vault_lift
				events.append(SimEvent.vaulted(tick, player.seat))
				_hazards.damage(
					state, contact.railing, _rules.vault_damage, pose_now, tick, events, player.seat
				)
				# In the air it meets other railings than on its feet: where it stood clear
				# before is no answer for it now.
				clear.erase(player.seat)
				break
			_hold(player, contact)
			moved = true
	return moved


## Bodies whose heights overlap push each other apart, pair by pair in seat order,
## each moving half the overlap. True when it moved anyone.
func _bodies(live: Array[PlayerState]) -> bool:
	var moved := false
	var reach := _rules.body_radius * 2.0
	var height := _rules.body_height
	for first in live.size():
		for second in range(first + 1, live.size()):
			var a := live[first]
			var b := live[second]
			var a_pos := a.pos
			var b_pos := b.pos
			if absf(a_pos.y - b_pos.y) >= height:
				continue
			var offset := Vector2(b_pos.x - a_pos.x, b_pos.z - a_pos.z)
			var distance := offset.length()
			if distance >= reach:
				continue
			var normal := offset / distance if distance > 0.0 else Vector2.RIGHT
			var push := normal * ((reach - distance) * 0.5)
			a.pos -= Vector3(push.x, 0.0, push.y)
			b.pos += Vector3(push.x, 0.0, push.y)
			moved = true
	return moved


## Moves [param player] out of [param contact] in the deck plane and takes the
## velocity into it.
func _hold(player: PlayerState, contact: Surfaces.Contact) -> void:
	player.pos += Vector3(contact.normal.x, 0.0, contact.normal.y) * contact.depth
	var planar := Vector2(player.vel.x, player.vel.z)
	var into := -planar.dot(contact.normal)
	if into > 0.0:
		planar += contact.normal * into
		player.vel = Vector3(planar.x, player.vel.y, planar.y)


## What each body stands on. A grounded body follows its surface up and down
## within step_height; past an edge deeper than that it falls. A falling body lands
## on the highest surface it comes down onto, staggered by the drop — a jump's by
## the drop below where it left, so its own height costs nothing. A swimmer's height
## is the water's (_water).
func _ground(
	live: Array[PlayerState], tick: int, events: Array[SimEvent], feet_before: PackedFloat64Array
) -> void:
	for player: PlayerState in live:
		if player.body == PlayerState.Body.SWIMMING:
			continue
		if player.body == PlayerState.Body.GROUNDED:
			var surface := surfaces.under(player.pos, _rules.step_height)
			player.surface = surface
			if surface == Surfaces.NONE:
				player.body = PlayerState.Body.AIRBORNE
				player.fall_from = player.pos.y
				events.append(SimEvent.fell(tick, player.seat))
				continue
			player.pos.y = surfaces.height_at(surface, player.pos)
			continue
		if not player.jumped:
			player.fall_from = maxf(player.fall_from, player.pos.y)
		if player.vel.y > 0.0:
			continue
		var below := surfaces.landing(Vector3(player.pos.x, feet_before[player.seat], player.pos.z))
		if below == Surfaces.NONE:
			continue
		var ground := surfaces.height_at(below, player.pos)
		if player.pos.y > ground:
			continue
		var drop := maxf(player.fall_from - ground, 0.0)
		var stagger := Ticks.from_seconds(drop * _rules.fall_stagger_per_m)
		player.body = PlayerState.Body.GROUNDED
		player.jumped = false
		player.surface = below
		player.pos.y = ground
		player.vel.y = 0.0
		player.stagger_ticks = maxi(player.stagger_ticks, stagger)
		events.append(SimEvent.landed(tick, player.seat, below, stagger))


## Counts every hit-stop down. One that runs out hands its body the velocity it
## held, to move with from the next tick.
func _thaw(live: Array[PlayerState]) -> void:
	for player: PlayerState in live:
		if not player.is_frozen():
			continue
		player.hitstop -= 1
		if not player.is_frozen():
			player.vel = player.held_vel
			player.held_vel = Vector3.ZERO


## Every active shove against the bodies and the crates as they stand now; all of
## this tick's hits apply together, so simultaneous shoves both land. A landed shove
## freezes its shover and its target for a hit-stop, and the knockback and the
## recoil wait for it to end; a crate takes its share of the knockback at once
## (Hazards.shove), and its shover rocks and stops as for a body.
func _shoves(live: Array[PlayerState], tick: int, events: Array[SimEvent]) -> void:
	var attempts: Array[ShoveResolver.Attempt] = []
	for player: PlayerState in live:
		if (
			player.action == PlayerState.Action.ACTIVE
			and not player.shove_spent
			and not player.is_staggered()
		):
			attempts.append(
				ShoveResolver.Attempt.new(
					player.seat,
					player.pos,
					_rules.body_radius,
					Vector2.from_angle(player.shove_facing)
				)
			)
	if attempts.is_empty():
		return
	var hits := ShoveResolver.resolve(
		attempts,
		_candidates(live),
		_rules.shove_reach,
		_rules.shove_cone_deg,
		surfaces,
		_rules.step_height
	)
	var count := state.seats.size()
	var knock := PackedVector2Array()
	knock.resize(count)
	var rock := PackedVector2Array()
	rock.resize(count)
	var hit_by := PackedInt32Array()
	hit_by.resize(count)
	hit_by.fill(-1)
	var landed := PackedByteArray()
	landed.resize(count)
	var staggers := PackedByteArray()
	staggers.resize(count)
	var stops := PackedInt32Array()
	stops.resize(count)
	for hit: ShoveResolver.Hit in hits:
		var target := state.seats[hit.target]
		var shover := state.seats[hit.shover]
		var speed := _knockback(shover)
		var stop := _hitstop(shover)
		if target.is_staggered():
			speed *= _rules.restagger_mult
		if _braced_against(target, shover, hit.direction):
			speed *= 1.0 - _rules.brace_reduction
			stop = _hitstop_braced_ticks
		else:
			staggers[hit.target] = 1
		knock[hit.target] += hit.direction * speed
		# Every hit of one shove shares its direction: one shove landing on two
		# bodies rocks its shover back once.
		rock[hit.shover] = -hit.direction * _rules.recoil
		landed[hit.shover] = 1
		stops[hit.target] = maxi(stops[hit.target], stop)
		stops[hit.shover] = maxi(stops[hit.shover], stop)
		events.append(SimEvent.shove_landed(tick, hit.shover, hit.target))
		if hit_by[hit.target] == -1:
			hit_by[hit.target] = hit.shover
	var crate_hits := ShoveResolver.resolve(
		attempts,
		_hazards.candidates(state, count),
		_rules.shove_reach,
		_rules.shove_cone_deg,
		surfaces,
		_rules.step_height
	)
	for hit: ShoveResolver.Hit in crate_hits:
		var shover := state.seats[hit.shover]
		_hazards.shove(state, hit, count, _knockback(shover), tick)
		rock[hit.shover] = -hit.direction * _rules.recoil
		landed[hit.shover] = 1
		stops[hit.shover] = maxi(stops[hit.shover], _hitstop(shover))
	for player: PlayerState in live:
		var seat := player.seat
		if hit_by[seat] == -1 and landed[seat] == 0:
			continue
		if landed[seat] == 1:
			player.shove_spent = true
		var moving := player.held_vel if player.is_frozen() else player.vel
		var planar := Vector2(moving.x, moving.z)
		if hit_by[seat] != -1:
			planar = knock[seat] + rock[seat]
			player.last_hit_by = hit_by[seat]
			player.last_hit_crate = -1
			player.last_hit_at = tick
			if player.is_climbing():
				_knock_back_in(player, tick, events)
			if staggers[seat] == 1:
				player.stagger_ticks = _stagger_ticks
				player.bracing = false
				_enter(player, PlayerState.Action.IDLE)
		else:
			planar += rock[seat]
		player.freeze(Vector3(planar.x, moving.y, planar.y), stops[seat])


## A quick shove's knockback, or a charged one's: from knockback at the threshold
## to charged_knockback at a full charge.
func _knockback(shover: PlayerState) -> float:
	if not shover.is_charged():
		return _rules.knockback
	return lerpf(_rules.knockback, _rules.charged_knockback, _charge_weight(shover))


## A quick shove's hit-stop, or a charged one's: longer the fuller the charge, as
## its knockback is.
func _hitstop(shover: PlayerState) -> int:
	if not shover.is_charged():
		return _hitstop_ticks
	return roundi(lerpf(_hitstop_ticks, _hitstop_charged_ticks, _charge_weight(shover)))


## How full [param shover]'s charge is: 0 at the threshold, 1 at a full charge.
func _charge_weight(shover: PlayerState) -> float:
	return (
		float(shover.charge - _charge_threshold_ticks)
		/ (_charge_full_ticks - _charge_threshold_ticks)
	)


## Whether [param target]'s brace takes the edge off [param shover]'s shove, sent
## along [param direction]: it must come into the front arc, and not be a full
## charge. A charge let go early is a stronger quick shove that a brace still
## reads, so breaking one takes the whole charge_full: the glow a brace sees
## coming, and a quick shove can cancel (§6, readable and punishable).
func _braced_against(target: PlayerState, shover: PlayerState, direction: Vector2) -> bool:
	if shover.charge >= _charge_full_ticks:
		return false
	return target.braced_against(direction, _rules.brace_arc_deg)


## A swimmer moves across the sea at swim_speed, without control while staggered.
## A body above the sea falls into it; in it, the water takes a dive's speed and
## floats it back to where it rests (_rest_at). A climber hangs where its climb has
## it (_water).
func _swim(player: PlayerState, pose_now: ShipPose) -> void:
	if player.is_climbing():
		return
	var dt := Ticks.SECONDS_PER_TICK
	var planar := Vector2(player.vel.x, player.vel.z)
	if player.is_staggered():
		planar = planar.move_toward(Vector2.ZERO, _rules.stagger_friction * dt)
		player.stagger_ticks -= 1
	else:
		var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.swim_speed
		planar = planar.move_toward(wish, _rules.ground_accel * dt)
	var rise := player.vel.y
	if surfaces.wet(player.pos, pose_now):
		var toward := signf(_rest_at(player.pos, player.pos.y, pose_now) - player.pos.y)
		rise = move_toward(rise, toward * _rules.float_speed, _rules.dunk_drag * dt)
	else:
		rise -= _rules.gravity * dt
	player.vel = Vector3(planar.x, rise, planar.y)


## Where a swimmer's feet rest at [param feet]'s x/z, coming from
## [param feet_before]'s height: swim_depth under the sea, or on the bottom there
## when that is higher.
func _rest_at(feet: Vector3, feet_before: float, pose_now: ShipPose) -> float:
	var sea := pose_now.sea_height(feet.x, feet.z)
	var rest := maxf(sea - _rules.swim_depth, _bottom(feet, feet_before, sea))
	return minf(rest, _headroom(feet, feet_before))


## The highest a swimmer's feet at [param feet]'s x/z, coming from
## [param feet_before]'s height, may rest: a body's height under the lowest deck over
## its head (Surfaces.ceiling). Under a deck the sea is filling, it stays under that
## deck as the water closes over its head; a head pressed into the deck would be
## pushed out sideways by it — through a wall or the hull.
func _headroom(feet: Vector3, feet_before: float) -> float:
	var from := Vector3(feet.x, feet_before, feet.z)
	return surfaces.ceiling(from, _rules.step_height) - _rules.body_height


## The height of the sea's bottom under a swimmer at [param feet] that came from
## [param feet_before]'s height: the surface it would come down on — within a
## swimmer's step over its feet (_swim_step), so a ramp it swims up carries it and a
## flooded deck it swims over lifts it — when that is under [param sea]; -INF
## otherwise. A surface above the sea is never its bottom: a climber shoved back
## falls past the edge it was climbing.
func _bottom(feet: Vector3, feet_before: float, sea: float) -> float:
	var from := Vector3(feet.x, maxf(feet.y, feet_before), feet.z)
	from.y += _swim_step(from, sea)
	var bottom := surfaces.landing(from)
	if bottom == Surfaces.NONE:
		return -INF
	var height := surfaces.height_at(bottom, feet)
	return height if height < sea else -INF


## How far up a swimmer with its feet at [param feet] steps: over any edge it can
## float across, as high as wade_depth under [param sea], but never so high that its
## head would meet a deck over it; a step_height at the least. A deck's edge it swims
## onto stands below its head and a deck it swims under above it, within a step: the
## first is no wall to someone swimming in from deeper water, the second no floor.
func _swim_step(feet: Vector3, sea: float) -> float:
	var clearance := _rules.body_height - _rules.step_height
	var overhead := surfaces.ceiling(feet, clearance) - _rules.body_height
	return maxf(_rules.step_height, minf(sea - _rules.wade_depth, overhead) - feet.y)


## The water is a countdown (SH5). A body whose feet go wade_depth into the sea, or
## that falls into it, swims. A swimmer comes to rest (_come_to_rest), stands up
## where the bottom rises within stand_depth of the sea, and climbs out where it can
## (_start_climb); while it swims and does not climb, its cold meter drains, and it
## is out when that is empty. Out of the sea the meter refills at cold_regen. A seat
## frozen in a hit-stop holds its meter, and neither falls in, stands, climbs nor
## settles until the stop ends. Returns who went out.
func _water(
	live: Array[PlayerState],
	pose_now: ShipPose,
	tick: int,
	events: Array[SimEvent],
	feet_before: PackedFloat64Array
) -> Array[PlayerState]:
	var dt := Ticks.SECONDS_PER_TICK
	var exits: Array[PlayerState] = []
	for player: PlayerState in live:
		if player.is_frozen():
			continue
		if player.body != PlayerState.Body.SWIMMING:
			if not _in_the_sea(player, pose_now):
				player.cold = minf(player.cold + _rules.cold_regen * dt, _rules.cold_meter)
				continue
			_fall_in(player, tick, events)
		if player.is_climbing():
			_climb(player, tick, events)
			continue
		_come_to_rest(player, feet_before[player.seat], pose_now)
		var ground := surfaces.under(player.pos, _rules.step_height)
		if (
			ground != Surfaces.NONE
			and surfaces.wet(player.pos, pose_now)
			and _sea_over(ground, player.pos, pose_now) < _rules.stand_depth
		):
			_stand(player, ground, tick, events)
			continue
		_start_climb(player, pose_now)
		if player.is_climbing():
			continue
		player.cold = maxf(player.cold - dt, 0.0)
		if player.cold == 0.0:
			_out(player, tick)
			exits.append(player)
	return exits


## Whether [param player], not swimming, is in the sea: in the air, its feet under
## it over a bottom wade_depth deep or more — it lands on a shallower one; on a
## surface, wade_depth under it or more.
func _in_the_sea(player: PlayerState, pose_now: ShipPose) -> bool:
	if player.body == PlayerState.Body.AIRBORNE:
		var sea := pose_now.sea_height(player.pos.x, player.pos.z)
		var depth := sea - _bottom(player.pos, player.pos.y, sea)
		return surfaces.wet(player.pos, pose_now) and depth >= _rules.wade_depth
	return _sea_over(player.surface, player.pos, pose_now) >= _rules.wade_depth


## How deep the sea stands over [param surface] under [param feet]'s x/z.
func _sea_over(surface: int, feet: Vector3, pose_now: ShipPose) -> float:
	return pose_now.sea_height(feet.x, feet.z) - surfaces.height_at(surface, feet)


## Into the sea: whatever [param player] was readying is dropped, and a shove or a
## crate that hit it credit_window or longer ago no longer counts as what put it
## there.
func _fall_in(player: PlayerState, tick: int, events: Array[SimEvent]) -> void:
	player.body = PlayerState.Body.SWIMMING
	player.surface = Surfaces.NONE
	player.jumped = false
	player.bracing = false
	_enter(player, PlayerState.Action.IDLE)
	if tick - player.last_hit_at >= _credit_window_ticks:
		player.forget_hit()
	events.append(SimEvent.entered_water(tick, player.seat))


## After this tick's move: on the bottom, if it went under it; at rest, if it rose
## to it, or sank onto it no faster than the water floats a body.
func _come_to_rest(player: PlayerState, feet_before: float, pose_now: ShipPose) -> void:
	var sea := pose_now.sea_height(player.pos.x, player.pos.z)
	var bottom := _bottom(player.pos, feet_before, sea)
	var rest := minf(maxf(sea - _rules.swim_depth, bottom), _headroom(player.pos, feet_before))
	var rise := player.vel.y
	if player.pos.y < bottom:
		player.pos.y = bottom
		rise = maxf(rise, 0.0)
	var speed := _rules.float_speed
	var risen := rise > 0.0 and player.pos.y >= rest
	var settled := (
		rise <= 0.0
		and rise >= -speed
		and player.pos.y <= rest
		and player.pos.y >= rest - speed * Ticks.SECONDS_PER_TICK
	)
	if risen or settled:
		player.pos.y = rest
		rise = 0.0
	player.vel.y = rise


## A swimmer pressing toward a way out that Surfaces finds (climb_out) starts up it:
## climb_time, or longer up a ladder at ladder_speed.
func _start_climb(player: PlayerState, pose_now: ShipPose) -> void:
	if player.is_staggered() or player.last_move == Vector2i.ZERO:
		return
	var climb := surfaces.climb_out(
		player.pos, Vector2(player.last_move).normalized(), pose_now, _rules
	)
	if climb == null:
		return
	var rise := climb.stand.y - pose_now.sea_height(climb.stand.x, climb.stand.z)
	player.climb_left = maxi(_climb_ticks, Ticks.from_seconds(rise / _rules.ladder_speed))
	player.climb_to = climb.stand
	player.vel = Vector3.ZERO
	player.jumped = false


## A climb rises an equal share of the rest of the way each tick, hanging at the
## edge, and steps over it at walk_speed at the end, to stand where it was going.
## Where that is gone — the deck collapsed under it — the climber lets go, back into
## the sea.
func _climb(player: PlayerState, tick: int, events: Array[SimEvent]) -> void:
	var ground := surfaces.under(player.climb_to, _rules.step_height)
	if ground == Surfaces.NONE:
		player.climb_left = 0
		return
	player.pos.y += (player.climb_to.y - player.pos.y) / player.climb_left
	var across := Vector2(player.climb_to.x - player.pos.x, player.climb_to.z - player.pos.z)
	var later := _rules.walk_speed * Ticks.SECONDS_PER_TICK * (player.climb_left - 1)
	var stride := across.limit_length(maxf(across.length() - later, 0.0))
	player.pos += Vector3(stride.x, 0.0, stride.y)
	player.climb_left -= 1
	if player.climb_left == 0:
		_stand(player, ground, tick, events)


## Out of the sea, standing on [param surface]: the shove or the crate that put it
## there no longer counts.
func _stand(player: PlayerState, surface: int, tick: int, events: Array[SimEvent]) -> void:
	player.body = PlayerState.Body.GROUNDED
	player.surface = surface
	player.pos.y = surfaces.height_at(surface, player.pos)
	player.vel.y = 0.0
	player.jumped = false
	player.climb_left = 0
	player.forget_hit()
	events.append(SimEvent.climbed_out(tick, player.seat, surface))


## A shove landing on a climber sends it back into the sea, colder by climb_penalty.
func _knock_back_in(player: PlayerState, tick: int, events: Array[SimEvent]) -> void:
	player.climb_left = 0
	player.cold = maxf(player.cold - _rules.climb_penalty, 0.0)
	events.append(SimEvent.knocked_back_in(tick, player.seat, player.last_hit_by))


func _out(player: PlayerState, tick: int) -> void:
	player.body = PlayerState.Body.OUT
	player.out_tick = tick
	player.out_cause = PlayerState.Cause.COLD
	player.vel = Vector3.ZERO
	player.stagger_ticks = 0
	player.hitstop = 0
	player.held_vel = Vector3.ZERO
	player.bracing = false
	player.climb_left = 0
	_enter(player, PlayerState.Action.IDLE)


## The sea settles it (§5): at the scenario's cap, or once every surface still
## standing is wade_depth under the sea and every seat still in swims — when nothing
## but the cold can change — they all go out by the cold, adding to [param exits],
## but for the one with the most cold left when it has the most alone. A tie for the
## most is a draw, the sea's; the verdict places the rest by the cold they had left.
func _sea_settles(pose_now: ShipPose, tick: int, exits: Array[PlayerState]) -> void:
	var live := _live_seats()
	if live.size() < 2:
		return
	if schedule.cap_tick() == -1 or tick < schedule.cap_tick():
		for player: PlayerState in live:
			if player.body != PlayerState.Body.SWIMMING:
				return
		if not surfaces.sunk(pose_now, _rules.wade_depth):
			return
	var most := 0.0
	var warmest := 0
	for player: PlayerState in live:
		if player.cold > most:
			most = player.cold
			warmest = 0
		if player.cold == most:
			warmest += 1
	for player: PlayerState in live:
		if warmest > 1 or player.cold != most:
			_out(player, tick)
			exits.append(player)


## Seats out on the same tick share a place, unless their cold meters differ: more
## cold left places higher. One or none left ends the match.
func _verdict(exits: Array[PlayerState], tick: int, events: Array[SimEvent]) -> void:
	if exits.is_empty():
		return
	var remaining := state.remaining()
	for player: PlayerState in exits:
		var warmer := 0
		for other: PlayerState in exits:
			if other.cold > player.cold:
				warmer += 1
		player.place = remaining + 1 + warmer
		events.append(
			SimEvent.seat_out(
				tick,
				player.seat,
				player.place,
				player.out_cause,
				player.last_hit_by,
				player.last_hit_crate
			)
		)
	if remaining > 1:
		return
	state.phase = MatchState.Phase.ENDED
	var winner := state.winner()
	if winner != -1:
		state.seats[winner].place = 1
	events.append(SimEvent.match_ended(tick, winner))


func _candidates(live: Array[PlayerState]) -> Array[ShoveResolver.Candidate]:
	var candidates: Array[ShoveResolver.Candidate] = []
	for player: PlayerState in live:
		candidates.append(_candidate(player))
	return candidates


func _candidate(player: PlayerState) -> ShoveResolver.Candidate:
	return ShoveResolver.Candidate.new(
		player.seat, player.pos, _rules.body_radius, _rules.body_height
	)
