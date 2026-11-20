class_name ShipDressing
extends RefCounted
## A ship dressed (ShipArt) before she is drawn: a match's — the whole of her, or, when
## her sinking breaks her, a ShipArt per stretch between her weak spots (ShipPieces) — or
## the menu's at rest (at_rest), built outside the tree for the scene to take as they are
## (MatchView.setup). Dressing a ship takes seconds, a liner's many, so a match's is
## dressed on a worker thread (start) while the frames go on — the countdown held, the
## room still showing — and only a tool's or a test's on the caller's (dress_now).
##
## One dressing builds at a time: ShipModel's cache of models is filled as she is dressed,
## never from two threads at once. A dressing under way reads some meshes back from the
## RenderingServer, which answers it only as the main thread's frames flush their work:
## so the main thread never just waits on one — dress_now, finish and finish_all keep that
## work flowing while they wait — and every one is finished before the game quits
## (finish_all), or its thread would wait on frames that never come.
##
## A match that breaks her is dressed as its StretchPlan has it: when her stretches can be
## built behind the match, her art is the whole of her, and done() says so as soon as it
## is — the match can start — while the stretches go on being built on the same thread,
## taken once they all are (take_stretches) to draw her in their place (MatchView).
##
## A match's dressing started ahead of her sinking (start) makes what of her the sinking
## has no say in — her sea's maps, and her art's frame as it is drawn when nothing of her
## falls (_frame_ahead) — while that is baked, then waits to be told it is made
## (sinking_made) before it reads her schedule: the rest of her art is drawn from it, what
## falls and what the hit left open. Once it has read her schedule (schedule_read), her match may be
## served beside the rest of her dressing.
##
## Where nothing is drawn — headless, as every test and tool runs — she is dressed on the
## caller's thread instead (threaded): there the RenderingServer is Godot's dummy, whose
## stores of meshes, multimeshes, materials and shaders hand out their RIDs without a lock
## up to 4.7.2 (godotengine/godot@5a4e2e8 locks them, on master). A mesh her thread made as
## the main thread made one could take the same RID, and both were broken (#571). Started,
## she is dressed at once — or, started ahead, as she is told her sinking is made.

## How long the main thread sleeps between flushes as it waits on a dressing, in µs.
const WAIT_USEC := 200
## How long a dressing started ahead sleeps between looks at whether her sinking is made,
## in µs.
const SINKING_LOOK_USEC := 20000

## Held by whichever dressing is building.
static var _building := Mutex.new()
## Every dressing started whose task has not been seen through: kept alive meanwhile.
static var _under_way: Array[ShipDressing] = []

## The match whose ship this dresses, as its sinking has her; null for one at rest.
var config: MatchConfig
## The height above which her art is cut away (ShipArt.cut_above).
var cut_above: float
## Her art: the stretch the ship's own node draws (ShipPieces.first_span) — all of her
## when she never breaks, or until her stretches are in (plan) — and the rest, aft to
## fore, each to hang on its piece: built before the match unless the plan has them later
## (take_stretches).
var art: ShipArt
var stretches: Array[ShipArt] = []
## Which of her stretches are built before the match starts, and which behind it; null
## for a ship at rest.
var plan: StretchPlan

var _ship: ShipLayout
var _rules: BrawlRules
var _task := -1
var _dressed := false
## Guards _built and _dropped between the dressing's thread and the main one.
var _guard := Mutex.new()
var _built := false
var _dropped := false
## Her art and every stretch built before the match is: done() may say she is dressed.
var _art_ready := false
## The stretches built behind the match are no longer wanted: those not yet built are
## not, and those built are freed (stop_later).
var _stop_later := false
## Per stretch, aft to fore, the one built (null until it is), and whether they have
## been taken (take_stretches).
var _cut: Array[ShipArt] = []
var _handed := false
## What her stretches are built of: where each runs (ShipPieces.cuts_of), worked out
## before her match starts — after, her schedule is the match's to read —, her layout bare
## of props, one ShipSpace of it for them all, and what of her the sinking can fell, fail
## and leave open.
var _cuts := PackedVector2Array()
var _bare: ShipLayout
var _space: ShipSpace
var _falls: Array[StringName] = []
var _fails := PackedInt32Array()
var _ports := PackedVector3Array()
## Whether she is started before her sinking is made (start), and whether it is made
## since (sinking_made); whether the dressing is done reading her schedule.
var _ahead := false
var _made := false
var _read := false
## Whether she was started ahead where she is dressed on the caller's thread (threaded):
## dressed as she is told her sinking is made.
var _waits_here := false
## Whether her art's frame (ShipArt.build_frame) was drawn ahead of her sinking
## (_frame_ahead).
var _framed := false
## One ShipSpace of her layout for her sea's maps and her art (ShipArt.shared_space),
## each asking what the other worked out; made as she is first dressed, on her
## dressing's thread, which alone asks it.
var _shared: ShipSpace


