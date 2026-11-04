// Each loop here is a GDScript one, line for line: a Vector3's y is a float32 widened
// to a double where the GDScript reads it into a float, sums run in the same order,
// minf and maxf are the engine's (a < b ? a : b, a > b ? a : b). Contraction is off.

#include "water_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <limits>

using namespace godot;

namespace {
constexpr int32_t NONE = -1;
constexpr double INF = std::numeric_limits<double>::infinity();

inline double min_f(double p_a, double p_b) {
	return p_a < p_b ? p_a : p_b;
}

inline double max_f(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}
} // namespace

// StillPoints.wet_all.
PackedByteArray NativeWater::wet_all(const PackedVector3Array &p_world, const PackedInt32Array &p_cells,
		bool p_keeps, const PackedFloat64Array &p_levels, const PackedVector3Array &p_world_own_floors,
		double p_highest, double p_dry) const {
	PackedByteArray found;
	const int64_t count = p_world.size();
	found.resize(count);
	found.fill(0);
	uint8_t *out = found.ptrw();
	const Vector3 *world = p_world.ptr();
	const int32_t *cells = p_cells.ptr();
	const double *levels = p_levels.ptr();
	const Vector3 *own = p_world_own_floors.ptr();
	for (int64_t index = 0; index < count; index++) {
		const double height = double(world[index].y);
		if (height >= p_highest) {
			continue;
		}
		const int32_t cell = p_keeps ? cells[index] : NONE;
		if (cell == NONE) {
			out[index] = height < 0.0 ? 1 : 0;
			continue;
		}
		const double level = levels[cell];
		if (height < level && level > double(own[index].y) + p_dry) {
			out[index] = 1;
		}
	}
	return found;
}

// Per group of points, from p_groups[group] to p_groups[group + 1], the least of their
// StillPoints.above_water (ShipPose.above_water_seen) — WalkGraph._floor_lowest of
// every zone.
PackedFloat64Array NativeWater::lowest_of(const PackedInt32Array &p_groups, const PackedVector3Array &p_world,
		const PackedInt32Array &p_chain_from, const PackedInt32Array &p_chain_cells,
		const PackedVector3Array &p_world_floors, const PackedFloat64Array &p_levels, double p_dry) const {
	PackedFloat64Array lowest_all;
	const int64_t groups = p_groups.size() - 1;
	if (groups <= 0) {
		return lowest_all;
	}
	lowest_all.resize(groups);
	double *out = lowest_all.ptrw();
	const int32_t *from = p_groups.ptr();
	const Vector3 *world = p_world.ptr();
	const int32_t *chain_from = p_chain_from.ptr();
	const int32_t *chain_cells = p_chain_cells.ptr();
	const Vector3 *floors = p_world_floors.ptr();
	const double *levels = p_levels.ptr();
	const bool dry_pose = p_levels.is_empty();
	for (int64_t group = 0; group < groups; group++) {
		double lowest = INF;
		for (int32_t corner = from[group]; corner < from[group + 1]; corner++) {
			const double height = double(world[corner].y);
			double above = height;
			if (!dry_pose) {
				for (int32_t at = chain_from[corner]; at < chain_from[corner + 1]; at++) {
					const int32_t cell = chain_cells[at];
					if (levels[cell] > double(floors[at].y) + p_dry) {
						above = height - levels[cell];
						break;
					}
				}
			}
			lowest = min_f(lowest, above);
		}
		out[group] = lowest;
	}
	return lowest_all;
}

// WalkGraph.world_height of every zone: a room by its middle, an open deck by the
// highest middle of its platforms.
PackedFloat64Array NativeWater::heights(int64_t p_rooms, const PackedVector3Array &p_middles,
		const PackedInt32Array &p_platforms_from, const PackedInt32Array &p_platforms,
		const PackedVector3Array &p_centres) const {
	PackedFloat64Array heights_all;
	const int64_t zones = p_platforms_from.size() - 1;
	if (zones <= 0) {
		return heights_all;
	}
	heights_all.resize(zones);
	double *out = heights_all.ptrw();
	const Vector3 *middles = p_middles.ptr();
	const int32_t *from = p_platforms_from.ptr();
	const int32_t *platforms = p_platforms.ptr();
	const Vector3 *centres = p_centres.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (zone < p_rooms) {
			out[zone] = double(middles[zone].y);
			continue;
		}
		double height = -INF;
		for (int32_t at = from[zone]; at < from[zone + 1]; at++) {
			height = max_f(height, double(centres[platforms[at]].y));
		}
		out[zone] = height;
	}
	return heights_all;
}

