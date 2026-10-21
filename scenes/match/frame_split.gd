class_name FrameSplit
extends RefCounted
## Where a drawn frame's time goes (make fps SPLIT=1): what FrameProbe and FrameMeter's
## timers measured of each frame, in microseconds, summed up over the frames kept. A
## part is a share of the one it lists as its parent; what a parent's measured parts
## leave of it is its rest, reported under the rest's own name — the display scripts'
## share of the frame's scripts, the step's own work, the drawing's swap and wait on the
## GPU, and the frame's unaccounted time — so the parts always add up to the frame.
## The display scripts are split further by node class (add_node): each class's
## _process, the stepping node's less the match's steps it runs, and what no class
## took — the probe's own work and whatever processes after the last timed script —
## as their own rest. Clock-free: it only adds what it is given.

## The frame and its parts, in the order the report lists them: key, label, parent.
const PARTS: Array[Array] = [
	[&"frame", "frame", &""],
	[&"process", "scripts (process)", &"frame"],
	[&"match", "match steps", &"process"],
	[&"bots", "bots' decisions", &"match"],
	[&"host_sim", "host sim step", &"match"],
	[&"snapshot", "snapshot and digest", &"match"],
	[&"wire", "wire encode and decode", &"match"],
	[&"prediction", "client prediction", &"match"],
	[&"reconcile", "client reconcile", &"match"],
	[&"draw", "drawing", &"frame"],
	[&"render", "render CPU", &"draw"],
]
## What each parent's measured parts leave of it, by name.
const RESTS := {
	&"frame": "unaccounted",
	&"process": "display scripts",
	&"match": "rest of the step",
	&"draw": "swap and waiting on the GPU",
}
## The node class whose _process runs the match's steps: its line is its own work, the
## steps (match) taken out.
const STEPPER := &"SimDriver"
## What the display scripts' node lines leave of them.
const NODES_REST := "probe and tail, no node's"

var _open := {}
var _sums := {}
var _nodes_open := {}
var _node_sums := {}
var _frames := 0


## Adds [param amount] — microseconds, or a count — to [param part] of the open frame.
func add(part: StringName, amount: int) -> void:
	_open[part] = _open.get(part, 0) + amount


## Adds [param us] microseconds to the _process time of the nodes of class
## [param node_class] in the open frame.
func add_node(node_class: StringName, us: int) -> void:
	_nodes_open[node_class] = _nodes_open.get(node_class, 0) + us


## Keeps the open frame, [param frame_us] long, and opens the next.
func close(frame_us: int) -> void:
	add(&"frame", frame_us)
	for part: StringName in _open:
		_sums[part] = _sums.get(part, 0) + _open[part]
	for node_class: StringName in _nodes_open:
		_node_sums[node_class] = _node_sums.get(node_class, 0) + _nodes_open[node_class]
	_frames += 1
	_open.clear()
	_nodes_open.clear()


## Leaves the open frame out — one before the frames kept — and opens the next.
func drop() -> void:
	_open.clear()
	_nodes_open.clear()


func frames() -> int:
	return _frames


## [param part]'s mean over the frames kept: milliseconds for a time, else its count.
func mean(part: StringName) -> float:
	if _frames == 0:
		return 0.0
	var sum: float = _sums.get(part, 0)
	return sum / _frames / (1.0 if _is_count(part) else 1000.0)


## The parts [param parent] is split into, in the report's order.
func parts_of(parent: StringName) -> Array[StringName]:
	var parts: Array[StringName] = []
	for row: Array in PARTS:
		if row[2] == parent:
			parts.append(row[0])
	return parts


## What [param parent]'s parts leave of it, in milliseconds per frame kept.
func rest(parent: StringName) -> float:
	var left := mean(parent)
	for part: StringName in parts_of(parent):
		left -= mean(part)
	return left