## [param dressed]'s ship to dress as its match draws her, cut away above [param cut] as
## the observer's view is (ShipArt.cut_above).
func _init(dressed: MatchConfig, cut: float = INF) -> void:
	config = dressed
	cut_above = cut
	if dressed != null:
		_ship = dressed.ship
		_rules = dressed.rules
	_new_art()


## A new art for her, as yet undrawn.
func _new_art() -> void:
	art = ShipArt.new()
	art.name = "ShipArt"
	art.cut_above = cut_above


## [param ship] to dress whole and at rest — nothing of her to fall, fail or stand open —
## to [param rules]' railings and bodies: the menu's backdrop's.
static func at_rest(ship: ShipLayout, rules: BrawlRules) -> ShipDressing:
	var dressing := ShipDressing.new(null)
	dressing._ship = ship
	dressing._rules = rules
	return dressing


## Dresses her on a worker thread where she may be (threaded), else here; done() says
## when she is. Returns itself. A match's
## dressing started [param ahead] of her sinking — still baking, never to be touched —
## makes her sea's maps at once, and reads her schedule only once told it is made
## (sinking_made).
func start(ahead := false) -> ShipDressing:
	if _task >= 0 or _dressed or _waits_here:
		return self
	_ahead = ahead and config != null
	if not threaded():
		_waits_here = _ahead
		if not _ahead:
			dress_now()
		return self
	_see_through()
	# A match's dressing begun means the match before is over: its stretches are no longer
	# wanted.
	for other: ShipDressing in _under_way:
		if config != null and other.config != null:
			other.stop_later()
	_under_way.append(self)
	_task = WorkerThreadPool.add_task(_dress, false, "Dressing a ship")
	return self


## Her match's sinking is made: a dressing started ahead of it may read her schedule.
func sinking_made() -> void:
	_guard.lock()
	_made = true
	_guard.unlock()
	if _waits_here:
		_waits_here = false
		dress_now()


## Whether the dressing is done reading her match's schedule: her match may be served
## (MatchScene.serve) beside the rest of it.
func schedule_read() -> bool:
	if done():
		return true
	_guard.lock()
	var read := _read
	_guard.unlock()
	return read


## Dresses her here and now, on the caller's thread — after any dressing under way.
func dress_now() -> void:
	if _task >= 0 or _dressed:
		return
	_dress()
	_dressed = true


## Waits until she is dressed, started or not: dressed here when she was not started.
func finish() -> void:
	if _task < 0:
		dress_now()
		return
	while not done():
		_flush()


## Whether she is dressed: art — and stretches, but those her plan builds later — are
## ready to take.
func done() -> bool:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_dressed = true
		_under_way.erase(self)
	elif _task >= 0 and not _dressed:
		_guard.lock()
		_dressed = _art_ready
		_guard.unlock()
	return _dressed


## Whether every stretch of hers is built, those her plan builds behind the match too.
func stretched() -> bool:
	return done() and _task < 0


## Her stretches, aft to fore, once every one is built (stretched) when her art is all of
## her (StretchPlan.whole): the first to take the art's place, the rest each to hang on
## its piece; none before then, nor twice.
func take_stretches() -> Array[ShipArt]:
	var found: Array[ShipArt] = []
	if plan == null or not plan.whole or _handed or not stretched():
		return found
	_handed = true
	found.assign(_cut)
	_cut.clear()
	return found


