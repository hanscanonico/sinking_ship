class_name ReplayNames
extends RefCounted
## How a saved replay is named, and which of them a prune drops (R3, #211). A name
## starts with when the replay was recorded, year first, so names sort as the
## replays were played; the moment is passed in as a datetime dictionary — no clock
## in core.


## The name of a replay recorded at [param datetime] (the engine's datetime dictionary,
## keyed year, month, day, hour, minute, second) of [param ship]'s match on
## [param seed_value]: yyyy-mm-dd_hh-mm-ss_ship_seed.
static func file_name(datetime: Dictionary, ship: StringName, seed_value: int) -> String:
	return (
		"%04d-%02d-%02d_%02d-%02d-%02d_%s_%d"
		% [
			datetime["year"],
			datetime["month"],
			datetime["day"],
			datetime["hour"],
			datetime["minute"],
			datetime["second"],
			ship,
			seed_value,
		]
	)


## Of [param paths], the ones past the newest [param keep] by their names' dates,
## newest first; a path whose name carries no date is kept whatever the count.
static func to_prune(paths: PackedStringArray, keep: int) -> PackedStringArray:
	var dated := PackedStringArray()
	for path in paths:
		if _dated(path.get_file()):
			dated.append(path)
	dated.sort()
	dated.reverse()
	var dropped := PackedStringArray()
	for at in range(maxi(keep, 0), dated.size()):
		dropped.append(dated[at])
	return dropped


## Whether [param name] starts with a yyyy-mm-dd_hh-mm-ss date.
static func _dated(name: String) -> bool:
	if name.length() < 19:
		return false
	for at in 19:
		var glyph := name[at]
		var expected := "0000-00-00_00-00-00"[at]
		if (expected == "0") != glyph.is_valid_int() or (expected != "0" and glyph != expected):
			return false
	return true
