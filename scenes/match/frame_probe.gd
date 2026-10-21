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
## The frames drawn while a match plays from the skip-th second of the run on are kept
## — the run's own clock, as --print-fps counts its seconds; the menu's and a held
## countdown's bake are not the match's — and the split of them all so far is printed
## once a second, lines starting "frame split", for tools/fps.sh to show the last.
##
## The display scripts are timed node by node from outside, nothing in the nodes
## themselves: every node in the tree whose script has a _process is handed a Lap, an
## internal first child at its priority — so it processes right after it, and none of
## the node's get_children sees it — which books the time since the last lap to the
## node's class. A class's line is so its _process, and any engine-processed node run
## between it and the timed script before it; the probe's own work and whatever
## processes after the last timed script are no node's.

const FIRST := -(1 << 30)
const LAST := 1 << 30
const REPORT_EVERY_US := 1000000

var split := FrameSplit.new()
## Whether a match is playing: only its frames are kept, from the one after it starts
## on — the frame it starts in builds it.
var playing := false:
	set(value):
		_starting = value and not playing
		playing = value

var _skip_us: int
var _frame_start := -1
var _process_start := 0
var _reported := 0
var _viewport: RID
var _drawn := 0
var _draw_start := 0
var _draw_end := 0
## When the last lap was booked, this frame.
var _lap := 0
## Whether the match started in the open frame: one not kept.
var _starting := false


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
	_watch_all(get_tree().root)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	get_tree().node_added.disconnect(_on_node_added)


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


## Hands [param node] — whatever it is by now — its Lap, once.
func _watch(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	var watched := node as Node
	if not watched.is_inside_tree():
		return
	if watched.get_child_count(true) > 0 and watched.get_child(0, true) is Lap:
		return
	var script := watched.get_script() as Script
	var named := script.get_global_name()
	if named.is_empty():
		named = StringName(script.resource_path.get_file().get_basename())
	if named.is_empty():
		named = StringName(watched.name)
	var lap_node := Lap.new()
	lap_node.probe = self
	lap_node.node_class = named
	lap_node.process_priority = watched.process_priority
	watched.add_child(lap_node, false, Node.INTERNAL_MODE_FRONT)


func _on_pre_draw() -> void:
	_draw_start = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_draw_end = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _frame_start >= 0:
		_close(now)
	_frame_start = now
	_process_start = now
	if now - _reported >= REPORT_EVERY_US and split.frames() > 0:
		_reported = now
		print("\n".join(split.report()))
	_lap = Time.get_ticks_usec()


## The frame that started at _frame_start, its render just done, closed at [param now].
func _close(now: int) -> void:
	var drawn := Engine.get_frames_drawn()
	var did_draw := drawn != _drawn
	_drawn = drawn
	if _frame_start < _skip_us or not playing or _starting:
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
	split.add(&"process", Time.get_ticks_usec() - _process_start)


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
