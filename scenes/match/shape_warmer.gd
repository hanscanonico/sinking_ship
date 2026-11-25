class_name ShapeWarmer
extends RefCounted
## Builds her shapes into the match's ShapeStock on a worker thread as her load ends,
## ahead of any reader (#563): each piece she breaks into — its cut layout, its decks'
## Surfaces, its solids — and each frame a piece of her turns onto as the timeline has her
## turn (SinkSchedule.placed_at, Faces.up_after), again for each way her watertight doors
## come to rest while it is turned, in the order she reaches them. Without it the sim, the
## HUD and the bots each build them the frame she breaks, rolls or a door of a turned
## piece fails: seconds of tens of thousands of plates. What it builds is what a reader
## would have built (ShapeStock), so nothing the match does depends on it having run.
## It stops once the match it warms for is gone.

## How many ticks apart the timeline is read for the frames her pieces turn onto: a
## frame held for less may be missed, and is then built by its first reader.
const STRIDE := 15

static var _tasks: Array[int] = []
static var _guard := Mutex.new()
## Set as the game quits: every warm task stops at its next shape, and is waited for.
static var _stopping := false


## Starts warming [param sim]'s match: its water's boxes (ShipPieces.warm_water), then
## its shapes, unless it has no physical sinking.
static func warm(sim: MatchSim) -> void:
	ShipPieces.warm_water(sim)
	_reap()
	var root := (Engine.get_main_loop() as SceneTree).root
	if not root.tree_exiting.is_connected(_stop_all):
		root.tree_exiting.connect(_stop_all)
	if sim.schedule.timeline() == null:
		return
	var config := sim.config
	var task := WorkerThreadPool.add_task(
		_warm.bind(weakref(config), config.shapes(), sim.schedule, sim.faces), false, "Ship shapes"
	)
	_guard.lock()
	_tasks.append(task)
	_guard.unlock()


## On a worker: every piece's shapes, then every frame foreseen, each built into
## [param stock] while [param match_config] is still played.
static func _warm(
	match_config: WeakRef, stock: ShapeStock, schedule: SinkSchedule, whole: Faces
) -> void:
	var config: MatchConfig = match_config.get_ref()
	if config == null:
		return
	var rules := config.rules
	var keep := rules.brace_holds_to
	var pieces := Pieces.new(config.ship, schedule, whole, keep, true, stock)
	# The bots' own (BotFloors): each piece's faces and walk graphs, theirs to claim.
	var bots: Pieces = null
	if config.humans < config.seats:
		bots = Pieces.new(config.ship, schedule, whole, keep, true, stock)
	config = null
	for piece in range(1, schedule.piece_count()):
		if _stopping or match_config.get_ref() == null:
			return
		pieces.faces(piece)
		if bots != null:
			var faces := bots.faces(piece)
			var graph := WalkGraph.new(
				faces.layout(Faces.Up.DECK), faces.surfaces(Faces.Up.DECK), rules
			)
			stock.offer([&"walk", piece, Faces.Up.DECK], [faces, graph])
	var ups := {0: Faces.Up.DECK}
	var built := {}
	for tick in range(0, schedule.end_tick() + STRIDE, STRIDE):
		if _stopping or match_config.get_ref() == null:
			return
		var pose := schedule.placed_at(tick)
		for piece: int in pose.standing:
			var from := piece
			while not ups.has(from):
				from = schedule.parent_of(from)
			var own := pose.of_piece(piece)
			var up := Faces.up_after(own, ups[from], keep)
			ups[piece] = up
			if up == Faces.Up.DECK:
				continue
			# Each way her doors stand at rest while the piece is turned is a frame of its
			# own: a door that fails or jams there has its frame built again (Faces).
			var shut := pieces.faces(piece).shut_of(own)
			if built.has([piece, up, shut]) or not Faces.at_rest(shut):
				continue
			built[[piece, up, shut]] = true
			pieces.faces(piece).stock_frame(up, shut)
			if bots != null:
				var made := bots.faces(piece).frame_of(up, shut)
				var graph := WalkGraph.new(made[0], made[1], rules)
				stock.offer([&"walk", piece, up, shut], [made[0], made[1], graph])


## Stops every warm task and waits for it, the game quitting: none may outlive it.
static func _stop_all() -> void:
	_stopping = true
	_guard.lock()
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()
	_guard.unlock()


## Sees through every warm task that is over.
static func _reap() -> void:
	_guard.lock()
	for task: int in _tasks.duplicate():
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			_tasks.erase(task)
	_guard.unlock()