## Stops building the stretches her plan builds behind the match, once the one under way
## is: those built are freed, never taken. Her art is left as it is.
func stop_later() -> void:
	_guard.lock()
	_stop_later = true
	var built := _built or _task < 0
	_guard.unlock()
	if built and not _handed:
		_free_stretches()


## Whether this dresses [param other]'s ship as its match draws her, cut away above
## [param cut]: its own match's, or one of the same ship, rules, scenario and seed, whose
## sinking — all of her art that is the match's — is the same (D4). Play makes a match of
## its own on the one dressed on the menu (NextMatch.chosen), which this fits.
func fits(other: MatchConfig, cut: float = INF) -> bool:
	if config == null or other == null or cut_above != cut:
		return false
	return (
		config == other
		or (
			other.ship == config.ship
			and other.rules == config.rules
			and other.scenario == config.scenario
			and other.match_seed == config.match_seed
		)
	)


## Lets her go, never taken: her nodes are freed — once she is dressed, when she is
## still being.
func drop() -> void:
	_guard.lock()
	_dropped = true
	var built := _built or _task < 0
	_guard.unlock()
	if built:
		_free_nodes()
	# Let go before her sinking was made, she is done with, as her thread would be.
	if _waits_here:
		_waits_here = false
		_dressed = true


## Finishes every dressing under way, the main thread's frames' work flowing meanwhile:
## what the game does before it quits.
static func finish_all() -> void:
	for dressing: ShipDressing in _under_way.duplicate():
		dressing.stop_later()
		while not dressing.stretched():
			_flush()


## How many dressings are under way, their tasks not yet seen through (finish_all).
static func under_way() -> int:
	return _under_way.size()


## Whether a ship is dressed on a worker thread: never headless, where the dummy
## RenderingServer cannot take RIDs made on two threads at once (the class's note).
static func threaded() -> bool:
	return DisplayServer.get_name() != "headless"


## Waits for, and forgets, every dressing under way whose task is over.
static func _see_through() -> void:
	for dressing: ShipDressing in _under_way.duplicate():
		dressing.done()


## Lets the RenderingServer answer a dressing's thread that waits on it, and sleeps a
## little.
static func _flush() -> void:
	RenderingServer.force_sync()
	OS.delay_usec(WAIT_USEC)


func _dress() -> void:
	if not _turn():
		return
	_shared = ShipSpace.new(_ship)
	art.shared_space = _shared
	if config == null:
		art.rules = _rules
		art.pack = true
		art.build(_ship, _rules.railing_height, _rules.body_radius)
	else:
		if _ahead:
			_building.unlock()
			_ship_maps()
			if not _turn():
				return
			_frame_ahead()
			_building.unlock()
			if not _sinking_waited() or not _turn():
				return
		var schedule := config.schedule()
		_falls = MatchView.falls_of(schedule)
		# Any railing may break (SH10), not only those the scenario fails.
		_fails = PackedInt32Array(range(_ship.railings.size()))
		_ports = MatchView.open_ports_of(schedule, _ship.structure)
		plan = StretchPlan.for_schedule(schedule, _ship)
		_cuts = ShipPieces.cuts_of(schedule)
		art.rules = _rules
		art.pack = true
		# All of her when the plan has her stretches in later to take her place.
		if not plan.whole:
			art.span = ShipPieces.first_span(schedule)
		# Her art and stretches built later are drawn from what was read of it here.
		if plan.whole:
			_schedule_read()
		if _framed and _falls.is_empty() and plan.whole:
			art.build_fittings(_ports)
		else:
			_framed_wrong()
			art.build(_ship, _rules.railing_height, _rules.body_radius, _falls, _fails, _ports)
		if plan.whole:
			_dress_stretches(plan.before)
		else:
			stretches = ShipPieces.stretches_of(
				_ship, schedule, _rules, cut_above, _falls, _fails, _ports
			)
			_schedule_read()
	_building.unlock()
	_ship_maps()
	_guard.lock()
	_art_ready = true
	_guard.unlock()
	# The stretches the plan builds behind the match, one dressing building at a time.
	if plan != null and plan.whole:
		_building.lock()
		_dress_stretches(plan.later)
		_building.unlock()
	_guard.lock()
	_built = true
	var dropped := _dropped
	var stopped := _stop_later
	_guard.unlock()
	if dropped:
		_free_nodes()
	elif stopped and not _handed:
		_free_stretches()


