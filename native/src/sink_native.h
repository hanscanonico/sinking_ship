// The sinking bake's hottest loops in C++ (#411): SinkStepper's solves for a held head —
// a cell alone by false position (_balanced), cells together by Newton's method
// (_newton, LinearSystem.solved) — and its sweep of the openings (step), with every
// flow they ask (_transfer, _surplus, _levelling, TiltedBox's volume and height,
// SinkAir.lift, ShippedWater.into), each giving the GDScript's answers bit for bit.
// The stepper keeps the state: it hands over her cells' and openings' layout once, and
// at each turn, step and change of what is open what the loops read, and every call
// takes the heads, water and held cells it works on and gives back what it found.
// Around the solves (sink_step_native.cpp): each opening's share open (_share_out), the
// cells a step holds stiff (_hold_stiff), and SinkFailures' heads across each opening
// that can fail, what gives way at them and how far each stands from it.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <vector>

namespace godot {

class NativeSink : public RefCounted {
	GDCLASS(NativeSink, RefCounted)

public:
	void setup(const PackedInt32Array &p_first, const PackedInt32Array &p_second,
			const PackedByteArray &p_in_floor, const PackedFloat64Array &p_middle,
			const PackedFloat64Array &p_half, const PackedFloat64Array &p_flow_area,
			const PackedFloat64Array &p_frames, const PackedFloat64Array &p_capacity,
			const PackedFloat64Array &p_full_area, const PackedFloat64Array &p_constants);
	void wells(const PackedInt32Array &p_well_of, const PackedInt32Array &p_edges_from,
			const PackedFloat64Array &p_ends, const PackedFloat64Array &p_lengths, double p_rate);
	void touched(const PackedInt32Array &p_from, const PackedInt32Array &p_touching);
	void faces(const PackedInt32Array &p_axis, const PackedFloat64Array &p_facing);
	PackedFloat64Array turned(const PackedFloat64Array &p_up);
	PackedInt32Array upward() const;
	PackedFloat64Array heights(const PackedFloat64Array &p_water) const;
	void shut_times(const PackedFloat64Array &p_shut_time);
	PackedFloat64Array shares(double p_since, const PackedFloat64Array &p_opened);
	void watched(const PackedInt32Array &p_index, const PackedInt32Array &p_first,
			const PackedInt32Array &p_second, const PackedFloat64Array &p_shut_time,
			const PackedFloat64Array &p_leak, const PackedFloat64Array &p_collapse,
			const PackedFloat64Array &p_leak_share, const PackedInt32Array &p_toward);
	void began(const PackedInt32Array &p_pocket, const PackedFloat64Array &p_air,
			const PackedInt32Array &p_members_from, const PackedInt32Array &p_members_count,
			const PackedInt32Array &p_members, const PackedByteArray &p_holding,
			const PackedByteArray &p_alone, const PackedFloat64Array &p_surface);

	double transfer(int64_t p_index, const PackedFloat64Array &p_heads, const PackedByteArray &p_held,
			double p_sea, double p_seconds);
	double surplus(int64_t p_cell, double p_at, double p_water, const PackedFloat64Array &p_heads,
			const PackedByteArray &p_held, double p_sea, double p_seconds);
	double balanced(int64_t p_cell, double p_water, const PackedFloat64Array &p_heads,
			const PackedByteArray &p_held, double p_sea, double p_seconds);
	PackedFloat64Array newton(const PackedInt32Array &p_group, const PackedFloat64Array &p_water,
			const PackedFloat64Array &p_heads, const PackedByteArray &p_held, double p_sea, double p_seconds);
	PackedFloat64Array sweep(bool p_reverse, const PackedFloat64Array &p_heads,
			const PackedFloat64Array &p_water, const PackedByteArray &p_held, double p_sea,
			double p_seconds, double p_sea_given);
	PackedInt32Array stiff(const PackedFloat64Array &p_heads, const PackedFloat64Array &p_water,
			const PackedByteArray &p_held, const PackedByteArray &p_holding, double p_sea,
			double p_per_metre) const;
	PackedFloat64Array across(const PackedFloat64Array &p_heads, const PackedFloat64Array &p_water,
			double p_sea, const PackedFloat64Array &p_ceilings, const PackedFloat64Array &p_sills,
			const PackedInt32Array &p_pocket, const PackedFloat64Array &p_air,
			const PackedInt32Array &p_members_from, const PackedInt32Array &p_members_count,
			const PackedInt32Array &p_members) const;
	PackedFloat64Array failed(const PackedFloat64Array &p_across, const PackedFloat64Array &p_opened,
			double p_seconds) const;
	PackedFloat64Array failure_gaps(const PackedFloat64Array &p_across) const;

