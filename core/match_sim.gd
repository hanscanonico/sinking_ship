class_name MatchSim
extends RefCounted
## The match, as a Node-free fixed-tick simulation (D1, D2). step() with one
## InputFrame per seat is the only way anything happens (D3); snapshot() is the
## whole truth and from_snapshot() continues it exactly (D5). Once she breaks (SH33) a
## tick runs piece by piece of her (Pieces), aft to fore: the bodies on each move, shove
## and swim in that piece's space and frame, under its pose; a body that leaves its
## piece in the air or the sea over another is carried across through the world.

const SNAPSHOT_VERSION := 12

var config: MatchConfig
var schedule: SinkSchedule
## Her own Surfaces, the frame of her decks (D6): what presentation asks.
var surfaces: Surfaces
## Every face of her as a surface, frame by frame (SH32).
var faces: Faces
## Her pieces, the whole ship first (SH33).
var pieces: Pieces
var state: MatchState

var _rules: BrawlRules
## The hazards and the movement of the piece the tick stands on now, and per piece
## each, made the first time a tick stands on it.
var _hazards: Hazards
var _movement: Movement
var _hazards_of: Dictionary[int, Hazards] = {}
var _movements: Dictionary[int, Movement] = {}
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
## Per prop of the layout, its kind (#273); and what a Grab press does (GrabReach).
var _kinds: Array[PropKind] = []
var _reach: GrabReach
## Per seat, the prop it holds, or -1, and the rules as they stand for it with that in its
## hands (SeatRules): asked of the props as the tick starts and kept with them through it
## (PropState.holder is the truth), the two changed together (_hold).
var _hands := PackedInt32Array()
var _rules_by_seat: Array[SeatRules] = []
## The rules for a seat with empty hands, and for one holding a prop of each kind, made
## the first time a seat holds one.
var _bare_rules: SeatRules
var _held_rules: Dictionary[PropKind, SeatRules] = {}
## The seats of the piece the tick stands on that pressed Grab, in seat order.
var _grabbing: Array[PlayerState] = []
## The bonuses the match plans to bring aboard (#307), drawn once from the config and the
## seed: none for a match without bonuses.
var _plan: BonusPlan


func _init(match_config: MatchConfig) -> void:
	config = match_config
	_rules = config.rules
	schedule = config.schedule()
	surfaces = Surfaces.new(config.ship)
	faces = Faces.new(
		config.ship, surfaces, _rules.brace_holds_to, SeaPhysics.load_default().capsized_movement
	)
	pieces = Pieces.new(
		config.ship,
		schedule,
		faces,
		_rules.brace_holds_to,
		SeaPhysics.load_default().capsized_movement
	)
	_hazards = Hazards.new(config, surfaces, 0, pieces)
	_movement = Movement.new(_rules, faces, _hazards)
	_hazards_of[0] = _hazards
	_movements[0] = _movement
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
	for prop: ShipProp in config.ship.props:
		_kinds.append(prop.prop_kind())
	_reach = GrabReach.new(config.ship, _rules, config.bonus_rules)
	_bare_rules = SeatRules.of(_rules, null)
	_plan = BonusPlan.drawn(
		config.bonus_rules, config.match_seed, config.scenario.clock, schedule.end_tick()
	)


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
	match_state.up.resize(sim.pieces.count())
	for piece in range(1, match_state.up.size()):
		match_state.up[piece] = -1
	sim.state = match_state
	return sim


## The match continued from [param snapshot], which [param match_config] started.
static func from_snapshot(snapshot: Dictionary, match_config: MatchConfig) -> MatchSim:
	var sim := MatchSim.new(match_config)
	sim.restore(snapshot)
	return sim


