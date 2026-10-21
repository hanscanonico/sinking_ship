extends GutTest
## FrameSplit sums up where each kept frame's time went (make fps SPLIT=1): every part
## averaged over the frames kept, each part's rest — what its own parts leave of it —
## reported under its own name, so the parts always add up to the frame, and the
## frame's own rest reported as unaccounted.


func _frame(split: FrameSplit, frame_us: int, parts: Dictionary) -> void:
	for part: StringName in parts:
		split.add(part, parts[part])
	split.close(frame_us)


func test_a_part_is_its_mean_over_the_frames_kept() -> void:
	var split := FrameSplit.new()
	_frame(split, 30000, {&"bots": 4000, &"match": 10000})
	_frame(split, 40000, {&"bots": 2000, &"match": 6000})
	assert_eq(split.frames(), 2)
	assert_almost_eq(split.mean(&"frame"), 35.0, 0.0001, "in milliseconds")
	assert_almost_eq(split.mean(&"bots"), 3.0, 0.0001)
	assert_almost_eq(split.mean(&"match"), 8.0, 0.0001)


func test_a_part_measured_twice_in_a_frame_counts_both_times() -> void:
	var split := FrameSplit.new()
	split.add(&"host_sim", 1500)
	split.add(&"host_sim", 2500)
	split.close(20000)
	assert_almost_eq(split.mean(&"host_sim"), 4.0, 0.0001, "two steps in one frame")


func test_a_dropped_frame_counts_for_nothing() -> void:
	var split := FrameSplit.new()
	split.add(&"bots", 90000)
	split.drop()
	_frame(split, 20000, {&"bots": 1000})
	assert_eq(split.frames(), 1)
	assert_almost_eq(split.mean(&"bots"), 1.0, 0.0001, "the dropped frame's time left out")


func test_what_a_part_leaves_of_its_parent_is_its_rest() -> void:
	var split := FrameSplit.new()
	_frame(
		split,
		40000,
		{
			&"process": 20000,
			&"match": 12000,
			&"bots": 5000,
			&"host_sim": 4000,
			&"draw": 15000,
			&"render": 11000,
		}
	)
	assert_almost_eq(split.rest(&"match"), 3.0, 0.0001, "the step less its measured parts")
	assert_almost_eq(split.rest(&"draw"), 4.0, 0.0001, "the swap and the wait on the GPU")
	assert_almost_eq(split.rest(&"process"), 8.0, 0.0001, "the display scripts' share")
	assert_almost_eq(split.rest(&"frame"), 5.0, 0.0001, "unaccounted")


func test_the_frames_parts_and_their_rest_add_up_to_the_frame() -> void:
	var split := FrameSplit.new()
	_frame(split, 38000, {&"process": 21000, &"match": 9000, &"draw": 12500})
	_frame(split, 41000, {&"process": 19000, &"match": 11000, &"draw": 13500})
	var top := 0.0
	for part: StringName in split.parts_of(&"frame"):
		top += split.mean(part)
	assert_almost_eq(top + split.rest(&"frame"), split.mean(&"frame"), 0.0001)
	assert_almost_eq(split.rest(&"frame"), 6.5, 0.0001)


func test_the_report_names_every_part_and_the_unaccounted_rest() -> void:
	var split := FrameSplit.new()
	_frame(
		split,
		40000,
		{
			&"process": 20000,
			&"match": 12000,
			&"bots": 5000,
			&"draw": 15000,
			&"render": 9000,
			&"poses": 21,
			&"pose_time": 3000,
			&"steps": 1,
		}
	)
	var report := "\n".join(split.report())
	assert_string_contains(report, "over the match's 1 frames")
	assert_string_contains(report, "not its bake's hold", "which frames, said plainly")
	assert_string_contains(report, "bots' decisions")
	assert_string_contains(report, "display scripts")
	assert_string_contains(report, "render CPU")
	assert_string_contains(report, "waiting on the GPU")
	assert_string_contains(report, "unaccounted")
	var unaccounted := Array(split.report()).filter(
		func(line: String) -> bool: return line.contains("unaccounted")
	)
	assert_eq(unaccounted.size(), 1)
	assert_string_contains(unaccounted[0], "5.00 ms", "the frame's rest, in milliseconds")
	assert_string_contains(report, "sinking poses")
	assert_string_contains(report, "21.0", "poses built per frame")


func test_a_prediction_never_run_is_said_not_exercised() -> void:
	var split := FrameSplit.new()
	_frame(split, 30000, {&"match": 6000, &"reconcile": 200, &"steps": 1})
	var report := "\n".join(split.report())
	assert_string_contains(report, "not exercised")
	assert_string_contains(report, "each snapshot restored")
	var predicting := FrameSplit.new()
	_frame(predicting, 30000, {&"match": 6000, &"prediction": 900, &"steps": 1})
	assert_false("\n".join(predicting.report()).contains("not exercised"), "said only when so")


func test_a_report_of_no_frames_says_so() -> void:
	var report := FrameSplit.new().report()
	assert_eq(report.size(), 1)
	assert_string_contains(report[0], "no frames kept")


