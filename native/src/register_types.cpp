// The extension's entry (sinking_native.gdextension): registers its classes at scene
// level, before any script that asks ClassDB for them runs.

#include "art_native.h"
#include "contacts_native.h"
#include "hull_native.h"
#include "motion_native.h"
#include "sight_native.h"
#include "sink_native.h"
#include "still_native.h"
#include "walk_search_native.h"
#include "water_fx_native.h"
#include "water_native.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static void initialize_sinking_native(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(NativeWalkGraph);
	GDREGISTER_CLASS(NativeWalkSearch);
	GDREGISTER_CLASS(NativeWater);
	GDREGISTER_CLASS(NativeSight);
	GDREGISTER_CLASS(NativeSink);
	GDREGISTER_CLASS(NativeMotion);
	GDREGISTER_CLASS(NativeLevelHull);
	GDREGISTER_CLASS(NativeGirder);
	GDREGISTER_CLASS(NativeIndoorGrid);
	GDREGISTER_CLASS(NativeLining);
	GDREGISTER_CLASS(NativeShipMesh);
	GDREGISTER_CLASS(NativeStands);
	GDREGISTER_CLASS(NativeSurfaces);
	GDREGISTER_CLASS(NativeCrates);
	GDREGISTER_CLASS(NativeWaterFx);
	GDREGISTER_CLASS(NativeStill);
}

static void uninitialize_sinking_native(ModuleInitializationLevel p_level) {
}

extern "C" {
GDExtensionBool GDE_EXPORT sinking_native_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_sinking_native);
	init_obj.register_terminator(uninitialize_sinking_native);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