## Takes the dressings' turn to build (the class's note): false when she was let go as
## she waited for it — never dressed, freed, so the next waits no longer.
func _turn() -> bool:
	# On the main thread the lock is waited for with the frames' work flowing, so the
	# dressing that holds it can finish (the class's note).
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		while not _building.try_lock():
			_flush()
	else:
		_building.lock()
	_guard.lock()
	var dropped := _dropped
	_guard.unlock()
	if not dropped:
		return true
	_building.unlock()
	_guard.lock()
	_built = true
	_guard.unlock()
	_free_nodes()
	return false


## Waits, on her dressing's thread, for her sinking to be made (sinking_made): false when
## she is let go, or no longer wanted (stop_later), meanwhile — then freed, never dressed.
func _sinking_waited() -> bool:
	while true:
		_guard.lock()
		var made := _made
		var gone := _dropped or _stop_later
		_guard.unlock()
		if made:
			return true
		if gone:
			# Freed before she counts as built: a drop() from now on finds nothing to free.
			_free_nodes()
			_guard.lock()
			_built = true
			_guard.unlock()
			return false
		OS.delay_usec(SINKING_LOOK_USEC)
	return false


## Her sea's maps of her rooms, which her match's sea takes as it starts: a liner's take
## seconds (SeaAndSky.maps_of); and which of her decks stand in her rooms, which the sea's
## wetness and white water on them ask (DeckWetness.out_on_deck); and the boxes her
## cells' water is drawn in, which her sea, her water and her effects read as her match
## starts (CellBoxes). Hers whatever her sinking does, each made once.
func _ship_maps() -> void:
	SeaAndSky.maps_of(_ship, _shared)
	DeckWetness.out_on_deck(_ship, _shared)
	if _ship.structure != null:
		CellBoxes.stacked(_ship.structure, _ship.rooms, _ship)


## Draws her art's frame (ShipArt.build_frame) as her sinking is baked: as it is drawn
## when nothing of hers falls and her art is all of her (StretchPlan.whole), as on every
## Titanic sinking measured (#411); for one that does not, she is drawn again from the
## start (_framed_wrong). Nothing of the frame reads what the hit leaves open.
func _frame_ahead() -> void:
	art.rules = _rules
	art.pack = true
	var fails := PackedInt32Array(range(_ship.railings.size()))
	var none: Array[StringName] = []
	art.build_frame(_ship, _rules.railing_height, _rules.body_radius, none, fails)
	_framed = true


## Lets go of a frame drawn ahead (_frame_ahead) that her sinking does not draw her as:
## her art is drawn anew.
func _framed_wrong() -> void:
	if not _framed:
		return
	_framed = false
	var span := art.span
	art.free()
	_new_art()
	art.shared_space = _shared
	art.rules = _rules
	art.pack = true
	art.span = span


func _schedule_read() -> void:
	_guard.lock()
	_read = true
	_guard.unlock()


## Builds the stretches [param which] of hers (ShipPieces.cuts_of), aft to fore, as
## ShipPieces.stretches_of does — but stopped once she is let go (drop, stop_later).
func _dress_stretches(which: PackedInt32Array) -> void:
	_cut.resize(_cuts.size())
	if _bare == null:
		_bare = ShipPieces.bare(_ship)
		_space = ShipSpace.new(_bare)
	for cut in which:
		_guard.lock()
		var stopped := _dropped or _stop_later
		_guard.unlock()
		if stopped:
			return
		_cut[cut] = ShipPieces.stretch_of(
			_bare, _space, _cuts, cut, _rules, cut_above, _falls, _fails, _ports
		)


func _free_nodes() -> void:
	if art != null:
		art.free()
		art = null
	for stretch: ShipArt in stretches:
		stretch.free()
	stretches.clear()
	_free_stretches()


## Frees the stretches built for the plan's later ones, never taken.
func _free_stretches() -> void:
	for stretch: ShipArt in _cut:
		if stretch != null:
			stretch.free()
	_cut.clear()
