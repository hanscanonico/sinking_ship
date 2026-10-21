class_name ReplayStore
extends RefCounted
## The replays kept on disk: one ReplayFile per .replay under [member dir],
## user://replays by default (R1, #209). The one place a replay touches a file — the
## core classes only make and read bytes.

const DIR := "user://replays"
const EXTENSION := ".replay"

var dir: String


func _init(directory := DIR) -> void:
	dir = directory


## Writes [param file] as [param name] (its extension added) and answers its path, or
## "" when it could not be written.
func save(file: ReplayFile, name: String) -> String:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	var path := dir.path_join(name + EXTENSION)
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(file.to_bytes())
	out.close()
	return path


## The replay at [param path], or null when it is missing or not a replay.
func load_file(path: String) -> ReplayFile:
	if not FileAccess.file_exists(path):
		return null
	return ReplayFile.from_bytes(FileAccess.get_file_as_bytes(path))


## Every replay's path, newest first — the names start with when they were recorded
## (ReplayNames), so that is their order read backwards.
func list() -> PackedStringArray:
	var found := PackedStringArray()
	var listing := DirAccess.open(dir)
	if listing == null:
		return found
	for name in listing.get_files():
		if name.ends_with(EXTENSION):
			found.append(dir.path_join(name))
	found.sort()
	found.reverse()
	return found


func delete(path: String) -> bool:
	return DirAccess.remove_absolute(path) == OK
