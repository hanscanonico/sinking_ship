extends GutTest
## The dev tools' bake cache (BakeCache): its key changes with everything a bake reads —
## the seed, her clock, a data file's bytes, a core script's — a stored sinking comes
## back as the very timeline it was, a corrupt entry is a miss and is deleted, the
## oldest entries go past the cap, and nothing uses it unless asked (--bake-cache).

const MATCH_DATA := "res://data/match/default.tres"
const DIR := "user://bake_cache_test"
const SEED := 1701
## A small ship, quick to bake.
const SHIP := &"tug"
## The project's code and data as the key reads them, made up: no file is written.
const FILES := {
	"res://core/sinking/must_sink.gd": "class_name MustSink",
	"res://data/physics/sea.tres": "[resource]\nsea_density = 1025.0",
}


func before_each() -> void:
	_clear()


func after_all() -> void:
	_clear()
	DirAccess.remove_absolute(DIR)


func _clear() -> void:
	var listing := DirAccess.open(DIR)
	if listing == null:
		return
	for name in listing.get_files():
		DirAccess.remove_absolute(DIR.path_join(name))


func _config(seed_value := SEED) -> MatchConfig:
	return MatchConfig.from_rules(load(MATCH_DATA), seed_value, 0, SHIP)


static func _sources(files: Dictionary) -> String:
	var bytes := {}
	for path: String in files:
		bytes[path] = String(files[path]).to_utf8_buffer()
	return BakeCache.sources_digest(bytes)


func test_the_key_changes_with_everything_the_bake_reads() -> void:
	var sources := _sources(FILES)
	var key := BakeCache.key_of(_config(), sources)
	assert_eq(BakeCache.key_of(_config(), _sources(FILES)), key, "the same inputs: the same key")
	assert_ne(BakeCache.key_of(_config(SEED + 1), sources), key, "another seed")
	var quick := _config()
	quick.scenario = MatchConfig.quickened(quick.scenario, quick.scenario.clock * 2.0)
	assert_ne(BakeCache.key_of(quick, sources), key, "another clock")
	var data := FILES.duplicate()
	data["res://data/physics/sea.tres"] = "[resource]\nsea_density = 1026.0"
	assert_ne(BakeCache.key_of(_config(), _sources(data)), key, "a data file's bytes")
	var code := FILES.duplicate()
	code["res://core/sinking/must_sink.gd"] = "class_name MustSink\n"
	assert_ne(BakeCache.key_of(_config(), _sources(code)), key, "a core script's bytes")
	var more := FILES.duplicate()
	more["res://core/new.gd"] = ""
	assert_ne(BakeCache.key_of(_config(), _sources(more)), key, "a script added")


func test_a_stored_sinking_comes_back_as_the_same_timeline() -> void:
	var cache := BakeCache.new(DIR, BakeCache.CAP_BYTES, _sources(FILES))
	var unbaked := _config()
	assert_false(cache.take(unbaked), "nothing stored yet: a miss")
	assert_false(cache.store(unbaked), "nothing baked yet: nothing stored")
	var baked := _config()
	var made := baked.sinking()
	assert_not_null(made, "she sinks")
	assert_true(cache.store(baked), "stored")
	var taken := _config()
	assert_true(cache.take(taken), "a hit")
	var back := taken.sinking()
	assert_true(back.received, "taken, never baked")
	assert_eq(back.timeline.digest(), made.timeline.digest(), "the very timeline")
	assert_eq(
		[back.draws, back.thrown, back.bakes, back.rung, back.sure],
		[made.draws, made.thrown, made.bakes, made.rung, made.sure],
		"how the rule came to it"
	)
	assert_eq(taken.schedule().hit_tick(), baked.schedule().hit_tick(), "struck alike")
	assert_false(cache.store(taken), "one taken is never stored again")
	var other := BakeCache.new(DIR, BakeCache.CAP_BYTES, _sources({}))
	assert_false(other.take(_config()), "other code and data: a miss")


func test_a_corrupt_entry_is_a_miss_and_deleted() -> void:
	var cache := BakeCache.new(DIR, BakeCache.CAP_BYTES, _sources(FILES))
	var baked := _config()
	baked.sinking()
	assert_true(cache.store(baked))
	var path := cache.entry_path(cache.key(baked))
	var whole := FileAccess.get_file_as_bytes(path)
	var garbled := whole.duplicate()
	garbled[garbled.size() - 1] ^= 0xff
	var foreign := whole.duplicate()
	foreign[0] ^= 0xff
	var bad := {
		"cut short": whole.slice(0, whole.size() / 2),
		"a byte garbled": garbled,
		"another layout": foreign,
		"empty": PackedByteArray(),
	}
	for what: String in bad:
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_buffer(bad[what])
		out.close()
		var config := _config()
		assert_false(cache.take(config), "%s: a miss" % what)
		assert_false(FileAccess.file_exists(path), "%s: deleted" % what)
		assert_false(config.bake_some(0), "%s: still to bake" % what)
	assert_null(BakeCache.unpacked(whole.slice(0, 10)), "a head alone is no entry")
	assert_not_null(BakeCache.unpacked(whole), "the whole entry is one")


func test_the_oldest_entries_go_past_the_cap() -> void:
	var cache := BakeCache.new(DIR, 25, "")
	DirAccess.make_dir_recursive_absolute(DIR)
	for name: String in ["a", "b", "c"]:
		var out := FileAccess.open(cache.entry_path(name), FileAccess.WRITE)
		out.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
		out.close()
	cache.evict()
	var left := Array(DirAccess.get_files_at(DIR))
	assert_eq(left.size(), 2, "within the cap")
	assert_false(cache.entry_path("a").get_file() in left, "the oldest gone first")
	var tight := BakeCache.new(DIR, 1, "")
	tight.evict()
	assert_eq(DirAccess.get_files_at(DIR).size(), 1, "the newest always kept")


func test_nothing_uses_it_unless_asked() -> void:
	assert_null(BakeCache.when(false), "off unless asked")
	assert_not_null(BakeCache.when(true), "on when asked, outside an exported build")
	assert_false(MatchArgs.parse(PackedStringArray()).bake_cache, "no flag, no cache")
	assert_true(MatchArgs.parse(PackedStringArray(["--bake-cache"])).bake_cache)
	var baker := SinkingBaker.new()
	assert_null(baker.cache, "a baker bakes afresh unless given one")
	baker.free()
