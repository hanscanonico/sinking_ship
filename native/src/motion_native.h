// The sinking bake's lift and load in C++ (#411): ShipMotion.lift_under — her sections
// cut by the sea at whatever attitude she has, the volume they push aside, its centre and
// her waterplane —, ShipMotion.highest and ShipMotion._loaded — her water's volume and
// moments, each cell's box turned (TiltedBox) —, each giving the GDScript's answers bit
// for bit. ShipMotion hands over her sections once and her cells' boxes once, and keeps
// its memo of the last lift asked; the boxes' own turns stay the GDScript's.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <vector>

namespace godot {

class NativeMotion : public RefCounted {
	GDCLASS(NativeMotion, RefCounted)

public:
	void setup(const PackedFloat64Array &p_x, const PackedFloat64Array &p_length,
			const PackedInt32Array &p_first, const PackedInt32Array &p_count,
			const PackedFloat64Array &p_points, const PackedFloat64Array &p_whole,
			const PackedInt32Array &p_corner_first, const PackedInt32Array &p_corner_count,
			const PackedFloat64Array &p_corners, const PackedFloat64Array &p_centre);
	PackedFloat64Array lift_under(const PackedFloat64Array &p_rotation, double p_sea);
	double highest(const PackedFloat64Array &p_rotation, double p_sea) const;
	void boxes(const PackedFloat64Array &p_frames, const PackedFloat64Array &p_capacity,
			const PackedFloat64Array &p_full_area, const PackedFloat64Array &p_sideways);
	PackedFloat64Array loaded(const PackedFloat64Array &p_rotation, const PackedFloat64Array &p_water) const;

protected:
	static void _bind_methods();

private:
	// ShipMotion's, per section: where along her and how long, its outline's points (z then
	// y) from first_[section], count_[section] of them, its whole outline's shoelace sums
	// (three) and its convex corners (z then y) from corner_first_[section]; and her centre
	// of mass, x, y, z.
	std::vector<double> x_;
	std::vector<double> length_;
	std::vector<int32_t> first_;
	std::vector<int32_t> count_;
	std::vector<double> points_;
	std::vector<double> whole_;
	std::vector<int32_t> corner_first_;
	std::vector<int32_t> corner_count_;
	std::vector<double> corners_;
	double centre_[3] = { 0.0, 0.0, 0.0 };
	// Where the section under way crosses the sea's line, along the line then z and y.
	std::vector<double> crossings_;
	// Per cell, its box's least corner and extent (six), the water it holds full, the
	// surface over its ceiling once full and its sideways share (TiltedBox).
	std::vector<double> frames_;
	std::vector<double> capacity_;
	std::vector<double> full_area_;
	std::vector<double> sideways_;

	void strips(const double *p_rotation, int64_t p_section, double p_across, double *r_plane);
	void sort_crossings();
};

} // namespace godot