// WalkGraph._flood_every_zone: 2 for flooded, 1 for not, what is known kept.
PackedByteArray NativeWater::flooded(const PackedByteArray &p_known, int64_t p_rooms,
		const PackedByteArray &p_middles_wet, const PackedInt32Array &p_platforms_from,
		const PackedInt32Array &p_platforms, const PackedByteArray &p_platforms_wet) const {
	PackedByteArray flooded_all = p_known;
	const int64_t zones = flooded_all.size();
	uint8_t *out = flooded_all.ptrw();
	const uint8_t *middles = p_middles_wet.ptr();
	const int32_t *from = p_platforms_from.ptr();
	const int32_t *platforms = p_platforms.ptr();
	const uint8_t *decks = p_platforms_wet.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (out[zone] != 0) {
			continue;
		}
		bool under = true;
		if (zone < p_rooms) {
			under = middles[zone] == 1;
		} else {
			for (int32_t at = from[zone]; at < from[zone + 1]; at++) {
				if (decks[platforms[at]] != 1) {
					under = false;
					break;
				}
			}
		}
		out[zone] = under ? 2 : 1;
	}
	return flooded_all;
}

// WalkGraph._wet_every_portal, every portal's shut known already.
PackedByteArray NativeWater::portals_wet(const PackedByteArray &p_known, const PackedByteArray &p_ends_wet,
		const PackedByteArray &p_shut) const {
	PackedByteArray wet_all = p_known;
	const int64_t portals = wet_all.size();
	uint8_t *out = wet_all.ptrw();
	const uint8_t *ends = p_ends_wet.ptr();
	const uint8_t *shut = p_shut.ptr();
	for (int64_t index = 0; index < portals; index++) {
		if (out[index] != 0) {
			continue;
		}
		const bool wet = ends[index * 2] == 1 || ends[index * 2 + 1] == 1;
		out[index] = wet || shut[index] == 2 ? 2 : 1;
	}
	return wet_all;
}

// WalkGraph._closed_ways' loop: 1 where a search may not go through the portal.
PackedByteArray NativeWater::closed(const PackedInt32Array &p_portal_to, bool p_falling,
		const PackedByteArray &p_doomed, bool p_swim, bool p_wade, const PackedByteArray &p_flooded,
		const PackedByteArray &p_shut, const PackedByteArray &p_portal_wet) const {
	PackedByteArray closed_all;
	const int64_t portals = p_portal_to.size();
	closed_all.resize(portals);
	closed_all.fill(0);
	uint8_t *out = closed_all.ptrw();
	const int32_t *to = p_portal_to.ptr();
	const uint8_t *doomed = p_doomed.ptr();
	const uint8_t *flooded = p_flooded.ptr();
	const uint8_t *shut = p_shut.ptr();
	const uint8_t *wet = p_portal_wet.ptr();
	for (int64_t index = 0; index < portals; index++) {
		const int32_t other = to[index];
		if ((p_falling && doomed[other] == 2) ||
				(!p_swim && (flooded[other] == 2 || shut[index] == 2)) ||
				(!p_swim && !p_wade && wet[index] == 2)) {
			out[index] = 1;
		}
	}
	return closed_all;
}

// WalkGraph.highest_in's loop: the highest zone reached and not giving way, or NONE.
int64_t NativeWater::highest(const PackedByteArray &p_reached, bool p_falling, const PackedByteArray &p_doomed,
		const PackedFloat64Array &p_heights) const {
	int64_t best = NONE;
	double best_height = -INF;
	const int64_t zones = p_reached.size();
	const uint8_t *reached = p_reached.ptr();
	const uint8_t *doomed = p_doomed.ptr();
	const double *heights = p_heights.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (reached[zone] == 0 || (p_falling && doomed[zone] == 2)) {
			continue;
		}
		const double height = heights[zone];
		if (height > best_height) {
			best = zone;
			best_height = height;
		}
	}
	return best;
}

