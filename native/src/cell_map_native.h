// CellMap.cell_at in C++: which of her cells a point lies in, asked a point at a time
// some two hundred times a tick (ShipPose's water, Falls, BotView). Stateful, unlike
// NativeWater: setup() takes one CellMap's slots, boxes and sections once, flattened as
// NativeWater.cells_at has them, and cell_at() then answers per point bit for bit.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class NativeCellMap : public RefCounted {
	GDCLASS(NativeCellMap, RefCounted)

	PackedVector3Array low;
	PackedVector3Array high;
	Vector3 from;
	Vector3 to;
	double slot = 1.0;
	PackedInt32Array slot_from;
	PackedInt32Array slot_cells;
	PackedByteArray poking;
	PackedFloat64Array inside_port;
	PackedFloat64Array inside_starboard;
	PackedFloat64Array section_x;
	PackedFloat64Array section_length;
	PackedInt32Array outline_from;
	PackedVector2Array outlines;
	Basis to_ship;
	bool framed = false;

public:
	void setup(const PackedVector3Array &p_low, const PackedVector3Array &p_high, const Vector3 &p_from,
			const Vector3 &p_to, double p_slot, const PackedInt32Array &p_slot_from,
			const PackedInt32Array &p_slot_cells, const PackedByteArray &p_poking,
			const PackedFloat64Array &p_inside_port, const PackedFloat64Array &p_inside_starboard,
			const PackedFloat64Array &p_section_x, const PackedFloat64Array &p_section_length,
			const PackedInt32Array &p_outline_from, const PackedVector2Array &p_outlines,
			const Basis &p_to_ship, bool p_framed);
	int64_t cell_at(const Vector3 &p_point) const;

protected:
	static void _bind_methods();
};

} // namespace godot