## Resets this match to [param snapshot], one of its own: what from_snapshot continues
## from, without building the ship again — a client predicting does it every snapshot.
## A crate the snapshot has as this match has it is kept, not made again.
func restore(snapshot: Dictionary) -> void:
	assert(snapshot["v"] == SNAPSHOT_VERSION, "snapshot version %s" % snapshot["v"])
	var kept: Array[PropState] = []
	if state != null:
		kept = state.props
	state = MatchState.from_dict(snapshot, kept)
	_honour(pose())


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
	_count_hands()
	var pose_now := schedule.pose_at(tick)
	_sinking_events(pose_now, tick, events)
	_rehome(pose_now, tick, events)
	var playing := tick >= config.countdown_ticks
	var exits: Array[PlayerState] = []
	var going: Array[PlayerState] = []
	var framed_of: Dictionary[int, ShipPose] = {}
	for piece: int in pose_now.standing:
		_stand_on(piece)
		var here := _on(live, piece)
		# From here to the piece's turn's end the points of every body on it are in the
		# frame of its faces that are floors (Movement.face), and so is the pose every rule
		# reads.
		var framed := _movement.face(state, pose_now.of_piece(piece), tick, events)
		framed_of[piece] = framed
		if not playing:
			for player: PlayerState in state.seats:
				if player.piece == piece:
					player.prev_buttons = player.last_buttons
		else:
			_intent(here, framed)
			_grabs(tick, events)
			_brace_and_stamina(here)
			_movement.forces(here, framed, _rules_by_seat)
			var feet_before := _movement.move(state, here, framed, tick, events)
			_movement.ground(here, tick, events, feet_before)
			_thaw(here)
			_hazards.step(state, pose_now, tick, events)
			_shoves(here, tick, events)
			exits.append_array(_water(here, framed, tick, events, feet_before))
			var gone_tick := schedule.piece_gone_tick(piece)
			going.append_array(
				MatchVerdict.gone_with(_on(_live_seats(), piece), framed, tick, gone_tick)
			)
		_movement.unface(state)
	# The bonuses aboard as the tick leaves them are those the next tick's presses find, as
	# its snapshot shows them (D13): the sea takes its own and the plan brings what is due
	# once every press of this one is done.
	_bonuses_lost(pose_now, tick, events)
	_bonuses_come(pose_now, tick, events)
	if playing:
		_carry(pose_now, live)
		var left: Array[PlayerState] = []
		for player: PlayerState in _live_seats():
			if not player in going:
				left.append(player)
		# The spares of the seats the last swim may put out, as they stand before any goes out
		# — its bonus goes with a seat: one going down with her has none to count.
		var spares := _spares(left)
		var sunk := _sunk.bind(pose_now.standing, framed_of)
		var cold := MatchVerdict.by_the_cold(left, sunk, spares)
		for player: PlayerState in going:
			_out(player, tick, events, PlayerState.Cause.WITH_HER)
			exits.append(player)
		for player: PlayerState in cold:
			_out(player, tick, events)
			exits.append(player)
		MatchVerdict.place(state, exits, tick, events, config.goal, schedule.end_tick(), spares)
	_ride_with_holders()
	state.tick += 1
	if state.phase == MatchState.Phase.COUNTDOWN and state.tick >= config.countdown_ticks:
		state.phase = MatchState.Phase.LIVE
	return events


