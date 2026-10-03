class_name MatchSim
extends RefCounted
## The match, as a Node-free fixed-tick simulation (D1, D2). step() with one
## InputFrame per seat is the only way anything happens (D3); snapshot() is the
## whole truth and from_snapshot() continues it exactly (D5).

const SNAPSHOT_VERSION := 1

var config: MatchConfig
var schedule: SinkSchedule
var surfaces: Surfaces
var state: MatchState

var _rules: BrawlRules
var _windup_ticks: int
var _active_ticks: int
var _recovery_ticks: int
var _stagger_ticks: int


func _init(match_config: MatchConfig) -> void:
	config = match_config
	_rules = config.rules
	schedule = SinkSchedule.new(
		config.scenario, config.ship.freeboard, SeedStreams.derive(config.match_seed, "sink")
	)
	surfaces = Surfaces.new(config.ship)
	_windup_ticks = Ticks.from_seconds(_rules.shove_windup)
	_active_ticks = Ticks.from_seconds(_rules.shove_active)
	_recovery_ticks = Ticks.from_seconds(_rules.shove_recovery)
	_stagger_ticks = Ticks.from_seconds(_rules.stagger)


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
		player.facing = Vector2(-player.pos.x, -player.pos.z).angle()
		player.surface = sim.surfaces.under(player.pos)
		match_state.seats.append(player)
	sim.state = match_state
	return sim


## The match continued from [param snapshot], which [param match_config] started.
static func from_snapshot(snapshot: Dictionary, match_config: MatchConfig) -> MatchSim:
	assert(snapshot["v"] == SNAPSHOT_VERSION, "snapshot version %s" % snapshot["v"])
	var sim := MatchSim.new(match_config)
	var match_state := MatchState.new()
	match_state.tick = snapshot["tick"]
	match_state.phase = snapshot["phase"]
	match_state.match_seed = snapshot["seed"]
	match_state.rng = SeedStreams.derive(match_state.match_seed, "match")
	match_state.rng.state = snapshot["rng"]
	for entry: Dictionary in snapshot["seats"]:
		match_state.seats.append(PlayerState.from_dict(entry))
	sim.state = match_state
	return sim


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
	_take_frames(frames, tick)
	var pose_now := schedule.pose_at(tick)
	if tick < config.countdown_ticks:
		for player: PlayerState in state.seats:
			player.prev_buttons = player.last_buttons
	else:
		_intent()
		_forces()
		_move()
		_ground()
		_shoves()
		_verdict(_water(pose_now, tick), tick, events)
	state.tick += 1
	if state.phase == MatchState.Phase.COUNTDOWN and state.tick >= config.countdown_ticks:
		state.phase = MatchState.Phase.LIVE
	return events


func _live_seats() -> Array[PlayerState]:
	var live: Array[PlayerState] = []
	for player: PlayerState in state.seats:
		if not player.is_out():
			live.append(player)
	return live


func _take_frames(frames: Array[InputFrame], tick: int) -> void:
	for player: PlayerState in _live_seats():
		var frame: InputFrame = frames[player.seat] if player.seat < frames.size() else null
		if frame == null:
			continue
		var valid := frame.validated(player.seat, tick)
		player.last_move = valid.move
		player.last_aim = valid.aim
		player.last_buttons = valid.buttons


## Button edges, shove phases and facing.
func _intent() -> void:
	var candidates := _candidates()
	var turn_step := deg_to_rad(_rules.turn_rate_deg) * Ticks.SECONDS_PER_TICK
	for player: PlayerState in _live_seats():
		if player.action != PlayerState.Action.IDLE:
			player.action_ticks += 1
			_advance_action(player)
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
			player.facing = ShoveResolver.autoaim(
				_candidate(player),
				player.facing,
				candidates,
				_rules.shove_reach,
				_rules.autoaim_cone_deg
			)
		var aiming := (
			player.action == PlayerState.Action.WINDUP or player.action == PlayerState.Action.ACTIVE
		)
		if player.last_move != Vector2i.ZERO and not aiming:
			var wanted := Vector2(player.last_move).angle()
			var turn := clampf(angle_difference(player.facing, wanted), -turn_step, turn_step)
			player.facing = wrapf(player.facing + turn, -PI, PI)


func _advance_action(player: PlayerState) -> void:
	match player.action:
		PlayerState.Action.WINDUP:
			if player.action_ticks >= _windup_ticks:
				_enter(player, PlayerState.Action.ACTIVE)
		PlayerState.Action.ACTIVE:
			if player.action_ticks >= _active_ticks:
				_enter(player, PlayerState.Action.RECOVERY)
		PlayerState.Action.RECOVERY:
			if player.action_ticks >= _recovery_ticks:
				_enter(player, PlayerState.Action.IDLE)


func _enter(player: PlayerState, action: PlayerState.Action) -> void:
	player.action = action
	player.action_ticks = 0


