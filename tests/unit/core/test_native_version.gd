extends GutTest
## A library in native/lib built from other sources than the GDScript beside it
## (NativeVersion) is treated as absent: every loader hands back its GDScript instead of a
## native object whose methods may be missing, as #671's NativeWater.chains_under was from
## a library built before it. A class the library lacks is absent the same way. CI sets
## SINKING_NATIVE_REQUIRED, so a stale library there fails.

const SCRATCH := "user://test_native_version"


func after_each() -> void:
	NativeVersion.expected = ""
	if not DirAccess.dir_exists_absolute(SCRATCH):
		return
	for name in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(name))
	DirAccess.remove_absolute(SCRATCH)


func test_a_stale_library_runs_the_gdscript() -> void:
	NativeVersion.expected = "0123456789abcdef"
	assert_false(NativeVersion.current())
	assert_false(NativeVersion.has(&"NativeWater"))
	assert_null(StillPoints.native_water())
	assert_false(ContactsNative.loaded())
	assert_null(WaterFxNative.made())
	assert_null(ArtNative.made(&"NativeShipMesh"))


func test_a_current_library_is_taken() -> void:
	if not _current():
		return
	assert_true(NativeVersion.has(&"NativeWater"))
	assert_not_null(StillPoints.native_water())
	assert_true(ContactsNative.loaded())


func test_a_class_the_library_lacks_runs_the_gdscript() -> void:
	NativeVersion.expected = NativeVersion.ANY
	assert_true(NativeVersion.current())
	assert_false(NativeVersion.has(&"NativeNoSuchClass"))


## An export leaves native/src out and takes the library it ships with as it is.
func test_without_sources_the_library_is_taken() -> void:
	assert_eq(NativeVersion.digest(SCRATCH.path_join("none")), NativeVersion.ANY)
	NativeVersion.expected = NativeVersion.ANY
	assert_true(NativeVersion.current())


## The digest is native/SConstruct's source_digest, byte for byte: Python's hashlib over
## the same two files gives this.
func test_the_digest_is_the_build_scripts() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	_write("b.cpp", "// b\n")
	_write("a.h", "int a;\n")
	_write("notes.txt", "not a source\n")
	var want := "bb7e73d5db208687735ac98be01304e49a3669e046f8f3ff2c341f231307f644"
	assert_eq(NativeVersion.digest(SCRATCH), want)
	_write("a.h", "int a = 1;\n")
	assert_ne(NativeVersion.digest(SCRATCH), want, "any change to a source changes it")


func _write(name: String, text: String) -> void:
	var file := FileAccess.open(SCRATCH.path_join(name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Whether the library loaded was built from this checkout's native/src: a failure where
## CI requires it, pending elsewhere.
func _current() -> bool:
	var sources := NativeVersion.digest(NativeVersion.SOURCES)
	if ClassDB.class_exists(&"NativeWater") and NativeVersion.built() == sources:
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test(
			(
				"native/lib was built from %s, native/src is %s: make native, then make import"
				% [NativeVersion.built(), sources]
			)
		)
	elif ClassDB.class_exists(&"NativeWater"):
		pending("native/lib is stale here (make native)")
	else:
		pending("the extension is not built here (make native)")
	return false
