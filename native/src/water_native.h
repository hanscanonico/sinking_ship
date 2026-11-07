// The bots' reads of the water over every zone and portal at once, in C++ (#410): the
// loops of core/still_points.gd, ai/walk_graph.gd and ai/bot_refuge.gd that ask a pose
// of thousands of points, each giving the GDScript's answers bit for bit. Stateless:
// the callers keep what they have found, and the engine still sets the points in the
// world (Transform3D * PackedVector3Array); only the loops over them are here.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class NativeWater : public RefCounted {
	GDCLASS(NativeWater, RefCounted)

public:
	Array lamps_shown(const PackedInt32Array &p_cells, const PackedByteArray &p_lit, const PackedFloat64Array &p_levels,
			const PackedVector3Array &p_world, const PackedInt32Array &p_shown) const;
	PackedByteArray wet_all(const PackedVector3Array &p_world, const PackedInt32Array &p_cells,
			bool p_keeps, const PackedFloat64Array &p_levels,
			const PackedVector3Array &p_world_own_floors, double p_highest, double p_dry) const;
	PackedFloat64Array lowest_of(const PackedInt32Array &p_groups, const PackedVector3Array &p_world,
			const PackedInt32Array &p_chain_from, const PackedInt32Array &p_chain_cells,
			const PackedVector3Array &p_world_floors, const PackedFloat64Array &p_levels,
			double p_dry) const;
	PackedFloat64Array heights(int64_t p_rooms, const PackedVector3Array &p_middles,
			const PackedInt32Array &p_platforms_from, const PackedInt32Array &p_platforms,
			const PackedVector3Array &p_centres) const;
	PackedByteArray flooded(const PackedByteArray &p_known, int64_t p_rooms,
			const PackedByteArray &p_middles_wet, const PackedInt32Array &p_platforms_from,
			const PackedInt32Array &p_platforms, const PackedByteArray &p_platforms_wet) const;
	PackedByteArray portals_wet(const PackedByteArray &p_known, const PackedByteArray &p_ends_wet,
			const PackedByteArray &p_shut) const;
	PackedByteArray closed(const PackedInt32Array &p_portal_to, bool p_falling,
			const PackedByteArray &p_doomed, bool p_swim, bool p_wade,
			const PackedByteArray &p_flooded, const PackedByteArray &p_shut,
			const PackedByteArray &p_portal_wet) const;
	int64_t highest(const PackedByteArray &p_reached, bool p_falling, const PackedByteArray &p_doomed,
			const PackedFloat64Array &p_heights) const;
	PackedFloat64Array refuge(const PackedByteArray &p_reached, bool p_falling,
			const PackedByteArray &p_doomed, const PackedFloat64Array &p_heights, bool p_rising,
			const PackedFloat64Array &p_then, const PackedFloat64Array &p_now, double p_seconds,
			double p_rise_seconds, int64_t p_kept) const;
	double share(const PackedFloat64Array &p_areas, const PackedByteArray &p_under) const;

protected:
	static void _bind_methods();
};

} // namespace godot
