class_name MatchSim
extends RefCounted
## The match, as a Node-free fixed-tick simulation (D1, D2). step() with one
## InputFrame per seat is the only way anything happens (D3); snapshot() is the
## whole truth and from_snapshot() continues it exactly (D5).

const SNAPSHOT_VERSION := 5
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
	_charge_threshold_ticks = Ticks.from_seconds(_rules.charge_threshold)
	_charge_full_ticks = Ticks.from_seconds(_rules.charge_full)
	_regen_delay_ticks = Ticks.from_seconds(_rules.stamina_regen_delay)
	_hitstop_ticks = Ticks.from_seconds(_rules.hitstop)
	_hitstop_charged_ticks = Ticks.from_seconds(_rules.hitstop_charged)
	_hitstop_braced_ticks = Ticks.from_seconds(_rules.hitstop_braced)


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
		_brace_and_stamina()
		_forces(pose_now)
		var feet_before := _move(tick, events)
		_ground(tick, events, feet_before)
		_thaw()
		_shoves(tick, events)
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
		player.last_look = valid.look_yaw
		player.last_buttons = valid.buttons
		# A seat's facing is its look, by any amount, every tick (D14).
		player.facing = InputFrame.yaw_angle(valid.look_yaw)


## Button edges and shove phases. A seat frozen in a hit-stop advances nothing,
## its button edges included: the first tick after the stop reads its buttons
## against those it held before it, so a press made in the stop and still held
## counts then, and one let go inside the stop never happened.
func _intent() -> void:
	var candidates := _candidates()
	for player: PlayerState in _live_seats():
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
			_advance_action(player, candidates)
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


## Tap or hold is read here, from ticks held (D3): a shove released after its
## windup fires as a quick shove; one still held at charge_threshold becomes a
## charge, which fires, paid for, when it is let go.
func _advance_action(player: PlayerState, candidates: Array[ShoveResolver.Candidate]) -> void:
	var held := player.last_buttons & InputFrame.SHOVE != 0
	match player.action:
		PlayerState.Action.WINDUP:
			if held and player.action_ticks >= _charge_threshold_ticks:
				if player.exhausted or player.stamina < _rules.charge_cost:
					_fire(player, candidates)
				else:
					player.charge = player.action_ticks
					_enter(player, PlayerState.Action.CHARGE)
			elif not held and player.action_ticks >= _windup_ticks:
				_fire(player, candidates)
		PlayerState.Action.CHARGE:
			player.charge = mini(player.charge + 1, _charge_full_ticks)
			if not held:
				_spend(player, _rules.charge_cost)
				_fire(player, candidates)
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
## shover looks now, bent toward the nearest target the autoaim cone holds — the
## shove, never the view (D14).
func _fire(player: PlayerState, candidates: Array[ShoveResolver.Candidate]) -> void:
	_enter(player, PlayerState.Action.ACTIVE)
	player.shove_facing = ShoveResolver.autoaim(
		_candidate(player),
		player.facing,
		candidates,
		_rules.shove_reach,
		_rules.autoaim_cone_deg,
		surfaces,
		_rules.step_height
	)


## Who is braced this tick, and stamina: a brace holds while its button is, on the
## ground, idle, unstaggered and not exhausted, and spends as it holds; after
## stamina_regen_delay without spending, stamina comes back. A hit-stop holds a
## seat's brace and stamina as they are.
func _brace_and_stamina() -> void:
	for player: PlayerState in _live_seats():
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
## A body frozen in a hit-stop feels none of it, and its stagger waits.
func _forces(pose_now: ShipPose) -> void:
	var dt := Ticks.SECONDS_PER_TICK
	var gravity := pose_now.ship_gravity(_rules.gravity)
	var downhill := Vector2(gravity.x, gravity.z) * dt
	var steep := pose_now.slope_deg() > _rules.grip_angle_deg
	for player: PlayerState in _live_seats():
		if player.is_frozen():
			continue
		if player.body == PlayerState.Body.AIRBORNE:
			player.vel += gravity * dt
			continue
		var planar := Vector2(player.vel.x, player.vel.z)
		var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.walk_speed
		if player.action == PlayerState.Action.CHARGE:
			wish = wish.limit_length(_rules.charge_walk)
		elif player.bracing:
			wish = Vector2.ZERO
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
				player.last_hit_by = -1
		player.vel = Vector3(planar.x, player.vel.y, planar.y)


