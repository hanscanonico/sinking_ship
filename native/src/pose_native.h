// A piece's water in C++: SinkSchedule._piece_pose's walk of its cells, each one's head
// and pocket carried between two kept states and what lights it, the very arithmetic the
// GDScript does (lerpf as a + (b - a) * w in doubles, SinkTimeline._pocket_between's one
// branch), so each pose holds the same numbers to the bit.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

class NativePose : public RefCounted {
	GDCLASS(NativePose, RefCounted)

public:
	// The timeline's heads, pockets and lights, per state kept, p_cells to a state (the
	// arrays are shared, never copied): again whenever the timeline has grown.
	void hold(const PackedFloat64Array &p_heads, const PackedFloat64Array &p_pockets,
			const PackedByteArray &p_lits, int64_t p_cells);
	// For the timeline's cells p_at, in order, p_weight of the way from state p_frame to
	// p_next: [levels (each head plus p_rise), pockets, lit as p_frame has it].
	Array pose(const PackedInt32Array &p_at, int64_t p_frame, int64_t p_next, double p_weight,
			double p_rise) const;

protected:
	static void _bind_methods();

private:
	PackedFloat64Array heads_;
	PackedFloat64Array pockets_;
	PackedByteArray lits_;
	int64_t cells_ = 0;
};

} // namespace godot
