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

## How long the main thread sleeps between flushes as it waits on a dressing, in µs.
const WAIT_USEC := 200

## Held by whichever dressing is building.
static var _building := Mutex.new()
## Every dressing started whose task has not been seen through: kept alive meanwhile.
static var _under_way: Array[ShipDressing] = []

## The match whose ship this dresses, as its sinking has her; null for one at rest.
var config: MatchConfig
## The height above which her art is cut away (ShipArt.cut_above).
var cut_above: float
## Her art: the stretch the ship's own node draws (ShipPieces.first_span) — all of her
## when she never breaks — and the rest, aft to fore, each to hang on its piece.
var art: ShipArt
var stretches: Array[ShipArt] = []

var _ship: ShipLayout
var _rules: BrawlRules
var _task := -1
var _dressed := false
## Guards _built and _dropped between the dressing's thread and the main one.
var _guard := Mutex.new()
var _built := false
var _dropped := false


## [param dressed]'s ship to dress as its match draws her, cut away above [param cut] as
## the observer's view is (ShipArt.cut_above).
func _init(dressed: MatchConfig, cut: float = INF) -> void:
	config = dressed
	cut_above = cut
	if dressed != null:
		_ship = dressed.ship
		_rules = dressed.rules
	art = ShipArt.new()
	art.name = "ShipArt"
	art.cut_above = cut


## [param ship] to dress whole and at rest — nothing of her to fall, fail or stand open —
## to [param rules]' railings and bodies: the menu's backdrop's.
static func at_rest(ship: ShipLayout, rules: BrawlRules) -> ShipDressing:
	var dressing := ShipDressing.new(null)
	dressing._ship = ship
	dressing._rules = rules
	return dressing


## Dresses her on a worker thread; done() says when she is. Returns itself.
func start() -> ShipDressing:
	if _task >= 0 or _dressed:
		return self
	_see_through()
	_under_way.append(self)
	_task = WorkerThreadPool.add_task(_dress, false, "Dressing a ship")
	return self


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
	while not WorkerThreadPool.is_task_completed(_task):
		_flush()
	done()


## Whether she is dressed: art and stretches are ready to take.
func done() -> bool:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_dressed = true
		_under_way.erase(self)
	return _dressed


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


## Finishes every dressing under way, the main thread's frames' work flowing meanwhile:
## what the game does before it quits.
static func finish_all() -> void:
	for dressing: ShipDressing in _under_way.duplicate():
		dressing.finish()


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
	# On the main thread the lock is waited for with the frames' work flowing, so the
	# dressing that holds it can finish (the class's note).
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		while not _building.try_lock():
			_flush()
	else:
		_building.lock()
	# Let go while she waited her turn: never dressed, so the next waits no longer.
	_guard.lock()
	var dropped := _dropped
	_guard.unlock()
	if dropped:
		_building.unlock()
		_guard.lock()
		_built = true
		_guard.unlock()
		_free_nodes()
		return
	if config == null:
		art.build(_ship, _rules.railing_height, _rules.body_radius)
	else:
		var schedule := config.schedule()
		var falls := MatchView.falls_of(schedule)
		# Any railing may break (SH10), not only those the scenario fails.
		var fails := PackedInt32Array(range(_ship.railings.size()))
		var ports := MatchView.open_ports_of(schedule, _ship.structure)
		art.span = ShipPieces.first_span(schedule)
		art.build(_ship, _rules.railing_height, _rules.body_radius, falls, fails, ports)
		stretches = ShipPieces.stretches_of(_ship, schedule, _rules, cut_above, falls, fails, ports)
	_building.unlock()
	# Her sea's maps of her rooms too, which her match's sea takes as it starts: a liner's
	# take seconds (SeaAndSky.maps_of).
	SeaAndSky.maps_of(_ship)
	_guard.lock()
	_built = true
	dropped = _dropped
	_guard.unlock()
	if dropped:
		_free_nodes()


func _free_nodes() -> void:
	if art != null:
		art.free()
		art = null
	for stretch: ShipArt in stretches:
		stretch.free()
	stretches.clear()
