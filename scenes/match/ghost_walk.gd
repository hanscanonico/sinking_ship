class_name GhostWalk
extends RefCounted
## The ghost (GLOSSARY: Ghost, #655): a view a seat out of the match, a watcher and the
## replay viewer may take in place of a seat's eyes or the free camera, walking her decks
## as a seat in the match does. Its body moves by the living seat's own rules — the sim's
## Movement, step for step, on a body of its own in a match of its own, through Surfaces
## (D6): it walks, jumps, takes the stairs, is held by walls, doors and railings and
## stands on the tilting deck, its eyes a seat's height over its feet. Its Movement is a
## ghost's: water neither slows it nor drowns it, no heel or trim slides it, and it shoves,
## slams and breaks nothing.
##
## Presentation only, as the free camera is: it stands on its own Surfaces, honoured with
## the snapshot drawn — the sim's stay the sim's — and nothing of it is ever sent, kept in
## a snapshot, a digest or a replay; no rule and no bot reads it, nobody sees it. Its
## ticks are its own, one every Ticks.SECONDS_PER_TICK of the frames it is walked through,
## on her as the snapshot drawn has her. It cannot leave her: off her decks, or with the
## piece of her it stands on gone, walk() says so and the view goes to the free camera.

## The most ticks one frame walks it: a hitch never runs it far on its own.
const MOST_TICKS := 4

## Every one whose ship is being made on a worker thread (build_ahead): kept until that is
## waited for, so none is freed while its thread works on it, and the game, quitting,
## waits for them all.
static var _under_way: Array[GhostWalk] = []

## Whether the view is the ghost's.
var active := false
## Its look and the frames it walks by, as the local seat's are (LocalInputSource): yaw
## in the plane of the face it stands on, pitch above the horizon, and the move relative
## to the look.
var look: LocalInputSource
## Its body, in the space of the piece of her it is on, as a snapshot keeps a seat's.
var body: PlayerState

var _config: MatchConfig
var _rules: BrawlRules
var _schedule: SinkSchedule
var _settings: ViewSettings
## Its rules: a seat's with empty hands and no bonus (SeatRules).
var _seat_rules: Array[SeatRules] = []
## Its own ship, made on a worker thread as soon as it may be walked (keep), else the
## first time it walks: her faces and her pieces, and per piece of her the Movement it
## walks by there (a ghost's). Never read while _task is the thread's still.
var _faces: Faces
var _pieces: Pieces
var _task := -1
var _movements: Dictionary[int, Movement] = {}
## Its match of one: its body, and the frame each piece of her stands in for it.
var _state: MatchState
## Where its feet were a tick ago, and how far into the next tick its frames have run, in
## seconds: what feet() draws between them.
var _from := Vector3.ZERO
var _owed := 0.0
## The crates the snapshot last honoured had, and its entries they were made from.
var _crates: Array[PropState] = []
var _crates_of: Array = []
## The snapshot its Surfaces were last honoured with, at its tick, on its piece: honoured
## again only for another.
var _honoured: Dictionary
var _honoured_tick := -1
var _honoured_piece := -1


func _init(config: MatchConfig, schedule: SinkSchedule, settings: ViewSettings = null) -> void:
	_config = config
	_rules = config.rules
	_schedule = schedule
	_settings = settings if settings != null else ViewSettings.new()
	_seat_rules.append(SeatRules.of(_rules, null))