## Walking, friction and gravity, as velocity.
func _forces() -> void:
	var dt := Ticks.SECONDS_PER_TICK
	for player: PlayerState in _live_seats():
		if player.body == PlayerState.Body.AIRBORNE:
			player.vel.y -= _rules.gravity * dt
			continue
		var planar := Vector2(player.vel.x, player.vel.z)
		if player.is_staggered():
			planar = planar.move_toward(Vector2.ZERO, _rules.stagger_friction * dt)
			player.stagger_ticks -= 1
		else:
			var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.walk_speed
			var rate := _rules.ground_accel if wish != Vector2.ZERO else _rules.ground_friction
			planar = planar.move_toward(wish, rate * dt)
			# The shove is spent once the body moves as its own input says; until then
			# a slide that outlasts the stagger is still the shover's.
			if planar == wish:
				player.last_hit_by = -1
		player.vel = Vector3(planar.x, player.vel.y, planar.y)


## Integration, then bodies push each other apart, pair by pair in seat order.
func _move() -> void:
	var live := _live_seats()
	for player: PlayerState in live:
		player.pos += player.vel * Ticks.SECONDS_PER_TICK
	var reach := _rules.body_radius * 2.0
	for first in live.size():
		for second in range(first + 1, live.size()):
			var a := live[first]
			var b := live[second]
			if absf(a.pos.y - b.pos.y) >= _rules.body_height:
				continue
			var offset := Vector2(b.pos.x - a.pos.x, b.pos.z - a.pos.z)
			var distance := offset.length()
			if distance >= reach:
				continue
			var normal := offset / distance if distance > 0.0 else Vector2.RIGHT
			var push := normal * ((reach - distance) * 0.5)
			a.pos -= Vector3(push.x, 0.0, push.y)
			b.pos += Vector3(push.x, 0.0, push.y)


## What each body stands on; walking off a platform starts a fall.
func _ground() -> void:
	for player: PlayerState in _live_seats():
		if player.body != PlayerState.Body.GROUNDED:
			continue
		var surface := surfaces.under(player.pos)
		player.surface = surface
		if surface == Surfaces.NONE:
			player.body = PlayerState.Body.AIRBORNE
			continue
		player.pos.y = surfaces.height(surface)


## Every active shove against the bodies as they stand now; all of this tick's
## hits apply together, so simultaneous shoves both land.
func _shoves() -> void:
	var attempts: Array[ShoveResolver.Attempt] = []
	for player: PlayerState in _live_seats():
		if (
			player.action == PlayerState.Action.ACTIVE
			and not player.shove_spent
			and not player.is_staggered()
		):
			attempts.append(
				ShoveResolver.Attempt.new(
					player.seat, player.pos, _rules.body_radius, player.facing_vector()
				)
			)
	if attempts.is_empty():
		return
	var hits := ShoveResolver.resolve(
		attempts, _candidates(), _rules.shove_reach, _rules.shove_cone_deg
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
	for hit: ShoveResolver.Hit in hits:
		var target := state.seats[hit.target]
		var speed := _rules.knockback
		if target.is_staggered():
			speed *= _rules.restagger_mult
		knock[hit.target] += hit.direction * speed
		rock[hit.shover] -= hit.direction * _rules.recoil
		landed[hit.shover] = 1
		if hit_by[hit.target] == -1:
			hit_by[hit.target] = hit.shover
	for player: PlayerState in _live_seats():
		var seat := player.seat
		if landed[seat] == 1:
			player.shove_spent = true
		var planar := Vector2(player.vel.x, player.vel.z)
		if hit_by[seat] != -1:
			planar = knock[seat] + rock[seat]
			player.stagger_ticks = _stagger_ticks
			player.last_hit_by = hit_by[seat]
			_enter(player, PlayerState.Action.IDLE)
		elif landed[seat] == 1:
			planar += rock[seat]
		player.vel = Vector3(planar.x, player.vel.y, planar.y)


## The water is a wall (SH1): feet below the sea plane is out, this tick.
func _water(pose_now: ShipPose, tick: int) -> Array[PlayerState]:
	var exits: Array[PlayerState] = []
	for player: PlayerState in _live_seats():
		if surfaces.wet(player.pos, pose_now):
			player.body = PlayerState.Body.OUT
			player.out_tick = tick
			player.out_cause = PlayerState.Cause.WATER
			player.vel = Vector3.ZERO
			player.stagger_ticks = 0
			_enter(player, PlayerState.Action.IDLE)
			exits.append(player)
	return exits


## Seats out on the same tick share a place; one or none left ends the match.
func _verdict(exits: Array[PlayerState], tick: int, events: Array[SimEvent]) -> void:
	if exits.is_empty():
		return
	var remaining := state.remaining()
	for player: PlayerState in exits:
		player.place = remaining + 1
		events.append(
			SimEvent.seat_out(tick, player.seat, player.place, player.out_cause, player.last_hit_by)
		)
	if remaining > 1:
		return
	state.phase = MatchState.Phase.ENDED
	var winner := state.winner()
	if winner != -1:
		state.seats[winner].place = 1
	events.append(SimEvent.match_ended(tick, winner))


func _candidates() -> Array[ShoveResolver.Candidate]:
	var candidates: Array[ShoveResolver.Candidate] = []
	for player: PlayerState in _live_seats():
		candidates.append(_candidate(player))
	return candidates


func _candidate(player: PlayerState) -> ShoveResolver.Candidate:
	return ShoveResolver.Candidate.new(
		player.seat, player.pos, _rules.body_radius, _rules.body_height
	)
