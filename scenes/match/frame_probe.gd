class_name FrameProbe
extends Node
## Where each drawn frame's time goes, asked for with --frame-split (make fps SPLIT=1):
## a frame is the wall time from one frame's scripts starting to the next's; its
## scripts, the time from the first node's _process to the last's — this probe runs
## first and its End last; the match's steps and their parts as FrameMeter's timers
## measured them inside; its drawing, the wall time from the RenderingServer's
## frame_pre_draw to its frame_post_draw — the render's CPU time within it, as the
## RenderingServer measured it, the rest the buffer swap and the wait on the GPU, which
## the Compatibility renderer cannot time itself.
## The frames drawn while a match plays from the skip-th second after it started on are
## kept — the menu's, a held countdown's bake and a held ship's dressing are not the
## match's, however long they take — and the split of them all so far is printed
## once a second, lines starting "frame split", for tools/fps.sh to show the last.
##
## The display scripts are timed node by node from outside, nothing in the nodes
## themselves: every node in the tree whose script has a _process is watched, and one
## that is processing is handed a Lap, an internal first child at its priority — so it
## processes right after it, and none of the node's get_children sees it — which books
## the time since the last lap to the node's class. A class's line is so its _process,
## and any engine-processed node run between it and the timed script before it; the
## probe's own work and whatever processes after the last timed script are no node's.
## A watched node that is not processing costs nothing — no Lap, or its Lap idle with
## it — and its class still has its line: the probe checks SWEEP_PER_FRAME watched
## nodes a frame, round the list, and turns each one's Lap on or off as the node's own
## processing is.

const FIRST := -(1 << 30)
const LAST := 1 << 30
const REPORT_EVERY_US := 1000000
## How many watched nodes a frame's sweep checks for processing turned on or off: the
## Titanic's ~2,700 in about 21 frames.
const SWEEP_PER_FRAME := 128

var split := FrameSplit.new()
## Whether a match is playing: only its frames are kept, from the one after it starts
## on — the frame it starts in builds it.
var playing := false:
	set(value):
		_starting = value and not playing
		if _starting:
			_playing_since = Time.get_ticks_usec()
		playing = value

var _skip_us: int
var _playing_since := 0
var _frame_start := -1
var _process_start := 0
var _reported := 0
var _viewport: RID
var _drawn := 0
var _draw_start := 0
var _draw_end := 0
## When the scripts of the open frame ended, and when the SceneTree began its frame.
var _scripts_end := 0
var _tree_frame := 0
var _physics_frames := 0
## When the last lap was booked, this frame.
var _lap := 0
## Whether the match started in the open frame: one not kept.
var _starting := false
## The nodes watched — those with a _process script, in the tree — each with its
## class's name, its Lap (null until it first processes) and its instance id, side by
## side; untyped, as a node may be freed before the sweep comes round to it.
var _watched: Array = []
var _named: Array[StringName] = []
var _laps: Array = []
var _ids: Array[int] = []
var _watching := {}
var _sweep_at := 0


## Keeps the frames from [param skip_seconds] of the run on.
func _init(skip_seconds: float) -> void:
	_skip_us = int(skip_seconds * 1000000.0)
	process_priority = FIRST
	var end := End.new()
	end.process_priority = LAST
	end.probe = self
	add_child(end)


func _ready() -> void:
	_viewport = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport, true)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	get_tree().node_added.connect(_on_node_added)
	get_tree().process_frame.connect(_on_process_frame)
	get_tree().physics_frame.connect(_on_physics_frame)
	_watch_all(get_tree().root)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	get_tree().node_added.disconnect(_on_node_added)
	get_tree().process_frame.disconnect(_on_process_frame)
	get_tree().physics_frame.disconnect(_on_physics_frame)
	# Its Laps go with it: none is left booking to a probe that is gone.
	for lap_node: Variant in _laps:
		if is_instance_valid(lap_node):
			(lap_node as Node).set_process(false)
			(lap_node as Node).queue_free()
	_watched.clear()
	_named.clear()
	_laps.clear()
	_ids.clear()
	_watching.clear()
	_sweep_at = 0


## Books the time since the last lap to [param node_class]'s _process.
func lap(node_class: StringName) -> void:
	var now := Time.get_ticks_usec()
	split.add_node(node_class, now - _lap)
	_lap = now


