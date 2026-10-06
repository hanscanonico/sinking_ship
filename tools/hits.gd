extends SceneTree
## `make hits SHIP=steamer SEEDS=200`: the spread of a ship's iceberg hits over seeds
## 1…SEEDS, each struck as her match on that seed strikes it — asked of SinkSchedule,
## never drawn again here (D13): the sides, where along her the gashes run, the cells
## they open, their areas and moments, the walls they weaken, and the doors that jam
## and the openings left open. Headless; no match is played.
##
##   godot --headless --path . -s res://tools/hits.gd -- --ship=steamer --seeds=200
##
## The ship is data/ships/SHIP.tres, struck in her open-sea scenario,
## data/sinking/SHIP_open_sea.tres.

const DEFAULT_SHIP := "steamer"
const DEFAULT_SEEDS := 200
## Where along her the gashes' middles fall: her hit zone cut into this many stretches.
const STRETCHES := 6
## The areas told apart, in m²: each bin runs up to its bound, the last past it.
const AREA_BOUNDS: Array[float] = [0.01, 0.1, 1.0]


func _initialize() -> void:
	var ship := DEFAULT_SHIP
	var seeds := DEFAULT_SEEDS
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--ship":
				ship = value
			"--seeds":
				seeds = value.to_int()
	var layout := Fleet.layout(ship)
	var scenario := Fleet.scenario(ship)
	if layout == null:
		printerr("hits: no ship called %s; the fleet has %s" % [ship, ", ".join(Fleet.names())])
		quit(1)
		return
	var problems := scenario.problems()
	if layout.structure == null or scenario.hit == null:
		problems.append("hits: %s has no structure, or her scenario no hit" % ship)
	elif seeds < 1:
		problems.append("hits: SEEDS must be 1 or more")
	else:
		problems.append_array(layout.structure.problems())
	if not problems.is_empty():
		printerr("\n".join(problems))
		quit(1)
		return
	printraw(_spread(ship, layout, scenario, seeds))
	quit()


func _spread(ship: String, layout: ShipLayout, scenario: SinkScenario, seeds: int) -> String:
	var structure := layout.structure
	var starboard := 0
	var stretches := PackedInt32Array()
	stretches.resize(STRETCHES)
	var cells := {}
	var walls := {}
	var jammed := {}
	var left_open := 0
	var missed := 0
	var areas := PackedFloat64Array()
	var moments := PackedFloat64Array()
	var zone := structure.hit_zone_x
	for seed_value in range(1, seeds + 1):
		var sink_stream := SeedStreams.derive(seed_value, "sink")
		var schedule := SinkSchedule.new(scenario, layout.freeboard, sink_stream, structure)
		var hit := schedule.hit()
		var damage := schedule.damage()
		if hit.side == 1:
			starboard += 1
		var middle := (damage.from_x + damage.to_x) * 0.5
		var stretch := int((middle - zone.x) / (zone.y - zone.x) * STRETCHES)
		stretches[clampi(stretch, 0, STRETCHES - 1)] += 1
		if damage.openings.is_empty():
			missed += 1
		for opening: ShipOpening in damage.openings:
			cells[opening.joins[0]] = cells.get(opening.joins[0], 0) + 1
		for wall: StringName in damage.weakened:
			walls[wall] = walls.get(wall, 0) + 1
		for door: StringName in damage.jammed:
			jammed[door] = jammed.get(door, 0) + 1
		left_open += damage.left_open.size()
		areas.append(damage.area())
		moments.append(Ticks.to_seconds(schedule.hit_tick()))
	areas.sort()
	moments.sort()
	var lines := PackedStringArray()
	lines.append("%s · open sea (%.0f m) · %d seeds" % [ship, scenario.sea_depth, seeds])
	lines.append("sides     port %d · starboard %d" % [seeds - starboard, starboard])
	var places := PackedStringArray()
	var length := (zone.y - zone.x) / STRETCHES
	for index in STRETCHES:
		var from := zone.x + length * index
		places.append("%+.1f…%+.1f m %d" % [from, from + length, stretches[index]])
	lines.append("places    %s  (the gash's middle, aft to fore)" % " · ".join(places))
	lines.append("cells     %s  (seeds opening each)" % _in_order(cells, _cell_names(structure)))
	lines.append("missed    %d  (the gash opens no cell)" % missed)
	lines.append("areas m²  %s" % _quantiles(areas, "%.4f"))
	lines.append("          %s" % _area_bins(areas))
	lines.append("moments   %s" % _quantiles(moments, "%.1f s"))
	lines.append("weakened  %s" % _in_order(walls, _wall_names(structure)))
	var doors: Array[StringName] = []
	var expected_jammed := PackedStringArray()
	var chances := 0
	var expected_open := 0.0
	for opening: ShipOpening in structure.openings:
		if opening.flip_chance <= 0.0:
			continue
		if opening.shuts_at_hit:
			doors.append(opening.name)
			expected_jammed.append("%.1f" % (opening.flip_chance * seeds))
		elif opening.starts == ShipOpening.Start.SHUT:
			chances += 1
			expected_open += opening.flip_chance * seeds
	lines.append(
		"jammed    %s  (expected %s)" % [_in_order(jammed, doors), " · ".join(expected_jammed)]
	)
	lines.append(
		(
			"left open %d  (expected %.1f: %d openings that start shut, over %d seeds)"
			% [left_open, expected_open, chances, seeds]
		)
	)
	return "\n".join(lines) + "\n"


## "name n · …" for every name of [param names] in its order, with its count in
## [param counts] — 0 for none; "none" for no names.
static func _in_order(counts: Dictionary, names: Array[StringName]) -> String:
	var parts := PackedStringArray()
	for item: StringName in names:
		parts.append("%s %d" % [item, counts.get(item, 0)])
	return " · ".join(parts) if not parts.is_empty() else "none"


static func _cell_names(structure: ShipStructure) -> Array[StringName]:
	var names: Array[StringName] = []
	for cell: FloodCell in structure.cells:
		names.append(cell.name)
	return names


static func _wall_names(structure: ShipStructure) -> Array[StringName]:
	var names: Array[StringName] = []
	for wall: ShipWall in structure.walls:
		names.append(wall.name)
	return names


## The least, the 10th percentile, the median, the 90th and the most of the sorted
## [param values], each as [param shape] has it.
static func _quantiles(values: PackedFloat64Array, shape: String) -> String:
	var parts := PackedStringArray()
	var labels := ["least", "p10", "median", "p90", "most"]
	var shares := [0.0, 0.1, 0.5, 0.9, 1.0]
	for index in labels.size():
		var at := roundi(shares[index] * (values.size() - 1))
		parts.append(("%s " + shape) % [labels[index], values[at]])
	return " · ".join(parts)


## How many of [param areas] fall under each of AREA_BOUNDS, and past the last.
static func _area_bins(areas: PackedFloat64Array) -> String:
	var counts := PackedInt32Array()
	counts.resize(AREA_BOUNDS.size() + 1)
	for area: float in areas:
		var bin := 0
		while bin < AREA_BOUNDS.size() and area >= AREA_BOUNDS[bin]:
			bin += 1
		counts[bin] += 1
	var parts := PackedStringArray(["under %s %d" % [AREA_BOUNDS[0], counts[0]]])
	for index in range(1, AREA_BOUNDS.size()):
		parts.append("%s–%s %d" % [AREA_BOUNDS[index - 1], AREA_BOUNDS[index], counts[index]])
	parts.append("over %s %d" % [AREA_BOUNDS[-1], counts[-1]])
	return " · ".join(parts)
