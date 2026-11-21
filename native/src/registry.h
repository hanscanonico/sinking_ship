// The extension's classes, each listed by the file that binds it: SINKING_CLASS(NativeX)
// beside NativeX::_bind_methods, and register_types.cpp registers every one listed at
// scene level. A new class touches no line another class's change touches.

#pragma once

#include <godot_cpp/core/class_db.hpp>

namespace sinking {

using Registration = void (*)();

// Adds a class's registration to those register_classes() runs; true, for a static.
bool list_class(Registration p_registration);
// Registers every class listed, in the order the library's files were linked.
void register_classes();

} // namespace sinking

#define SINKING_CLASS(m_class) \
	[[maybe_unused]] static const bool m_class##_listed = \
			::sinking::list_class([]() { GDREGISTER_CLASS(m_class); });
