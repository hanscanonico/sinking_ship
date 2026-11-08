// See sight_native.h.

#include "sight_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>
#include <limits>

namespace godot {

void NativeSight::_bind_methods() {
	ClassDB::bind_method(D_METHOD("lay_out", "box_positions", "box_sizes", "area_positions", "area_sizes",
								 "doors_from", "door_lines", "door_ways", "reach", "storey"),
			&NativeSight::lay_out);
	ClassDB::bind_method(D_METHOD("choose", "eye", "looked_before", "looked", "burning", "limit", "lit", "reach",
								 "handed"),
			&NativeSight::choose);
}

// Per room, its box (ship space) and its area on the ship plane; per side of it with a
// doorway, p_doors_from[room]… p_doors_from[room + 1] into p_door_lines (a point on the
// side's line) and p_door_ways (the side's way out); and how near the eye stands to a
// room it may light: p_reach across the ship plane, p_storey up or down
// (ShipLamp.relevant).
void NativeSight::lay_out(const PackedVector3Array &p_box_positions, const PackedVector3Array &p_box_sizes,
		const PackedVector2Array &p_area_positions, const PackedVector2Array &p_area_sizes,
		const PackedInt32Array &p_doors_from, const PackedVector2Array &p_door_lines,
		const PackedVector2Array &p_door_ways, double p_reach, double p_storey) {
	box_positions_.assign(p_box_positions.ptr(), p_box_positions.ptr() + p_box_positions.size());
	box_sizes_.assign(p_box_sizes.ptr(), p_box_sizes.ptr() + p_box_sizes.size());
	area_positions_.assign(p_area_positions.ptr(), p_area_positions.ptr() + p_area_positions.size());
	area_sizes_.assign(p_area_sizes.ptr(), p_area_sizes.ptr() + p_area_sizes.size());
	doors_from_.assign(p_doors_from.ptr(), p_doors_from.ptr() + p_doors_from.size());
	door_lines_.assign(p_door_lines.ptr(), p_door_lines.ptr() + p_door_lines.size());
	door_ways_.assign(p_door_ways.ptr(), p_door_ways.ptr() + p_door_ways.size());
	reach_ = p_reach;
	storey_ = p_storey;
}

// LampSight.sees: from inside its area, or from beyond a side of it with a doorway.
bool NativeSight::sees(const Vector3 &p_eye, int32_t p_room) const {
	const Vector2 across(p_eye.x, p_eye.z);
	const Rect2 area(area_positions_[p_room], area_sizes_[p_room]);
	if (area.has_point(across)) {
		return true;
	}
	for (int32_t door = doors_from_[p_room]; door < doors_from_[p_room + 1]; door++) {
		if ((across - door_lines_[door]).dot(door_ways_[door]) > 0.0) {
			return true;
		}
	}
	return false;
}

// LampSight.choose for the eye at p_eye (ship space), the rooms near its square
// p_looked, those the last choice looked at p_looked_before, each room's lamps burning
// p_burning, within the preset's p_limit; each room's last choice p_lit and p_reach,
// and what its lamps were last handed, p_handed. Returns the rooms' choice, lit and
// reach, and the rooms whose lamps are to be handed it, in the order the GDScript hands
// them (those looked at before, then those looked at now), each as room * 2 + lit.
Array NativeSight::choose(const Vector3 &p_eye, const PackedInt32Array &p_looked_before,
		const PackedInt32Array &p_looked, const PackedInt32Array &p_burning, int64_t p_limit,
		const PackedByteArray &p_lit, const PackedFloat32Array &p_reach, const PackedByteArray &p_handed) const {
	PackedByteArray lit_of = p_lit;
	PackedFloat32Array reach_of = p_reach;
	uint8_t *lit = lit_of.ptrw();
	float *reach = reach_of.ptrw();
	const int32_t *burning_of = p_burning.ptr();
	const float inf = std::numeric_limits<float>::infinity();
	const int32_t *before = p_looked_before.ptr();
	const int64_t before_count = p_looked_before.size();
	const int32_t *looked = p_looked.ptr();
	const int64_t looked_count = p_looked.size();
	for (int64_t at = 0; at < before_count; at++) {
		lit[before[at]] = 0;
		reach[before[at]] = inf;
	}
	int64_t burning = 0;
	for (int64_t at = 0; at < looked_count; at++) {
		const int32_t room = looked[at];
		// ShipLamp.relevant: GDScript takes each difference in doubles, then makes the
		// Vector2 of them in real_t.
		const Vector3 end = box_positions_[room] + box_sizes_[room];
		const Vector3 nearest = p_eye.clamp(box_positions_[room], end);
		const Vector2 flat(real_t(double(p_eye.x) - double(nearest.x)), real_t(double(p_eye.z) - double(nearest.z)));
		const double across = flat.length();
		if (!(across <= reach_ && std::abs(double(p_eye.y) - double(nearest.y)) <= storey_)) {
			continue;
		}
		if (sees(p_eye, room)) {
			lit[room] = 1;
			burning += burning_of[room];
		} else {
			reach[room] = flat.length();
		}
	}
	while (true) {
		int32_t next = -1;
		for (int64_t at = 0; at < looked_count; at++) {
			const int32_t room = looked[at];
			if (lit[room] == 0 && (next == -1 || reach[room] < reach[next])) {
				next = room;
			}
		}
		if (next == -1 || std::isinf(reach[next]) || burning + burning_of[next] > p_limit) {
			break;
		}
		lit[next] = 1;
		burning += burning_of[next];
	}
	PackedByteArray handed_of = p_handed;
	uint8_t *handed = handed_of.ptrw();
	PackedInt32Array handing;
	for (int64_t at = 0; at < before_count + looked_count; at++) {
		const int32_t room = at < before_count ? before[at] : looked[at - before_count];
		if (lit[room] != handed[room]) {
			handed[room] = lit[room];
			handing.push_back(room * 2 + lit[room]);
		}
	}
	Array found;
	found.push_back(lit_of);
	found.push_back(reach_of);
	found.push_back(handing);
	return found;
}

} // namespace godot