	double volume(int64_t p_cell, double p_height) const;
	double height(int64_t p_cell, double p_water) const;
	double common_level(int64_t p_a, int64_t p_b, const PackedFloat64Array &p_breaks, double p_total) const;
	PackedFloat64Array solved(const PackedFloat64Array &p_matrix, const PackedFloat64Array &p_values,
			int64_t p_count) const;

protected:
	static void _bind_methods();

private:
	// Her layout, as the stepper compiled it: per opening its sides, whether it is a hole
	// in a floor, its middle and half extents (three each) and flow area; per cell its
	// box's least corner and extent (six), the water it holds full and the surface over
	// its ceiling; the openings touching each cell, from[cell] to from[cell + 1].
	std::vector<int32_t> first_;
	std::vector<int32_t> second_;
	std::vector<uint8_t> in_floor_;
	std::vector<double> middle_;
	std::vector<double> half_;
	std::vector<double> flow_area_;
	std::vector<double> frames_;
	std::vector<double> capacity_;
	std::vector<double> full_area_;
	std::vector<int32_t> touch_from_;
	std::vector<int32_t> touching_;
	double g_ = 0.0;
	double discharge_ = 0.0;
	double atmosphere_ = 0.0;
	double least_ = 0.0;
	// Her open wells (ShippedWater): per cell its well or -1; per well its edges, from
	// edges_from[well] to edges_from[well + 1], each edge's two ends (six) and length;
	// and at the step begun, each edge end's height, the crest and the trough.
	std::vector<int32_t> well_of_;
	std::vector<int32_t> edges_from_;
	std::vector<double> ends_;
	std::vector<double> lengths_;
	std::vector<double> edge_heights_;
	double ship_rate_ = 0.0;
	double crest_ = 0.0;
	double trough_ = 0.0;
	// At the step begun, per well its edges' lowest end (ShippedWater.ships).
	std::vector<double> lowest_;
	// Per opening, the seconds the ship takes to shut it (SinkStepper.open_share).
	std::vector<double> shut_time_;
	// SinkFailures' watched openings, in its order: each one's index among the openings,
	// its sides, the seconds the ship takes to shut it, the heads it leaks and gives way
	// at, its leak's share of its area, and the side a hinged door opens toward.
	std::vector<int32_t> watched_index_;
	std::vector<int32_t> watched_first_;
	std::vector<int32_t> watched_second_;
	std::vector<double> watched_shut_;
	std::vector<double> leak_;
	std::vector<double> collapse_;
	std::vector<double> leak_share_;
	std::vector<int32_t> toward_;
	// At the attitude last turned to (TiltedBox.turn, SinkStepper._turn): per cell its
	// lowest and highest corner, shift, widths a ≥ b ≥ c, spreads counted and average
	// surface; per opening its bottom, top and width or area.
	std::vector<double> bottom_;
	std::vector<double> top_;
	std::vector<double> shift_;
	std::vector<double> a_;
	std::vector<double> b_;
	std::vector<double> c_;
	std::vector<int32_t> counted_;
	std::vector<double> area_;
	std::vector<double> opening_bottom_;
	std::vector<double> opening_top_;
	std::vector<double> opening_size_;
	// Per opening, SinkAir's: the ship axis it is flat across, or -1, and which way along
	// it its first side lies; and at the attitude last turned to, the way air passes it.
	std::vector<int32_t> axis_;
	std::vector<double> facing_;
	PackedInt32Array upward_;
	// In the step begun: each opening's share open; each cell's pocket, held water and
	// whether its push is its own; each pocket's air and cells, by its first cell; and
	// the push each pocket was last worked out at, with the heads it was worked from.
	std::vector<double> shares_;
	std::vector<int32_t> pocket_;
	std::vector<double> pocket_air_;
	std::vector<int32_t> members_from_;
	std::vector<int32_t> members_count_;
	std::vector<int32_t> members_;
	std::vector<uint8_t> holding_;
	std::vector<uint8_t> alone_;
	std::vector<double> pushed_;
	std::vector<double> pushed_at_;
	// The call under way: the held cells and the sea.
	const uint8_t *held_ = nullptr;
	double sea_ = 0.0;
	double seconds_ = 0.0;

	int64_t cells() const { return int64_t(capacity_.size()); }
	double share_of(int64_t p_cell, double p_t) const;
	double share_rising(int64_t p_cell, double p_t, double &r_slope) const;
	double level_of(int64_t p_a, int64_t p_b, double *p_breaks, int64_t p_count, double p_total) const;
	double between(int64_t p_a, int64_t p_b, double p_total, double p_low, double p_low_held,
			double p_high, double p_high_held) const;
	double push(int32_t p_first, const double *p_heads);
	double lift(int32_t p_cell, int32_t p_other, const double *p_heads);
	double flow_of(int64_t p_index, const double *p_heads, const double *p_following = nullptr);
	double orifice(double p_area, double p_difference, double p_give) const;
	double weir(double p_width, double p_depth, double p_give) const;
	double flow(double p_width, double p_bottom, double p_top, double p_high, double p_low) const;
	double levelling(int32_t p_up, int32_t p_down, const double *p_heads, double p_sill, double p_lifted) const;
	double ship_into(int64_t p_cell, double p_level) const;
	double ship_highest(int64_t p_cell) const;
	double gives_way_gap(int64_t p_watched, double p_across) const;
	double surplus_of(int64_t p_cell, double p_at, double p_water, double *p_heads);
	double balance(int64_t p_cell, double p_water, double *p_heads);
	bool solve_together(const std::vector<int32_t> &p_held, const double *p_water, double *p_heads);
	void solve(std::vector<double> &r_matrix, std::vector<double> &r_values, int64_t p_count,
			std::vector<double> &r_x) const;
	void begin_call(const PackedByteArray &p_held, double p_sea, double p_seconds);
};

} // namespace godot