func test_frames_not_drawn_are_named() -> void:
	var split := FrameSplit.new()
	_frame(split, 7000, {&"undrawn": 1})
	_frame(split, 30000, {&"undrawn": 0, &"render": 9000})
	assert_string_contains("\n".join(split.report()), "1 frames not drawn")
	assert_false("\n".join(_drawn_split().report()).contains("not drawn"), "said only when so")


func _drawn_split() -> FrameSplit:
	var split := FrameSplit.new()
	_frame(split, 30000, {&"undrawn": 0})
	return split


func test_the_bots_fresh_route_searches_are_reported_per_frame_and_in_all() -> void:
	var split := FrameSplit.new()
	_frame(split, 30000, {&"replans": 3})
	_frame(split, 30000, {&"replans": 0})
	_frame(split, 30000, {&"replans": 6})
	_frame(split, 30000, {&"replans": 1})
	var lines := Array(split.report()).filter(
		func(line: String) -> bool: return line.contains("bot replans")
	)
	assert_eq(lines.size(), 1, "one row")
	if lines.is_empty():
		return
	assert_string_contains(lines[0], "2.50 per frame")
	assert_string_contains(lines[0], "10 over the 4 frames")
	assert_eq(
		Array(split.report()).find(lines[0]),
		_row_after(split, "sinking poses"),
		"beside the sinking poses"
	)


## The index of the line right after the one containing [param text].
func _row_after(split: FrameSplit, text: String) -> int:
	var lines := Array(split.report())
	for index in lines.size():
		if (lines[index] as String).contains(text):
			return index + 1
	return -1


func test_a_node_class_is_its_processes_mean_over_the_frames_kept() -> void:
	var split := FrameSplit.new()
	split.add_node(&"ShipLamp", 100)
	split.add_node(&"ShipLamp", 300)
	split.add_node(&"MatchView", 900)
	split.close(10000)
	split.add_node(&"MatchView", 1100)
	split.close(10000)
	assert_almost_eq(split.node_mean(&"ShipLamp"), 0.2, 0.0001, "every lamp, summed")
	assert_almost_eq(split.node_mean(&"MatchView"), 1.0, 0.0001)
	assert_eq(split.node_classes(), [&"MatchView", &"ShipLamp"] as Array[StringName], "costliest first")


func test_a_dropped_frames_nodes_count_for_nothing() -> void:
	var split := FrameSplit.new()
	split.add_node(&"MatchView", 90000)
	split.drop()
	split.add_node(&"MatchView", 500)
	split.close(10000)
	assert_almost_eq(split.node_mean(&"MatchView"), 0.5, 0.0001)


func test_the_stepper_is_its_own_work_without_the_steps_it_runs() -> void:
	var split := FrameSplit.new()
	_node_frame(split, {&"SimDriver": 2600, &"MatchView": 900}, {&"process": 4000, &"match": 2200})
	assert_almost_eq(split.node_mean(&"SimDriver"), 0.4, 0.0001, "its steps taken out")


func test_the_node_lines_and_their_rest_add_up_to_the_display_scripts() -> void:
	var split := FrameSplit.new()
	_node_frame(split, {&"SimDriver": 2500, &"MatchView": 900}, {&"process": 4000, &"match": 2200})
	_node_frame(split, {&"SimDriver": 300, &"MatchView": 1000}, {&"process": 1600, &"match": 0})
	var lines := 0.0
	for node_class: StringName in split.node_classes():
		lines += split.node_mean(node_class)
	assert_almost_eq(lines + split.nodes_rest(), split.rest(&"process"), 0.0001)
	assert_almost_eq(split.nodes_rest(), 0.45, 0.0001, "the probe's own and the tail")


func test_the_report_lists_the_nodes_under_the_display_scripts() -> void:
	var split := FrameSplit.new()
	_node_frame(split, {&"SimDriver": 2600, &"MatchView": 900}, {&"process": 4000, &"match": 2200})
	var lines := Array(split.report())
	var display := _row_after(split, "display scripts") - 1
	assert_string_contains(lines[display + 1], "MatchView")
	assert_string_contains(lines[display + 1], "0.90 ms")
	assert_string_contains(lines[display + 2], "SimDriver beyond its steps")
	assert_string_contains(lines[display + 2], "0.40 ms")
	assert_string_contains(lines[display + 3], FrameSplit.NODES_REST)
	assert_string_contains(lines[display + 3], "0.50 ms", "what no node took")
	var indent := func(line: String) -> int: return line.length() - line.lstrip(" ").length()
	assert_gt(indent.call(lines[display + 1]), indent.call(lines[display]), "indented under it")


func test_a_report_with_no_node_timed_lists_none() -> void:
	var split := FrameSplit.new()
	_frame(split, 10000, {&"process": 4000})
	assert_false("\n".join(split.report()).contains(FrameSplit.NODES_REST), "said only when timed")


func _node_frame(split: FrameSplit, nodes: Dictionary, parts: Dictionary) -> void:
	for node_class: StringName in nodes:
		split.add_node(node_class, nodes[node_class])
	_frame(split, 10000, parts)
