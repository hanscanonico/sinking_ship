class_name FrameProbe
extends Node
## Where each drawn frame's time goes, asked for with --frame-split (make fps SPLIT=1):
## a frame is the wall time from one frame's scripts starting to the next's; its
## scripts, the time from the first node's _process to the last's — this probe runs
## first and its End last; the match's steps and their parts as FrameMeter's timers
## measured them inside; and the render's CPU time, as the RenderingServer measured it.
## The frames from the skip-th second of the run on are kept — the run's own clock,
## as --print-fps counts its seconds — and the split of them all so far is printed
## once a second, lines starting "frame split", for tools/fps.sh to show the last.

const FIRST := -(1 << 30)
const LAST := 1 << 30
const REPORT_EVERY_US := 1000000

var split := FrameSplit.new()

var _skip_us: int
var _frame_start := -1
var _process_start := 0
var _reported := 0
var _viewport: RID


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


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _frame_start >= 0:
		_close(now)
	_frame_start = now
	_process_start = now
	if now - _reported >= REPORT_EVERY_US and split.frames() > 0:
		_reported = now
		print("\n".join(split.report()))


## The frame that started at _frame_start, its render just done, closed at [param now].
func _close(now: int) -> void:
	if _frame_start < _skip_us:
		split.drop()
		return
	var render_ms := (
		RenderingServer.get_frame_setup_time_cpu()
		+ RenderingServer.viewport_get_measured_render_time_cpu(_viewport)
	)
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