## The display scripts' share of [param node_class]'s _process, in milliseconds per
## frame kept: the stepper's without the match's steps it runs.
func node_mean(node_class: StringName) -> float:
	if _frames == 0:
		return 0.0
	var sum: float = _node_sums.get(node_class, 0)
	var ms := sum / _frames / 1000.0
	return ms - mean(&"match") if node_class == STEPPER else ms


## The node classes timed, the costliest first.
func node_classes() -> Array[StringName]:
	var classes: Array[StringName] = []
	classes.assign(_node_sums.keys())
	classes.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var by_a := node_mean(a)
			var by_b := node_mean(b)
			return by_a > by_b if by_a != by_b else String(a) < String(b)
	)
	return classes


## What the node lines leave of the display scripts, in milliseconds per frame kept.
func nodes_rest() -> float:
	var left := rest(&"process")
	for node_class: StringName in _node_sums:
		left -= node_mean(node_class)
	return left


## The split as lines of text, every time in milliseconds per frame kept.
func report() -> PackedStringArray:
	if _frames == 0:
		return PackedStringArray(["frame split: no frames kept"])
	var frame := mean(&"frame")
	var lines := PackedStringArray(
		[
			(
				"frame split over the match's %d frames, not its bake's hold — the median above"
				% _frames
			),
			"  counts those too — per frame (%.1f fps of the match alone):" % (1000.0 / frame),
		]
	)
	_report_part(&"frame", "frame", 1, lines)
	lines.append(
		(
			"  sinking poses built %.1f, %.2f ms (inside the parts above)"
			% [mean(&"poses"), mean(&"pose_time")]
		)
	)
	lines.append(
		(
			"  bot replans %.2f per frame, %d over the %d frames (fresh route searches)"
			% [mean(&"replans"), _sums.get(&"replans", 0), _frames]
		)
	)
	var gpu := mean(&"gpu")
	lines.append(
		"  GPU %s (beside the CPU, not added)" % ("%.2f ms" % gpu if gpu > 0.0 else "not measured")
	)
	lines.append("  draw calls %.0f, primitives %.0f" % [mean(&"draw_calls"), mean(&"primitives")])
	var undrawn: int = _sums.get(&"undrawn", 0)
	if undrawn > 0:
		lines.append("  %d frames not drawn (the window out of sight), nothing rendered" % undrawn)
	return lines


func _report_part(part: StringName, label: String, depth: int, lines: PackedStringArray) -> void:
	var note := ""
	if part == &"match":
		note = "  (%.2f steps)" % mean(&"steps")
	elif part == &"prediction" and mean(part) == 0.0:
		note = "  (not exercised: the client only watches, or nothing lags its wire)"
	elif part == &"reconcile" and mean(&"prediction") == 0.0:
		note = "  (each snapshot restored, nothing re-run)"
	lines.append(_line(label, mean(part), depth) + note)
	var parts := parts_of(part)
	if parts.is_empty():
		return
	for row: Array in PARTS:
		if row[2] == part:
			_report_part(row[0], row[1], depth + 1, lines)
	lines.append(_line(RESTS[part], rest(part), depth + 1))
	if part == &"process" and not _node_sums.is_empty():
		_report_nodes(depth + 2, lines)


## The display scripts by node class, under their line, and what no class took.
func _report_nodes(depth: int, lines: PackedStringArray) -> void:
	for node_class: StringName in node_classes():
		var label := String(node_class)
		if node_class == STEPPER:
			label += " beyond its steps"
		lines.append(_line(label, node_mean(node_class), depth))
	lines.append(_line(NODES_REST, nodes_rest(), depth))


static func _line(label: String, ms: float, depth: int) -> String:
	var indent := "  ".repeat(depth)
	return "%s%s %8.2f ms" % [indent, label.rpad(36 - indent.length()), ms]


static func _is_count(part: StringName) -> bool:
	return part in [&"poses", &"replans", &"steps", &"draw_calls", &"primitives", &"undrawn"]