func _watch_all(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_watch_all(child)


func _on_node_added(node: Node) -> void:
	if node is Lap or node is End or node == self:
		return
	var script := node.get_script() as Script
	if script != null and node.has_method(&"_process"):
		# Not while the node is still entering the tree with its children.
		_watch.call_deferred(node)


## Watches [param node] — whatever it is by now — once, its class named in the split.
func _watch(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	var watched := node as Node
	if not watched.is_inside_tree() or _watching.has(watched.get_instance_id()):
		return
	var script := watched.get_script() as Script
	var named := script.get_global_name()
	if named.is_empty():
		named = StringName(script.resource_path.get_file().get_basename())
	if named.is_empty():
		named = StringName(watched.name)
	split.name_node(named)
	# Its own Lap, if the node is back in the tree: another probe's is left to go.
	var lap_node: Lap = null
	if watched.get_child_count(true) > 0 and watched.get_child(0, true) is Lap:
		var first := watched.get_child(0, true) as Lap
		if is_instance_valid(first.probe) and first.probe == self:
			lap_node = first
	_watching[watched.get_instance_id()] = true
	_watched.append(watched)
	_named.append(named)
	_laps.append(lap_node)
	_ids.append(watched.get_instance_id())
	_sync(_watched.size() - 1)


## Checks the next [param count] watched nodes, round the list: a Lap for each one
## processing, its Lap idle for each one not, and nodes freed or gone from the tree
## let go.
func sweep(count: int) -> void:
	for _i in mini(count, _watched.size()):
		if _sweep_at >= _watched.size():
			_sweep_at = 0
		if _sync(_sweep_at):
			_sweep_at += 1


## Gives the watched node at [param at] a Lap that processes as it does: false when
## the node is gone and the last one watched took its place.
func _sync(at: int) -> bool:
	var node: Variant = _watched[at]
	if not is_instance_valid(node) or not (node as Node).is_inside_tree():
		_let_go(at)
		return false
	var watched := node as Node
	var lap_node: Variant = _laps[at]
	var processing := watched.is_processing()
	if lap_node == null:
		if processing:
			var added := Lap.new()
			added.probe = self
			added.node_class = _named[at]
			added.process_priority = watched.process_priority
			watched.add_child(added, false, Node.INTERNAL_MODE_FRONT)
			_laps[at] = added
	elif (lap_node as Lap).is_processing() != processing:
		(lap_node as Lap).set_process(processing)
	return true


func _let_go(at: int) -> void:
	_watching.erase(_ids[at])
	var last := _watched.size() - 1
	_watched[at] = _watched[last]
	_named[at] = _named[last]
	_laps[at] = _laps[last]
	_ids[at] = _ids[last]
	_watched.resize(last)
	_named.resize(last)
	_laps.resize(last)
	_ids.resize(last)


func _on_pre_draw() -> void:
	_draw_start = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_draw_end = Time.get_ticks_usec()


func _on_process_frame() -> void:
	_tree_frame = Time.get_ticks_usec()


func _on_physics_frame() -> void:
	_physics_frames += 1


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _frame_start >= 0:
		_close(now)
	_frame_start = now
	_process_start = now
	if now - _reported >= REPORT_EVERY_US and split.frames() > 0:
		_reported = now
		print("\n".join(split.report()))
	sweep(SWEEP_PER_FRAME)
	_lap = Time.get_ticks_usec()


## The frame that started at _frame_start, its render just done, closed at [param now].
func _close(now: int) -> void:
	var physics_frames := _physics_frames
	_physics_frames = 0
	var drawn := Engine.get_frames_drawn()
	var did_draw := drawn != _drawn
	_drawn = drawn
	if _frame_start < _playing_since + _skip_us or not playing or _starting:
		_starting = false
		split.drop()
		return
	split.add(&"undrawn", 0 if did_draw else 1)
	if not did_draw:
		# A window the system is not drawing renders nothing: the last frame's
		# readings are not this one's.
		split.close(now - _frame_start)
		return
	var render_ms := (
		RenderingServer.get_frame_setup_time_cpu()
		+ RenderingServer.viewport_get_measured_render_time_cpu(_viewport)
	)
	if _draw_start >= _frame_start and _draw_end >= _draw_start:
		split.add(&"draw", _draw_end - _draw_start)
		# The engine's own work around the draw: from the scripts' end to it, from it
		# to the next frame's SceneTree frame, and from that to the next scripts.
		if _scripts_end >= _frame_start and _draw_start >= _scripts_end:
			split.add(&"settle", _draw_start - _scripts_end)
		if _tree_frame >= _draw_end and now >= _tree_frame:
			split.add(&"loop", _tree_frame - _draw_end)
			split.add(&"flush", now - _tree_frame)
	split.add(&"physics_frames", physics_frames)
	split.add(&"nodes", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	split.add(&"objects", int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	split.add(&"render", int(render_ms * 1000.0))
	split.add(
		&"gpu", int(RenderingServer.viewport_get_measured_render_time_gpu(_viewport) * 1000.0)
	)
	split.add(
		&"draw_calls", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	)
	split.add(
		&"primitives", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	)
	split.close(now - _frame_start)


func scripts_done() -> void:
	_scripts_end = Time.get_ticks_usec()
	split.add(&"process", _scripts_end - _process_start)


## The last node to process in a frame: where the frame's scripts end.
class End:
	extends Node
	var probe: FrameProbe

	func _process(_delta: float) -> void:
		probe.scripts_done()


## Processes right after the node it is the first child of: books its _process.
class Lap:
	extends Node
	var probe: FrameProbe
	var node_class: StringName

	func _process(_delta: float) -> void:
		probe.lap(node_class)
