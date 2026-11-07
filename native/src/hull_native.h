// Her hull's sums over her sections in C++: LevelHull's build — each section's breadth
// as straight lines between its corner heights, and the volume under every corner height
// of all of them — and HullGirder.measure — the loads on her stations, the bending they
// give and her worst station —, each giving the GDScript's answers bit for bit. Both
// grow with her sections: a hull cut fine where she tapers has hundreds (#492).

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <vector>

namespace godot {

class NativeLevelHull : public RefCounted {
	GDCLASS(NativeLevelHull, RefCounted)

public:
	PackedFloat64Array build(const PackedVector2Array &p_points, const PackedInt32Array &p_first,
			const PackedFloat64Array &p_length) const;

protected:
	static void _bind_methods();
};

class NativeGirder : public RefCounted {
	GDCLASS(NativeGirder, RefCounted)

public:
	void setup(const PackedFloat64Array &p_own, const PackedInt32Array &p_first, const PackedInt32Array &p_counts,
			const PackedInt32Array &p_starts, const PackedFloat64Array &p_shares, const PackedFloat64Array &p_bounds,
			double p_hog, double p_sag);
	PackedFloat64Array measure(const PackedFloat64Array &p_lift, const PackedFloat64Array &p_water, double p_across) const;

protected:
	static void _bind_methods();

private:
	// HullGirder's: per station her own weight; per cell its first station, how many it
	// reaches and where its shares start; the shares; her stations' ends; her strength.
	std::vector<double> own_;
	std::vector<int32_t> first_;
	std::vector<int32_t> counts_;
	std::vector<int32_t> starts_;
	std::vector<double> shares_;
	std::vector<double> bounds_;
	double hog_ = 1.0;
	double sag_ = 1.0;
};

} // namespace godot