## Stands it at [param at] — feet in the space of piece [param piece] of her — on the
## highest floor under it there as [param snapshot] has her, looking along
## [param ahead] (in that piece's space), and makes the view its own. False, and the view
## left as it was, when nothing of her is under [param at]: in the sea off her, on a piece
## of her gone.
func start(snapshot: Dictionary, at: Vector3, piece: int, ahead: Vector3) -> bool:
	if snapshot.is_empty():
		return false
	_ship()
	var placed := PlayerState.new(0)
	placed.pos = at
	placed.piece = piece
	placed.body = PlayerState.Body.AIRBORNE
	var state := MatchState.new()
	state.seats.append(placed)
	state.up.resize(_pieces.count())
	var ups: Array = snapshot["up"]
	for index in state.up.size():
		state.up[index] = ups[index] if index < ups.size() else -1
	var tick: int = snapshot["tick"]
	var pose := _schedule.pose_at(tick)
	if not _rehome(placed, state, pose, tick):
		return false
	_honour(snapshot, pose, placed.piece)
	var movement := _movement_of(placed.piece)
	var events: Array[SimEvent] = []
	movement.face(state, pose.of_piece(placed.piece), tick, events)
	var here := movement.surfaces()
	var floor := here.landing(placed.pos + Vector3.UP * _rules.step_height)
	if floor != Surfaces.NONE:
		placed.pos.y = here.height_at(floor, placed.pos)
		placed.body = PlayerState.Body.GROUNDED
		placed.surface = floor
	movement.unface(state)
	if floor == Surfaces.NONE:
		return false
	body = placed
	_state = state
	_from = body.pos
	_owed = 0.0
	var level := Faces.to_frame(up()) * ahead
	look = LocalInputSource.new(0, atan2(level.z, level.x), _settings)
	active = true
	return true


## Back to a seat's eyes, or on to another view.
func leave() -> void:
	active = false


## Off once the view may not be a ghost's, while [param spectating] says it is not; while
## it may be, its ship made ahead, on a worker thread where a ship is dressed on one
## (ShipDressing.threaded): her Surfaces and faces take the Titanic most of a second, a
## hitch on the frame of the first switch to it. A thread's work done is seen through.
func keep(spectating: bool) -> void:
	active = active and spectating
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish()
	elif spectating and ShipDressing.threaded():
		build_ahead()


## Starts making its ship on a worker thread, unless that is under way or done; any other
## match's ghost whose ship is made by now is let go.
func build_ahead() -> void:
	if _task >= 0 or _faces != null:
		return
	for ghost: GhostWalk in _under_way.duplicate():
		if WorkerThreadPool.is_task_completed(ghost._task):
			ghost._finish()
	_under_way.append(self)
	_task = WorkerThreadPool.add_task(_make_ship, false, "Making the ghost's ship")


## Waits for every ship being made ahead: what the game does as it quits.
static func finish_all() -> void:
	for ghost: GhostWalk in _under_way.duplicate():
		ghost._finish()


## How many are making their ship on a worker thread, not yet waited for.
static func under_way() -> int:
	return _under_way.size()


func _finish() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_under_way.erase(self)


## Walks it [param delta] seconds on as [param snapshot] has her, one tick for every
## Ticks.SECONDS_PER_TICK of them (at most MOST_TICKS), each by the frame its look makes
## of the keys and the pad. False once it is off her (walk).
func advance(snapshot: Dictionary, delta: float) -> bool:
	_owed += delta
	var ticks := 0
	while _owed >= Ticks.SECONDS_PER_TICK:
		_owed -= Ticks.SECONDS_PER_TICK
		ticks += 1
		if ticks > MOST_TICKS:
			_owed = 0.0
			break
		if not walk(snapshot, look.next_frame(snapshot["tick"])):
			return false
	return true


## One tick of its walk by [param frame], on her as [param snapshot] has her: its move,
## its look and its buttons taken as a seat's are, a jump pressed taken as a seat's is,
## then Movement's forces, move and ground, as MatchSim steps a live seat. False — and the
## view no longer a ghost's — once it is off her: falling with nothing of her under it,
## or on a piece of her gone.
func walk(snapshot: Dictionary, frame: InputFrame) -> bool:
	var tick: int = snapshot["tick"]
	var pose := _schedule.pose_at(tick)
	_from = body.pos
	if not _rehome(body, _state, pose, tick):
		active = false
		return false
	_honour(snapshot, pose, body.piece)
	var movement := _movement_of(body.piece)
	var events: Array[SimEvent] = []
	var was := up()
	var framed := movement.face(_state, pose.of_piece(body.piece), tick, events)
	body.last_move = frame.move
	body.last_look = frame.look_yaw
	body.facing = InputFrame.yaw_angle(frame.look_yaw)
	body.last_buttons = frame.buttons
	var pressed := body.last_buttons & ~body.prev_buttons
	body.prev_buttons = body.last_buttons
	if pressed & InputFrame.JUMP and movement.can_leap(body, framed):
		movement.leap(body, framed, _seat_rules[0].jump_height)
	var bodies: Array[PlayerState] = [body]
	movement.forces(bodies, framed, _seat_rules)
	var feet_before := movement.move(_state, bodies, framed, tick, events)
	movement.ground(bodies, tick, events, feet_before)
	var off := (
		body.body == PlayerState.Body.AIRBORNE
		and movement.surfaces().landing(body.pos) == Surfaces.NONE
	)
	movement.unface(_state)
	if up() != was:
		look.turn_face(was, up(), Basis.IDENTITY)
		_from = body.pos
	if off:
		active = false
	return not off


