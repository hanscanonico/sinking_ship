class_name MatchSim
extends RefCounted
## The match, as a Node-free fixed-tick simulation (D1, D2). step() with one
## InputFrame per seat is the only way anything happens (D3); snapshot() is the
## whole truth and from_snapshot() continues it exactly (D5).

const SNAPSHOT_VERSION := 9

var config: MatchConfig
var schedule: SinkSchedule
## Her own Surfaces, the frame of her decks (D6): what presentation asks.
var surfaces: Surfaces
## Every face of her as a surface, frame by frame (SH32).
var faces: Faces
var state: MatchState

var _rules: BrawlRules
var _hazards: Hazards
var _movement: Movement
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
var _credit_window_ticks: int


func _init(match_config: MatchConfig) -> void:
	config = match_config
	_rules = config.rules
	schedule = config.schedule()
	surfaces = Surfaces.new(config.ship)
	faces = Faces.new(
		config.ship,
		surfaces,
		schedule.damage(),
		_rules.brace_holds_to,
		SeaPhysics.load_default().capsized_movement
	)
	_hazards = Hazards.new(config, surfaces)
	_movement = Movement.new(_rules, faces, _hazards)
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
	match_state.up = snapshot["up"]
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
	# From here to the tick's end every body's points are in the frame of the faces that
	# are floors (Movement.face), and so is the pose every rule reads.
	var framed := _movement.face(state, pose_now, tick, events)
	if tick < config.countdown_ticks:
		for player: PlayerState in state.seats:
			player.prev_buttons = player.last_buttons
	else:
		_intent(live, framed)
		_brace_and_stamina(live)
		_movement.forces(live, framed)
		var feet_before := _movement.move(state, live, framed, tick, events)
		_movement.ground(live, tick, events, feet_before)
		_thaw(live)
		_hazards.step(state, pose_now, tick, events)
		_shoves(live, tick, events)
		var exits := _water(live, framed, tick, events, feet_before)
		var settled := MatchVerdict.settled_by_the_sea(
			_live_seats(), framed, tick, schedule.gone_tick(), _here(), _rules.wade_depth
		)
		for player: PlayerState in settled:
			_out(player, tick)
			exits.append(player)
		MatchVerdict.place(state, exits, tick, events)
	_movement.unface(state)
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


## The Surfaces of the frame the tick stands in (Movement.face).
func _here() -> Surfaces:
	return _movement.surfaces()


func _live_seats() -> Array[PlayerState]:
	var live: Array[PlayerState] = []
	for player: PlayerState in state.seats:
		if not player.is_out():
			live.append(player)
	return live


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
## with jump_cost of stamina to spend. It goes up along the world's up (D8) until its
## feet are jump_height above where it left along the frame's — whatever the face's
## tilt, never over a railing — and gravity, the world's turned by the pose, brings it
## down where it rose, on its way across the face as it was walking.
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
	# The take-off speed up the frame whose apex, stepped tick by tick as Movement's forces
	# and move step it, is jump_height: v² − g·dt·v − 2·g·h = 0; along the world's up,
	# gravity's own way back, it carries the share across the face that goes with it.
	var gravity := pose_now.ship_gravity(_rules.gravity)
	var fall := -gravity.y
	var drop := fall * Ticks.SECONDS_PER_TICK
	var rise := (drop + sqrt(drop * drop + 8.0 * fall * _rules.jump_height)) * 0.5
	player.vel += Vector3(gravity.x * rise / gravity.y, 0.0, gravity.z * rise / gravity.y)
	player.vel.y = rise
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
		_here(),
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
		_here(),
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
		_here(),
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


## The water is a countdown (SH5). A body whose feet go wade_depth into the sea, or
## that falls into it, swims. A swimmer comes to rest (Movement.come_to_rest), stands
## up where the bottom rises within stand_depth of the sea, and climbs out where it can
## (Movement.start_climb) — onto a dry face in a pocket as onto a deck edge; while it
## swims and does not climb, its cold meter drains — at pocket_cold_rate of the open water's with
## its head in trapped air (Q22) — and it is out when that is empty. Out of the sea the
## meter refills at cold_regen. A seat frozen in a hit-stop holds its meter, and
## neither falls in, stands, climbs nor settles until the stop ends. Returns who went
## out.
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
			if not _movement.in_the_sea(player, pose_now):
				player.cold = minf(player.cold + _rules.cold_regen * dt, _rules.cold_meter)
				continue
			_fall_in(player, tick, events)
		if player.is_climbing():
			_movement.climb(player, tick, events)
			continue
		_movement.come_to_rest(player, feet_before[player.seat], pose_now)
		var ground := _here().under(player.pos, _rules.step_height)
		if (
			ground != Surfaces.NONE
			and _here().wet(player.pos, pose_now)
			and _movement.sea_over(ground, player.pos, pose_now) < _rules.stand_depth
		):
			_movement.stand(player, ground, tick, events)
			continue
		_movement.start_climb(player, pose_now)
		if player.is_climbing():
			continue
		var head := player.pos + Vector3.UP * _rules.head_height()
		var rate := _rules.pocket_cold_rate if pose_now.in_pocket(head) else 1.0
		player.cold = maxf(player.cold - dt * rate, 0.0)
		if player.cold == 0.0:
			_out(player, tick)
			exits.append(player)
	return exits


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


func _candidates(live: Array[PlayerState]) -> Array[ShoveResolver.Candidate]:
	var candidates: Array[ShoveResolver.Candidate] = []
	for player: PlayerState in live:
		candidates.append(_candidate(player))
	return candidates


func _candidate(player: PlayerState) -> ShoveResolver.Candidate:
	return ShoveResolver.Candidate.new(
		player.seat, player.pos, _rules.body_radius, _rules.body_height
	)
