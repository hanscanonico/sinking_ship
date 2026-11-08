// Which of her rooms' lamps light the frame, in C++ (#410): the loops of
// scenes/art/lamp_sight.gd that look at every room near the eye each frame — whether
// the eye is near it on its storey, sees into it, or how far off it stands — and light
// the rooms out of sight nearest first within the preset's limit, for every stretch of
// the Titanic at once. The same float sums as the GDScript's, in the same order, so it
// lights what the GDScript lights (test_lamp_sight). Her rooms' boxes, areas and
// doorways are laid out once; LampSight keeps each frame's choice and hands it to the
// lamps.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

namespace godot {

class NativeSight : public RefCounted {
	GDCLASS(NativeSight, RefCounted)

public:
	void lay_out(const PackedVector3Array &p_box_positions, const PackedVector3Array &p_box_sizes,
			const PackedVector2Array &p_area_positions, const PackedVector2Array &p_area_sizes,
			const PackedInt32Array &p_doors_from, const PackedVector2Array &p_door_lines,
			const PackedVector2Array &p_door_ways, double p_reach, double p_storey);
	Array choose(const Vector3 &p_eye, const PackedInt32Array &p_looked_before, const PackedInt32Array &p_looked,
			const PackedInt32Array &p_burning, int64_t p_limit, const PackedByteArray &p_lit,
			const PackedFloat32Array &p_reach, const PackedByteArray &p_handed) const;

protected:
	static void _bind_methods();

private:
	bool sees(const Vector3 &p_eye, int32_t p_room) const;

	std::vector<Vector3> box_positions_;
	std::vector<Vector3> box_sizes_;
	std::vector<Vector2> area_positions_;
	std::vector<Vector2> area_sizes_;
	std::vector<int32_t> doors_from_;
	std::vector<Vector2> door_lines_;
	std::vector<Vector2> door_ways_;
	double reach_ = 0.0;
	double storey_ = 0.0;
};

} // namespace godot