## Integration, then contacts: blockers, then railings, then bodies pushing each
## other apart pair by pair in seat order, pass after pass until nothing moves.
## Walls and rails have the last word — the last pass stops before bodies push — so
## a crowd may end a tick pressed together, never inside a wall. Returns each seat's
## feet height before it moved.
func _move(tick: int, events: Array[SimEvent]) -> PackedFloat64Array:
	var live := _live_seats()
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
	for _step in steps:
		for player: PlayerState in live:
			player.pos += player.vel * dt
		for contact_pass in CONTACT_PASSES:
			var held := _blockers(live, feet_before)
			held = _railings(live, tick, events, came_from) or held
			if contact_pass == CONTACT_PASSES - 1:
				break
			if not _bodies(live) and not held:
				break
	return feet_before


## Whatever stops a body — a blocker, a wall, a deck edge too high to step onto —
## pushes it back out in the deck plane and takes the velocity into it. It is met at
## the height the feet stood at before this tick's move, so a fall lands on a deck
## in _ground rather than being pushed off its edge. True when it moved anyone.
func _blockers(live: Array[PlayerState], feet_before: PackedFloat64Array) -> bool:
	var moved := false
	for player: PlayerState in live:
		var feet := Vector3(player.pos.x, feet_before[player.seat], player.pos.z)
		var contacts := surfaces.obstacle_contacts(
			feet, _rules.body_radius, _rules.body_height, _rules.step_height
		)
		for contact: Surfaces.Contact in contacts:
			_hold(player, contact)
			moved = true
	return moved


## A railing stops a grounded body crossing it slower than vault_speed — it loses
## the velocity into the rail — and tips one at or above it over, into the air. In
## the air, a body that came from a rail's side with its feet below the rail's top
## is held the same way, unless it crosses at vault_speed or more: a vaulter is never
## pulled back. True when it moved anyone.
func _railings(
	live: Array[PlayerState], tick: int, events: Array[SimEvent], came_from: PackedVector2Array
) -> bool:
	var moved := false
	for player: PlayerState in live:
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
				break
			_hold(player, contact)
			moved = true
	return moved


## Bodies whose heights overlap push each other apart, pair by pair in seat order,
## each moving half the overlap. True when it moved anyone.
func _bodies(live: Array[PlayerState]) -> bool:
	var moved := false
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
## on the highest surface it comes down onto, staggered by the drop.
func _ground(tick: int, events: Array[SimEvent], feet_before: PackedFloat64Array) -> void:
	for player: PlayerState in _live_seats():
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
		player.fall_from = maxf(player.fall_from, player.pos.y)
		if player.vel.y > 0.0:
			continue
		var below := surfaces.landing(Vector3(player.pos.x, feet_before[player.seat], player.pos.z))
		if below == Surfaces.NONE:
			continue
		var ground := surfaces.height_at(below, player.pos)
		if player.pos.y > ground:
			continue
		var stagger := Ticks.from_seconds((player.fall_from - ground) * _rules.fall_stagger_per_m)
		player.body = PlayerState.Body.GROUNDED
		player.surface = below
		player.pos.y = ground
		player.vel.y = 0.0
		player.stagger_ticks = maxi(player.stagger_ticks, stagger)
		events.append(SimEvent.landed(tick, player.seat, below, stagger))


## Counts every hit-stop down. One that runs out hands its body the velocity it
## held, to move with from the next tick.
func _thaw() -> void:
	for player: PlayerState in _live_seats():
		if not player.is_frozen():
			continue
		player.hitstop -= 1
		if not player.is_frozen():
			player.vel = player.held_vel
			player.held_vel = Vector3.ZERO


## Every active shove against the bodies as they stand now; all of this tick's
## hits apply together, so simultaneous shoves both land. A landed shove freezes
## its shover and its target for a hit-stop, and the knockback and the recoil wait
## for it to end.
func _shoves(tick: int, events: Array[SimEvent]) -> void:
	var attempts: Array[ShoveResolver.Attempt] = []
	for player: PlayerState in _live_seats():
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
		_candidates(),
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
	for player: PlayerState in _live_seats():
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
			if staggers[seat] == 1:
				player.stagger_ticks = _stagger_ticks
				player.bracing = false
				_enter(player, PlayerState.Action.IDLE)
		else:
			planar += rock[seat]
		_freeze(player, Vector3(planar.x, moving.y, planar.y), stops[seat])


## Freezes [param player] for [param ticks] — a longer stop already running wins —
## holding [param velocity] back until the stop ends; with no stop it moves at once.
func _freeze(player: PlayerState, velocity: Vector3, ticks: int) -> void:
	player.hitstop = maxi(player.hitstop, ticks)
	if player.is_frozen():
		player.held_vel = velocity
		player.vel = Vector3.ZERO
	else:
		player.vel = velocity


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
	if not target.bracing or shover.charge >= _charge_full_ticks:
		return false
	return (
		absf(Vector2.from_angle(target.facing).angle_to(-direction))
		<= deg_to_rad(_rules.brace_arc_deg)
	)


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
			player.hitstop = 0
			player.held_vel = Vector3.ZERO
			player.bracing = false
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
