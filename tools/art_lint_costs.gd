## What art-lint's checks of a ship cost (tools/art_lint.gd, --costs): per check, by
## its kind and index ("blocker 12"), the microseconds it took, gathered as the lint
## runs and written out as a table a CI run keeps.

## Every check's microseconds so far, "kind\tindex" to them.
var costs := {}


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
