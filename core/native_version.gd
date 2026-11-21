class_name NativeVersion
extends RefCounted
## Whether the game's extension (native/, make native) is loaded and was built from these
## sources: native/lib is built per machine and never tracked, so a checkout that pulled
## a change to the extension's classes and did not run make native again holds a library
## older than the GDScript that calls it. Such a library is treated as absent — every
## loader asks has() before it makes a native object, and the GDScript runs instead, the
## same answers by design — with one warning to run make native. CI requires the library
## (SINKING_NATIVE_REQUIRED), and test_native_version fails there on any mismatch.
##
## Nothing is bumped by hand: the library carries the digest of the native/src it was
## built from (NativeAbi.source, worked out by native/SConstruct), and this works out the
## same digest of the native/src beside it. A change to any native source makes every
## library built before it stale; a class a library lacks is absent all the same.

## The class whose source() gives the digest the loaded library was built from; a
## library built before there was one has none, and counts as stale.
const ABI := &"NativeAbi"
## The extension's sources, which an export leaves out: there the library shipped is the
## one built with it, and is taken as it is.
const SOURCES := "res://native/src"
## What [method wanted] answers where there are no sources to hold the library to.
const ANY := "any"

## For tests: the digest the loaded library must carry, as a stale one would differ;
## empty until [method wanted] works it out from [constant SOURCES].
static var expected := ""
static var _warned := false


## Whether the extension's class [param name] is loaded from a library of these sources.
static func has(name: StringName) -> bool:
	return ClassDB.class_exists(name) and current()


## Whether the loaded library was built from [method wanted]'s sources; warns once when
## not.
static func current() -> bool:
	var want := wanted()
	var found := built()
	if want == ANY or found == want:
		return true
	if not _warned:
		_warned = true
		var told := "native/lib was built from other sources than native/src (%s, not %s)"
		push_warning(told % [found, want] + ": running the GDScript instead (make native)")
	return false


## The digest the loaded library must carry: native/src's, worked out once, or
## [constant ANY] where the sources are not shipped.
static func wanted() -> String:
	if expected.is_empty():
		expected = digest(SOURCES)
	return expected


## The digest of the sources the loaded library was built from: empty where it has none,
## or none is loaded.
static func built() -> String:
	if not ClassDB.class_exists(ABI) or not ClassDB.class_has_method(ABI, &"source"):
		return ""
	return str(ClassDB.instantiate(ABI).call(&"source"))


## The digest native/SConstruct builds into the library (source_digest), of the .cpp and
## .h files in [param folder]: SHA-256 over each by name, as its name, a newline, its
## size in bytes, a newline, its bytes. [constant ANY] where the folder cannot be read.
static func digest(folder: String) -> String:
	var dir := DirAccess.open(folder)
	if dir == null:
		return ANY
	var names: Array[String] = []
	for name: String in dir.get_files():
		if name.ends_with(".cpp") or name.ends_with(".h"):
			names.append(name)
	names.sort()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for name in names:
		var data := FileAccess.get_file_as_bytes(folder.path_join(name))
		hashing.update(("%s\n%d\n" % [name, data.size()]).to_utf8_buffer())
		if not data.is_empty():
			hashing.update(data)
	return hashing.finish().hex_encode()
