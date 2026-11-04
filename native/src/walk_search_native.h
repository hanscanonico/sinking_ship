// The walk-graph search of ai/walk_search.gd in C++ (#410): the same answers, bit for
// bit, for the bots of a ship whose search bounds her frame. WalkSearch hands every
// question to these when the extension is loaded, and answers them itself otherwise.

#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <vector>

namespace godot {

class NativeWalkSearch;

// What a search walks, laid out once a graph (WalkGraph._init): per zone its portals
// out, flat, and its pace; per portal where it leads, where it is entered and left, and
// its length.
class NativeWalkGraph : public RefCounted {
	GDCLASS(NativeWalkGraph, RefCounted)

public:
	std::vector<int32_t> out_start;
	std::vector<int32_t> out_portals;
	std::vector<int32_t> portal_to;
	std::vector<Vector3> portal_entry;
	std::vector<Vector3> portal_exit;
	std::vector<double> portal_length;
	std::vector<double> pace;

	void build(const Array &p_out, const PackedInt32Array &p_portal_to,
			const PackedVector3Array &p_portal_entry, const PackedVector3Array &p_portal_exit,
			const PackedFloat64Array &p_portal_length, const PackedFloat64Array &p_pace);
	int64_t zone_count() const;
	Ref<NativeWalkSearch> start(int64_t p_zones);

protected:
	static void _bind_methods();
};

// One WalkSearch: its methods, step for step, over a NativeWalkGraph.
class NativeWalkSearch : public RefCounted {
	GDCLASS(NativeWalkSearch, RefCounted)

	Ref<NativeWalkGraph> graph;
	int32_t zones = 0;
	PackedFloat64Array cost;
	std::vector<int32_t> came_by;
	std::vector<int32_t> came_from;
	std::vector<Vector3> arrived;
	std::vector<uint8_t> done;
	std::vector<double> heap_costs;
	std::vector<int32_t> heap_zones;
	std::vector<int32_t> seeds;
	PackedByteArray reach_;
	bool asked = false;
	PackedByteArray closed;

	// A zone as GDScript indexes a packed array by it: a negative one from the end.
	inline int32_t slot(int32_t p_zone) const { return p_zone < 0 ? p_zone + zones : p_zone; }
	void push(double p_cost, int32_t p_zone);
	void settle(int32_t p_goal, double p_within);

public:
	void setup(const Ref<NativeWalkGraph> &p_graph, int64_t p_zones);
	void reach(int64_t p_zone, double p_cost, const Vector3 &p_at, int64_t p_portal);
	void walk(const PackedByteArray &p_closed);
	bool is_empty() const;
	bool reaches(int64_t p_zone);
	PackedByteArray reached();
	double cost_to(int64_t p_zone, double p_within);
	PackedFloat64Array costs();
	PackedInt32Array way_to(int64_t p_zone);

protected:
	static void _bind_methods();
};

} // namespace godot