## Its feet as drawn now, in the space of its piece: between where the last tick found them
## and where the one before did, as far as its frames have run into the next.
func feet() -> Vector3:
	return _from.lerp(body.pos, clampf(_owed / Ticks.SECONDS_PER_TICK, 0.0, 1.0))


## The frame it stands in (Faces.Up): its piece's.
func up() -> int:
	return _state.up[body.piece]


## The layout of the piece of her it is on: hers, cut to that piece (Pieces.layout).
func layout() -> ShipLayout:
	return _pieces.layout(body.piece)


## How tall it stands where it is, over a standing body's height: less in a crawl space.
func stature() -> float:
	var framed := Faces.to_frame(up()) * body.pos
	return _rules.height_at(_movement_of(body.piece).surfaces(), framed) / _rules.body_height


## Its own Surfaces, faces and pieces of her, made once (Pieces), as MatchSim makes hers:
## here, unless build_ahead's worker has, waited for first.
func _ship() -> void:
	_finish()
	_make_ship()


func _make_ship() -> void:
	if _faces != null:
		return
	var capsized := SeaPhysics.load_default().capsized_movement
	var deck := Surfaces.new(_config.ship)
	var faces := Faces.new(_config.ship, deck, _rules.brace_holds_to, capsized)
	_pieces = Pieces.new(_config.ship, _schedule, faces, _rules.brace_holds_to, capsized)
	_faces = faces


## The Movement it walks by on piece [param piece] of her, made the first time: a ghost's,
## with no currents, falls or hazards.
func _movement_of(piece: int) -> Movement:
	if not _movements.has(piece):
		var made := Movement.new(_rules, _pieces.faces(piece), null, piece)
		made.ghost = true
		_movements[piece] = made
	return _movements[piece]


## [param player] of [param state] on the piece of her under it once the one it stood on
## has broken by [param tick] under [param pose], as MatchSim's _rehome moves a seat — the
## new piece in the frame of the one it broke from; false once that piece is gone, or none
## of her stands.
func _rehome(player: PlayerState, state: MatchState, pose: ShipPose, tick: int) -> bool:
	var standing := pose.standing
	if standing.is_empty():
		return false
	while not player.piece in standing:
		var aft := -1
		for other in _pieces.count():
			if _schedule.parent_of(other) == player.piece:
				aft = other
				break
		if aft == -1:
			return false
		var from := player.piece
		player.piece = aft if player.pos.x < _schedule.span_of(aft).y else aft + 1
		if state.up[player.piece] == -1:
			state.up[player.piece] = state.up[from]
		player.surface = Surfaces.NONE
		if player.body == PlayerState.Body.GROUNDED:
			player.body = PlayerState.Body.AIRBORNE
			player.jumped = false
			player.fall_from = (Faces.to_frame(state.up[player.piece]) * player.pos).y
	var gone := _schedule.piece_gone_tick(player.piece)
	return gone == -1 or tick < gone


## Its own Surfaces of piece [param piece] of her, honoured with her [param pose], the
## railings broken and the crates as [param snapshot] has them (Pieces.honour).
func _honour(snapshot: Dictionary, pose: ShipPose, piece: int) -> void:
	var tick: int = snapshot["tick"]
	if is_same(snapshot, _honoured) and tick == _honoured_tick and piece == _honoured_piece:
		return
	_honoured = snapshot
	_honoured_tick = tick
	_honoured_piece = piece
	var entries: Array = snapshot["props"]
	if not is_same(_crates_of, entries):
		_crates = HudAnswers.kept_crates(entries, _crates_of, _crates)
		_crates_of = entries
	var broken := MatchState.broken_in(snapshot["railing_hp"])
	_pieces.honour(piece, pose, broken, _crates)
