class_name NativeVersion
extends RefCounted
## Whether the game's extension (native/, make native) is loaded and was built from these
## sources: native/lib is built per machine and never tracked, so a checkout that pulled
## a change to the extension's classes and did not run make native again holds a library
## older than the GDScript that calls it. Such a library is treated as absent — every
## loader asks has() before it makes a native object, and the GDScript runs instead, the
## same answers by design — with one warning to run make native. CI requires the library
## (SINKING_NATIVE_REQUIRED), and test_native_version fails there on any mismatch.

## The version of the extension's classes this GDScript calls. Bump it, and NativeAbi's
## VERSION in native/src/register_types.cpp with it, in every change that adds, removes or
## changes a native class or a method the GDScript calls.
const VERSION := 1
## The class whose VERSION constant gives the loaded library's version; a library built
## before there was one has none, and counts as stale.
const ABI := &"NativeAbi"

## For tests: the version the loaded library must be, as a stale one would differ.
static var expected := VERSION
static var _warned := false


## Whether the extension's class [param name] is loaded from a library of this version.
static func has(name: StringName) -> bool:
	return ClassDB.class_exists(name) and current()


## Whether the loaded library is of [member expected]'s version; warns once when not.
static func current() -> bool:
	var found := built()
	if found == expected:
		return true
	if not _warned:
		_warned = true
		var told := "native/lib is version %d, the GDScript calls version %d" % [found, expected]
		push_warning(told + ": running the GDScript instead (make native)")
	return false


## The loaded library's version: 0 where it has none, or none is loaded.
static func built() -> int:
	if not ClassDB.class_exists(ABI):
		return 0
	return ClassDB.class_get_integer_constant(ABI, &"VERSION")
