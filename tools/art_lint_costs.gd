extends RefCounted
## What art-lint's checks of a ship cost (tools/art_lint.gd), and its parts dealt by
## them (--part). Per check, by its kind and index ("blocker\t12"), the microseconds
## it took, gathered as the lint runs (--costs=FILE) and kept by each CI part as an
## artifact; tools/art_lint_costs.py writes TABLE from a run's, in milliseconds: the
## dear checks one by one, and per kind what its cheap ones cost each ("kind\t*").
## The parts deal the checks by TABLE's costs, the dearest first to the part with the
## least so far, as tools/test_shards.py deals test scripts: dealt by count, the
## Titanic's four parts ran 10 to 23 minutes (run 41554654682).

const TABLE := "res://tools/art_lint_costs.tsv"

## Every check's microseconds so far, "kind\tindex" to them.
var costs := {}


## Every check art-lint deals of [param layout] (tools/art_lint.gd, _deal), as
## "kind\tindex": a platform's top and the floor past its edges, each ramp, blocker
## and ladder, each [param stretch]-long stretch of her length a face of
## [param furnished] stands in, her undersides, crate light, hull and panes.
static func units(
	layout: ShipLayout, furnished: PackedVector3Array, stretch: float
) -> PackedStringArray:
	var found := PackedStringArray(["undersides\t0", "crate\t0"])
	if layout.structure != null:
		found.append_array(["hull\t0", "panes\t0"])
	var lists := {
		"platform": layout.platforms.size(),
		"floor": layout.platforms.size(),
		"ramp": layout.ramps.size(),
		"blocker": layout.blockers.size(),
		"ladder": layout.ladders.size(),
	}
	for kind: String in lists:
		for index in lists[kind]:
			found.append("%s\t%d" % [kind, index])
	var stretches := {}
	for index in range(0, furnished.size(), 3):
		stretches[floori(furnished[index].x / stretch)] = true
	for at: int in stretches:
		found.append("stretch\t%d" % at)
	return found


## [param ship]'s rows of the cost table at [param path], "kind\tindex" to their cost:
## lines "ship\tkind\tindex\tcost", # a comment; none when there is no file.
static func table(path: String, ship: String) -> Dictionary:
	var found := {}
	if not FileAccess.file_exists(path):
		return found
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var fields := line.strip_edges().split("\t")
		if not line.begins_with("#") and fields.size() == 4 and fields[0] == ship:
			found["%s\t%s" % [fields[1], fields[2]]] = fields[3].to_float()
	return found


## What each of [param units] weighs by [param known]: its cost there, else its
## kind's cheap checks' ("kind\t*", the table's row for every one it does not list),
## else the middle of its kind's there, else the middle of every one there, else 1.
static func weights(units: PackedStringArray, known: Dictionary) -> PackedFloat64Array:
	var kinds := {}
	for unit: String in known:
		var kind := unit.get_slice("\t", 0)
		if not kinds.has(kind):
			kinds[kind] = PackedFloat64Array()
		kinds[kind].append(known[unit])
	var middles := {}
	for kind: String in kinds:
		middles[kind] = known.get(kind + "\t*", _middle(kinds[kind]))
	var every := _middle(PackedFloat64Array(known.values())) if not known.is_empty() else 1.0
	var weighed := PackedFloat64Array()
	for unit in units:
		weighed.append(known.get(unit, middles.get(unit.get_slice("\t", 0), every)))
	return weighed


## [param units] dealt among [param parts] parts by what [param known] says they cost
## (weights): unit to part, from 0. The dearest first, each to the part with the
## least so far, the lowest of those; equal costs go in the units' sorted order, so
## a deal is the same however the units are listed.
static func deal(units: PackedStringArray, known: Dictionary, parts: int) -> Dictionary:
	var sorted := units.duplicate()
	sorted.sort()
	var weighed := weights(sorted, known)
	var order := range(sorted.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return weighed[a] > weighed[b] or (weighed[a] == weighed[b] and a < b)
	)
	var loads := PackedFloat64Array()
	loads.resize(parts)
	var dealt := {}
	for index: int in order:
		var lightest := 0
		for part in parts:
			if loads[part] < loads[lightest]:
				lightest = part
		loads[lightest] += weighed[index]
		dealt[sorted[index]] = lightest
	return dealt


static func _middle(values: PackedFloat64Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var half := sorted.size() / 2
	return sorted[half] if sorted.size() % 2 == 1 else (sorted[half - 1] + sorted[half]) * 0.5


## Adds the time since [param since] (Time.get_ticks_usec) to check [param kind]
## [param index].
func timed(kind: String, index: int, since: int) -> void:
	var key := "%s\t%d" % [kind, index]
	costs[key] = costs.get(key, 0) + Time.get_ticks_usec() - since


## One line per kind of check: how many there were and their seconds between them.
func summary() -> PackedStringArray:
	var kinds := {}
	for key: String in costs:
		var kind := key.get_slice("\t", 0)
		var sum: Vector2 = kinds.get(kind, Vector2.ZERO)
		kinds[kind] = sum + Vector2(1.0, costs[key] / 1e6)
	var lines := PackedStringArray()
	var names := kinds.keys()
	names.sort()
	for kind: String in names:
		lines.append("%s x%d %.1f s" % [kind, kinds[kind].x, kinds[kind].y])
	return lines


## Appends every check's cost to [param path] as "ship\tkind\tindex\tmicroseconds"
## lines, [param ship] naming her.
func write(path: String, ship: String) -> void:
	var out := FileAccess.open(
		path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	)
	out.seek_end()
	var keys := costs.keys()
	keys.sort()
	for key: String in keys:
		out.store_line("%s\t%s\t%d" % [ship, key, costs[key]])
	out.close()