## The ship stands as the pose says from this tick on — a collapsed platform is no
## surface — with the railings the match has broken and its crates where they are,
## and the sinking's telegraphs and events for this tick go out.
func _sinking_events(pose_now: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	_honour(pose_now)
	events.append_array(schedule.events_at(tick))


## Every piece she stands in under [param pose_now] honours it (Pieces.honour).
func _honour(pose_now: ShipPose) -> void:
	for piece: int in pose_now.standing:
		pieces.honour(piece, pose_now, state.broken_railings(), state.props)


## The tick's rules stand on piece [param piece]: its movement and hazards, made the
## first time.
func _stand_on(piece: int) -> void:
	if not _movements.has(piece):
		var deck := pieces.faces(piece).surfaces(Faces.Up.DECK)
		_hazards_of[piece] = Hazards.new(config, deck, piece, pieces)
		_movements[piece] = Movement.new(_rules, pieces.faces(piece), _hazards_of[piece], piece)
	_movement = _movements[piece]
	_hazards = _hazards_of[piece]


## The seats of [param seats] on piece [param piece].
static func _on(seats: Array[PlayerState], piece: int) -> Array[PlayerState]:
	var found: Array[PlayerState] = []
	for player: PlayerState in seats:
		if player.piece == piece:
			found.append(player)
	return found


## Every seat on a piece that has broken by this tick goes to the piece of it under it
## (Pieces) — the aft one where it stands aft of the cut, torn ends and all — and each
## piece new by this tick stands in the frame of the piece it broke from. A body
## standing keeps its footing where the new piece has a floor under it, and falls where
## the deck is torn away; a climber lets go.
func _rehome(pose_now: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	var standing := pose_now.standing
	for piece: int in standing:
		var from := piece
		while state.up[from] == -1:
			from = schedule.parent_of(from)
		state.up[piece] = state.up[from]
	for player: PlayerState in state.seats:
		if player.piece in standing:
			continue
		while not player.piece in standing:
			var aft := _children_of(player.piece)
			var x := player.pos.x
			player.piece = aft if x < schedule.span_of(aft).y else aft + 1
		player.climb_left = 0
		if player.body != PlayerState.Body.GROUNDED:
			continue
		var up: int = state.up[player.piece]
		var feet := Faces.to_frame(up) * player.pos
		player.surface = pieces.faces(player.piece).surfaces(up).under(feet, _rules.step_height)
		if player.surface == Surfaces.NONE:
			player.body = PlayerState.Body.AIRBORNE
			player.jumped = false
			player.fall_from = feet.y
			events.append(SimEvent.fell(tick, player.seat))


## Every bonus aboard the sea has taken by [param tick] is lost (#311): one at a spot no
## bonus may lie at any more — she has turned past its floor, or the piece of her it lies in
## is gone (_spot_pose) — or with water standing at it as the water stands now under
## [param pose_now] (Surfaces.wet).
func _bonuses_lost(pose_now: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	if state.bonuses.is_empty():
		return
	var kept: Array[BonusState] = []
	for bonus: BonusState in state.bonuses:
		var posed := _spot_pose(bonus.spot, pose_now, tick)
		if posed == null or surfaces.wet(config.ship.bonus_spots[bonus.spot].point, posed):
			events.append(SimEvent.bonus_lost(tick, bonus.kind, bonus.spot))
		else:
			kept.append(bonus)
	state.bonuses = kept


## The pose bonus spot [param spot] stands in on [param tick] under [param pose_now] — that
## of the piece of her it lies in — or null where no bonus may lie any more: on a piece
## standing on any face but her decks (Faces), its floors no floors since she turned past
## them; on a piece gone (SinkSchedule.piece_gone_tick); or on none, its floor torn away
## between two (Pieces.piece_at).
func _spot_pose(spot: int, pose_now: ShipPose, tick: int) -> ShipPose:
	var piece := pieces.piece_at(pose_now.standing, config.ship.bonus_spots[spot].point.x)
	if piece == -1 or state.up[piece] != Faces.Up.DECK:
		return null
	var gone := schedule.piece_gone_tick(piece)
	if gone != -1 and tick >= gone:
		return null
	return pose_now.of_piece(piece)


## The bonuses the plan brings aboard on [param tick] (BonusPlan), each to the open spot its
## pick lands on (_open_spots) — and none while the most are aboard, or with no spot open:
## that one never comes.
func _bonuses_come(pose_now: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	for planned: int in _plan.due(tick):
		if state.bonuses.size() >= config.bonus_rules.most_aboard:
			continue
		var open := _open_spots(pose_now, tick)
		if open.is_empty():
			continue
		var bonus := BonusState.new(planned, _plan.kinds[planned], _plan.spot_of(planned, open))
		state.bonuses.append(bonus)
		events.append(SimEvent.bonus_came(tick, bonus.kind, bonus.spot))


## Her open bonus spots on [param tick] under [param pose_now], by their index in her
## layout, in its order: those no bonus lies at, where one may still lie (_spot_pose), whose
## room has no water standing anywhere on its floor (Surfaces.floor_wet) — as the water
## stands now, never as the timeline has it next (D10).
func _open_spots(pose_now: ShipPose, tick: int) -> PackedInt32Array:
	var open := PackedInt32Array()
	for spot in config.ship.bonus_spots.size():
		var lies := false
		for bonus: BonusState in state.bonuses:
			lies = lies or bonus.spot == spot
		if lies:
			continue
		var posed := _spot_pose(spot, pose_now, tick)
		var room := config.ship.rooms[config.ship.bonus_spots[spot].room]
		if posed != null and not surfaces.floor_wet(room.area, room.floor_height, posed):
			open.append(spot)
	return open


## The first of the two pieces [param piece] broke into, the aft one; the fore one is
## the next.
func _children_of(piece: int) -> int:
	for other in pieces.count():
		if schedule.parent_of(other) == piece:
			return other
	return -1


## Every body of [param live] in the air or the sea that has left its piece's stretch and
## is over another piece's, carried across into that piece through the world (Pieces.carry).
func _carry(pose_now: ShipPose, live: Array[PlayerState]) -> void:
	var standing := pose_now.standing
	if standing.size() == 1:
		return
	for player: PlayerState in live:
		var loose := (
			player.body == PlayerState.Body.AIRBORNE or player.body == PlayerState.Body.SWIMMING
		)
		if (
			not loose
			or player.is_climbing()
			or pieces.piece_at(standing, player.pos.x) == player.piece
		):
			continue
		var world := pose_now.of_piece(player.piece).transform * player.pos
		for other: int in standing:
			var there := pose_now.of_piece(other).transform.affine_inverse() * world
			if other != player.piece and pieces.piece_at(standing, there.x) == other:
				Pieces.carry(player, player.piece, other, pose_now)
				break


## Whether every surface still standing on every piece of [param standing] is wade_depth
## under the sea, each read in the frame its tick stood in, [param framed_of] its pose.
func _sunk(standing: PackedInt32Array, framed_of: Dictionary[int, ShipPose]) -> bool:
	for piece: int in standing:
		if not _movements[piece].surfaces().sunk(framed_of[piece], _rules.wade_depth):
			return false
	return true


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
		if pressed & InputFrame.GRAB:
			_grabbing.append(player)
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


## A jump is a press, never a hold, from the ground gravity holds it to: idle, its brace
## let go, standing — a crawler never jumps — and with jump_cost of stamina to spend. It
## goes up along the world's up (D8) until its feet are its jump height (SeatRules) above
## where it left along the frame's — whatever the face's tilt, never over a railing — and
## gravity, the world's turned by the pose, brings it down where it rose, on its way
## across the face as it was walking.
func _jump(player: PlayerState, pose_now: ShipPose) -> void:
	if (
		player.body != PlayerState.Body.GROUNDED
		or player.action != PlayerState.Action.IDLE
		or player.last_buttons & InputFrame.BRACE
		or player.exhausted
		or player.stamina < _rules.jump_cost
		or pose_now.ship_gravity(_rules.gravity).y >= 0.0
		or _movement.height_of(player) < _rules.body_height
	):
		return
	_spend(player, _rules.jump_cost)
	# The take-off speed up the frame whose apex, stepped tick by tick as Movement's forces
	# and move step it, is the jump height: v² − g·dt·v − 2·g·h = 0; along the world's up,
	# gravity's own way back, it carries the share across the face that goes with it.
	var gravity := pose_now.ship_gravity(_rules.gravity)
	var fall := -gravity.y
	var drop := fall * Ticks.SECONDS_PER_TICK
	var height := _seat_rules(player).jump_height
	var rise := (drop + sqrt(drop * drop + 8.0 * fall * height)) * 0.5
	player.vel += Vector3(gravity.x * rise / gravity.y, 0.0, gravity.z * rise / gravity.y)
	player.vel.y = rise
	player.body = PlayerState.Body.AIRBORNE
	player.surface = Surfaces.NONE
	player.fall_from = player.pos.y
	player.jumped = true


## Who holds what, from the props: each seat's prop, or -1, and its rules with it.
func _count_hands() -> void:
	_hands.resize(state.seats.size())
	_hands.fill(-1)
	_rules_by_seat.resize(state.seats.size())
	_rules_by_seat.fill(_bare_rules)
	for prop: PropState in state.props:
		if prop.holder != -1:
			_hold(prop.holder, prop.prop)


## [param seat]'s hands hold [param prop] from now — -1 for none — and its rules are as
## they stand for a seat holding that (SeatRules).
func _hold(seat: int, prop: int) -> void:
	_hands[seat] = prop
	if prop == -1:
		_rules_by_seat[seat] = _bare_rules
		return
	var kind := _kinds[prop]
	if not _held_rules.has(kind):
		_held_rules[kind] = SeatRules.of(_rules, kind)
	_rules_by_seat[seat] = _held_rules[kind]


## The kind of prop [param player] holds, or null for empty hands.
func _held_kind(player: PlayerState) -> PropKind:
	var held := _hands[player.seat]
	return _kinds[held] if held != -1 else null


## The rules as they stand for [param player] now (SeatRules), by what its hands hold:
## the tick reads every rule that may differ from seat to seat here, never off the brawl
## rules.
func _seat_rules(player: PlayerState) -> SeatRules:
	return _rules_by_seat[player.seat]


## Every held prop where its holder's feet are now, as the snapshot draws it.
func _ride_with_holders() -> void:
	for prop: PropState in state.props:
		if prop.holder != -1:
			prop.pos = state.seats[prop.holder].pos


## The tick's Grab presses (#273), as _intent read them, each doing what GrabReach says a
## press does: taking the bonus in reach, whatever the hands hold (#307); else letting go of
## the prop in the hands; else taking the prop in reach. Of two seats taking one bonus or
## one prop, the nearer takes it — of two as near, the lower — and the other takes nothing.
func _grabs(tick: int, events: Array[SimEvent]) -> void:
	var claims: Dictionary[int, PlayerState] = {}
	var bonus_claims: Dictionary[int, PlayerState] = {}
	for player: PlayerState in _grabbing:
		var press := _reach.press(
			player,
			state.up[player.piece],
			_movement.height_of(player),
			_hands[player.seat],
			state.bonuses,
			state.props,
			_here()
		)
		if press.aboard != -1:
			var spot := config.ship.bonus_spots[state.bonuses[press.aboard].spot]
			_claim(bonus_claims, press.aboard, player, spot.point)
		elif press.let_go != -1:
			events.append(SimEvent.prop_let_go(tick, player.seat, press.let_go))
			_let_go(player, tick, events)
		elif press.prop != -1:
			_claim(claims, press.prop, player, state.props[press.prop].pos)
	_grabbing.clear()
	_take_bonuses(bonus_claims, tick, events)
	var claimed := claims.keys()
	claimed.sort()
	for prop: int in claimed:
		var taken := state.props[prop]
		var seat := claims[prop].seat
		taken.body = PropState.Body.HELD
		taken.holder = seat
		taken.vel = Vector3.ZERO
		taken.surface = Surfaces.NONE
		_hold(seat, prop)
		events.append(SimEvent.prop_grabbed(tick, seat, prop))


## [param player] claiming [param claimed] — a bonus aboard, or a prop — lying at
## [param at], in [param claims], each one's claimant so far: the claim is its with none
## made yet, or standing nearer than the seat that made it — so of two as near, the lower
## seat, which claims first, keeps it.
static func _claim(
	claims: Dictionary[int, PlayerState], claimed: int, player: PlayerState, at: Vector3
) -> void:
	if not claims.has(claimed) or _nearer(player, claims[claimed], at):
		claims[claimed] = player


## Each bonus aboard [param claims] names a taker of — by its place among those aboard —
## used up at once: gone from aboard, and its kind its taker's bonus, replacing any it had.
func _take_bonuses(
	claims: Dictionary[int, PlayerState], tick: int, events: Array[SimEvent]
) -> void:
	var taken := claims.keys()
	taken.sort()
	for index: int in taken:
		var bonus := state.bonuses[index]
		claims[index].bonus = bonus.kind
		events.append(SimEvent.bonus_taken(tick, claims[index].seat, bonus.kind, bonus.spot))
	taken.reverse()
	for index: int in taken:
		state.bonuses.remove_at(index)


## [param player] lets go of the prop it holds: at its feet, falling from there — lost
## at once where its piece stands on any face but her decks, where nothing stays stowed
## (Hazards).
func _let_go(player: PlayerState, tick: int, events: Array[SimEvent]) -> void:
	var held := state.props[_hands[player.seat]]
	_hold(player.seat, -1)
	held.holder = -1
	held.vel = Vector3.ZERO
	held.surface = Surfaces.NONE
	if state.up[player.piece] != Faces.Up.DECK:
		_lose_prop(held, tick, events)
		return
	held.body = PropState.Body.AIRBORNE
	held.pos = player.pos


## [param prop] gone into the sea, for the rest of the match.
static func _lose_prop(prop: PropState, tick: int, events: Array[SimEvent]) -> void:
	prop.body = PropState.Body.LOST
	prop.holder = -1
	prop.surface = Surfaces.NONE
	prop.vel = Vector3.ZERO
	events.append(SimEvent.prop_lost(tick, prop.prop))


## Whether [param player] stands nearer [param point] (x/z) than [param other] does.
static func _nearer(player: PlayerState, other: PlayerState, point: Vector3) -> bool:
	var at := Vector2(point.x, point.z)
	var mine := Vector2(player.pos.x, player.pos.z).distance_squared_to(at)
	return mine < Vector2(other.pos.x, other.pos.z).distance_squared_to(at)


## Tap or hold is read here, from ticks held (D3): a shove released after its
## windup fires as a quick shove; one still held at charge_threshold becomes a
## charge, which fires, paid for, when it is let go.
func _advance_action(player: PlayerState, live: Array[PlayerState]) -> void:
	var held := player.last_buttons & InputFrame.SHOVE != 0
	match player.action:
		PlayerState.Action.WINDUP:
			if held and player.action_ticks >= _charge_threshold_ticks:
				if (
					player.exhausted
					or player.stamina < _rules.charge_cost
					or not _seat_rules(player).may_charge
				):
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
		_candidates(live, PackedVector2Array([Vector2(player.pos.x, player.pos.z)])),
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
			and _seat_rules(player).may_brace
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
## freezes its shover and its target for a hit-stop, and the knockback — the share of it
## its target's rules take (SeatRules.knockback_share), before a brace takes its own
## off — and the recoil wait for it to end; a crate takes its share of the knockback at once
## (Hazards.shove), and its shover rocks and stops as for a body. A charged shove landing
## on a body holding a prop its kind lets a charge knock loose knocks it out of its hands
## at its feet (#273).
func _shoves(live: Array[PlayerState], tick: int, events: Array[SimEvent]) -> void:
	var attempts: Array[ShoveResolver.Attempt] = []
	var origins := PackedVector2Array()
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
			origins.append(Vector2(player.pos.x, player.pos.z))
	if attempts.is_empty():
		return
	var hits := ShoveResolver.resolve(
		attempts,
		_candidates(live, origins),
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
	var charged_by := hit_by.duplicate()
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
		speed *= _seat_rules(target).knockback_share
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
		if shover.is_charged() and charged_by[hit.target] == -1:
			charged_by[hit.target] = hit.shover
	var crate_hits := ShoveResolver.resolve(
		attempts,
		_hazards.candidates(state, count, origins, _rules.shove_reach),
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
			var kind := _held_kind(player)
			if charged_by[seat] != -1 and kind != null and kind.loose_on_charge:
				events.append(SimEvent.knocked_loose(tick, seat, _hands[seat], charged_by[seat]))
				_let_go(player, tick, events)
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
## swims and does not climb, its cold meter drains — at pocket_cold_rate of the open
## water's with its head in trapped air (Q22), at the sea_cold_rate of a prop it holds
## that keeps it afloat (#273), the lower of the two where both do — and it is out when
## that is empty, but for a seat whose bonus gives a spare meter (Double life, #307): that
## fills it again, once, and the bonus is spent. Out of the sea the meter refills at
## cold_regen. A seat frozen in a hit-stop holds its meter, and neither falls in, stands,
## climbs nor settles until the stop ends. Returns who went out.
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
		_movement.start_climb(player, pose_now, _seat_rules(player))
		if player.is_climbing():
			continue
		var head := player.pos + Vector3.UP * _rules.head_height(_movement.height_of(player))
		var rate := _rules.pocket_cold_rate if pose_now.in_pocket(head) else 1.0
		rate = minf(rate, _seat_rules(player).sea_cold_rate)
		player.cold = maxf(player.cold - dt * rate, 0.0)
		if player.cold == 0.0 and _has_spare(player):
			player.cold = _rules.cold_meter
			events.append(SimEvent.double_life_spent(tick, player.seat, player.bonus))
			player.bonus = -1
		elif player.cold == 0.0:
			_out(player, tick, events)
			exits.append(player)
	return exits


## Whether [param player]'s bonus gives it a spare cold meter, unspent (BonusKind).
func _has_spare(player: PlayerState) -> bool:
	return player.bonus != -1 and config.bonus_rules.kinds[player.bonus].spare_meter


## Per seat, the seconds of cold an unspent spare meter its bonus gives it adds — a full
## meter (MatchVerdict.cold_left) — counted for [param seats] alone, none for any other; and
## none at all in a match without bonuses.
func _spares(seats: Array[PlayerState]) -> PackedFloat64Array:
	var spares := PackedFloat64Array()
	if config.bonus_rules == null:
		return spares
	spares.resize(state.seats.size())
	for player: PlayerState in seats:
		if _has_spare(player):
			spares[player.seat] = _rules.cold_meter
	return spares


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


## Out of the match by [param cause], and whatever it held into the sea with it; its bonus
## goes with it (#307).
func _out(
	player: PlayerState, tick: int, events: Array[SimEvent], cause := PlayerState.Cause.COLD
) -> void:
	if _hands[player.seat] != -1:
		_lose_prop(state.props[_hands[player.seat]], tick, events)
		_hold(player.seat, -1)
	player.bonus = -1
	player.body = PlayerState.Body.OUT
	player.out_tick = tick
	player.out_cause = cause
	player.vel = Vector3.ZERO
	player.stagger_ticks = 0
	player.hitstop = 0
	player.held_vel = Vector3.ZERO
	player.bracing = false
	player.climb_left = 0
	_enter(player, PlayerState.Action.IDLE)


## The bodies of [param live] a shove from any of [param origins] (x/z) could land on,
## in seat order (Movement.around): none farther could.
func _candidates(
	live: Array[PlayerState], origins: PackedVector2Array
) -> Array[ShoveResolver.Candidate]:
	var candidates: Array[ShoveResolver.Candidate] = []
	for player: PlayerState in _movement.around(live, origins, _rules.shove_reach):
		candidates.append(_candidate(player))
	return candidates


## [param player] as a shove reaches it: as tall as it is where it is — a crawler
## lower, out of reach of the deck over it.
func _candidate(player: PlayerState) -> ShoveResolver.Candidate:
	return ShoveResolver.Candidate.new(
		player.seat, player.pos, _rules.body_radius, _movement.height_of(player)
	)
