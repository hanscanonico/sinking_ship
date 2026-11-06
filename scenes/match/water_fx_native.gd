class_name WaterFxNative
extends RefCounted
## The water's effects' loops in the game's extension (native/, #410): InnerWater's walk
## of her cells and openings a frame, FxPlanner's and CuePlanner's of her decks, cells
## and openings a step, each worked by a NativeWaterFx to the GDScript's answers bit for
## bit (test_water_fx_native). None where the extension is not loaded — the web, a
## checkout that never ran make native — and the GDScript runs instead.


## A NativeWaterFx where the game's extension is loaded, else null.
static func made() -> Object:
	if not ClassDB.class_exists(&"NativeWaterFx"):
		return null
	return ClassDB.instantiate(&"NativeWaterFx")
