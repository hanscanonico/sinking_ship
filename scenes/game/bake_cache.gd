class_name BakeCache
extends RefCounted
## Sinkings already baked, kept on disk for the dev tools — make match, capture, fps,
## smoke, run and replay pass --bake-cache (BAKE_CACHE=0 drops it). A sinking is a pure
## function of what its bake reads (D7): the code under res://core/, the data under
## res://data/, the match's own data (MatchConfig.data_hash), its seed and its clock. One
## baked before from the very same of all of them is taken as an online client takes the
## host's (MatchConfig.receive_sinking), never baked again; the match plays it exactly as
## the bake (D4). Opt-in, and never in an exported build: tests, players and online play
## never touch it. The one place a sinking touches a file — the core classes only make
## and read bytes.

const DIR := "user://bake_cache"
const EXTENSION := ".sink"
## What an entry starts with, its layout's name: bumped when that layout changes. Then
## the SHA-256 of what follows, then the timeline's bytes (SinkTimeline.to_bytes).
const MAGIC := "SSBAKE1"
const DIGEST_BYTES := 32
## The most the entries may take together, in bytes: the oldest go first past it. A
## Titanic sinking is a few hundred kB, a small ship's tens.
const CAP_BYTES := 64 * 1024 * 1024
## What the bake reads from the project, by root: its code and its data.
const SOURCE_ROOTS: Array[String] = ["res://core", "res://data"]
const SOURCE_EXTENSIONS: Array[String] = ["gd", "tres", "res"]

var dir: String
var cap_bytes: int
## The digest of SOURCE_ROOTS' files (sources_digest), read on first need.
var _sources: String


## A cache under [param directory], its entries kept to [param cap] bytes; given
## [param sources], the digest of what the bake reads, it never reads the project's.
func _init(directory := DIR, cap := CAP_BYTES, sources := "") -> void:
	dir = directory
	cap_bytes = cap
	_sources = sources


## The cache when [param wanted] (--bake-cache) and this is no exported build; else null,
## and every bake made as if there were none.
static func when(wanted: bool) -> BakeCache:
	if not wanted or OS.has_feature("template"):
		return null
	return BakeCache.new()


## Takes [param config]'s sinking from the entry its key names (receive_sinking), when one
## is there whole; whether it did. An entry that is not one — cut short, garbled, of
## another layout, or a timeline whose hit this config does not draw — is deleted, a miss.
func take(config: MatchConfig) -> bool:
	var path := entry_path(key(config))
	if not FileAccess.file_exists(path):
		return false
	var timeline := unpacked(FileAccess.get_file_as_bytes(path))
	if timeline != null and config.receive_sinking(timeline):
		return true
	DirAccess.remove_absolute(path)
	return false


## Keeps [param config]'s sinking, once its bake is over, under its key: never one it
## took from here or from a host, never one still to bake. The oldest entries go past
## the cap. Whether it was written.
func store(config: MatchConfig) -> bool:
	if not config.bake_some(0):
		return false
	var choice := config.sinking()
	if choice == null or choice.received:
		return false
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var path := entry_path(key(config))
	# Written aside, then moved in whole: a session reading it meanwhile never sees half.
	var aside := "%s.%d.part" % [path, OS.get_process_id()]
	var out := FileAccess.open(aside, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(packed(choice.timeline))
	out.close()
	DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(aside, path) != OK:
		DirAccess.remove_absolute(aside)
		return false
	evict()
	return true


## Deletes the oldest entries until the rest are within the cap, the newest always kept.
func evict() -> void:
	var listing := DirAccess.open(dir)
	if listing == null:
		return
	var entries: Array[Array] = []
	var total := 0
	for name in listing.get_files():
		if not name.ends_with(EXTENSION):
			continue
		var path := dir.path_join(name)
		var size := FileAccess.get_size(path)
		entries.append([FileAccess.get_modified_time(path), name, size])
		total += size
	entries.sort()
	for index in entries.size() - 1:
		if total <= cap_bytes:
			break
		DirAccess.remove_absolute(dir.path_join(entries[index][1]))
		total -= entries[index][2]


func entry_path(entry_key: String) -> String:
	return dir.path_join(entry_key + EXTENSION)


## [param config]'s key: everything its bake reads, hashed (key_of).
func key(config: MatchConfig) -> String:
	if _sources.is_empty():
		_sources = sources_digest(source_files(SOURCE_ROOTS))
	return key_of(config, _sources)


## The key of [param config]'s sinking with the project's code and data at
## [param sources] (sources_digest): its match data, its seed, her clock, and the engine
## that bakes it, with the entry's layout.
static func key_of(config: MatchConfig, sources: String) -> String:
	var parts := PackedStringArray(
		[
			MAGIC,
			Engine.get_version_info()["string"],
			sources,
			config.data_hash(),
			str(config.match_seed),
			var_to_str(config.scenario.clock),
		]
	)
	return "\n".join(parts).sha256_text()


## The SHA-256 of [param files] — each path's bytes, by path — in the order of their
## paths: a file added, gone, moved or changed in a byte changes it.
static func sources_digest(files: Dictionary) -> String:
	var paths: Array = files.keys()
	paths.sort()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for path: String in paths:
		var bytes: PackedByteArray = files[path]
		hashing.update(("%s\n%d\n" % [path, bytes.size()]).to_utf8_buffer())
		if not bytes.is_empty():
			hashing.update(bytes)
	return hashing.finish().hex_encode()


## Every file of SOURCE_EXTENSIONS under [param roots], at any depth: its bytes by path.
static func source_files(roots: Array[String]) -> Dictionary:
	var files := {}
	var pending: Array[String] = roots.duplicate()
	while not pending.is_empty():
		var at: String = pending.pop_back()
		var listing := DirAccess.open(at)
		if listing == null:
			continue
		for name in listing.get_directories():
			pending.append(at.path_join(name))
		for name in listing.get_files():
			if name.get_extension() in SOURCE_EXTENSIONS:
				var file := at.path_join(name)
				files[file] = FileAccess.get_file_as_bytes(file)
	return files


## An entry's bytes for [param timeline]: MAGIC, the digest of the timeline's bytes, them.
static func packed(timeline: SinkTimeline) -> PackedByteArray:
	var body := timeline.to_bytes()
	var bytes := MAGIC.to_utf8_buffer()
	bytes.append_array(_digest(body))
	bytes.append_array(body)
	return bytes


## The timeline an entry's [param bytes] hold; null when they are not a whole entry.
static func unpacked(bytes: PackedByteArray) -> SinkTimeline:
	var magic := MAGIC.to_utf8_buffer()
	var head := magic.size() + DIGEST_BYTES
	if bytes.size() <= head or bytes.slice(0, magic.size()) != magic:
		return null
	var body := bytes.slice(head)
	if _digest(body) != bytes.slice(magic.size(), head):
		return null
	return SinkTimeline.from_bytes(body)


static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish()
