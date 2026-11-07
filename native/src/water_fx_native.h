// The water's effects in C++ (#410): the loops of scenes/art/inner_water.gd,
// scenes/match/fx_planner.gd and scenes/audio/cue_planner.gd that go through every
// cell, opening and deck of hers a frame or a step, each giving the GDScript's answers
// bit for bit. Stateless: the callers keep what they have found and every node they
// draw, and the engine still sets the points in the world (Transform3D *
// PackedVector3Array) — only the loops over them, in doubles, are here; each call says
// which cells, openings or decks the GDScript is left to draw or tell.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class NativeWaterFx : public RefCounted {
	GDCLASS(NativeWaterFx, RefCounted)

public:
	PackedFloat64Array levels_between(const PackedFloat64Array &p_then, const PackedFloat64Array &p_now,
			double p_alpha) const;
	PackedInt32Array surfaces(const PackedFloat64Array &p_levels, const PackedInt32Array &p_cells,
			const PackedVector3Array &p_middles, const PackedVector3Array &p_halves,
			const PackedFloat64Array &p_spread, const PackedByteArray &p_shown) const;
	Array stacks(const PackedFloat64Array &p_levels, const PackedInt32Array &p_stack_cells,
			const PackedInt32Array &p_stacks_from, const PackedVector3Array &p_bound_middles,
			const PackedVector3Array &p_bound_halves, const PackedInt32Array &p_stacks_shown,
			const PackedVector3Array &p_middles, const PackedVector3Array &p_halves,
			const PackedFloat64Array &p_spread, const PackedByteArray &p_shown) const;
	Array find_wet(const PackedFloat64Array &p_then, const PackedFloat64Array &p_now,
			const PackedFloat64Array &p_heads, const PackedInt32Array &p_slots,
			const PackedByteArray &p_made, const PackedByteArray &p_drawn,
			const PackedVector3Array &p_middles_then, const PackedVector3Array &p_middles_now,
			const PackedFloat64Array &p_rises, const PackedFloat64Array &p_reaches,
			const PackedVector2Array &p_last_heads, const PackedInt32Array &p_wet) const;
	PackedByteArray reading(const PackedVector3Array &p_floors, const PackedVector3Array &p_floor_halves,
			const PackedFloat64Array &p_levels, const PackedFloat64Array &p_row, double p_rise,
			const PackedInt32Array &p_sides, const PackedVector3Array &p_centres,
			const PackedVector3Array &p_opening_halves, double p_shows, double p_pours) const;
	Array coming_on(const PackedByteArray &p_then, const PackedByteArray &p_now, int64_t p_cells,
			const PackedByteArray &p_decks_then, const PackedByteArray &p_decks_now,
			const PackedInt32Array &p_platform_slots, const PackedByteArray &p_heard,
			const PackedInt32Array &p_off_since, int64_t p_tick, int64_t p_cell_rearm,
			int64_t p_pour_rearm) const;
	PackedInt32Array risen(const PackedByteArray &p_now, const PackedByteArray &p_then) const;
	PackedInt32Array held(const PackedFloat64Array &p_pockets, int64_t p_count) const;
	Array placed(const PackedInt32Array &p_touched, const PackedInt32Array &p_cells, const PackedFloat64Array &p_levels,
			const PackedVector3Array &p_middles, const PackedVector3Array &p_world_middles,
			const PackedVector3Array &p_halves, const Basis &p_level) const;
	Array pours(const PackedInt32Array &p_wet, const PackedFloat64Array &p_levels, const PackedInt32Array &p_sides,
			const PackedVector3Array &p_centres, const PackedVector3Array &p_sizes, const PackedInt32Array &p_facings,
			const PackedByteArray &p_drawn, const PackedByteArray &p_crossed, const PackedVector3Array &p_span_middles,
			const PackedVector3Array &p_span_halves, const PackedVector3Array &p_world_centres,
			const PackedVector3Array &p_world_unders, const PackedVector2Array &p_last_heads,
			const PackedFloat64Array &p_open, const PackedFloat64Array &p_flow, const PackedVector3Array &p_cell_lows,
			const PackedVector3Array &p_cell_highs, const PackedVector3Array &p_flats,
			const PackedFloat64Array &p_spread) const;
	Array inflows(const PackedFloat64Array &p_then, const PackedFloat64Array &p_now,
			const PackedVector3Array &p_middles_then, const PackedVector3Array &p_middles_now,
			const PackedFloat64Array &p_inflows, double p_seconds, double p_full, double p_ease, double p_calm) const;

protected:
	static void _bind_methods();
};

} // namespace godot
