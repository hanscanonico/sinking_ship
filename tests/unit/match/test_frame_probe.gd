extends GutTest
## FrameProbe times the display scripts node by node (make fps SPLIT=1) with a Lap
## under each node that processes: a node whose script has a _process but is not
## processing costs nothing — no Lap, or its Lap idle — yet its class keeps its line,
## and one that starts processing is timed from then on.

## Long enough a _process that its line cannot read nothing.
const BUSY_US := 300


class Busy:
	extends Node

	func _process(_delta: float) -> void:
		OS.delay_usec(BUSY_US)


var _probe: FrameProbe


func before_each() -> void:
	_probe = add_child_autofree(FrameProbe.new(0.0))


## [param node] in the tree, watched by the probe, [param processing] or not.
func _watched(node: Node, processing: bool) -> Node:
	add_child_autofree(node)
	node.set_process(processing)
	await wait_process_frames(2)
	_probe.sweep(1 << 20)
	return node


func _lap_of(node: Node) -> Node:
	if node.get_child_count(true) == 0:
		return null
	var first := node.get_child(0, true)
	return first if first is FrameProbe.Lap else null


func test_a_node_that_is_not_processing_gets_no_lap() -> void:
	var idle: Node = await _watched(Busy.new(), false)
	assert_null(_lap_of(idle), "nothing under it")
	assert_eq(idle.get_child_count(true), 0)


func test_a_processing_node_gets_its_lap() -> void:
	var busy: Node = await _watched(Busy.new(), true)
	var lap := _lap_of(busy) as FrameProbe.Lap
	assert_not_null(lap)
	assert_true(lap.is_processing())
	assert_eq(lap.process_priority, busy.process_priority, "right after it")
	assert_eq(busy.get_child_count(), 0, "its own children do not see it")


func test_an_idle_nodes_class_keeps_its_line() -> void:
	var idle: Node = await _watched(Busy.new(), false)
	var classes := _probe.split.node_classes()
	idle.set_process(true)
	_probe.sweep(1 << 20)
	var lap := _lap_of(idle) as FrameProbe.Lap
	assert_not_null(lap, "a Lap once it processes")
	assert_has(classes, lap.node_class, "named before it ever processed")


func test_a_node_that_starts_processing_is_timed_from_then_on() -> void:
	var node: Node = await _watched(Busy.new(), false)
	node.set_process(true)
	_probe.sweep(1 << 20)
	var lap := _lap_of(node) as FrameProbe.Lap
	_probe.playing = true
	await wait_process_frames(6)
	assert_gt(_probe.split.frames(), 0, "frames kept")
	assert_gt(_probe.split.node_mean(lap.node_class), BUSY_US / 2000.0, "its _process timed")


func test_a_node_that_stops_processing_idles_its_lap() -> void:
	var node: Node = await _watched(Busy.new(), true)
	var lap := _lap_of(node) as FrameProbe.Lap
	node.set_process(false)
	_probe.sweep(1 << 20)
	assert_false(lap.is_processing(), "its Lap idle with it")
	node.set_process(true)
	_probe.sweep(1 << 20)
	assert_true(lap.is_processing(), "and back on with it")
	assert_eq(_lap_of(node), lap, "the same Lap, not another")


func test_a_freed_node_is_let_go() -> void:
	var node: Node = await _watched(Busy.new(), true)
	node.free()
	_probe.sweep(1 << 20)
	var other: Node = await _watched(Busy.new(), true)
	assert_not_null(_lap_of(other), "the sweep goes on past it")
