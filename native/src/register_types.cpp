// The extension's entry (sinking_native.gdextension): registers its classes at scene
// level, before any script that asks ClassDB for them runs. Each class is listed by its
// own file (SINKING_CLASS, registry.h), so adding one never edits this file.

#include "registry.h"

#include <gdextension_interface.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/string.hpp>

#include <vector>

using namespace godot;

// The digest of native/src this library was built from: native/SConstruct works it out
// and defines SINKING_NATIVE_SOURCE for this file alone.
#define SINKING_TEXT_(m_token) #m_token
#define SINKING_TEXT(m_token) SINKING_TEXT_(m_token)

namespace godot {

// Which sources this library was built from, read by core/native_version.gd: it works
// out the same digest of the native/src it runs beside and treats a library built from
// any other sources as absent, running the GDScript instead with a warning to run make
// native. Nothing is bumped by hand: a change to any file in native/src changes it.
class NativeAbi : public RefCounted {
	GDCLASS(NativeAbi, RefCounted)

public:
	String source() const { return SINKING_TEXT(SINKING_NATIVE_SOURCE); }

protected:
	static void _bind_methods() { ClassDB::bind_method(D_METHOD("source"), &NativeAbi::source); }
};

} // namespace godot

namespace sinking {

namespace {

// Made on first use, so a file's static that lists a class never finds it unbuilt.
std::vector<Registration> &listed() {
	static std::vector<Registration> registrations;
	return registrations;
}

} // namespace

bool list_class(Registration p_registration) {
	listed().push_back(p_registration);
	return true;
}

void register_classes() {
	for (Registration registration : listed()) {
		registration();
	}
}

} // namespace sinking

static void initialize_sinking_native(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(NativeAbi);
	sinking::register_classes();
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