// BotRefuge.choose's loop: [best, its height, the kept one's height (-INF for none)],
// each zone's height marked down by its rise (BotRefuge._rise) times p_rise_seconds.
PackedFloat64Array NativeWater::refuge(const PackedByteArray &p_reached, bool p_falling,
		const PackedByteArray &p_doomed, const PackedFloat64Array &p_heights, bool p_rising,
		const PackedFloat64Array &p_then, const PackedFloat64Array &p_now, double p_seconds,
		double p_rise_seconds, int64_t p_kept) const {
	int64_t best = NONE;
	double best_height = -INF;
	double kept_height = -INF;
	const int64_t zones = p_reached.size();
	const uint8_t *reached = p_reached.ptr();
	const uint8_t *doomed = p_doomed.ptr();
	const double *heights = p_heights.ptr();
	const double *then = p_then.ptr();
	const double *now = p_now.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (reached[zone] == 0 || (p_falling && doomed[zone] == 2)) {
			continue;
		}
		double rise = 0.0;
		if (p_rising) {
			const double fallen = then[zone] - now[zone];
			rise = max_f(fallen / p_seconds, 0.0);
		}
		const double marked = rise * p_rise_seconds;
		const double height = heights[zone] - marked;
		if (zone == p_kept) {
			kept_height = height;
		}
		if (height > best_height) {
			best = zone;
			best_height = height;
		}
	}
	PackedFloat64Array found;
	found.push_back(double(best));
	found.push_back(best_height);
	found.push_back(kept_height);
	return found;
}

// WalkGraph.flooded_share's sum: each platform's area, and its area again where under.
double NativeWater::share(const PackedFloat64Array &p_areas, const PackedByteArray &p_under) const {
	double flooded = 0.0;
	double whole = 0.0;
	const int64_t platforms = p_areas.size();
	const double *areas = p_areas.ptr();
	const uint8_t *under = p_under.ptr();
	for (int64_t platform = 0; platform < platforms; platform++) {
		const double area = areas[platform];
		whole += area;
		flooded += under[platform] == 1 ? area : 0.0;
	}
	return whole > 0.0 ? flooded / whole : 0.0;
}

void NativeWater::_bind_methods() {
	ClassDB::bind_method(D_METHOD("wet_all", "world", "cells", "keeps", "levels", "world_own_floors", "highest",
								 "dry"),
			&NativeWater::wet_all);
	ClassDB::bind_method(D_METHOD("lowest_of", "groups", "world", "chain_from", "chain_cells", "world_floors",
								 "levels", "dry"),
			&NativeWater::lowest_of);
	ClassDB::bind_method(D_METHOD("heights", "rooms", "middles", "platforms_from", "platforms", "centres"),
			&NativeWater::heights);
	ClassDB::bind_method(D_METHOD("flooded", "known", "rooms", "middles_wet", "platforms_from", "platforms",
								 "platforms_wet"),
			&NativeWater::flooded);
	ClassDB::bind_method(D_METHOD("portals_wet", "known", "ends_wet", "shut"), &NativeWater::portals_wet);
	ClassDB::bind_method(D_METHOD("closed", "portal_to", "falling", "doomed", "swim", "wade", "flooded", "shut",
								 "portal_wet"),
			&NativeWater::closed);
	ClassDB::bind_method(D_METHOD("highest", "reached", "falling", "doomed", "heights"), &NativeWater::highest);
	ClassDB::bind_method(D_METHOD("refuge", "reached", "falling", "doomed", "heights", "rising", "then", "now",
								 "seconds", "rise_seconds", "kept"),
			&NativeWater::refuge);
	ClassDB::bind_method(D_METHOD("share", "areas", "under"), &NativeWater::share);
}
