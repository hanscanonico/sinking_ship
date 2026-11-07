// Her lamps' swing in C++ (#410): the loop of scenes/art/lamp_swing.gd that swings each
// lamp only swinging — its light settled, carried by LampSwing — toward the world's down
// under the node it hangs from, every frame, the Titanic's ~370 near the eye at once.
// The same float sums in the same order as the GDScript's, so each lamp hangs to the bit
// where the GDScript hangs it (test_swing_native). Stateless: LampSwing keeps every
// lamp's state and sets every node.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class NativeSwing : public RefCounted {
	GDCLASS(NativeSwing, RefCounted)

public:
	Array swing(const PackedInt32Array &p_slots, const PackedInt32Array &p_downs_of,
			const PackedVector3Array &p_downs, const PackedVector3Array &p_hang, const PackedVector3Array &p_swing,
			const PackedFloat64Array &p_clock, const PackedFloat64Array &p_since, const PackedVector3Array &p_at,
			const PackedFloat64Array &p_rules) const;

protected:
	static void _bind_methods();
};

} // namespace godot
