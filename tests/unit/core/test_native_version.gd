extends GutTest
## A library in native/lib older than the GDScript that calls it (NativeVersion) is
## treated as absent: every loader hands back its GDScript instead of a native object
## whose methods may be missing, as #671's NativeWater.chains_under was from a library
## built before it. CI sets SINKING_NATIVE_REQUIRED, so a stale library there fails.


func after_each() -> void:
	NativeVersion.expected = NativeVersion.VERSION


func test_a_stale_library_runs_the_gdscript() -> void:
	NativeVersion.expected = NativeVersion.VERSION + 1
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


## Whether the library loaded is of this version: a failure where CI requires it,
## pending elsewhere.
func _current() -> bool:
	if ClassDB.class_exists(&"NativeWater") and NativeVersion.built() == NativeVersion.VERSION:
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test(
			(
				"native/lib is version %d, not %d: make native, then make import"
				% [NativeVersion.built(), NativeVersion.VERSION]
			)
		)
	elif ClassDB.class_exists(&"NativeWater"):
		pending("native/lib is stale here (make native)")
	else:
		pending("the extension is not built here (make native)")
	return false
